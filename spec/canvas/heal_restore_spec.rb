# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/canvas/bridge_server'
require_relative '../support/canvas_events_helper'

# A restart used to drop every session whose DSL the bridge did not hold at
# that moment, silently, and open tabs then showed "Session Complete". The
# newest pushed DSL is in history/, so the snapshot keeps it, restore keeps
# empty sessions alive, and anything still lost is named in the event log.
RSpec.describe 'canvas restart keeps and names what it carries' do
  let(:client) { StreamWeaver::Canvas::Client }
  include CanvasEventsHelper

  let(:cli) { StreamWeaver::CLI }

  around do |example|
    Dir.mktmpdir('heal-restore') do |dir|
      @dir = dir
      old = ENV.values_at('STREAMWEAVER_HISTORY_ROOT', 'STREAMWEAVER_CANVAS_EVENTS')
      ENV['STREAMWEAVER_HISTORY_ROOT'] = File.join(dir, 'history')
      ENV['STREAMWEAVER_CANVAS_EVENTS'] = File.join(dir, 'events.jsonl')
      example.run
    ensure
      ENV['STREAMWEAVER_HISTORY_ROOT'], ENV['STREAMWEAVER_CANVAS_EVENTS'] = old
    end
  end

  def events = canvas_events

  def quiet
    old = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = old
  end

  def keep_in_history(name, dsl)
    dir = File.join(ENV['STREAMWEAVER_HISTORY_ROOT'], name)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, '20261105_190000.rb'), dsl)
  end

  # A current bridge: understands get_dsl, holds a DSL for some sessions only.
  def stub_bridge(held)
    allow(client).to receive(:bridge_running?).and_return(true)
    allow(client).to receive(:send_message) do |msg|
      case msg[:type]
      when 'list' then { type: 'sessions', sessions: held.keys.map { |n| { name: n } } }
      when 'get_dsl' then { type: 'dsl', name: msg[:name], dsl: held[msg[:name]], theme: 'default', layout: 'fluid' }
      end
    end
  end

  it 'snapshots a live session that holds no DSL from its newest history push' do
    keep_in_history('today-focus', "header1 'from history'")
    stub_bridge('today-focus' => nil, 'held' => "header1 'live'")

    result = quiet { cli.do_canvas_snapshot(File.join(@dir, 'snap')) }

    entry = result[:sessions].find { |s| s['name'] == 'today-focus' }
    expect(entry).to include('has_content' => true, 'source' => 'history')
    expect(File.read(File.join(@dir, 'snap', 'today-focus.rb'))).to eq("header1 'from history'")
    expect(result[:sessions].find { |s| s['name'] == 'held' }).to include('source' => 'bridge')
  end

  it 'prefers the live DSL over history when the bridge has one' do
    keep_in_history('s', "header1 'old'")
    stub_bridge('s' => "header1 'live'")

    quiet { cli.do_canvas_snapshot(File.join(@dir, 'snap')) }

    expect(File.read(File.join(@dir, 'snap', 's.rb'))).to eq("header1 'live'")
  end

  it 'names a session it still cannot carry, one session_dropped event each' do
    stub_bridge('nothing-anywhere' => nil)

    quiet { cli.do_canvas_snapshot(File.join(@dir, 'snap')) }

    dropped = events.select { |e| e['event'] == 'session_dropped' }
    expect(dropped.map { |e| e['session_name'] }).to eq(%w[nothing-anywhere])
    expect(dropped.first['cause']).to eq('bridge_restart')
  end

  it 'does not let history make an empty live session look occupied (restore guard)' do
    keep_in_history('s', "header1 'old'")
    stub_bridge('s' => nil)

    expect(cli.existing_sessions_with_content).to eq('s' => false)
  end

  it 'records session_restore_failed when a restored push is refused' do
    dir = File.join(@dir, 'snap')
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, 'manifest.yml'),
               YAML.dump('sessions' => [{ 'name' => 'bad', 'has_content' => true, 'theme' => 'default', 'layout' => 'fluid' }]))
    File.write(File.join(dir, 'bad.rb'), 'oops')
    allow(client).to receive(:ensure_bridge_running)
    allow(client).to receive(:bridge_running?).and_return(false)
    allow(client).to receive(:send_message) do |msg|
      msg[:type] == 'create' ? { type: 'ready' } : { type: 'push_error', message: 'boom' }
    end

    quiet { cli.do_canvas_restore(dir) }

    expect(events.map { |e| [e['event'], e['session_name']] }).to include(%w[session_restore_failed bad])
  end

  describe 'bridge_start' do
    it 'carries the cause, the caller and the code stamp handed to the new bridge' do
      stub_const('ENV', ENV.to_h.merge('SW_BRIDGE_START_CAUSE' => 'bridge_restart', 'SW_BRIDGE_START_DETAIL' => 'staleness_heal',
                                       'SW_BRIDGE_START_CALLER' => JSON.generate(pid: 77, command: 'streamweaver panel x')))

      StreamWeaver::Canvas::BridgeServer.record_start

      expect(events.last['event']).to eq('bridge_start')
      expect(events.last['code']).to eq(StreamWeaver::Canvas::CodeStamp.fingerprint)
      expect(events.last).to include('cause' => 'bridge_restart', 'detail' => 'staleness_heal',
                                     'caller' => { 'pid' => 77, 'command' => 'streamweaver panel x' })
    end

    it 'ignores a malformed caller instead of failing the boot' do
      expect(StreamWeaver::Canvas::BridgeServer.parse_caller('{not json')).to be_nil
      expect(StreamWeaver::Canvas::BridgeServer.parse_caller(nil)).to be_nil
    end
  end

  it 'announce_start hands the next spawned bridge its cause, detail and caller, once' do
    client.announce_start(cause: 'bridge_restart', detail: 'canvas_restart')

    env = client.take_start_env
    expect(env.values_at('SW_BRIDGE_START_CAUSE', 'SW_BRIDGE_START_DETAIL')).to eq(%w[bridge_restart canvas_restart])
    expect(JSON.parse(env['SW_BRIDGE_START_CALLER'])).to include('pid' => Process.pid)
    expect(client.take_start_env).to eq({})
    expect(client.bridge_spawn_command('/tmp/x.rb').first).not_to include('SW_BRIDGE_START_CAUSE')
  end

  it 'fails the restore when an empty session cannot be recreated' do
    dir = File.join(@dir, 'snap')
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, 'manifest.yml'),
               YAML.dump('sessions' => [{ 'name' => 'e', 'has_content' => false, 'theme' => 'default', 'layout' => 'fluid' }]))
    allow(client).to receive(:ensure_bridge_running)
    allow(client).to receive(:bridge_running?).and_return(false)
    allow(client).to receive(:send_message).and_return({ type: 'error' })

    expect(quiet { cli.do_canvas_restore(dir) }).to be(false)
  end
end
