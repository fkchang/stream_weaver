# frozen_string_literal: true

require 'timeout'
require 'shellwords'

module StreamWeaver
  # iTerm2 integration for panel workflow via the optional iterm2_ruby gem
  # (`gem install iterm2_ruby` — https://rubygems.org/gems/iterm2_ruby).
  # Falls back to system browser when iTerm2 API is unavailable.
  class ITerm
    # iTerm2's built-in profile that renders a web view instead of a shell.
    BROWSER_PROFILE = "Web Browser"

    # Default window frames (points) for the two windows this class ever
    # creates from scratch -- the University controller (narrow, tall) and a
    # worker tab that couldn't inherit the caller's window (wide, short).
    # Each is overridable via env as "x,y,width,height".
    CONTROLLER_FRAME_DEFAULTS = { x: 40, y: 40, width: 760, height: 1200 }.freeze
    WORKER_FRAME_DEFAULTS = { x: 80, y: 80, width: 1600, height: 1000 }.freeze

    # Bracketed paste (DEC 2004). A TUI that has enabled the mode reads
    # everything between these two sequences as one pasted block and takes
    # the block whole, rather than interpreting each byte as it arrives --
    # which is what lets the Return that follows read as a keypress.
    PASTE_START = "\e[200~"
    PASTE_END = "\e[201~"

    class << self
      def available?
        return @available if defined?(@available)
        @available = check_availability
      end

      def current_session_guid
        ENV["ITERM_SESSION_ID"]&.split(":", 2)&.last&.then { |g| g.empty? ? nil : g }
      end

      # True only when the user is inside iTerm2 on macOS but the optional gem
      # isn't installed — the one case where a "gem install iterm2_ruby" hint
      # is actionable rather than noise.
      def gem_missing?
        !available? &&
          RbConfig::CONFIG["host_os"].match?(/darwin/) &&
          !ENV["ITERM_SESSION_ID"].to_s.empty?
      end

      # Split a browser pane with the URL into `target_session` (any session
      # id, e.g. a just-created worker tab's session -- not necessarily the
      # calling pane). Defaults to the calling session (current_session_guid)
      # when target_session is nil, matching the original single-pane
      # `panel` behavior. Returns Hash with :type (:browser, :external, or
      # nil) and :pane_id.
      def split_vertical_with_url(url, open_browser: true, horizontal: false, target_session: nil)
        return { type: nil, pane_id: nil } unless available?

        pane_id = split_browser_pane(url, horizontal: horizontal, target_session: target_session)

        if pane_id
          { type: :browser, pane_id: pane_id }
        elsif open_browser && !ENV['SW_NO_OPEN']
          system("open", url)
          { type: :external, pane_id: nil }
        else
          { type: nil, pane_id: nil }
        end
      end

      # Opens `url` in an iTerm2 browser pane that owns a WHOLE WINDOW, and
      # returns that browser session's id (nil if it could not be opened) --
      # same shape as open_worker_tab.
      #
      # StreamWeaver University's canvas is a controller, not a sidecar: it
      # gets its own window so the worker tab stays free for the agent and
      # the demo canvas panes the course steps have it create. iTerm2's API
      # has no "new browser window" call, so this composes three primitives
      # that already work elsewhere in this file -- create_tab with no
      # window_id makes a new window, split_pane with the Web Browser
      # profile makes the browser, and the shell that came with the window
      # is then closed so only the canvas is left.
      #
      # A brand new iTerm2 window opens at the profile's default size --
      # unlike open_worker_tab below, this one has no caller's window to
      # reuse (the controller is its own window by design), so it sizes
      # itself explicitly via set_window_frame instead: a narrow controller
      # shape (CONTROLLER_FRAME_DEFAULTS, overridable via SW_CONTROLLER_FRAME).
      # Degrades silently on an older iterm2_ruby that lacks the method.
      def open_browser_window(url)
        return nil unless available?

        with_timeout(10, default: nil) do
          connect do |c|
            created = c.create_tab
            shell = created && created[:session_id]
            next nil unless shell

            apply_window_frame(c, created[:window_id], "SW_CONTROLLER_FRAME", CONTROLLER_FRAME_DEFAULTS)

            pane = browser_pane_in(c, shell, url)

            # Either way the shell goes: with a browser it would be clutter
            # beside the canvas, and without one it is a window the user
            # never asked for and cannot account for. Closing the only
            # session takes the window with it. Scoped so a close that
            # fails can never cost us a working pane's id -- losing that
            # would leave a canvas window nothing can close later.
            close_quietly(c, shell)
            pane
          end
        end
      rescue StandardError
        nil
      end

      def close_pane(pane_id)
        return false unless available? && pane_id
        connect { |c| c.close_session(pane_id, force: true) }
      rescue ITerm2::Error
        false
      end

      def split_vertical_with_command(command)
        return false unless available?

        guid = current_session_guid or return false

        connect do |c|
          new_id = c.split_pane(guid, vertical: true)
          c.send_text(new_id, "#{command}\n")
        end
        true
      rescue ITerm2::Error
        false
      end

      def navigate_browser(session_id, url)
        return false unless available? && session_id
        connect { |c| c.set_profile_property(session_id, "Initial URL", url) }
      rescue ITerm2::Error
        false
      end

      # Attempts an actual connection to iTerm2's Python API server (osascript
      # auth handshake + websocket upgrade) -- distinct from `available?`,
      # which only confirms the gem itself is installed/loadable. The one
      # case this tells apart: gem installed, but iTerm2's own
      # Preferences > General > Magic > Enable Python API toggle is off.
      def python_api_reachable?
        return false unless available?
        with_timeout(5, default: false) { connect { true } }
      rescue StandardError
        false
      end

      # Create a new iTerm2 tab, cd into `dir` (defaults to the caller's cwd),
      # then run `command` in it (e.g. the `claude` or `codex` CLI). A new
      # iTerm2 tab starts in the user's home directory, not the caller's --
      # without the cd, the agent launches at ~ instead of the project it was
      # invoked from. Returns the new tab's primary session_id, or nil if
      # unavailable or the RPC failed.
      def open_worker_tab(command, dir: Dir.pwd)
        return nil unless available?
        with_timeout(8, default: nil) do
          connect do |c|
            # In the caller's own window when we can find it -- the window
            # the user is already sitting in is by definition the size they
            # chose, so that path leaves the frame untouched apart from
            # growing it up to the worker minimum (and the calling PANE is
            # untouched either way, which is the actual product promise).
            # Only the fallback path -- a genuinely new window -- gets an
            # explicit wide frame via set_window_frame, since a brand new
            # iTerm2 window otherwise opens at the profile's default size
            # (UAT found that unusably small twice over).
            window_id = calling_window_id(c)
            result = window_id ? c.create_tab(window_id: window_id) : c.create_tab
            session_id = result && result[:session_id]
            if session_id
              window_id ? ensure_min_worker_frame(c, window_id) : apply_window_frame(c, result[:window_id], "SW_WORKER_FRAME", WORKER_FRAME_DEFAULTS)
              c.send_text(session_id, "cd #{Shellwords.escape(dir)} && #{command}\n")
            end
            session_id
          end
        end
      rescue StandardError
        nil
      end

      # --- Driver adapter -------------------------------------------------
      # The surface adapter above puts a canvas beside a terminal; these two
      # put text *into* one specific terminal. StreamWeaver University's
      # runner uses them to send a step's prompt to the worker session
      # `get-started` recorded, and only that one -- see
      # lib/stream_weaver/university/runner.rb.

      # Types `text` into exactly `session_id`, then presses Return unless
      # `submit: false`. Never falls back to the calling session: a
      # mistargeted send drops a prompt into whatever pane the user happens
      # to be looking at, which is the failure this whole path exists to
      # prevent.
      #
      # Return is a carriage return, not a line feed -- that is what a
      # terminal actually sends when a human presses the key, and a raw-mode
      # TUI (the `claude` / `codex` CLIs) does not read an LF as submit.
      #
      # It also goes in a write of its OWN. UAT 2026-08-31: with the CR
      # appended to the same write, the prompt appeared in the claude pane
      # and just sat there -- the TUI read the whole write as pasted text,
      # so the CR became a character in the composer rather than a keypress.
      # A real Return is a separate event, so we send a separate one.
      #
      # UAT 2026-09-03 (round 3): a separate CR write still did not submit.
      # The text write is therefore wrapped in bracketed paste markers, so
      # the TUI knows exactly where the pasted block ends -- without them it
      # keeps treating the following bytes as more of the same paste, and
      # the CR is swallowed as paste content rather than read as Return.
      # Only the text is bracketed; the CR must arrive OUTSIDE the block or
      # the whole exercise is moot.
      #
      # Owning the keystroke here is what lets callers hand over prompt text
      # and nothing terminal-shaped; a later herdr/cmux driver makes the
      # same promise its own way.
      def send_to_session(session_id, text, submit: true)
        return false unless available? && session_id

        with_timeout(8, default: false) do
          connect do |c|
            next false unless c.send_text(session_id, bracketed_paste(text))
            next true unless submit
            next false unless c.send_text(session_id, "\r")

            # A successful submit is exactly the moment the worker's tab and
            # window should come to front -- Forrest's UAT wants Run to feel
            # like handing control to the agent, not typing into a pane he
            # has to go find. Only a full send (text landed AND Return
            # landed) gets here; a refused, degraded, or half-sent attempt
            # returns false above and never raises anything.
            activate_session_quietly(c, session_id)
            true
          end
        end
      rescue StandardError
        false
      end

      # True only when `session_id` is still in iTerm2's live topology --
      # the check that distinguishes "the worker tab is there" from "the
      # user closed it an hour ago". False on any doubt (gem missing, API
      # unreachable, RPC error), so callers degrade rather than guess.
      def session_alive?(session_id)
        return false unless available? && session_id

        with_timeout(5, default: false) do
          connect { |c| c.topology.any? { |s| s[:session_id] == session_id } }
        end
      rescue StandardError
        false
      end

      private

      APP_NAME = "StreamWeaver"

      # `text` as one bracketed-paste block. A terminal that has not enabled
      # the mode drops the markers on the floor, so this is safe to apply
      # unconditionally rather than sniffing what is running in the pane.
      def bracketed_paste(text) = "#{PASTE_START}#{text}#{PASTE_END}"

      # The browser pane for `url`, or nil. The real client raises on a
      # failed split (and returns nil only for an OK response with no
      # session), so both spellings of failure are caught here rather than
      # unwinding past the shell cleanup above.
      def browser_pane_in(client, shell, url)
        client.split_pane(
          shell,
          vertical: true,
          profile_name: BROWSER_PROFILE,
          profile_customizations: { "Initial URL" => url }
        )
      rescue StandardError
        nil
      end

      def close_quietly(client, session_id)
        client.close_session(session_id, force: true)
      rescue StandardError
        nil
      end

      # Sets window_id's frame to defaults, overridden by an "x,y,width,height"
      # value in ENV[env_var] when present and parseable. Silently a no-op on
      # an iterm2_ruby too old to have set_window_frame (one stderr hint,
      # printed once) -- callers don't need to know which gem version is
      # installed.
      def apply_window_frame(client, window_id, env_var, defaults)
        return unless window_id

        unless client.respond_to?(:set_window_frame)
          warn_frame_unsupported_once
          return
        end

        frame = parse_frame_env(ENV[env_var], defaults)
        client.set_window_frame(window_id, **frame)
      rescue StandardError
        nil
      end

      def parse_frame_env(raw, defaults)
        return defaults if raw.to_s.empty?

        parts = raw.split(",").map(&:strip)
        return defaults unless parts.size == 4

        x, y, width, height = parts.map { |p| Integer(p, exception: false) }
        return defaults if [x, y, width, height].any?(&:nil?)

        { x: x, y: y, width: width, height: height }
      end

      def warn_frame_unsupported_once
        return if @frame_hint_shown
        @frame_hint_shown = true
        warn "StreamWeaver: window sizing needs iterm2_ruby >= 0.3.0 (gem install iterm2_ruby)"
      end

      # Grows window_id up to the worker minimum (WORKER_FRAME_DEFAULTS,
      # overridable via SW_WORKER_FRAME) when the caller's own window --
      # reused rather than created by open_worker_tab -- is smaller than
      # that on either axis. Keeps the window's current x,y: this is a
      # floor, not a reposition. Never shrinks a window already at or above
      # the minimum, and never touches set_window_frame at all in that
      # case. Degrades silently on an older iterm2_ruby that lacks
      # get_window_frame.
      def ensure_min_worker_frame(client, window_id)
        return unless client.respond_to?(:get_window_frame)

        current = client.get_window_frame(window_id)
        return unless current && current[:width] && current[:height]

        minimum = parse_frame_env(ENV["SW_WORKER_FRAME"], WORKER_FRAME_DEFAULTS)
        return if current[:width] >= minimum[:width] && current[:height] >= minimum[:height]

        client.set_window_frame(
          window_id,
          x: current[:x],
          y: current[:y],
          width: [current[:width], minimum[:width]].max,
          height: [current[:height], minimum[:height]].max
        )
      rescue StandardError
        nil
      end

      # Best-effort: brings the worker's tab and window to the front after a
      # step prompt actually goes out, so Run feels like handing control to
      # the agent rather than something the user has to go find. Degrades
      # silently (one memoized stderr hint) on an older iterm2_ruby that
      # lacks activate_session -- never raises past this, since a raise
      # failing is not a reason to report the send itself as failed.
      def activate_session_quietly(client, session_id)
        unless client.respond_to?(:activate_session)
          warn_activate_unsupported_once
          return
        end

        client.activate_session(session_id)
      rescue StandardError
        nil
      end

      def warn_activate_unsupported_once
        return if @activate_hint_shown
        @activate_hint_shown = true
        warn "StreamWeaver: raise-on-run needs iterm2_ruby >= 0.3.1"
      end

      # The window holding the session this process is running in, or nil if
      # it can't be determined (not in iTerm2, or the lookup failed). Callers
      # treat nil as "open a new window".
      def calling_window_id(client)
        guid = current_session_guid or return nil
        client.topology.find { |s| s[:session_id] == guid }&.dig(:window_id)
      rescue StandardError
        nil
      end

      def check_availability
        return false unless RbConfig::CONFIG["host_os"].match?(/darwin/)
        # Fast check: ITERM_SESSION_ID is set when running inside iTerm2.
        # Avoids the slow ITerm2.connect call (which spawns a Python subprocess
        # and can hang for seconds when the Python API is slow to initialize).
        return false unless ENV['ITERM_SESSION_ID']

        require "iterm2"
        true
      rescue LoadError
        false
      end

      def connect(&) = ITerm2.connect(app_name: APP_NAME, &)

      def split_browser_pane(url, horizontal: false, target_session: nil)
        guid = target_session || current_session_guid or return nil
        with_timeout(8, default: nil) do
          connect do |c|
            c.split_pane(
              guid,
              vertical: !horizontal,
              profile_name: BROWSER_PROFILE,
              profile_customizations: { "Initial URL" => url }
            )
          end
        end
      rescue ITerm2::Error
        nil
      end

      def with_timeout(seconds, default: nil)
        Timeout.timeout(seconds) { yield }
      rescue Timeout::Error
        default
      end
    end
  end
end
