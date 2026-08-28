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
      DEFAULT_PATH = File.expand_path('~/.streamweaver/university/progress.yml')

      def self.path
        ENV['STREAMWEAVER_UNIVERSITY_PROGRESS'] || DEFAULT_PATH
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

      def mark_done!(step_number)
        @data['done'][step_number.to_s] = true
        write
        self
      end

      # Undoes a mark-done -- not exercised by the current UI, but the
      # natural inverse and cheap to keep correct for tests/future use.
      def unmark_done!(step_number)
        @data['done'].delete(step_number.to_s)
        write
        self
      end

      def done_steps
        @data['done'].select { |_k, v| v }.keys.map(&:to_i).sort
      end

      def done_count
        done_steps.size
      end

      # The runner hook `driver-worker-runner` will replace with an actual
      # send-to-worker dispatch. For now it only records that a Run/Repeat
      # click happened, so the ledger (and any UAT of this story) has
      # something real to observe.
      def record_run_requested!(step_number)
        @data['requested'][step_number.to_s] = Time.now.utc.iso8601
        write
        self
      end

      def requested_at(step_number)
        @data['requested'][step_number.to_s]
      end

      private

      def read
        return blank_data unless File.exist?(@path)

        loaded = YAML.safe_load(File.read(@path)) || {}
        {
          'done' => loaded['done'] || {},
          'requested' => loaded['requested'] || {}
        }
      rescue Psych::SyntaxError
        blank_data
      end

      def blank_data
        { 'done' => {}, 'requested' => {} }
      end

      def write
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, YAML.dump(@data))
      end
    end
  end
end
