# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/iterm'

# Round-7 UAT: a worker-initiated canvas push (unlike a Run submit) raises
# nothing on its own -- `canvas-raise` is the one-liner that surfaces an
# already-pushed session without opening a second pane (unlike `panel`,
# which always splits a new one).
RSpec.describe StreamWeaver::CLI do
  def capture_io
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end

  describe '.canvas_raise' do
    context 'when the session has a live iTerm pane tracked' do
      before do
        allow(StreamWeaver::Canvas::Client).to receive(:send_message).with({ type: 'list' }).and_return(
          type: 'list', sessions: [{ name: 'decision', pane_id: 'pane-123', websocket_count: 1 }]
        )
        allow(StreamWeaver::ITerm).to receive(:available?).and_return(true)
        allow(StreamWeaver::ITerm).to receive(:session_alive?).with('pane-123').and_return(true)
        allow(StreamWeaver::ITerm).to receive(:activate_session)
      end

      it 'activates the tracked pane instead of opening a browser' do
        expect(StreamWeaver::ITerm).to receive(:activate_session).with('pane-123')
        expect(described_class).not_to receive(:open_browser)

        capture_io { described_class.canvas_raise(['decision']) }
      end

      it 'reports the pane was raised' do
        out, = capture_io { described_class.canvas_raise(['decision']) }

        expect(out).to include('decision')
        expect(out).to match(/iTerm pane/)
      end
    end

    context 'when there is no pane to reuse (degraded / browser-tab mode)' do
      let(:live_bridge_url) { 'http://localhost:59322/canvas/decision' }

      before do
        allow(StreamWeaver::Canvas::Client).to receive(:send_message).with({ type: 'list' }).and_return(
          type: 'list', sessions: [{ name: 'decision', pane_id: nil, websocket_count: 1 }]
        )
        allow(StreamWeaver::Canvas::Client).to receive(:read_bridge_info).and_return(pid: 123, port: 59_322)
        allow(described_class).to receive(:open_browser)
      end

      it 'falls back to opening the session URL in the default browser' do
        expect(described_class).to receive(:open_browser).with(live_bridge_url)

        capture_io { described_class.canvas_raise(['decision']) }
      end

      it 'never opens a browser when SW_NO_OPEN is set -- open_browser itself is the SW_NO_OPEN gate' do
        prev = ENV['SW_NO_OPEN']
        ENV['SW_NO_OPEN'] = '1'
        allow(described_class).to receive(:open_browser).and_call_original

        expect(Kernel).not_to receive(:system)

        capture_io { described_class.canvas_raise(['decision']) }
      ensure
        ENV['SW_NO_OPEN'] = prev
      end
    end

    context 'when iTerm2 is available but the tracked pane is gone (closed by the user)' do
      let(:live_bridge_url) { 'http://localhost:59323/canvas/decision' }

      before do
        allow(StreamWeaver::Canvas::Client).to receive(:send_message).with({ type: 'list' }).and_return(
          type: 'list', sessions: [{ name: 'decision', pane_id: 'stale-pane', websocket_count: 1 }]
        )
        allow(StreamWeaver::ITerm).to receive(:available?).and_return(true)
        allow(StreamWeaver::ITerm).to receive(:session_alive?).with('stale-pane').and_return(false)
        allow(StreamWeaver::Canvas::Client).to receive(:read_bridge_info).and_return(pid: 123, port: 59_323)
        allow(described_class).to receive(:open_browser)
      end

      it 'falls back to the browser instead of activating a pane that no longer exists' do
        expect(StreamWeaver::ITerm).not_to receive(:activate_session)
        expect(described_class).to receive(:open_browser).with(live_bridge_url)

        capture_io { described_class.canvas_raise(['decision']) }
      end
    end

    # capture_io can't survive `exit`'s SystemExit (it interrupts the block
    # before the [stdout, stderr] pair is returned), so these three swap
    # $stderr in directly and restore it themselves.
    def capture_stderr_through_exit
      old_stderr = $stderr
      $stderr = StringIO.new
      expect { yield }.to raise_error(SystemExit)
      $stderr.string
    ensure
      $stderr = old_stderr
    end

    it 'errors with usage and exits 1 when no session name is given' do
      err = capture_stderr_through_exit { described_class.canvas_raise([]) }
      expect(err).to include('Usage: streamweaver canvas-raise')
    end

    it 'errors and exits 1 when the named session does not exist' do
      allow(StreamWeaver::Canvas::Client).to receive(:send_message).with({ type: 'list' }).and_return(
        type: 'list', sessions: []
      )

      err = capture_stderr_through_exit { described_class.canvas_raise(['ghost']) }
      expect(err).to include('Session not found: ghost')
    end

    it 'errors and exits 1 when the canvas bridge is not running' do
      allow(StreamWeaver::Canvas::Client).to receive(:send_message).with({ type: 'list' })
        .and_raise(StreamWeaver::Canvas::Client::NotRunningError, 'Canvas bridge is not running')

      err = capture_stderr_through_exit { described_class.canvas_raise(['decision']) }
      expect(err).to include('Canvas bridge is not running')
    end
  end
end
