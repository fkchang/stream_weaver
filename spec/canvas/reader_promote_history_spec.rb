# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'rack/test'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/canvas/doc_store'

RSpec.describe StreamWeaver::Canvas::Reader, 'promote-from-history' do
  include Rack::Test::Methods
  def app
    described_class
  end

  around do |ex|
    prev_doc = ENV['STREAMWEAVER_DOC_ROOT']
    Dir.mktmpdir do |outer|
      Dir.mktmpdir do |doc_root|
        ENV['STREAMWEAVER_DOC_ROOT'] = doc_root
        @doc_root = doc_root

        @docs_dir     = File.join(outer, 'docs')
        @history_root = File.join(outer, 'history')
        @session      = File.join(@history_root, 'brainstorm')
        [@docs_dir, @session].each { |d| FileUtils.mkdir_p(d) }

        File.write(File.join(@docs_dir, 'arch.rb'),                "header1 'Arch'")
        File.write(File.join(@session, '20260427_143012.rb'),       "header1 'Snapshot'")

        list = StreamWeaver::Canvas::Reader::FileList.build(
          [@docs_dir, @session],
          history_roots: [@history_root]
        )
        described_class.configure_files!(list)
        ex.run
      end
    end
  ensure
    ENV['STREAMWEAVER_DOC_ROOT'] = prev_doc
  end

  describe 'POST /save-doc' do
    it 'writes file and returns path on success' do
      post '/save-doc',
           { file: 1, name: 'my-snapshot' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to be true
      expect(body['path']).to be_a(String)
      expect(File.exist?(body['path'])).to be true
      expect(File.read(body['path'])).to eq("header1 'Snapshot'")
      expect(body['path']).to start_with(@doc_root)
    end

    it 'returns 422 when file index is out of range' do
      post '/save-doc',
           { file: 999, name: 'my-snapshot' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to be false
      expect(body['error']).to match(/index/i)
    end

    it 'returns 422 when name is invalid (ArgumentError from DocStore)' do
      post '/save-doc',
           { file: 1, name: '../evil' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to be false
      expect(body['error']).to match(/invalid doc name/)
    end

    it 'returns 500 on unexpected errors from DocStore' do
      allow(StreamWeaver::Canvas::DocStore)
        .to receive(:save).and_raise(StandardError, 'disk full')

      post '/save-doc',
           { file: 1, name: 'my-snapshot' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(500)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to be false
      expect(body['error']).to include('disk full')
    end

    it 'returns 404 when no file list is configured' do
      prev = described_class.file_list
      described_class.configure_files!(nil)
      begin
        post '/save-doc',
             { file: 0, name: 'foo' }.to_json,
             'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(404)
        body = JSON.parse(last_response.body)
        expect(body['ok']).to be false
      ensure
        described_class.configure_files!(prev)
      end
    end
  end

  describe 'GET / for a history file' do
    let(:html) do
      get '/?file=1'
      last_response.body
    end

    it 'renders the floating Save-as-doc button' do
      expect(html).to include('sw-save-doc-btn')
    end

    it 'renders the Alpine modal dialog markup' do
      expect(html).to include('sw-save-doc-dialog')
      expect(html).to include('sw-save-doc-modal')
    end

    it 'pre-fills the default name as <session>-<timestamp>' do
      expect(html).to include('brainstorm-20260427_143012')
    end

    it 'POSTs to /save-doc with the current file index' do
      expect(html).to include("'/save-doc'")
      expect(html).to match(/file:\s*1\b/)
    end
  end

  describe 'GET / for a docs file' do
    let(:html) do
      get '/?file=0'
      last_response.body
    end

    it 'does NOT render the Save-as-doc button (already saved)' do
      expect(html).not_to include('sw-save-doc-btn')
    end

    it 'does NOT render the modal dialog' do
      expect(html).not_to include('sw-save-doc-dialog')
    end
  end
end
