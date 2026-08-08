# frozen_string_literal: true

require 'fileutils'

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
    # explicit and avoids silently writing to an unexpected file. The .rb
    # extension is forced and idempotent: save("foo") and save("foo.rb") both
    # write to <path>/foo.rb. Extra dots within the name are allowed
    # (auth-flow.v2 -> auth-flow.v2.rb) since the allowlist already permits
    # '.' and descriptive multi-segment names are useful.
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
      def save(name, dsl)
        filename = normalize_name(name)
        dir = path
        FileUtils.mkdir_p(dir)

        full = File.join(dir, filename)
        File.write(full, stamp(dsl))
        full
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
        return "#{STAMP}\n" if text.empty?

        "#{STAMP}\n#{text}"
      end

      # Strips a single trailing .rb (case-sensitive), validates the resulting
      # basename against VALID_NAME with explicit '..' and null-byte rejection,
      # then re-adds .rb. Bare ".rb" normalizes to an empty basename and is
      # rejected.
      def normalize_name(name)
        raise ArgumentError, "invalid doc name: #{name.inspect}" unless name.is_a?(String)

        stripped = name.end_with?('.rb') ? name[0...-3] : name

        unless !stripped.empty? &&
               !stripped.include?('..') &&
               !stripped.include?("\0") &&
               stripped.match?(VALID_NAME)
          raise ArgumentError, "invalid doc name: #{name.inspect}"
        end

        "#{stripped}.rb"
      end
      private_class_method :normalize_name
    end
  end
end
