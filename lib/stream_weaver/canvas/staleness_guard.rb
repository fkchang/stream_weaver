# frozen_string_literal: true

require 'fileutils'
require 'stringio'
require_relative 'code_stamp'

module StreamWeaver
  module Canvas
    # Detects a canvas bridge left running on code the caller no longer has,
    # and restarts it in place (disc-171).
    #
    # A bridge outlives the shells that talk to it and holds its classes in
    # memory, so `rake install` or `gem update` underneath one leaves it
    # serving the old code: pushed canvas source calls a brand-new method and
    # the bridge dies with a bare NameError, with nothing on screen saying
    # why. Client calls ensure_current! before every socket conversation, so
    # every command that reaches the bridge is covered by one check rather
    # than N call sites.
    #
    # The whole design leans away from acting: a spurious restart takes down
    # every session the developer has open in a browser, which is worse than
    # the staleness it would be curing. Hence the once-per-process latch, the
    # cross-process cooldown, and CodeStamp.stale?'s refusal to guess.
    module StalenessGuard
      # Long enough that a checkout/gem pair alternating on one bridge stops
      # after the first restart instead of thrashing on every command; short
      # enough that a genuine second upgrade in the same session still heals.
      COOLDOWN_SECONDS = 60

      module_function

      def pending?
        !@checked
      end

      # For canvas-stop and canvas-restart, which are the manual spelling of
      # this same cure -- healing inside them is a restart within a restart.
      def disable!
        @checked = true
      end

      # Specs only: the latch is process-global and RSpec is one process.
      def reset!
        @checked = false
      end

      def ensure_current!
        return unless pending?

        @checked = true

        return unless Client.bridge_running?
        return unless CodeStamp.stale?(Client.read_bridge_info)

        if auto_restart_disabled?
          warn_only("canvas bridge is running older code")
        elsif recently_healed?
          # Two installs cannot land inside a minute; a second mismatch this
          # soon means two callers disagree about which code is current
          # (a dev checkout and the installed gem, say), and restarting again
          # would just hand the bridge back and forth forever. Naming
          # canvas-restart here would be advice to resume the fight, so this
          # branch points at the off switch instead.
          $stderr.puts "StreamWeaver: canvas bridge still looks like older code, but was just restarted — two installs disagree about which code is current; set SW_NO_AUTO_RESTART=1 to stop the restarts."
        else
          heal!
        end
      end

      def auto_restart_disabled?
        !ENV['SW_NO_AUTO_RESTART'].to_s.empty?
      end

      def warn_only(reason)
        $stderr.puts "StreamWeaver: #{reason} — run `streamweaver canvas-restart` to pick it up."
      end

      # Announced on stderr, not stdout: canvas-wait and friends emit JSON for
      # a script to parse, and a line of narration in front of it is a parse
      # error on the other end.
      #
      # The restart lives in the CLI, which owns snapshot/restore; required
      # here rather than at the top of the file because the CLI requires the
      # canvas client back. Its narration is swallowed so the heal costs the
      # caller one line; anything it could not preserve, or could not do at
      # all, still speaks -- with the manual command.
      def heal!
        require_relative '../cli'

        $stderr.puts "StreamWeaver: canvas bridge was running older code — restarting it (sessions preserved)…"
        record_heal!

        result = silently { StreamWeaver::CLI.restart_bridge_preserving_sessions }
        report(result)
        result
      rescue StandardError => e
        # A cure that cannot finish must not take down the command it was
        # trying to help: the caller only wanted to push a canvas.
        $stderr.puts "StreamWeaver: automatic bridge restart failed (#{e.class}: #{e.message}) — run `streamweaver canvas-restart`."
        { ok: false, dir: nil, unconfirmed: [] }
      end

      # Everything that qualifies the "sessions preserved" the announcement
      # already promised: a session the snapshot never read, a bridge that came
      # back on a different port (every open tab is now pointing at a dead one
      # -- canvas-restart warns about this in stars, and an automatic restart
      # owes at least as much), and a restore that did not finish.
      def report(result)
        unconfirmed = result[:unconfirmed] || []
        unless unconfirmed.empty?
          $stderr.puts "StreamWeaver: could not capture #{unconfirmed.join(', ')} before the restart — snapshot at #{result[:dir]}"
        end

        if result[:old_port] && result[:port] && result[:old_port] != result[:port]
          $stderr.puts "StreamWeaver: bridge moved from port #{result[:old_port]} to #{result[:port]} — reload any canvas tab you have open."
        end

        return if result[:ok]

        $stderr.puts "StreamWeaver: automatic bridge restart did not complete — snapshot at #{result[:dir]}; run `streamweaver canvas-restart` if sessions look wrong."
      end

      def silently
        original = $stdout
        $stdout = StringIO.new
        yield
      ensure
        $stdout = original
      end

      # Written BEFORE the restart, so a second process arriving mid-heal
      # backs off rather than snapshotting a half-restored bridge.
      def heal_marker_path
        File.join(File.dirname(Client.pid_file_path), 'canvas.heal')
      end

      def recently_healed?
        Time.now - File.mtime(heal_marker_path) < COOLDOWN_SECONDS
      rescue SystemCallError
        false
      end

      # Silent on failure by design: an unwritable marker only costs the next
      # invocation its cooldown, and the heal itself is worth doing anyway --
      # there is nothing here to tell the operator to act on.
      def record_heal!
        FileUtils.mkdir_p(File.dirname(heal_marker_path))
        File.write(heal_marker_path, Time.now.to_i.to_s)
      rescue SystemCallError
        nil
      end
    end
  end
end
