# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'json'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/doc_store'

RSpec.describe StreamWeaver::Canvas::BridgeServer, type: :request do
  include Rack::Test::Methods

  def app
    described_class
  end

  around do |ex|
    prev_root = ENV['STREAMWEAVER_DOC_ROOT']
    Dir.mktmpdir do |d|
      ENV['STREAMWEAVER_DOC_ROOT'] = d
      @doc_root = d
      prev_bridge = described_class.bridge
      described_class.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      begin
        ex.run
      ensure
        described_class.bridge = prev_bridge
      end
    end
  ensure
    ENV['STREAMWEAVER_DOC_ROOT'] = prev_root
  end

  describe 'POST /canvas/:name/save-doc' do
    it 'returns 404 when session not found' do
      post '/canvas/missing/save-doc',
           { name: 'foo' }.to_json,
           'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(404)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
      expect(body['error']).to include('missing')
    end

    it 'returns 422 when session has no DSL stored yet' do
      described_class.bridge.create_session('s1')
      post '/canvas/s1/save-doc',
           { name: 'foo' }.to_json,
           'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
      expect(body['error']).to match(/no dsl/i)
    end

    it 'writes DSL and returns path on success' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: 'mydoc' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(true)
      expect(body['path']).to be_a(String)
      expect(File.exist?(body['path'])).to eq(true)
      # The session's theme/layout are prepended so canvas-read can re-render
      # the saved doc with the same look (stream_weaver-csf).
      expect(File.read(body['path'])).to eq("use_theme :default\nuse_layout :fluid\nheader1 'Hi'")
      expect(body['path']).to start_with(@doc_root)
    end

    it 'prepends the session theme/layout so the saved doc renders the same in canvas-read' do
      session = described_class.bridge.create_session('s2', theme: :doc, layout: :wide)
      session.set_dsl("header1 'Hi'")

      post '/canvas/s2/save-doc',
           { name: 'themed' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      written = File.read(JSON.parse(last_response.body)['path'])
      expect(written).to eq("use_theme :doc\nuse_layout :wide\nheader1 'Hi'")
    end

    it 'does not double up metadata when the DSL already declares it' do
      session = described_class.bridge.create_session('s3', theme: :doc, layout: :wide)
      session.set_dsl("use_theme :dark\nuse_layout :full\nheader1 'Hi'")

      post '/canvas/s3/save-doc',
           { name: 'already-themed' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      written = File.read(JSON.parse(last_response.body)['path'])
      expect(written).to eq("use_theme :dark\nuse_layout :full\nheader1 'Hi'")
      expect(written.scan(/use_theme/).size).to eq(1)
    end

    it 'accepts a name with .rb suffix and writes the doc' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: 'mydoc.rb' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['path']).to end_with('mydoc.rb')
    end

    it 'returns 422 on invalid name (path traversal)' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: '../evil' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
      expect(body['error']).to match(/invalid doc name/)
    end

    it 'returns 422 when name is missing/nil' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           {}.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
    end

    it 'returns 500 on unexpected errors from DocStore' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      allow(StreamWeaver::Canvas::DocStore)
        .to receive(:save).and_raise(StandardError, 'disk full')

      post '/canvas/s1/save-doc',
           { name: 'mydoc' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(500)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
      expect(body['error']).to include('disk full')
    end
  end
end

RSpec.describe StreamWeaver::Canvas::Session do
  describe '#set_dsl / #dsl' do
    it 'starts as nil and stores the last set DSL' do
      session = described_class.new('s1')
      expect(session.dsl).to be_nil
      session.set_dsl("header1 'Hi'")
      expect(session.dsl).to eq("header1 'Hi'")
      session.set_dsl("header1 'Bye'")
      expect(session.dsl).to eq("header1 'Bye'")
    end
  end
end

RSpec.describe StreamWeaver::Canvas::Bridge do
  describe '#handle_push DSL retention' do
    let(:bridge) { described_class.new(port: 0) }

    before { bridge.create_session('s1') }

    it 'stores DSL on a successful render' do
      bridge.send(:handle_push, 's1', "header1 'Hi'")
      expect(bridge.get_session('s1').dsl).to eq("header1 'Hi'")
    end

    it 'does NOT replace stored DSL when a later render fails' do
      bridge.send(:handle_push, 's1', "header1 'Good'")
      result = bridge.send(:handle_push, 's1', "raise 'boom'")
      expect(result[:type]).to eq('push_error')
      expect(bridge.get_session('s1').dsl).to eq("header1 'Good'")
    end

    it 'leaves DSL nil when the very first push fails' do
      result = bridge.send(:handle_push, 's1', "raise 'boom'")
      expect(result[:type]).to eq('push_error')
      expect(bridge.get_session('s1').dsl).to be_nil
    end
  end
end
