# frozen_string_literal: true

require 'fileutils'

module StreamWeaver
  module Canvas
    # Tier 1 (off-repo) history of canvas-push DSL snapshots.
    #
    # Snapshots live at <root>/<session>/<YYYYMMDD_HHMMSS>.rb where <root> is
    # ENV['STREAMWEAVER_HISTORY_ROOT'] || ~/.streamweaver/history. The env-var
    # override exists so specs (and ad-hoc tooling) can redirect writes away
    # from the user's real home directory.
    #
    # Session names are validated against an allowlist (alnum + . _ -, must
    # start with alnum) and an explicit '..'-substring check. Bad names raise
    # ArgumentError -- raising rather than sanitizing keeps the contract
    # explicit and avoids silently storing under an unexpected directory.
    module History
      MAX_AGE_DAYS    = 7
      MAX_AGE_SECONDS = MAX_AGE_DAYS * 86_400
      DEFAULT_ROOT    = File.expand_path('~/.streamweaver/history')
      VALID_NAME      = /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/

      module_function

      def root
        env = ENV['STREAMWEAVER_HISTORY_ROOT']
        return env if env && !env.empty?

        DEFAULT_ROOT
      end

      # Writes dsl to <root>/<session>/<timestamp>.rb and returns the path.
      # Appends a numeric suffix on collision so back-to-back writes within
      # the same second don't clobber each other. Paths are claimed atomically
      # (File::EXCL), so concurrent callers get distinct files instead of
      # racing between an exist? check and the write.
      def record(session, dsl)
        validate_session!(session)
        dir = File.join(root, session)
        FileUtils.mkdir_p(dir)

        stamp = Time.now.strftime('%Y%m%d_%H%M%S')
        write_unique(dir, stamp, dsl)
      end

      # Deletes snapshot files older than MAX_AGE_DAYS and prunes any
      # session directory left empty afterwards. No-op if root is missing.
      def cleanup
        base = root
        return unless Dir.exist?(base)

        cutoff = Time.now - MAX_AGE_SECONDS

        Dir.children(base).each do |session|
          session_dir = File.join(base, session)
          next unless File.directory?(session_dir)

          Dir.glob(File.join(session_dir, '*.rb')).each do |file|
            File.delete(file) if File.mtime(file) < cutoff
          end

          Dir.rmdir(session_dir) if Dir.children(session_dir).empty?
        end
      end

      def validate_session!(session)
        return if session.is_a?(String) && session.match?(VALID_NAME) && !session.include?('..')

        raise ArgumentError, "invalid session name: #{session.inspect}"
      end
      private_class_method :validate_session!

      def write_unique(dir, stamp, dsl)
        suffix = nil
        loop do
          name = suffix ? "#{stamp}_#{suffix}.rb" : "#{stamp}.rb"
          path = File.join(dir, name)
          begin
            File.open(path, File::WRONLY | File::CREAT | File::EXCL) { |f| f.write(dsl) }
            return path
          rescue Errno::EEXIST
            suffix = (suffix || 0) + 1
          end
        end
      end
      private_class_method :write_unique
    end
  end
end
