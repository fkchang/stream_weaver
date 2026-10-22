# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'

# Viewer comments (canvas-click-comments): POST /canvas/:name/note holds a note
# on the session; the drain_notes socket command returns and clears them.
RSpec.describe StreamWeaver::Canvas::BridgeServer, 'notes', type: :request do
  include Rack::Test::Methods

  def app = described_class

  let(:bridge) { described_class.bridge }
  let(:note) do
    { text: 'make this clearer', selected_text: 'Revenue', element_text: 'Revenue grew 4%',
      breadcrumb: 'Summary > Results', kind: 'table' }
  end

  around do |ex|
    prev_bridge = described_class.bridge
    prev_conns = described_class.claude_connections
    described_class.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    begin
      ex.run
    ensure
      described_class.bridge = prev_bridge
      described_class.claude_connections = prev_conns
    end
  end

  def post_note(name, payload, raw: nil)
    post "/canvas/#{name}/note", raw || payload.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  def drain(name = nil)
    bridge.handle_claude_message(type: 'drain_notes', name: name)
  end

  it 'stores a note and returns the stored count' do
    bridge.create_session('plan')
    post_note('plan', note)
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq('ok' => true, 'count' => 1)
    post_note('plan', note)
    expect(JSON.parse(last_response.body)['count']).to eq(2)
  end

  it 'drains all notes for a session and clears them' do
    bridge.create_session('plan')
    post_note('plan', note)
    post_note('plan', note.merge(text: 'second'))
    result = drain('plan')
    expect(result[:type]).to eq('notes')
    expect(result[:notes]['plan'].map { |n| n[:text] }).to eq(['make this clearer', 'second'])
    expect(result[:notes]['plan'].first).to include(selected_text: 'Revenue', breadcrumb: 'Summary > Results', kind: 'table')
    expect(drain('plan')[:notes]['plan']).to eq([])
  end

  it 'drains every session that has notes when no name is given' do
    bridge.create_session('a')
    bridge.create_session('b')
    bridge.create_session('quiet')
    post_note('a', note)
    post_note('b', note)
    expect(drain[:notes].keys).to contain_exactly('a', 'b')
    expect(drain[:notes]).to eq({})
  end

  it 'returns an error for draining an unknown session' do
    expect(drain('nope')[:type]).to eq('error')
  end

  it 'never returns the same note twice across concurrent drains' do
    bridge.create_session('plan')
    session = bridge.get_session('plan')
    total = 500
    total.times { |i| session.add_note(text: "n#{i}") }
    results = Array.new(8) { [] }
    threads = results.map do |bucket|
      Thread.new { 50.times { bucket.concat(session.drain_notes) } }
    end
    threads.each(&:join)
    texts = results.flatten.map { |n| n[:text] }
    expect(texts.size).to eq(total)
    expect(texts.uniq.size).to eq(total)
  end

  it 'returns 404 for a session that does not exist' do
    post_note('missing', note)
    expect(last_response.status).to eq(404)
  end

  it 'rejects text over 2 KB with 413' do
    bridge.create_session('plan')
    post_note('plan', note.merge(text: 'x' * 2049))
    expect(last_response.status).to eq(413)
    expect(drain('plan')[:notes]['plan']).to eq([])
  end

  it 'accepts text of exactly 2 KB' do
    bridge.create_session('plan')
    post_note('plan', note.merge(text: 'x' * 2048))
    expect(last_response.status).to eq(200)
  end

  it 'rejects a body over 16 KB with 413' do
    bridge.create_session('plan')
    post_note('plan', note.merge(element_text: 'y' * 17_000))
    expect(last_response.status).to eq(413)
  end

  it 'rejects malformed or textless notes with 422' do
    bridge.create_session('plan')
    post_note('plan', nil, raw: 'not json')
    expect(last_response.status).to eq(422)
    post_note('plan', note.merge(text: '  '))
    expect(last_response.status).to eq(422)
  end

  it 'drops unknown fields' do
    bridge.create_session('plan')
    post_note('plan', note.merge(evil: 'x'))
    expect(drain('plan')[:notes]['plan'].first.keys).not_to include(:evil)
  end

  it 'does not forward a note to socket clients or touch session state' do
    bridge.create_session('plan')
    written = []
    conn = Object.new
    conn.define_singleton_method(:write) { |data| written << data }
    described_class.claude_connections = [conn]
    session = bridge.get_session('plan')
    ws_sent = []
    ws = Object.new
    ws.define_singleton_method(:send) { |data| ws_sent << data }
    session.add_websocket(ws)

    post_note('plan', note)

    expect(written).to be_empty
    expect(ws_sent).to be_empty
    expect(session.state).to eq({})
  end
end
