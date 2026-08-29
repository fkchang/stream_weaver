# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/university/course'

RSpec.describe StreamWeaver::University::Course do
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

    it 'has step 1 open a canvas session before pushing the card into it' do
      step1 = described_class::GETTING_STARTED_STEPS.find { |s| s[:number] == 1 }
      expect(step1[:prompt]).to include('streamweaver panel hello')
      expect(step1[:prompt]).to include('streamweaver canvas-push hello')
    end

    it 'has step 2 run the minimal counter app with `ruby app.rb`, standalone (no canvas)' do
      step2 = described_class::GETTING_STARTED_STEPS.find { |s| s[:number] == 2 }
      expect(step2[:prompt]).to include('ruby app.rb')
      expect(step2[:prompt]).to include('increments a')
      expect(step2[:prompt]).to include('counter held in `state`')
      expect(step2[:prompt]).not_to include('canvas-push')
    end

    it 'keeps the step 3 prompt to radio_group/select/text_field only (disc-098, disc-105)' do
      step3 = described_class::GETTING_STARTED_STEPS.find { |s| s[:number] == 3 }
      expect(step3[:prompt]).to include('radio_group and a button')
      expect(step3[:prompt]).to include('canvas-wait')
      expect(step3[:prompt]).not_to match(/checkbox_group|chip_group/)
    end

    it 'has step 4 invoke the growing-doc script by a gem-relative require, not a home path' do
      step4 = described_class::GETTING_STARTED_STEPS.find { |s| s[:number] == 4 }
      expect(step4[:prompt]).to include("require 'stream_weaver/university/scripts/growing_doc'")
      expect(step4[:prompt]).not_to match(%r{/Users/|~/})
    end

    it 'keeps step 4 and 5 doc content free of chart shorthands (disc-094)' do
      %w[bar_chart line_chart pie_chart].each do |shorthand|
        described_class::GETTING_STARTED_STEPS.each do |step|
          expect(step[:prompt]).not_to include(shorthand)
        end
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
