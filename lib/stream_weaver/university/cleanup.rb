# frozen_string_literal: true

require 'fileutils'
require 'stream_weaver/university/artifacts'
require 'stream_weaver/university/progress'
require 'stream_weaver/university/scripts/growing_doc_state'

module StreamWeaver
  module University
    # The ONE implementation of "delete something the course created".
    # `streamweaver university-cleanup` and the completion recap's own
    # delete buttons both come through here -- two surfaces, one deletion
    # path, so a rule proven about one is true of the other.
    #
    # Every delete is allowlisted, and the allowlist is not a list this
    # module keeps: it is whatever `Artifacts` currently records, plus two
    # deterministic knowns this module owns outright (the course's own state
    # files, by exact basename; the demo canvas sessions `university-reset`
    # already closes by name). A ref that is in neither raises `Refused` and
    # nothing happens -- a stale button, or a caller passing a path it made
    # up, both land in the same place.
    #
    # Being precise about how far that goes, because safety code that
    # over-promises is worse than safety code that doesn't: for `session`
    # and `gist` there is a SECOND guard here (the demo-session allowlist,
    # the gist-URL parse), so a hand-edited manifest cannot reach past them.
    # For `doc` and `org` there is no second guard -- any path the manifest
    # records is deleted. The strict door for those two is `Artifacts`
    # itself, which stores them expanded and only ever records a path
    # something actually produced, so keep it that way.
    #
    # Nothing here prompts. Confirmation belongs to the surface (the CLI's
    # per-group y/N and per-gist y/N; the canvas's confirm re-push), because
    # the two surfaces confirm in completely different ways and only one of
    # them has a tty.
    module Cleanup
      # Raised when a ref is not something this course is allowed to delete.
      # Deliberately an exception rather than a false return: a refusal is a
      # bug or an attack, never a routine outcome to fall through.
      Refused = Class.new(StandardError)

      # What one delete attempt did. `ok` is false for a real failure (gh
      # missing, gh errored); a file or session that was already gone is
      # `ok` -- the end state the caller asked for is the end state it got.
      Outcome = Struct.new(:ok, :message, keyword_init: true)

      # State files the course itself writes, by exact basename. An
      # allowlist, not a glob: this directory is under the user's home and a
      # `Dir[dir/*]` sweep would delete whatever else ever lands there.
      # `*_state.yml` is growing_doc's per-session sidecar, whose session
      # half is itself allowlisted (GrowingDocState.path).
      STATE_BASENAMES = %w[
        progress.yml progress.yml.bak worker.json listener.pid listener.log
      ].freeze

      # Where those files live: whatever directory the progress ledger is
      # in, so a redirected STREAMWEAVER_UNIVERSITY_PROGRESS redirects this
      # too -- a spec (or a second isolated University) must never be able
      # to reach the developer's real state dir.
      def self.state_dir
        File.dirname(Progress.path)
      end

      # The state files that actually exist right now, absolute paths. This
      # is recomputed on every call and is the allowlist `delete_state_file!`
      # checks against.
      def self.state_files
        dir = state_dir
        return [] unless File.directory?(dir)

        # The manifest's and the growing-doc sidecars' names come from the
        # modules that actually write them, not from a literal here, so a
        # renamed file can't leave cleanup deleting a name nothing uses.
        # Filtered back to `dir` afterwards: those two honor env overrides
        # of their own, and a partially-overridden environment (a spec that
        # redirects the ledger but not the doc state) must not let this
        # reach out of the directory it was scoped to.
        names = STATE_BASENAMES + [File.basename(Artifacts.path)]
        paths = names.map { |n| File.join(dir, n) } +
                Artifacts.demo_session_names.map { |n| Scripts::GrowingDocState.path(n) }
        paths.select { |p| File.dirname(p) == dir && File.file?(p) }.uniq
      end

      # The state files' own pseudo-type in `inventory`. Not one of
      # Artifacts::TYPES -- these are never recorded, they are the
      # deterministic known this module owns -- but they are a group the
      # surfaces confirm exactly like the others, so they are keyed the
      # same way.
      STATE = 'state'

      # Everything cleanup can offer to remove, keyed by artifact type (plus
      # STATE), every group always present so an empty one is `[]` rather
      # than missing. Keyed by TYPES rather than by names of its own so a
      # caller cannot pair the wrong group with the wrong type -- an earlier
      # shape had `:docs`/`:orgs` symbols that the CLI hand-paired with
      # `'doc'`/`'org'`, and nothing but a later refusal would have caught a
      # swap. File groups carry size and whether the file is still there.
      # Reading this deletes nothing.
      def self.inventory
        grouped = Artifacts.grouped
        inv = Artifacts::TYPES.each_with_object({}) do |type, out|
          entries = grouped[type].to_a
          out[type] = if %w[doc org].include?(type)
                        file_entries(entries)
                      else
                        entries.map { |e| { ref: e['ref'], step: e['step'] } }
                      end
        end
        inv[STATE] = state_files.map { |p| { ref: p, exists: true, size: File.size(p) } }
        inv
      end

      # True when there is nothing left for cleanup to do.
      def self.empty?(inv = inventory)
        inv.values.all?(&:empty?)
      end

      # Deletes one manifest entry, by type and ref. The refusal check reads
      # the manifest FRESH rather than trusting whatever the caller was
      # holding: a button rendered against an older push, or a ref handed in
      # by a caller that never looked, both get checked against what is
      # actually recorded now.
      def self.delete_entry!(type, ref)
        type = type.to_s
        ref = ref.to_s
        unless Artifacts.all.any? { |e| e['type'] == type && e['ref'] == ref }
          raise Refused, "refusing to delete #{ref.inspect}: not in the University artifact manifest"
        end

        outcome =
          case type
          when 'doc', 'org' then delete_file!(ref)
          when 'gist' then delete_gist!(ref)
          when 'session' then close_session!(ref)
          else raise Refused, "refusing to delete #{ref.inspect}: unknown artifact type #{type.inspect}"
          end

        Artifacts.forget!(type, ref) if outcome.ok
        outcome
      end

      # Deletes a list of refs of one type, reporting a refusal as its own
      # not-ok outcome rather than raising through the caller. This is where
      # BOTH surfaces come in -- the CLI's group confirm and the canvas's
      # confirmed pending delete -- so "what a refusal does to the rest of
      # the batch" has one answer: the refused ref is reported, the others
      # still go. `delete_entry!` keeps raising, because a single delete
      # with no batch around it has nowhere to put a report.
      def self.delete_refs!(type, refs)
        Array(refs).map do |ref|
          begin
            delete_entry!(type, ref)
          rescue Refused => e
            Outcome.new(ok: false, message: e.message)
          end
        end
      end

      # Every entry of one type -- what a CLI group confirm acts on.
      def self.delete_type!(type)
        delete_refs!(type, Artifacts.grouped[type.to_s].to_a.map { |e| e['ref'] })
      end

      # Deletes the course's own state files. Never touches the manifest's
      # entries -- those are separate groups with their own confirmations --
      # though artifacts.yml itself is one of these files, so a run that
      # confirms this group last removes the record along with the rest.
      def self.delete_state_files!
        state_files.map { |p| delete_state_file!(p) }
      end

      # A single state file. Same shape of guard as delete_entry!: the
      # allowlist is recomputed here, so a path that is not one of the
      # course's own state files right now is refused no matter who passed
      # it in.
      def self.delete_state_file!(file_path)
        unless state_files.include?(file_path.to_s)
          raise Refused, "refusing to delete #{file_path.inspect}: not a University state file"
        end

        FileUtils.rm_f(file_path)
        Outcome.new(ok: true, message: "removed #{file_path}")
      end

      # Whether gist deletion is even possible on this machine. When it
      # isn't, `delete_gist!` reports the URL and leaves the manifest entry
      # alone rather than pretending the gist is gone.
      def self.gh_available?
        ENV['PATH'].to_s.split(File::PATH_SEPARATOR).any? do |dir|
          gh = File.join(dir, 'gh')
          File.file?(gh) && File.executable?(gh)
        end
      end

      def self.delete_file!(file_path)
        return Outcome.new(ok: true, message: "already gone: #{file_path}") unless File.exist?(file_path)

        FileUtils.rm_f(file_path)
        Outcome.new(ok: true, message: "deleted #{file_path}")
      end
      private_class_method :delete_file!

      # `gh gist delete <id> --yes`. The id is the last path segment of the
      # URL, which is what `gh` wants; anything that doesn't look like a
      # gist URL is refused rather than shelled out with.
      def self.delete_gist!(url)
        # Artifacts.gist_id, not a second pattern of this module's own: the
        # door that records a gist and the door that deletes one have to
        # agree on what a gist URL is, or a ref loose enough to record is
        # too vague to ever delete.
        id = Artifacts.gist_id(url) or
          raise Refused, "refusing to delete #{url.inspect}: not a gist URL"

        unless gh_available?
          return Outcome.new(ok: false, message: "gh is not installed -- delete this one yourself: #{url}")
        end

        if system('gh', 'gist', 'delete', id, '--yes', out: File::NULL, err: File::NULL)
          Outcome.new(ok: true, message: "deleted gist #{url}")
        else
          # A gist deleted on github.com (or by GitHub's own abuse
          # detection) fails here exactly like a permissions problem does,
          # and neither is worth failing the whole run over.
          Outcome.new(ok: false, message: "gh could not delete #{url} (already gone, or not yours)")
        end
      end
      private_class_method :delete_gist!

      # Closing a demo session IS the delete for that type. Guarded a second
      # time against the same allowlist the manifest was guarded by on the
      # way in -- a hand-edited artifacts.yml must not be able to name the
      # controller session, or one of the user's own.
      def self.close_session!(name)
        unless Artifacts.demo_session_names.include?(name.to_s)
          raise Refused, "refusing to close #{name.inspect}: not a course demo session"
        end

        require 'stream_weaver/canvas/client'
        ::StreamWeaver::Canvas::Client.send_message(
          ::StreamWeaver::Canvas::Protocol::Messages.close(name)
        )
        Outcome.new(ok: true, message: "closed canvas session '#{name}'")
      rescue ::StreamWeaver::Canvas::Client::NotRunningError,
             ::StreamWeaver::Canvas::Client::ConnectionError
        # No bridge means no session to close: the end state is the one the
        # caller wanted, so the entry goes away with it.
        Outcome.new(ok: true, message: "canvas bridge not running -- '#{name}' is already closed")
      end
      private_class_method :close_session!

      def self.file_entries(entries)
        entries.to_a.map do |e|
          exists = File.exist?(e['ref'])
          { ref: e['ref'], step: e['step'], exists: exists, size: exists ? File.size(e['ref']) : nil }
        end
      end
      private_class_method :file_entries
    end
  end
end
