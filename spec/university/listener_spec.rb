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
      # STREAMWEAVER_UNIVERSITY_PROGRESS is here too so `.handle_event`
      # (which loads its own Progress internally) never touches the
      # developer's real ledger either.
      with_env('STREAMWEAVER_UNIVERSITY_WORKER' => File.join(dir, 'worker.json'),
               'STREAMWEAVER_UNIVERSITY_PROGRESS' => @path) { example.run }
    end
  end

  def progress
    StreamWeaver::University::Progress.new(@path)
  end

  # reset-course (via handle_token) and repush (via handle_event) both
  # reach Canvas::Client.send_message for real unless stubbed -- if a
  # bridge happens to be running on this machine, an unstubbed call would
  # either block on its timeout or touch whatever is really running the
  # `university` session. Stubbed globally so no example has to remember.
  before { allow(StreamWeaver::Canvas::Client).to receive(:send_message) }

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

    it 'opens the step screen for a view-N button id (a row\'s Details button)' do
      p = progress
      expect(described_class.handle_token('btn_details_view-2', p)).to eq(2)
      expect(p.viewing_step).to eq(2)
    end

    it 'opens the step screen for a next-N button id (the step screen\'s Next link)' do
      p = progress
      expect(described_class.handle_token('btn_next_step_4_next-4', p)).to eq(4)
      expect(p.viewing_step).to eq(4)
    end

    it 'returns to the course list for a back-to-list button id' do
      p = progress
      p.view_step!(2)

      expect(described_class.handle_token('btn_all_steps_back-to-list', p)).to be(true)
      expect(p.viewing_step).to be_nil
    end

    # progress-ledger's Reset deliverable: the canvas's "Reset course"
    # button and `streamweaver university-reset` both funnel through this
    # branch. Session closing is covered separately below
    # (`.close_demo_sessions!`); here it's enough that the branch calls it
    # and returns to the zero-state ledger.
    describe 'a reset-course button id' do
      it 'clears the ledger back to the zero-state' do
        p = progress
        p.mark_done!(1)
        p.mark_done!(2)
        allow(described_class).to receive(:close_demo_sessions!)

        described_class.handle_token('btn_reset_course_reset-course', p)

        expect(p.done_steps).to eq([])
      end

      it 'closes the demo canvas sessions' do
        allow(described_class).to receive(:close_demo_sessions!)

        described_class.handle_token('btn_reset_course_reset-course', progress)

        expect(described_class).to have_received(:close_demo_sessions!)
      end

      it 'returns true (a whole-course action, not a single step)' do
        allow(described_class).to receive(:close_demo_sessions!)

        expect(described_class.handle_token('btn_reset_course_reset-course', progress)).to be(true)
      end
    end

    # progress-ledger's Mark-done feedback deliverable: a silent ledger
    # write plus a later re-push reads as nothing happened. The
    # confirmation itself -- "Step N done -- ..." -- is rendered from
    # progress.last_done by canvas.rb on that same re-push (see
    # spec/university/canvas_spec.rb); handle_token's job is only to make
    # sure mark_done! (which stamps last_done) actually runs.
    describe 'a mark-done-N button id' do
      it 'stamps last_done so the next render can confirm it' do
        p = progress

        described_class.handle_token('btn_mark_done_mark-done-2', p)

        expect(p.last_done).to include('step' => 2)
      end

      # The confirmation band only exists on the course list (canvas.rb
      # has no equivalent on the step screen), and canvas.rb's own "Two
      # exits, deliberately unequal" comment claims Mark done returns
      # there -- so this has to be true regardless of which of the two
      # Mark-done buttons was clicked, the course-list row's or the step
      # screen's own.
      it 'clears the viewed step, landing back on the course list' do
        p = progress
        p.view_step!(2)

        described_class.handle_token('btn_mark_step_2_done_mark-done-2', p)

        expect(p.viewing_step).to be_nil
      end
    end
  end

  describe '.close_demo_sessions!' do
    it 'sends a close message for every demo session name, never the controller session' do
      allow(StreamWeaver::Canvas::Client).to receive(:send_message)

      described_class.close_demo_sessions!

      described_class::DEMO_SESSION_NAMES.each do |name|
        expect(StreamWeaver::Canvas::Client).to have_received(:send_message).with(
          hash_including(name: name, type: 'close')
        )
      end
      expect(StreamWeaver::Canvas::Client).not_to have_received(:send_message).with(
        hash_including(name: described_class::SESSION)
      )
    end

    it 'keeps closing the remaining sessions when one is not found' do
      allow(StreamWeaver::Canvas::Client).to receive(:send_message)
        .and_raise(StreamWeaver::Canvas::Client::NotRunningError, 'bridge down')

      expect { described_class.close_demo_sessions! }.not_to raise_error
      expect(StreamWeaver::Canvas::Client).to have_received(:send_message).exactly(described_class::DEMO_SESSION_NAMES.size).times
    end
  end

  describe '.handle_event' do
    it 'repushes to the given session_name after applying the token' do
      allow(described_class).to receive(:repush)

      described_class.handle_event({ data: { button: 'btn_mark_done_mark-done-1' } }, session_name: 'demo-session')

      expect(described_class).to have_received(:repush).with(session_name: 'demo-session')
    end
  end
end
