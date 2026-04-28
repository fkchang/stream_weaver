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
  describe '.canvas_read with no args' do
    around do |ex|
      prev = ENV['STREAMWEAVER_DOC_ROOT']
      Dir.mktmpdir do |d|
        ENV['STREAMWEAVER_DOC_ROOT'] = d
        @doc_root = d
        ex.run
      end
    ensure
      ENV['STREAMWEAVER_DOC_ROOT'] = prev
    end

    before do
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
      prev = ENV['STREAMWEAVER_DOC_ROOT']
      Dir.mktmpdir do |d|
        ENV['STREAMWEAVER_DOC_ROOT'] = d
        @doc_root = d
        ex.run
      end
    ensure
      ENV['STREAMWEAVER_DOC_ROOT'] = prev
    end

    before do
      allow(StreamWeaver::Canvas::Reader).to receive(:run!)
      allow(StreamWeaver::Canvas::Reader).to receive(:find_available_port).and_return(45678)
      allow(StreamWeaver::Canvas::Reader).to receive(:set)
      allow(StreamWeaver::Canvas::Reader).to receive(:configure_files!)
      allow(described_class).to receive(:open_browser)
      allow(Thread).to receive(:new).and_yield
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
