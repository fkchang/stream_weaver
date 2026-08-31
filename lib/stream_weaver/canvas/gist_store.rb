# frozen_string_literal: true

require 'json'
require 'time'
require 'fileutils'
require 'securerandom'

module StreamWeaver
  module Canvas
    # Persistent record of gists StreamWeaver has published on the user's
    # behalf, so a later session can find "the gist for this doc" without
    # keeping any in-memory session state.
    #
    # Unlike DocStore (one file per doc, resolved via a 3-tier git-aware
    # path), GistStore is a single flat JSON file holding every recorded
    # gist, keyed by doc base name. There is no git-root behavior here --
    # gist publication has no repo-relative meaning, so the path is just
    # ENV override or DEFAULT_PATH.
    #
    # This is an index, not a source of truth -- every entry in it can be
    # rebuilt by re-publishing. Two deliberate concessions follow from that:
    # a corrupt or empty file degrades to empty rather than raising
    # (raising would also break the calls you'd use to repair it), and two
    # processes recording at once is last-writer-wins -- the atomic write
    # below buys readers a whole file, not writers a serialized one.
    #
    # Resolved path priority:
    #   1. ENV['STREAMWEAVER_GIST_STORE']  (test/override hook)
    #   2. ~/.streamweaver/canvas/gists.json
    module GistStore
      DEFAULT_PATH = File.expand_path('~/.streamweaver/canvas/gists.json')

      module_function

      # Resolves the store file path. Read fresh on every call (not memoized)
      # so an ENV override flips behavior mid-process -- specs rely on this,
      # same rationale as DocStore#path.
      def path
        env = ENV['STREAMWEAVER_GIST_STORE']
        return env if env && !env.empty?

        DEFAULT_PATH
      end

      # Returns the full store: name => {"id" =>, "url" =>, "revisions" =>,
      # "created_at" =>, "updated_at" =>}. Empty hash for a missing, empty,
      # or corrupt file -- see the module comment for why this degrades
      # instead of raising.
      def all
        file = path
        return {} unless File.exist?(file)

        content = File.read(file)
        return {} if content.strip.empty?

        JSON.parse(content)
      rescue JSON::ParserError
        {}
      end

      # Returns the entry for `name`, or nil if it has never been recorded.
      def lookup(name)
        all[name.to_s]
      end

      # Upserts the entry for `name`: id/url/revisions are overwritten,
      # created_at is set once and preserved across later calls, updated_at
      # always advances to now. Returns the resulting entry hash.
      def record(name, id:, url:, revisions:)
        name = name.to_s
        store = all
        now = timestamp

        entry = {
          'id' => id,
          'url' => url,
          'revisions' => revisions,
          'created_at' => store.dig(name, 'created_at') || now,
          'updated_at' => now
        }
        store[name] = entry
        persist(store)
        entry
      end

      # Among recorded names starting with `prefix`, returns the entry with
      # the most recent updated_at -- how a caller with only a doc-name
      # prefix (e.g. a canvas session name) finds "the gist for this
      # session" with no session state of its own. nil if nothing matches.
      def latest_for_prefix(prefix)
        prefix = prefix.to_s
        match = all.select { |name, _| name.start_with?(prefix) }.max_by { |_, entry| entry['updated_at'] }
        match&.last
      end

      # Removes the entry for `name` if present. No-op if it was never
      # recorded.
      def forget(name)
        store = all
        persist(store) if store.delete(name.to_s)
      end

      # Millisecond precision, not the 1-second default: two gists published
      # within the same second are ordinary, and latest_for_prefix has to
      # break that tie correctly rather than by hash insertion order.
      def timestamp
        Time.now.utc.iso8601(3)
      end
      private_class_method :timestamp

      # Writes `store` to `path` atomically: JSON goes to a temp file in the
      # SAME directory (so the rename is on one filesystem, where POSIX
      # guarantees it is atomic) and is then renamed over the target. A plain
      # File.write truncates first, which would let a concurrent reader
      # observe an empty or half-written file; the temp file is removed if
      # the write or rename fails so a failure never leaves stray files
      # behind.
      def persist(store)
        file = path
        dir = File.dirname(file)
        FileUtils.mkdir_p(dir)

        tmp = File.join(dir, ".#{File.basename(file)}.#{Process.pid}.#{SecureRandom.hex(4)}.tmp")
        begin
          File.write(tmp, JSON.generate(store))
          File.rename(tmp, file)
        rescue StandardError
          FileUtils.rm_f(tmp)
          raise
        end
      end
      private_class_method :persist
    end
  end
end
