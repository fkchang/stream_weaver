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
  end
end
