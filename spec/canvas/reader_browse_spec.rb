# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'rack/test'
require 'stream_weaver/canvas/reader'

# GET /browse and GET /open (stream_weaver-rdh): a live filesystem browse
# view inside canvas-read, so you can navigate to a doc saved elsewhere
# without restarting the process with a new CLI arg. No index, no
# registered locations -- browsing computed fresh on every request is the
# discovery mechanism.
RSpec.describe StreamWeaver::Canvas::Reader, 'file browser' do
  include Rack::Test::Methods
  def app = described_class

  around do |ex|
    Dir.mktmpdir do |dir|
      @dir = dir
      File.write(File.join(dir, 'doc.rb'), "header1 'From the docs dir'")
      described_class.configure_files!(described_class::FileList.build([dir]))
      described_class.configure_defaults!(theme: nil, layout: nil)

      # A second, entirely separate tmp tree Browse navigates into --
      # standing in for "a doc saved in a different repo," the whole
      # point of this feature.
      Dir.mktmpdir do |elsewhere|
        @elsewhere = elsewhere
        FileUtils.mkdir_p(File.join(elsewhere, 'subdir'))
        File.write(File.join(elsewhere, 'other.rb'), "header1 'Saved elsewhere'")
        File.write(File.join(elsewhere, 'subdir', 'nested.rb'), "header1 'Nested'")
        File.write(File.join(elsewhere, 'not-ruby.txt'), 'ignore me')
        FileUtils.mkdir_p(File.join(elsewhere, '.hidden'))
        begin
          ex.run
        ensure
          described_class.configure_defaults!(theme: nil, layout: nil)
          described_class.configure_files!(nil)
        end
      end
    end
  end

  describe 'GET /browse' do
    it 'lists subdirectories and .rb files, excluding non-.rb files and dotfiles' do
      get "/browse?dir=#{ERB::Util.url_encode(@elsewhere)}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('other.rb')
      expect(last_response.body).to include('subdir')
      expect(last_response.body).not_to include('not-ruby.txt')
      expect(last_response.body).not_to include('.hidden')
    end

    # .org support (stream_weaver-yf3a): browse_entries was .rb-only.
    it 'also lists .org files' do
      File.write(File.join(@elsewhere, 'doc.org'), "#+STREAMWEAVER_DSL: 1\n#+TITLE: T\n")
      get "/browse?dir=#{ERB::Util.url_encode(@elsewhere)}"

      expect(last_response.body).to include('doc.org')
    end

    it 'navigating into a subdirectory shows that directory\'s own contents' do
      get "/browse?dir=#{ERB::Util.url_encode(File.join(@elsewhere, 'subdir'))}"

      expect(last_response.body).to include('nested.rb')
      expect(last_response.body).not_to include('other.rb')
    end

    it 'falls back to $HOME on a nonexistent dir rather than 404ing' do
      Dir.mktmpdir do |fake_home|
        File.write(File.join(fake_home, 'home-marker.rb'), "text 'home'")
        original_home = ENV['HOME']
        ENV['HOME'] = fake_home
        begin
          get "/browse?dir=#{ERB::Util.url_encode(File.join(@elsewhere, 'does-not-exist'))}"

          expect(last_response.status).to eq(200)
          # Asserts it actually landed in $HOME, not just that *something*
          # rendered -- a broken fallback (e.g. silently 500ing into an
          # error page that happens to also return 200) would pass a bare
          # status check. Stubbed rather than exercising the developer's
          # real $HOME: faster, and a failure here would otherwise dump the
          # real path into spec output (this repo's own git-hygiene policy
          # blocks home paths in committed content -- worth avoiding in
          # test output too).
          expect(last_response.body).to include('home-marker.rb')
        ensure
          ENV['HOME'] = original_home
        end
      end
    end

    it 'lists a directory whose name ends in .rb only once, as a directory' do
      # A directory literally named "*.rb" is rare but real (generator
      # fixtures do this) -- it must satisfy the directory branch only, not
      # both, or it renders as a dead file link (404 on click) alongside a
      # working directory link. "weird.rb" itself legitimately appears
      # twice in a correct render (once in the href, once as link text) --
      # what must be exactly one is the /open?path= (file) link, which
      # would only exist if the double-listing bug were back.
      FileUtils.mkdir_p(File.join(@elsewhere, 'weird.rb'))
      get "/browse?dir=#{ERB::Util.url_encode(@elsewhere)}"

      expect(last_response.body).to include("browse?dir=#{ERB::Util.url_encode(File.join(@elsewhere, 'weird.rb'))}")
      expect(last_response.body).not_to include("open?path=#{ERB::Util.url_encode(File.join(@elsewhere, 'weird.rb'))}")
    end

    it 'shows an empty listing rather than 500ing on a permission-denied directory' do
      restricted = File.join(@elsewhere, 'restricted')
      FileUtils.mkdir_p(restricted)
      File.chmod(0o000, restricted)
      begin
        get "/browse?dir=#{ERB::Util.url_encode(restricted)}"
        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('browse-empty')
      ensure
        File.chmod(0o755, restricted) # so Dir.mktmpdir's own cleanup can remove it
      end
    end

    it 'does not 500 on a non-String dir param (?dir[]=x)' do
      get '/browse?dir[]=x'
      expect(last_response.status).to eq(200)
    end

    it 'does not 500 on a dir param containing a null byte' do
      get "/browse?dir=#{ERB::Util.url_encode("#{@elsewhere}\x00")}"
      expect(last_response.status).to eq(200)
    end

    it 'does not 500 on an unresolvable ~user in the dir param' do
      get '/browse?dir=~nosuchuserxyz'
      expect(last_response.status).to eq(200)
    end

    # Filenames come straight off the filesystem -- '"', '<', '&' are all
    # legal there, and unlike the fixed docs sections, Browse can be
    # pointed at any directory (~/Downloads included, where an attacker
    # controls a dropped file's name). Every filesystem-derived string in
    # the sidebar must be escaped or this is a same-origin XSS.
    it 'escapes a filename containing HTML-significant characters' do
      evil = %(evil".rb)
      File.write(File.join(@elsewhere, evil), "text 'x'")
      get "/browse?dir=#{ERB::Util.url_encode(@elsewhere)}"

      expect(last_response.body).not_to include(%("><img src=x>))
      expect(last_response.body).to include('evil&quot;.rb')
    end

    it 'shows a "StreamWeaver (global)" shortcut always' do
      get "/browse?dir=#{ERB::Util.url_encode(@elsewhere)}"

      expect(last_response.body).to include('StreamWeaver (global)')
    end

    it 'renders breadcrumbs for the current directory' do
      get "/browse?dir=#{ERB::Util.url_encode(File.join(@elsewhere, 'subdir'))}"

      expect(last_response.body).to include('subdir')
      expect(last_response.body).to include('href="/browse?dir=%2F"')
    end

    it 'shows an empty-state message for a directory with nothing to list' do
      Dir.mktmpdir do |empty_dir|
        get "/browse?dir=#{ERB::Util.url_encode(empty_dir)}"
        expect(last_response.body).to include('browse-empty')
      end
    end

    # Browse mode has no meaningful ?file=N index, so Prev/Next/counter and
    # the Save-as-doc widget (which needs a real history-snapshot index)
    # must not render -- rendering them against a nil/garbage index would
    # be either a crash or a silently-wrong link.
    it 'does not render Prev/Next/counter (no file index to page through)' do
      get "/browse?dir=#{ERB::Util.url_encode(@elsewhere)}"

      expect(last_response.body).not_to match(%r{<a[^>]*data-nav="prev"})
      expect(last_response.body).not_to include('sw-save-doc-btn')
    end
  end

  describe 'GET /open' do
    it 'renders a file found via Browse, independent of the configured FileList' do
      path = File.join(@elsewhere, 'other.rb')
      get "/open?path=#{ERB::Util.url_encode(path)}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Saved elsewhere')
    end

    it 'keeps the sidebar in Browse mode (that file\'s own directory), not the configured docs list' do
      path = File.join(@elsewhere, 'other.rb')
      get "/open?path=#{ERB::Util.url_encode(path)}"

      expect(last_response.body).to include('href="/open?path=')
      # The originally-configured doc's own sidebar entry ("doc.rb" in @dir,
      # rendered as a .dir-section) shouldn't appear -- Browse mode replaces
      # the sidebar's content, it doesn't merge it. "/?file=0" alone isn't a
      # safe negative here: the "← Back to docs" link legitimately points
      # there too.
      expect(last_response.body).not_to include('class="dir-section"')
    end

    it '404s on a nonexistent path' do
      get "/open?path=#{ERB::Util.url_encode(File.join(@elsewhere, 'nope.rb'))}"
      expect(last_response.status).to eq(404)
    end

    it '404s on a path that is not a .rb or .org file' do
      get "/open?path=#{ERB::Util.url_encode(File.join(@elsewhere, 'not-ruby.txt'))}"
      expect(last_response.status).to eq(404)
    end

    # .org support (stream_weaver-yf3a).
    it 'renders an .org file found via Browse' do
      path = File.join(@elsewhere, 'notes.org')
      File.write(path, "#+STREAMWEAVER_DSL: 1\n#+TITLE: Org Via Open\n\nOpened via /open\n")
      get "/open?path=#{ERB::Util.url_encode(path)}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Org Via Open')
      expect(last_response.body).to include('Opened via /open')
    end

    it 'shows a "Browsed: <name>" note in place of Prev/Next, with no file index' do
      path = File.join(@elsewhere, 'other.rb')
      get "/open?path=#{ERB::Util.url_encode(path)}"

      expect(last_response.body).to include('Browsed: other.rb')
      expect(last_response.body).not_to match(%r{<a[^>]*data-nav="prev"})
    end

    # Reader.render_doc already rescues ScriptError/StandardError into a red
    # error Doc rather than raising (spec/canvas/reader_spec.rb pins that
    # for the ?file=N path) -- this just confirms /open, which evaluates
    # whatever .rb it's pointed at, inherits the same safety rather than
    # bypassing it.
    it 'shows the red DSL-error box, not a 500, for a file that raises on eval' do
      path = File.join(@elsewhere, 'broken.rb')
      File.write(path, "no_such_component 'boom'")
      get "/open?path=#{ERB::Util.url_encode(path)}"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('DSL error')
    end
  end

  describe 'sidebar entry point and accordion-state regression guard' do
    it 'the normal docs view offers a Browse files… link' do
      get '/?file=0'
      expect(last_response.body).to include('Browse files')
    end

    # stream_weaver-8v1: accordion expand/collapse state in #sw-reader-files
    # survives normal navigation specifically because it is NOT re-swapped.
    # Browse links carry their own wider hx-select-oob to swap it anyway --
    # that override must stay scoped to Browse links, or every Prev/Next/
    # sidebar click would silently start resetting open/closed sections.
    it 'does not widen hx-select-oob on normal doc links (regression guard for stream_weaver-8v1)' do
      get '/?file=0'

      chrome = last_response.body[/<nav id="sw-reader-chrome"[^>]*>/]
      expect(chrome).to include('hx-select-oob="#sw-reader-nav"')
      expect(chrome).not_to include('#sw-reader-files')

      doc_link = last_response.body[/<a href="\/\?file=0"[^>]*>/]
      expect(doc_link).not_to include('hx-select-oob')
    end

    it 'widens hx-select-oob specifically on the Browse entry link' do
      get '/?file=0'

      browse_link = last_response.body[/<a href="\/browse"[^>]*>/]
      expect(browse_link).to include('hx-select-oob="#sw-reader-nav, #sw-reader-files"')
    end

    # Nine separate links carry BROWSE_OOB by hand (shortcuts, breadcrumbs,
    # up-link, every dir/file entry, back-link, the entry point above).
    # Missing it on any ONE of them means clicking that specific link
    # updates the main pane but leaves the sidebar showing the wrong
    # directory -- a bug that only shows up on that one link, easy for a
    # future edit to reintroduce silently. Assert it holds for every
    # /browse-hrefed anchor actually inside the Browse listing, not just
    # the entry point already covered above.
    it 'widens hx-select-oob on every link inside the Browse listing itself' do
      get "/browse?dir=#{ERB::Util.url_encode(@elsewhere)}"

      browse_dir_links = last_response.body.scan(%r{<a href="/browse\?dir=[^>]*>})
      expect(browse_dir_links).not_to be_empty
      browse_dir_links.each do |tag|
        expect(tag).to include('hx-select-oob="#sw-reader-nav, #sw-reader-files"')
      end
    end
  end

  # The before filter (stream_weaver-rdh): /open evaluates whatever .rb
  # it's handed, and 127.0.0.1-binding alone doesn't stop a page already
  # open in the user's browser from issuing a cross-origin GET here with
  # no CSRF token. Pinned against ALL routes, not just /browse and /open,
  # since a wrong Host/Sec-Fetch-Site should never reach any of them.
  describe 'cross-origin request gate' do
    it 'blocks a request with a Host header the reader does not recognize' do
      header 'Host', 'evil.example.com'
      get '/health'
      expect(last_response.status).to eq(403)
    end

    it 'blocks a request whose Sec-Fetch-Site says cross-site' do
      header 'Sec-Fetch-Site', 'cross-site'
      get '/health'
      expect(last_response.status).to eq(403)
    end

    it 'blocks same-site (a sibling origin), not just cross-site' do
      header 'Sec-Fetch-Site', 'same-site'
      get '/health'
      expect(last_response.status).to eq(403)
    end

    it 'allows a same-origin request through' do
      header 'Sec-Fetch-Site', 'same-origin'
      get '/health'
      expect(last_response.status).to eq(200)
    end

    it 'allows a request with no Sec-Fetch-Site header at all (older browsers)' do
      get '/health'
      expect(last_response.status).to eq(200)
    end
  end
end
