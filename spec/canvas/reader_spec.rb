# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'rack/test'
require 'stream_weaver/canvas/reader'

RSpec.describe StreamWeaver::Canvas::Reader::FileList do
  around { |ex| Dir.mktmpdir { |d| @dir = d; ex.run } }

  def touch(rel)
    path = File.join(@dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "header1 '#{rel}'")
    path
  end

  describe '.build' do
    it 'accepts explicit file paths' do
      f = touch('a.rb')
      list = described_class.build([f])
      expect(list.files).to eq([f])
    end

    it 'scans a directory for *.rb files' do
      touch('x.rb')
      touch('y.rb')
      list = described_class.build([@dir])
      expect(list.files.size).to eq(2)
    end

    it 'ignores non-.rb files in directory scan' do
      touch('a.rb')
      File.write(File.join(@dir, 'readme.md'), 'ignore me')
      list = described_class.build([@dir])
      expect(list.files.size).to eq(1)
    end

    it 'raises if no files resolve' do
      expect { described_class.build(['/nonexistent/path.rb']) }
        .to raise_error(StreamWeaver::Canvas::Reader::NoFilesError)
    end

    it 'combines explicit files and directory scan' do
      f1 = touch('sub/extra.rb')
      touch('a.rb')
      list = described_class.build([@dir, f1])
      expect(list.files).to include(f1)
    end
  end

  describe '#groups' do
    it 'groups files by parent directory' do
      d2 = File.join(@dir, 'sub')
      FileUtils.mkdir_p(d2)
      f1 = touch('a.rb')
      f2 = touch('sub/b.rb')
      list = described_class.build([f1, f2])
      groups = list.groups
      expect(groups.keys).to include(@dir, d2)
    end
  end

  describe '#at' do
    it 'returns file at index' do
      f = touch('a.rb')
      list = described_class.build([f])
      expect(list.at(0)).to eq(f)
    end

    it 'returns nil for out-of-range index' do
      f = touch('a.rb')
      list = described_class.build([f])
      expect(list.at(99)).to be_nil
    end
  end
end

RSpec.describe StreamWeaver::Canvas::Reader do
  describe '.render_dsl' do
    it 'returns HTML string for valid DSL' do
      html = described_class.render_dsl("header1 'Hello'")
      expect(html).to include('Hello')
      expect(html).to be_a(String)
    end

    it 'returns error HTML for invalid DSL without raising' do
      html = described_class.render_dsl("this is not valid !@#")
      expect(html).to include('error')
    end
  end
end

RSpec.describe StreamWeaver::Canvas::Reader, type: :request do
  include Rack::Test::Methods

  before(:all) do
    @dir = Dir.mktmpdir
    File.write(File.join(@dir, 'doc1.rb'), "header1 'Doc One'")
    File.write(File.join(@dir, 'doc2.rb'), "header1 'Doc Two'")
    StreamWeaver::Canvas::Reader.configure_files!(
      StreamWeaver::Canvas::Reader::FileList.build([@dir])
    )
  end

  after(:all) { FileUtils.rm_rf(@dir) }

  def app = StreamWeaver::Canvas::Reader

  describe 'GET /' do
    it 'redirects to ?file=0' do
      get '/'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('file=0')
    end
  end

  describe 'GET /?file=0' do
    it 'returns 200 with doc1 content' do
      get '/?file=0'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Doc One')
    end

    it 'includes sidebar with both filenames' do
      get '/?file=0'
      expect(last_response.body).to include('doc1')
      expect(last_response.body).to include('doc2')
    end
  end

  describe 'GET /?file=1' do
    it 'returns doc2 content' do
      get '/?file=1'
      expect(last_response.body).to include('Doc Two')
    end
  end

  describe 'GET /health' do
    it 'returns 200' do
      get '/health'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'GET /?file=99' do
    it 'returns 404' do
      get '/?file=99'
      expect(last_response.status).to eq(404)
    end
  end

  # Sidebar state preservation: hx-boost on body intercepts <a> clicks and
  # swaps only #content (+ #nav out-of-band). Without these attributes every
  # click does a full reload, collapsing the History accordion.
  describe 'htmx-boosted navigation' do
    it 'declares hx-boost on the body so anchor clicks become AJAX swaps' do
      get '/?file=0'
      body = last_response.body
      expect(body).to match(/<body[^>]*hx-boost="true"/)
      expect(body).to match(/<body[^>]*hx-target="#content"/)
      expect(body).to match(/<body[^>]*hx-select="#content"/)
      expect(body).to match(/<body[^>]*hx-select-oob="#nav"/)
    end

    it 'renders Prev/Next as <a> tags so hx-boost intercepts them' do
      get '/?file=0'
      body = last_response.body
      # First file: Prev is disabled (span), Next is anchor
      expect(body).to match(/<span class="nav-link nav-link--disabled">◀ Prev<\/span>/)
      expect(body).to match(%r{<a href="/\?file=1" class="nav-link" data-nav="next">Next})
    end

    it 'disables Next on the last file via <span>, not <a>' do
      get '/?file=1'
      body = last_response.body
      expect(body).to match(/<span class="nav-link nav-link--disabled">Next ▶<\/span>/)
      expect(body).to match(%r{<a href="/\?file=0" class="nav-link" data-nav="prev">◀ Prev})
    end
  end
end
