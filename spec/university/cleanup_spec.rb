# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/university/cleanup'
require_relative '../support/env_helper'

# Deletion safety. Every case here exists because the alternative is
# destroying something of the user's: the manifest is the allowlist, a ref
# that is not in it must be refused no matter who passes it, a gist is only
# ever deleted through an explicit confirm the surface performed, and a
# failed delete must leave its manifest entry alone so the thing can still
# be found later.
RSpec.describe StreamWeaver::University::Cleanup do
  include EnvHelper

  let(:artifacts) { StreamWeaver::University::Artifacts }

  around do |example|
    Dir.mktmpdir('university-cleanup-spec') do |dir|
      @dir = dir
      @state_dir = File.join(dir, 'state')
      FileUtils.mkdir_p(@state_dir)
      with_env(
        'STREAMWEAVER_UNIVERSITY_ARTIFACTS' => File.join(@state_dir, 'artifacts.yml'),
        'STREAMWEAVER_UNIVERSITY_PROGRESS' => File.join(@state_dir, 'progress.yml'),
        'STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR' => @state_dir
      ) do
        example.run
      end
    end
  end

  # A real file on disk, recorded in the manifest -- the only shape
  # delete_entry! will act on.
  def recorded_file(name, type: nil)
    path = File.join(@dir, name)
    File.write(path, "# #{name}\n")
    artifacts.record!(path, type: type, step: 4)
    path
  end

  describe 'the allowlist' do
    it 'refuses a path that is not in the manifest' do
      outsider = File.join(@dir, 'precious.rb')
      File.write(outsider, 'do not delete me')

      expect { described_class.delete_entry!('doc', outsider) }
        .to raise_error(described_class::Refused, /not in the University artifact manifest/)
      expect(File.exist?(outsider)).to be(true)
    end

    it 'refuses a path smuggled in under a type that IS recorded for another ref' do
      recorded_file('mine.rb')
      outsider = File.join(@dir, 'yours.rb')
      File.write(outsider, 'not mine')

      expect { described_class.delete_entry!('doc', outsider) }
        .to raise_error(described_class::Refused)
      expect(File.exist?(outsider)).to be(true)
    end

    it 'refuses an entry recorded under a type it cannot dispatch on' do
      # Only reachable by hand-editing artifacts.yml -- record! would have
      # refused this type on the way in. The second guard is the point.
      File.write(
        artifacts.path,
        YAML.dump('entries' => [{ 'type' => 'command', 'ref' => 'rm -rf /', 'step' => 1 }])
      )

      expect { described_class.delete_entry!('command', 'rm -rf /') }
        .to raise_error(described_class::Refused, /unknown artifact type/)
    end

    it 'refuses to close a session that is not a course demo session, even when the manifest names it' do
      # Hand-edited manifest naming the controller canvas the course must
      # never close.
      File.write(
        artifacts.path,
        YAML.dump('entries' => [{ 'type' => 'session', 'ref' => 'university', 'step' => 1 }])
      )
      allow(StreamWeaver::Canvas::Client).to receive(:send_message)

      expect { described_class.delete_entry!('session', 'university') }
        .to raise_error(described_class::Refused, /not a course demo session/)
      expect(StreamWeaver::Canvas::Client).not_to have_received(:send_message)
    end

    it 'refuses a state-file path outside the course state dir' do
      outsider = File.join(@dir, 'progress.yml')
      File.write(outsider, 'someone else\'s progress')

      expect { described_class.delete_state_file!(outsider) }
        .to raise_error(described_class::Refused, /not a University state file/)
      expect(File.exist?(outsider)).to be(true)
    end

    it 'refuses a file inside the state dir that is not one of the known state files' do
      stranger = File.join(@state_dir, 'notes.txt')
      File.write(stranger, 'personal')

      expect { described_class.delete_state_file!(stranger) }
        .to raise_error(described_class::Refused)
      expect(File.exist?(stranger)).to be(true)
    end
  end

  describe '.delete_entry! on a doc or org' do
    it 'deletes the file and forgets it' do
      path = recorded_file('university-doc.rb')

      outcome = described_class.delete_entry!('doc', path)

      expect(outcome.ok).to be(true)
      expect(File.exist?(path)).to be(false)
      expect(artifacts.all).to eq([])
    end

    it 'reports a file that is already gone rather than failing' do
      path = recorded_file('university-doc.org', type: 'org')
      FileUtils.rm_f(path)

      outcome = described_class.delete_entry!('org', path)

      expect(outcome.ok).to be(true)
      expect(outcome.message).to match(/already gone/)
      expect(artifacts.all).to eq([])
    end
  end

  describe '.delete_entry! on a gist' do
    let(:url) { 'https://gist.github.com/someone/abc123def456' }

    before { artifacts.record!(url, step: 5) }

    it 'shells gh with the gist id and forgets it on success' do
      allow(described_class).to receive(:gh_available?).and_return(true)
      allow(described_class).to receive(:system).and_return(true)

      outcome = described_class.delete_entry!('gist', url)

      expect(described_class).to have_received(:system)
        .with('gh', 'gist', 'delete', 'abc123def456', '--yes', hash_including(:out, :err))
      expect(outcome.ok).to be(true)
      expect(artifacts.all).to eq([])
    end

    it 'keeps the entry when gh is missing, so the URL can still be found' do
      allow(described_class).to receive(:gh_available?).and_return(false)
      allow(described_class).to receive(:system)

      outcome = described_class.delete_entry!('gist', url)

      expect(described_class).not_to have_received(:system)
      expect(outcome.ok).to be(false)
      expect(outcome.message).to include(url)
      expect(artifacts.all.size).to eq(1)
    end

    it 'keeps the entry when gh fails (already deleted, or not yours)' do
      allow(described_class).to receive(:gh_available?).and_return(true)
      allow(described_class).to receive(:system).and_return(false)

      outcome = described_class.delete_entry!('gist', url)

      expect(outcome.ok).to be(false)
      expect(artifacts.all.size).to eq(1)
    end

    it 'refuses a manifest gist entry whose ref is not a gist URL' do
      File.write(
        artifacts.path,
        YAML.dump('entries' => [{ 'type' => 'gist', 'ref' => 'https://example.com/evil', 'step' => 5 }])
      )
      allow(described_class).to receive(:system)

      expect { described_class.delete_entry!('gist', 'https://example.com/evil') }
        .to raise_error(described_class::Refused, /not a gist URL/)
      expect(described_class).not_to have_received(:system)
    end
  end

  describe '.delete_entry! on a session' do
    it 'sends one close message for an allowlisted demo session and forgets it' do
      artifacts.record_session!('doc-demo', step: 4)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message)

      outcome = described_class.delete_entry!('session', 'doc-demo')

      expect(StreamWeaver::Canvas::Client).to have_received(:send_message)
        .with(StreamWeaver::Canvas::Protocol::Messages.close('doc-demo'))
      expect(outcome.ok).to be(true)
      expect(artifacts.all).to eq([])
    end

    it 'treats a bridge that is not running as already closed' do
      artifacts.record_session!('dashboard', step: 1)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message)
        .and_raise(StreamWeaver::Canvas::Client::NotRunningError.new('no bridge'))

      expect(described_class.delete_entry!('session', 'dashboard').ok).to be(true)
      expect(artifacts.all).to eq([])
    end
  end

  describe '.delete_refs!' do
    it 'reports a refusal as its own outcome instead of raising through the batch' do
      kept = recorded_file('kept.rb')
      outsider = File.join(@dir, 'not-mine.rb')
      File.write(outsider, 'not mine')

      outcomes = described_class.delete_refs!('doc', [outsider, kept])

      expect(outcomes.first.ok).to be(false)
      expect(outcomes.first.message).to match(/refusing to delete/)
      expect(File.exist?(outsider)).to be(true)
      # The refusal must not cost the rest of the batch its turn.
      expect(outcomes.last.ok).to be(true)
      expect(File.exist?(kept)).to be(false)
    end
  end

  describe '.delete_type!' do
    it 'deletes every entry of one type and nothing of another' do
      doc = recorded_file('a.rb')
      org = recorded_file('a.org', type: 'org')

      described_class.delete_type!('doc')

      expect(File.exist?(doc)).to be(false)
      expect(File.exist?(org)).to be(true)
      expect(artifacts.all.map { |e| e['type'] }).to eq(['org'])
    end
  end

  describe '.state_files and .delete_state_files!' do
    it 'lists only the course-owned basenames that actually exist' do
      %w[progress.yml worker.json listener.log doc-demo_state.yml].each do |name|
        File.write(File.join(@state_dir, name), 'x')
      end
      File.write(File.join(@state_dir, 'unrelated.yml'), 'x')

      expect(described_class.state_files.map { |p| File.basename(p) })
        .to contain_exactly('progress.yml', 'worker.json', 'listener.log', 'doc-demo_state.yml')
    end

    it 'never reaches outside the state dir when only some env overrides are set' do
      # A partially-redirected environment: the ledger is redirected here,
      # growing_doc's own state dir is somewhere else entirely. That other
      # directory is not this course's state dir, so nothing in it is ours
      # to delete.
      Dir.mktmpdir('elsewhere') do |elsewhere|
        File.write(File.join(elsewhere, 'doc-demo_state.yml'), 'x')
        with_env('STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR' => elsewhere) do
          expect(described_class.state_files).to eq([])
        end
        expect(File.exist?(File.join(elsewhere, 'doc-demo_state.yml'))).to be(true)
      end
    end

    it 'deletes them and leaves everything else in the directory alone' do
      File.write(File.join(@state_dir, 'progress.yml'), 'x')
      keeper = File.join(@state_dir, 'unrelated.yml')
      File.write(keeper, 'x')

      described_class.delete_state_files!

      expect(File.exist?(File.join(@state_dir, 'progress.yml'))).to be(false)
      expect(File.exist?(keeper)).to be(true)
    end
  end

  describe '.inventory' do
    it 'groups everything cleanup could remove, and deletes nothing by reading it' do
      doc = recorded_file('a.rb')
      artifacts.record!('https://gist.github.com/me/abc123', step: 5)
      artifacts.record_session!('dashboard', step: 1)
      File.write(File.join(@state_dir, 'worker.json'), '{}')

      inv = described_class.inventory

      expect(inv['doc'].first).to include(ref: doc, exists: true)
      expect(inv['doc'].first[:size]).to be > 0
      expect(inv['gist'].map { |g| g[:ref] }).to eq(['https://gist.github.com/me/abc123'])
      expect(inv['session'].map { |s| s[:ref] }).to eq(['dashboard'])
      expect(inv[described_class::STATE].map { |s| File.basename(s[:ref]) })
        .to include('worker.json', 'artifacts.yml')
      expect(File.exist?(doc)).to be(true)
    end

    it 'is keyed by artifact type, with every group present even when empty' do
      expect(described_class.inventory.keys)
        .to eq(StreamWeaver::University::Artifacts::TYPES + [described_class::STATE])
      expect(described_class.inventory['gist']).to eq([])
    end

    it 'reports a recorded doc the user has already deleted themselves' do
      path = recorded_file('a.rb')
      FileUtils.rm_f(path)

      expect(described_class.inventory['doc'].first).to include(exists: false, size: nil)
    end

    it 'is empty? at the zero-state' do
      expect(described_class.empty?).to be(true)
    end
  end
end
