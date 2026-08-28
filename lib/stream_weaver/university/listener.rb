# frozen_string_literal: true

require 'stream_weaver/university/progress'

module StreamWeaver
  module University
    # Turns one canvas click event into a ledger write plus a re-push. This
    # is the manual/UAT driver for course-list-canvas + progress-ledger --
    # `driver-worker-runner` (the next story) replaces `handle_token`'s
    # run/repeat branch with an actual send-to-worker dispatch and is
    # expected to own the persistent run loop; `step!` below exists so this
    # story's wiring is real and testable without waiting on that story.
    #
    # Button ids come from lib/stream_weaver/university/canvas.rb's `id:`
    # scheme: "mark-done-N", "run-N" / "repeat-N", "hero-run-N" /
    # "hero-repeat-N". The rendered `id:` (e.g. "mark-done-3") becomes a
    # `btn_<label-slug>_<id>` DOM/dispatch id (app.rb `button`), so every
    # pattern below is anchored to the string's end, not its start.
    module Listener
      SESSION = 'university'

      # Applies one dispatched button token to the ledger. Returns the step
      # number acted on, or nil if the token didn't match a known action.
      def self.handle_token(token, progress)
        case token.to_s
        when /mark-done-(\d+)\z/
          step = Regexp.last_match(1).to_i
          progress.mark_done!(step)
          step
        when /(?:hero-run|hero-repeat|run|repeat)-(\d+)\z/
          step = Regexp.last_match(1).to_i
          progress.record_run_requested!(step)
          step
        end
      end

      # Blocks for exactly one canvas event (mirrors `canvas-wait`'s
      # subscribe/timeout shape), applies it, and re-pushes the app so the
      # rendered page reflects the ledger's new state. Returns the button
      # token handled, or nil on timeout / no session.
      def self.step!(session_name: SESSION, timeout: 300)
        require 'stream_weaver/canvas/client'

        result = Canvas::Client.send_and_wait(
          { type: 'subscribe', name: session_name },
          event_type: 'event',
          timeout: timeout
        )
        return nil unless result

        token = result.dig(:data, :button)
        progress = Progress.load
        handle_token(token, progress) if token

        canvas_path = File.expand_path('canvas.rb', __dir__)
        Canvas::Client.send_message(
          Canvas::Protocol::Messages.push(session_name, File.read(canvas_path), source_dir: nil)
        )
        token
      rescue Canvas::Client::NotRunningError, Canvas::Client::ConnectionError
        nil
      end

      # Runs until killed. Not started automatically by `get-started` --
      # see docs/university/design-spec.md and the progress-ledger UAT
      # handoff note for how to run this by hand during verification.
      def self.run!(session_name: SESSION)
        loop { step!(session_name: session_name) }
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  $LOAD_PATH.unshift(File.expand_path('../..', __dir__))
  require 'stream_weaver'
  StreamWeaver::University::Listener.run!
end
