# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'stream_weaver/canvas/doc_roots'

# Discovery for canvas-read's multi-repo sidebar (stream_weaver-iugu): a scan
# of known parent dirs unioned with an append-only registry, so a doc saved in
# repo A is readable from a canvas-read launched in repo B -- including when
# repo A lives somewhere the scan never looks.
RSpec.describe StreamWeaver::Canvas::DocRoots do
  # Every example gets its own registry, scan root, global store and
  # STREAMWEAVER_DOC_ROOT, so nothing here can see (or write to) the
  # developer's real ~/.streamweaver or ~/work.
  around do |ex|
    saved = ENV.to_hash.slice(
      'STREAMWEAVER_DOCS_REGISTRY', 'STREAMWEAVER_DOCS_SCAN_ROOTS', 'STREAMWEAVER_DOC_ROOT'
    )
    Dir.mktmpdir do |tmp|
      @tmp      = tmp
      @registry = File.join(tmp, 'docs_roots.log')
      @scan     = File.join(tmp, 'work')
      FileUtils.mkdir_p(@scan)
      ENV['STREAMWEAVER_DOCS_REGISTRY']   = @registry
      ENV['STREAMWEAVER_DOCS_SCAN_ROOTS'] = @scan
      ENV['STREAMWEAVER_DOC_ROOT']        = File.join(tmp, 'nonexistent-host-repo')
      ex.run
    end
  ensure
    %w[STREAMWEAVER_DOCS_REGISTRY STREAMWEAVER_DOCS_SCAN_ROOTS STREAMWEAVER_DOC_ROOT].each do |k|
      ENV[k] = saved[k]
    end
  end

  # DocStore::DEFAULT_ROOT is a hard-coded ~/.streamweaver/canvas with no ENV
  # override (by design -- the global store is always its own group), so on a
  # machine that actually has one it turns up in .roots for real. Assertions
  # about the tmpdir-built roots exclude it rather than pretending it isn't
  # there; the one example that cares about it asserts on it directly.
  def discovered_roots
    described_class.roots - [StreamWeaver::Canvas::DocStore::DEFAULT_ROOT]
  end

  # Builds <parent>/<name>/docs/streamweaver_canvas with one doc in it and
  # returns the docs root.
  def make_repo(parent, name, filename = 'doc.rb')
    root = File.join(parent, name, StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
    FileUtils.mkdir_p(root)
    File.write(File.join(root, filename), "header1 '#{name}'")
    root
  end

  describe '.record / .registered' do
    it 'round-trips an appended root' do
      root = make_repo(@tmp, 'elsewhere')
      described_class.record(root)
      expect(described_class.registered).to eq([root])
    end

    it 'writes one absolute path per line' do
      a = make_repo(@tmp, 'alpha')
      b = make_repo(@tmp, 'beta')
      described_class.record(a)
      described_class.record(b)
      expect(File.readlines(@registry, chomp: true)).to eq([a, b])
    end

    it 'de-dupes duplicate lines on read' do
      root = make_repo(@tmp, 'twice')
      File.write(@registry, "#{root}\n#{root}\n#{root}\n")
      expect(described_class.registered).to eq([root])
    end

    it 'filters out roots whose directory no longer exists (self-healing)' do
      alive = make_repo(@tmp, 'alive')
      dead  = File.join(@tmp, 'deleted', StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
      File.write(@registry, "#{dead}\n#{alive}\n")
      expect(described_class.registered).to eq([alive])
    end

    it 'does not append a path the registry already holds' do
      root = make_repo(@tmp, 'stable')
      3.times { described_class.record(root) }
      expect(File.readlines(@registry).size).to eq(1)
    end

    it 'returns nil and writes nothing for a blank root' do
      expect(described_class.record('')).to be_nil
      expect(File.exist?(@registry)).to be(false)
    end

    it 'reads as empty when the registry file does not exist' do
      expect(described_class.registered).to eq([])
    end
  end

  describe '.scanned' do
    it 'finds a repo docs root one level under the scan root' do
      root = make_repo(@scan, 'myrepo')
      expect(described_class.scanned).to include(root)
    end

    it 'ignores a repo that has no docs/streamweaver_canvas' do
      FileUtils.mkdir_p(File.join(@scan, 'plain-repo', 'lib'))
      expect(described_class.scanned).to eq([])
    end

    it 'does not descend past one level' do
      make_repo(File.join(@scan, 'nested'), 'deep')
      expect(described_class.scanned).to eq([])
    end

    it 'respects a multi-entry STREAMWEAVER_DOCS_SCAN_ROOTS override' do
      other = File.join(@tmp, 'src')
      FileUtils.mkdir_p(other)
      a = make_repo(@scan, 'from-work')
      b = make_repo(other, 'from-src')
      ENV['STREAMWEAVER_DOCS_SCAN_ROOTS'] = "#{@scan}#{File::PATH_SEPARATOR}#{other}"
      expect(described_class.scanned).to contain_exactly(a, b)
    end

    it 'scans nothing when the override is explicitly empty' do
      make_repo(@scan, 'ignored')
      ENV['STREAMWEAVER_DOCS_SCAN_ROOTS'] = ''
      expect(described_class.scanned).to eq([])
    end
  end

  describe '.roots' do
    it 'unions scan and registry without double-listing a repo in both' do
      scanned    = make_repo(@scan, 'both')
      registered = make_repo(@tmp, 'registry-only')
      described_class.record(scanned)
      described_class.record(registered)

      expect(discovered_roots).to contain_exactly(scanned, registered)
    end

    it 'does not double-list a root reached by a symlinked spelling' do
      real = make_repo(@tmp, 'realdir')
      link = File.join(@tmp, 'linked')
      File.symlink(File.join(@tmp, 'realdir'), link)
      described_class.record(real)
      described_class.record(File.join(link, StreamWeaver::Canvas::DocStore::DOCS_SUBPATH))

      expect(discovered_roots.size).to eq(1)
    end

    it 'includes the host repo docs root (DocStore.path) first' do
      host = File.join(@tmp, 'host', StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
      FileUtils.mkdir_p(host)
      ENV['STREAMWEAVER_DOC_ROOT'] = host
      make_repo(@scan, 'peer')

      expect(described_class.roots.first).to eq(host)
    end

    # Stubbed rather than mkdir_p'd: DEFAULT_ROOT is a literal path in the
    # real home directory, and a spec has no business creating one there on a
    # machine that has never run canvas.
    it 'includes the global store as its own root' do
      global = StreamWeaver::Canvas::DocStore::DEFAULT_ROOT
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:directory?).with(global).and_return(true)

      expect(described_class.roots).to include(global)
    end

    it 'drops a registry entry whose directory has been deleted' do
      gone = File.join(@tmp, 'gone', StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
      File.write(@registry, "#{gone}\n")
      expect(discovered_roots).to eq([])
    end

    # Existing but empty is not the same as worth listing (stream_weaver-uvaj):
    # a root whose last doc was just deleted -- from the reader, by a git pull,
    # by hand -- would otherwise stay in the rail as a heading that discloses
    # nothing and a repo-filter chip that selects nothing.
    describe 'roots with nothing in them' do
      it 'drops a scanned root that currently holds no docs' do
        empty = File.join(@scan, 'emptied', StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
        FileUtils.mkdir_p(empty)
        stocked = make_repo(@scan, 'stocked')

        expect(discovered_roots).to eq([stocked])
      end

      it 'drops a registered root that currently holds no docs' do
        empty = File.join(@tmp, 'emptied', StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
        FileUtils.mkdir_p(empty)
        described_class.record(empty)

        expect(discovered_roots).to eq([])
      end

      it 'counts an .org-only root as having docs' do
        root = make_repo(@scan, 'org-only', 'doc.org')
        expect(discovered_roots).to eq([root])
      end

      # The two roots the host process owns are exempt: they are where its own
      # Save-as-doc writes, and the reader mtime-watches every root it is
      # handed, so dropping an empty one would mean the FIRST doc saved into it
      # needed a restart to appear.
      it 'keeps the host repo docs root even while it holds no docs' do
        host = File.join(@tmp, 'host', StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
        FileUtils.mkdir_p(host)
        ENV['STREAMWEAVER_DOC_ROOT'] = host

        expect(described_class.roots).to include(host)
      end

      it 'keeps the global store even while it holds no docs' do
        global = File.join(@tmp, 'globalstore')
        FileUtils.mkdir_p(global)
        stub_const('StreamWeaver::Canvas::DocStore::DEFAULT_ROOT', global)

        expect(described_class.roots).to include(global)
      end
    end
  end

  describe '.record_if_new' do
    it 'records a directory nothing else discovers' do
      root = make_repo(@tmp, 'outsider')
      expect(described_class.record_if_new(root)).to eq(root)
      expect(described_class.registered).to eq([root])
    end

    it 'does not record a directory the scan already finds' do
      root = make_repo(@scan, 'already-scanned')
      expect(described_class.record_if_new(root)).to be_nil
      expect(File.exist?(@registry)).to be(false)
    end

    it 'ignores a path that is not a directory' do
      expect(described_class.record_if_new(File.join(@tmp, 'nope'))).to be_nil
    end
  end

  describe '.labels' do
    it 'labels a repo docs root with the repo directory name' do
      root = make_repo(@scan, 'stream_weaver')
      expect(described_class.labels([root])).to eq(root => 'stream_weaver')
    end

    it 'labels the global store Global' do
      global = StreamWeaver::Canvas::DocStore::DEFAULT_ROOT
      expect(described_class.labels([global])).to eq(global => 'Global')
    end

    # A basename-keyed hash would silently drop one of these; the design
    # calls for disambiguating the display label instead.
    it 'disambiguates two same-named repos from different parents' do
      other = File.join(@tmp, 'src')
      FileUtils.mkdir_p(other)
      a = make_repo(@scan, 'notes')
      b = make_repo(other, 'notes')

      labels = described_class.labels([a, b])
      expect(labels.keys).to contain_exactly(a, b)
      expect(labels.values.uniq.size).to eq(2)
      expect(labels[a]).to eq('notes')
      expect(labels[b]).to eq('notes (src)')
    end
  end
end
