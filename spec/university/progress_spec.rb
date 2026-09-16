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

  def new_progress(course_id: nil)
    described_class.new(@path, course_id: course_id)
  end

  def a_temporary_ledger_path
    satisfy do |temporary|
      File.dirname(temporary) == File.dirname(@path) && temporary.start_with?("#{@path}.tmp.")
    end
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

    # progress-ledger's Mark-done feedback deliverable: `last_done` is what
    # the canvas renders as "Step N done -- ..." on the SAME re-push that
    # wrote it -- see the class comment for why that replaced a bridge
    # toast (a toast queued alongside this same write's re-push loses a
    # race against the client unconditionally clearing it on new HTML).
    it 'stamps last_done, persisted across instances' do
      new_progress.mark_done!(3)

      reloaded = new_progress
      expect(reloaded.last_done).to include('step' => 3)
      expect(reloaded.last_done['at']).to be_a(String)
    end

    it 'is nil before any Mark-done click' do
      expect(new_progress.last_done).to be_nil
    end

    it 'is cleared by a subsequent record_run! (a later click supersedes it)' do
      new_progress.mark_done!(1)
      progress = new_progress
      progress.record_run!(2, status: :no_worker)

      expect(progress.last_done).to be_nil
    end
  end

  describe '#unmark_done!' do
    it 'removes a step from the done set and persists the removal' do
      progress = new_progress
      progress.mark_done!(1)
      progress.unmark_done!(1)

      expect(new_progress.done?(1)).to be(false)
    end

    it 'clears last_done along with the done flag' do
      progress = new_progress
      progress.mark_done!(1)
      progress.unmark_done!(1)

      expect(new_progress.last_done).to be_nil
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

  describe '#expand_step! / #collapse! (inline Details expansion)' do
    it 'is nil before any row has been expanded' do
      expect(new_progress.expanded_step).to be_nil
    end

    it 'persists which step is expanded, across instances' do
      new_progress.expand_step!(3)

      expect(new_progress.expanded_step).to eq(3)
    end

    it 'collapses on collapse!' do
      progress = new_progress
      progress.expand_step!(3)
      progress.collapse!

      expect(new_progress.expanded_step).to be_nil
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

  describe '#reset! ("Reset course")' do
    it 'backs the ledger up to <path>.bak before clearing it' do
      progress = new_progress
      progress.mark_done!(1)
      progress.mark_done!(2)
      original = File.read(@path)

      progress.reset!

      expect(File.read("#{@path}.bak")).to eq(original)
    end

    it 'returns every step to undone, on this instance and a freshly loaded one' do
      progress = new_progress
      progress.record_run!(2, status: :sent)
      progress.expand_step!(3)
      progress.mark_done!(1)

      progress.reset!

      expect(progress.done_steps).to eq([])
      expect(progress.last_run).to be_nil
      expect(progress.last_done).to be_nil
      expect(progress.expanded_step).to be_nil
      reloaded = new_progress
      expect(reloaded.done_steps).to eq([])
      expect(reloaded.last_run).to be_nil
      expect(reloaded.last_done).to be_nil
      expect(reloaded.expanded_step).to be_nil
    end

    it 'removes the ledger file rather than leaving an empty one behind' do
      progress = new_progress
      progress.mark_done!(1)

      progress.reset!

      expect(File.exist?(@path)).to be(false)
    end

    it 'does not blow up, and writes no backup, when there was nothing on disk yet' do
      progress = new_progress

      expect { progress.reset! }.not_to raise_error
      expect(File.exist?("#{@path}.bak")).to be(false)
      expect(progress.done_steps).to eq([])
    end

    it 'overwrites a previous backup rather than accumulating history' do
      progress = new_progress
      progress.mark_done!(1)
      progress.reset!
      first_backup = File.read("#{@path}.bak")

      progress = new_progress
      progress.mark_done!(2)
      progress.reset!

      expect(File.read("#{@path}.bak")).not_to eq(first_backup)
    end

    it 'atomically replaces a namespaced ledger while preserving another course' do
      new_progress(course_id: 'course-one').mark_done!(1)
      new_progress(course_id: 'course-two').mark_done!(2)

      expect(File).to receive(:rename).with(
        a_temporary_ledger_path,
        @path
      ).and_call_original

      new_progress(course_id: 'course-one').reset!
      expect(new_progress(course_id: 'course-two').done_steps).to eq([2])
    end
  end

  describe 'course-namespaced progress' do
    it 'persists each selected course under its course ID without changing another course' do
      first = new_progress(course_id: 'course-one')
      second = new_progress(course_id: 'course-two')

      first.mark_done!(1)
      first.record_run!(2, status: :sent)
      first.expand_step!(3)

      expect(new_progress(course_id: 'course-one').done_steps).to eq([1])
      expect(new_progress(course_id: 'course-one').requested_at(2)).to be_a(String)
      expect(new_progress(course_id: 'course-one').expanded_step).to eq(3)
      expect(new_progress(course_id: 'course-two').done_steps).to eq([])
      expect(new_progress(course_id: 'course-two').requested_at(2)).to be_nil
      expect(new_progress(course_id: 'course-two').expanded_step).to be_nil

      stored = YAML.safe_load(File.read(@path))
      expect(stored.fetch('courses').keys).to contain_exactly('course-one')
    end

    it 'preserves other courses when separate instances write in sequence' do
      new_progress(course_id: 'course-one').mark_done!(1)
      new_progress(course_id: 'course-two').mark_done!(2)

      expect(new_progress(course_id: 'course-one').done_steps).to eq([1])
      expect(new_progress(course_id: 'course-two').done_steps).to eq([2])
    end

    it 'merges marks from two stale instances of the same course' do
      first = new_progress(course_id: 'course-one')
      second = new_progress(course_id: 'course-one')

      first.mark_done!(1)
      second.mark_done!(2)

      expect(new_progress(course_id: 'course-one').done_steps).to eq([1, 2])
    end

    it 'atomically replaces the ledger for a course mutation' do
      expect(File).to receive(:rename).with(
        a_temporary_ledger_path,
        @path
      ).and_call_original

      new_progress(course_id: 'course-one').mark_done!(1)
      expect(new_progress(course_id: 'course-one').done_steps).to eq([1])
    end

    it 'merges requests from two stale instances of the same course' do
      first = new_progress(course_id: 'course-one')
      second = new_progress(course_id: 'course-one')

      first.record_run!(1, status: :sent)
      second.record_run!(2, status: :sent)

      reloaded = new_progress(course_id: 'course-one')
      expect(reloaded.requested_at(1)).to be_a(String)
      expect(reloaded.requested_at(2)).to be_a(String)
      expect(reloaded.last_run).to include('step' => 2, 'status' => 'sent')
    end

    it 'preserves a stale instance mark when another instance changes the expanded step' do
      first = new_progress(course_id: 'course-one')
      second = new_progress(course_id: 'course-one')

      first.mark_done!(1)
      second.expand_step!(3)

      reloaded = new_progress(course_id: 'course-one')
      expect(reloaded.done_steps).to eq([1])
      expect(reloaded.expanded_step).to eq(3)
    end

    it 'does not resurrect state cleared by reset when a stale instance later mutates the course' do
      original = new_progress(course_id: 'course-one')
      original.mark_done!(1)
      stale = new_progress(course_id: 'course-one')

      original.reset!
      stale.mark_done!(2)

      expect(new_progress(course_id: 'course-one').done_steps).to eq([2])
    end

    it 'resets only the selected course and backs up the complete ledger' do
      new_progress(course_id: 'course-one').mark_done!(1)
      new_progress(course_id: 'course-two').mark_done!(2)
      before_reset = File.read(@path)

      new_progress(course_id: 'course-one').reset!

      expect(File.read("#{@path}.bak")).to eq(before_reset)
      expect(new_progress(course_id: 'course-one').done_steps).to eq([])
      expect(new_progress(course_id: 'course-two').done_steps).to eq([2])
    end

    it 'exposes the selected course identifier' do
      expect(new_progress(course_id: 'course-one').course_id).to eq('course-one')
      expect(new_progress.course_id).to be_nil
    end
  end

  describe 'legacy progress.yml compatibility and migration' do
    it 'keeps no-course writes in the legacy top-level shape' do
      new_progress.mark_done!(2)

      stored = YAML.safe_load(File.read(@path))
      expect(stored).to include('done' => { '2' => true })
      expect(stored).not_to have_key('courses')
    end

    it 'reads legacy state as Getting Started when that course is selected explicitly' do
      new_progress.mark_done!(2)

      expect(new_progress(course_id: 'getting-started').done_steps).to eq([2])
    end

    it 'migrates legacy state without loss when another course first writes' do
      legacy = new_progress
      legacy.mark_done!(2)
      legacy.record_run!(3, status: :sent)

      new_progress(course_id: 'course-two').mark_done!(1)

      stored = YAML.safe_load(File.read(@path))
      expect(stored.dig('courses', 'getting-started', 'done')).to eq('2' => true)
      expect(stored.dig('courses', 'getting-started', 'requested', '3')).to be_a(String)
      expect(stored.dig('courses', 'course-two', 'done')).to eq('1' => true)
      expect(new_progress.done_steps).to eq([2])
    end

    it 'keeps namespaced courses intact when a no-course command later writes Getting Started' do
      new_progress(course_id: 'course-two').mark_done!(2)

      new_progress.mark_done!(1)

      expect(new_progress.done_steps).to eq([1])
      expect(new_progress(course_id: 'course-two').done_steps).to eq([2])
    end

    it 'keeps a later course write when an already-loaded no-course instance writes' do
      getting_started = new_progress
      new_progress(course_id: 'course-two').mark_done!(2)

      getting_started.mark_done!(1)

      expect(new_progress.done_steps).to eq([1])
      expect(new_progress(course_id: 'course-two').done_steps).to eq([2])
    end

    it 'keeps other courses when an already-loaded no-course instance resets' do
      getting_started = new_progress
      getting_started.mark_done!(1)
      new_progress(course_id: 'course-two').mark_done!(2)

      getting_started.reset!

      expect(new_progress.done_steps).to eq([])
      expect(new_progress(course_id: 'course-two').done_steps).to eq([2])
    end
  end
end
