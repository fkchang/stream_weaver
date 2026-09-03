# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/university/course'
require 'stream_weaver/university/runner'

RSpec.describe StreamWeaver::University::Course do
  # Prompts are heredocs whose line wrapping is free to change; what
  # actually reaches the worker session is Runner.one_line's collapsed
  # single line. Every content assertion below runs against that, so
  # re-flowing a paragraph can never break a check -- and what the spec
  # pins is what the agent is really told.
  def prompt(number)
    step = described_class::GETTING_STARTED_STEPS.find { |s| s[:number] == number }
    StreamWeaver::University::Runner.one_line(step[:prompt])
  end

  def step(number)
    described_class::GETTING_STARTED_STEPS.find { |s| s[:number] == number }
  end

  describe 'GETTING_STARTED_STEPS' do
    it 'has exactly five steps, numbered 1 through 5 in order' do
      numbers = described_class::GETTING_STARTED_STEPS.map { |s| s[:number] }
      expect(numbers).to eq([1, 2, 3, 4, 5])
    end

    it 'gives every step a title, payoff, why_it_matters, prompt, and what_you_should_see' do
      described_class::GETTING_STARTED_STEPS.each do |step|
        expect(step[:title].to_s.strip).not_to be_empty
        expect(step[:payoff].to_s.strip).not_to be_empty
        expect(step[:why_it_matters].to_s.strip).not_to be_empty
        expect(step[:prompt].to_s.strip).not_to be_empty
        expect(step[:what_you_should_see]).to be_an(Array)
        expect(step[:what_you_should_see]).not_to be_empty
        step[:what_you_should_see].each { |line| expect(line.to_s.strip).not_to be_empty }
      end
    end

    # Course content law (features/university-getting-started.context.md):
    # every step earns its minute with something a TUI cannot do. These are
    # the presence checks for each step's capability delta -- the live
    # behaviour itself is UAT.
    it 'has step 1 push one canvas holding stat tiles, a chart and a mermaid diagram' do
      expect(prompt(1)).to include('streamweaver panel dashboard')
      expect(prompt(1)).to include('streamweaver canvas-push dashboard')
      expect(prompt(1)).to include('stat_display')
      expect(prompt(1)).to include('chart type: :bar')
      expect(prompt(1)).to include('mermaid')
      # Three pushes: the first, then two more that mutate the numbers live.
      expect(prompt(1)).to include('twice more')
    end

    it 'has step 2 run the minimal counter app with `ruby app.rb`, standalone (no canvas push)' do
      expect(prompt(2)).to include('ruby app.rb')
      expect(prompt(2)).to include('increments a')
      expect(prompt(2)).to include('counter held in `state`')
      expect(prompt(2)).not_to include('canvas-push')
    end

    it 'has step 2 name the background task and kill it at the end' do
      expect(prompt(2)).to include('BACKGROUND task')
      expect(prompt(2)).to match(/kill that background task/i)
      expect(step(2)[:what_you_should_see].join(' ')).to match(/background task/i)
    end

    it 'has step 3 explain itself first, then block on a canvas form' do
      expect(prompt(3)).to include('Before you build anything')
      expect(prompt(3)).to include('streamweaver panel decision')
      expect(prompt(3)).to include('canvas-wait decision')
      expect(prompt(3)).to match(/visibly block/i)
      expect(prompt(3)).to include('JSON')
    end

    it 'gives step 3 a diagram, a table, a blocking-form callout, and the non-blocking beat' do
      expect(prompt(3)).to include('mermaid')
      expect(prompt(3)).to include('table')
      expect(prompt(3)).to include('callout')
      expect(prompt(3)).to match(/blocking form/i)
      expect(prompt(3)).to match(/no `canvas-wait` behind it/)
    end

    it 'keeps the step 3 form to radio_group/select/text_field only (disc-098, disc-105)' do
      expect(prompt(3)).to include('`radio_group`')
      expect(prompt(3)).to include('`text_field`')
      expect(prompt(3)).not_to match(/checkbox_group|chip_group/)
    end

    it 'has step 4 invoke the growing-doc script by a gem-relative require, not a home path' do
      expect(prompt(4)).to include("require 'stream_weaver/university/scripts/growing_doc'")
      expect(prompt(4)).not_to match(%r{/Users/|~/})
    end

    it 'has step 4 name the doc features and end on the Save-as-doc dialog' do
      expect(prompt(4)).to include('Save as doc')
      expect(prompt(4)).to include('docs/streamweaver_canvas/<name>.rb')
      expect(prompt(4)).to include('Save as Org')
      %w[two-column code callout mermaid].each do |feature|
        expect(prompt(4)).to include(feature)
      end
    end

    # disc-094: `streamweaver export` drops Chart.js for the chart
    # shorthands, so anything that will be saved, org-exported and reopened
    # (step 4's doc, which step 5 carries out to a gist) must never name
    # one. Step 1's dashboard is live-canvas-only, and is told to use the
    # explicit `chart type:` form regardless -- asserted above.
    it 'keeps step 4 and 5 doc content free of chart shorthands (disc-094)' do
      %w[bar_chart hbar_chart line_chart area_chart pie_chart doughnut_chart
         stacked_bar_chart sparkline].each do |shorthand|
        [4, 5].each { |n| expect(prompt(n)).not_to include(shorthand) }
      end
    end

    it 'has step 5 check gh before exporting the step 4 doc and pushing it to a gist' do
      expect(prompt(5)).to include('gh auth status')
      expect(prompt(5)).to include('org-export')
      expect(prompt(5)).to include('gh gist create')
      expect(prompt(5)).to include('StreamWeaver Doc Viewer')
    end

    it 'has step 5 close every demo session and leave only the controller' do
      expect(prompt(5)).to include('streamweaver canvas-list')
      expect(prompt(5)).to include('Leave only `university`')
      %w[dashboard decision doc-demo].each do |session|
        expect(prompt(5)).to include(session)
      end
    end

    # Rule 2 of the course content law: no step inherits the previous
    # step's clutter, and the controller canvas is never a casualty of the
    # cleanup.
    it 'opens every step after the first by closing the previous step\'s demo' do
      (2..5).each do |n|
        expect(prompt(n)).to match(/canvas-close|kill the background/i),
                             "step #{n} does not clean up the previous step"
      end
    end

    it 'tells step 1 to clear leftovers from a prior run without closing the controller' do
      expect(prompt(1)).to include('streamweaver canvas-list')
      expect(prompt(1)).to include('streamweaver canvas-close')
      expect(prompt(1)).to include('Never close `university`')
    end

    it 'never tells the agent to close the university controller session' do
      (1..5).each { |n| expect(prompt(n)).not_to include('canvas-close university') }
    end

    it 'has every step announce what is about to happen before it happens' do
      (1..5).each do |n|
        expect(prompt(n)).to match(/tell me|say (?:this|out loud)|explain/i),
                             "step #{n} never narrates before acting"
      end
    end
  end

  describe 'FUTURE_COURSES' do
    it 'lists exactly the three dormant courses named in the design spec' do
      names = described_class::FUTURE_COURSES.map { |c| c[:name] }
      expect(names).to eq(['Docs deep dive', 'Canvas modes', 'Skills and panels'])
    end

    it 'gives every future course a one-line blurb' do
      described_class::FUTURE_COURSES.each do |course|
        expect(course[:blurb].to_s.strip).not_to be_empty
      end
    end
  end
end
