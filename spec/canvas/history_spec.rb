# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'stream_weaver/canvas/history'

RSpec.describe StreamWeaver::Canvas::History do
  around do |ex|
    prev = ENV['STREAMWEAVER_HISTORY_ROOT']
    Dir.mktmpdir do |d|
      ENV['STREAMWEAVER_HISTORY_ROOT'] = d
      @root = d
      ex.run
    end
  ensure
    ENV['STREAMWEAVER_HISTORY_ROOT'] = prev
  end

  describe '.record' do
    it 'writes the DSL to <root>/<session>/<timestamp>.rb and returns the path' do
      path = described_class.record('demo', "header1 'Hi'")
      expect(File.read(path)).to eq("header1 'Hi'")
      expect(path).to start_with(File.join(@root, 'demo'))
      expect(path).to match(%r{/\d{8}_\d{6}\.rb\z})
    end

    it 'creates the session directory if it does not exist' do
      session_dir = File.join(@root, 'fresh')
      expect(Dir.exist?(session_dir)).to be(false)
      described_class.record('fresh', 'x')
      expect(Dir.exist?(session_dir)).to be(true)
    end

    it 'embeds the current timestamp in the filename' do
      now = Time.utc(2026, 4, 27, 14, 30, 52)
      allow(Time).to receive(:now).and_return(now)
      path = described_class.record('demo', 'x')
      expect(File.basename(path)).to eq('20260427_143052.rb')
    end

    it 'avoids filename collisions for rapid successive writes' do
      now = Time.utc(2026, 4, 27, 14, 30, 52)
      allow(Time).to receive(:now).and_return(now)
      p1 = described_class.record('demo', 'a')
      p2 = described_class.record('demo', 'b')
      expect(p1).not_to eq(p2)
      expect(File.read(p1)).to eq('a')
      expect(File.read(p2)).to eq('b')
    end

    it 'claims paths atomically — a file appearing between candidates is never clobbered' do
      now = Time.utc(2026, 4, 27, 14, 30, 52)
      allow(Time).to receive(:now).and_return(now)
      # Simulate another process winning the race for both the base name and
      # the first suffix before we write.
      dir = File.join(@root, 'demo')
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, '20260427_143052.rb'), 'theirs')
      File.write(File.join(dir, '20260427_143052_1.rb'), 'theirs too')

      path = described_class.record('demo', 'mine')

      expect(File.basename(path)).to eq('20260427_143052_2.rb')
      expect(File.read(File.join(dir, '20260427_143052.rb'))).to eq('theirs')
      expect(File.read(File.join(dir, '20260427_143052_1.rb'))).to eq('theirs too')
      expect(File.read(path)).to eq('mine')
    end

    it 'rejects session names containing path separators' do
      expect { described_class.record('../evil', 'x') }
        .to raise_error(ArgumentError)
      expect { described_class.record('a/b', 'x') }
        .to raise_error(ArgumentError)
      expect { described_class.record('a\\b', 'x') }
        .to raise_error(ArgumentError)
    end

    it 'rejects session names containing .. as a substring' do
      expect { described_class.record('foo..bar', 'x') }
        .to raise_error(ArgumentError)
      expect { described_class.record('..foo', 'x') }
        .to raise_error(ArgumentError)
    end

    it 'rejects empty or blank session names' do
      expect { described_class.record('', 'x') }.to raise_error(ArgumentError)
      expect { described_class.record('   ', 'x') }.to raise_error(ArgumentError)
    end

    it 'accepts well-formed session names (alnum, dot, underscore, dash)' do
      expect { described_class.record('brainstorm', 'x') }.not_to raise_error
      expect { described_class.record('auth-flow.v2_1', 'x') }.not_to raise_error
    end
  end

  describe '.cleanup' do
    def write_aged(session, name, age_days)
      dir = File.join(@root, session)
      FileUtils.mkdir_p(dir)
      path = File.join(dir, name)
      File.write(path, 'data')
      t = Time.now - (age_days * 86_400)
      File.utime(t, t, path)
      path
    end

    it 'deletes files older than MAX_AGE_DAYS' do
      old = write_aged('s1', '20200101_000000.rb', 30)
      described_class.cleanup
      expect(File.exist?(old)).to be(false)
    end

    it 'keeps files newer than MAX_AGE_DAYS' do
      fresh = write_aged('s1', '20260427_000000.rb', 1)
      described_class.cleanup
      expect(File.exist?(fresh)).to be(true)
    end

    it 'removes session directories that become empty after cleanup' do
      write_aged('stale', '20200101_000000.rb', 30)
      session_dir = File.join(@root, 'stale')
      described_class.cleanup
      expect(Dir.exist?(session_dir)).to be(false)
    end

    it 'preserves session directories that still contain fresh files' do
      write_aged('mixed', '20200101_000000.rb', 30)
      write_aged('mixed', '20260427_000000.rb', 1)
      session_dir = File.join(@root, 'mixed')
      described_class.cleanup
      expect(Dir.exist?(session_dir)).to be(true)
      expect(Dir.glob(File.join(session_dir, '*.rb')).size).to eq(1)
    end

    it 'does nothing when the history root does not exist' do
      missing = File.join(@root, 'does-not-exist-subdir')
      ENV['STREAMWEAVER_HISTORY_ROOT'] = missing
      expect { described_class.cleanup }.not_to raise_error
    end
  end

  describe '.root' do
    it 'honors STREAMWEAVER_HISTORY_ROOT env var' do
      expect(described_class.root).to eq(@root)
    end

    it 'falls back to ~/.streamweaver/history when env var is unset' do
      ENV.delete('STREAMWEAVER_HISTORY_ROOT')
      expect(described_class.root).to eq(File.expand_path('~/.streamweaver/history'))
    end

    it 'falls back to ~/.streamweaver/history when env var is an empty string' do
      ENV['STREAMWEAVER_HISTORY_ROOT'] = ''
      expect(described_class.root).to eq(File.expand_path('~/.streamweaver/history'))
    end
  end
end
