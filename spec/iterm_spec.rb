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

  # --- Driver adapter (driver-worker-runner) --------------------------------
  # The University canvas drives a worker tab through these two methods.
  # `send_to_session` must hit exactly the session id it is handed -- the
  # whole point of the story is that a mistargeted send lands a prompt in
  # somebody else's pane -- and `session_alive?` is the check that stops a
  # send to a tab the user already closed.

  describe '.send_to_session' do
    let(:client) { instance_double(ITerm2::Client) }

    before do
      allow(described_class).to receive(:available?).and_return(true)
      allow(ITerm2).to receive(:connect).and_yield(client)
      allow(client).to receive(:send_text).and_return(true)
    end

    it 'sends to exactly the session id given, never the calling session' do
      allow(described_class).to receive(:current_session_guid).and_return('calling-session')

      described_class.send_to_session('worker-session', 'do the thing')

      expect(client).to have_received(:send_text).with('worker-session', "do the thing\r").once
      expect(client).not_to have_received(:send_text).with('calling-session', anything)
    end

    # Pressing Return is a carriage return, not a line feed -- an LF typed
    # at a raw-mode TUI is not Enter. Owning that here (rather than letting
    # callers append their own newline) is what keeps terminal semantics
    # out of the University side.
    it 'submits by pressing Return (CR), not by appending a line feed' do
      described_class.send_to_session('worker-session', 'do the thing')

      expect(client).to have_received(:send_text).with('worker-session', "do the thing\r")
    end

    it 'sends the text with no submit keystroke when submit: false' do
      described_class.send_to_session('worker-session', 'half a thought', submit: false)

      expect(client).to have_received(:send_text).with('worker-session', 'half a thought')
    end

    it 'returns true when the RPC reports success' do
      expect(described_class.send_to_session('worker-session', "hi\n")).to be true
    end

    it 'returns false when the RPC reports failure' do
      allow(client).to receive(:send_text).and_return(false)

      expect(described_class.send_to_session('worker-session', "hi\n")).to be false
    end

    it 'returns false without connecting when no session id is given' do
      expect(described_class.send_to_session(nil, "hi\n")).to be false
      expect(ITerm2).not_to have_received(:connect)
    end

    it 'returns false without connecting when the gem is unavailable' do
      allow(described_class).to receive(:available?).and_return(false)

      expect(described_class.send_to_session('worker-session', "hi\n")).to be false
      expect(ITerm2).not_to have_received(:connect)
    end

    it 'returns false rather than raising when the RPC blows up' do
      allow(client).to receive(:send_text).and_raise(ITerm2::Error, 'boom')

      expect(described_class.send_to_session('worker-session', "hi\n")).to be false
    end
  end

  describe '.session_alive?' do
    let(:client) { instance_double(ITerm2::Client) }

    before do
      allow(described_class).to receive(:available?).and_return(true)
      allow(ITerm2).to receive(:connect).and_yield(client)
      allow(client).to receive(:topology).and_return(
        [
          { window_id: 'win-1', tab_id: 'tab-1', session_id: 'worker-session', title: 'claude' },
          { window_id: 'win-1', tab_id: 'tab-1', session_id: 'canvas-pane', title: 'Web Browser' }
        ]
      )
    end

    it 'is true when the session id is in the live topology' do
      expect(described_class.session_alive?('worker-session')).to be true
    end

    it 'is false when the session id is absent (the tab was closed)' do
      expect(described_class.session_alive?('gone-session')).to be false
    end

    it 'is false without connecting when no session id is given' do
      expect(described_class.session_alive?(nil)).to be false
      expect(ITerm2).not_to have_received(:connect)
    end

    it 'is false without connecting when the gem is unavailable' do
      allow(described_class).to receive(:available?).and_return(false)

      expect(described_class.session_alive?('worker-session')).to be false
      expect(ITerm2).not_to have_received(:connect)
    end

    it 'is false rather than raising when the lookup blows up' do
      allow(client).to receive(:topology).and_raise(ITerm2::Error, 'boom')

      expect(described_class.session_alive?('worker-session')).to be false
    end
  end

  describe '.split_vertical_with_url (target_session)' do
    # Product design: get-started's premier path splits the canvas into the
    # NEW worker tab's session, not the calling terminal's session -- so
    # split_pane must be able to target an arbitrary session id, not just
    # current_session_guid.
    let(:client) { instance_double(ITerm2::Client) }

    before do
      allow(described_class).to receive(:available?).and_return(true)
      allow(ITerm2).to receive(:connect).and_yield(client)
    end

    it 'splits the given target_session, not the calling session, when target_session is passed' do
      allow(described_class).to receive(:current_session_guid).and_return('calling-session-guid')
      allow(client).to receive(:split_pane).and_return('canvas-pane-1')

      result = described_class.split_vertical_with_url(
        'http://example/canvas', open_browser: false, target_session: 'worker-session-guid'
      )

      expect(client).to have_received(:split_pane).with(
        'worker-session-guid', vertical: true, profile_name: 'Web Browser',
        profile_customizations: { 'Initial URL' => 'http://example/canvas' }
      )
      expect(result).to eq(type: :browser, pane_id: 'canvas-pane-1')
    end

    it 'falls back to current_session_guid when target_session is not given (original panel behavior)' do
      allow(described_class).to receive(:current_session_guid).and_return('calling-session-guid')
      allow(client).to receive(:split_pane).and_return('some-pane')

      described_class.split_vertical_with_url('http://example/canvas', open_browser: false)

      expect(client).to have_received(:split_pane).with(
        'calling-session-guid', vertical: true, profile_name: 'Web Browser',
        profile_customizations: { 'Initial URL' => 'http://example/canvas' }
      )
    end
  end
end
