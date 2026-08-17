# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'stream_weaver/canvas/doc_store'

RSpec.describe StreamWeaver::Canvas::DocStore do
  around do |ex|
    prev = ENV['STREAMWEAVER_DOC_ROOT']
    Dir.mktmpdir do |d|
      ENV['STREAMWEAVER_DOC_ROOT'] = d
      @root = d
      ex.run
    end
  ensure
    ENV['STREAMWEAVER_DOC_ROOT'] = prev
  end

  describe '.path' do
    it 'returns the STREAMWEAVER_DOC_ROOT env var when set' do
      expect(described_class.path).to eq(@root)
    end

    context 'when env var is unset' do
      around do |ex|
        prev = ENV['STREAMWEAVER_DOC_ROOT']
        ENV.delete('STREAMWEAVER_DOC_ROOT')
        ex.run
      ensure
        ENV['STREAMWEAVER_DOC_ROOT'] = prev
      end

      it 'returns <git_root>/docs/streamweaver_canvas when inside a git repo' do
        Dir.mktmpdir do |tmp|
          repo = File.join(tmp, 'repo')
          nested = File.join(repo, 'a', 'b')
          FileUtils.mkdir_p(File.join(repo, '.git'))
          FileUtils.mkdir_p(nested)

          # Use realpath: on macOS Dir.chdir resolves /var -> /private/var,
          # so git_root walks up from the realpath form.
          expected_root = File.realpath(repo)

          Dir.chdir(nested) do
            expect(described_class.path)
              .to eq(File.join(expected_root, 'docs', 'streamweaver_canvas'))
          end
        end
      end

      it 'falls back to ~/.streamweaver/canvas when not in a git repo' do
        # Stub git_root to nil to simulate "not in a repo" without depending
        # on the ambient filesystem (the tmpdir's ancestors might include a
        # .git directory on a contributor's machine).
        allow(described_class).to receive(:git_root).and_return(nil)
        expect(described_class.path).to eq(File.expand_path('~/.streamweaver/canvas'))
      end
    end
  end

  describe '.git_root' do
    it 'returns the directory containing .git' do
      Dir.mktmpdir do |tmp|
        repo = File.join(tmp, 'repo')
        nested = File.join(repo, 'a', 'b', 'c')
        FileUtils.mkdir_p(File.join(repo, '.git'))
        FileUtils.mkdir_p(nested)

        expect(described_class.git_root(nested)).to eq(File.expand_path(repo))
      end
    end

    it 'returns nil when no .git ancestor exists' do
      Dir.mktmpdir do |tmp|
        leaf = File.join(tmp, 'no-repo', 'sub')
        FileUtils.mkdir_p(leaf)
        # Need to confirm none of tmp's ancestors are a git repo before asserting
        # nil. Walk up; if any ancestor is a repo, skip the assertion.
        ancestor_repo = nil
        dir = File.expand_path(tmp)
        loop do
          if File.exist?(File.join(dir, '.git'))
            ancestor_repo = dir
            break
          end
          parent = File.dirname(dir)
          break if parent == dir
          dir = parent
        end

        skip 'tmpdir has a .git ancestor' if ancestor_repo
        expect(described_class.git_root(leaf)).to be_nil
      end
    end

    it 'treats .git as a hit whether it is a directory or a file (worktree)' do
      Dir.mktmpdir do |tmp|
        repo = File.join(tmp, 'wt')
        FileUtils.mkdir_p(repo)
        # Worktrees use a .git FILE, not a directory.
        File.write(File.join(repo, '.git'), "gitdir: /elsewhere\n")

        expect(described_class.git_root(repo)).to eq(File.expand_path(repo))
      end
    end
  end

  # A saved doc is a bare DSL body, indistinguishable from ordinary Ruby to
  # anything that finds it out of context -- a renderer looking at a GitHub
  # blob, an editor plugin. The stamp is what makes it identifiable, so these
  # pin down that it is present, survives re-saving, and never runs twice.
  describe 'doc stamping' do
    describe '.stamped?' do
      it 'recognizes a stamped body' do
        expect(described_class.stamped?("#{described_class::STAMP}\nheader1 'Hi'")).to be(true)
      end

      it 'rejects an unstamped body' do
        expect(described_class.stamped?("header1 'Hi'")).to be(false)
      end

      it 'recognizes a stamp below a magic comment' do
        src = "# frozen_string_literal: true\n#{described_class::STAMP}\nheader1 'Hi'"
        expect(described_class.stamped?(src)).to be(true)
      end

      it 'recognizes a future stamp version, so a v2 doc is still a doc' do
        expect(described_class.stamped?("# streamweaver-doc: v2\nheader1 'Hi'")).to be(true)
      end

      it 'tolerates spacing variations' do
        expect(described_class.stamped?("#streamweaver-doc:v1\nx")).to be(true)
      end

      it 'ignores a stamp buried deeper than the scan window' do
        buried = (["md 'x'"] * 20).join("\n") + "\n#{described_class::STAMP}\n"
        expect(described_class.stamped?(buried)).to be(false)
      end

      it 'is false for non-strings' do
        expect(described_class.stamped?(nil)).to be(false)
      end
    end

    describe '.stamp' do
      it 'prepends the stamp' do
        expect(described_class.stamp("header1 'Hi'"))
          .to eq("#{described_class::STAMP}\nheader1 'Hi'")
      end

      it 'is idempotent, so re-saving does not accumulate stamps' do
        once  = described_class.stamp("header1 'Hi'")
        twice = described_class.stamp(once)
        expect(twice).to eq(once)
      end

      it 'stamps an empty body without leaving a stray blank line' do
        expect(described_class.stamp('')).to eq("#{described_class::STAMP}\n")
      end

      it 'leaves the body evaluable as Ruby' do
        stamped = described_class.stamp("$stamp_probe = 41 + 1")
        eval(stamped) # rubocop:disable Security/Eval
        expect($stamp_probe).to eq(42)
      end
    end

    it 'stamps on save, and re-saving the read-back content does not double it' do
      path  = described_class.save('doc', "header1 'Hi'")
      first = File.read(path)
      expect(described_class.stamped?(first)).to be(true)

      described_class.save('doc', first)
      expect(File.read(path)).to eq(first)
    end
  end

  # Half of canvas-read's cross-repo discovery (stream_weaver-iugu): saving
  # into a repo is what makes that repo's docs findable from a canvas-read
  # launched anywhere else, with no registration step to remember.
  describe '.save registry side effect' do
    around do |ex|
      prev = ENV['STREAMWEAVER_DOCS_REGISTRY']
      Dir.mktmpdir do |d|
        ENV['STREAMWEAVER_DOCS_REGISTRY'] = File.join(d, 'docs_roots.log')
        @registry = ENV['STREAMWEAVER_DOCS_REGISTRY']
        ex.run
      end
    ensure
      ENV['STREAMWEAVER_DOCS_REGISTRY'] = prev
    end

    it 'records the docs root it wrote to' do
      described_class.save('hello', "header1 'Hi'")
      expect(File.readlines(@registry, chomp: true)).to eq([@root])
    end

    it 'does not re-record the same root on every save' do
      3.times { |i| described_class.save("doc#{i}", "header1 'Hi'") }
      expect(File.readlines(@registry, chomp: true)).to eq([@root])
    end

    it 'does not record anything when the save itself fails' do
      expect { described_class.save('bad name!', "header1 'Hi'") }.to raise_error(ArgumentError)
      expect(File.exist?(@registry)).to be(false)
    end

    # Discovery is a convenience; the save is the user's actual work.
    it 'still saves when the registry cannot be written' do
      allow(StreamWeaver::Canvas::DocRoots).to receive(:registry_path)
        .and_return('/proc/nonexistent/docs_roots.log')
      path = described_class.save('hello', "header1 'Hi'")
      expect(File.read(path)).to include("header1 'Hi'")
    end
  end

  describe '.save' do
    it 'writes the DSL to <path>/<name>.rb and returns the absolute path' do
      path = described_class.save('hello', "header1 'Hi'")
      expect(File.read(path)).to eq("#{described_class::STAMP}\nheader1 'Hi'")
      expect(path).to eq(File.join(@root, 'hello.rb'))
    end

    it 'creates the docs directory if missing' do
      nested = File.join(@root, 'subdir-not-yet')
      ENV['STREAMWEAVER_DOC_ROOT'] = nested
      expect(Dir.exist?(nested)).to be(false)
      described_class.save('hello', 'x')
      expect(Dir.exist?(nested)).to be(true)
    end

    it 'forces a .rb extension when not present' do
      path = described_class.save('plain', 'x')
      expect(File.basename(path)).to eq('plain.rb')
    end

    it 'is idempotent on extension: save("foo") and save("foo.rb") use same filename' do
      p1 = described_class.save('foo', 'a')
      p2 = described_class.save('foo.rb', 'b')
      expect(p1).to eq(p2)
      expect(File.read(p1)).to eq("#{described_class::STAMP}\nb") # second write overwrites first
    end

    it 'allows descriptive names with extra dots (e.g. auth-flow.v2)' do
      path = described_class.save('auth-flow.v2', 'x')
      expect(File.basename(path)).to eq('auth-flow.v2.rb')
    end

    it 'rejects names containing path separators' do
      expect { described_class.save('a/b', 'x') }.to raise_error(ArgumentError)
      expect { described_class.save('a\\b', 'x') }.to raise_error(ArgumentError)
    end

    it 'rejects names containing ..' do
      expect { described_class.save('../evil', 'x') }.to raise_error(ArgumentError)
      expect { described_class.save('foo..bar', 'x') }.to raise_error(ArgumentError)
      expect { described_class.save('..foo', 'x') }.to raise_error(ArgumentError)
    end

    it 'rejects names containing null bytes' do
      expect { described_class.save("foo\0bar", 'x') }.to raise_error(ArgumentError)
    end

    it 'rejects empty or blank names' do
      expect { described_class.save('', 'x') }.to raise_error(ArgumentError)
      expect { described_class.save('   ', 'x') }.to raise_error(ArgumentError)
    end

    it 'rejects bare ".rb" (which would normalize to empty basename)' do
      expect { described_class.save('.rb', 'x') }.to raise_error(ArgumentError)
    end

    it 'rejects non-String input' do
      expect { described_class.save(nil, 'x') }.to raise_error(ArgumentError)
      expect { described_class.save(:sym, 'x') }.to raise_error(ArgumentError)
    end

    it 'accepts well-formed names (alnum, dot, underscore, dash)' do
      expect { described_class.save('brainstorm', 'x') }.not_to raise_error
      expect { described_class.save('auth-flow.v2_1', 'x') }.not_to raise_error
    end

    it 'accepts a .org extension, forcing it the same way .rb is forced' do
      path = described_class.save('mydoc.org', "#+STREAMWEAVER_DSL: 1\n")
      expect(path).to end_with('mydoc.org')
      expect(File.read(path)).to eq("#+STREAMWEAVER_DSL: 1\n")
    end

    it 'defaults to .rb when no recognized extension is given (unchanged existing behavior)' do
      path = described_class.save('mydoc', 'md "x"')
      expect(path).to end_with('mydoc.rb')
    end

    it 'still rejects invalid names when saving as .org' do
      expect { described_class.save('../evil.org', 'x') }.to raise_error(ArgumentError)
    end

    it 'rejects bare ".org" (which would normalize to empty basename), same as bare ".rb"' do
      expect { described_class.save('.org', 'x') }.to raise_error(ArgumentError)
    end

    # canvas-read rescans the docs directory on every render (stream_weaver-iugu),
    # so the window in which a reader can catch a save in progress is now hit
    # constantly. A plain File.write truncates before it fills, which is exactly
    # what those readers must never see (stream_weaver-5nvz).
    describe 'atomicity' do
      it 'never truncates the target -- a reader mid-save still sees the previous content' do
        path = described_class.save('doc', 'old')
        previous = File.read(path)

        # Sample the target at the last instant before the swap: that is what a
        # concurrent reader would get.
        seen = nil
        allow(File).to receive(:rename).and_wrap_original do |orig, *args|
          seen = File.read(path)
          orig.call(*args)
        end

        described_class.save('doc', 'new')

        expect(seen).to eq(previous)
        expect(File.read(path)).to eq("#{described_class::STAMP}\nnew")
      end

      it 'leaves no temp file behind on a successful save' do
        described_class.save('hello', 'x')
        expect(Dir.children(@root)).to contain_exactly('hello.rb')
      end

      it 'leaves no temp file behind in a freshly created directory' do
        nested = File.join(@root, 'brand-new')
        ENV['STREAMWEAVER_DOC_ROOT'] = nested

        path = described_class.save('hello', "header1 'Hi'")

        expect(path).to eq(File.join(nested, 'hello.rb'))
        expect(File.read(path)).to eq("#{described_class::STAMP}\nheader1 'Hi'")
        expect(Dir.children(nested)).to contain_exactly('hello.rb')
      end

      it 'cleans up the temp file and leaves the old doc intact when the swap fails' do
        described_class.save('doc', 'old')
        allow(File).to receive(:rename).and_raise(Errno::EACCES)

        expect { described_class.save('doc', 'new') }.to raise_error(Errno::EACCES)

        expect(Dir.children(@root)).to contain_exactly('doc.rb')
        expect(File.read(File.join(@root, 'doc.rb'))).to eq("#{described_class::STAMP}\nold")
      end
    end
  end

  # Shared by BOTH Save-as-doc routes (BridgeServer and Reader) so the two
  # buttons can never write differently shaped files (stream_weaver-csf).
  describe '.dsl_with_metadata' do
    it 'prepends use_theme/use_layout so canvas-read re-renders the same look' do
      expect(described_class.dsl_with_metadata("header1 'Hi'", theme: :doc, layout: :wide))
        .to eq("use_theme :doc\nuse_layout :wide\nheader1 'Hi'")
    end

    it 'is idempotent -- a DSL that already declares them is untouched' do
      dsl = "use_theme :dark\nuse_layout :full\nheader1 'Hi'"
      expect(described_class.dsl_with_metadata(dsl, theme: :doc, layout: :wide)).to eq(dsl)
    end

    it 'injects only the directive that is missing' do
      dsl = "use_theme :dark\nheader1 'Hi'"
      expect(described_class.dsl_with_metadata(dsl, theme: :doc, layout: :wide))
        .to eq("use_layout :wide\n#{dsl}")
    end

    it 'returns the DSL unchanged when neither theme nor layout is known' do
      expect(described_class.dsl_with_metadata("header1 'Hi'")).to eq("header1 'Hi'")
    end

    it 'only counts a declaration at the start of a line, not a mention mid-string' do
      dsl = "text 'call use_theme to set a theme'"
      expect(described_class.dsl_with_metadata(dsl, theme: :doc))
        .to eq("use_theme :doc\n#{dsl}")
    end
  end
end
