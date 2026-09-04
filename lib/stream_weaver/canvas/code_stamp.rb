# frozen_string_literal: true

require_relative '../version'

module StreamWeaver
  module Canvas
    # Identity of the StreamWeaver code a process has loaded: stamped into the
    # bridge's pid file at boot, re-computed by every CLI invocation that talks
    # to the bridge, and compared by StalenessGuard.ensure_current!.
    #
    # A canvas bridge is long-lived and keeps its classes in memory, so a
    # `rake install` or `gem update` underneath it leaves it serving code the
    # caller no longer has -- pushed canvas source calls a method the running
    # bridge has never heard of and NameErrors (disc-171, hit three times
    # live). Version alone does not catch it: the trap fires hardest on a
    # same-version reinstall, which is why the mtime of the loaded
    # stream_weaver.rb is half the stamp.
    #
    # It deliberately fingerprints that one file rather than walking lib/: any
    # install rewrites stream_weaver.rb along with everything else, so every
    # install is caught, while editing a file deeper in lib/ in a dev checkout
    # is not and still wants an explicit `canvas-restart`.
    module CodeStamp
      module_function

      def version
        StreamWeaver::VERSION
      end

      # The stream_weaver.rb above this file -- resolved from __dir__ rather
      # than $LOADED_FEATURES so a process that required only the canvas
      # subtree still fingerprints the library it is actually running.
      def library_path
        File.expand_path('../../stream_weaver.rb', __dir__)
      end

      def fingerprint
        fingerprint_for(library_path)
      end

      def fingerprint_for(path)
        return nil unless File.file?(path)

        "#{path}:#{File.mtime(path).to_i}"
      rescue SystemCallError
        nil
      end

      # Appended to the bridge's pid file; the existing pid=/port= lines are
      # parsed by regex, so extra lines are invisible to older readers.
      def pid_file_stanza
        "version=#{version}\ncode=#{fingerprint}\n"
      end

      def parse(content)
        { version: content[/^version=(.*)$/, 1], code: content[/^code=(.*)$/, 1] }
      end

      # True when the stamp read from a running bridge's pid file does not
      # describe the code THIS process loaded. No stamp at all means a bridge
      # started before this existed -- precisely the upgrade case, so it counts
      # as stale. Unknowable on our own side (no library file to stat) never
      # counts: a false positive restarts a developer's live bridge mid-session,
      # which is worse than the staleness it would be curing.
      def stale?(stamped)
        mine = fingerprint
        return false if mine.nil?

        stamped ||= {}
        stamped[:version] != version || stamped[:code] != mine
      end
    end
  end
end
