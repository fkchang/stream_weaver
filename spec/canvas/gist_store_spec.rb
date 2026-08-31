# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'stream_weaver/canvas/gist_store'

RSpec.describe StreamWeaver::Canvas::GistStore do
  around do |ex|
    prev = ENV['STREAMWEAVER_GIST_STORE']
    Dir.mktmpdir do |d|
      @store_path = File.join(d, 'gists.json')
      ENV['STREAMWEAVER_GIST_STORE'] = @store_path
      ex.run
    end
  ensure
    ENV['STREAMWEAVER_GIST_STORE'] = prev
  end

  describe '.path' do
    it 'returns the STREAMWEAVER_GIST_STORE env var when set' do
      expect(described_class.path).to eq(@store_path)
    end

    context 'when env var is unset' do
      around do |ex|
        prev = ENV['STREAMWEAVER_GIST_STORE']
        ENV.delete('STREAMWEAVER_GIST_STORE')
        ex.run
      ensure
        ENV['STREAMWEAVER_GIST_STORE'] = prev
      end

      it 'falls back to ~/.streamweaver/canvas/gists.json' do
        expect(described_class.path).to eq(File.expand_path('~/.streamweaver/canvas/gists.json'))
      end
    end
  end

  describe '.record and .lookup' do
    it 'round-trips an entry with id/url/revisions/created_at/updated_at' do
      entry = described_class.record('mydoc', id: 'abc123', url: 'https://gist.example/abc123', revisions: 1)

      expect(entry['id']).to eq('abc123')
      expect(entry['url']).to eq('https://gist.example/abc123')
      expect(entry['revisions']).to eq(1)
      expect(entry['created_at']).not_to be_nil
      expect(entry['updated_at']).not_to be_nil

      looked_up = described_class.lookup('mydoc')
      expect(looked_up).to eq(entry)
    end

    it 'returns nil for a name that was never recorded' do
      expect(described_class.lookup('nope')).to be_nil
    end

    it 'accepts a Symbol name and finds it back by either Symbol or String' do
      described_class.record(:mydoc, id: 'abc', url: 'https://gist.example/abc', revisions: 1)

      expect(described_class.lookup(:mydoc)['id']).to eq('abc')
      expect(described_class.lookup('mydoc')['id']).to eq('abc')
    end

    it 'preserves created_at and advances updated_at on a second record call' do
      described_class.record('mydoc', id: 'abc', url: 'https://gist.example/abc', revisions: 1)

      # Force a distinct, known prior timestamp without a real sleep: write
      # the store directly with an explicit earlier timestamp, then record
      # again and confirm created_at survived while updated_at moved on.
      store = JSON.parse(File.read(described_class.path))
      store['mydoc']['created_at'] = '2020-01-01T00:00:00Z'
      store['mydoc']['updated_at'] = '2020-01-01T00:00:00Z'
      File.write(described_class.path, JSON.generate(store))

      second = described_class.record('mydoc', id: 'abc', url: 'https://gist.example/abc', revisions: 2)

      expect(second['created_at']).to eq('2020-01-01T00:00:00Z')
      expect(second['updated_at']).not_to eq('2020-01-01T00:00:00Z')
      expect(second['revisions']).to eq(2)
    end
  end

  describe '.latest_for_prefix' do
    it 'returns the entry with the most recent updated_at among matching names' do
      described_class.record('session-a.doc1', id: '1', url: 'https://gist.example/1', revisions: 1)
      described_class.record('session-a.doc2', id: '2', url: 'https://gist.example/2', revisions: 1)
      described_class.record('session-b.doc1', id: '3', url: 'https://gist.example/3', revisions: 1)

      # Pin explicit ordering directly in the persisted JSON rather than
      # inferring it from write order -- an explicit assertion, not a
      # workaround.
      store = JSON.parse(File.read(described_class.path))
      store['session-a.doc1']['updated_at'] = '2026-01-01T00:00:00Z'
      store['session-a.doc2']['updated_at'] = '2026-01-02T00:00:00Z'
      store['session-b.doc1']['updated_at'] = '2026-01-03T00:00:00Z'
      File.write(described_class.path, JSON.generate(store))

      result = described_class.latest_for_prefix('session-a')
      expect(result['id']).to eq('2')
    end

    it 'returns nil when no recorded name matches the prefix' do
      described_class.record('session-a.doc1', id: '1', url: 'https://gist.example/1', revisions: 1)
      expect(described_class.latest_for_prefix('session-z')).to be_nil
    end

    it 'accepts a Symbol prefix' do
      described_class.record('session-a.doc1', id: '1', url: 'https://gist.example/1', revisions: 1)
      expect(described_class.latest_for_prefix(:'session-a')['id']).to eq('1')
    end
  end

  describe '.forget' do
    it 'removes a recorded entry so a subsequent lookup returns nil' do
      described_class.record('mydoc', id: 'abc', url: 'https://gist.example/abc', revisions: 1)
      described_class.forget('mydoc')
      expect(described_class.lookup('mydoc')).to be_nil
    end

    it 'does not raise when forgetting a name that was never recorded' do
      expect { described_class.forget('never-existed') }.not_to raise_error
    end

    it 'accepts a Symbol name for an entry recorded under that name' do
      described_class.record(:mydoc, id: 'abc', url: 'https://gist.example/abc', revisions: 1)
      described_class.forget(:mydoc)
      expect(described_class.lookup('mydoc')).to be_nil
    end
  end

  describe '.all' do
    it 'returns {} before anything has been recorded (cold start, no file yet)' do
      expect(described_class.all).to eq({})
    end

    it 'returns everything recorded' do
      described_class.record('doc1', id: '1', url: 'https://gist.example/1', revisions: 1)
      described_class.record('doc2', id: '2', url: 'https://gist.example/2', revisions: 1)

      expect(described_class.all.keys).to contain_exactly('doc1', 'doc2')
    end

    it 'returns {} rather than raising when the store file is corrupt JSON' do
      FileUtils.mkdir_p(File.dirname(described_class.path))
      File.write(described_class.path, '{not valid json')

      expect(described_class.all).to eq({})
    end
  end

  describe 'atomic write correctness' do
    it 'persists valid JSON with the expected shape, independent of .all' do
      described_class.record('mydoc', id: 'abc123', url: 'https://gist.example/abc123', revisions: 3)

      raw = JSON.parse(File.read(described_class.path))
      expect(raw['mydoc']['id']).to eq('abc123')
      expect(raw['mydoc']['url']).to eq('https://gist.example/abc123')
      expect(raw['mydoc']['revisions']).to eq(3)
      expect(raw['mydoc']['created_at']).not_to be_nil
      expect(raw['mydoc']['updated_at']).not_to be_nil
    end

    it 'cleans up the temp file and leaves the old store intact when the rename fails' do
      described_class.record('mydoc', id: 'abc', url: 'https://gist.example/abc', revisions: 1)
      previous = File.read(described_class.path)

      allow(File).to receive(:rename).and_raise(Errno::EACCES)

      expect do
        described_class.record('mydoc', id: 'new', url: 'https://gist.example/new', revisions: 2)
      end.to raise_error(Errno::EACCES)

      expect(File.read(described_class.path)).to eq(previous)
      dir = File.dirname(described_class.path)
      expect(Dir.children(dir)).to contain_exactly(File.basename(described_class.path))
    end
  end

  describe 'directory auto-creation' do
    it 'creates the parent directory when recording into a path whose directory does not exist yet' do
      Dir.mktmpdir do |d|
        nested = File.join(d, 'not-yet', 'created', 'gists.json')
        ENV['STREAMWEAVER_GIST_STORE'] = nested

        expect(Dir.exist?(File.dirname(nested))).to be(false)
        described_class.record('mydoc', id: 'abc', url: 'https://gist.example/abc', revisions: 1)
        expect(Dir.exist?(File.dirname(nested))).to be(true)
        expect(File.exist?(nested)).to be(true)
      end
    end
  end
end
