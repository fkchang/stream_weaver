# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/university/artifacts'
require_relative '../support/env_helper'

# The manifest is the allowlist Cleanup deletes against, so its recording
# and type-inference rules are load-bearing safety, not bookkeeping: a ref
# that gets in here is a ref cleanup is allowed to destroy.
RSpec.describe StreamWeaver::University::Artifacts do
  include EnvHelper

  around do |example|
    Dir.mktmpdir('university-artifacts-spec') do |dir|
      @dir = dir
      with_env('STREAMWEAVER_UNIVERSITY_ARTIFACTS' => File.join(dir, 'artifacts.yml')) do
        example.run
      end
    end
  end

  describe '.path' do
    it 'honors STREAMWEAVER_UNIVERSITY_ARTIFACTS' do
      with_env('STREAMWEAVER_UNIVERSITY_ARTIFACTS' => '/tmp/elsewhere/artifacts.yml') do
        expect(described_class.path).to eq('/tmp/elsewhere/artifacts.yml')
      end
    end

    it 'falls back to ~/.streamweaver/university/artifacts.yml when unset' do
      with_env('STREAMWEAVER_UNIVERSITY_ARTIFACTS' => nil) do
        expect(described_class.path).to eq(File.expand_path('~/.streamweaver/university/artifacts.yml'))
      end
    end
  end

  describe 'zero-state' do
    it 'is empty and does not create the file just by reading it' do
      expect(described_class.all).to eq([])
      expect(described_class.grouped).to eq({})
      expect(File.exist?(described_class.path)).to be(false)
    end
  end

  describe '.infer_type' do
    it 'reads a gist.github.com URL as a gist' do
      expect(described_class.infer_type('https://gist.github.com/someone/abc123def')).to eq('gist')
    end

    it 'reads an .org path as an org and an .rb path as a doc' do
      expect(described_class.infer_type('/tmp/doc.org')).to eq('org')
      expect(described_class.infer_type('/tmp/doc.rb')).to eq('doc')
    end

    it 'reads an allowlisted demo session name as a session' do
      expect(described_class.infer_type('doc-demo')).to eq('session')
    end

    it 'returns nil for anything it does not recognize' do
      expect(described_class.infer_type('https://example.com/not-a-gist')).to be_nil
      expect(described_class.infer_type('/etc/passwd')).to be_nil
      expect(described_class.infer_type('some-session-i-opened-myself')).to be_nil
    end

    it 'refuses a gist.github.com URL with no id in it -- Cleanup could never delete one' do
      expect(described_class.infer_type('https://gist.github.com/someone')).to be_nil
      expect(described_class.infer_type('https://gist.github.com/')).to be_nil
    end
  end

  describe '.gist_id' do
    it 'is the single definition of "a gist URL" that both doors use' do
      expect(described_class.gist_id('https://gist.github.com/me/abc123def')).to eq('abc123def')
      expect(described_class.gist_id('https://gist.github.com/abc123def')).to eq('abc123def')
      expect(described_class.gist_id('https://gist.github.com/me')).to be_nil
    end
  end

  describe '.record!' do
    it 'records with an inferred type and a step, and persists immediately' do
      described_class.record!('/tmp/a.rb', step: 4)
      expect(File.exist?(described_class.path)).to be(true)

      entry = described_class.all.first
      expect(entry['type']).to eq('doc')
      expect(entry['ref']).to eq('/tmp/a.rb')
      expect(entry['step']).to eq(4)
      expect(entry['created_at']).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it 'lets an explicit type override inference' do
      described_class.record!('/tmp/a.rb', type: 'org')
      expect(described_class.all.first['type']).to eq('org')
    end

    it 'refuses a ref whose type cannot be determined' do
      expect(described_class.record!('/etc/passwd')).to be_nil
      expect(described_class.all).to eq([])
    end

    it 'refuses a type outside TYPES' do
      expect(described_class.record!('/tmp/a.rb', type: 'command')).to be_nil
      expect(described_class.all).to eq([])
    end

    it 'stores a file ref absolute -- the process that deletes it has a different cwd' do
      Dir.chdir(@dir) { described_class.record!('notes.rb') }

      ref = described_class.all.first['ref']
      # Compared by realpath, not by string: macOS resolves the tmpdir's
      # /var -> /private/var symlink on chdir, which is exactly the kind of
      # difference storing an expanded path exists to settle.
      expect(ref).to start_with('/')
      expect(File.realpath(File.dirname(ref))).to eq(File.realpath(@dir))
      expect(File.basename(ref)).to eq('notes.rb')
    end

    it 'refuses a gist URL it could never resolve to an id' do
      expect(described_class.record!('https://gist.github.com/someone', type: 'gist')).to be_nil
      expect(described_class.all).to eq([])
    end

    it 'dedupes on [type, ref] -- re-saving the same doc is still one thing to delete' do
      described_class.record!('/tmp/a.rb', step: 4)
      described_class.record!('/tmp/a.rb', step: 4)
      expect(described_class.all.size).to eq(1)
    end

    it 'keeps the same ref under two different types apart' do
      described_class.record!('/tmp/a.rb', type: 'doc')
      described_class.record!('/tmp/a.rb', type: 'org')
      expect(described_class.all.size).to eq(2)
    end
  end

  describe '.record_doc!' do
    it 'records the saved doc' do
      described_class.record_doc!(File.join(@dir, 'university-doc.rb'), step: 4)
      expect(described_class.grouped['doc'].map { |e| e['ref'] })
        .to eq([File.join(@dir, 'university-doc.rb')])
    end

    it 'also records an .org sibling that already exists beside it' do
      File.write(File.join(@dir, 'university-doc.org'), 'exported')
      described_class.record_doc!(File.join(@dir, 'university-doc.rb'), step: 4)

      expect(described_class.grouped['org'].map { |e| e['ref'] })
        .to eq([File.join(@dir, 'university-doc.org')])
    end

    it 'does not invent an .org sibling that has not been exported' do
      described_class.record_doc!(File.join(@dir, 'university-doc.rb'), step: 4)
      expect(described_class.grouped['org']).to be_nil
    end
  end

  describe '.record_session!' do
    it 'records an allowlisted course demo session' do
      described_class.record_session!('dashboard', step: 1)
      expect(described_class.grouped['session'].map { |e| e['ref'] }).to eq(['dashboard'])
    end

    it 'refuses a session the course never opened' do
      expect(described_class.record_session!('my-own-work')).to be_nil
      expect(described_class.record_session!('university')).to be_nil
      expect(described_class.all).to eq([])
    end
  end

  describe '.forget!' do
    it 'drops exactly one entry and leaves the rest' do
      described_class.record!('/tmp/a.rb')
      described_class.record!('/tmp/b.org')

      expect(described_class.forget!('doc', '/tmp/a.rb')).to be(true)
      expect(described_class.all.map { |e| e['ref'] }).to eq(['/tmp/b.org'])
    end

    it 'is a no-op for something that was never recorded' do
      expect(described_class.forget!('doc', '/tmp/nope.rb')).to be(false)
    end
  end

  describe '.grouped and .for_step' do
    before do
      described_class.record!('/tmp/a.rb', step: 4)
      described_class.record!('/tmp/a.org', step: 5)
      described_class.record!('https://gist.github.com/me/abc123', step: 5)
      described_class.record_session!('dashboard', step: 1)
    end

    it 'groups in TYPES order and omits empty groups' do
      expect(described_class.grouped.keys).to eq(%w[doc org gist session])
    end

    it 'reports what one step created' do
      expect(described_class.for_step(5).map { |e| e['ref'] })
        .to eq(['/tmp/a.org', 'https://gist.github.com/me/abc123'])
      expect(described_class.for_step(2)).to eq([])
    end
  end

  describe 'pending delete confirmation' do
    it 'round-trips through disk so a re-push can render it' do
      described_class.request_delete!(label: 'saved docs', kind: 'doc', refs: ['/tmp/a.rb'])

      expect(described_class.pending_delete).to eq(
        'label' => 'saved docs', 'kind' => 'doc', 'refs' => ['/tmp/a.rb']
      )
    end

    it 'clears without disturbing recorded entries' do
      described_class.record!('/tmp/a.rb')
      described_class.request_delete!(label: 'saved docs', kind: 'doc', refs: ['/tmp/a.rb'])
      described_class.clear_pending!

      expect(described_class.pending_delete).to be_nil
      expect(described_class.all.size).to eq(1)
    end
  end

  it 'survives a corrupt file rather than raising' do
    File.write(described_class.path, "\tnot: [valid")
    expect(described_class.all).to eq([])
  end
end
