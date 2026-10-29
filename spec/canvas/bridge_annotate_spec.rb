# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'

# Annotate mode is held on the session: the panel header carries the toggle, a
# reload or a second tab reads the same flag, and none of it leaks into the doc.
RSpec.describe StreamWeaver::Canvas::BridgeServer, 'annotate mode', type: :request do
  include Rack::Test::Methods

  def app = described_class

  let(:bridge) { described_class.bridge }

  around do |ex|
    prev_bridge = described_class.bridge
    described_class.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    begin
      ex.run
    ensure
      described_class.bridge = prev_bridge
    end
  end

  def set_annotate(name, on)
    post "/canvas/#{name}/annotate", { on: on }.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  before { bridge.create_session('plan') }

  it 'starts off and the page carries no annotate class' do
    get '/canvas/plan'
    expect(last_response.body).not_to include('sw-annotate-on">')
    expect(bridge.get_session('plan')).not_to be_annotate
  end

  it 'turns on, shows on the poll and on a fresh page load (second tab)' do
    set_annotate('plan', true)
    expect(JSON.parse(last_response.body)).to include('annotate' => true)
    get '/canvas/plan/poll'
    expect(JSON.parse(last_response.body)['annotate']).to be(true)
    get '/canvas/plan'
    expect(last_response.body).to match(/<body class="[^"]*sw-annotate-on"/)
    set_annotate('plan', false)
    get '/canvas/plan/poll'
    expect(JSON.parse(last_response.body)['annotate']).to be(false)
  end

  it 'puts the toggle in the panel header and moves the region version when it flips' do
    session = bridge.get_session('plan')
    before = session.region('side')
    set_annotate('plan', true)
    after = session.region('side')
    expect(after[:version]).to be > before[:version]
    expect(after[:html]).to include('data-sw-action="annotate-toggle"').and include('aria-pressed="true"')
    expect(before[:html]).to include('aria-pressed="false"')
  end

  it 'rejects a missing or non-boolean value and an unknown session' do
    post '/canvas/plan/annotate', { on: 'yes' }.to_json, 'CONTENT_TYPE' => 'application/json'
    expect(last_response.status).to eq(422)
    set_annotate('nope', true)
    expect(last_response.status).to eq(404)
  end

  it 'keeps the chrome out of the doc html that canvas-read and export use' do
    session = bridge.get_session('plan')
    session.set_html('<p>doc</p>')
    set_annotate('plan', true)
    expect(session.html).not_to include('annotate')
    expect(session.html).not_to include('sw-notes')
  end

  it 'ships the layout rules: 320px panel, 352px padding, bottom sheet under 860px, no top bar' do
    js = File.read(File.join(__dir__, '../../lib/stream_weaver/assets/js/sw-canvas-notes.js'))
    expect(js).to include('width:320px').and include('padding-right:352px')
    expect(js).to include('max-width:859px').and include('height:40vh')
    expect(js).not_to match(/position:fixed;top:0;left:0;right:0/)
  end
end
