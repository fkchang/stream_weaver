# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
# Mutually required with doc_roots (which needs DOCS_SUBPATH/DEFAULT_ROOT for
# its scan and its global group). Safe in both load orders: Ruby marks a file
# as loaded before evaluating it, so the second require is a no-op, and
# neither file touches the other's constants at load time -- only inside
# method bodies.
require 'stream_weaver/canvas/doc_roots'

module StreamWeaver
  module Canvas
    # Tier 2 (persistent, in-repo) storage for canvas docs the user has
    # explicitly chosen to keep. Sibling of Canvas::History (Tier 1, ephemeral).
    #
    # Resolved path priority:
    #   1. ENV['STREAMWEAVER_DOC_ROOT']            (test/override hook)
    #   2. <git_root>/docs/streamweaver_canvas     (when invoked inside a repo)
    #   3. ~/.streamweaver/canvas                  (no-repo fallback)
    #
    # Git-root detection walks the filesystem looking for a .git entry on the
    # current working directory or any ancestor. We deliberately do NOT shell
    # out to `git`: filesystem walking is faster, has no PATH/install
    # dependency, and is easy to stub in specs. A .git that is either a
    # directory (normal repo) or a file (worktree/submodule pointer) counts
    # as a hit -- File.exist? covers both.
    #
    # Doc names are validated against an allowlist (alnum + . _ -, must start
    # with alnum) and an explicit '..'-substring + null-byte check. Bad names
    # raise ArgumentError -- raising rather than sanitizing keeps the contract
    # explicit and avoids silently writing to an unexpected file. The
    # extension is forced and idempotent: .rb and .org are both valid
    # (save("foo") and save("foo.rb") both write to <path>/foo.rb; likewise
    # for .org), defaulting to .rb when neither is present. Extra dots
    # within the name are allowed (auth-flow.v2 -> auth-flow.v2.rb) since
    # the allowlist already permits '.' and descriptive multi-segment names
    # are useful.
    #
    # No cleanup method: Tier 2 is permanent. Git is the cleanup mechanism.
    module DocStore
      DEFAULT_ROOT  = File.expand_path('~/.streamweaver/canvas')
      DOCS_SUBPATH  = File.join('docs', 'streamweaver_canvas')
      VALID_NAME    = /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/

      # Marks a file as a StreamWeaver doc body.
      #
      # A saved doc is a bare DSL body -- no require, no app wrapper -- so
      # nothing about the file announces what it is. Tooling that finds one out
      # of context (a renderer looking at a GitHub blob, an editor plugin, a
      # human) has no reliable way to tell it apart from ordinary Ruby.
      # Guessing from content does not work either: substantial docs use a dozen
      # distinct DSL calls, but a thin one may be almost entirely `md`.
      #
      # A comment costs nothing at eval time and travels with the file wherever
      # it goes, independent of path or extension.
      STAMP = '# streamweaver-doc: v1'

      # Recognizes the stamp anywhere in a leading comment block, so it still
      # matches if a magic comment (frozen_string_literal) or a title comment
      # sits above it. The version is captured but not pinned -- a v2 doc should
      # still be recognizable as a doc.
      STAMP_RE = /^#\s*streamweaver-doc:\s*v(\d+)\s*$/

      # How far into a file to look. Deep enough for a comment header, shallow
      # enough that a stray match in prose does not count.
      STAMP_SCAN_LINES = 10

      module_function

      # Resolves the docs directory. Read fresh on every call so an ENV
      # override flips behavior mid-process (specs rely on this).
      def path
        env = ENV['STREAMWEAVER_DOC_ROOT']
        return env if env && !env.empty?

        if (root = git_root)
          File.join(root, DOCS_SUBPATH)
        else
          DEFAULT_ROOT
        end
      end

      # Walks up from `start` looking for a .git entry. Returns the absolute
      # path of the directory that contains it, or nil at the filesystem
      # root. Treats .git as a hit whether it is a directory or a file
      # (worktree/submodule).
      def git_root(start = Dir.pwd)
        dir = File.expand_path(start)
        loop do
          return dir if File.exist?(File.join(dir, '.git'))

          parent = File.dirname(dir)
          return nil if parent == dir

          dir = parent
        end
      end

      # Writes `dsl` to <path>/<normalized_name>.rb and returns the absolute
      # path. Creates the docs directory if missing. Overwrites any existing
      # file with the same name (Tier 2 docs are user-managed; collisions
      # mean the user is intentionally updating).
      #
      # scope/source_dir (stream_weaver-j3b3): a caller with an explicit
      # destination in mind (the Save-as-doc toggle) passes both. `scope:
      # :global` always writes to DEFAULT_ROOT. `scope: :repo` (the default)
      # writes under `source_dir` when given; when `source_dir` is nil (no
      # caller preference, e.g. a caller with no repo context to offer) it
      # falls back to the existing auto-detected `path` -- unchanged
      # behavior for every pre-existing caller.
      #
      # Only .rb output gets the `# streamweaver-doc: v1` stamp -- .org output
      # already self-identifies via its own `#+STREAMWEAVER_DSL: 1` header
      # keyword (org-doc-format-design.md), which must be the file's first
      # line unconditionally. Prepending the .rb-style stamp in front of it
      # would violate that and, being a bare `#` line rather than a `#+`
      # keyword, wouldn't even be recognized by org-ruby.
      #
      # The write is atomic: content goes to a temp file in the SAME directory
      # (so the rename stays on one filesystem, where POSIX guarantees it is
      # atomic) and is then renamed over the target. A plain File.write
      # truncates first, so a concurrent reader -- canvas-read's docs scan on
      # every render, or another process's GET -- can observe an empty or
      # half-written file. The temp name is dotted and .tmp-suffixed so it
      # matches neither the *.rb nor the *.org globs even in the instant it
      # exists, and it is removed if the write or rename fails so a failure
      # never litters the docs directory.
      def save(name, dsl, scope: :repo, source_dir: nil)
        filename = normalize_name(name)
        dir = target_dir(scope, source_dir)
        FileUtils.mkdir_p(dir)

        full = File.join(dir, filename)
        content = filename.end_with?('.org') ? dsl : stamp(dsl)
        tmp = File.join(dir, ".#{filename}.#{Process.pid}.#{SecureRandom.hex(4)}.tmp")
        begin
          File.write(tmp, content)
          File.rename(tmp, full)
        rescue StandardError
          FileUtils.rm_f(tmp)
          raise
        end

        # Half of canvas-read's cross-repo discovery (stream_weaver-iugu):
        # saving into a repo is what makes that repo's docs findable from a
        # canvas-read launched anywhere else. Deliberately after the rename,
        # so a failed write never registers a root that has no docs in it.
        # DocRoots.record swallows its own filesystem errors -- a registry
        # that can't be written must never fail the save it followed.
        DocRoots.record(dir)

        full
      end

      # Prepends `use_theme`/`use_layout` declarations so a saved doc renders
      # with the theme/layout of the canvas session it came from
      # (stream_weaver-csf). Saved docs are re-rendered later by canvas-read,
      # which has no session to inherit from -- only the DSL text -- so the
      # metadata has to live in the text itself.
      #
      # Shared by BOTH save routes (BridgeServer's /canvas/:name/save-doc and
      # Reader's /save-doc) deliberately: duplicating the prepend logic would
      # let the two Save-as-doc buttons silently write different files.
      #
      # Idempotent: a DSL that already declares either directive keeps its own,
      # so re-saving never stacks duplicates. nil theme/layout are skipped --
      # that's the Reader's promote-from-history case, where the snapshot was
      # written by `canvas-push` (which never sees the bridge session's theme),
      # so those docs keep rendering with canvas-read's default.
      def dsl_with_metadata(dsl, theme: nil, layout: nil)
        lines = []
        lines << "use_theme :#{theme}"   if theme  && !dsl.match?(/^[ \t]*use_theme\b/)
        lines << "use_layout :#{layout}" if layout && !dsl.match?(/^[ \t]*use_layout\b/)
        return dsl if lines.empty?

        (lines + [dsl]).join("\n")
      end

      # True when `source` already declares itself a StreamWeaver doc.
      #
      # Only the first STAMP_SCAN_LINES are considered, so a doc that happens to
      # quote the stamp inside prose or a code_block further down is not
      # mistaken for a stamped file.
      def stamped?(source)
        return false unless source.is_a?(String)

        source.each_line.first(STAMP_SCAN_LINES).any? { |line| line.match?(STAMP_RE) }
      end

      # Returns `dsl` with the stamp on its first line, or unchanged if it is
      # already stamped.
      #
      # Idempotent on purpose: saving over an existing doc is the normal way to
      # update one, and the stamp must not accumulate. Prepending is safe even
      # when the body opens with `# frozen_string_literal: true` -- Ruby honors
      # a magic comment anywhere in the leading comment block, not only on line
      # one.
      def stamp(dsl)
        text = dsl.to_s
        return text if stamped?(text)
        # Defense in depth, not currently reachable: `save`'s own
        # filename.end_with?('.org') check is what actually protects org
        # content today (`stamp` has no other caller). Kept here too so a
        # future caller of `stamp` directly can't reintroduce the exact bug
        # c1df5f6 fixed -- the .rb-style stamp corrupting .org's hard
        # requirement that '#+STREAMWEAVER_DSL: 1' be the literal first line.
        return text if text.start_with?('#+')
        return "#{STAMP}\n" if text.empty?

        "#{STAMP}\n#{text}"
      end

      # Strips a single trailing .rb or .org (case-sensitive), validates the
      # resulting basename against VALID_NAME with explicit '..' and
      # null-byte rejection, then re-adds whichever extension was detected
      # (defaulting to .rb when neither is present). Bare ".rb"/".org"
      # normalize to an empty basename and are rejected.
      def normalize_name(name)
        raise ArgumentError, "invalid doc name: #{name.inspect}" unless name.is_a?(String)

        ext, stripped = if name.end_with?('.rb')
                          ['.rb', name[0...-3]]
                        elsif name.end_with?('.org')
                          ['.org', name[0...-4]]
                        else
                          ['.rb', name]
                        end

        unless !stripped.empty? &&
               !stripped.include?('..') &&
               !stripped.include?("\0") &&
               stripped.match?(VALID_NAME)
          raise ArgumentError, "invalid doc name: #{name.inspect}"
        end

        "#{stripped}#{ext}"
      end
      private_class_method :normalize_name

      # Resolves the destination directory for `save`'s scope/source_dir
      # arguments. See `save`'s comment for the semantics.
      def target_dir(scope, source_dir)
        return DEFAULT_ROOT if scope == :global
        return File.join(source_dir, DOCS_SUBPATH) if source_dir

        path
      end
      private_class_method :target_dir
    end
  end
end
