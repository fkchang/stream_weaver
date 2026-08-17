# frozen_string_literal: true

require 'fileutils'
require 'stream_weaver/canvas/doc_store'

module StreamWeaver
  module Canvas
    # Finds every docs root on this machine that canvas-read should show,
    # and gives each one a display label (stream_weaver-iugu).
    #
    # Two sources, unioned, because neither alone is sufficient:
    #
    # - **Scan** of `$STREAMWEAVER_DOCS_SCAN_ROOTS` (default `~/work`), one
    #   level deep for `*/docs/streamweaver_canvas`. Catches repos under a
    #   known parent automatically -- including ones that arrived via `git
    #   pull` and were never saved to or visited on this machine, which is
    #   exactly what a registry alone would miss.
    # - **Registry** at `~/.streamweaver/docs_roots.log`: one absolute docs
    #   root per line, append-only. Catches repos that live somewhere the
    #   scan doesn't reach (`~/rails/...`, `~/src/...`), which is exactly
    #   what a scan alone would miss. Written by DocStore.save and by
    #   `canvas-read <explicit path>` -- visiting a pre-existing doc once is
    #   what backfills it, so there is no separate registration command.
    #
    # Deliberately NOT a database: a flat newline-delimited file of absolute
    # paths needs no schema, no locking (a sub-PIPE_BUF append on a local
    # filesystem is atomic), no corruption recovery, and can be fixed with a
    # text editor. Everything is filtered through File.directory? on read, so
    # a repo that is deleted or moved simply drops off -- self-healing, no
    # `forget` operation to build or remember to call.
    #
    # No cache/TTL on the scan: it is a single-digit-millisecond glob at real
    # repo counts, and staleness in a tool whose whole job is "show me what's
    # on disk right now" is worse than the work it would save.
    module DocRoots
      DEFAULT_REGISTRY_PATH = File.expand_path('~/.streamweaver/docs_roots.log')

      # Colon-separated, like PATH. `~/work` is the default because that's
      # where the overwhelming majority of repos live; anything else is what
      # the registry half is for.
      DEFAULT_SCAN_ROOTS = '~/work'

      # The label for DocStore::DEFAULT_ROOT. Not a repo, so it gets a name
      # rather than a basename ('canvas' would be meaningless in the rail).
      GLOBAL_LABEL = 'Global'

      module_function

      # Read fresh on every call (not memoized into a constant) so an ENV
      # override flips behavior mid-process -- same contract DocStore.path
      # has, and what keeps specs from writing to the real registry.
      def registry_path
        env = ENV['STREAMWEAVER_DOCS_REGISTRY']
        env && !env.empty? ? File.expand_path(env) : DEFAULT_REGISTRY_PATH
      end

      # An explicitly empty STREAMWEAVER_DOCS_SCAN_ROOTS means "scan nothing"
      # (registry only), which is distinct from unset meaning "scan ~/work".
      def scan_roots
        raw = ENV['STREAMWEAVER_DOCS_SCAN_ROOTS'] || DEFAULT_SCAN_ROOTS
        raw.split(File::PATH_SEPARATOR).reject { |p| p.strip.empty? }.map { |p| File.expand_path(p.strip) }
      end

      # Symlink-resolved path, used only as a dedupe/comparison KEY -- never
      # for display. macOS's /tmp -> /private/tmp is the everyday case: the
      # same directory reached two ways must not become two sidebar groups.
      # Falls back to expand_path for a path that no longer resolves.
      def canonical(path)
        File.realpath(path)
      rescue SystemCallError
        File.expand_path(path)
      end

      # Appends `root` to the registry. Returns the recorded absolute path,
      # or nil if there was nothing to record or the write failed.
      #
      # Skips the append when the exact line is already present: duplicates
      # are harmless (reads dedupe), but re-saving the same doc a thousand
      # times shouldn't grow the file a thousand lines. The check is a read
      # of a few hundred bytes, and a lost race just writes a duplicate --
      # which is, again, harmless.
      #
      # Swallows filesystem errors on purpose: failing to record a root
      # degrades discovery, and must never take down the save that triggered
      # it.
      def record(root)
        return nil unless root.is_a?(String) && !root.empty?

        path = File.expand_path(root)
        return path if raw_entries.include?(path)

        FileUtils.mkdir_p(File.dirname(registry_path))
        File.open(registry_path, 'a') { |f| f.write("#{path}\n") }
        path
      rescue SystemCallError
        nil
      end

      # Records `dir` only when nothing already discovers it -- the
      # `canvas-read <explicit path>` backfill. A path the scan already
      # finds needs no registry entry.
      def record_if_new(dir)
        return nil unless dir && File.directory?(dir)

        key = canonical(dir)
        return nil if roots.any? { |r| canonical(r) == key }

        record(dir)
      end

      # Registry contents that still exist, deduped, in file order.
      def registered
        raw_entries.uniq.select { |p| File.directory?(p) }
      end

      # `*/docs/streamweaver_canvas` under each scan root, one level deep.
      def scanned
        scan_roots.flat_map { |r| Dir.glob(File.join(r, '*', DocStore::DOCS_SUBPATH)) }
                  .select { |p| File.directory?(p) }
                  .sort
      end

      # Every docs root to show, deduped by canonical path and ordered
      # host-repo first, then scanned, then registered, then global.
      #
      # DocStore.path leads deliberately: it is the repo the reader was
      # launched from, it is what the default sidebar filter selects, and it
      # may be reachable by neither other source (a repo outside the scan
      # roots that has been cloned but never saved to on this machine, or a
      # STREAMWEAVER_DOC_ROOT override).
      #
      # Keyed by canonical path, NOT by basename: two repos named `docs` in
      # different parents are two roots, and a basename-keyed hash would
      # silently drop one of them. Basename is a display label only -- see
      # #labels, which disambiguates collisions instead of discarding them.
      #
      # A discovered root that currently holds no `*.{rb,org}` is dropped:
      # File.directory? alone answers "does this place exist," not "is there
      # anything here to show," and a root that once had docs and no longer
      # does (a `git pull` that removed them, deleting the last one from the
      # reader -- stream_weaver-uvaj) is a sidebar heading that discloses
      # nothing. The two roots the host process owns are exempt and always
      # listed while they exist as directories: DocStore.path is the repo the
      # reader was launched from and the target of its own Save-as-doc, and
      # DocStore::DEFAULT_ROOT is the global fallback store -- both need to
      # stay wired up (mtime-watched by the reader's FileList) so the FIRST
      # doc saved into an empty one shows up without a restart.
      def roots
        always     = [DocStore.path, DocStore::DEFAULT_ROOT].compact.map { |p| File.expand_path(p) }
        candidates = [DocStore.path, *scanned, *registered, DocStore::DEFAULT_ROOT]
        seen = {}
        candidates.each do |candidate|
          next if candidate.nil? || candidate.to_s.empty?

          expanded = File.expand_path(candidate)
          next unless File.directory?(expanded)
          next unless always.include?(expanded) || docs?(expanded)

          seen[canonical(expanded)] ||= expanded
        end
        seen.values
      end

      # True when `root` directly contains at least one doc file. Same
      # '*.{rb,org}' glob FileList.build uses to populate the sidebar, so
      # "root is listed" and "root produces a group" can't disagree.
      def docs?(root)
        Dir.glob(File.join(root, '*.{rb,org}')).any?
      end

      # {root => label} for `roots_list`, insertion-ordered. Labels are
      # unique across the hash, since a label is what `?repo=` addresses --
      # two groups sharing one label would be unfilterable.
      def labels(roots_list = roots)
        used = {}
        roots_list.each_with_object({}) do |root, out|
          out[root] = unique_label(root, used)
        end
      end

      # The repo directory a docs root belongs to -- the root with the
      # `docs/streamweaver_canvas` suffix removed. A root that doesn't carry
      # that suffix (a STREAMWEAVER_DOC_ROOT override, the global store) is
      # its own repo dir.
      def repo_dir(root)
        suffix = File::SEPARATOR + DocStore::DOCS_SUBPATH
        root.end_with?(suffix) ? root[0...-suffix.length] : root
      end

      def base_label(root)
        return GLOBAL_LABEL if canonical(root) == canonical(DocStore::DEFAULT_ROOT)

        File.basename(repo_dir(root))
      end

      # Disambiguates a colliding basename with its parent directory rather
      # than dropping the root -- `~/work/notes` and `~/src/notes` are two
      # real repos and both have to be reachable.
      def unique_label(root, used)
        base = base_label(root)
        return claim(base, used) unless used.key?(base)

        parent = File.basename(File.dirname(repo_dir(root)))
        candidate = "#{base} (#{parent})"
        n = 2
        while used.key?(candidate)
          candidate = "#{base} (#{parent} #{n})"
          n += 1
        end
        claim(candidate, used)
      end
      private_class_method :unique_label

      def claim(label, used)
        used[label] = true
        label
      end
      private_class_method :claim

      # Every non-blank line, expanded, without the directory filter --
      # `record`'s duplicate check needs to see entries that no longer
      # exist, or a deleted-and-recreated root would append forever.
      def raw_entries
        return [] unless File.file?(registry_path)

        File.readlines(registry_path, chomp: true).map(&:strip).reject(&:empty?).map { |p| File.expand_path(p) }
      rescue SystemCallError
        []
      end
      private_class_method :raw_entries
    end
  end
end
