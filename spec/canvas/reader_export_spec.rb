# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'rack/test'
require 'stream_weaver/canvas/reader'

# GET /export downloads the currently-viewed doc as a standalone HTML file
# (stream_weaver-65z). Failures must answer with a status and a message --
# never a partial document, which lands in ~/Downloads looking like a success.
RSpec.describe StreamWeaver::Canvas::Reader, 'HTML export' do
  include Rack::Test::Methods
  def app = described_class

  around do |ex|
    Dir.mktmpdir do |dir|
      @dir = dir
      File.write(File.join(dir, 'arch notes.rb'), "header1 'Arch Notes'\ntext 'From the DSL.'")
      File.write(File.join(dir, 'broken.rb'),     "no_such_component 'boom'")
      File.write(File.join(dir, 'full_app.rb'),   "app = StreamWeaver::App.new('X')\napp.run!")
      File.write(File.join(dir, 'diagram.rb'),    %(mermaid "graph TD; A-->B;"))
      described_class.configure_files!(described_class::FileList.build([dir]))
      described_class.configure_defaults!(theme: nil, layout: nil)
      begin
        ex.run
      ensure
        # Class-level state -- leaking either here would affect other specs:
        # a stale --theme retheming them, or a stale file_list pointing at
        # this (about to be deleted) tmpdir.
        described_class.configure_defaults!(theme: nil, layout: nil)
        described_class.configure_files!(nil)
      end
    end
  end

  # FileList sorts by path: arch notes, broken, diagram, full_app
  let(:doc_index)      { 0 }
  let(:broken_index)   { 1 }
  let(:mermaid_index)  { 2 }
  let(:full_app_index) { 3 }

  describe 'GET /export' do
    it 'returns the rendered doc as an HTML attachment' do
      get "/export?file=#{doc_index}"

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to include('text/html')
      expect(last_response.body).to include('<!DOCTYPE html>')
      expect(last_response.body).to include('Arch Notes')
      expect(last_response.body).to include('From the DSL.')
    end

    it 'sanitizes the download filename to the DocStore allowlist' do
      get "/export?file=#{doc_index}"

      expect(last_response.headers['Content-Disposition'])
        .to eq('attachment; filename="arch-notes.html"')
    end

    it 'carries the doc theme/layout onto the exported body' do
      get "/export?file=#{doc_index}"

      expect(last_response.body).to include('<body class="sw-theme-default sw-layout-fluid">')
    end

    it 'honours canvas-read --theme/--layout fallbacks so the file matches the screen' do
      described_class.configure_defaults!(theme: 'doc', layout: 'wide')
      get "/export?file=#{doc_index}"

      expect(last_response.body).to include('<body class="sw-theme-doc sw-layout-wide">')
    end

    it '404s on an out-of-range index instead of wrapping to the last file' do
      get '/export?file=99'
      expect(last_response.status).to eq(404)
      expect(last_response.headers['Content-Type']).to include('text/plain')

      get '/export?file=-1'
      expect(last_response.status).to eq(404)
    end

    it '422s with an explanation when the file is a full app rather than a DSL fragment' do
      get "/export?file=#{full_app_index}"

      expect(last_response.status).to eq(422)
      expect(last_response.headers['Content-Type']).to include('text/plain')
      expect(last_response.body).to include('canvas-doc DSL fragment')
      expect(last_response.body).not_to include('<!DOCTYPE html>')
    end

    # A DSL that fails to eval is bad input, the same class of problem as the
    # full-app case above -- not an internal exporter failure, so 422 rather
    # than 500, matching GET /'s equivalent case (its red error box).
    it '422s with the DSL error rather than a partial document' do
      get "/export?file=#{broken_index}"

      expect(last_response.status).to eq(422)
      expect(last_response.headers['Content-Type']).to include('text/plain')
      expect(last_response.body).to include('Export failed')
      expect(last_response.body).not_to include('<!DOCTYPE html>')
    end

    # ?offline=1 (stream_weaver-dnq). Stubs the network fetch -- these
    # specs are about the query param reaching HtmlExporter#to_html, not
    # about actually reaching jsdelivr.
    describe '?offline=1' do
      it 'inlines mermaid instead of referencing its CDN' do
        allow_any_instance_of(StreamWeaver::Export::HtmlExporter)
          .to receive(:fetch_url).and_return("/* stubbed mermaid global */")

        get "/export?file=#{mermaid_index}&offline=1"

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include("/* stubbed mermaid global */")
        expect(last_response.body).not_to match(%r{<script[^>]*mermaid\.esm})
      end

      it 'still references the CDN when offline is omitted' do
        get "/export?file=#{mermaid_index}"

        expect(last_response.body).to match(%r{<script[^>]*mermaid\.esm})
      end

      it '502s with an actionable message when the fetch fails' do
        allow_any_instance_of(StreamWeaver::Export::HtmlExporter)
          .to receive(:fetch_url).and_raise(Timeout::Error, "execution expired")

        get "/export?file=#{mermaid_index}&offline=1"

        expect(last_response.status).to eq(502)
        expect(last_response.headers['Content-Type']).to include('text/plain')
        expect(last_response.body).to include('needs network access')
      end
    end
  end

  describe 'the Export HTML button' do
    it 'appears in the reader nav for every file, not just history snapshots' do
      get "/?file=#{doc_index}"

      nav = last_response.body[/<div id="sw-reader-nav">([\s\S]*?)<\/nav>/, 1]
      expect(nav).to include("href=\"/export?file=#{doc_index}\"")
      expect(nav).to include('Export HTML')
    end

    # The offline variant only does something on a doc with a mermaid
    # diagram to inline -- shown only there, so it isn't a confusing extra
    # click that does nothing on every other doc.
    it 'shows the offline export link only on a doc that has mermaid' do
      get "/?file=#{doc_index}"
      expect(last_response.body).not_to include('Export HTML (offline)')

      get "/?file=#{mermaid_index}"
      nav = last_response.body[/<div id="sw-reader-nav">([\s\S]*?)<\/nav>/, 1]
      expect(nav).to include("href=\"/export?file=#{mermaid_index}&amp;offline=1\"")
      expect(nav).to include('Export HTML (offline)')
    end

    it 'opts the link out of hx-boost so the download is not swapped into the page' do
      get "/?file=#{doc_index}"

      link = last_response.body[/<a href="\/export\?file=0"[^>]*>/]
      expect(link).to include('hx-boost="false"')
    end

    # Regression guard: `download` forces the response body into ~/Downloads
    # regardless of HTTP status, so a 422/500 from GET /export would land as
    # a mystery extensionless file instead of showing the error. Content-
    # Disposition: attachment already handles the success-path download.
    it 'does not carry a download attribute (would force error bodies into ~/Downloads too)' do
      get "/?file=#{doc_index}"

      link = last_response.body[/<a href="\/export\?file=0"[^>]*>/]
      expect(link).not_to include('download')
    end
  end
end
