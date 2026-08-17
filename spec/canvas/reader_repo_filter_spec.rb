# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'tmpdir'
require 'fileutils'
require 'stream_weaver/canvas/reader'

# The sidebar's per-repo grouping and ?repo= filter (stream_weaver-iugu).
# Multi-repo discovery is only useful if you can also get one repo's docs
# back out of the resulting pile, and if launching inside a repo lands you
# on that repo's docs without a click.
RSpec.describe StreamWeaver::Canvas::Reader do
  include Rack::Test::Methods
  def app = described_class

  # Two repo docs roots plus a stand-in for the global store, each with one
  # doc, wired into a labeled FileList exactly as CLI.canvas_read would.
  around do |ex|
    Dir.mktmpdir do |tmp|
      @alpha  = File.join(tmp, 'alpha',  'docs', 'streamweaver_canvas')
      @beta   = File.join(tmp, 'beta',   'docs', 'streamweaver_canvas')
      @global = File.join(tmp, 'globalstore')
      [@alpha, @beta, @global].each { |d| FileUtils.mkdir_p(d) }
      File.write(File.join(@alpha,  'alpha-doc.rb'),  "header1 'Alpha'")
      File.write(File.join(@beta,   'beta-doc.rb'),   "header1 'Beta'")
      File.write(File.join(@global, 'global-doc.rb'), "header1 'GlobalDoc'")
      @labels = { @alpha => 'alpha', @beta => 'beta', @global => 'Global' }
      ex.run
    end
  end

  before do
    described_class.configure_files!(
      described_class::FileList.build([@alpha, @beta, @global], labels: @labels)
    )
  end

  after { described_class.configure_files!(nil) }

  describe 'grouping' do
    it 'labels each group by its repo, not by the docs dir basename' do
      get '/?file=0&repo=all'
      expect(last_response.body).to include('>alpha<').and include('>beta<').and include('>Global<')
      # 'streamweaver_canvas' is what File.basename(dir) would have shown for
      # both repo groups -- indistinguishable, which is the bug the label
      # exists to fix.
      expect(last_response.body).not_to match(/<span title="[^"]*">streamweaver_canvas<\/span>/)
    end

    it 'offers a repo filter row with every label plus All' do
      get '/?file=0&repo=all'
      expect(last_response.body).to include('class="repo-filter"')
      expect(last_response.body).to include('repo=alpha').and include('repo=beta').and include('repo=all')
    end
  end

  describe '?repo= filtering' do
    it 'shows only the named repo group' do
      get '/?file=0&repo=beta'
      body = last_response.body
      expect(body).to include('beta-doc')
      expect(body).not_to include('alpha-doc')
      expect(body).not_to include('global-doc')
    end

    it 'keeps global ?file= indices stable across filters' do
      # beta-doc is index 1 in the full list; filtering must not renumber it.
      get '/?file=0&repo=beta'
      expect(last_response.body).to include('/?file=1')
    end

    it 'repo=all clears the filter' do
      get '/?file=0&repo=all'
      body = last_response.body
      expect(body).to include('alpha-doc').and include('beta-doc').and include('global-doc')
    end

    it 'falls back to all for a label with no matching group' do
      get '/?file=0&repo=deleted-repo'
      expect(last_response.body).to include('alpha-doc').and include('beta-doc')
    end

    it 'carries the active filter through file links so navigation keeps it' do
      get '/?file=1&repo=beta'
      expect(last_response.body).to include('/?file=1&amp;repo=beta')
    end

    it 'carries the active filter through Prev/Next' do
      get '/?file=1&repo=all'
      expect(last_response.body).to include('/?file=0&amp;repo=all')
      expect(last_response.body).to include('/?file=2&amp;repo=all')
    end
  end

  describe 'default filter' do
    it "defaults to the host process's own repo when it is one of the groups" do
      allow(described_class).to receive(:repo_docs_root).and_return(@alpha)
      get '/?file=0'
      body = last_response.body
      expect(body).to include('alpha-doc')
      expect(body).not_to include('beta-doc')
    end

    it 'falls back to Global when the host repo has no group here' do
      allow(described_class).to receive(:repo_docs_root).and_return('/nowhere/docs/streamweaver_canvas')
      get '/?file=0'
      body = last_response.body
      expect(body).to include('global-doc')
      expect(body).not_to include('alpha-doc')
    end

    it 'matches the host repo through a symlinked spelling of the same dir' do
      link_parent = Dir.mktmpdir
      link = File.join(link_parent, 'alpha-link')
      File.symlink(File.dirname(File.dirname(@alpha)), link)
      allow(described_class).to receive(:repo_docs_root)
        .and_return(File.join(link, 'docs', 'streamweaver_canvas'))

      get '/?file=0'
      expect(last_response.body).to include('alpha-doc')
      expect(last_response.body).not_to include('beta-doc')
    ensure
      FileUtils.remove_entry(link_parent) if link_parent
    end

    it 'shows everything when neither the host repo nor Global is present' do
      described_class.configure_files!(
        described_class::FileList.build([@alpha, @beta], labels: { @alpha => 'alpha', @beta => 'beta' })
      )
      allow(described_class).to receive(:repo_docs_root).and_return(nil)

      get '/?file=0'
      expect(last_response.body).to include('alpha-doc').and include('beta-doc')
    end
  end

  describe 'single-repo boot (regression)' do
    it 'renders no filter row when there is nothing to filter between' do
      described_class.configure_files!(described_class::FileList.build([@alpha], labels: { @alpha => 'alpha' }))
      get '/?file=0'
      expect(last_response.body).to include('alpha-doc')
      expect(last_response.body).not_to include('class="repo-filter"')
    end

    it 'falls back to the dir basename when no label was supplied' do
      described_class.configure_files!(described_class::FileList.build([@alpha]))
      get '/?file=0'
      expect(last_response.body).to include('>streamweaver_canvas<')
    end
  end
end
