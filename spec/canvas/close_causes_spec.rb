# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/iterm'

# Each way a canvas can be closed or its bridge stopped hands the lifecycle
# log (Canvas::EventLog) a cause, so "Session Complete" can be traced.
RSpec.describe 'close paths name their cause' do
  def quietly
    old = [$stdout, $stderr]
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
  ensure
    $stdout, $stderr = old
  end

  let(:client) { StreamWeaver::Canvas::Client }
  let(:sent) { [] }

  before do
    allow(client).to receive(:ensure_bridge_running)
    allow(client).to receive(:send_message) { |msg| sent << msg; { type: 'ready', name: 'n', url: 'http://x/canvas/n' } }
    allow(StreamWeaver::ITerm).to receive(:available?).and_return(false)
    allow(StreamWeaver::CLI).to receive(:open_browser)
  end

  it 'panel --fresh closes with cause fresh_panel' do
    quietly { StreamWeaver::CLI.panel(%w[n --fresh]) }

    close = sent.find { |m| m[:type] == 'close' }
    expect(close).to include(name: 'n', cause: 'fresh_panel')
    expect(close[:caller]).to include(pid: Process.pid)
  end

  it 'canvas-close closes with cause cli_close' do
    allow(client).to receive(:send_message) { |msg| sent << msg; { type: 'closed', name: 'n' } }
    quietly { StreamWeaver::CLI.canvas_close(%w[n]) }

    expect(sent.first).to include(type: 'close', cause: 'cli_close')
  end

  it 'builds the /shutdown path with cause, detail and caller' do
    path = client.shutdown_path('bridge_restart', 'staleness_heal')
    query = URI.decode_www_form(URI(path).query).to_h

    expect(URI(path).path).to eq('/shutdown')
    expect(query).to include('cause' => 'bridge_restart', 'detail' => 'staleness_heal')
    expect(JSON.parse(query['caller'])).to include('pid' => Process.pid)
  end

  it 'the staleness heal stops the bridge as bridge_restart' do
    cli = StreamWeaver::CLI
    allow(cli).to receive_messages(default_snapshot_dir: '/nonexistent', do_canvas_snapshot: {},
                                   do_canvas_restore: true, wait_for_bridge_ready: nil)
    allow(client).to receive_messages(bridge_running?: false, ensure_bridge_running: { port: 4700 })
    expect(client).to receive(:stop_bridge).with(cause: 'bridge_restart', detail: 'staleness_heal')

    cli.restart_bridge_preserving_sessions
  end

  it 'canvas-stop stops the bridge as other/canvas_stop' do
    expect(client).to receive(:stop_bridge).with(cause: 'other', detail: 'canvas_stop').and_return(true)

    quietly { StreamWeaver::CLI.canvas_stop }
  end
end
