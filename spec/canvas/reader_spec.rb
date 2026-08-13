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

  # Sidebar state preservation: hx-boost on the chrome rail intercepts <a>
  # clicks and swaps only #app-container (+ #sw-reader-nav out-of-band).
  # Without these attributes every click does a full reload, collapsing the
  # History accordion.
  describe 'htmx-boosted navigation' do
    # The rail's own open tag, so these assertions can't be satisfied by
    # attributes that happen to appear elsewhere on the page.
    def chrome_tag
      get '/?file=0'
      last_response.body[/<nav id="sw-reader-chrome"[^>]*>/m]
    end

    it 'declares hx-boost on the chrome rail, not the body' do
      tag = chrome_tag
      expect(tag).not_to be_nil
      expect(tag).to include('hx-boost="true"')
      expect(tag).to include('hx-target="#app-container"')
      expect(tag).to include('hx-select="#app-container"')
      expect(tag).to include('hx-select-oob="#sw-reader-nav"')
      # hx-boost on <body> would also catch the sidebar_toc's in-document
      # #section-id jump links.
      expect(last_response.body).not_to match(/<body[^>]*hx-boost/)
    end

    # hx-select keeps the MATCHED element itself. With hx-swap="innerHTML"
    # (the old setting) a navigation would nest a fresh #app-container inside
    # the old one, killing every `body[class*="sw-layout-"] > #app-container`
    # selector and both getElementById('app-container') lookups in
    # adapter/alpinejs.rb after the very first sidebar click.
    it 'swaps outerHTML so #app-container is replaced, never nested' do
      tag = chrome_tag
      expect(tag).to include('hx-swap="outerHTML"')
      expect(tag).not_to include('hx-swap="innerHTML"')
    end

    it 'returns exactly one #app-container per navigation response' do
      %w[/?file=0 /?file=1].each do |path|
        get path
        expect(last_response.body.scan(/id="app-container"/).size).to eq(1)
      end
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

  # Every relevant sidebar_toc/theme selector in adapter/alpinejs.rb and
  # views.rb uses the ">" (direct child) combinator against
  # `body[class*="sw-layout-"] > #app-container`. Nesting the container inside
  # a wrapper div (the old #main/#content shell) leaves all of them dead.
  describe 'page shell structure' do
    it 'renders #app-container as the first thing inside <body>' do
      get '/?file=0'
      between = last_response.body[/<body[^>]*>([\s\S]*?)<div id="app-container"/, 1]
      expect(between).not_to be_nil
      expect(between.strip).to eq('')
    end

    it 'gives <body> the doc theme + layout classes' do
      get '/?file=0'
      expect(last_response.body).to match(/<body class="sw-theme-\w+ sw-layout-\w+ sw-reader"/)
    end

    it 'drops the old #main/#content two-pane wrapper entirely' do
      get '/?file=0'
      expect(last_response.body).not_to include('id="content"')
      expect(last_response.body).not_to include('id="main"')
      expect(last_response.body).not_to include('id="sidebar"')
    end

    # <body>'s own class attribute is never part of the swapped region, so the
    # afterSwap handler reads the incoming doc's classes off this attribute.
    it 'carries the body classes on #app-container for the afterSwap handler' do
      get '/?file=0'
      expect(last_response.body).to match(/<div id="app-container" data-sw-body-class="sw-theme-\w+ sw-layout-\w+ sw-reader"/)
    end
  end

  # The core "did we actually fix the missing CSS" guard for stream_weaver-csf:
  # before this, the reader embedded only the raw unlayered CANVAS_CSS and had
  # no master theme, no visual-skills CSS, and no cascade-layer pin at all.
  describe 'framework CSS via PageShell' do
    let(:body) do
      get '/?file=0'
      last_response.body
    end

    it 'pins both cascade layers, framework first' do
      expect(body).to include('<style>@layer stream-weaver, sw-reader-chrome;</style>')
    end

    it 'includes the full PageShell framework head' do
      expect(body).to include(
        StreamWeaver::PageShell.framework_css_html(extra_layers: %w[sw-reader-chrome]).strip
      )
    end

    it 'includes master_theme_css tokens' do
      expect(body).to include('--sw-font-body')
      expect(body).to match(/body\[class\*="sw-layout-"\] > #app-container/)
    end

    it 'includes visual_skills_css tokens' do
      marker = StreamWeaver::Theme.visual_skills_css[/\.sw-[a-z-]+/]
      expect(marker).not_to be_nil
      expect(body).to include(marker)
    end

    it 'layer-wraps CANVAS_CSS rather than emitting it unlayered' do
      expect(body).to include(StreamWeaver::CSS.layer_wrap(StreamWeaver::PageShell::CANVAS_CSS))
    end

    it 'emits the doc use_stylesheet CSS unlayered and after the framework' do
      dir = Dir.mktmpdir
      File.write(File.join(dir, 'styled.rb'), "use_stylesheet('.mine { color: rebeccapurple; }')\nheader1 'Styled'")
      prev = described_class.file_list
      described_class.configure_files!(described_class::FileList.build([dir]))
      begin
        get '/?file=0'
        html = last_response.body
        expect(html).to include('<style>.mine { color: rebeccapurple; }</style>')
        expect(html.index('<style>.mine'))
          .to be > html.index('@layer stream-weaver {')
      ensure
        described_class.configure_files!(prev)
        FileUtils.rm_rf(dir)
      end
    end
  end

  # The websocket adapter mode is kept for component-markup parity, but its
  # connect script points at /canvas/reader/ws, which the reader never serves.
  describe 'CDN scripts' do
    it 'does not emit the canvas websocket init script' do
      get '/?file=0'
      expect(last_response.body).not_to include('/canvas/reader/ws')
      expect(last_response.body).not_to include('StreamWeaver Canvas connected')
    end

    it 'still emits plain htmx and Alpine tags' do
      get '/?file=0'
      expect(last_response.body).to include('htmx.org@2.0.4')
      expect(last_response.body).to include('alpinejs@3.x.x')
    end
  end
end
