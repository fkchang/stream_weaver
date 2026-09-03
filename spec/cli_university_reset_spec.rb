# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/university/progress'
require 'stream_weaver/university/listener'
require_relative 'support/env_helper'

# Covers `streamweaver university-reset` (lib/stream_weaver/cli.rb): the
# terminal door onto the same "Reset course" the canvas's own button
# triggers (University::Listener.handle_token's "reset-course" branch) --
# back up + clear the progress ledger, close the demo canvas sessions the
# course itself opened, and re-push the course list at its zero-state.
RSpec.describe StreamWeaver::CLI do
  include EnvHelper

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

  around do |example|
    Dir.mktmpdir('university-reset-cli-spec') do |dir|
      @path = File.join(dir, 'progress.yml')
      with_env('STREAMWEAVER_UNIVERSITY_PROGRESS' => @path) { example.run }
    end
  end

  def progress
    StreamWeaver::University::Progress.new(@path)
  end

  describe '.university_reset' do
    context 'with --yes (skips the confirm)' do
      it 'clears the progress ledger' do
        progress.mark_done!(1)

        allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(false)

        capture_io { described_class.university_reset(['--yes']) }

        expect(progress.done_steps).to eq([])
      end

      it 'backs the ledger up first' do
        progress.mark_done!(1)
        allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(false)

        capture_io { described_class.university_reset(['-y']) }

        expect(File.exist?("#{@path}.bak")).to be(true)
      end

      it 'closes the demo sessions and re-pushes the course list when a bridge is running' do
        allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(true)
        allow(StreamWeaver::University::Listener).to receive(:close_demo_sessions!)
        allow(StreamWeaver::University::Listener).to receive(:repush)

        capture_io { described_class.university_reset(['--yes']) }

        expect(StreamWeaver::University::Listener).to have_received(:close_demo_sessions!)
        expect(StreamWeaver::University::Listener).to have_received(:repush)
      end

      it 'skips closing sessions and re-pushing when no bridge is running' do
        allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(false)
        allow(StreamWeaver::University::Listener).to receive(:close_demo_sessions!)
        allow(StreamWeaver::University::Listener).to receive(:repush)

        out, _err = capture_io { described_class.university_reset(['--yes']) }

        expect(StreamWeaver::University::Listener).not_to have_received(:close_demo_sessions!)
        expect(StreamWeaver::University::Listener).not_to have_received(:repush)
        expect(out).to match(/not running/)
      end
    end

    context 'without --yes (interactive confirm)' do
      it 'does nothing when the user declines' do
        progress.mark_done!(1)
        allow($stdin).to receive(:tty?).and_return(true)
        allow($stdin).to receive(:gets).and_return("n\n")

        capture_io { described_class.university_reset([]) }

        expect(progress.done?(1)).to be(true)
      end

      it 'resets when the user confirms' do
        progress.mark_done!(1)
        allow($stdin).to receive(:tty?).and_return(true)
        allow($stdin).to receive(:gets).and_return("y\n")
        allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(false)

        capture_io { described_class.university_reset([]) }

        expect(progress.done_steps).to eq([])
      end

      it 'defaults to "no" on a bare Enter -- this is destructive' do
        progress.mark_done!(1)
        allow($stdin).to receive(:tty?).and_return(true)
        allow($stdin).to receive(:gets).and_return("\n")

        capture_io { described_class.university_reset([]) }

        expect(progress.done?(1)).to be(true)
      end
    end
  end
end
