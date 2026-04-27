# frozen_string_literal: true

require 'rack/session/abstract/id'
require 'fileutils'

module StreamWeaver
  # ── Session state filters ─────────────────────────────────────────────────
  # Each store type owns its filter logic. Cookie store guards the 4KB limit;
  # file store passes state through unchanged.

  module SessionStore
    class Base
      def filter(state, app_transient: [])
        raise NotImplementedError, "#{self.class}#filter not implemented"
      end

      private

      # Treat nil and empty string as blank — both are equivalent to "unset" for form fields.
      def blank?(v)
        v.nil? || v == ""
      end
    end

    class FileStore < Base
      # No size limit, but strip blank values — they'll be re-initialized by ||= on next load.
      def filter(state, app_transient: [])
        state.reject { |_, v| blank?(v) }
      end
    end

    class CookieStore < Base
      HARD_TRANSIENT = %i[code_content current_file_path examples _deck_state].freeze
      LIMIT_BYTES    = 4096
      WARN_THRESHOLD = 3072 # warn at 75% capacity

      def filter(state, app_transient: [])
        filtered = state.reject do |k, v|
          blank?(v) ||
            HARD_TRANSIENT.include?(k) ||
            app_transient.include?(k) ||
            k.to_s.end_with?('_edited_code')
        end
        size = JSON.dump(filtered).bytesize
        if size > WARN_THRESHOLD
          $stderr.puts "[SW] WARNING: cookie session #{size}B / #{LIMIT_BYTES}B limit — " \
                       "set SW_SESSION_STORE=file to avoid silent data loss"
        end
        filtered
      end
    end

    def self.build(store_name)
      case store_name.to_s
      when 'file'   then FileStore.new
      when 'cookie' then CookieStore.new
      else raise ArgumentError, "Unknown SW_SESSION_STORE '#{store_name}'. Use 'file' or 'cookie'."
      end
    end
  end

  # ── File-backed Rack session middleware ────────────────────────────────────
  # Stores one Marshal file per session under SW_SESSION_DIR.
  # Compatible with Rack::Session::Abstract::PersistedSecure (same interface as Pool).

  class FileSession < Rack::Session::Abstract::PersistedSecure
    DEFAULT_OPTIONS = Rack::Session::Abstract::ID::DEFAULT_OPTIONS.merge(
      drop:           false,
      allow_fallback: true,
      expire_after:   86_400
    )

    def initialize(app, options = {})
      @session_dir  = options.delete(:path) { ::File.join(Dir.home, '.config', 'stream_weaver', 'sessions') }
      @expire_after = options.fetch(:expire_after, DEFAULT_OPTIONS[:expire_after])
      @allow_fallback = options.fetch(:allow_fallback, DEFAULT_OPTIONS[:allow_fallback])
      @mutex = Mutex.new
      FileUtils.mkdir_p(@session_dir)
      super
    end

    def generate_sid(*args, use_mutex: true)
      loop do
        sid = super(*args)
        exists = use_mutex ? @mutex.synchronize { file_exists_for?(sid) } : file_exists_for?(sid)
        break sid unless exists
      end
    end

    def find_session(req, sid)
      @mutex.synchronize do
        session = sid && fetch_session_data(sid)
        unless session
          sid     = generate_sid(use_mutex: false)
          session = {}
          # Don't write here — let write_session handle it so we don't create orphan files
        end
        [sid, session]
      end
    end

    def write_session(req, session_id, new_session, options)
      @mutex.synchronize do
        write_file(session_id, new_session)
        session_id
      end
    rescue => e
      $stderr.puts "[SW] FileSession write error: #{e}"
      false
    end

    def delete_session(req, session_id, options)
      @mutex.synchronize do
        remove_file(session_id)
        unless options[:drop]
          sid = generate_sid(use_mutex: false)
          write_file(sid, {})
          sid
        end
      end
    end

    private

    def session_path(sid)
      id = sid.respond_to?(:private_id) ? sid.private_id : sid.to_s
      ::File.join(@session_dir, "session_#{id.gsub(/[^a-zA-Z0-9\-]/, '_')}")
    end

    def file_exists_for?(sid)
      ::File.exist?(session_path(sid))
    end

    # Renamed from load_session to avoid overriding Persisted#load_session(req)
    def fetch_session_data(sid)
      session = read_session_file(sid.private_id)
      session ||= read_session_file(sid.public_id) if @allow_fallback && sid.respond_to?(:public_id)
      session
    rescue => e
      $stderr.puts "[SW] FileSession load error: #{e}"
      nil
    end

    def read_session_file(raw_id)
      path = ::File.join(@session_dir, "session_#{raw_id.to_s.gsub(/[^a-zA-Z0-9\-]/, '_')}")
      return nil unless ::File.exist?(path)
      if ::File.mtime(path) < Time.now - @expire_after
        ::File.delete(path)
        return nil
      end
      Marshal.load(::File.binread(path))
    rescue => e
      $stderr.puts "[SW] FileSession read error for #{raw_id}: #{e}"
      nil
    end

    def write_file(sid, session)
      ::File.binwrite(session_path(sid), Marshal.dump(session))
    end

    def remove_file(sid)
      path = session_path(sid)
      ::File.delete(path) if ::File.exist?(path)
    end
  end
end
