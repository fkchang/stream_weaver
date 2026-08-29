# frozen_string_literal: true

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
        when /(?:run|repeat)-(\d+)\z/ # also catches hero-run-N / hero-repeat-N
          step = Regexp.last_match(1).to_i
          # Dispatches to the worker session and records the outcome
          # (including the refusals) in the ledger; the re-push in `step!`
          # then renders whatever it wrote.
          Runner.run_step!(step, progress: progress)
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
