# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/cli'
require 'stream_weaver/university/canvas'
require_relative '../support/env_helper'

# The recap's Artifacts section, rendered through the same
# instance_eval-a-mini-app path the bridge itself uses. What matters here is
# that a delete button only ever ASKS (the confirm button appears only once
# something is pending) and that a gist gets its own button showing its URL.
RSpec.describe 'University canvas artifacts section' do
  include EnvHelper

  let(:artifacts) { StreamWeaver::University::Artifacts }

  around do |example|
    Dir.mktmpdir('university-canvas-artifacts-spec') do |dir|
      @dir = dir
      with_env(
        'STREAMWEAVER_UNIVERSITY_PROGRESS' => File.join(dir, 'progress.yml'),
        'STREAMWEAVER_UNIVERSITY_ARTIFACTS' => File.join(dir, 'artifacts.yml')
      ) do
        example.run
      end
    end
  end

  def render
    source = File.read(File.expand_path('../../lib/stream_weaver/university/canvas.rb', __dir__))
    StreamWeaver::CLI.render_dsl_to_html(source, session_name: 'university-spec')
  end

  def finish_course
    progress = StreamWeaver::University::Progress.load
    StreamWeaver::University::Course::GETTING_STARTED_STEPS.each { |s| progress.mark_done!(s[:number]) }
  end

  def record_everything
    artifacts.record!(File.join(@dir, 'university-doc.rb'), step: 4)
    artifacts.record!(File.join(@dir, 'university-doc.org'), step: 5)
    artifacts.record!('https://gist.github.com/me/abc123def', step: 5)
    artifacts.record_session!('doc-demo', step: 4)
  end

  it 'says nothing about artifacts before the course is finished' do
    record_everything
    expect(render).not_to include('cleanup-ask-docs')
  end

  it 'lists what the course created, grouped, once every step is done' do
    finish_course
    record_everything
    html = render

    expect(html).to include('Artifacts')
    expect(html).to include('This course created 4 things')
    expect(html).to include('Saved docs', 'Exported .org files', 'Gists', 'Course canvas sessions')
    expect(html).to include('university-doc.rb', 'https://gist.github.com/me/abc123def', 'doc-demo')
  end

  it 'renders nothing at all when the course created nothing' do
    finish_course
    expect(render).not_to include('This course created')
  end

  it 'gives each group one delete button, and each gist its own showing the URL' do
    finish_course
    record_everything
    html = render

    expect(html).to include('cleanup-ask-docs', 'cleanup-ask-orgs', 'cleanup-ask-sessions')
    expect(html).to include('cleanup-ask-gist-0')
    expect(html).to include('Delete https://gist.github.com/me/abc123def')
  end

  it 'offers no confirm button until something is actually pending' do
    finish_course
    record_everything

    expect(render).not_to include('cleanup-confirm')
  end

  it 'replaces the delete buttons with a confirmation naming what would go' do
    finish_course
    record_everything
    artifacts.request_delete!(label: 'the saved docs', kind: 'doc',
                              refs: [File.join(@dir, 'university-doc.rb')])
    html = render

    expect(html).to include('Really delete the saved docs?')
    expect(html).to include('cleanup-confirm', 'cleanup-keep')
    expect(html).not_to include('cleanup-ask-docs')
  end

  it 'reports what the last confirmed delete did' do
    finish_course
    record_everything
    artifacts.record_cleanup!(['deleted /tmp/university-doc.rb'])

    expect(render).to include('deleted /tmp/university-doc.rb')
  end

  describe 'per-step "created:" line' do
    it 'lists what that step created on its expanded row' do
      artifacts.record!(File.join(@dir, 'university-doc.rb'), step: 4)
      artifacts.record_session!('doc-demo', step: 4)
      StreamWeaver::University::Progress.load.expand_step!(4)

      expect(render).to include("created: #{File.join(@dir, 'university-doc.rb')}, doc-demo")
    end

    it 'says nothing for a step that created nothing' do
      artifacts.record!(File.join(@dir, 'university-doc.rb'), step: 4)
      StreamWeaver::University::Progress.load.expand_step!(2)

      expect(render).not_to include('created:')
    end

    it 'offers no delete control on a step row -- the recap owns deleting' do
      artifacts.record!(File.join(@dir, 'university-doc.rb'), step: 4)
      StreamWeaver::University::Progress.load.expand_step!(4)

      expect(render).not_to include('cleanup-ask')
    end
  end
end
