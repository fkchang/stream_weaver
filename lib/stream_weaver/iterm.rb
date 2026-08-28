# frozen_string_literal: true

require 'timeout'

module StreamWeaver
  # iTerm2 integration for panel workflow via the optional iterm2_ruby gem
  # (`gem install iterm2_ruby` — https://rubygems.org/gems/iterm2_ruby).
  # Falls back to system browser when iTerm2 API is unavailable.
  class ITerm
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

      # Split the calling iTerm2 pane and open a browser pane with the URL.
      # Returns Hash with :type (:browser, :external, or nil) and :pane_id
      def split_vertical_with_url(url, open_browser: true, horizontal: false)
        return { type: nil, pane_id: nil } unless available?

        pane_id = split_browser_pane(url, horizontal: horizontal)

        if pane_id
          { type: :browser, pane_id: pane_id }
        elsif open_browser
          system("open", url)
          { type: :external, pane_id: nil }
        else
          { type: nil, pane_id: nil }
        end
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

      # Create a new iTerm2 tab and run `command` in it (e.g. the `claude` or
      # `codex` CLI). Returns the new tab's primary session_id, or nil if
      # unavailable or the RPC failed.
      def open_worker_tab(command)
        return nil unless available?
        with_timeout(8, default: nil) do
          connect do |c|
            result = c.create_tab
            session_id = result && result[:session_id]
            c.send_text(session_id, "#{command}\n") if session_id
            session_id
          end
        end
      rescue StandardError
        nil
      end

      private

      APP_NAME = "StreamWeaver"

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

      def split_browser_pane(url, horizontal: false)
        guid = current_session_guid or return nil
        with_timeout(8, default: nil) do
          connect do |c|
            c.split_pane(
              guid,
              vertical: !horizontal,
              profile_name: "Web Browser",
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
