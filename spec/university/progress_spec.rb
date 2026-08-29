# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/university/progress'
require_relative '../support/env_helper'

# Covers read/write/resume, the zero-state, and the "survives a bridge
# restart" criterion (progress-ledger #1, #3, #5): a bridge restart only
# ever loses in-memory session state, never this file, so a fresh
# Progress instance pointed at the same path must see prior writes.
RSpec.describe StreamWeaver::University::Progress do
  include EnvHelper

  around do |example|
    Dir.mktmpdir('university-progress-spec') do |dir|
      @path = File.join(dir, 'progress.yml')
      example.run
    end
  end

  def new_progress
    described_class.new(@path)
  end

  describe '.path' do
    it 'honors STREAMWEAVER_UNIVERSITY_PROGRESS so specs never touch the real ledger' do
      with_env('STREAMWEAVER_UNIVERSITY_PROGRESS' => '/tmp/somewhere/progress.yml') do
        expect(described_class.path).to eq('/tmp/somewhere/progress.yml')
      end
    end

    it 'falls back to ~/.streamweaver/university/progress.yml when unset' do
      with_env('STREAMWEAVER_UNIVERSITY_PROGRESS' => nil) do
        expect(described_class.path).to eq(File.expand_path('~/.streamweaver/university/progress.yml'))
      end
    end
  end

  describe 'zero-state (no file on disk yet)' do
    it 'reports every step undone' do
      progress = new_progress
      expect(progress.done?(1)).to be(false)
      expect(progress.done_steps).to eq([])
      expect(progress.done_count).to eq(0)
    end

    it 'does not create the file just by reading it' do
      new_progress
      expect(File.exist?(@path)).to be(false)
    end
  end

  describe '#mark_done!' do
    it 'persists to disk immediately' do
      new_progress.mark_done!(2)
      expect(File.exist?(@path)).to be(true)
    end

    it 'is visible to a brand new instance pointed at the same path (bridge-restart survival)' do
      new_progress.mark_done!(3)

      reloaded = new_progress
      expect(reloaded.done?(3)).to be(true)
      expect(reloaded.done_steps).to eq([3])
    end

    it 'accumulates multiple done steps across separate instances' do
      new_progress.mark_done!(1)
      new_progress.mark_done!(2)

      expect(new_progress.done_steps).to eq([1, 2])
      expect(new_progress.done_count).to eq(2)
    end
  end

  describe '#unmark_done!' do
    it 'removes a step from the done set and persists the removal' do
      progress = new_progress
      progress.mark_done!(1)
      progress.unmark_done!(1)

      expect(new_progress.done?(1)).to be(false)
    end
  end

  describe '#record_run! (driver-worker-runner outcome)' do
    it 'records a timestamp for a step whose prompt was actually sent' do
      new_progress.record_run!(4, status: :sent)

      reloaded = new_progress
      expect(reloaded.requested_at(4)).to be_a(String)
      expect(reloaded.requested_at(4)).not_to be_empty
    end

    it 'is nil for a step that was never requested' do
      expect(new_progress.requested_at(5)).to be_nil
    end

    # A click that found no worker, or a closed tab, is not a send -- a
    # requested_at for it would be a lie the ledger tells forever.
    it 'records no timestamp when the prompt never went out' do
      new_progress.record_run!(4, status: :session_missing)

      expect(new_progress.requested_at(4)).to be_nil
    end

    it 'records the outcome as last_run for every status, persisted across instances' do
      new_progress.record_run!(2, status: :no_worker)

      expect(new_progress.last_run).to include('step' => 2, 'status' => 'no_worker')
      expect(new_progress.last_run['at']).to be_a(String)
    end

    it 'is nil before any Run click' do
      expect(new_progress.last_run).to be_nil
    end

    # The notice reports the last click; marking a step done IS a later
    # click, so it must not leave a stale run notice pinned to the canvas.
    it 'is cleared by a subsequent mark_done!' do
      new_progress.record_run!(1, status: :no_worker)
      new_progress.mark_done!(1)

      expect(new_progress.last_run).to be_nil
    end
  end

  describe '#view_step! / #clear_view! (step screen navigation)' do
    it 'is nil before any step screen has been opened' do
      expect(new_progress.viewing_step).to be_nil
    end

    it 'persists which step is showing, across instances' do
      new_progress.view_step!(3)

      expect(new_progress.viewing_step).to eq(3)
    end

    it 'returns to the course list on clear_view!' do
      progress = new_progress
      progress.view_step!(3)
      progress.clear_view!

      expect(new_progress.viewing_step).to be_nil
    end
  end

  describe 'a corrupt or partial file on disk' do
    it 'treats invalid YAML as the zero-state rather than raising' do
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, "not: valid: yaml: [")

      expect { new_progress.done?(1) }.not_to raise_error
      expect(new_progress.done?(1)).to be(false)
    end
  end

end
