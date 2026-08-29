# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/university/listener'
require 'stream_weaver/university/progress'
require 'stream_weaver/university/runner'
require_relative '../support/env_helper'

# Covers the button-id -> ledger-write mapping (progress-ledger: "Wire
# Mark-done and Run/Repeat as button actions that write the ledger") and
# the Run/Repeat -> worker dispatch that driver-worker-runner wired on top
# of it. `.step!` (the live subscribe/re-push loop) needs a running bridge
# and is exercised by UAT, not here -- see the story's handoff note.
RSpec.describe StreamWeaver::University::Listener do
  include EnvHelper

  around do |example|
    Dir.mktmpdir('university-listener-spec') do |dir|
      @path = File.join(dir, 'progress.yml')
      # Points at a worker.json that this tmpdir never contains -- the
      # examples can then exercise the degraded path without ever being
      # able to reach the developer's real recorded worker session.
      with_env('STREAMWEAVER_UNIVERSITY_WORKER' => File.join(dir, 'worker.json')) { example.run }
    end
  end

  def progress
    StreamWeaver::University::Progress.new(@path)
  end

  describe '.handle_token' do
    it 'marks the step done for a mark-done-N button id' do
      p = progress
      described_class.handle_token('btn_mark_done_mark-done-3', p)
      expect(p.done?(3)).to be(true)
    end

    it 'dispatches a run-N button id to the worker runner' do
      allow(StreamWeaver::University::Runner).to receive(:run_step!)
      p = progress

      described_class.handle_token('btn_run_run-4', p)

      expect(StreamWeaver::University::Runner).to have_received(:run_step!).with(4, progress: p)
    end

    it 'dispatches a repeat-N button id to the worker runner' do
      allow(StreamWeaver::University::Runner).to receive(:run_step!)
      p = progress

      described_class.handle_token('btn_repeat_repeat-2', p)

      expect(StreamWeaver::University::Runner).to have_received(:run_step!).with(2, progress: p)
    end

    it 'dispatches the resume band hero-run-N button id to the worker runner' do
      allow(StreamWeaver::University::Runner).to receive(:run_step!)
      p = progress

      described_class.handle_token('btn_run_step_1_hero-run-1', p)

      expect(StreamWeaver::University::Runner).to have_received(:run_step!).with(1, progress: p)
    end

    it 'never dispatches to the runner for a mark-done button id' do
      allow(StreamWeaver::University::Runner).to receive(:run_step!)

      described_class.handle_token('btn_mark_done_mark-done-3', progress)

      expect(StreamWeaver::University::Runner).not_to have_received(:run_step!)
    end

    it 'records the degraded outcome in the ledger when no worker is recorded' do
      p = progress

      described_class.handle_token('btn_run_run-4', p)

      expect(progress.last_run).to include('step' => 4, 'status' => 'no_worker')
    end

    it 'returns the step number acted on' do
      p = progress
      expect(described_class.handle_token('btn_mark_done_mark-done-5', p)).to eq(5)
    end

    it 'returns nil and changes nothing for an unrecognized token' do
      p = progress
      expect(described_class.handle_token('btn_theme_toggle_x', p)).to be_nil
      expect(p.done_steps).to eq([])
    end
  end
end
