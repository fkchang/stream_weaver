# frozen_string_literal: true

require 'json'
require 'time'
require 'fileutils'
require_relative '../version'

module StreamWeaver
  module Canvas
    # Append-only JSONL log of canvas lifecycle events (bridge start/stop,
    # session create/close, pane create/duplicate, polls for unknown names).
    # It exists to answer one question the bridge could not: who or what closed
    # this canvas. Logging only -- it never changes bridge behavior, and a
    # failure to log is swallowed so the request path can never break on it.
    #
    # One line per event, written with a single O_APPEND write under flock, so
    # concurrent writers (the bridge's request threads) never interleave. At
    # MAX_BYTES the file rotates to <path>.1 (one generation kept).
    #
    # Only two environment values are ever recorded: CLAUDE_CODE_SESSION_ID and
    # CODEX_THREAD_ID, to attribute a close to the session that ran it.
    module EventLog
      MAX_BYTES = 5 * 1024 * 1024
      CAUSES = %w[cli_close fresh_panel bridge_restart listener_exit user_tab other unknown].freeze
      SESSION_ENV = %w[CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID].freeze
      PPID_LEVELS = 3
      COMMAND_MAX = 200
      SECONDS_PER_UNIT = { 's' => 1, 'm' => 60, 'h' => 3600, 'd' => 86_400 }.freeze
      # argv can carry credentials (`--token abc`, `KEY=abc`, a pasted bearer
      # token) and a parent's argv can be a whole prompt, so command lines are
      # scrubbed and truncated before they reach disk.
      SECRET_ARG = /(token|secret|password|passwd|api[_-]?key|authorization|bearer)([=:\s]+)(?:bearer\s+)?\S+/i
      SECRET_SHAPE = /\b(?:sk|ghp|gho|ghs|xox[abprs])[-_][A-Za-z0-9_-]{8,}/

      module_function

      def path
        ENV['STREAMWEAVER_CANVAS_EVENTS'] || File.join(Dir.home, '.streamweaver', 'canvas-events.jsonl')
      end

      # Never raises. Returns true when a line was written.
      def record(event, session_name: nil, pane_id: nil, cause: nil, caller_info: nil, **extra)
        entry = {
          ts: Time.now.utc.iso8601(3),
          event: event.to_s,
          session_name: session_name,
          pane_id: pane_id,
          cause: normalize_cause(cause),
          caller: caller_info || 'unknown',
          bridge_pid: Process.pid,
          version: StreamWeaver::VERSION
        }.merge(extra)
        append(JSON.generate(entry) + "\n")
      rescue StandardError
        false
      end

      def normalize_cause(cause)
        return cause.to_s if CAUSES.include?(cause.to_s)

        cause.nil? ? 'unknown' : 'other'
      end

      def append(line)
        FileUtils.mkdir_p(File.dirname(path))
        rotate_if_needed
        File.open(path, File::WRONLY | File::APPEND | File::CREAT, 0o600) do |f|
          f.flock(File::LOCK_EX)
          f.syswrite(line)
        end
        true
      end

      # Two racing rotators at worst drop one old generation; a lost log line
      # is never the result, because the live file is reopened after rename.
      def rotate_if_needed
        File.rename(path, "#{path}.1") if File.size?(path).to_i > MAX_BYTES
      rescue SystemCallError
        nil
      end

      # Who ran this process: pid, argv, three ppid levels, cwd, and the two
      # session ids. Anything unknowable stays "unknown", never guessed.
      def caller_info
        {
          pid: Process.pid,
          command: process_command(Process.pid),
          ppid_chain: ppid_chain,
          cwd: utf8(Dir.pwd),
          claude_code_session_id: ENV['CLAUDE_CODE_SESSION_ID'],
          codex_thread_id: ENV['CODEX_THREAD_ID']
        }
      rescue StandardError
        'unknown'
      end

      def ppid_chain
        pid = Process.ppid
        chain = []
        while chain.size < PPID_LEVELS && pid && pid > 1
          chain << { pid: pid, command: process_command(pid) }
          pid = process_ppid(pid)
        end
        chain
      end

      def process_command(pid)
        out = `ps -o command= -p #{Integer(pid)} 2>/dev/null`.strip
        out.empty? ? 'unknown' : scrub_command(utf8(out))
      rescue StandardError
        'unknown'
      end

      # Backtick output and paths carry the process's external encoding; under
      # LANG=C a non-ASCII byte makes JSON.generate raise, and caller_info is
      # built outside record's rescue, on the close and stop paths.
      def utf8(text)
        text.dup.force_encoding(Encoding::UTF_8).scrub('?')
      end

      def scrub_command(text)
        scrubbed = text.gsub(SECRET_ARG, '\\1\\2[REDACTED]').gsub(SECRET_SHAPE, '[REDACTED]')
        scrubbed.length > COMMAND_MAX ? "#{scrubbed[0, COMMAND_MAX]}..." : scrubbed
      end

      def process_ppid(pid)
        out = `ps -o ppid= -p #{Integer(pid)} 2>/dev/null`.strip
        out.empty? ? nil : out.to_i
      rescue StandardError
        nil
      end

      # Reading side, used by `streamweaver canvas-events`. Read-only; returns
      # parsed entries oldest first across the rotated and live files.
      def read(session: nil, since: nil)
        lines = [ "#{path}.1", path ].select { |p| File.file?(p) }.flat_map { |p| File.readlines(p) }
        entries = lines.filter_map do |l|
          JSON.parse(l)
        rescue JSON::ParserError
          nil
        end
        entries = entries.select { |e| e['session_name'] == session } if session
        entries = entries.select { |e| (Time.parse(e['ts'].to_s) >= since rescue false) } if since
        entries
      end

      # "30m", "2h", "1d" -> Time
      def parse_since(text, now: Time.now)
        m = text.to_s.match(/\A(\d+)([smhd])\z/) or return nil
        now - (m[1].to_i * SECONDS_PER_UNIT.fetch(m[2]))
      end
    end
  end
end
