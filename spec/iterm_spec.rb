# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/iterm'

RSpec.describe StreamWeaver::ITerm do
  # available? memoizes; reset between examples so stubs take effect
  before { described_class.remove_instance_variable(:@available) if described_class.instance_variable_defined?(:@available) }
  after  { described_class.remove_instance_variable(:@available) if described_class.instance_variable_defined?(:@available) }

  describe '.gem_missing?' do
    it 'is true when in iTerm on macOS but the gem is unavailable' do
      allow(described_class).to receive(:available?).and_return(false)
      stub_const('RbConfig::CONFIG', RbConfig::CONFIG.merge('host_os' => 'darwin23'))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ITERM_SESSION_ID').and_return('w0t0p0:GUID')

      expect(described_class.gem_missing?).to be true
    end

    it 'is false when the gem is available' do
      allow(described_class).to receive(:available?).and_return(true)

      expect(described_class.gem_missing?).to be false
    end

    it 'is false outside iTerm (no ITERM_SESSION_ID)' do
      allow(described_class).to receive(:available?).and_return(false)
      stub_const('RbConfig::CONFIG', RbConfig::CONFIG.merge('host_os' => 'darwin23'))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ITERM_SESSION_ID').and_return(nil)

      expect(described_class.gem_missing?).to be false
    end

    it 'is false on non-macOS hosts' do
      allow(described_class).to receive(:available?).and_return(false)
      stub_const('RbConfig::CONFIG', RbConfig::CONFIG.merge('host_os' => 'linux-gnu'))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ITERM_SESSION_ID').and_return('w0t0p0:GUID')

      expect(described_class.gem_missing?).to be false
    end
  end
end
