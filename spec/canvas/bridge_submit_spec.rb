# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'rack/test'
require 'tmpdir'
require 'socket'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/client'

# Submit-and-wait (canvas-annotate-review): comments are queued until Send,
# Send releases ONE batch to a waiting agent, and the panel says whether an
# agent is listening.
RSpec.describe 'canvas submit and wait' do
  include Rack::Test::Methods

  def app = StreamWeaver::Canvas::BridgeServer

  let(:server) { StreamWeaver::Canvas::BridgeServer }
  let(:bridge) { server.bridge }
  let(:session) { bridge.get_session('plan') }

  around do |ex|
    prev_bridge = server.bridge
    prev_conns = server.claude_connections
    server.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    begin
      ex.run
    ensure
      server.bridge = prev_bridge
      server.claude_connections = prev_conns
    end
  end

  before { bridge.create_session('plan') }

  def post_note(text, name = 'plan')
    post "/canvas/#{name}/note", { text: text }.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  def post_send(body = nil, name = 'plan')
    post "/canvas/#{name}/send", body ? body.to_json : '', 'CONTENT_TYPE' => 'application/json'
    JSON.parse(last_response.body)
  end

  def side_html = session.region('side')[:html]

  def states = session.notes_snapshot.map { |n| n[:state] }

  it 'stores notes as queued and Send moves all of them to sent' do
    3.times { |i| post_note("n#{i}") }
    expect(states).to eq(%w[queued queued queued])
    expect(post_send).to include('ok' => true, 'sent' => 3, 'ended' => false)
    expect(states).to eq(%w[sent sent sent])
    expect(post_send['sent']).to eq(0)
  end

  it 'Send on an unknown session is a 404' do
    post_send(nil, 'nope')
    expect(last_response.status).to eq(404)
  end

  it 'moves queued to sent exactly once under concurrency' do
    300.times { |i| session.add_note(text: "n#{i}") }
    counts = Array.new(8) { Thread.new { session.send_queued[:sent] } }.map(&:value)
    expect(counts.sum).to eq(300)
    expect(states.uniq).to eq(['sent'])
  end

  it 'a wait started before Send returns the batch once' do
    post_note('one')
    post_note('two')
    waiter = Thread.new { session.wait_for_submit(poll: 0.05) }
    sleep 0.2
    expect(waiter.status).to eq('sleep')
    post_send
    batch = waiter.value
    expect(batch[:notes].map { |n| n[:text] }).to eq(%w[one two])
    expect(batch[:ended]).to be(false)
    expect(states.uniq).to eq(['seen'])
    expect(session.wait_for_submit(poll: 0.02, timeout: 0.2)).to be_nil
  end

  it 'a wait started after Send returns at once with the unread batch' do
    post_note('kept')
    post_send
    batch = session.wait_for_submit(poll: 0.05, timeout: 1)
    expect(batch[:notes].map { |n| n[:text] }).to eq(['kept'])
  end

  it 'two waiters share one batch: exactly one gets it' do
    post_note('solo')
    waiters = Array.new(2) { Thread.new { session.wait_for_submit(poll: 0.02, timeout: 0.8) } }
    sleep 0.2
    post_send
    expect(waiters.map(&:value).compact.size).to eq(1)
  end

  it 'Send & End hands over the batch with ended: true, once, and marks the review ended' do
    post_note('last')
    expect(post_send({ end: true })).to include('sent' => 1, 'ended' => true)
    expect(side_html).to include('Review ended')
    batch = session.wait_for_submit(timeout: 1)
    expect(batch).to include(ended: true)
    expect(batch[:notes].size).to eq(1)
    expect(session.wait_for_submit(poll: 0.02, timeout: 0.15)).to be_nil
  end

  it 'Send & End with nothing queued still ends the review' do
    post_send({ end: true })
    expect(session.wait_for_submit(timeout: 1)).to eq(notes: [], ended: true)
  end

  it 'the plain pull still returns every pending note, queued or sent, and marks them seen' do
    post_note('queued one')
    post_note('to be sent')
    session.send_queued
    post_note('queued after')
    taken = bridge.handle_claude_message(type: 'drain_notes', name: 'plan')[:notes]['plan']
    expect(taken.map { |n| n[:text] }).to eq(['queued one', 'to be sent', 'queued after'])
    expect(states.uniq).to eq(['seen'])
  end

  it 'a Send with no waiter loses nothing and the pull still gets it' do
    post_note('a')
    post_send
    taken = bridge.handle_claude_message(type: 'drain_notes', name: 'plan')[:notes]['plan']
    expect(taken.size).to eq(1)
  end

  describe 'presence' do
    it 'says no agent is listening, with a copyable line, when nobody waits' do
      expect(side_html).to include('No agent is listening', 'tell your agent: ', 'see my comments', 'data-sw-action="copy"')
      expect(side_html).not_to include('Your agent is waiting')
    end

    it 'says the agent is waiting only while a wait is connected, and clears when it is killed' do
      alive = true
      waiter = Thread.new { session.wait_for_submit(alive: -> { alive }, poll: 0.05) }
      sleep 0.2
      expect(side_html).to include('Your agent is waiting')
      expect(side_html).not_to include('No agent is listening')
      version = session.region('side')[:version]

      alive = false
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(waiter.value).to be_nil
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
      expect(side_html).to include('No agent is listening')
      expect(session.region('side')[:version]).to be > version
    end

    it 'is per canvas: a wait on another canvas does not count' do
      bridge.create_session('other')
      waiter = Thread.new { bridge.get_session('other').wait_for_submit(poll: 0.05, timeout: 0.5) }
      sleep 0.15
      expect(side_html).to include('No agent is listening')
      waiter.join
    end

    it 'treats a closed canvas as a wake with closed: true' do
      waiter = Thread.new { session.wait_for_submit(poll: 0.05) }
      sleep 0.15
      bridge.close_session('plan')
      expect(waiter.value).to eq(closed: true)
    end
  end

  it 'shows the same queued and sent comments on reload (page render and poll)' do
    post_note('first')
    post_note('second')
    session.send_queued
    post_note('third')
    expected = %w[Queued Sent Sent] # grouped: ready to send first
    get '/canvas/plan'
    in_page = last_response.body[%r{<aside data-sw-region="side">.*?</aside>}m].scan(/sw-notes-state">(\w+)</)
    expect(in_page.flatten).to eq(expected)
    get '/canvas/plan/poll'
    polled = JSON.parse(last_response.body)['regions']['side']['html'].scan(/sw-notes-state">(\w+)</)
    expect(polled.flatten).to eq(expected)
  end

  it 'never forwards Send to socket clients' do
    written = []
    conn = Object.new
    conn.define_singleton_method(:write) { |d| written << d }
    server.claude_connections = [conn]
    post_note('x')
    post_send
    expect(written).to be_empty
  end

  it 'wait_submit through the bridge returns a typed submitted reply, and a vanished client gets none' do
    post_note('hi')
    post_send
    reply = bridge.handle_claude_message({ type: 'wait_submit', name: 'plan' })
    expect(reply).to include(type: 'submitted', name: 'plan', ended: false)
    expect(reply[:notes].first[:text]).to eq('hi')
    expect(bridge.handle_claude_message({ type: 'wait_submit', name: 'plan' }, -> { false })).to be_nil
    expect(bridge.handle_claude_message({ type: 'wait_submit', name: 'nope' })[:type]).to eq('error')
  end

  describe 'Client.request_typed' do
    around do |ex|
      Dir.mktmpdir('sw') do |dir|
        @sock = File.join(dir, 's')
        @pid = File.join(dir, 'p')
        File.write(@pid, "pid=#{Process.pid}\nport=1\n")
        old = ENV.values_at('STREAMWEAVER_CANVAS_SOCKET', 'STREAMWEAVER_CANVAS_PID')
        ENV['STREAMWEAVER_CANVAS_SOCKET'] = @sock
        ENV['STREAMWEAVER_CANVAS_PID'] = @pid
        begin
          ex.run
        ensure
          ENV['STREAMWEAVER_CANVAS_SOCKET'], ENV['STREAMWEAVER_CANVAS_PID'] = old
        end
      end
    end

    before { allow(StreamWeaver::Canvas::StalenessGuard).to receive(:ensure_current!) }

    def fake_bridge(frames)
      listener = UNIXServer.new(@sock)
      Thread.new do
        conn = listener.accept
        conn.readpartial(4096)
        frames.each do |f|
          conn.write(StreamWeaver::Canvas::Protocol.encode(f))
          sleep 0.05
        end
        sleep 0.2
        conn.close
      ensure
        listener.close
      end
    end

    it 'ignores event frames that arrive mid-wait and returns its own typed reply' do
      event = { type: 'event', name: 'plan', event: 'click', data: { button: 'ok' } }
      submitted = { type: 'submitted', name: 'plan', notes: [{ text: 'hi' }], ended: false }
      thread = fake_bridge([event, event, submitted])
      reply = StreamWeaver::Canvas::Client.request_typed(
        StreamWeaver::Canvas::Protocol::Messages.wait_submit('plan'), types: %w[submitted error closed], timeout: 5
      )
      thread.join
      expect(reply).to include(type: 'submitted')
      expect(reply[:notes]).to eq([{ text: 'hi' }])
    end

    it 'returns nil when the bridge hangs up without a typed reply' do
      event = { type: 'event', name: 'plan', event: 'click', data: {} }
      thread = fake_bridge([event])
      reply = StreamWeaver::Canvas::Client.request_typed(
        StreamWeaver::Canvas::Protocol::Messages.wait_submit('plan'), types: %w[submitted], timeout: 5
      )
      thread.join
      expect(reply).to be_nil
    end
  end

  describe 'BridgeServer.connection_alive?' do
    it 'is true for a live peer and false once the peer closes' do
      a, b = UNIXSocket.pair
      expect(server.connection_alive?(a)).to be(true)
      b.close
      expect(server.connection_alive?(a)).to be(false)
      a.close
    end

    it 'stays true while the peer has unread bytes pending' do
      a, b = UNIXSocket.pair
      b.write('x')
      expect(server.connection_alive?(a)).to be(true)
      expect(a.read_nonblock(1)).to eq('x')
    ensure
      a.close
      b.close
    end
  end
end
