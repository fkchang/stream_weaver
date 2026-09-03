# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'json'
require 'stream_weaver/iterm'
require 'stream_weaver/university/runner'
require 'stream_weaver/university/course'
require 'stream_weaver/university/progress'
require_relative '../support/env_helper'

# Covers driver-worker-runner: a Run/Repeat click sends that step's prompt
# to the ONE iTerm session `get-started` recorded in worker.json, and
# refuses to send anywhere at all when that target is gone or was never
# recorded. StreamWeaver::ITerm is fully stubbed here -- no iTerm2, no
# iterm2_ruby RPC. The live "it lands in the worker tab" check is UAT
# (see the story's handoff note).
RSpec.describe StreamWeaver::University::Runner do
  include EnvHelper

  around do |example|
    Dir.mktmpdir('university-runner-spec') do |dir|
      @worker_path = File.join(dir, 'worker.json')
      @progress_path = File.join(dir, 'progress.yml')
      with_env(
        'STREAMWEAVER_UNIVERSITY_WORKER' => @worker_path,
        'STREAMWEAVER_UNIVERSITY_PROGRESS' => @progress_path
      ) { example.run }
    end
  end

  def write_worker(session_id: 'worker-session-1', **extra)
    File.write(@worker_path, JSON.pretty_generate({
      session_id: session_id,
      agent: 'claude',
      cwd: '/tmp/project',
      controller_session_id: 'ctrl-1',
      created_at: '2026-08-28T00:00:00Z'
    }.merge(extra)))
  end

  def progress
    StreamWeaver::University::Progress.new(@progress_path)
  end

  def step_1_prompt
    StreamWeaver::University::Course::GETTING_STARTED_STEPS.first[:prompt]
  end

  describe '.worker' do
    it 'reads the session id recorded by get-started' do
      write_worker(session_id: 'w-42')

      expect(described_class.worker['session_id']).to eq('w-42')
    end

    it 'is nil when no worker.json exists (degraded / browser-only path)' do
      expect(described_class.worker).to be_nil
    end

    it 'is nil rather than raising when worker.json is malformed' do
      File.write(@worker_path, '{ not json at all')

      expect(described_class.worker).to be_nil
    end
  end

  describe '.run_step! — premier path' do
    before do
      write_worker(session_id: 'worker-session-1')
      allow(StreamWeaver::ITerm).to receive(:session_alive?).with('worker-session-1').and_return(true)
      allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(true)
    end

    it "sends step N's prompt to the recorded session id, and to no other id" do
      described_class.run_step!(1)

      expect(StreamWeaver::ITerm).to have_received(:send_to_session)
        .with('worker-session-1', described_class.one_line(step_1_prompt)).once
      expect(StreamWeaver::ITerm).not_to have_received(:send_to_session)
        .with(satisfy { |id| id != 'worker-session-1' }, anything)
    end

    # The prompts are multi-line heredocs. Typed verbatim at an agent TUI,
    # every embedded newline is a keystroke: either each line submits as
    # its own turn (step 1 asks the agent to write "a tiny script that
    # pushes one card to a") or nothing submits at all -- and the ledger
    # would record :sent either way. They go as one line.
    it 'sends the prompt as a single line, with no embedded newlines' do
      described_class.run_step!(2)

      sent = nil
      expect(StreamWeaver::ITerm).to have_received(:send_to_session) { |_id, text| sent = text }
      expect(sent).not_to include("\n")
      expect(sent).to include('increments a counter held in `state`')
    end

    it 'leaves pressing Return to the adapter rather than appending its own newline' do
      described_class.run_step!(1)

      sent = nil
      expect(StreamWeaver::ITerm).to have_received(:send_to_session) { |_id, text| sent = text }
      expect(sent).not_to end_with("\n")
      expect(sent).not_to end_with("\r")
    end

    # The bracketed-paste wrapping lives in the adapter (ITerm.send_to_session)
    # so every driver caller gets it. The runner's half of that bargain is to
    # hand over prompt text and nothing terminal-shaped -- if it bracketed too,
    # the block would be nested and the markers would land in the composer.
    it 'hands the adapter plain prompt text, with no paste escapes of its own' do
      described_class.run_step!(1)

      sent = nil
      expect(StreamWeaver::ITerm).to have_received(:send_to_session) { |_id, text| sent = text }
      expect(sent).not_to include("\e[200~")
      expect(sent).not_to include("\e[201~")
    end

    it 'reports :sent with the step, prompt, and target session' do
      result = described_class.run_step!(1)

      expect(result.status).to eq(:sent)
      expect(result.step).to eq(1)
      expect(result.prompt).to eq(step_1_prompt)
      expect(result.session_id).to eq('worker-session-1')
    end

    it 'records requested_at for that step in progress.yml' do
      described_class.run_step!(3)

      expect(progress.requested_at(3)).to be_a(String)
      expect(progress.requested_at(3)).not_to be_empty
    end

    it 'records the outcome as last_run so the next render can report it' do
      described_class.run_step!(2)

      expect(progress.last_run).to include('step' => 2, 'status' => 'sent')
    end

    it 'verifies the session is alive BEFORE sending anything' do
      described_class.run_step!(1)

      expect(StreamWeaver::ITerm).to have_received(:session_alive?).with('worker-session-1')
    end

    it 'reports :send_failed and records no requested_at when the RPC refuses' do
      allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(false)

      result = described_class.run_step!(1)

      expect(result.status).to eq(:send_failed)
      expect(result.prompt).to eq(step_1_prompt)
      expect(progress.requested_at(1)).to be_nil
    end
  end

  describe '.run_step! — closed or wrong target' do
    before do
      write_worker(session_id: 'worker-session-1')
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(false)
      allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(true)
    end

    it 'sends nowhere at all when the recorded session no longer exists' do
      described_class.run_step!(1)

      expect(StreamWeaver::ITerm).not_to have_received(:send_to_session)
    end

    it 'reports :session_missing with the prompt kept for the copy fallback' do
      result = described_class.run_step!(1)

      expect(result.status).to eq(:session_missing)
      expect(result.prompt).to eq(step_1_prompt)
      expect(result.message).to include('streamweaver get-started')
    end

    it 'records no requested_at — nothing was sent' do
      described_class.run_step!(1)

      expect(progress.requested_at(1)).to be_nil
    end
  end

  describe '.run_step! — degraded (no worker.json)' do
    before do
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(true)
      allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(true)
    end

    it 'sends nowhere and never even looks for a session' do
      described_class.run_step!(1)

      expect(StreamWeaver::ITerm).not_to have_received(:send_to_session)
      expect(StreamWeaver::ITerm).not_to have_received(:session_alive?)
    end

    it 'reports :no_worker with the prompt to copy and paste instructions' do
      result = described_class.run_step!(1)

      expect(result.status).to eq(:no_worker)
      expect(result.prompt).to eq(step_1_prompt)
      expect(result.message).to include('paste')
    end

    it 'still records last_run so the canvas can show the copy fallback' do
      described_class.run_step!(4)

      expect(progress.last_run).to include('step' => 4, 'status' => 'no_worker')
    end
  end

  describe '.run_step! — unknown step' do
    before do
      write_worker
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(true)
      allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(true)
    end

    it 'sends nothing for a step number the course does not have' do
      result = described_class.run_step!(99)

      expect(result.status).to eq(:unknown_step)
      expect(StreamWeaver::ITerm).not_to have_received(:send_to_session)
    end

    # Otherwise the previous notice stays pinned to the canvas, attributed
    # to a step the user did not just click.
    it 'still supersedes the previous run notice in the ledger' do
      described_class.run_step!(1)
      described_class.run_step!(99)

      expect(progress.last_run).to include('step' => 99, 'status' => 'unknown_step')
    end
  end
end
