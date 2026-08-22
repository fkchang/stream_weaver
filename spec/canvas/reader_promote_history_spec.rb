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
      expect(File.read(body['path']))
        .to eq("#{StreamWeaver::Canvas::DocStore::STAMP}\nheader1 'Snapshot'")
      expect(body['path']).to start_with(@doc_root)
    end

    # stream_weaver-j3b3: reader has no live session/source_dir, so "repo"
    # scope keeps resolving via DocStore's own auto-detection (here,
    # STREAMWEAVER_DOC_ROOT from the outer `around`) -- unchanged from
    # before this toggle existed. Only the "always writes here regardless"
    # part of scope: :global is new reader behavior.
    describe 'the scope toggle' do
      it "writes via the existing auto-detection when scope is 'repo' (default, unchanged behavior)" do
        post '/save-doc',
             { file: 1, name: 'my-snapshot', scope: 'repo' }.to_json,
             'CONTENT_TYPE' => 'application/json'

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['path']).to start_with(@doc_root)
      end

      it 'writes to DEFAULT_ROOT when scope is global' do
        Dir.mktmpdir do |global_root|
          stub_const('StreamWeaver::Canvas::DocStore::DEFAULT_ROOT', global_root)

          post '/save-doc',
               { file: 1, name: 'my-snapshot', scope: 'global' }.to_json,
               'CONTENT_TYPE' => 'application/json'

          expect(last_response.status).to eq(200)
          body = JSON.parse(last_response.body)
          expect(body['path']).to eq(File.join(global_root, 'my-snapshot.rb'))
        end
      end
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

    # Regression: `index.respond_to?(:to_i)` is true for nil (nil.to_i == 0),
    # so a missing `file` key silently promoted file 0 instead of rejecting
    # the request.
    it 'returns 422 when the file key is missing entirely (does not silently promote file 0)' do
      post '/save-doc',
           { name: 'my-snapshot' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to be false
    end

    # Regression: Array#[] accepts negative indices (wraps to count from the
    # end), so `file: -1` promoted the LAST file in the list instead of being
    # rejected as an invalid index.
    it 'returns 422 for a negative file index (does not wrap to the last file)' do
      post '/save-doc',
           { file: -1, name: 'my-snapshot' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to be false
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

    it 'saves as .org and returns coverage in the JSON response when format=org' do
      post '/save-doc',
           { file: 1, name: 'my-snapshot', format: 'org' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to be true
      expect(body['coverage']).to eq(
        { 'total' => 1, 'recognized' => 0, 'passthrough_verbatim' => 1, 'passthrough_lossy' => 0 }
      )
      saved_path = File.join(StreamWeaver::Canvas::DocStore.path, 'my-snapshot.org')
      expect(body['path']).to eq(saved_path)
      expect(File.exist?(saved_path)).to be true
    end

    it 'still saves as .rb with no coverage field when format is omitted (unchanged default)' do
      post '/save-doc',
           { file: 1, name: 'my-snapshot' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to be true
      expect(body).not_to have_key('coverage')
    end

    it 'does not double the extension when the user already typed .org into the name field' do
      post '/save-doc',
           { file: 1, name: 'my-snapshot.org', format: 'org' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['path']).to end_with('my-snapshot.org')
      expect(body['path']).not_to end_with('.org.org')
    end

    it 'rejects an unrecognized format value instead of silently falling back to .rb' do
      post '/save-doc',
           { file: 1, name: 'my-snapshot', format: 'pdf' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to be false
      expect(body['error']).to include('pdf')
    end

    it 'rejects a non-String name on the org path the same way the .rb path already does (no silent #to_s coercion)' do
      post '/save-doc',
           { file: 1, name: 123, format: 'org' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['ok']).to be false
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

    # Regression for the q4y rendering bug: `name: <%= default_name.to_json %>`
    # rendered literal `"` characters inside the x-data attribute, prematurely
    # closing the attribute and leaking the openDialog/save body as page text.
    # Symptom: dialog buttons inert + raw JS visible above the sidebar.
    #
    # The check below requires that openDialog() AND async save() both appear
    # within a single `[^"]*?` window starting at `<div x-data="` — i.e. with
    # no intervening `"`. If the attribute closes early on an unescaped `"`,
    # the non-greedy match cannot bridge across the closing `"` and the test
    # fails immediately.
    it 'keeps the openDialog/save body inside the x-data attribute (not leaking as text)' do
      match = html.match(/<div\s+x-data="([^"]*?openDialog\(\).*?async save\(\)[^"]*?)"/m)
      expect(match).not_to be_nil,
        'x-data attribute did not contain openDialog() and save() as expected — ' \
        'it likely closed prematurely on an internal double-quote'
    end

    # stream_weaver-j3b3: the reader computes source_dir itself (no session
    # to carry one) via the same git-root auto-detection DocStore.save
    # already used internally -- this spec process's own cwd is a real git
    # repo (this checkout), so the toggle should show, not hide.
    it "shows the This repo toggle, resolved from the reader process's own cwd" do
      source_dir = StreamWeaver::Canvas::DocStore.git_root(Dir.pwd)
      expect(source_dir).not_to be_nil # sanity: this checkout IS a git repo

      expect(html).to include('x-model="scope"')
      expect(html).to include("This repo (#{File.basename(source_dir)})")
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
