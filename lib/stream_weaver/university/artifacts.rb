# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'time'

module StreamWeaver
  module University
    # The course's own record of what it left behind: every doc it saved,
    # every org file exported from one, every gist published, every demo
    # canvas session it opened. Persisted as YAML at
    # `~/.streamweaver/university/artifacts.yml`, same shape and same
    # env-override convention as Progress's own ledger.
    #
    # Invisible by design: nothing asks the user to maintain it. The pieces
    # that create artifacts record them as they go (growing_doc's save,
    # Listener.warm_up!'s session create), and the one thing a worker has to
    # record by hand -- a gist URL, which only it ever sees -- has a CLI door
    # (`streamweaver university-artifact add`) named in step 5's own prompt.
    #
    # It exists for exactly one consumer: cleanup. `University::Cleanup` will
    # delete a thing only if this manifest currently lists it (or it is one
    # of the deterministic knowns Cleanup owns outright), so the manifest is
    # the allowlist, not merely an inventory. That is why `record!` is
    # additive and deduped, `forget!` is called only after a delete actually
    # lands, and nothing here ever deletes a file itself.
    module Artifacts
      DEFAULT_PATH = '~/.streamweaver/university/artifacts.yml'

      # doc  -- a StreamWeaver DSL file saved out of a canvas (`.rb`)
      # org  -- its `streamweaver org-export` sibling (`.org`)
      # gist -- a published gist URL
      # session -- a course demo canvas session, by name
      TYPES = %w[doc org gist session].freeze

      # Human names for the types, in one place: both surfaces show these
      # (the CLI's inventory headings and "Kept: ..." lines, the canvas's
      # group headings and delete-button labels), and two copies would let
      # the same group be called two different things depending on where
      # the user was standing.
      LABELS = {
        'doc' => 'Saved docs',
        'org' => 'Exported .org files',
        'gist' => 'Gists',
        'session' => 'Course canvas sessions'
      }.freeze

      def self.label(type)
        LABELS.fetch(type.to_s, type.to_s)
      end

      # Expanded per call, not at the constant, so a spec that redirects
      # HOME is redirected here too -- same reasoning as Progress.path.
      def self.path
        ENV['STREAMWEAVER_UNIVERSITY_ARTIFACTS'] || File.expand_path(DEFAULT_PATH)
      end

      # Every recorded artifact, oldest first, as plain string-keyed hashes.
      def self.all
        read['entries'] || []
      end

      # Records one artifact. `type` is inferred from the ref when omitted
      # (see .infer_type). Deduped on [type, ref] -- re-running step 4 saves
      # over the same path, and one path is still one thing to delete.
      # Returns the entry, or nil when the type could not be determined
      # (callers surface that; a manifest entry with no type is one Cleanup
      # could never dispatch on).
      def self.record!(ref, type: nil, step: nil)
        ref = ref.to_s
        type = (type || infer_type(ref))&.to_s
        return nil unless TYPES.include?(type)

        # A file ref is stored absolute, always. The process that records
        # one (a worker's shell, the bridge) is not the process that later
        # deletes it, so a relative path would be resolved against a
        # different working directory than the one it meant -- and the
        # thing resolved would be deleted without anyone noticing the
        # difference. Refuse a gist ref that the deleter could not resolve
        # for the same reason: `Cleanup` shells `gh` with the id this
        # parses out, so a URL with no id in it is a manifest entry that
        # can only ever fail.
        ref = File.expand_path(ref) if %w[doc org].include?(type)
        return nil if type == 'gist' && gist_id(ref).nil?

        data = read
        entries = data['entries'] || []
        existing = entries.find { |e| e['type'] == type && e['ref'] == ref }
        return existing if existing

        entry = {
          'type' => type,
          'ref' => ref,
          'step' => step&.to_i,
          'created_at' => Time.now.utc.iso8601
        }
        write(data.merge('entries' => entries + [entry]))
        entry
      end

      # growing_doc's save path, plus the `.org` sibling `streamweaver
      # org-export` writes beside it when that has already happened (step 5
      # exports after the fact, so the sibling usually gets recorded by the
      # worker's own `university-artifact add` instead -- both doors, one
      # manifest).
      def self.record_doc!(doc_path, step: nil)
        return nil unless doc_path

        entry = record!(doc_path, type: 'doc', step: step)
        org = doc_path.to_s.sub(/\.rb\z/, '.org')
        record!(org, type: 'org', step: step) if org != doc_path.to_s && File.exist?(org)
        entry
      end

      # A course demo canvas session, by name. Guarded on the same allowlist
      # `university-reset` closes by (Listener::DEMO_SESSION_NAMES): a
      # session the course did not open is not the course's to record, and
      # therefore never becomes something cleanup is allowed to close.
      def self.record_session!(name, step: nil)
        return nil unless demo_session_names.include?(name.to_s)

        record!(name, type: 'session', step: step)
      end

      # Drops one entry -- called by Cleanup after a delete actually lands,
      # never speculatively. A no-op for an entry that isn't there.
      def self.forget!(type, ref)
        data = read
        entries = data['entries'] || []
        kept = entries.reject { |e| e['type'] == type.to_s && e['ref'] == ref.to_s }
        return false if kept.size == entries.size

        write(data.merge('entries' => kept))
        true
      end

      # { 'doc' => [entry, ...], ... } in TYPES order, empty groups omitted.
      def self.grouped
        by_type = all.group_by { |e| e['type'] }
        TYPES.each_with_object({}) do |type, out|
          out[type] = by_type[type] if by_type[type]&.any?
        end
      end

      # Everything recorded for one step, in record order -- what a step
      # row's "created:" line reads (display only; it deletes nothing).
      def self.for_step(step_number)
        all.select { |e| e['step'].to_i == step_number.to_i }
      end

      # The gist id `gh gist delete` wants, or nil if this is not a gist URL
      # this course could act on. Lives here, beside the recording door,
      # rather than in Cleanup: "is this a gist?" must have exactly ONE
      # definition, or a URL loose enough to record can be too vague to
      # delete -- a manifest entry that is permanently stuck. Cleanup calls
      # this again on the way out as its second guard.
      def self.gist_id(url)
        match = url.to_s.match(%r{\Ahttps?://gist\.github\.com/(?:[^/]+/)?([0-9a-f]{6,})/?\z}i)
        match && match[1]
      end

      # gist URL > .org path > .rb path > an allowlisted demo session name.
      # Deliberately narrow: an unrecognized ref returns nil and `record!`
      # refuses it rather than guessing a type Cleanup would later act on.
      def self.infer_type(ref)
        ref = ref.to_s
        return 'gist' if gist_id(ref)
        return 'org' if ref.end_with?('.org')
        return 'doc' if ref.end_with?('.rb')
        return 'session' if demo_session_names.include?(ref)

        nil
      end

      # The delete a canvas click has asked for but not yet confirmed:
      # { 'label' =>, 'kind' =>, 'refs' => [...] }, or nil.
      #
      # Lives here, in the artifacts file, rather than in Progress: it is
      # state about artifacts, and Progress is the course-completion ledger.
      # It has to live on disk at all for the same reason `viewing` does --
      # canvas.rb is instance_eval'd fresh on every push, so nothing about
      # what is currently on screen survives in memory between the click
      # that asks and the re-push that renders the confirmation.
      def self.pending_delete
        read['pending']
      end

      # Asking clears whatever the last delete reported: the recap shows one
      # thing at a time, and the question the user is being asked now
      # supersedes the answer to the last one.
      def self.request_delete!(label:, kind:, refs:)
        pending = { 'label' => label.to_s, 'kind' => kind.to_s, 'refs' => Array(refs).map(&:to_s) }
        write(read.merge('pending' => pending, 'last_cleanup' => nil))
        pending
      end

      def self.clear_pending!
        write(read.merge('pending' => nil))
      end

      # What the last confirmed delete actually did, as the lines Cleanup
      # reported -- rendered in the recap so a click on the canvas says
      # something, the same way a Run click's own notice band does. Cleared
      # by the next question (above).
      def self.last_cleanup
        read['last_cleanup']
      end

      def self.record_cleanup!(messages)
        write(read.merge('last_cleanup' => Array(messages).map(&:to_s), 'pending' => nil))
      end

      # Resolved lazily rather than by a top-level require: Listener records
      # sessions through this module, so requiring it from here at load time
      # would be a cycle. `require` is idempotent, so the cost is one hash
      # lookup after the first call.
      def self.demo_session_names
        require 'stream_weaver/university/listener'
        Listener::DEMO_SESSION_NAMES
      end

      def self.read
        return {} unless File.exist?(path)

        loaded = YAML.safe_load(File.read(path))
        loaded.is_a?(Hash) ? loaded : {}
      rescue Psych::SyntaxError, SystemCallError, IOError
        {}
      end
      private_class_method :read

      # Locked, because two live processes write this file: the background
      # listener records a session the moment a Run click warms one up,
      # while a foreground `university-cleanup` is forgetting entries it
      # just deleted. Both rewrite the whole document, so without the lock
      # the loser's change is dropped -- worst case a deleted artifact's
      # entry comes back, which is a confusing offer to delete it again
      # rather than a wrong deletion, but not something to leave to luck.
      def self.write(data)
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, File::RDWR | File::CREAT, 0o644) do |file|
          file.flock(File::LOCK_EX)
          file.truncate(0)
          file.write(YAML.dump(data))
        end
      end
      private_class_method :write
    end
  end
end
