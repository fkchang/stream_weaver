# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/university/listener'
require 'stream_weaver/university/progress'

# Covers the button-id -> ledger-write mapping (progress-ledger: "Wire
# Mark-done and Run/Repeat as button actions that write the ledger").
# `.step!` (the live subscribe/re-push loop) needs a running bridge and is
# exercised by UAT, not here -- see the story's handoff note.
RSpec.describe StreamWeaver::University::Listener do
  around do |example|
    Dir.mktmpdir('university-listener-spec') do |dir|
      @path = File.join(dir, 'progress.yml')
      example.run
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

    it 'records a run request (the driver-worker-runner hook) for a run-N button id' do
      p = progress
      described_class.handle_token('btn_run_run-4', p)
      expect(p.requested_at(4)).to be_a(String)
    end

    it 'records a run request for a repeat-N button id' do
      p = progress
      described_class.handle_token('btn_repeat_repeat-2', p)
      expect(p.requested_at(2)).to be_a(String)
    end

    it 'records a run request for the resume band hero-run-N button id' do
      p = progress
      described_class.handle_token('btn_run_step_1_hero-run-1', p)
      expect(p.requested_at(1)).to be_a(String)
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
