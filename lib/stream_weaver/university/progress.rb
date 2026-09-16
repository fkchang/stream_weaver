# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'time'

module StreamWeaver
  module University
    # University's per-course, per-step completion ledger, persisted as YAML
    # at `~/.streamweaver/university/progress.yml`. Explicit course selections
    # are stored under their course IDs. The legacy top-level Getting Started
    # shape remains readable and is migrated without loss when another course
    # is first written. A plain file, not in-memory session state, so every
    # write survives a bridge restart.
    #
    # STREAMWEAVER_UNIVERSITY_PROGRESS overrides the path -- used by specs
    # (never touch the developer's real ledger) and by anyone running a
    # second, isolated University instance.
    class Progress
      DEFAULT_PATH = '~/.streamweaver/university/progress.yml'
      DEFAULT_COURSE_ID = 'getting-started'

      # Expanded per call, not at the constant, so a spec that redirects
      # HOME is redirected here too -- and so this mirrors
      # University::Runner.worker_path exactly, as its comment claims.
      def self.path
        ENV['STREAMWEAVER_UNIVERSITY_PROGRESS'] || File.expand_path(DEFAULT_PATH)
      end

      # Loads the ledger at the current path (honoring the env override at
      # call time, not at class-load time).
      def self.load(course_id: nil)
        new(path, course_id: course_id)
      end

      def initialize(path = self.class.path, course_id: nil)
        @path = path
        @course_id = course_id&.to_s
        loaded = read_file
        @data = data_for(loaded)
      end

      attr_reader :path, :course_id

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
        mutate do |data|
          data['done'][step_number.to_s] = true
          data['last_run'] = nil
          data['last_done'] = { 'step' => step_number.to_i, 'at' => Time.now.utc.iso8601 }
        end
        self
      end

      # Undoes a mark-done -- not exercised by the current UI, but the
      # natural inverse and cheap to keep correct for tests/future use.
      # Clears `last_run`/`last_done` for the same reason mark_done! sets
      # them: this instance no longer reflects what either field claims.
      def unmark_done!(step_number)
        mutate do |data|
          data['done'].delete(step_number.to_s)
          data['last_run'] = nil
          data['last_done'] = nil
        end
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
        mutate do |data|
          now = Time.now.utc.iso8601
          data['requested'][step_number.to_s] = now if status.to_s == 'sent'
          data['last_run'] = { 'step' => step_number.to_i, 'status' => status.to_s, 'at' => now }
          data['last_done'] = nil
        end
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

      # Which step's row is expanded inline on the course list, or nil if
      # none is. canvas-push instance_evals canvas.rb fresh on every render
      # (no in-memory app state survives between pushes -- see canvas.rb's
      # file header), so which row (if any) renders expanded has to live
      # somewhere that does survive: this ledger, same as done/last_run.
      # Also what makes a deep link work -- whoever set this before the
      # canvas was last (re)pushed gets that row auto-expanded on load,
      # with no separate navigation step to get there.
      #
      # Still the `'viewing'` key on disk -- deliberately not renamed to
      # `'expanded'` alongside this method (single-mode, 2026-09-03): only
      # the meaning of "which row" changed (a screen to navigate to versus
      # a row to expand in place), not what's being tracked, and a silent
      # key rename would orphan whatever any already-running canvas last
      # wrote. Renaming the key belongs to a real migration, not this diff.
      def expanded_step
        @data['viewing']
      end

      # Expands step `step_number`'s row inline on the next render --
      # "Details" on a step row. At most one step is ever expanded: this
      # simply overwrites whichever was expanded before, which is what
      # makes "expanding one collapses others" true by construction.
      def expand_step!(step_number)
        mutate { |data| data['viewing'] = step_number.to_i }
        self
      end

      # Collapses whichever row is expanded -- "Hide" on an expanded row's
      # own Details button, and what mark_done! calls so a Mark-done click
      # never leaves a stale expansion open under the confirmation band.
      def collapse!
        mutate { |data| data['viewing'] = nil }
        self
      end

      # "Reset course": backs up whatever was on disk to `<path>.bak`
      # (overwriting any earlier backup -- one reset's worth of undo, not a
      # history) and returns the selected course to the zero-state. A legacy
      # ledger is deleted exactly as before. A namespaced ledger keeps every
      # other course and is deleted only when no course state remains.
      def reset!
        with_lock do
          FileUtils.cp(@path, "#{@path}.bak") if File.exist?(@path)
          loaded = read_file
          if @course_id.nil? && !namespaced?(loaded)
            FileUtils.rm_f(@path)
          else
            document = namespaced_document(loaded)
            document['courses'].delete(selected_course_id)
            if document['courses'].empty?
              FileUtils.rm_f(@path)
            else
              write_document(document)
            end
          end
          @data = blank_data
        end
        self
      end

      private

      def read_file
        return {} unless File.exist?(@path)

        loaded = YAML.safe_load(File.read(@path)) || {}
        loaded.is_a?(Hash) ? loaded : {}
      rescue Psych::SyntaxError
        {}
      end

      def data_for(loaded)
        if namespaced?(loaded)
          normalize_data(loaded['courses'][selected_course_id])
        elsif @course_id.nil? || @course_id == DEFAULT_COURSE_ID
          normalize_data(loaded)
        else
          blank_data
        end
      end

      def normalize_data(loaded)
        loaded = {} unless loaded.is_a?(Hash)
        {
          'done' => loaded['done'] || {},
          'requested' => loaded['requested'] || {},
          'last_run' => loaded['last_run'],
          'last_done' => loaded['last_done'],
          'viewing' => loaded['viewing']
        }
      end

      def blank_data
        { 'done' => {}, 'requested' => {}, 'last_run' => nil, 'last_done' => nil, 'viewing' => nil }
      end

      # Every mutation reloads inside the ledger lock. This makes @data a
      # read cache, never the source for a write, so two instances created
      # from the same snapshot cannot overwrite one another's changes.
      def mutate
        with_lock do
          loaded = read_file
          data = data_for(loaded)
          yield data

          if @course_id.nil? && !namespaced?(loaded)
            write_document(data)
          else
            document = namespaced_document(loaded)
            document['courses'][selected_course_id] = data
            write_document(document)
          end

          @data = data
        end
      end

      def with_lock
        FileUtils.mkdir_p(File.dirname(@path))
        File.open("#{@path}.lock", File::RDWR | File::CREAT, 0o644) do |lock|
          lock.flock(File::LOCK_EX)
          yield
        end
      end

      def namespaced?(loaded)
        loaded.is_a?(Hash) && loaded['courses'].is_a?(Hash)
      end

      def namespaced_document(loaded)
        if namespaced?(loaded)
          courses = loaded['courses'].each_with_object({}) do |(id, data), normalized|
            normalized[id.to_s] = normalize_data(data)
          end
          { 'courses' => courses }
        else
          courses = {}
          courses[DEFAULT_COURSE_ID] = normalize_data(loaded) if legacy_data?(loaded)
          { 'courses' => courses }
        end
      end

      def legacy_data?(loaded)
        loaded.is_a?(Hash) && %w[done requested last_run last_done viewing].any? { |key| loaded.key?(key) }
      end

      def selected_course_id
        @course_id || DEFAULT_COURSE_ID
      end

      def write_document(document)
        FileUtils.mkdir_p(File.dirname(@path))
        temporary_path = "#{@path}.tmp.#{$$}.#{Thread.current.object_id}"
        File.open(temporary_path, 'w') do |file|
          file.write(YAML.dump(document))
          file.flush
          file.fsync
        end
        File.rename(temporary_path, @path)
      ensure
        FileUtils.rm_f(temporary_path) if temporary_path
      end
    end
  end
end
