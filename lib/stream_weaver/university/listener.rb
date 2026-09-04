# frozen_string_literal: true

require 'fileutils'
require 'rbconfig'
require 'stream_weaver/canvas/client'
require 'stream_weaver/university/course'
require 'stream_weaver/university/progress'
require 'stream_weaver/university/runner'
require 'stream_weaver/university/scripts/growing_doc_state'

module StreamWeaver
  module University
    # Turns one canvas click event into a ledger write plus a re-push.
    # Mark-done writes the ledger directly; Run/Repeat hands off to
    # Runner, which sends the step's prompt to the recorded worker session
    # (or records why it wouldn't), warms up that step's own demo canvas
    # the moment (and only if) the send actually lands (see `.warm_up!`),
    # and leaves the outcome in the ledger for the re-push to render.
    #
    # Button ids come from lib/stream_weaver/university/canvas.rb's `id:`
    # scheme: "mark-done-N", "run-N" / "repeat-N", "hero-run-N" /
    # "hero-repeat-N" on the course list; "view-N" (a row's Details/Hide
    # button) toggles that row's inline expansion; "reset-course" (the
    # recap screen and the course-list footer) clears the whole course.
    # The rendered `id:` (e.g. "mark-done-3") becomes a
    # `btn_<label-slug>_<id>` DOM/dispatch id (app.rb `button`), so every
    # pattern below is anchored to the string's end, not its start.
    module Listener
      SESSION = 'university'

      # How long run! waits before reconnecting to a bridge that went away.
      RECONNECT_DELAY = 1

      # name/theme pair for one step's own demo canvas session.
      DemoSession = Struct.new(:name, :theme)

      # Which of the course's own canvas demo sessions each step opens, and
      # the theme its prompt creates that session with -- mined from
      # course.rb's step prompts, and named in
      # features/university-getting-started.context.md ("Course session
      # names"). The theme matters here specifically because
      # `Bridge#create_session` is `@sessions[name] ||= Session.new(...)`
      # (canvas/bridge.rb): a session's theme is fixed by whichever `create`
      # reaches the bridge FIRST, and every later `create` for that name --
      # including the worker's own, e.g. `streamweaver panel doc-demo
      # --theme=doc` (course.rb) or `growing_doc.rb`'s `create(...,
      # theme: :doc)` -- is a no-op. `warm_up!` runs before any of that, so
      # it has to create with the SAME theme the real demo will, not the
      # bridge's `:default`, or the worker's own theme call would silently
      # never take effect for the rest of that get-started run. Steps 2 and
      # 5 never open a demo canvas of their own (a standalone `ruby app.rb`,
      # and gists/org-export respectively), so neither appears here: a Run
      # click on either has nothing to warm up, and "Reset course" has
      # nothing of theirs to close.
      STEP_DEMO_SESSIONS = {
        1 => DemoSession.new('dashboard', :default),
        3 => DemoSession.new('decision', :default),
        4 => DemoSession.new('doc-demo', :doc)
      }.freeze

      # "Reset course" closes exactly these, by name, and nothing else:
      # never the controller session (SESSION, above) and never a session
      # the user opened on their own that just happens to still exist.
      # Derived from STEP_DEMO_SESSIONS so the two lists can never drift.
      DEMO_SESSION_NAMES = STEP_DEMO_SESSIONS.values.map(&:name).freeze

      # Applies one dispatched button token to the ledger. Returns the step
      # number acted on, true for a whole-course action with no step of its
      # own (reset-course), or nil if the token didn't match a known
      # action.
      def self.handle_token(token, progress)
        case token.to_s
        when /mark-done-(\d+)\z/
          step = Regexp.last_match(1).to_i
          # progress.mark_done! stamps `last_done`, which the re-push below
          # renders as an inline confirmation band. collapse! is what
          # closes that row's expansion regardless of which of the two
          # Mark-done buttons was clicked (the row's own, or its expanded
          # body's) -- a stale expansion left open under the confirmation
          # band would read as though nothing happened.
          progress.mark_done!(step)
          progress.collapse!
          step
        when /(?:run|repeat)-(\d+)\z/ # also catches hero-run-N / hero-repeat-N
          step = Regexp.last_match(1).to_i
          # Dispatches to the worker session and records the outcome
          # (including the refusals) in the ledger; the re-push in `step!`
          # then renders whatever it wrote. The block runs once, only after
          # Runner confirms the send actually landed -- warm_up! paints
          # something instantly (Forrest's UAT round 5 clocked the worker's
          # own first push at ~5 minutes) without ever promising "your
          # agent is preparing" on a click that turned out refused or
          # degraded (no recorded worker, a closed session, or the RPC
          # itself failing) -- Runner is the one place that already knows
          # which of those this click was.
          Runner.run_step!(step, progress: progress) { warm_up!(step) }
          step
        when /view-(\d+)\z/
          # Toggles: Details on the already-expanded row hides it again
          # (Hide), Details on any other row expands that one instead --
          # at most one row is ever expanded, so this is also what makes
          # "expanding one collapses others" true.
          step = Regexp.last_match(1).to_i
          if progress.expanded_step == step
            progress.collapse!
          else
            progress.expand_step!(step)
          end
          step
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
          begin
            ::StreamWeaver::Canvas::Client.send_message(
              ::StreamWeaver::Canvas::Protocol::Messages.close(name)
            )
          rescue ::StreamWeaver::Canvas::Client::NotRunningError, ::StreamWeaver::Canvas::Client::ConnectionError
            nil
          end
          # growing_doc.rb's own persisted --extend keys (round-7 UAT) --
          # otherwise a reset course still remembers last run's picks the
          # next time its script runs. A no-op (FileUtils.rm_f) for every
          # name but doc-demo's, which never had state to begin with.
          ::StreamWeaver::University::Scripts::GrowingDocState.clear(name)
        end
      end

      # Pushes a deterministic, no-LLM placeholder card to step `step_number`'s
      # own demo canvas session -- called by Runner.run_step!'s block, which
      # only runs once a send has actually landed, so the pane paints
      # something in well under a second instead of sitting empty for
      # however long the worker takes to reach its own first push
      # (Forrest's UAT round 5: ~5 minutes), and never on a refused or
      # degraded send. Creates the session first if it doesn't exist yet
      # (canvas `push` errors on a session it can't find), WITH the same
      # theme the step's own demo uses (STEP_DEMO_SESSIONS) -- a session's
      # theme is fixed by whichever `create` reaches the bridge first, so
      # creating with the wrong one here would permanently strand the
      # worker's own later `--theme=doc` as a no-op for the rest of this
      # get-started run. The worker's own first real push against the same
      # session name replaces this outright -- nothing here persists.
      # No-op for a step with no demo session of its own (steps 2 and 5).
      def self.warm_up!(step_number)
        demo = STEP_DEMO_SESSIONS[step_number.to_i] or return
        step = Course.step(step_number) or return

        ::StreamWeaver::Canvas::Client.send_message(
          ::StreamWeaver::Canvas::Protocol::Messages.create(demo.name, theme: demo.theme)
        )
        ::StreamWeaver::Canvas::Client.send_message(
          ::StreamWeaver::Canvas::Protocol::Messages.push(demo.name, warm_up_dsl(step), source_dir: nil)
        )
      rescue ::StreamWeaver::Canvas::Client::NotRunningError, ::StreamWeaver::Canvas::Client::ConnectionError
        nil
      end

      # The warm-up card's own DSL source, instance_eval'd bridge-side --
      # same "one string of Ruby, eval'd fresh" contract canvas.rb's own
      # file header describes. Deliberately small: a title, one line of
      # what's coming, a tasteful mini stat row plus a one-sentence
      # callout, and the "preparing" line -- everything a terminal-only
      # tool cannot show while a real worker is still thinking.
      def self.warm_up_dsl(step)
        <<~RUBY
          use_theme :doc
          use_layout :default
          card(depth: :elevated) do
            card_header { header2 #{step[:title].inspect} }
            card_body do
              phrase #{"Coming up: #{step[:payoff]}".inspect}
              div(style: "display:flex; gap:14px; margin:16px 0;") do
                stat_display value: #{step[:number].to_s.inspect}, label: "this step"
                stat_display value: #{StreamWeaver::University::Course::GETTING_STARTED_STEPS.size.to_s.inspect}, label: "steps in the course"
              end
              callout "Your agent is preparing the live demo…", variant: :info
            end
          end
        RUBY
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
