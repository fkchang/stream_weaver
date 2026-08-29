# frozen_string_literal: true

require 'json'
require 'stream_weaver/iterm'
require 'stream_weaver/university/course'
require 'stream_weaver/university/progress'

module StreamWeaver
  module University
    # The driver: turns "the user clicked Run on step N" into "step N's
    # prompt is now typed into the worker session, and nowhere else".
    #
    # The one hard rule is the target. `streamweaver get-started` recorded
    # exactly which iTerm2 session runs the agent (worker.json's
    # `session_id`, written by CLI.write_get_started_worker_json); this
    # sends there or it does not send at all. It never falls back to the
    # current/front session -- a mistargeted send drops a course prompt
    # into whatever the user was actually doing, which is worse than not
    # running the step. Every refusal keeps the prompt on the Result so the
    # canvas can offer it with a copy button instead.
    #
    # The iTerm2 mechanics live in StreamWeaver::ITerm's driver adapter
    # (`session_alive?` / `send_to_session`), next to the surface adapter;
    # swapping in herdr or cmux later means another adapter pair, not
    # changes here (see features/university-getting-started.context.md).
    module Runner
      DEFAULT_PATH = '~/.streamweaver/university/worker.json'

      # The one worker.json path, for the reader here AND the writer in
      # CLI.write_get_started_worker_json. STREAMWEAVER_UNIVERSITY_WORKER
      # overrides it, mirroring Progress's STREAMWEAVER_UNIVERSITY_PROGRESS
      # -- and, as there, both ends must honor the override or a spec that
      # exercises the premier path clobbers the developer's real recorded
      # worker session. Expanded per call, not at the constant, so a spec
      # that redirects HOME is redirected here too.
      def self.worker_path
        ENV['STREAMWEAVER_UNIVERSITY_WORKER'] || File.expand_path(DEFAULT_PATH)
      end

      # The recorded worker as a plain Hash, or nil when there isn't one
      # (degraded/browser path) or the file is missing/unreadable. A
      # malformed worker.json degrades exactly like a missing one: show the
      # prompt, let the user paste it.
      def self.worker
        parsed = JSON.parse(File.read(worker_path))
        parsed if parsed.is_a?(Hash) && parsed['session_id']
      rescue JSON::ParserError, SystemCallError, IOError
        nil
      end

      # What happened, in a shape both the ledger and the canvas can read.
      # :status is one of :sent, :session_missing, :send_failed,
      # :no_worker, :unknown_step.
      Result = Struct.new(:status, :step, :prompt, :session_id, :message, keyword_init: true)

      MESSAGES = {
        sent: 'Sent step %<step>d to the worker pane.',
        unknown_step: 'Step %<step>d is not part of this course.',
        session_missing: 'Worker session not found -- run `streamweaver get-started` again, ' \
                         'or copy the prompt below and paste it into your agent.',
        send_failed: 'Could not reach the worker session -- copy the prompt below and ' \
                     'paste it into your agent.',
        no_worker: 'No worker session recorded -- copy the prompt below and paste it into ' \
                   'the terminal where your agent is running.'
      }.freeze

      # The one wording for an outcome, so the canvas reporting a run and
      # the driver that performed it can never drift apart. Unknown
      # statuses read as the degraded case -- the safe thing to tell
      # someone is "copy this and paste it yourself".
      def self.message_for(status, step_number)
        template = MESSAGES[status.to_s.to_sym] || MESSAGES[:no_worker]
        format(template, step: step_number.to_i)
      end

      # Whether an outcome means the prompt actually went out. The canvas
      # asks this rather than comparing status strings itself, so the
      # vocabulary stays in one place alongside MESSAGES.
      def self.sent?(status)
        status.to_s == 'sent'
      end

      # Sends step `step_number`'s prompt to the recorded worker session.
      # Records the outcome in the ledger (`requested_at` only on a real
      # send) so the next canvas render can report it. Returns a Result;
      # never raises for an absent/closed worker.
      def self.run_step!(step_number, progress: Progress.load)
        prompt = Course.prompt_for(step_number)
        # Recorded like any other outcome: a click on a step the course no
        # longer has must supersede the previous notice, not leave it
        # pinned and attributed to a different step.
        return finish(:unknown_step, step_number, nil, nil, progress: progress) unless prompt

        recorded = worker
        return finish(:no_worker, step_number, prompt, nil, progress: progress) unless recorded

        session_id = recorded['session_id']
        return finish(:session_missing, step_number, prompt, session_id, progress: progress) unless
          ITerm.session_alive?(session_id)

        status = ITerm.send_to_session(session_id, one_line(prompt)) ? :sent : :send_failed
        finish(status, step_number, prompt, session_id, progress: progress)
      end

      # The course prompts are multi-line heredocs, which read well on the
      # canvas and are wrong on the wire: typed at an agent TUI, every
      # embedded newline is a keystroke, so the prompt either submits one
      # broken fragment per line or never submits at all. They are prose,
      # so collapsing the line breaks costs nothing and makes the send one
      # unambiguous line followed by one Return (pressed by the adapter).
      def self.one_line(prompt)
        prompt.gsub(/\s*\n\s*/, ' ').strip
      end

      def self.finish(status, step_number, prompt, session_id, progress:)
        progress.record_run!(step_number, status: status)
        Result.new(
          status: status,
          step: step_number.to_i,
          prompt: prompt,
          session_id: session_id,
          message: message_for(status, step_number)
        )
      end
      private_class_method :finish
    end
  end
end
