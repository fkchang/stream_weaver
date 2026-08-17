# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'rack/test'
require 'tmpdir'
require 'fileutils'
require 'stream_weaver/canvas/reader'

# POST /delete-doc (stream_weaver-uvaj): the one destructive operation
# canvas-read offers, so its boundary is the point of the whole feature.
# Deletable is exactly two roots -- the repo THIS process was launched in and
# the global store -- and both are resolved from this process's own state, not
# from anything a client sends. Every other doc the multi-repo discovery
# surfaces is readable and permanently undeletable.
RSpec.describe StreamWeaver::Canvas::Reader, 'delete a saved doc' do
  include Rack::Test::Methods
  def app = described_class

  # Host repo (two docs), the global store (one), and a peer repo the scan
  # would surface for reading (one) -- plus two decoys outside every root.
  around do |ex|
    Dir.mktmpdir do |tmp|
      @tmp       = tmp
      @repo_git  = File.join(tmp, 'hostrepo')
      @repo      = File.join(@repo_git, StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
      @global    = File.join(tmp, 'globalstore')
      @peer      = File.join(tmp, 'peerrepo', StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
      # Name deliberately prefixed by @repo: a start_with? containment check
      # would accept this directory as "inside" the docs root.
      @evil      = "#{@repo}_evil"
      [@repo, @global, @peer, @evil].each { |d| FileUtils.mkdir_p(d) }

      File.write(alpha,  "header1 'Alpha'")
      File.write(bravo,  "header1 'Bravo'")
      File.write(global_doc, "header1 'Global'")
      File.write(peer_doc,   "header1 'Peer'")
      File.write(evil_doc,   "header1 'Evil'")
      File.write(outsider,   "header1 'Outside every root'")
      ex.run
    end
  end

  def alpha      = File.join(@repo,   'alpha.rb')
  def bravo      = File.join(@repo,   'bravo.rb')
  def global_doc = File.join(@global, 'global-doc.rb')
  def peer_doc   = File.join(@peer,   'peer-doc.rb')
  def evil_doc   = File.join(@evil,   'evil.rb')
  def outsider   = File.join(@tmp,    'outsider.rb')

  # git_root is what Reader.repo_docs_root builds the host docs root from, and
  # DEFAULT_ROOT is a constant pointing at the developer's real
  # ~/.streamweaver/canvas -- neither may be left pointing at the real machine
  # in a spec whose whole subject is deleting files.
  before do
    allow(StreamWeaver::Canvas::DocStore).to receive(:git_root).and_return(@repo_git)
    stub_const('StreamWeaver::Canvas::DocStore::DEFAULT_ROOT', @global)
    configure_list([@repo, @global, @peer])
  end

  after { described_class.configure_files!(nil) }

  # Indices are positions in the whole list, in arg order:
  #   0 alpha, 1 bravo (host repo) | 2 global-doc | 3 peer-doc
  def configure_list(dirs)
    labels = { @repo => 'hostrepo', @global => 'Global', @peer => 'peerrepo' }
    described_class.configure_files!(
      described_class::FileList.build(dirs, labels: labels.slice(*dirs))
    )
  end

  def delete_doc(path, file: nil)
    post '/delete-doc', { path: path, file: file }.to_json, 'CONTENT_TYPE' => 'application/json'
    last_response
  end

  def json = JSON.parse(last_response.body)

  describe 'deleting from an owned root' do
    it 'removes a doc in the host repo and reports where to land' do
      res = delete_doc(alpha, file: 0)

      expect(res.status).to eq(200)
      expect(json['ok']).to be(true)
      expect(File.exist?(alpha)).to be(false)
      # bravo slid into position 0, so the open index doesn't move.
      expect(json['file']).to eq(0)
    end

    it 'removes a doc in the global store' do
      res = delete_doc(global_doc, file: 2)

      expect(res.status).to eq(200)
      expect(File.exist?(global_doc)).to be(false)
      expect(File.exist?(alpha)).to be(true)
    end

    it 'drops both deleted docs out of the sidebar on the next render' do
      delete_doc(alpha, file: 0)
      delete_doc(global_doc, file: 0)

      # Asserted on the full paths (each row's title attribute), not the bare
      # stem: "alpha" also appears as a local variable in the inlined mermaid
      # zoom script, which would make a stem match pass or fail for reasons
      # that have nothing to do with the sidebar.
      get '/?file=0&repo=all'
      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to include(alpha)
      expect(last_response.body).not_to include(global_doc)
      expect(last_response.body).to include(bravo)
    end

    # A .rb/.org pair are two rows and two independent deletes -- removing
    # one must never take its same-stem sibling with it.
    it 'deletes only the named file, not its same-stem sibling' do
      org = File.join(@repo, 'alpha.org')
      File.write(org, "#+STREAMWEAVER_DSL: 1\n#+TITLE: Alpha\n")
      configure_list([@repo, @global, @peer])

      delete_doc(alpha)

      expect(File.exist?(alpha)).to be(false)
      expect(File.exist?(org)).to be(true)
    end
  end

  describe 'refusing anything outside the two owned roots' do
    # Every one of these constructs the request directly rather than going
    # through the UI: the sidebar not offering a button is a courtesy, the
    # server-side check is the actual boundary.
    it 'refuses a ../ traversal out of a docs root' do
      res = delete_doc(File.join(@repo, '..', '..', '..', 'outsider.rb'))

      expect(res.status).to eq(403)
      expect(json['ok']).to be(false)
      expect(File.exist?(outsider)).to be(true)
    end

    it 'refuses a symlink inside the root that points out of it' do
      link = File.join(@repo, 'escape.rb')
      File.symlink(outsider, link)

      res = delete_doc(link)

      expect(res.status).to eq(403)
      expect(File.exist?(outsider)).to be(true)
      expect(File.symlink?(link)).to be(true)
    end

    it "refuses a peer repo's doc, even though the sidebar lists it" do
      get '/?file=0&repo=all'
      expect(last_response.body).to include('peer-doc')

      res = delete_doc(peer_doc, file: 3)

      expect(res.status).to eq(403)
      expect(File.exist?(peer_doc)).to be(true)
    end

    # The reason containment is equality on the canonical parent rather than
    # start_with?: this path IS prefixed by the docs root.
    it 'refuses a sibling directory whose name merely starts with the root' do
      res = delete_doc(evil_doc)

      expect(res.status).to eq(403)
      expect(File.exist?(evil_doc)).to be(true)
    end

    it 'refuses a non-doc file sitting inside an owned root' do
      notes = File.join(@repo, 'notes.txt')
      File.write(notes, 'not a doc')

      expect(delete_doc(notes).status).to eq(403)
      expect(File.exist?(notes)).to be(true)
    end

    it 'refuses a nested subdirectory of an owned root' do
      nested_dir = File.join(@repo, 'nested')
      FileUtils.mkdir_p(nested_dir)
      nested = File.join(nested_dir, 'deep.rb')
      File.write(nested, "header1 'Deep'")

      expect(delete_doc(nested).status).to eq(403)
      expect(File.exist?(nested)).to be(true)
    end

    it 'refuses a missing path, a blank one, and a non-string one' do
      expect(delete_doc(File.join(@repo, 'nope.rb')).status).to eq(403)
      expect(delete_doc('').status).to eq(403)
      expect(delete_doc(nil).status).to eq(403)
      post '/delete-doc', 'not json at all', 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(403)
    end

    it 'refuses the docs root directory itself' do
      expect(delete_doc(@repo).status).to eq(403)
      expect(File.directory?(@repo)).to be(true)
    end
  end

  describe 'where the reader lands afterwards' do
    it 'stays at the same position when the deleted doc was the open one' do
      # bravo (index 1) deleted while open -> global-doc slides into 1.
      expect(delete_doc(bravo, file: 1).status).to eq(200)
      expect(json['file']).to eq(1)

      get "/?file=#{json['file']}"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Global')
    end

    it 'steps back one when the deleted doc was last in the list' do
      configure_list([@repo, @global])
      # global-doc is index 2 of 3 -- nothing follows it.
      expect(delete_doc(global_doc, file: 2).status).to eq(200)
      expect(json['file']).to eq(1)
    end

    it 'shifts the open doc down when an earlier doc is deleted' do
      # alpha (0) deleted while global-doc (2) is open.
      expect(delete_doc(alpha, file: 2).status).to eq(200)
      expect(json['file']).to eq(1)
    end

    it 'leaves the open doc alone when a later doc is deleted' do
      expect(delete_doc(global_doc, file: 0).status).to eq(200)
      expect(json['file']).to eq(0)
    end

    it 'reports nothing to open once the last doc is gone, and renders the placeholder' do
      configure_list([@repo])
      delete_doc(alpha, file: 0)
      res = delete_doc(bravo, file: 0)

      expect(res.status).to eq(200)
      expect(json['file']).to be_nil

      get '/?file=0'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Pick a')
      expect(last_response.body).not_to include('bravo')
    end

    it 'answers a now-stale ?file=N with a 404, not a crash' do
      configure_list([@repo])
      delete_doc(bravo, file: 0)

      get '/?file=1'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'the sidebar control' do
    it 'offers a delete button for docs in the two owned roots' do
      get '/?file=0&repo=all'

      expect(last_response.body).to include('class="sw-doc-delete"')
      expect(last_response.body).to include("askDelete(&quot;#{alpha}&quot;")
      expect(last_response.body).to include("askDelete(&quot;#{global_doc}&quot;")
    end

    it "offers none for a peer repo's docs" do
      get '/?file=0&repo=peerrepo'

      expect(last_response.body).to include('peer-doc')
      expect(last_response.body).not_to include('class="sw-doc-delete"')
    end

    # The confirm gate: the row button only opens the dialog, and the POST
    # lives on the dialog's own button. A JS confirm() is ruled out by design.
    it 'gates the delete behind an in-page dialog, never a JS confirm()' do
      get '/?file=0&repo=all'
      body = last_response.body

      expect(body).to include('class="sw-doc-delete-modal"')
      expect(body).to include('class="sw-doc-delete-confirm"')
      expect(body).to match(/sw-doc-delete-confirm[^>]*@click="doDelete\(\)"/m)
      # No JS confirm dialog anywhere -- ruled out by the design doc, and the
      # reason the modal above exists at all.
      expect(body).not_to match(/(window\.)?confirm\s*\(\s*['"`]/)
      # The row button opens the dialog and does nothing else.
      expect(body).not_to match(/class="sw-doc-delete"[^>]*doDelete/m)
    end

    # The refresh has to swap the file rail itself, which the chrome's
    # default OOB (#sw-reader-nav alone) deliberately does not.
    it 'carries the wider sidebar OOB on the confirm button' do
      get '/?file=0&repo=all'

      expect(last_response.body).to match(
        /sw-doc-delete-confirm[^>]*hx-select-oob="#sw-reader-nav, #sw-reader-files"/m
      )
    end

    # The dialog's CSS ships unconditionally with the rest of the chrome
    # block; it's the MARKUP that must be absent, hence the class= form.
    it 'renders no dialog markup at all when nothing on screen is deletable' do
      get '/?file=0&repo=peerrepo'

      expect(last_response.body).not_to include('class="sw-doc-delete-modal"')
    end
  end
end
