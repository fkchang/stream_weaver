# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/protocol'

RSpec.describe 'canvas lifecycle events' do
  let(:dir) { Dir.mktmpdir('bridge-events-spec') }
  let(:log) { File.join(dir, 'canvas-events.jsonl') }
  let(:bridge) { StreamWeaver::Canvas::Bridge.new(port: 0) }
  let(:messages) { StreamWeaver::Canvas::Protocol::Messages }

  around do |example|
    old = ENV['STREAMWEAVER_CANVAS_EVENTS']
    ENV['STREAMWEAVER_CANVAS_EVENTS'] = log
    example.run
  ensure
    ENV['STREAMWEAVER_CANVAS_EVENTS'] = old
    FileUtils.rm_rf(dir)
  end

  def events
    File.exist?(log) ? File.readlines(log).map { |l| JSON.parse(l) } : []
  end

  it 'logs session_create once, with how it was created' do
    bridge.handle_claude_message(messages.create('s1'))
    bridge.handle_claude_message(messages.create('s1'))

    expect(events.map { |e| [e['event'], e['session_name'], e['via']] }).to eq([%w[session_create s1 cli_create]])
  end

  it 'logs a close from the CLI with cause and the caller who ran it' do
    bridge.handle_claude_message(messages.create('s1'))
    bridge.handle_claude_message(messages.close('s1', cause: 'cli_close'))

    close = events.find { |e| e['event'] == 'session_close' }
    expect(close).to include('session_name' => 's1', 'cause' => 'cli_close', 'existed' => true)
    expect(close['caller']).to include('pid' => Process.pid)
  end

  it 'logs a close whose sender did not say why as unknown' do
    bridge.handle_claude_message(messages.create('s1'))
    bridge.handle_claude_message(messages.close('s1'))

    expect(events.last['cause']).to eq('unknown')
  end

  it 'does not log a pane_create when the same pane id is set again' do
    bridge.handle_claude_message(messages.create('s1'))
    2.times { bridge.handle_claude_message(type: 'set_pane_id', name: 's1', pane_id: 'pane-A') }

    expect(events.count { |e| e['event'].start_with?('pane_') }).to eq(1)
  end

  it 'logs panel --fresh closes as fresh_panel' do
    bridge.handle_claude_message(messages.create('s1'))
    bridge.handle_claude_message(messages.close('s1', cause: 'fresh_panel'))

    expect(events.last['cause']).to eq('fresh_panel')
  end

  it 'logs a close from an older client as unknown, never guessed' do
    bridge.handle_claude_message(type: 'create', name: 's1')
    bridge.handle_claude_message(type: 'close', name: 's1')

    close = events.find { |e| e['event'] == 'session_close' }
    expect(close).to include('cause' => 'unknown', 'caller' => 'unknown')
  end

  it 'still logs a close for a name the bridge does not know' do
    bridge.handle_claude_message(messages.close('ghost'))

    expect(events.last).to include('event' => 'session_close', 'session_name' => 'ghost', 'existed' => false)
  end

  it 'logs pane_create, then pane_duplicate when a second pane replaces the first' do
    bridge.handle_claude_message(messages.create('s1'))
    bridge.handle_claude_message(type: 'set_pane_id', name: 's1', pane_id: 'pane-A')
    bridge.handle_claude_message(type: 'set_pane_id', name: 's1', pane_id: 'pane-B')

    panes = events.select { |e| e['event'].start_with?('pane_') }
    expect(panes.map { |e| e['event'] }).to eq(%w[pane_create pane_duplicate])
    expect(panes.last).to include('pane_id' => 'pane-B', 'previous_pane_id' => 'pane-A')
  end

  describe StreamWeaver::Canvas::BridgeServer do
    before { described_class.instance_variable_set(:@poll_not_found_at, nil) }

    it 'logs poll_not_found at most once a minute per name' do
      3.times { described_class.record_poll_not_found('gone') }
      described_class.record_poll_not_found('other')

      expect(events.map { |e| [e['event'], e['session_name']] }).to eq([%w[poll_not_found gone], %w[poll_not_found other]])
    end

    it 'logs bridge_stop with the cause and caller handed to /shutdown' do
      described_class.note_shutdown('bridge_restart', 'staleness_heal', JSON.generate(pid: 42))
      described_class.record_stop

      expect(events.last).to include('event' => 'bridge_stop', 'cause' => 'bridge_restart',
                                     'detail' => 'staleness_heal', 'caller' => { 'pid' => 42 })
    ensure
      described_class.instance_variable_set(:@stop_info, nil)
    end

    it 'logs a stop nobody asked for as unknown' do
      described_class.instance_variable_set(:@stop_info, nil)
      described_class.record_stop

      expect(events.last).to include('event' => 'bridge_stop', 'cause' => 'unknown', 'caller' => 'unknown')
    end
  end
end
