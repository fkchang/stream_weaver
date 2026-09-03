# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'time'

module StreamWeaver
  module University
    # Getting Started's per-step completion ledger, persisted as YAML at
    # `~/.streamweaver/university/progress.yml`. A plain file, not in-memory
    # session state, so "survives a bridge restart" just means every write
    # hits disk immediately and a later re-push re-reads it (progress-ledger
    # criterion 5).
    #
    # STREAMWEAVER_UNIVERSITY_PROGRESS overrides the path -- used by specs
    # (never touch the developer's real ledger) and by anyone running a
    # second, isolated University instance.
    class Progress
      DEFAULT_PATH = '~/.streamweaver/university/progress.yml'

      # Expanded per call, not at the constant, so a spec that redirects
      # HOME is redirected here too -- and so this mirrors
      # University::Runner.worker_path exactly, as its comment claims.
      def self.path
        ENV['STREAMWEAVER_UNIVERSITY_PROGRESS'] || File.expand_path(DEFAULT_PATH)
      end

      # Loads the ledger at the current path (honoring the env override at
      # call time, not at class-load time).
      def self.load
        new(path)
      end

      def initialize(path = self.class.path)
        @path = path
        @data = read
      end

      attr_reader :path

      def done?(step_number)
        !!@data['done'][step_number.to_s]
      end

      # Clears `last_run` along the way: that field reports what the user's
      # last click did, and marking a step done IS a later click. Without
      # this, a run notice (in degraded mode, a whole copy-this-prompt
      # block for step 1) stays pinned above the step list for days.
      #
      # Stamps `last_done` for the SAME reason `record_run!` stamps
      # `last_run`: the next canvas render needs to say what a click just
      # did, and it needs to say so reliably. An earlier version of this
      # feedback used a bridge toast instead -- broken by construction,
      # because the toast and this same write's re-push land in the same
      # ~500ms poll response, and the client unconditionally clears any
      # toast the instant new HTML arrives (bridge_server.rb's poll()).
      # Putting the message IN the re-pushed HTML has no such race.
      def mark_done!(step_number)
        @data['done'][step_number.to_s] = true
        @data['last_run'] = nil
        @data['last_done'] = { 'step' => step_number.to_i, 'at' => Time.now.utc.iso8601 }
        write
        self
      end

      # Undoes a mark-done -- not exercised by the current UI, but the
      # natural inverse and cheap to keep correct for tests/future use.
      # Clears `last_run`/`last_done` for the same reason mark_done! sets
      # them: this instance no longer reflects what either field claims.
      def unmark_done!(step_number)
        @data['done'].delete(step_number.to_s)
        @data['last_run'] = nil
        @data['last_done'] = nil
        write
        self
      end

      def done_steps
        @data['done'].select { |_k, v| v }.keys.map(&:to_i).sort
      end

      def done_count
        done_steps.size
      end

      # Records the outcome of one Run/Repeat click (Runner#run_step!).
      #
      # `requested` only gains a timestamp when the prompt actually reached
      # the worker session -- a click that found no worker, or a closed
      # tab, is not a send, and a `requested_at` for it would be a lie the
      # ledger tells forever. `last_run` always updates: it is what the
      # next canvas render reads to report what happened, including the
      # failures that need a copy-the-prompt fallback.
      def record_run!(step_number, status:)
        now = Time.now.utc.iso8601
        @data['requested'][step_number.to_s] = now if status.to_s == 'sent'
        @data['last_run'] = { 'step' => step_number.to_i, 'status' => status.to_s, 'at' => now }
        @data['last_done'] = nil
        write
        self
      end

      def requested_at(step_number)
        @data['requested'][step_number.to_s]
      end

      # The last Run/Repeat outcome: {'step' =>, 'status' =>, 'at' =>}, or
      # nil before the first click.
      def last_run
        @data['last_run']
      end

      # The step a Mark-done click just finished: {'step' =>, 'at' =>}, or
      # nil. Mutually exclusive with `last_run` -- each write clears the
      # other, so the canvas only ever has one "what just happened" band to
      # show, whichever action was more recent.
      def last_done
        @data['last_done']
      end

      # Which step's detail screen is showing, or nil for the course list.
      # canvas-push instance_evals canvas.rb fresh on every render (no
      # in-memory app state survives between pushes -- see canvas.rb's file
      # header), so which of the app's two screens to render has to live
      # somewhere that does survive: this ledger, same as done/last_run.
      def viewing_step
        @data['viewing']
      end

      # Opens step `step_number`'s detail screen on the next render --
      # "Details" on a step row, or "Next: step N" on the step screen's own
      # footer.
      def view_step!(step_number)
        @data['viewing'] = step_number.to_i
        write
        self
      end

      # Returns to the course list on the next render -- "All steps".
      def clear_view!
        @data['viewing'] = nil
        write
        self
      end

      # "Reset course": backs up whatever was on disk to `<path>.bak`
      # (overwriting any earlier backup -- one reset's worth of undo, not a
      # history) and returns to the zero-state. Deletes rather than
      # rewrites the file, so this in-memory instance and a freshly loaded
      # one agree the same way every other zero-state case already does
      # (`#read`, below, and the "does not create the file just by reading
      # it" contract) -- there is exactly one representation of "nothing
      # done yet", not two that both mean it.
      def reset!
        FileUtils.cp(@path, "#{@path}.bak") if File.exist?(@path)
        FileUtils.rm_f(@path)
        @data = blank_data
        self
      end

      private

      def read
        return blank_data unless File.exist?(@path)

        loaded = YAML.safe_load(File.read(@path)) || {}
        {
          'done' => loaded['done'] || {},
          'requested' => loaded['requested'] || {},
          'last_run' => loaded['last_run'],
          'last_done' => loaded['last_done'],
          'viewing' => loaded['viewing']
        }
      rescue Psych::SyntaxError
        blank_data
      end

      def blank_data
        { 'done' => {}, 'requested' => {}, 'last_run' => nil, 'last_done' => nil, 'viewing' => nil }
      end

      def write
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, YAML.dump(@data))
      end
    end
  end
end
