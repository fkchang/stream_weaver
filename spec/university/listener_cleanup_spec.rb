# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/university/listener'
require_relative '../support/env_helper'

# The canvas half of the artifact lifecycle: a delete button ASKS, a second
# click confirms, and only that second click reaches Cleanup. Nothing here
# may delete on one click, and nothing here may reach past Cleanup's own
# allowlist.
RSpec.describe StreamWeaver::University::Listener do
  include EnvHelper

  let(:artifacts) { StreamWeaver::University::Artifacts }

  around do |example|
    Dir.mktmpdir('university-listener-cleanup-spec') do |dir|
      @dir = dir
      with_env(
        'STREAMWEAVER_UNIVERSITY_ARTIFACTS' => File.join(dir, 'artifacts.yml'),
        'STREAMWEAVER_UNIVERSITY_PROGRESS' => File.join(dir, 'progress.yml')
      ) do
        example.run
      end
    end
  end

  before { allow(StreamWeaver::Canvas::Client).to receive(:send_message) }

  def progress
    StreamWeaver::University::Progress.load
  end

  def recorded_doc(name = 'a.rb')
    path = File.join(@dir, name)
    File.write(path, '# doc')
    artifacts.record!(path, step: 4)
    path
  end

  describe 'asking (cleanup-ask-*)' do
    it 'writes a pending confirmation naming every ref in the group, and deletes nothing' do
      path = recorded_doc

      described_class.handle_token('btn_delete_saved_docs_cleanup-ask-docs', progress)

      expect(artifacts.pending_delete).to include(
        'kind' => 'doc', 'label' => 'the saved docs', 'refs' => [path]
      )
      expect(File.exist?(path)).to be(true)
      expect(artifacts.all.size).to eq(1)
    end

    it 'asks about ONE gist at a time, by its own URL' do
      artifacts.record!('https://gist.github.com/me/aaa111', step: 5)
      artifacts.record!('https://gist.github.com/me/bbb222', step: 5)

      described_class.handle_token('btn_delete_cleanup-ask-gist-1', progress)

      expect(artifacts.pending_delete).to include(
        'kind' => 'gist', 'refs' => ['https://gist.github.com/me/bbb222']
      )
    end

    it 'resolves refs at ask time, so the confirmation deletes exactly what it showed' do
      first = recorded_doc('first.rb')
      described_class.handle_token('btn_cleanup-ask-docs', progress)
      second = recorded_doc('second.rb')

      described_class.handle_token('btn_cleanup-confirm', progress)

      expect(File.exist?(first)).to be(false)
      expect(File.exist?(second)).to be(true)
    end

    it 'asks about nothing when the group is empty' do
      expect(described_class.cleanup_ask!('docs')).to be_nil
      expect(artifacts.pending_delete).to be_nil
    end

    it 'asks about nothing for a gist index that is not there' do
      expect(described_class.cleanup_ask!('gist-7')).to be_nil
      expect(artifacts.pending_delete).to be_nil
    end
  end

  describe 'confirming (cleanup-confirm)' do
    it 'deletes the pending refs and reports what happened' do
      path = recorded_doc

      described_class.handle_token('btn_cleanup-ask-docs', progress)
      described_class.handle_token('btn_cleanup-confirm', progress)

      expect(File.exist?(path)).to be(false)
      expect(artifacts.all).to eq([])
      expect(artifacts.pending_delete).to be_nil
      expect(artifacts.last_cleanup.join).to include('deleted')
    end

    it 'does nothing at all with no pending confirmation' do
      path = recorded_doc

      expect(described_class.handle_token('btn_cleanup-confirm', progress)).to be(true)
      expect(File.exist?(path)).to be(true)
    end

    it 'reports a refusal instead of raising inside a listener nobody is watching' do
      # A pending confirmation naming something the manifest does not
      # record -- the shape a stale button or an edited file would produce.
      outsider = File.join(@dir, 'precious.rb')
      File.write(outsider, 'keep me')
      artifacts.request_delete!(label: 'the saved docs', kind: 'doc', refs: [outsider])

      expect { described_class.cleanup_confirm! }.not_to raise_error
      expect(File.exist?(outsider)).to be(true)
      expect(artifacts.last_cleanup.join).to include('refusing to delete')
    end
  end

  describe 'keeping (cleanup-keep)' do
    it 'clears the question and leaves everything alone' do
      path = recorded_doc
      described_class.handle_token('btn_cleanup-ask-docs', progress)

      described_class.handle_token('btn_keep_cleanup-keep', progress)

      expect(artifacts.pending_delete).to be_nil
      expect(File.exist?(path)).to be(true)
      expect(artifacts.all.size).to eq(1)
    end
  end

  describe '.warm_up!' do
    it 'records the demo session it creates in the artifact manifest' do
      described_class.warm_up!(1)

      expect(artifacts.grouped['session'].map { |e| e['ref'] }).to eq(['dashboard'])
      expect(artifacts.grouped['session'].first['step']).to eq(1)
    end

    it 'records nothing for a step with no demo session of its own' do
      described_class.warm_up!(5)
      expect(artifacts.all).to eq([])
    end
  end

  describe '.close_demo_sessions!' do
    it 'clears growing_doc state by default (reset means start over)' do
      allow(StreamWeaver::University::Scripts::GrowingDocState).to receive(:clear)
      described_class.close_demo_sessions!
      expect(StreamWeaver::University::Scripts::GrowingDocState).to have_received(:clear).at_least(:once)
    end

    it 'keeps growing_doc state with clear_state: false (stop means put it down)' do
      allow(StreamWeaver::University::Scripts::GrowingDocState).to receive(:clear)
      described_class.close_demo_sessions!(clear_state: false)
      expect(StreamWeaver::University::Scripts::GrowingDocState).not_to have_received(:clear)
    end
  end
end
