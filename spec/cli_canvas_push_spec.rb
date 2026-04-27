# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'stringio'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/canvas/history'

RSpec.describe StreamWeaver::CLI do
  describe '.canvas_push (history auto-save)' do
    let(:dsl) { "header1 'Hi'" }
    let(:session_name) { 'mytest' }

    around do |ex|
      prev = ENV['STREAMWEAVER_HISTORY_ROOT']
      Dir.mktmpdir do |d|
        ENV['STREAMWEAVER_HISTORY_ROOT'] = d
        @history_root = d
        # Reset the once-per-process cleanup flag so each example exercises it.
        if described_class.instance_variable_defined?(:@history_cleaned)
          described_class.remove_instance_variable(:@history_cleaned)
        end
        ex.run
      end
    ensure
      ENV['STREAMWEAVER_HISTORY_ROOT'] = prev
    end

    before do
      allow($stdin).to receive(:tty?).and_return(false)
      allow($stdin).to receive(:read).and_return(dsl)
    end

    def capture_io
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new
      yield
      [$stdout.string, $stderr.string]
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end

    context 'when the bridge accepts the push (success)' do
      before do
        # send_message returns nil on success in the canvas_push flow (no
        # response type triggers the error branches).
        allow(StreamWeaver::Canvas::Client).to receive(:send_message).and_return(nil)
      end

      it 'saves the DSL to <root>/<session>/<timestamp>.rb after a successful push' do
        capture_io { described_class.canvas_push([session_name]) }

        saved = Dir.glob(File.join(@history_root, session_name, '*.rb'))
        expect(saved.size).to eq(1)
        expect(File.read(saved.first)).to eq(dsl)
      end

      it 'prints the saved path on stderr (and keeps the existing "Pushed to" line on stdout)' do
        stdout, stderr = capture_io { described_class.canvas_push([session_name]) }
        expect(stdout).to include("Pushed to #{session_name}")
        expect(stderr).to include('saved:')
        expect(stderr).to include(@history_root)
      end

      it 'runs History.cleanup once across multiple pushes in the same process' do
        expect(StreamWeaver::Canvas::History).to receive(:cleanup).once.and_call_original

        capture_io do
          described_class.canvas_push([session_name])
          described_class.canvas_push([session_name])
          described_class.canvas_push([session_name])
        end
      end

      it 'still marks cleanup-as-done if cleanup raises (does not retry)' do
        call_count = 0
        allow(StreamWeaver::Canvas::History).to receive(:cleanup) do
          call_count += 1
          raise StandardError, 'boom'
        end

        capture_io do
          described_class.canvas_push([session_name])
          described_class.canvas_push([session_name])
        end
        expect(call_count).to eq(1)
      end
    end

    context 'when the bridge returns push_error' do
      before do
        allow(StreamWeaver::Canvas::Client).to receive(:send_message)
          .and_return({ type: 'push_error', message: 'bad DSL' })
      end

      it 'does NOT save to history' do
        expect { capture_io { described_class.canvas_push([session_name]) } }
          .to raise_error(SystemExit)
        expect(Dir.glob(File.join(@history_root, session_name, '*.rb'))).to be_empty
      end
    end

    context 'when the bridge returns a generic error' do
      before do
        allow(StreamWeaver::Canvas::Client).to receive(:send_message)
          .and_return({ type: 'error', message: 'kaboom' })
      end

      it 'does NOT save to history' do
        expect { capture_io { described_class.canvas_push([session_name]) } }
          .to raise_error(SystemExit)
        expect(Dir.glob(File.join(@history_root, session_name, '*.rb'))).to be_empty
      end
    end

    context 'when the bridge raises a connection error' do
      before do
        allow(StreamWeaver::Canvas::Client).to receive(:send_message)
          .and_raise(StreamWeaver::Canvas::Client::ConnectionError, 'no bridge')
      end

      it 'does NOT save to history' do
        expect { capture_io { described_class.canvas_push([session_name]) } }
          .to raise_error(SystemExit)
        expect(Dir.glob(File.join(@history_root, session_name, '*.rb'))).to be_empty
      end
    end

    context 'when the bridge raises a not-running error' do
      before do
        allow(StreamWeaver::Canvas::Client).to receive(:send_message)
          .and_raise(StreamWeaver::Canvas::Client::NotRunningError, 'bridge not running')
      end

      it 'does NOT save to history' do
        expect { capture_io { described_class.canvas_push([session_name]) } }
          .to raise_error(SystemExit)
        expect(Dir.glob(File.join(@history_root, session_name, '*.rb'))).to be_empty
      end
    end

    context 'when History.record raises (e.g. invalid session name)' do
      before do
        allow(StreamWeaver::Canvas::Client).to receive(:send_message).and_return(nil)
        allow(StreamWeaver::Canvas::History).to receive(:record)
          .and_raise(ArgumentError, 'invalid session name: "weird/name"')
      end

      it 'still reports the push as successful and does not raise' do
        stdout, stderr = capture_io { described_class.canvas_push([session_name]) }
        expect(stdout).to include("Pushed to #{session_name}")
        expect(stderr).to include('history save skipped')
      end
    end
  end
end
