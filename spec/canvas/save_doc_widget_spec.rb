# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'

RSpec.describe 'Save-as-doc widget injection' do
  include Rack::Test::Methods

  def app
    StreamWeaver::Canvas::BridgeServer
  end

  around do |ex|
    described_class_app = StreamWeaver::Canvas::BridgeServer
    described_class_app.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    ex.run
  ensure
    described_class_app.bridge = nil
  end

  before do
    StreamWeaver::Canvas::BridgeServer.bridge.create_session('mysession')
  end

  let(:html) do
    get '/canvas/mysession'
    last_response.body
  end

  it 'renders the canvas page successfully' do
    get '/canvas/mysession'
    expect(last_response.status).to eq(200)
  end

  it 'includes a Save as doc button anchored to the session name' do
    expect(html).to include('sw-save-doc-btn')
    expect(html).to match(/Save as doc/i)
  end

  it 'embeds the session name in the save-doc POST URL' do
    expect(html).to include('/canvas/mysession/save-doc')
  end

  it 'pre-fills the dialog with <session>-YYYYMMDD-HHMM' do
    # The default-name JS should reference the session and timestamp pattern.
    expect(html).to include("'mysession-'")
  end

  it 'mounts an Alpine.js x-data component for the dialog' do
    expect(html).to include('x-data')
    expect(html).to include('sw-save-doc-modal')
  end

  it 'styles the floating button (CSS class present)' do
    expect(html).to match(/\.sw-save-doc-btn\b/)
  end
end
