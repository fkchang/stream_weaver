# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'stream_weaver/cli'
require 'stream_weaver/university/artifacts'
require 'stream_weaver/university/cleanup'
require_relative 'support/env_helper'

# `streamweaver university-artifact`, `university-cleanup` and
# `university-stop`. The cleanup cases are the strict ones: --dry-run must
# delete nothing, a declined confirm must delete nothing, and a gist must
# never go without its own individual yes.
RSpec.describe StreamWeaver::CLI do
  include EnvHelper

  let(:artifacts) { StreamWeaver::University::Artifacts }

  def capture_io
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end

  around do |example|
    Dir.mktmpdir('university-artifacts-cli-spec') do |dir|
      @dir = dir
      @state_dir = File.join(dir, 'state')
      FileUtils.mkdir_p(@state_dir)
      with_env(
        'STREAMWEAVER_UNIVERSITY_ARTIFACTS' => File.join(@state_dir, 'artifacts.yml'),
        'STREAMWEAVER_UNIVERSITY_PROGRESS' => File.join(@state_dir, 'progress.yml'),
        'STREAMWEAVER_UNIVERSITY_WORKER' => File.join(@state_dir, 'worker.json')
      ) do
        example.run
      end
    end
  end

  def recorded_doc(name = 'university-doc.rb')
    path = File.join(@dir, name)
    File.write(path, '# doc')
    artifacts.record!(path, step: 4)
    path
  end

  # Answers every confirm the same way -- what a run with no tty does
  # already, made explicit.
  def answering(yes)
    allow(described_class).to receive(:get_started_confirm?).and_return(yes)
  end

  describe '.university_artifact' do
    it 'records a doc path with an inferred type and a step' do
      out, = capture_io { described_class.university_artifact(['add', '/tmp/a.rb', '--step', '4']) }

      expect(out).to include('Recorded doc: /tmp/a.rb (step 4)')
      expect(artifacts.all.first).to include('type' => 'doc', 'step' => 4)
    end

    it 'records a gist URL -- the one artifact only the worker ever sees' do
      capture_io { described_class.university_artifact(['add', 'https://gist.github.com/me/abc123', '--step=5']) }

      expect(artifacts.grouped['gist'].first['ref']).to eq('https://gist.github.com/me/abc123')
    end

    it 'takes an explicit --type over inference' do
      capture_io { described_class.university_artifact(['add', '/tmp/a.rb', '--type', 'org']) }
      expect(artifacts.all.first['type']).to eq('org')
    end

    it 'finds the ref with flags in front of it, not the flag value' do
      # An agent runs the command this way readily, and taking "doc" as the
      # ref would record a RELATIVE path that cleanup later resolves against
      # some other process's working directory.
      capture_io { described_class.university_artifact(['add', '--type', 'doc', '--step', '4', '/tmp/a.rb']) }

      expect(artifacts.all.first).to include('type' => 'doc', 'ref' => '/tmp/a.rb', 'step' => 4)
    end

    it 'refuses a ref it cannot classify rather than guessing' do
      out, err = capture_io do
        expect { described_class.university_artifact(['add', '/etc/passwd']) }
          .to raise_error(SystemExit)
      end

      expect(err).to include('could not tell what kind of artifact')
      expect(out).to eq('')
      expect(artifacts.all).to eq([])
    end

    it 'lists what is recorded, grouped' do
      recorded_doc
      artifacts.record!('https://gist.github.com/me/abc123', step: 5)

      out, = capture_io { described_class.university_artifact(['list']) }

      expect(out).to include('Saved docs (1):', 'Gists (1):', 'https://gist.github.com/me/abc123')
    end

    it 'says so plainly when nothing is recorded' do
      out, = capture_io { described_class.university_artifact(['list']) }
      expect(out).to include('No University artifacts recorded yet.')
    end
  end

  describe '.university_cleanup' do
    it 'says there is nothing to do at the zero-state' do
      out, = capture_io { described_class.university_cleanup([]) }
      expect(out).to include('Nothing to clean up')
    end

    it '--dry-run prints the inventory and deletes nothing, without ever prompting' do
      path = recorded_doc
      allow(described_class).to receive(:get_started_confirm?)

      out, = capture_io { described_class.university_cleanup(['--dry-run']) }

      expect(out).to include(path, '--dry-run: nothing was deleted.')
      expect(described_class).not_to have_received(:get_started_confirm?)
      expect(File.exist?(path)).to be(true)
      expect(artifacts.all.size).to eq(1)
    end

    it 'deletes a whole group on one yes' do
      path = recorded_doc
      answering(true)
      allow(StreamWeaver::University::Cleanup).to receive(:gh_available?).and_return(false)

      capture_io { described_class.university_cleanup([]) }

      expect(File.exist?(path)).to be(false)
      expect(artifacts.grouped['doc']).to be_nil
    end

    it 'deletes nothing when every group is declined' do
      path = recorded_doc
      artifacts.record_session!('doc-demo', step: 4)
      answering(false)

      out, = capture_io { described_class.university_cleanup([]) }

      expect(File.exist?(path)).to be(true)
      expect(artifacts.all.size).to eq(2)
      expect(out).to include('Kept: saved docs.')
    end

    it 'reports a refusal and keeps going, rather than a backtrace mid-delete' do
      # The shape a hand-edited manifest produces: an entry the allowlist
      # will refuse. It must not abort the run with files already gone and
      # the remaining groups never offered.
      outsider = File.join(@dir, 'not-mine.rb')
      File.write(outsider, 'not mine')
      File.write(artifacts.path, YAML.dump('entries' => [
                                             { 'type' => 'doc', 'ref' => outsider, 'step' => 4 }
                                           ]))
      # Refused is raised by delete_entry!'s fresh manifest read, so make
      # the manifest disagree with what cleanup was handed.
      allow(StreamWeaver::University::Cleanup).to receive(:delete_entry!)
        .and_raise(StreamWeaver::University::Cleanup::Refused, 'refusing to delete: test')
      answering(true)

      out, = capture_io { expect { described_class.university_cleanup([]) }.not_to raise_error }

      expect(out).to include('refusing to delete: test')
      expect(out).to include('Cleanup done.')
      expect(File.exist?(outsider)).to be(true)
    end

    it 'reports a doc the user already deleted themselves instead of erroring' do
      path = recorded_doc
      FileUtils.rm_f(path)
      answering(true)
      allow(StreamWeaver::University::Cleanup).to receive(:gh_available?).and_return(false)

      out, = capture_io { described_class.university_cleanup([]) }

      expect(out).to include('missing (already deleted)')
    end

    describe 'gists' do
      let(:url) { 'https://gist.github.com/me/abc123def' }

      before { artifacts.record!(url, step: 5) }

      it 'asks per gist, showing the URL, and deletes only on that yes' do
        allow(StreamWeaver::University::Cleanup).to receive(:gh_available?).and_return(true)
        allow(StreamWeaver::University::Cleanup).to receive(:system).and_return(true)
        allow(described_class).to receive(:get_started_confirm?) do |question, **|
          question.include?(url)
        end

        capture_io { described_class.university_cleanup([]) }

        expect(StreamWeaver::University::Cleanup).to have_received(:system)
          .with('gh', 'gist', 'delete', 'abc123def', '--yes', hash_including(:out, :err))
      end

      it 'never deletes a gist the user declined' do
        allow(StreamWeaver::University::Cleanup).to receive(:gh_available?).and_return(true)
        allow(StreamWeaver::University::Cleanup).to receive(:system)
        answering(false)

        out, = capture_io { described_class.university_cleanup([]) }

        expect(StreamWeaver::University::Cleanup).not_to have_received(:system)
        expect(out).to include("Kept #{url}")
      end

      it 'lists the URLs and skips when gh is not installed' do
        allow(StreamWeaver::University::Cleanup).to receive(:gh_available?).and_return(false)
        allow(StreamWeaver::University::Cleanup).to receive(:system)
        answering(false)

        out, = capture_io { described_class.university_cleanup([]) }

        expect(out).to include('gh is not installed', url)
        expect(StreamWeaver::University::Cleanup).not_to have_received(:system)
        expect(artifacts.grouped['gist'].size).to eq(1)
      end
    end

    it 'deletes the course state files, and nothing else in that directory' do
      File.write(File.join(@state_dir, 'listener.log'), 'log')
      keeper = File.join(@state_dir, 'something-else.txt')
      File.write(keeper, 'not mine')
      answering(true)
      allow(StreamWeaver::University::Cleanup).to receive(:gh_available?).and_return(false)

      capture_io { described_class.university_cleanup([]) }

      expect(File.exist?(File.join(@state_dir, 'listener.log'))).to be(false)
      expect(File.exist?(keeper)).to be(true)
    end
  end

  describe '.university_stop' do
    before do
      allow(StreamWeaver::University::Listener).to receive(:stop!).and_return(true)
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(true)
      allow(StreamWeaver::University::Listener).to receive(:close_demo_sessions!)
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(true)
      allow(StreamWeaver::ITerm).to receive(:close_pane).and_return(true)
    end

    def record_worker(session_id: 'worker-guid', controller_session_id: 'controller-guid')
      File.write(
        StreamWeaver::University::Runner.worker_path,
        JSON.generate(session_id: session_id, controller_session_id: controller_session_id)
      )
    end

    it 'stops the listener and closes the demo sessions without forgetting growing_doc state' do
      capture_io { described_class.university_stop }

      expect(StreamWeaver::University::Listener).to have_received(:stop!)
      expect(StreamWeaver::University::Listener).to have_received(:close_demo_sessions!)
        .with(clear_state: false)
    end

    it 'closes exactly the two iTerm sessions get-started recorded' do
      record_worker

      capture_io { described_class.university_stop }

      expect(StreamWeaver::ITerm).to have_received(:close_pane).with('worker-guid')
      expect(StreamWeaver::ITerm).to have_received(:close_pane).with('controller-guid')
      expect(StreamWeaver::ITerm).to have_received(:close_pane).twice
    end

    it 'never closes a session that is no longer alive' do
      record_worker
      allow(StreamWeaver::ITerm).to receive(:session_alive?).and_return(false)

      capture_io { described_class.university_stop }

      expect(StreamWeaver::ITerm).not_to have_received(:close_pane)
    end

    it 'closes nothing when no worker was ever recorded (the degraded path)' do
      capture_io { described_class.university_stop }
      expect(StreamWeaver::ITerm).not_to have_received(:close_pane)
    end

    it 'closes only the worker tab when no controller window was recorded' do
      record_worker(controller_session_id: nil)

      capture_io { described_class.university_stop }

      expect(StreamWeaver::ITerm).to have_received(:close_pane).with('worker-guid').once
      expect(StreamWeaver::ITerm).to have_received(:close_pane).once
    end

    it 'keeps progress and the artifact manifest, and says so' do
      recorded_doc
      progress_path = StreamWeaver::University::Progress.path
      StreamWeaver::University::Progress.load.mark_done!(1)

      out, = capture_io { described_class.university_stop }

      expect(File.exist?(progress_path)).to be(true)
      expect(artifacts.all.size).to eq(1)
      expect(out).to include('Kept your progress', 'Kept the artifact manifest')
    end

    it 'reports a bridge that is not running rather than trying to close sessions' do
      allow(StreamWeaver::Canvas::Client).to receive(:bridge_running?).and_return(false)

      out, = capture_io { described_class.university_stop }

      expect(StreamWeaver::University::Listener).not_to have_received(:close_demo_sessions!)
      expect(out).to include('canvas bridge not running')
    end
  end
end
