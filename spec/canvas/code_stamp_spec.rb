# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'stream_weaver/canvas/code_stamp'

# The comparison that decides whether a long-running canvas bridge is serving
# code the caller no longer has (disc-171). Everything here is pure string and
# stat work -- no bridge, no sockets -- because the auto-heal it feeds
# restarts a process the developer has open in a browser: a fingerprint that
# reports "different" when nothing changed is worse than the staleness itself.
RSpec.describe StreamWeaver::Canvas::CodeStamp do
  let(:tmpdir) { File.join(Dir.tmpdir, "sw-code-stamp-#{Process.pid}-#{rand(100_000)}") }
  let(:file) { File.join(tmpdir, 'stream_weaver.rb') }

  before do
    FileUtils.mkdir_p(tmpdir)
    File.write(file, "# fake library\n")
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe '.fingerprint_for' do
    it 'is stable across repeated reads of an untouched file' do
      expect(described_class.fingerprint_for(file)).to eq(described_class.fingerprint_for(file))
    end

    it 'changes when the same path is rewritten (the rake-install case)' do
      before_stamp = described_class.fingerprint_for(file)
      File.utime(Time.now + 60, Time.now + 60, file)

      expect(described_class.fingerprint_for(file)).not_to eq(before_stamp)
    end

    it 'differs between two paths holding identical content (the gem-vs-checkout case)' do
      other = File.join(tmpdir, 'other', 'stream_weaver.rb')
      FileUtils.mkdir_p(File.dirname(other))
      File.write(other, File.read(file))
      File.utime(File.mtime(file), File.mtime(file), other)

      expect(described_class.fingerprint_for(other)).not_to eq(described_class.fingerprint_for(file))
    end

    it 'is nil for a path that does not exist' do
      expect(described_class.fingerprint_for(File.join(tmpdir, 'gone.rb'))).to be_nil
    end
  end

  describe '.fingerprint' do
    it 'points at the stream_weaver.rb this process actually loaded' do
      expect(described_class.fingerprint).to start_with(described_class.library_path)
      expect(described_class.library_path).to eq(File.expand_path('../../lib/stream_weaver.rb', __dir__))
    end
  end

  describe '.parse' do
    it 'reads the stamp out of a pid file' do
      content = "pid=123\nport=4700\nversion=9.9.9\ncode=/x/stream_weaver.rb:1750000000\n"

      expect(described_class.parse(content)).to eq(version: '9.9.9', code: '/x/stream_weaver.rb:1750000000')
    end

    it 'returns nils for a pre-stamp pid file rather than raising (back-compat)' do
      expect(described_class.parse("pid=123\nport=4700\n")).to eq(version: nil, code: nil)
    end
  end

  describe '.stale?' do
    let(:current) { { version: described_class.version, code: described_class.fingerprint } }

    it 'is false when version and code fingerprint both match' do
      expect(described_class.stale?(current)).to be(false)
    end

    it 'is true when the bridge stamped a different version' do
      expect(described_class.stale?(current.merge(version: '0.0.1'))).to be(true)
    end

    it 'is true when the bridge stamped the same version from different code' do
      expect(described_class.stale?(current.merge(code: '/somewhere/else.rb:1'))).to be(true)
    end

    it 'is true for a bridge that carries no stamp at all (the upgrade case)' do
      expect(described_class.stale?(version: nil, code: nil)).to be(true)
      expect(described_class.stale?(nil)).to be(true)
    end

    it 'is false when this process cannot fingerprint its own code' do
      allow(described_class).to receive(:fingerprint).and_return(nil)

      expect(described_class.stale?(version: nil, code: nil)).to be(false)
    end
  end
end
