# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/cli'
require 'stream_weaver/university/canvas'
require 'stream_weaver/university/course'
require 'stream_weaver/university/progress'

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

  def with_env(vars)
    old = {}
    vars.each_key { |k| old[k] = ENV[k] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end
end
