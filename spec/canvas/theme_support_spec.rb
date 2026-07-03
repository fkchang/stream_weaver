# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'

RSpec.describe 'Canvas theme support' do
  describe StreamWeaver::Canvas::Session do
    it 'defaults theme to :default' do
      session = described_class.new('x')
      expect(session.theme).to eq(:default)
    end

    it 'accepts an explicit theme' do
      session = described_class.new('x', theme: :doc)
      expect(session.theme).to eq(:doc)
    end

    it 'includes theme in to_h' do
      session = described_class.new('x', theme: :doc)
      expect(session.to_h[:theme]).to eq(:doc)
    end
  end

  describe StreamWeaver::Canvas::Protocol::Messages do
    it 'includes theme in the create message, defaulting to :default' do
      expect(described_class.create('x')).to include(theme: :default)
    end

    it 'includes an explicit theme in the create message' do
      expect(described_class.create('x', theme: :doc)).to include(theme: :doc)
    end
  end

  describe StreamWeaver::Canvas::Bridge do
    let(:bridge) { described_class.new(port: 0) }

    it 'creates a session with the requested theme' do
      session = bridge.create_session('x', theme: :doc)
      expect(session.theme).to eq(:doc)
    end

    it 'defaults to :default when no theme is passed' do
      session = bridge.create_session('x')
      expect(session.theme).to eq(:default)
    end

    it 'passes theme through from a create message (string -> symbol)' do
      bridge.handle_claude_message(type: 'create', name: 'x', theme: 'doc')
      expect(bridge.get_session('x').theme).to eq(:doc)
    end
  end

  describe 'GET /canvas/:name', type: :request do
    include Rack::Test::Methods

    def app
      StreamWeaver::Canvas::BridgeServer
    end

    around do |ex|
      prev_bridge = StreamWeaver::Canvas::BridgeServer.bridge
      StreamWeaver::Canvas::BridgeServer.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      ex.run
    ensure
      StreamWeaver::Canvas::BridgeServer.bridge = prev_bridge
    end

    it 'renders sw-theme-doc body class, doc CSS tokens, and data-sw-theme script when theme: :doc' do
      StreamWeaver::Canvas::BridgeServer.bridge.create_session('doc-session', theme: :doc)
      get '/canvas/doc-session'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('class="sw-theme-doc sw-layout-fluid"')
      expect(last_response.body).to include('body.sw-theme-doc')
      expect(last_response.body).to include('data-sw-theme')
    end

    it 'defaults to sw-theme-default when no theme is passed (regression guard)' do
      StreamWeaver::Canvas::BridgeServer.bridge.create_session('default-session')
      get '/canvas/default-session'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('class="sw-theme-default sw-layout-fluid"')
    end
  end
end
