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

  # stream_weaver-j3b3: the This repo/Global scope toggle.
  describe 'the scope toggle' do
    it 'is hidden when the session has no source_dir yet (nothing pushed, or pushed from outside a repo)' do
      expect(StreamWeaver::Canvas::BridgeServer.bridge.get_session('mysession').source_dir).to be_nil
      expect(html).not_to include('This repo')
      expect(html).not_to include('x-model="scope"')
    end

    it "shows 'This repo (<basename>)' with the resolved directory once the session has a source_dir" do
      StreamWeaver::Canvas::BridgeServer.bridge.get_session('mysession').set_source_dir('/Users/someone/work/billing_engine')

      expect(html).to include('x-model="scope"')
      expect(html).to include('This repo (billing_engine)')
      expect(html).to include('/Users/someone/work/billing_engine')
      expect(html).to include('value="repo"')
      expect(html).to include('value="global"')
    end

    it 'defaults the scope to repo when source_dir is present' do
      StreamWeaver::Canvas::BridgeServer.bridge.get_session('mysession').set_source_dir('/repo/one')
      expect(html).to include("scope: 'repo'")
    end

    it 'defaults the scope to global when source_dir is absent' do
      expect(html).to include("scope: 'global'")
    end

    it 'includes scope in the POST body sent by save()' do
      expect(html).to include('scope: this.scope')
    end

    it 'HTML-escapes a source_dir path containing special characters' do
      StreamWeaver::Canvas::BridgeServer.bridge.get_session('mysession').set_source_dir("/tmp/a & b's <repo>")
      expect(html).to include('&amp;')
      expect(html).to include('&#39;')
    end
  end
end
