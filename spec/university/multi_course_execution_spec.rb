# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tmpdir'
require 'stream_weaver/iterm'
require 'stream_weaver/university/course_catalog'
require 'stream_weaver/university/demos'
require 'stream_weaver/university/listener'
require 'stream_weaver/university/progress'
require_relative '../support/env_helper'

RSpec.describe 'University multi-course execution' do
  include EnvHelper

  let(:provider_class) { Struct.new(:courses) }

  around do |example|
    Dir.mktmpdir('university-multi-course-spec') do |dir|
      @progress_path = File.join(dir, 'progress.yml')
      @worker_path = File.join(dir, 'worker.json')
      @provider_demo = File.join(dir, 'diagram.rb')
      File.write(@provider_demo, "# packaged provider demo\n")
      File.write(@worker_path, JSON.generate(session_id: 'worker-1', agent: 'codex'))

      StreamWeaver::Extensions.reset!
      StreamWeaver.register_extension(
        :fixture_provider,
        course_provider: provider_class.new([
          {
            id: 'fixture-diagram-intent',
            title: 'Diagram Intent',
            blurb: 'Choose a diagram by intent.',
            steps: [
              { number: 1, title: 'Choose the shape', payoff: 'A fitting diagram',
                prompt: 'Run the selected Diagram Intent course prompt.' }
            ],
            demo_resolver: ->(name) { name == 'diagram' ? @provider_demo : nil }
          }
        ])
      )

      with_env(
        'STREAMWEAVER_UNIVERSITY_PROGRESS' => @progress_path,
        'STREAMWEAVER_UNIVERSITY_WORKER' => @worker_path
      ) { example.run }
    ensure
      StreamWeaver::Extensions.reset!
    end
  end

  before do
    allow(StreamWeaver::ITerm).to receive(:session_alive?).with('worker-1').and_return(true)
    allow(StreamWeaver::ITerm).to receive(:send_to_session).and_return(true)
    allow(StreamWeaver::Canvas::Client).to receive(:send_message)
  end

  it 'runs a provider step from its course-qualified listener token without changing Getting Started' do
    getting_started = StreamWeaver::University::Progress.load
    getting_started.mark_done!(2)

    token = 'btn_run_course_fixture_diagram_intent_run-course-fixture-diagram-intent-1'
    StreamWeaver::University::Listener.handle_event({ data: { button: token } })

    expect(StreamWeaver::ITerm).to have_received(:send_to_session).with(
      'worker-1',
      'Run the selected Diagram Intent course prompt.'
    )
    expect(StreamWeaver::University::Progress.load(course_id: 'fixture-diagram-intent').requested_at(1)).to be_a(String)
    expect(StreamWeaver::University::Progress.load.done_steps).to eq([2])
  end

  it 'marks and resets only the course identified by the control token' do
    StreamWeaver::University::Progress.load.mark_done!(2)
    StreamWeaver::University::Listener.handle_event(
      { data: { button: 'btn_mark_done_course_fixture_diagram_intent_mark-done-course-fixture-diagram-intent-1' } }
    )

    expect(StreamWeaver::University::Progress.load(course_id: 'fixture-diagram-intent').done_steps).to eq([1])

    StreamWeaver::University::Listener.handle_event(
      { data: { button: 'btn_reset_course_fixture_diagram_intent_reset-course-fixture-diagram-intent' } }
    )

    expect(StreamWeaver::University::Progress.load(course_id: 'fixture-diagram-intent').done_steps).to eq([])
    expect(StreamWeaver::University::Progress.load.done_steps).to eq([2])
  end

  it 'resolves the selected course demo while omitted selection stays on Getting Started' do
    expect(StreamWeaver::University::Demos.path('diagram', course_id: 'fixture-diagram-intent')).to eq(@provider_demo)
    expect(StreamWeaver::University::Demos.path('dashboard')).to eq(
      StreamWeaver::University::Demos::PATHS.fetch('dashboard')
    )
  end
end
