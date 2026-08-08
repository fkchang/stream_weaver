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
      # the saved doc with the same look (stream_weaver-csf), and the whole
      # thing gets the stamp DocStore.save always adds on top (outermost,
      # since dsl_with_metadata runs first and save's stamp() wraps its result).
      expect(File.read(body['path']))
        .to eq("#{StreamWeaver::Canvas::DocStore::STAMP}\nuse_theme :default\nuse_layout :fluid\nheader1 'Hi'")
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

    it 'saves as .org and returns coverage in the JSON response when format=org' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl(%(md "hello"\ntable(headers: ["A"], rows: [["1"]])\n))

      post '/canvas/s1/save-doc',
           { name: 'mydoc', format: 'org' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(true)
      expect(body['coverage']).to eq(
        { 'total' => 2, 'recognized' => 2, 'passthrough_verbatim' => 0, 'passthrough_lossy' => 0 }
      )
      saved_path = File.join(StreamWeaver::Canvas::DocStore.path, 'mydoc.org')
      expect(body['path']).to eq(saved_path)
      expect(File.exist?(saved_path)).to eq(true)
    end

    it 'still saves as .rb with no coverage field when format is omitted (unchanged default)' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: 'mydoc' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(true)
      expect(body).not_to have_key('coverage')
      expect(body['path']).to end_with('mydoc.rb')
    end

    it 'does not double the extension when the user already typed .org into the name field' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl(%(md "hello"\n))

      post '/canvas/s1/save-doc',
           { name: 'mydoc.org', format: 'org' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['path']).to end_with('mydoc.org')
      expect(body['path']).not_to end_with('.org.org')
    end

    it 'rejects an unrecognized format value instead of silently falling back to .rb' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl(%(md "hello"\n))

      post '/canvas/s1/save-doc',
           { name: 'mydoc', format: 'pdf' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
      expect(body['error']).to include('pdf')
    end

    it 'rejects a non-String name on the org path the same way the .rb path already does (no silent #to_s coercion)' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl(%(md "hello"\n))

      post '/canvas/s1/save-doc',
           { name: 123, format: 'org' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
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
