# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/iterm'
require 'iterm2'

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

  describe '.open_worker_tab' do
    # A new iTerm2 tab starts in $HOME, not the caller's cwd -- regression
    # coverage for streamweaver get-started's worker tab opening at ~
    # instead of the project it was invoked from (UAT finding).
    let(:client) { instance_double(ITerm2::Client) }

    before do
      allow(described_class).to receive(:available?).and_return(true)
      allow(ITerm2).to receive(:connect).and_yield(client)
      allow(client).to receive(:create_tab).and_return(session_id: 'w-1', window_id: 'win-1', tab_id: 'tab-1')
      allow(client).to receive(:send_text)
    end

    it 'sends a single line that cds (shell-escaped) into the given directory before launching the command' do
      described_class.open_worker_tab('claude', dir: '/tmp/my project')

      expect(client).to have_received(:send_text).with('w-1', "cd /tmp/my\\ project && claude\n")
    end

    it 'defaults dir to the caller cwd when not given' do
      allow(Dir).to receive(:pwd).and_return('/tmp/fake-project')

      described_class.open_worker_tab('claude')

      expect(client).to have_received(:send_text).with('w-1', "cd /tmp/fake-project && claude\n")
    end

    it 'returns the new tab session id' do
      expect(described_class.open_worker_tab('claude', dir: '/tmp')).to eq('w-1')
    end

    it 'returns nil without attempting a connection when the gem is unavailable' do
      allow(described_class).to receive(:available?).and_return(false)

      expect(described_class.open_worker_tab('claude', dir: '/tmp')).to be_nil
      expect(ITerm2).not_to have_received(:connect)
    end
  end
end
