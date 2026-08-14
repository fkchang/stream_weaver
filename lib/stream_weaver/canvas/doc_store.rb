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
        File.write(full, dsl)
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
    end
  end
end
