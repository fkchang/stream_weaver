# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/canvas/doc_store'

# Coverage for the no-arg default behaviour of `streamweaver canvas-read`.
# When called with no args the command should look up the project's
# docs/streamweaver_canvas/ directory (via DocStore.path) and use it
# automatically. Falls back to a helpful usage message when the dir
# is missing or empty.
RSpec.describe StreamWeaver::CLI do
  # DocRoots always includes DocStore::DEFAULT_ROOT (~/.streamweaver/canvas)
  # as its own group -- by design, and with no ENV override, since the global
  # store is a fixed location. On a developer machine that has actually saved
  # a doc it is a real directory with real files in it, which would make these
  # expectations depend on whatever happens to be in the developer's home.
  # Stubbed to "doesn't exist" so every example sees only its own tmpdirs.
  def hide_global_doc_store
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:directory?)
      .with(StreamWeaver::Canvas::DocStore::DEFAULT_ROOT).and_return(false)
  end

  describe '.canvas_read with no args' do
    around do |ex|
      prev_doc  = ENV['STREAMWEAVER_DOC_ROOT']
      prev_hist = ENV['STREAMWEAVER_HISTORY_ROOT']
      Dir.mktmpdir do |doc_d|
        Dir.mktmpdir do |hist_d|
          ENV['STREAMWEAVER_DOC_ROOT']     = doc_d
          ENV['STREAMWEAVER_HISTORY_ROOT'] = hist_d
          @doc_root     = doc_d
          @history_root = hist_d
          ex.run
        end
      end
    ensure
      ENV['STREAMWEAVER_DOC_ROOT']     = prev_doc
      ENV['STREAMWEAVER_HISTORY_ROOT'] = prev_hist
    end

    before do
      hide_global_doc_store
      # Don't actually start the Sinatra server during specs.
      allow(StreamWeaver::Canvas::Reader).to receive(:run!)
      allow(StreamWeaver::Canvas::Reader).to receive(:find_available_port).and_return(45678)
      allow(StreamWeaver::Canvas::Reader).to receive(:set)
      allow(StreamWeaver::Canvas::Reader).to receive(:configure_files!)
      allow(described_class).to receive(:open_browser)
      # Suppress the background browser-open thread; let the reader thread spec
      # see the resolution logic without actually launching anything.
      allow(Thread).to receive(:new).and_yield
    end

    context 'when docs root exists with .rb files' do
      before do
        FileUtils.mkdir_p(@doc_root)
        File.write(File.join(@doc_root, 'arch.rb'), "header1 'Arch'")
      end

      it 'auto-resolves to DocStore.path and configures the reader' do
        expect(StreamWeaver::Canvas::Reader).to receive(:configure_files!) do |list|
          expect(list.size).to eq(1)
          expect(list.files.first).to end_with('arch.rb')
        end
        expect { described_class.canvas_read([]) }.to output(/canvas-read.*1 file/).to_stdout
      end

      it 'prints the default path so the user knows what was opened' do
        expect { described_class.canvas_read([]) }.to output(/#{Regexp.escape(@doc_root)}/).to_stdout
      end
    end

    # The default used to glob '*.rb' only, so a repo whose docs were all
    # saved as .org read as empty and was dropped entirely -- even though
    # FileList.build has globbed '*.{rb,org}' since stream_weaver-gnj8.
    context 'when docs root holds only .org docs' do
      before do
        FileUtils.mkdir_p(@doc_root)
        File.write(File.join(@doc_root, 'arch.org'), "#+STREAMWEAVER_DSL: 1\n* Arch\n")
      end

      it 'still finds the docs root' do
        expect(StreamWeaver::Canvas::Reader).to receive(:configure_files!) do |list|
          expect(list.files.map { |f| File.basename(f) }).to eq(['arch.org'])
        end
        expect { described_class.canvas_read([]) }.to output(/canvas-read.*1 file/).to_stdout
      end
    end

    # Cross-repo discovery (stream_weaver-iugu): a doc saved in another repo
    # has to show up here, labeled, without any per-repo setup step.
    context 'with peer repos discovered by scan and registry' do
      around do |ex|
        saved = ENV.to_hash.slice('STREAMWEAVER_DOCS_REGISTRY', 'STREAMWEAVER_DOCS_SCAN_ROOTS')
        Dir.mktmpdir do |tmp|
          @scan = File.join(tmp, 'work')
          FileUtils.mkdir_p(@scan)
          @scanned_repo = File.join(@scan, 'peer-scanned', StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
          @far_repo     = File.join(tmp, 'elsewhere', 'peer-registered',
                                    StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
          [@scanned_repo, @far_repo].each { |d| FileUtils.mkdir_p(d) }
          File.write(File.join(@scanned_repo, 'scanned.rb'), "header1 'Scanned'")
          File.write(File.join(@far_repo, 'registered.rb'), "header1 'Registered'")

          ENV['STREAMWEAVER_DOCS_SCAN_ROOTS'] = @scan
          ENV['STREAMWEAVER_DOCS_REGISTRY']   = File.join(tmp, 'docs_roots.log')
          File.write(ENV['STREAMWEAVER_DOCS_REGISTRY'], "#{@far_repo}\n")
          ex.run
        end
      ensure
        saved.each { |k, v| ENV[k] = v }
      end

      before do
        FileUtils.mkdir_p(@doc_root)
        File.write(File.join(@doc_root, 'host.rb'), "header1 'Host'")
      end

      it 'includes the host repo, a scanned peer and a registered peer' do
        expect(StreamWeaver::Canvas::Reader).to receive(:configure_files!) do |list|
          expect(list.files.map { |f| File.basename(f) })
            .to contain_exactly('host.rb', 'scanned.rb', 'registered.rb')
        end
        expect { described_class.canvas_read([]) }.to output.to_stdout
      end

      it 'labels each group by its repo name' do
        expect(StreamWeaver::Canvas::Reader).to receive(:configure_files!) do |list|
          expect(list.label_for(@scanned_repo)).to eq('peer-scanned')
          expect(list.label_for(@far_repo)).to eq('peer-registered')
        end
        expect { described_class.canvas_read([]) }.to output.to_stdout
      end

      it 'does not double-list a repo present in both scan and registry' do
        File.write(ENV['STREAMWEAVER_DOCS_REGISTRY'], "#{@far_repo}\n#{@scanned_repo}\n")

        expect(StreamWeaver::Canvas::Reader).to receive(:configure_files!) do |list|
          expect(list.files.count { |f| File.basename(f) == 'scanned.rb' }).to eq(1)
        end
        expect { described_class.canvas_read([]) }.to output.to_stdout
      end

      it 'names the scan roots and their override so an absent repo is explainable' do
        expect { described_class.canvas_read([]) }.to(
          output(/scanned: #{Regexp.escape(@scan)}.*STREAMWEAVER_DOCS_SCAN_ROOTS/m).to_stdout
        )
      end
    end

    context 'when docs root is missing or empty' do
      it 'prints helpful usage and exits non-zero' do
        # No files written to @doc_root → empty.
        expect { described_class.canvas_read([]) }.to(
          raise_error(SystemExit) { |err| expect(err.status).to eq(1) }
            .and(output(/Usage: streamweaver canvas-read/).to_stderr)
        )
      end

      it 'mentions the default path it tried' do
        expect { described_class.canvas_read([]) }.to(
          raise_error(SystemExit)
            .and(output(/#{Regexp.escape(@doc_root)}/).to_stderr)
        )
      end
    end
  end

  describe '.canvas_read with explicit args (regression)' do
    around do |ex|
      prev_doc  = ENV['STREAMWEAVER_DOC_ROOT']
      prev_hist = ENV['STREAMWEAVER_HISTORY_ROOT']
      Dir.mktmpdir do |doc_d|
        Dir.mktmpdir do |hist_d|
          ENV['STREAMWEAVER_DOC_ROOT']     = doc_d
          ENV['STREAMWEAVER_HISTORY_ROOT'] = hist_d
          @doc_root = doc_d
          ex.run
        end
      end
    ensure
      ENV['STREAMWEAVER_DOC_ROOT']     = prev_doc
      ENV['STREAMWEAVER_HISTORY_ROOT'] = prev_hist
    end

    before do
      allow(StreamWeaver::Canvas::Reader).to receive(:run!)
      allow(StreamWeaver::Canvas::Reader).to receive(:find_available_port).and_return(45678)
      allow(StreamWeaver::Canvas::Reader).to receive(:set)
      allow(StreamWeaver::Canvas::Reader).to receive(:configure_files!)
      allow(described_class).to receive(:open_browser)
      allow(Thread).to receive(:new).and_yield
    end

    # --theme/--layout are a fallback for docs with no `use_theme`/`use_layout`
    # of their own; they must not survive into FileList.build as paths
    # (stream_weaver-csf).
    describe '--theme / --layout flags' do
      after { StreamWeaver::Canvas::Reader.configure_defaults!(theme: nil, layout: nil) }

      it 'passes them to the reader as render defaults and strips them from args' do
        Dir.mktmpdir do |explicit|
          File.write(File.join(explicit, 'explicit.rb'), "header1 'Explicit'")

          expect(StreamWeaver::Canvas::Reader).to receive(:configure_files!) do |list|
            expect(list.files.map { |f| File.basename(f) }).to eq(['explicit.rb'])
          end

          expect do
            described_class.canvas_read(['--theme=doc', explicit, '--layout=wide'])
          end.to output.to_stdout

          expect(StreamWeaver::Canvas::Reader.default_theme).to eq(:doc)
          expect(StreamWeaver::Canvas::Reader.default_layout).to eq(:wide)
        end
      end

      it 'leaves the defaults nil when the flags are absent' do
        Dir.mktmpdir do |explicit|
          File.write(File.join(explicit, 'explicit.rb'), "header1 'Explicit'")
          expect { described_class.canvas_read([explicit]) }.to output.to_stdout
          expect(StreamWeaver::Canvas::Reader.default_theme).to be_nil
          expect(StreamWeaver::Canvas::Reader.default_layout).to be_nil
        end
      end
    end

    # Backfill (stream_weaver-iugu): opening a pre-existing doc dir by hand is
    # what makes that repo discoverable from every later canvas-read, so there
    # is no separate "register this repo" command to know about.
    describe 'registry backfill' do
      around do |ex|
        saved = ENV.to_hash.slice('STREAMWEAVER_DOCS_REGISTRY', 'STREAMWEAVER_DOCS_SCAN_ROOTS')
        Dir.mktmpdir do |tmp|
          @registry = File.join(tmp, 'docs_roots.log')
          @scan     = File.join(tmp, 'work')
          FileUtils.mkdir_p(@scan)
          ENV['STREAMWEAVER_DOCS_REGISTRY']   = @registry
          ENV['STREAMWEAVER_DOCS_SCAN_ROOTS'] = @scan
          ex.run
        end
      ensure
        saved.each { |k, v| ENV[k] = v }
      end

      it 'records an explicit directory that nothing else discovers' do
        Dir.mktmpdir do |far|
          File.write(File.join(far, 'far.rb'), "header1 'Far'")
          expect { described_class.canvas_read([far]) }.to output.to_stdout
          expect(File.readlines(@registry, chomp: true)).to include(File.expand_path(far))
        end
      end

      it "records an explicit file's directory" do
        Dir.mktmpdir do |far|
          doc = File.join(far, 'far.rb')
          File.write(doc, "header1 'Far'")
          expect { described_class.canvas_read([doc]) }.to output.to_stdout
          expect(File.readlines(@registry, chomp: true)).to include(File.expand_path(far))
        end
      end

      it 'does not record a directory the scan already finds' do
        already = File.join(@scan, 'seen', StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
        FileUtils.mkdir_p(already)
        File.write(File.join(already, 'seen.rb'), "header1 'Seen'")

        expect { described_class.canvas_read([already]) }.to output.to_stdout
        expect(File.exist?(@registry)).to be(false)
      end
    end

    it 'uses the explicit path even when default exists' do
      FileUtils.mkdir_p(@doc_root)
      File.write(File.join(@doc_root, 'default.rb'), "header1 'Default'")

      Dir.mktmpdir do |explicit|
        File.write(File.join(explicit, 'explicit.rb'), "header1 'Explicit'")

        expect(StreamWeaver::Canvas::Reader).to receive(:configure_files!) do |list|
          expect(list.files.first).to end_with('explicit.rb')
        end

        expect { described_class.canvas_read([explicit]) }.to output.to_stdout
      end
    end
  end
end
