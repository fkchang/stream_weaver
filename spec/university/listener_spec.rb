# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'json'
require 'stream_weaver/university/listener'
require 'stream_weaver/university/progress'
require 'stream_weaver/university/runner'
require 'stream_weaver/iterm'
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
      # Points at a worker.json that this tmpdir never contains unless an
      # example writes one (write_worker, below) -- the examples can then
      # exercise the degraded path without ever being able to reach the
      # developer's real recorded worker session. STREAMWEAVER_UNIVERSITY_PROGRESS
      # is here too so `.handle_event` (which loads its own Progress
      # internally) never touches the developer's real ledger either.
      @worker_path = File.join(dir, 'worker.json')
      with_env('STREAMWEAVER_UNIVERSITY_WORKER' => @worker_path,
               'STREAMWEAVER_UNIVERSITY_PROGRESS' => @path) { example.run }
    end
  end

  def progress
    StreamWeaver::University::Progress.new(@path)
  end

  def write_worker(session_id: 'worker-session-1')
    File.write(@worker_path, JSON.generate(session_id: session_id, agent: 'claude'))
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

    it 'expands the row for a view-N button id (a row\'s Details button)' do
      p = progress
      expect(described_class.handle_token('btn_details_view-2', p)).to eq(2)
      expect(p.expanded_step).to eq(2)
    end

    it 'collapses the row on a second view-N click on the same step (Details/Hide toggle)' do
      p = progress
      described_class.handle_token('btn_details_view-2', p)

      expect(described_class.handle_token('btn_hide_view-2', p)).to eq(2)
      expect(p.expanded_step).to be_nil
    end

    it 'expanding one row\'s Details collapses whichever other was expanded' do
      p = progress
      described_class.handle_token('btn_details_view-2', p)

      described_class.handle_token('btn_details_view-4', p)

      expect(p.expanded_step).to eq(4)
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

      # Mark done closes the row's own expansion regardless of which of the
      # two Mark-done buttons was clicked, the compact row's or the
      # expanded body's -- a stale expansion left open under the
      # confirmation band would read as though nothing happened.
      it 'collapses the expanded row' do
        p = progress
        p.expand_step!(2)

        described_class.handle_token('btn_mark_step_2_done_mark-done-2', p)

        expect(p.expanded_step).to be_nil
      end
    end
  end

  # Warm-up push (Forrest, live UAT round 5: worker's own first paint took
  # ~5 minutes). The real Runner runs here (only its ITerm edges stubbed,
  # same as runner_spec.rb) so the block Listener hands it only fires on
  # whatever Runner itself determines was a confirmed :sent -- a card
  # promising "your agent is preparing" must never be pushed on a send
  # that turned out refused or degraded, and the only place that actually
  # knows which one a click was is Runner, not a duplicate check here.
  describe 'warm-up push on Run' do
    it 'pushes a warm-up card to the step\'s demo session once the send is confirmed' do
      write_worker
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(true)
      allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(true)
      calls = []
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) { |msg| calls << msg }

      described_class.handle_token('btn_run_run-1', progress)

      # create then push, both against step 1's own demo session ("dashboard").
      expect(calls[0]).to include(type: 'create', name: 'dashboard')
      expect(calls[1]).to include(type: 'push', name: 'dashboard')
    end

    it 'creates the session with the same theme the step\'s own demo uses' do
      write_worker
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(true)
      allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(true)
      create_call = nil
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        create_call = msg if msg[:type] == 'create'
      end

      # Step 4's demo (course.rb: `streamweaver panel doc-demo --theme=doc`)
      # is the one step whose demo isn't the bridge's :default theme --
      # `Bridge#create_session` is `||=`, so getting this wrong here would
      # permanently strand the worker's own later --theme=doc as a no-op.
      described_class.handle_token('btn_run_run-4', progress)

      expect(create_call).to include(name: 'doc-demo', theme: :doc)
    end

    it 'includes the step title and the "preparing" line in the warm-up card' do
      write_worker
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(true)
      allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(true)
      push_dsl = nil
      allow(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        push_dsl = msg[:dsl] if msg[:type] == 'push'
      end

      described_class.handle_token('btn_run_run-1', progress)

      step1 = StreamWeaver::University::Course.step(1)
      expect(push_dsl).to include(step1[:title])
      expect(push_dsl).to include('preparing the live demo')
    end

    it 'is not pushed when no worker is recorded (no_worker)' do
      described_class.handle_token('btn_run_run-1', progress)

      expect(StreamWeaver::Canvas::Client).not_to have_received(:send_message)
    end

    it 'is not pushed when the recorded worker session has gone away (session_missing)' do
      write_worker
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(false)

      described_class.handle_token('btn_run_run-1', progress)

      expect(StreamWeaver::Canvas::Client).not_to have_received(:send_message)
    end

    # The gap a prior version of this feature had: session_alive? passing
    # is not the same as the send itself landing.
    it 'is not pushed when the send RPC itself fails (send_failed)' do
      write_worker
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(true)
      allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(false)

      described_class.handle_token('btn_run_run-1', progress)

      expect(StreamWeaver::Canvas::Client).not_to have_received(:send_message)
    end

    it 'is not pushed for a step with no demo session of its own (step 2)' do
      write_worker
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(true)
      allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(true)

      described_class.handle_token('btn_run_run-2', progress)

      expect(StreamWeaver::Canvas::Client).not_to have_received(:send_message)
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

  # Round-8 UAT: every step's closing ritual used to hand a "click Mark
  # done" click back to the user. `university_done!` is what
  # `streamweaver university-done` (cli.rb) calls instead -- same ledger
  # write as a mark-done-N click, plus a repush, with no button event.
  describe '.university_done!' do
    it 'marks the step done in the ledger the same way a mark-done-N click does' do
      allow(described_class).to receive(:repush)

      described_class.university_done!(3)

      expect(progress.done?(3)).to be(true)
    end

    it 'collapses whichever row was expanded' do
      progress.expand_step!(2)
      allow(described_class).to receive(:repush)

      described_class.university_done!(2)

      expect(progress.expanded_step).to be_nil
    end

    it 'repushes the given session_name' do
      allow(described_class).to receive(:repush)

      described_class.university_done!(1, session_name: 'demo-session')

      expect(described_class).to have_received(:repush).with(session_name: 'demo-session')
    end

    it 'returns the step number' do
      allow(described_class).to receive(:repush)

      expect(described_class.university_done!(4)).to eq(4)
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
