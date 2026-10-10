# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stringio'
require 'yaml'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/session'

# reply_to (story: reply-to-session-field): an opaque "<extension id>:<payload>" string a canvas
# session carries so the bridge knows who receives its browser events. Absent means every message,
# listing, get_dsl answer and snapshot manifest is exactly what it was before this existed.
RSpec.describe 'canvas reply_to' do
  let(:messages) { StreamWeaver::Canvas::Protocol::Messages }
  let(:bridge) { StreamWeaver::Canvas::Bridge.new(port: 0) }

  def capture_io
    old_out = $stdout
    old_err = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout = old_out
    $stderr = old_err
  end

  describe 'protocol messages' do
    it 'create and push carry reply_to only when given' do
      expect(messages.create('c', reply_to: 'peerpressure:abc')).to include(reply_to: 'peerpressure:abc')
      expect(messages.push('c', 'x', reply_to: 'peerpressure:abc')).to include(reply_to: 'peerpressure:abc')
    end

    it 'leaves both messages byte-for-byte unchanged without it' do
      expect(messages.create('c', layout: :wide, theme: :doc)).to eq(type: 'create', name: 'c', layout: :wide, theme: :doc)
      expect(messages.push('c', 'x', source_dir: '/r')).to eq(type: 'push', name: 'c', dsl: 'x', source_dir: '/r')
    end
  end

  describe StreamWeaver::Canvas::Session do
    it 'stores a trimmed reply_to and clears on blank' do
      s = described_class.new('c')
      s.set_reply_to("  peerpressure:abc \n")
      expect(s.reply_to).to eq('peerpressure:abc')
      s.set_reply_to('  ')
      expect(s.reply_to).to be_nil
    end

    it 'adds reply_to to to_h only when set, so listings are unchanged otherwise' do
      s = described_class.new('c')
      expect(s.to_h).not_to have_key(:reply_to)
      s.set_reply_to('peerpressure:abc')
      expect(s.to_h[:reply_to]).to eq('peerpressure:abc')
    end
  end

  describe 'bridge' do
    it 'records reply_to from create and reports it in list and get_dsl' do
      bridge.handle_claude_message(type: 'create', name: 's', reply_to: 'peerpressure:abc')
      expect(bridge.handle_claude_message(type: 'list')[:sessions].first[:reply_to]).to eq('peerpressure:abc')
      expect(bridge.handle_claude_message(type: 'get_dsl', name: 's')[:reply_to]).to eq('peerpressure:abc')
    end

    it 'lets a push set or replace reply_to on a session that already exists' do
      bridge.handle_claude_message(type: 'create', name: 's', theme: :doc, reply_to: 'peerpressure:old')
      bridge.handle_claude_message(type: 'push', name: 's', dsl: "header1 'Hi'", reply_to: 'peerpressure:new')
      expect(bridge.get_session('s').reply_to).to eq('peerpressure:new')
      expect(bridge.get_session('s').theme).to eq(:doc) # create stays first-wins for theme and layout
    end

    it 'lets a create on an existing session replace reply_to without touching theme or layout' do
      bridge.handle_claude_message(type: 'create', name: 's', theme: :doc, layout: :wide)
      bridge.handle_claude_message(type: 'create', name: 's', theme: :default, reply_to: 'peerpressure:abc')
      s = bridge.get_session('s')
      expect([s.reply_to, s.theme, s.layout]).to eq(['peerpressure:abc', :doc, :wide])
    end

    it 'leaves reply_to alone when a push does not mention it, and clears it on an empty string' do
      bridge.handle_claude_message(type: 'create', name: 's', reply_to: 'peerpressure:abc')
      bridge.handle_claude_message(type: 'push', name: 's', dsl: "header1 'Hi'")
      expect(bridge.get_session('s').reply_to).to eq('peerpressure:abc')
      bridge.handle_claude_message(type: 'push', name: 's', dsl: "header1 'Hi'", reply_to: '')
      expect(bridge.get_session('s').reply_to).to be_nil
    end

    it 'leaves reply_to unchanged when a push fails to render, like dsl, stylesheets and source_dir' do
      bridge.handle_claude_message(type: 'create', name: 's', reply_to: 'peerpressure:old')
      response = bridge.handle_claude_message(type: 'push', name: 's', dsl: 'raise "bad dsl"', reply_to: 'peerpressure:new')
      expect(response[:type]).to eq('push_error')
      expect(bridge.get_session('s').reply_to).to eq('peerpressure:old')
    end

    it 'keeps list and get_dsl exactly as before for a session without reply_to' do
      bridge.handle_claude_message(type: 'create', name: 's', layout: :wide, theme: :doc)
      bridge.get_session('s').set_dsl("header1 'Hi'")
      expect(bridge.handle_claude_message(type: 'get_dsl', name: 's'))
        .to eq(type: 'dsl', name: 's', dsl: "header1 'Hi'", theme: :doc, layout: :wide)
      expect(bridge.handle_claude_message(type: 'list')[:sessions].first.keys)
        .to eq(%i[name state websocket_count created_at pane_id theme layout])
    end
  end

  describe 'CLI' do
    around do |ex|
      prev = ENV['STREAMWEAVER_HISTORY_ROOT']
      Dir.mktmpdir do |d|
        ENV['STREAMWEAVER_HISTORY_ROOT'] = d
        @tmp = d
        ex.run
      end
    ensure
      ENV['STREAMWEAVER_HISTORY_ROOT'] = prev
    end

    it 'canvas keeps accepting --layout=wide, with --reply-to in either form' do
      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return(pid: 1, port: 4700)
      sent = []
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) { |m| sent << m; { type: 'ready', name: 's', url: 'u' } }
      capture_io { StreamWeaver::CLI.canvas_session(['--layout=wide', '--reply-to=peerpressure:a', 's']) }
      capture_io { StreamWeaver::CLI.canvas_session(['s', '--reply-to', 'peerpressure:b']) }
      expect(sent.first).to include(layout: :wide, reply_to: 'peerpressure:a')
      expect(sent.last).to include(reply_to: 'peerpressure:b')
    end

    it 'canvas with --reply-to but no value fails with usage instead of eating the session name' do
      expect(StreamWeaver::Canvas::Client).not_to receive(:send_message)
      _out, err = capture_io { expect { StreamWeaver::CLI.canvas_session(['s', '--reply-to']) }.to raise_error(SystemExit) }
      expect(err).to include('missing argument').and include('Usage: streamweaver canvas')
    end

    it 'canvas-push sends --reply-to to the bridge, and omits it when not given' do
      allow($stdin).to receive(:tty?).and_return(false)
      allow($stdin).to receive(:read).and_return("header1 'Hi'")
      sent = []
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) { |m| sent << m; nil }
      capture_io { StreamWeaver::CLI.canvas_push(['s', '--reply-to', 'peerpressure:abc']) }
      capture_io { StreamWeaver::CLI.canvas_push(['s']) }
      expect(sent.first[:reply_to]).to eq('peerpressure:abc')
      expect(sent.last).not_to have_key(:reply_to)
    end

    it 'canvas sends --reply-to on create' do
      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return(pid: 1, port: 4700)
      sent = []
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) { |m| sent << m; { type: 'ready', name: 's', url: 'u' } }
      capture_io { StreamWeaver::CLI.canvas_session(['--reply-to', 'peerpressure:abc', 's']) }
      expect(sent.first).to include(type: 'create', name: 's', reply_to: 'peerpressure:abc')
    end
  end

  describe 'snapshot and restore' do
    around { |ex| Dir.mktmpdir { |d| @tmp = d; ex.run } }

    it 'writes reply_to into the manifest only when set, and restore sends it back on create' do
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(true)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        case msg[:type]
        when 'list'
          { type: 'list', sessions: [
            { name: 'pinned', theme: 'default', layout: 'fluid', reply_to: 'peerpressure:abc' },
            { name: 'plain', theme: 'default', layout: 'fluid' }
          ] }
        when 'get_dsl' then { type: 'dsl', name: msg[:name], dsl: "header1 'Hi'", theme: 'default', layout: 'fluid' }
        end
      end
      dir = File.join(@tmp, 'snap')
      capture_io { StreamWeaver::CLI.canvas_snapshot([dir]) }
      manifest = YAML.safe_load(File.read(File.join(dir, 'manifest.yml')))
      expect(manifest['sessions'].find { |s| s['name'] == 'pinned' }['reply_to']).to eq('peerpressure:abc')
      expect(manifest['sessions'].find { |s| s['name'] == 'plain' }).not_to have_key('reply_to')

      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return(pid: 1, port: 4700)
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(false)
      sent = []
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        sent << msg
        msg[:type] == 'create' ? { type: 'ready', name: msg[:name], url: 'u' } : { type: 'push_ok' }
      end
      capture_io { StreamWeaver::CLI.canvas_restore([dir]) }
      expect(sent.find { |m| m[:type] == 'create' && m[:name] == 'pinned' }[:reply_to]).to eq('peerpressure:abc')
      expect(sent.find { |m| m[:type] == 'create' && m[:name] == 'plain' }).not_to have_key(:reply_to)
    end
  end
end
