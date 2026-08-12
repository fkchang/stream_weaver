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

    it 'pins cascade layer order and wraps SW_STYLES in the framework layer (stream_weaver-oeo)' do
      # Regression guard: SW_STYLES was left unlayered while master_theme_css
      # and visual_skills_css were layered around it. Per the cascade-layers
      # spec, unlayered rules beat every layer regardless of specificity or
      # order -- so SW_STYLES silently won every property it shares with
      # master_theme_css (body margin/padding/font, #app-container padding/
      # radius/shadow), undoing the theme wherever the two collide.
      StreamWeaver::Canvas::BridgeServer.bridge.create_session('layer-session')
      get '/canvas/layer-session'
      body = last_response.body

      # Layer order pinned before any framework CSS, matching views.rb's head.
      pin_index = body.index('@layer stream-weaver;')
      expect(pin_index).not_to be_nil

      # SW_STYLES-only rule (--sw-radius-md is unique to it; master_theme_css
      # uses --sw-radius-lg for #app-container) must be inside the layer.
      expect(body).to match(/@layer stream-weaver \{\n[^@]*--sw-radius-md/m)
      expect(pin_index).to be < body.index('--sw-radius-md')
    end
  end
end
