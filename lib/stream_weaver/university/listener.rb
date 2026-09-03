# frozen_string_literal: true

require 'fileutils'
require 'rbconfig'
require 'stream_weaver/canvas/client'
require 'stream_weaver/university/progress'
require 'stream_weaver/university/runner'

module StreamWeaver
  module University
    # Turns one canvas click event into a ledger write plus a re-push.
    # Mark-done writes the ledger directly; Run/Repeat hands off to
    # Runner, which sends the step's prompt to the recorded worker session
    # (or records why it wouldn't) and leaves the outcome in the ledger for
    # the re-push to render.
    #
    # Button ids come from lib/stream_weaver/university/canvas.rb's `id:`
    # scheme: "mark-done-N", "run-N" / "repeat-N", "hero-run-N" /
    # "hero-repeat-N" on the course list; "view-N" (a row's Details button),
    # "back-to-list" (the step screen's "All steps"), and "next-N" (the step
    # screen's "Next: step N") navigate between the app's two screens;
    # "reset-course" (the recap screen and the course-list footer) clears
    # the whole course. The rendered `id:` (e.g. "mark-done-3") becomes a
    # `btn_<label-slug>_<id>` DOM/dispatch id (app.rb `button`), so every
    # pattern below is anchored to the string's end, not its start.
    module Listener
      SESSION = 'university'

      # How long run! waits before reconnecting to a bridge that went away.
      RECONNECT_DELAY = 1

      # Canvas sessions the course steps themselves open (step 1's `hello`,
      # step 3's `form-demo`, step 4's `doc-demo` -- the exact names the
      # course prompts in course.rb tell the worker to use). "Reset course"
      # closes exactly these, by name, and nothing else: never the
      # controller session (SESSION, above) and never a session the user
      # opened on their own that just happens to still exist.
      DEMO_SESSION_NAMES = %w[hello form-demo doc-demo].freeze

      # Applies one dispatched button token to the ledger. Returns the step
      # number acted on, true for a navigation/whole-course action with no
      # step of its own (back-to-list, reset-course), or nil if the token
      # didn't match a known action.
      def self.handle_token(token, progress)
        case token.to_s
        when /mark-done-(\d+)\z/
          step = Regexp.last_match(1).to_i
          # progress.mark_done! stamps `last_done`, which the re-push below
          # renders as an inline confirmation band -- but only on the
          # course list (canvas.rb has no such band on the step screen).
          # clear_view! is what makes that true regardless of which of the
          # two Mark-done buttons was clicked (the course-list row's, or
          # the step screen's own): both land back on the list, where the
          # updated rail AND the confirmation are both visible. This is
          # also what canvas.rb's step-screen footer comment already
          # claims happens -- it just didn't, before this.
          progress.mark_done!(step)
          progress.clear_view!
          step
        when /(?:run|repeat)-(\d+)\z/ # also catches hero-run-N / hero-repeat-N
          step = Regexp.last_match(1).to_i
          # Dispatches to the worker session and records the outcome
          # (including the refusals) in the ledger; the re-push in `step!`
          # then renders whatever it wrote.
          Runner.run_step!(step, progress: progress)
          step
        when /view-(\d+)\z/, /next-(\d+)\z/
          step = Regexp.last_match(1).to_i
          progress.view_step!(step)
          step
        when /back-to-list\z/
          progress.clear_view!
          true
        when /reset-course\z/
          # Same effect as `streamweaver university-reset -y`: back up +
          # clear the ledger, close the demo sessions the course itself
          # opened. The trailing repush in `handle_event` below is what
          # then renders the zero-state list -- this branch does not push.
          progress.reset!
          close_demo_sessions!
          true
        end
      end

      # Applies one event to the ledger and re-pushes the app so the
      # rendered page reflects the new state. The re-push is not optional
      # bookkeeping: a click swaps the page for the canvas_continue spinner
      # (see canvas.rb), and this push is what puts the real page back --
      # and, for Mark-done specifically, is what makes the row visibly flip
      # to done AND shows the "Step N done" confirmation, both read
      # straight off the ledger this same push just wrote.
      # Returns the button token handled, or nil if the event carried none.
      def self.handle_event(event, session_name: SESSION)
        token = event.dig(:data, :button)
        return nil unless token

        handle_token(token, Progress.load)
        repush(session_name: session_name)
        token
      end

      # "Reset course": closes DEMO_SESSION_NAMES, one `close` message each.
      # Best-effort per session -- a session that was never opened (most
      # courses never get all three names created) or an already-closed
      # one just gets "Session not found" back, which is not a reason to
      # skip the rest. Shared by the canvas's own Reset button
      # (`handle_token`, above) and `streamweaver university-reset`.
      def self.close_demo_sessions!
        DEMO_SESSION_NAMES.each do |name|
          ::StreamWeaver::Canvas::Client.send_message(
            ::StreamWeaver::Canvas::Protocol::Messages.close(name)
          )
        rescue ::StreamWeaver::Canvas::Client::NotRunningError, ::StreamWeaver::Canvas::Client::ConnectionError
          nil
        end
      end

      def self.repush(session_name: SESSION)
        canvas_path = File.expand_path('canvas.rb', __dir__)
        ::StreamWeaver::Canvas::Client.send_message(
          ::StreamWeaver::Canvas::Protocol::Messages.push(session_name, File.read(canvas_path), source_dir: nil)
        )
      end

      # Blocks for exactly one canvas event, applies it, and re-pushes.
      # Returns the button token handled, or nil on timeout / no bridge.
      # Kept as the single-shot form for manual verification; `run!` uses
      # the persistent stream instead.
      def self.step!(session_name: SESSION, timeout: 300)
        result = ::StreamWeaver::Canvas::Client.send_and_wait(
          { type: 'subscribe', name: session_name },
          event_type: 'event',
          timeout: timeout
        )
        return nil unless result

        handle_event(result, session_name: session_name)
      rescue ::StreamWeaver::Canvas::Client::NotRunningError, ::StreamWeaver::Canvas::Client::ConnectionError
        nil
      end

      # Runs until killed, over ONE held-open connection at a time. Not a
      # loop of `step!`: that reconnects after every event, and the gap
      # lands exactly where the user is most likely to click again -- while
      # the re-push is in flight.
      #
      # The outer loop is not optional robustness. `each_event` returns when
      # the bridge closes the socket, which a `canvas-restart` does
      # routinely; without reconnecting, the listener would exit and the
      # canvas would go permanently dead -- and worse than before this
      # story, because the canvas_continue marker means a click with no
      # re-push leaves "Working..." on screen forever and sets
      # _swFeedbackActive, which makes the adapter swallow every later
      # click. Same reason a not-yet-running bridge waits rather than
      # exiting: `university-listener start` must not report a pid for a
      # process that is already gone.
      def self.run!(session_name: SESSION)
        complained = false

        loop do
          begin
            ::StreamWeaver::Canvas::Client.each_event(session_name) do |event|
              handle_event(event, session_name: session_name)
            rescue StandardError => e
              # One bad click must not take down a listener nobody can see.
              warn "university-listener: #{e.class}: #{e.message}"
            end
            complained = false
          rescue StandardError => e
            # Deliberately every StandardError, not just the two bridge
            # errors: this process must not die anywhere the user can't see
            # it, and RECONNECT_DELAY below already rules out a hot spin, so
            # there is no failure here from which exiting beats retrying.
            #
            # Logged once per outage, not once per second: the log is
            # append-only with nothing rotating it, and a bridge left down
            # overnight would otherwise put ~86k lines in a file the user
            # doesn't know exists.
            unless complained
              warn "university-listener: waiting for the canvas bridge (#{e.class}: #{e.message})"
              complained = true
            end
          end

          sleep RECONNECT_DELAY
        end
      end

      # --- Process lifecycle ------------------------------------------------
      # `get-started` starts this in the background; without it every button
      # on the canvas does nothing at all (UAT 2026-08-29). The env
      # overrides mirror Progress/Runner so specs never touch the real files.

      def self.pid_path
        ENV['STREAMWEAVER_UNIVERSITY_LISTENER_PID'] ||
          File.expand_path('~/.streamweaver/university/listener.pid')
      end

      def self.log_path
        ENV['STREAMWEAVER_UNIVERSITY_LISTENER_LOG'] ||
          File.expand_path('~/.streamweaver/university/listener.log')
      end

      # The pid recorded by `start!`, or nil if there isn't a usable one.
      def self.recorded_pid
        pid = File.read(pid_path).to_i
        pid.positive? ? pid : nil
      rescue SystemCallError, IOError
        nil
      end

      def self.running?
        pid = recorded_pid or return false
        ours?(pid)
      end

      # Alive AND plausibly the listener we spawned. `start!` uses
      # `pgroup: true`, so our listener is its own process-group leader;
      # a pid recycled onto some unrelated process almost never is. Without
      # this check, a crash plus enough pid churn has `get-started` sending
      # TERM to whatever the user happens to be running.
      def self.ours?(pid)
        Process.kill(0, pid)
        Process.getpgid(pid) == pid
      rescue Errno::ESRCH, Errno::EPERM
        false
      end
      private_class_method :ours?

      # How long start! waits for the listener it just TERMed to actually go.
      EXIT_POLL = 0.05
      EXIT_WAIT = 40 # * EXIT_POLL = 2s

      # Stops any listener already recorded, waits for it to actually exit,
      # then spawns a fresh detached one. Stopping first is what keeps a
      # second `get-started` (or a canvas-restart) from leaving two
      # listeners racing to re-push -- whichever push lands second wins, so
      # the loser shows stale state. Returns the new pid.
      def self.start!(session_name: SESSION)
        previous = recorded_pid
        stop!
        await_exit(previous)

        FileUtils.mkdir_p(File.dirname(log_path))
        FileUtils.mkdir_p(File.dirname(pid_path))

        pid = Process.spawn(
          RbConfig.ruby,
          "-I#{File.expand_path('../..', __dir__)}",
          '-r', 'stream_weaver/university/listener',
          '-e', "StreamWeaver::University::Listener.run!(session_name: #{session_name.inspect})",
          out: [log_path, 'a'], err: %i[child out], pgroup: true
        )
        Process.detach(pid)
        File.write(pid_path, "#{pid}\n")
        pid
      end

      # TERM is asynchronous, so "stopped" is a request, not a fact. Spawning
      # the replacement while the old one still holds its connection gives
      # two listeners racing to re-push, and whichever push lands second
      # wins -- so the canvas can settle on state the user did not ask for.
      def self.await_exit(pid)
        return unless pid

        EXIT_WAIT.times do
          return unless ours?(pid)

          sleep EXIT_POLL
        end

        # Falling through here is the very race this method exists to
        # prevent, so escalate rather than spawn a rival quietly.
        warn "university-listener: pid #{pid} ignored TERM, sending KILL"
        Process.kill('KILL', pid)
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end
      private_class_method :await_exit

      # Terminates the recorded listener. Always clears the pid file, even
      # when the process was already gone -- a stale pid file left by a
      # crash must not look like a running listener forever.
      def self.stop!
        pid = recorded_pid
        return false unless pid && ours?(pid)

        Process.kill('TERM', pid)
        true
      rescue Errno::ESRCH, Errno::EPERM
        false
      ensure
        FileUtils.rm_f(pid_path)
      end

      def self.status
        alive = running?
        { running: alive, pid: alive ? recorded_pid : nil, log: log_path }
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  $LOAD_PATH.unshift(File.expand_path('../..', __dir__))
  require 'stream_weaver'
  StreamWeaver::University::Listener.run!
end
