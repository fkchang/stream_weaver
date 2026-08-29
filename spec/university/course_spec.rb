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
