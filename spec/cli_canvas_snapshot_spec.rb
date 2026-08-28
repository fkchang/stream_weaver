# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'stringio'
require 'yaml'
require 'time'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/session'

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

  # --- Bridge-level: the new get_dsl message (stream_weaver-ps84) ---

  describe 'Canvas::Bridge#handle_claude_message (get_dsl)' do
    let(:bridge) { StreamWeaver::Canvas::Bridge.new(port: 0) }

    it 'returns dsl/theme/layout for a session that has content' do
      session = bridge.create_session('s1', layout: :wide, theme: :doc)
      session.set_dsl("header1 'Hi'")

      response = bridge.handle_claude_message(type: 'get_dsl', name: 's1')

      expect(response).to eq(type: 'dsl', name: 's1', dsl: "header1 'Hi'", theme: :doc, layout: :wide)
    end

    it 'returns a nil dsl for a session with no content yet' do
      bridge.create_session('s2')
      response = bridge.handle_claude_message(type: 'get_dsl', name: 's2')
      expect(response[:dsl]).to be_nil
    end

    it 'errors for an unknown session' do
      response = bridge.handle_claude_message(type: 'get_dsl', name: 'missing')
      expect(response).to eq(type: 'error', message: 'Session not found: missing')
    end
  end

  describe 'Canvas::Session#to_h' do
    it 'includes layout alongside theme (needed to restore a session verbatim)' do
      session = StreamWeaver::Canvas::Session.new('x', layout: :full, theme: :doc)
      expect(session.to_h[:layout]).to eq(:full)
      expect(session.to_h[:theme]).to eq(:doc)
    end
  end

  # --- canvas-snapshot ---

  describe '.canvas_snapshot / .do_canvas_snapshot' do
    around do |ex|
      Dir.mktmpdir { |d| @tmp = d; ex.run }
    end

    it 'writes manifest.yml + <name>.rb per session with content, and skips empty ones' do
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(true)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        case msg[:type]
        when 'list'
          { type: 'list', sessions: [
            { name: 'full', theme: 'doc', layout: 'wide', websocket_count: 0 },
            { name: 'empty', theme: 'default', layout: 'fluid', websocket_count: 0 }
          ] }
        when 'get_dsl'
          if msg[:name] == 'full'
            { type: 'dsl', name: 'full', dsl: "header1 'Hi'", theme: 'doc', layout: 'wide' }
          else
            { type: 'dsl', name: 'empty', dsl: nil, theme: 'default', layout: 'fluid' }
          end
        end
      end

      dir = File.join(@tmp, 'snap1')
      stdout, = capture_io { described_class.canvas_snapshot([dir]) }

      manifest = YAML.safe_load(File.read(File.join(dir, 'manifest.yml')))
      names = manifest['sessions'].map { |s| s['name'] }
      expect(names).to contain_exactly('full', 'empty')

      full_entry = manifest['sessions'].find { |s| s['name'] == 'full' }
      empty_entry = manifest['sessions'].find { |s| s['name'] == 'empty' }
      expect(full_entry['has_content']).to eq(true)
      expect(full_entry['theme']).to eq('doc')
      expect(full_entry['layout']).to eq('wide')
      expect(empty_entry['has_content']).to eq(false)

      expect(File.read(File.join(dir, 'full.rb'))).to eq("header1 'Hi'")
      expect(File.exist?(File.join(dir, 'empty.rb'))).to eq(false)

      expect(stdout).to include('snap  full')
      expect(stdout).to include('skip  empty')
      expect(stdout).to include(dir)
    end

    it 'writes an empty manifest and does not raise when the bridge is not running' do
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(false)

      dir = File.join(@tmp, 'snap2')
      stdout, = capture_io { described_class.canvas_snapshot([dir]) }

      manifest = YAML.safe_load(File.read(File.join(dir, 'manifest.yml')))
      expect(manifest['sessions']).to eq([])
      expect(stdout).to include('not running')
    end

    it 'skips a session whose name is not filesystem-safe rather than writing outside dir' do
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(true)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        case msg[:type]
        when 'list'
          { type: 'list', sessions: [{ name: '../evil', theme: 'default', layout: 'fluid', websocket_count: 0 }] }
        end
      end

      dir = File.join(@tmp, 'snap3')
      stdout, = capture_io { described_class.canvas_snapshot([dir]) }

      expect(stdout).to include('unsafe session name')
      expect(Dir.glob(File.join(@tmp, '**', '*.rb'))).to be_empty
    end
  end

  describe '.default_snapshot_dir' do
    around do |ex|
      prev = ENV['STREAMWEAVER_SNAPSHOT_ROOT']
      Dir.mktmpdir do |d|
        ENV['STREAMWEAVER_SNAPSHOT_ROOT'] = d
        @root = d
        ex.run
      end
    ensure
      ENV['STREAMWEAVER_SNAPSHOT_ROOT'] = prev
    end

    it 'defaults under STREAMWEAVER_SNAPSHOT_ROOT with a UTC timestamp' do
      expect(described_class.default_snapshot_dir).to start_with(@root)
    end
  end

  # --- canvas-restore ---

  describe '.canvas_restore / .do_canvas_restore' do
    around do |ex|
      Dir.mktmpdir { |d| @tmp = d; ex.run }
    end

    def write_manifest(dir, sessions)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, 'manifest.yml'),
                 YAML.dump('captured_at' => Time.now.utc.iso8601, 'sessions' => sessions))
    end

    it 'recreates a session with its theme/layout and pushes its body, skipping empty snapshots' do
      dir = File.join(@tmp, 'restore1')
      write_manifest(dir, [
        { 'name' => 'full', 'theme' => 'doc', 'layout' => 'wide', 'has_content' => true },
        { 'name' => 'empty', 'theme' => 'default', 'layout' => 'fluid', 'has_content' => false }
      ])
      File.write(File.join(dir, 'full.rb'), "header1 'Hi'")

      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return(pid: 1, port: 4700)
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(false)

      sent = []
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        sent << msg
        case msg[:type]
        when 'create' then { type: 'ready', name: msg[:name], url: 'http://x' }
        when 'push' then { type: 'push_ok' }
        end
      end

      stdout, = capture_io { described_class.canvas_restore([dir]) }

      create_msg = sent.find { |m| m[:type] == 'create' && m[:name] == 'full' }
      expect(create_msg[:theme]).to eq(:doc)
      expect(create_msg[:layout]).to eq(:wide)

      push_msg = sent.find { |m| m[:type] == 'push' && m[:name] == 'full' }
      expect(push_msg[:dsl]).to eq("header1 'Hi'")

      expect(sent.none? { |m| m[:name] == 'empty' }).to eq(true)
      expect(stdout).to include('OK    full')
      expect(stdout).to include('skip  empty')
    end

    it 'skips a session that already exists with content unless --force' do
      dir = File.join(@tmp, 'restore2')
      write_manifest(dir, [{ 'name' => 'already', 'theme' => 'default', 'layout' => 'fluid', 'has_content' => true }])
      File.write(File.join(dir, 'already.rb'), "header1 'Hi'")

      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return(pid: 1, port: 4700)
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(true)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        case msg[:type]
        when 'list'
          { type: 'list', sessions: [{ name: 'already', theme: 'default', layout: 'fluid', websocket_count: 0 }] }
        when 'get_dsl'
          { type: 'dsl', name: 'already', dsl: 'existing', theme: 'default', layout: 'fluid' }
        end
      end

      stdout, = capture_io { described_class.canvas_restore([dir]) }
      expect(stdout).to include('skip  already')
      expect(stdout).to include('already exists')
    end

    it 'overwrites an existing session when --force is given' do
      dir = File.join(@tmp, 'restore3')
      write_manifest(dir, [{ 'name' => 'already', 'theme' => 'default', 'layout' => 'fluid', 'has_content' => true }])
      File.write(File.join(dir, 'already.rb'), "header1 'New'")

      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return(pid: 1, port: 4700)
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(true)
      sent = []
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        sent << msg
        case msg[:type]
        when 'list'
          { type: 'list', sessions: [{ name: 'already', theme: 'default', layout: 'fluid', websocket_count: 0 }] }
        when 'get_dsl'
          { type: 'dsl', name: 'already', dsl: 'existing', theme: 'default', layout: 'fluid' }
        when 'create'
          { type: 'ready', name: msg[:name], url: 'http://x' }
        when 'push'
          { type: 'push_ok' }
        end
      end

      stdout, = capture_io { described_class.canvas_restore([dir, '--force']) }
      expect(stdout).to include('OK    already')
      push_msg = sent.find { |m| m[:type] == 'push' }
      expect(push_msg[:dsl]).to eq("header1 'New'")
    end

    it 'exits non-zero and reports FAIL when a push fails' do
      dir = File.join(@tmp, 'restore4')
      write_manifest(dir, [{ 'name' => 'bad', 'theme' => 'default', 'layout' => 'fluid', 'has_content' => true }])
      File.write(File.join(dir, 'bad.rb'), 'broken(')

      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return(pid: 1, port: 4700)
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(false)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        case msg[:type]
        when 'create' then { type: 'ready', name: msg[:name], url: 'http://x' }
        when 'push' then { type: 'push_error', message: 'boom' }
        end
      end

      expect { capture_io { described_class.canvas_restore([dir]) } }.to raise_error(SystemExit)
    end

    it 'errors and exits non-zero when the manifest is missing' do
      dir = File.join(@tmp, 'no-manifest')
      FileUtils.mkdir_p(dir)

      expect { capture_io { described_class.canvas_restore([dir]) } }.to raise_error(SystemExit)
    end
  end

  # --- canvas-restart ---

  describe '.canvas_restart' do
    around do |ex|
      prev = ENV['STREAMWEAVER_SNAPSHOT_ROOT']
      Dir.mktmpdir do |d|
        ENV['STREAMWEAVER_SNAPSHOT_ROOT'] = d
        ex.run
      end
    ensure
      ENV['STREAMWEAVER_SNAPSHOT_ROOT'] = prev
    end

    it 'snapshots, stops, restarts, restores, and warns loudly on a port change' do
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(true)
      allow(StreamWeaver::Canvas::Client).to receive(:read_bridge_info).and_return(pid: 1, port: 4700)
      allow(StreamWeaver::Canvas::Client).to receive(:stop_bridge).and_return(true)
      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return(pid: 2, port: 4701)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        { type: 'list', sessions: [] } if msg[:type] == 'list'
      end

      stdout, stderr = capture_io { described_class.canvas_restart }

      expect(stdout).to include('port 4701')
      expect(stderr).to include('4700 to 4701')
    end

    it 'does not warn when the port is unchanged' do
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(true)
      allow(StreamWeaver::Canvas::Client).to receive(:read_bridge_info).and_return(pid: 1, port: 4700)
      allow(StreamWeaver::Canvas::Client).to receive(:stop_bridge).and_return(true)
      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return(pid: 2, port: 4700)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        { type: 'list', sessions: [] } if msg[:type] == 'list'
      end

      _stdout, stderr = capture_io { described_class.canvas_restart }
      expect(stderr).not_to include('WARNING')
    end
  end
end
