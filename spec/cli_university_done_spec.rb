# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/university/progress'
require 'stream_weaver/university/listener'
require_relative 'support/env_helper'

# Covers `streamweaver university-done <N>` (lib/stream_weaver/cli.rb):
# the terminal door every step's closing ritual now runs itself, instead of
# handing a "click Mark done" click back to the user (round-8 UAT). Same
# ledger write as the canvas's own Mark-done button
# (University::Listener.mark_step_done!), plus bringing the controller
# window forward the same way `canvas-raise` does.
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
    Dir.mktmpdir('university-done-cli-spec') do |dir|
      @path = File.join(dir, 'progress.yml')
      with_env('STREAMWEAVER_UNIVERSITY_PROGRESS' => @path) { example.run }
    end
  end

  def progress
    StreamWeaver::University::Progress.new(@path)
  end

  describe '.university_done' do
    it 'rejects a missing or non-numeric step argument' do
      expect { capture_io { described_class.university_done([]) } }.to raise_error(SystemExit)
      expect { capture_io { described_class.university_done(['three']) } }.to raise_error(SystemExit)
    end

    it 'rejects a step number the course does not have' do
      expect { capture_io { described_class.university_done(['42']) } }.to raise_error(SystemExit)
      expect(progress.done?(42)).to be(false)
    end

    it 'marks the step done in the ledger, clears any expanded row, and raises the controller' do
      progress.expand_step!(2)
      allow(described_class).to receive(:canvas_raise)
      allow(StreamWeaver::University::Listener).to receive(:repush)

      capture_io { described_class.university_done(['2']) }

      expect(progress.done?(2)).to be(true)
      expect(progress.expanded_step).to be_nil
    end

    it 'repushes the controller and raises the university canvas, marking done BEFORE raising' do
      order = []
      allow(StreamWeaver::University::Listener).to receive(:repush) { order << :repush }
      allow(described_class).to receive(:canvas_raise) { order << :canvas_raise }

      out, = capture_io { described_class.university_done(['1']) }

      expect(StreamWeaver::University::Listener).to have_received(:repush)
      expect(described_class).to have_received(:canvas_raise).with(['university'])
      expect(order).to eq(%i[repush canvas_raise])
      expect(out).to match(/Marked step 1 done\./)
    end

    it 'reports the ledger write even when the bridge cannot be reached' do
      allow(StreamWeaver::University::Listener).to receive(:repush)
        .and_raise(StreamWeaver::Canvas::Client::NotRunningError, 'no bridge')

      out, = capture_io { described_class.university_done(['1']) }

      expect(progress.done?(1)).to be(true)
      expect(out).to match(/progress saved/)
    end

    # canvas_raise (cli.rb) exits 1 when the university session isn't in
    # the bridge's own session list -- routine right after a
    # canvas-restart. The ledger write already landed by then, so this must
    # not read as a failure of the mark-done itself.
    it 'reports the ledger write even when canvas_raise finds no session to raise' do
      allow(StreamWeaver::University::Listener).to receive(:repush)
      allow(described_class).to receive(:canvas_raise) { exit 1 }

      out, = capture_io { described_class.university_done(['1']) }

      expect(progress.done?(1)).to be(true)
      expect(out).to match(/isn't open to bring forward/)
    end
  end
end
