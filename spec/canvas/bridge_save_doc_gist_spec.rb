# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'json'
require 'rack/test'
require 'open3'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/doc_store'
require 'stream_weaver/canvas/gist_store'
require 'stream_weaver/canvas/gist_publisher'

# scope == 'gist' branch of POST /canvas/:name/save-doc (share-to-gist epic,
# bridge-canvas-gist-endpoint story). Follows bridge_save_doc_spec.rb's
# Dir.mktmpdir + ENV around-hook idiom, plus a STREAMWEAVER_GIST_STORE
# override and an Open3.capture3 stub -- nothing here may shell out to a
# real `gh` or touch the network.
RSpec.describe StreamWeaver::Canvas::BridgeServer, type: :request do
  include Rack::Test::Methods

  def app
    described_class
  end

  around do |ex|
    prev_doc_root = ENV['STREAMWEAVER_DOC_ROOT']
    prev_gist_store = ENV['STREAMWEAVER_GIST_STORE']
    Dir.mktmpdir do |d|
      ENV['STREAMWEAVER_DOC_ROOT'] = d
      ENV['STREAMWEAVER_GIST_STORE'] = File.join(d, 'gists.json')
      prev_bridge = described_class.bridge
      described_class.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      begin
        ex.run
      ensure
        described_class.bridge = prev_bridge
      end
    end
  ensure
    ENV['STREAMWEAVER_DOC_ROOT'] = prev_doc_root
    ENV['STREAMWEAVER_GIST_STORE'] = prev_gist_store
  end

  def gh_response(id: 'abc123', revisions: 1)
    {
      'id' => id,
      'html_url' => "https://gist.github.com/someone/#{id}",
      'history' => Array.new(revisions) { |i| { 'version' => format('%040d', i) } }
    }.to_json
  end

  def ok_status
    instance_double(Process::Status, success?: true, exitstatus: 0)
  end

  def fail_status(code = 1)
    instance_double(Process::Status, success?: false, exitstatus: code)
  end

  # Records every capture3 invocation so examples can assert on exact argv.
  def stub_capture3(*results)
    calls = []
    queue = results.dup
    allow(Open3).to receive(:capture3) do |*argv, **opts|
      calls << { argv: argv, stdin: opts[:stdin_data] }
      queue.shift || raise('unexpected extra Open3.capture3 call')
    end
    calls
  end

  describe "POST /canvas/:name/save-doc with scope: 'gist'" do
    it 'returns 200 with gist_url/gist_id/revisions/action on a successful publish' do
      calls = stub_capture3([gh_response(id: 'abc123', revisions: 1), '', ok_status])
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: 'shared-doc', scope: 'gist' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(true)
      expect(body['gist_url']).to eq('https://gist.github.com/someone/abc123')
      expect(body['gist_id']).to eq('abc123')
      expect(body['revisions']).to eq(1)
      expect(body['action']).to eq('create')
      expect(calls.length).to eq(1)
      expect(calls[0][:argv]).to eq(['gh', 'api', '-X', 'POST', '/gists', '--input', '-'])

      # Recorded so the next save updates the same gist instead of minting one.
      expect(StreamWeaver::Canvas::GistStore.lookup('shared-doc')['id']).to eq('abc123')
    end

    it 'returns 404 when the session is not found (unaffected by the gist branch)' do
      post '/canvas/missing/save-doc',
           { name: 'foo', scope: 'gist' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(404)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
    end

    it 'returns 422 when the session has no DSL stored yet (unaffected by the gist branch)' do
      described_class.bridge.create_session('s1')

      post '/canvas/s1/save-doc',
           { name: 'foo', scope: 'gist' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
      expect(body['error']).to match(/no dsl/i)
    end

    it 'returns 422 on an invalid doc name via the propagated ArgumentError' do
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: '../evil', scope: 'gist' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
      expect(body['error']).to match(/invalid doc name/)
    end

    it 'returns 502 with the error surfaced when GistPublisher.publish reports failure' do
      allow(StreamWeaver::Canvas::GistPublisher)
        .to receive(:publish).and_return({ ok: false, error: 'gh timed out after 20s talking to GitHub' })
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: 'shared-doc', scope: 'gist' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(502)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
      expect(body['error']).to eq('gh timed out after 20s talking to GitHub')
    end

    it 'returns 500 on an unexpected StandardError from the publisher' do
      allow(StreamWeaver::Canvas::GistPublisher)
        .to receive(:publish).and_raise(StandardError, 'boom')
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: 'shared-doc', scope: 'gist' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(500)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(false)
      expect(body['error']).to include('boom')
    end

    it 'does not fail the response when GistStore.record raises -- returns ok:true with a warning instead' do
      calls = stub_capture3([gh_response, '', ok_status])
      allow(StreamWeaver::Canvas::GistStore).to receive(:record).and_raise(StandardError, 'disk full')
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: 'shared-doc', scope: 'gist' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to eq(true)
      expect(body['gist_url']).to eq('https://gist.github.com/someone/abc123')
      expect(body['warning']).to match(/disk full/)
      expect(calls.length).to eq(1)
    end

    it 'passes the existing gist id to GistPublisher.publish on a second save for the same doc name' do
      StreamWeaver::Canvas::GistStore.record('shared-doc', id: 'oldid1', url: 'https://gist.github.com/someone/oldid1', revisions: 1)
      calls = stub_capture3([gh_response(id: 'oldid1', revisions: 2), '', ok_status])
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: 'shared-doc', scope: 'gist' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      expect(calls[0][:argv]).to eq(['gh', 'api', '-X', 'PATCH', '/gists/oldid1', '--input', '-'])
      body = JSON.parse(last_response.body)
      expect(body['action']).to eq('update')
      expect(body['revisions']).to eq(2)
    end

    it 'falls back to creating a fresh gist, and records exactly one entry under the new id, when the recorded gist was deleted upstream (404 on PATCH)' do
      StreamWeaver::Canvas::GistStore.record('shared-doc', id: 'oldid1', url: 'https://gist.github.com/someone/oldid1', revisions: 1)
      calls = stub_capture3(
        [nil, 'HTTP 404: Not Found', fail_status(404)],
        [gh_response(id: 'newid2', revisions: 1), '', ok_status]
      )
      session = described_class.bridge.create_session('s1')
      session.set_dsl("header1 'Hi'")

      post '/canvas/s1/save-doc',
           { name: 'shared-doc', scope: 'gist' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['action']).to eq('create')
      expect(body['gist_id']).to eq('newid2')
      expect(calls.map { |c| c[:argv][3] }).to eq(%w[PATCH POST])

      # GistStore is keyed by doc name, not gist id -- the single entry for
      # 'shared-doc' is simply overwritten with the fresh id, with nothing
      # left behind under the stale id to clean up.
      expect(StreamWeaver::Canvas::GistStore.all.keys).to eq(['shared-doc'])
      expect(StreamWeaver::Canvas::GistStore.lookup('shared-doc')['id']).to eq('newid2')
    end
  end
end
