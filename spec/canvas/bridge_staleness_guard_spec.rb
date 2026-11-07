# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/staleness_guard'
require 'stream_weaver/canvas/code_stamp'
require_relative '../support/env_helper'
require_relative '../support/output_helper'
require_relative '../support/canvas_events_helper'

# The guard that auto-restarts a canvas bridge left running on older code
# (disc-171). It fires inside ordinary commands -- canvas-push, get-started,
# panel -- so the bar is not "does it heal" but "does it stay completely still
# when nothing is wrong": a spurious restart takes down every session the
# developer has open in a browser.
#
# The pid file here names THIS process, which makes bridge_running? true
# without a real bridge; the real thing is covered by the e2e spec next door.
RSpec.describe StreamWeaver::Canvas::StalenessGuard do
  include EnvHelper
  include OutputHelper
  include CanvasEventsHelper

  let(:tmpdir) { File.join(Dir.tmpdir, "sw-stale-#{Process.pid}-#{rand(100_000)}") }
  let(:pid_file) { File.join(tmpdir, 'canvas.pid') }
  let(:client) { StreamWeaver::Canvas::Client }
  let(:stamp) { StreamWeaver::Canvas::CodeStamp }
  let(:healed) { { ok: true, dir: '/tmp/snap', unconfirmed: [], old_port: 4700, port: 4700 } }

  around do |example|
    FileUtils.mkdir_p(tmpdir)
    # SW_NO_AUTO_RESTART is on suite-wide (spec_helper) so no spec can restart
    # the developer's real bridge; cleared here because the heal is the thing
    # under test, and safe because the pid file is a throwaway.
    with_env('STREAMWEAVER_CANVAS_PID' => pid_file,
             'STREAMWEAVER_CANVAS_SOCKET' => File.join(tmpdir, 'canvas.sock'),
             'SW_NO_AUTO_RESTART' => nil) do
      example.run
    end
  ensure
    FileUtils.rm_rf(tmpdir)
  end

  # An idle bridge (no sessions) is the only one the guard restarts on sight;
  # the live-sessions case has its own examples below.
  before do
    described_class.reset!
    allow(described_class).to receive(:live_session_names).and_return([])
  end
  after { described_class.reset! }

  # A pid file naming a live process (ours), with whatever stamp is passed --
  # none at all by default, which is what an upgraded-underneath bridge looks
  # like.
  def write_pid_file(extra = '')
    File.write(pid_file, "pid=#{Process.pid}\nport=4700\n#{extra}")
  end

  describe 'the pid file stamp' do
    it 'is written alongside pid and port at bridge boot' do
      StreamWeaver::Canvas::BridgeServer.write_pid_file

      content = File.read(pid_file)
      expect(content).to match(/^pid=\d+$/)
      expect(content).to match(/^port=\d+$/)
      expect(stamp.parse(content)).to eq(version: stamp.version, code: stamp.fingerprint)
    end

    it 'round-trips through read_bridge_info without disturbing pid and port' do
      StreamWeaver::Canvas::BridgeServer.write_pid_file

      info = client.read_bridge_info
      expect(info[:pid]).to eq(Process.pid)
      expect(info[:port]).to be_a(Integer)
      expect(info[:version]).to eq(stamp.version)
      expect(info[:code]).to eq(stamp.fingerprint)
    end

    it 'reads a pre-stamp two-line pid file with nil stamp fields (back-compat)' do
      write_pid_file

      info = client.read_bridge_info
      expect(info[:pid]).to eq(Process.pid)
      expect(info[:port]).to eq(4700)
      expect(info[:version]).to be_nil
      expect(info[:code]).to be_nil
      expect(client.bridge_running?).to be(true)
    end
  end

  describe '.ensure_current!' do
    it 'does nothing at all when the running bridge matches this code' do
      write_pid_file(stamp.pid_file_stanza)
      expect(StreamWeaver::CLI).not_to receive(:restart_bridge_preserving_sessions)

      expect(capture_stderr { described_class.ensure_current! }).to eq('')
    end

    it 'does nothing when no bridge is running, stamp or no stamp' do
      expect(File.exist?(pid_file)).to be(false)
      expect(StreamWeaver::CLI).not_to receive(:restart_bridge_preserving_sessions)

      described_class.ensure_current!
    end

    it 'restarts once, announces it in a single line, and returns for the caller to proceed' do
      write_pid_file
      expect(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions).once.and_return(healed)

      err = capture_stderr { described_class.ensure_current! }

      expect(err.lines.size).to eq(1)
      expect(err).to include('canvas bridge was running older code')
    end

    it 'announces on stderr, never stdout -- canvas-wait emits JSON there' do
      write_pid_file
      allow(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions).and_return(healed)

      expect(capture_stdout { capture_stderr { described_class.ensure_current! } }).to eq('')
    end

    it 'checks once per process, so a command that sends ten messages restarts at most once' do
      write_pid_file
      expect(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions).once.and_return(healed)

      capture_stderr { 10.times { described_class.ensure_current! } }
    end

    it 'cannot recurse: the restart it runs re-enters the guard as a no-op' do
      write_pid_file
      calls = 0
      allow(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions) do
        calls += 1
        described_class.ensure_current!
        healed
      end

      capture_stderr { described_class.ensure_current! }

      expect(calls).to eq(1)
    end

    it 'warns with the manual command instead of restarting under SW_NO_AUTO_RESTART' do
      write_pid_file
      expect(StreamWeaver::CLI).not_to receive(:restart_bridge_preserving_sessions)

      with_env('SW_NO_AUTO_RESTART' => '1') do
        err = capture_stderr { described_class.ensure_current! }

        expect(err.lines.size).to eq(1)
        expect(err).to include('canvas-restart')
      end
    end

    it 'names what it could not capture rather than claiming it preserved everything' do
      write_pid_file
      allow(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions)
        .and_return(healed.merge(unconfirmed: %w[ghost]))

      err = capture_stderr { described_class.ensure_current! }

      expect(err).to include('could not capture ghost')
      expect(err).to include('/tmp/snap')
    end

    it 'says so when the restarted bridge landed on a different port, since open tabs are now dead' do
      write_pid_file
      allow(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions)
        .and_return(healed.merge(old_port: 4700, port: 4701))

      err = capture_stderr { described_class.ensure_current! }

      expect(err).to include('moved from port 4700 to 4701')
      expect(err).to include('reload')
    end

    it 'stays quiet about ports when the bridge came back on the one it had' do
      write_pid_file
      allow(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions).and_return(healed)

      expect(capture_stderr { described_class.ensure_current! }).not_to include('moved from port')
    end

    it 'reports the failure rather than swallowing it when the restart does not come back' do
      write_pid_file
      allow(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions)
        .and_return(healed.merge(ok: false))

      expect(capture_stderr { described_class.ensure_current! }).to include('canvas-restart')
    end

    it 'degrades to a warning when the restart itself raises, rather than killing the command' do
      write_pid_file
      allow(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions)
        .and_raise(Errno::ENOENT, 'snapshot dir')

      err = capture_stderr { expect { described_class.ensure_current! }.not_to raise_error }

      expect(err).to include('restart failed')
      expect(err).to include('canvas-restart')
    end
  end

  describe 'the cooldown that stops two installs from fighting over one bridge' do
    # A dev checkout and the installed gem fingerprint differently on purpose,
    # so without this a developer alternating between them would restart the
    # bridge -- and lose their sessions -- on every single command.
    it 'warns instead of restarting again when a heal just happened' do
      write_pid_file
      allow(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions).once.and_return(healed)
      capture_stderr { described_class.ensure_current! }

      described_class.reset!
      err = capture_stderr { described_class.ensure_current! }

      expect(err).to include('was just restarted')
      expect(err).to include('SW_NO_AUTO_RESTART=1')
    end

    it 'heals again once the cooldown has passed' do
      write_pid_file
      expect(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions).twice.and_return(healed)
      capture_stderr { described_class.ensure_current! }

      stale_marker = Time.now - (described_class::COOLDOWN_SECONDS + 1)
      File.utime(stale_marker, stale_marker, described_class.heal_marker_path)
      described_class.reset!

      expect(capture_stderr { described_class.ensure_current! }).to include('was running older code')
    end
  end

  describe 'commands that restart the bridge themselves' do
    it 'canvas-stop has the guard disabled before it touches the bridge' do
      write_pid_file
      allow(client).to receive(:stop_bridge) do
        expect(described_class.pending?).to be(false)
        true
      end

      capture_stdout { StreamWeaver::CLI.canvas_stop }
    end

    it 'canvas-restart has the guard disabled before it touches the bridge' do
      write_pid_file
      allow(StreamWeaver::CLI).to receive(:do_canvas_snapshot) do |dir|
        expect(described_class.pending?).to be(false)
        { dir: dir, sessions: [], unconfirmed: [] }
      end
      allow(client).to receive(:stop_bridge).and_return(true)
      allow(client).to receive(:ensure_bridge_running).and_return(pid: 1, port: 4700)
      allow(StreamWeaver::CLI).to receive(:wait_for_bridge_ready).and_return(true)
      allow(StreamWeaver::CLI).to receive(:do_canvas_restore).and_return(true)

      capture_stderr { capture_stdout { StreamWeaver::CLI.canvas_restart(['--yes']) } }
    end
  end

  describe 'the socket calls every canvas command funnels through' do
    it 'runs the guard before send_message reaches the socket' do
      write_pid_file(stamp.pid_file_stanza)
      expect(described_class).to receive(:ensure_current!).and_call_original

      # No bridge is actually listening on the socket path, so this raises --
      # what matters is that the guard already ran by then.
      expect { client.send_message({ type: 'list' }) }.to raise_error(StreamWeaver::Canvas::Client::ConnectionError)
    end

    it 'runs the guard before send_and_wait reaches the socket' do
      write_pid_file(stamp.pid_file_stanza)
      expect(described_class).to receive(:ensure_current!).and_call_original

      expect { client.send_and_wait({ type: 'list' }, event_type: 'event', timeout: 1) }
        .to raise_error(StreamWeaver::Canvas::Client::ConnectionError)
    end

    it 'runs the guard before each_event reaches the socket' do
      write_pid_file(stamp.pid_file_stanza)
      expect(described_class).to receive(:ensure_current!).and_call_original

      expect { client.each_event('x') { nil } }.to raise_error(StreamWeaver::Canvas::Client::ConnectionError)
    end

    it 'runs the guard before ensure_bridge_running decides the bridge is usable' do
      write_pid_file(stamp.pid_file_stanza)
      allow(client).to receive(:http_healthy?).and_return(true)
      expect(described_class).to receive(:ensure_current!).and_call_original

      client.ensure_bridge_running
    end
  end

  describe 'a stale bridge that holds live sessions' do
    before { write_pid_file }

    it 'is not restarted: it warns once and names the manual command' do
      allow(described_class).to receive(:live_session_names).and_return(%w[today-focus efforts])
      expect(StreamWeaver::CLI).not_to receive(:restart_bridge_preserving_sessions)

      err = capture_stderr { described_class.ensure_current! }

      expect(err).to include('holds 2 live session(s)').and include('not restarting it').and include('canvas-restart')
    end

    it 'is not restarted when the bridge cannot say what it holds' do
      allow(described_class).to receive(:live_session_names).and_return(nil)
      expect(StreamWeaver::CLI).not_to receive(:restart_bridge_preserving_sessions)

      expect(capture_stderr { described_class.ensure_current! }).to include('unknown number')
    end

    it 'records heal_skipped with who asked and both code stamps' do
      allow(described_class).to receive(:live_session_names).and_return(%w[efforts])
      capture_stderr { described_class.ensure_current! }

      skipped = last_canvas_event(:heal_skipped)
      expect(skipped).to include('cause' => 'bridge_restart', 'detail' => 'live_sessions', 'sessions' => %w[efforts])
      expect(skipped['caller']).to include('pid' => Process.pid)
      expect(skipped).to include('bridge_stamp', 'my_stamp')
    end
  end

  describe 'an idle stale bridge' do
    it 'is healed, and the bridge_heal event names the caller and both stamps' do
      write_pid_file
      allow(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions).and_return(healed)

      capture_stderr { described_class.ensure_current! }

      heal = last_canvas_event(:bridge_heal)
      expect(heal).to include('detail' => 'staleness_heal', 'cause' => 'bridge_restart')
      expect(heal['caller']).to include('pid' => Process.pid)
      expect(heal).to include('old_stamp', 'new_stamp')
      expect(client.take_start_env).to include('SW_BRIDGE_START_CAUSE' => 'bridge_restart',
                                               'SW_BRIDGE_START_DETAIL' => 'staleness_heal')
    end

    it 'toasts every canvas the restart touched (sessions created between the idle check and the snapshot)' do
      write_pid_file
      allow(StreamWeaver::CLI).to receive(:restart_bridge_preserving_sessions)
        .and_return(healed.merge(kept: %w[a], dropped: %w[b]))
      toasts = []
      allow(client).to receive(:send_message) { |msg| toasts << msg if msg[:type] == 'toast' }

      capture_stderr { described_class.ensure_current! }

      expect(toasts.map { |t| t[:name] }).to match_array(%w[a b])
      expect(toasts.first).to include(variant: 'warning', duration: 0)
      expect(toasts.first[:message]).to include('restarted', 'Came back empty: b')
    end
  end
end
