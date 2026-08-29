# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/cli'
require 'stream_weaver/university/canvas'
require 'stream_weaver/university/course'
require 'stream_weaver/university/progress'
require_relative '../support/env_helper'

# Covers course-list-canvas (criteria 2-4: Getting Started's five steps +
# progress, dormant future courses with blurbs, the tutorial pointer) and
# progress-ledger (criteria 3-4: done/current marking, Run/Repeat on every
# step) by rendering the real pushed source through the same
# instance_eval-a-mini-app path the bridge itself uses
# (StreamWeaver::CLI.render_dsl_to_html) -- no live bridge required. This
# renderer (rather than Canvas::Reader's inert/websocket one) is used
# because it's the one that keeps button `id:` attributes in the markup,
# which these specs assert on directly.
RSpec.describe StreamWeaver::University::Canvas do
  include EnvHelper

  around do |example|
    Dir.mktmpdir('university-canvas-spec') do |dir|
      @progress_path = File.join(dir, 'progress.yml')
      with_env('STREAMWEAVER_UNIVERSITY_PROGRESS' => @progress_path) { example.run }
    end
  end

  def source
    File.read(File.expand_path('../../lib/stream_weaver/university/canvas.rb', __dir__))
  end

  def render
    StreamWeaver::CLI.render_dsl_to_html(source, session_name: 'university-spec')
  end

  def mark_done(*numbers)
    progress = StreamWeaver::University::Progress.new(@progress_path)
    numbers.each { |n| progress.mark_done!(n) }
  end

  describe '.step_states' do
    let(:steps) { StreamWeaver::University::Course::GETTING_STARTED_STEPS }

    it 'marks every step :todo, except step 1 :current, in the zero-state' do
      progress = StreamWeaver::University::Progress.new(@progress_path)
      states = described_class.step_states(progress, steps: steps)

      expect(states[1]).to eq(:current)
      expect(states.values_at(2, 3, 4, 5)).to all(eq(:todo))
    end

    it 'marks completed steps :done and the first unfinished step :current' do
      mark_done(1, 2)
      progress = StreamWeaver::University::Progress.new(@progress_path)
      states = described_class.step_states(progress, steps: steps)

      expect(states[1]).to eq(:done)
      expect(states[2]).to eq(:done)
      expect(states[3]).to eq(:current)
      expect(states[4]).to eq(:todo)
      expect(states[5]).to eq(:todo)
    end

    it 'marks every step :done when all are complete, with no :current' do
      mark_done(1, 2, 3, 4, 5)
      progress = StreamWeaver::University::Progress.new(@progress_path)
      states = described_class.step_states(progress, steps: steps)

      expect(states.values).to all(eq(:done))
    end
  end

  describe 'rendered course list (zero-state)' do
    it 'renders the app name and Getting Started as an enabled, open course' do
      html = render
      expect(html).to include('StreamWeaver University')
      expect(html).to include('Getting Started')
      expect(html).to include('uni-course--dormant').and include('sw-card')
    end

    it 'renders all five step titles' do
      html = render
      StreamWeaver::University::Course::GETTING_STARTED_STEPS.each do |step|
        expect(html).to include(step[:title])
      end
    end

    it 'reads "Start with step 1" and shows 0 of 5 done' do
      html = render
      expect(html).to include('Start with step 1')
      expect(html).to include('0 of 5 done')
    end

    it 'offers Run on every step row (no Repeat yet -- nothing is done)' do
      html = render
      expect(html.scan('id="btn_run_run-').size).to eq(5)
      expect(html).not_to include('btn_repeat_repeat-')
    end

    it 'lists the three future courses as dormant, with their blurbs, and no controls' do
      html = render
      StreamWeaver::University::Course::FUTURE_COURSES.each do |course|
        expect(html).to include(course[:name])
        expect(html).to include(course[:blurb])
      end
      expect(html).to include('uni-chip--soon')
    end

    it 'links the classic tutorial as the escape hatch' do
      html = render
      expect(html).to include('streamweaver tutorial')
    end
  end

  describe 'rendered course list (in progress: steps 1-2 done)' do
    before { mark_done(1, 2) }

    it 'marks steps 1 and 2 done and highlights step 3 as current' do
      html = render
      expect(html).to include('uni-step uni-step--done')
      expect(html).to include('uni-step uni-step--current')
      expect(html).to include('Pick up at step 3')
      expect(html).to include('2 of 5 done')
    end

    it 'offers Run/Repeat: Repeat on done steps, Run on the current and remaining steps' do
      html = render
      expect(html.scan('id="btn_repeat_repeat-').size).to eq(2)
      expect(html.scan('id="btn_run_run-').size).to eq(3) # current (3) + todo (4, 5)
    end

    it 'offers Mark done on the current step' do
      html = render
      expect(html).to include('id="btn_mark_done_mark-done-3"')
    end
  end

  describe 'rendered course list (all done)' do
    before { mark_done(1, 2, 3, 4, 5) }

    it 'shows the Complete chip, no primary Run, and Repeat on every row' do
      html = render
      expect(html).to include('Complete')
      expect(html.scan('id="btn_repeat_repeat-').size).to eq(5)
      expect(html).not_to include('id="btn_run_step')
    end
  end

  # --- driver-worker-runner: the on-canvas report of the last Run click ----
  # Criterion 4 (a wrong/closed target is reported on the canvas, never sent
  # elsewhere) and criterion 5 (degraded mode shows the prompt with a copy
  # button and paste instructions) are both rendered from `last_run` in the
  # ledger -- the canvas never talks to iTerm itself.

  def record_run(step, status)
    StreamWeaver::University::Progress.new(@progress_path).record_run!(step, status: status)
  end

  def step_prompt(number)
    StreamWeaver::University::Course.prompt_for(number)
  end

  # UAT 2026-08-29: every button blanked the canvas to "✓ Submitted -- You
  # can close this window". The buttons were already dispatching non-terminal
  # `action` events; the blanking is adapter/alpinejs.rb's showFeedback(),
  # which falls back to that terminal screen when the pushed DSL carries no
  # #sw-canvas-continue marker. A long-lived control panel must carry one, so
  # a click shows a brief spinner that the listener's re-push then replaces.
  describe 'click feedback' do
    it 'emits the canvas continue marker so a click never renders the terminal Submitted screen' do
      html = render

      expect(html).to include('id="sw-canvas-continue"')
      expect(html).to include('data-continue-message')
    end
  end

  describe 'rendered run notice' do
    it 'shows nothing when no Run has been clicked yet' do
      expect(render).not_to include('uni-run-notice')
    end

    it 'reports a closed/missing worker session and never claims it was sent' do
      record_run(1, :session_missing)
      html = render

      expect(html).to include('uni-run-notice')
      expect(html).to include('streamweaver get-started')
      expect(html).not_to include('Sent step 1')
    end

    it 'offers the prompt with a copy affordance when the worker session is missing' do
      record_run(1, :session_missing)
      html = render

      expect(html).to include('sw-copy-button')
      expect(html).to include(step_prompt(1).lines.first.strip)
    end

    it 'shows the prompt, a copy button, and paste instructions in degraded mode' do
      record_run(2, :no_worker)
      html = render

      expect(html).to include('uni-run-notice')
      expect(html).to include('sw-copy-button')
      expect(html).to include('paste')
      expect(html).to include(step_prompt(2).lines.first.strip)
    end

    it 'confirms a successful send without repeating the prompt' do
      record_run(3, :sent)
      html = render

      expect(html).to include('uni-run-notice')
      expect(html).to include('Sent step 3')
      expect(html).not_to include('sw-copy-button')
    end
  end

  # --- step-1-canvas-push: the step screen, a second view of this same app,
  # reached from a row's Details button and left via "All steps" or "Next".

  def view_step(number)
    StreamWeaver::University::Progress.new(@progress_path).view_step!(number)
  end

  describe 'course list rows' do
    it 'offers a Details button on every step row, reachable into the step screen' do
      html = render
      expect(html.scan('id="btn_details_view-').size).to eq(5)
    end
  end

  describe 'rendered step screen' do
    it 'is not shown until a step is being viewed' do
      html = render
      expect(html).not_to include('uni-promptbox')
    end

    it 'renders the step title, why-it-matters, prompt, and what-you-should-see' do
      view_step(3)
      html = render
      step3 = StreamWeaver::University::Course.step(3)

      expect(html).to include(step3[:title])
      expect(html).to include('Why this matters')
      expect(html).to include('The prompt your worker session receives')
      expect(html).to include(step3[:prompt])
      expect(html).to include('What you should see')
      step3[:what_you_should_see].each { |line| expect(html).to include(line) }
    end

    it 'offers Run in worker session (routed through the same run-N id Runner handles) and Copy prompt' do
      view_step(3)
      html = render

      expect(html).to include('id="btn_run_in_worker_session_run-3"')
      expect(html).to include('sw-copy-button')
    end

    it 'offers Mark step N done and a back to the list' do
      view_step(3)
      html = render

      expect(html).to include('id="btn_mark_step_3_done_mark-done-3"')
      expect(html).to include('id="btn_all_steps_back-to-list"')
    end

    it 'offers a Next: step N+1 link for steps before the last' do
      view_step(3)
      html = render

      expect(html).to include('id="btn_next_step_4_next-4"')
    end

    it 'has no Next link on the last step' do
      view_step(5)
      html = render

      expect(html).not_to include('btn_next_step')
      expect(html).to include('That is the whole course.')
    end
  end
end
