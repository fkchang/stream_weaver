# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'

# Unsent comments can be edited and removed from the panel; once sent they are
# the agent's and the routes answer 404. The panel list carries what the
# browser needs to find the element again, all escaped.
RSpec.describe StreamWeaver::Canvas::BridgeServer, 'note edit and remove', type: :request do
  include Rack::Test::Methods

  def app = described_class

  let(:bridge) { described_class.bridge }
  let(:session) { bridge.get_session('plan') }

  around do |ex|
    prev_bridge = described_class.bridge
    described_class.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    begin
      ex.run
    ensure
      described_class.bridge = prev_bridge
    end
  end

  before do
    bridge.create_session('plan')
    session.add_note(text: 'first', kind: 'td', element_text: 'Q3 "x" <b>', breadcrumb: 'A > B')
    session.add_note(text: 'second', kind: 'p')
  end

  def patch_note(id, payload = nil, raw: nil)
    patch "/canvas/plan/note/#{id}", raw || payload.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  it 'edits a queued note and re-renders the panel' do
    patch_note(1, { text: 'changed' })
    expect(last_response.status).to eq(200)
    expect(session.notes_snapshot.first[:text]).to eq('changed')
    expect(session.region('side')[:html]).to include('changed')
  end

  it 'removes a queued note and the count drops' do
    expect(session.region('side')[:html]).to include('2 unsent')
    delete '/canvas/plan/note/1'
    expect(last_response.status).to eq(200)
    expect(session.notes_snapshot.map { |n| n[:text] }).to eq(['second'])
    expect(session.region('side')[:html]).to include('1 unsent')
  end

  it 'answers 404 for a sent, unknown or missing note, and for an unknown session' do
    session.send_queued
    patch_note(1, { text: 'late' })
    expect(last_response.status).to eq(404)
    delete '/canvas/plan/note/1'
    expect(last_response.status).to eq(404)
    delete '/canvas/plan/note/99'
    expect(last_response.status).to eq(404)
    delete '/canvas/nope/note/1'
    expect(last_response.status).to eq(404)
    expect(session.notes_snapshot.map { |n| n[:text] }).to eq(%w[first second])
  end

  it 'applies the POST caps and validation to PATCH' do
    patch_note(1, { text: '  ' })
    expect(last_response.status).to eq(422)
    patch_note(1, { text: 'x' * (2 * 1024 + 1) })
    expect(last_response.status).to eq(413)
    patch_note(1, raw: 'x' * (16 * 1024 + 1))
    expect(last_response.status).to eq(413)
  end

  it 'shows edit and remove only on queued pills, and escapes the element data' do
    html = session.region('side')[:html]
    expect(html.scan('data-sw-action="remove"').size).to eq(2)
    expect(html).to include('data-sw-kind="td"').and include('Q3 &quot;x&quot;')
    expect(html).not_to include('"x"')
    session.send_queued
    expect(session.region('side')[:html]).not_to include('data-sw-action="remove"')
    expect(session.region('side')[:html]).to include('0 unsent')
  end

  it 'ships the composer title, highlight classes and the element-changed pill in the overlay' do
    js = File.read(File.join(__dir__, '../../lib/stream_weaver/assets/js/sw-canvas-notes.js'))
    expect(js).to include("'Annotate <' + ctx.kind + '>'").and include('sw-hl-sel').and include('sw-notes-gone')
  end
end
