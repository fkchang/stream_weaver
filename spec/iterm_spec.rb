# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/iterm'
require 'iterm2'

RSpec.describe StreamWeaver::ITerm do
  # available? memoizes; reset between examples so stubs take effect. The
  # unsupported-gem warning is also memoized (printed once), same reason.
  before do
    described_class.remove_instance_variable(:@available) if described_class.instance_variable_defined?(:@available)
    described_class.remove_instance_variable(:@frame_hint_shown) if described_class.instance_variable_defined?(:@frame_hint_shown)
    described_class.remove_instance_variable(:@activate_hint_shown) if described_class.instance_variable_defined?(:@activate_hint_shown)
  end
  after do
    described_class.remove_instance_variable(:@available) if described_class.instance_variable_defined?(:@available)
    described_class.remove_instance_variable(:@frame_hint_shown) if described_class.instance_variable_defined?(:@frame_hint_shown)
    described_class.remove_instance_variable(:@activate_hint_shown) if described_class.instance_variable_defined?(:@activate_hint_shown)
  end

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
      allow(client).to receive(:set_window_frame)
      # Default: the calling window can't be resolved, so these examples
      # exercise the new-window path. The window-inheritance examples below
      # override this.
      allow(client).to receive(:topology).and_return([])
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

    # UAT 2026-08-29: the worker tab opened as its own new window, sized so
    # small it needed manual resizing twice before it was usable. The gem
    # exposes no set_property, so a frame cannot be set -- the real fix is to
    # put the tab in the window the user is already in, which is already the
    # size they chose.
    it 'creates the tab in the calling session\'s own window so it inherits that window size' do
      allow(described_class).to receive(:current_session_guid).and_return('calling-session')
      allow(client).to receive(:topology).and_return(
        [{ window_id: 'callers-window', tab_id: 'tab-0', session_id: 'calling-session' }]
      )

      described_class.open_worker_tab('claude', dir: '/tmp')

      expect(client).to have_received(:create_tab).with(window_id: 'callers-window')
    end

    it 'falls back to a new window when the calling window cannot be resolved' do
      allow(described_class).to receive(:current_session_guid).and_return(nil)
      allow(client).to receive(:topology).and_return([])

      expect(described_class.open_worker_tab('claude', dir: '/tmp')).to eq('w-1')
      expect(client).to have_received(:create_tab).with(no_args)
    end

    it 'falls back to a new window rather than failing when the topology lookup raises' do
      allow(described_class).to receive(:current_session_guid).and_return('calling-session')
      allow(client).to receive(:topology).and_raise(ITerm2::Error, 'boom')

      expect(described_class.open_worker_tab('claude', dir: '/tmp')).to eq('w-1')
      expect(client).to have_received(:create_tab).with(no_args)
    end

    it 'returns the new tab session id' do
      expect(described_class.open_worker_tab('claude', dir: '/tmp')).to eq('w-1')
    end

    it 'returns nil without attempting a connection when the gem is unavailable' do
      allow(described_class).to receive(:available?).and_return(false)

      expect(described_class.open_worker_tab('claude', dir: '/tmp')).to be_nil
      expect(ITerm2).not_to have_received(:connect)
    end

    # window-frame sizing (driver-worker-runner): a genuinely new window gets
    # sized wide; a window inherited from the caller is left alone.
    describe 'window frame sizing' do
      it 'sizes the new window to the default wide worker frame' do
        described_class.open_worker_tab('claude', dir: '/tmp')

        expect(client).to have_received(:set_window_frame).with('win-1', x: 80, y: 80, width: 1600, height: 1000)
      end

      it 'honors SW_WORKER_FRAME when set to a valid "x,y,w,h" value' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('SW_WORKER_FRAME').and_return('10,20,900,700')

        described_class.open_worker_tab('claude', dir: '/tmp')

        expect(client).to have_received(:set_window_frame).with('win-1', x: 10, y: 20, width: 900, height: 700)
      end

      it 'falls back to defaults when SW_WORKER_FRAME is garbage' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('SW_WORKER_FRAME').and_return('not-a-frame')

        described_class.open_worker_tab('claude', dir: '/tmp')

        expect(client).to have_received(:set_window_frame).with('win-1', x: 80, y: 80, width: 1600, height: 1000)
      end

      it 'does not touch the frame when reusing the calling window' do
        allow(described_class).to receive(:current_session_guid).and_return('calling-session')
        allow(client).to receive(:topology).and_return(
          [{ window_id: 'callers-window', tab_id: 'tab-0', session_id: 'calling-session' }]
        )

        described_class.open_worker_tab('claude', dir: '/tmp')

        expect(client).not_to have_received(:set_window_frame)
      end

      it 'degrades silently when the installed client lacks set_window_frame' do
        allow(client).to receive(:respond_to?).with(:set_window_frame).and_return(false)

        expect { described_class.open_worker_tab('claude', dir: '/tmp') }.not_to raise_error
        expect(client).not_to have_received(:set_window_frame)
      end

      # Ensure-minimum resize (driver-worker-runner round 2): reusing the
      # caller's window is otherwise hands-off, but a window smaller than
      # the worker minimum on EITHER axis is unusable for the same reason a
      # brand-new profile-default window was -- so it grows to the floor
      # instead of being left alone.
      describe 'ensure-minimum resize on the reused window' do
        # A plain (non-verifying) double, not instance_double(ITerm2::Client):
        # get_window_frame is the newest method on this adapter's surface,
        # and the locally installed gem can be mid-upgrade while these specs
        # run -- a verifying double would fail depending on exactly what the
        # gem on disk exposes at that instant, which is not what these specs
        # are about. See the frame-sizing specs' note on 0.2.0 for the same
        # class of problem.
        let(:client) { double('ITerm2::Client') }

        before do
          allow(described_class).to receive(:current_session_guid).and_return('calling-session')
          allow(client).to receive(:create_tab).and_return(session_id: 'w-1', window_id: 'win-1', tab_id: 'tab-1')
          allow(client).to receive(:send_text)
          allow(client).to receive(:set_window_frame)
          allow(client).to receive(:get_window_frame).and_return(x: 80, y: 80, width: 1600, height: 1000)
          allow(client).to receive(:topology).and_return(
            [{ window_id: 'callers-window', tab_id: 'tab-0', session_id: 'calling-session' }]
          )
        end

        it 'grows a too-small window to the worker minimum, keeping its x,y' do
          allow(client).to receive(:get_window_frame).with('callers-window')
            .and_return(x: 12, y: 34, width: 400, height: 300)

          described_class.open_worker_tab('claude', dir: '/tmp')

          expect(client).to have_received(:set_window_frame)
            .with('callers-window', x: 12, y: 34, width: 1600, height: 1000)
        end

        it 'grows only the short axis when just one dimension is under the minimum' do
          allow(client).to receive(:get_window_frame).with('callers-window')
            .and_return(x: 0, y: 0, width: 2000, height: 300)

          described_class.open_worker_tab('claude', dir: '/tmp')

          expect(client).to have_received(:set_window_frame)
            .with('callers-window', x: 0, y: 0, width: 2000, height: 1000)
        end

        it 'never shrinks or moves a window already at or above the minimum' do
          allow(client).to receive(:get_window_frame).with('callers-window')
            .and_return(x: 5, y: 5, width: 2400, height: 1400)

          described_class.open_worker_tab('claude', dir: '/tmp')

          expect(client).not_to have_received(:set_window_frame)
        end

        it 'honors SW_WORKER_FRAME as the floor, same as the new-window path' do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with('SW_WORKER_FRAME').and_return('0,0,900,700')
          allow(client).to receive(:get_window_frame).with('callers-window')
            .and_return(x: 0, y: 0, width: 400, height: 300)

          described_class.open_worker_tab('claude', dir: '/tmp')

          expect(client).to have_received(:set_window_frame)
            .with('callers-window', x: 0, y: 0, width: 900, height: 700)
        end

        it 'degrades silently when the installed client lacks get_window_frame' do
          allow(client).to receive(:respond_to?).with(:get_window_frame).and_return(false)

          expect { described_class.open_worker_tab('claude', dir: '/tmp') }.not_to raise_error
          expect(client).not_to have_received(:set_window_frame)
        end
      end
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
    # The exact bytes the text write must carry: the prompt inside one
    # bracketed-paste block. Spelled out literally here rather than built
    # from the constants, so a typo in either escape sequence fails a spec
    # instead of quietly agreeing with itself.
    let(:pasted) { "\e[200~do the thing\e[201~" }

    before do
      allow(described_class).to receive(:available?).and_return(true)
      allow(ITerm2).to receive(:connect).and_yield(client)
      allow(client).to receive(:send_text).and_return(true)
    end

    it 'sends to exactly the session id given, never the calling session' do
      allow(described_class).to receive(:current_session_guid).and_return('calling-session')

      described_class.send_to_session('worker-session', 'do the thing')

      expect(client).to have_received(:send_text).with('worker-session', pasted).once
      expect(client).not_to have_received(:send_text).with('calling-session', anything)
    end

    # UAT 2026-08-31: the prompt arrived in the claude pane but sat there
    # unsubmitted -- Forrest had to press Return. A CR riding in the same
    # write as the text is read as part of the pasted text, not as a
    # keypress. Return has to be its own event.
    it 'submits with a SEPARATE write carrying only the carriage return' do
      described_class.send_to_session('worker-session', 'do the thing')

      expect(client).to have_received(:send_text).with('worker-session', pasted).ordered
      expect(client).to have_received(:send_text).with('worker-session', "\r").ordered
    end

    it 'never appends the carriage return to the text write' do
      described_class.send_to_session('worker-session', 'do the thing')

      expect(client).not_to have_received(:send_text).with('worker-session', "do the thing\r")
      expect(client).not_to have_received(:send_text).with('worker-session', "#{pasted}\r")
    end

    # UAT 2026-09-03 (round 3): text write + separate CR write still left
    # the prompt sitting in the composer. Round 4 wraps the text -- and only
    # the text -- in bracketed paste so the TUI sees the block end before
    # the Return arrives.
    it 'wraps the text write in bracketed paste markers, then presses Return' do
      writes = []
      allow(client).to receive(:send_text) do |_id, t|
        writes << t
        true
      end

      described_class.send_to_session('worker-session', 'do the thing')

      expect(writes).to eq(["\e[200~do the thing\e[201~", "\r"])
      expect(writes.first).to start_with("\e[200~")
      expect(writes.first).to end_with("\e[201~")
    end

    it 'leaves the carriage return OUTSIDE the bracketed block' do
      described_class.send_to_session('worker-session', 'do the thing')

      expect(client).to have_received(:send_text).with('worker-session', "\r").once
      expect(client).not_to have_received(:send_text).with('worker-session', "\e[200~\r\e[201~")
      expect(client).not_to have_received(:send_text).with('worker-session', "\e[200~do the thing\r\e[201~")
    end

    it 'sends one write and no Return when submit: false' do
      described_class.send_to_session('worker-session', 'half a thought', submit: false)

      expect(client).to have_received(:send_text)
        .with('worker-session', "\e[200~half a thought\e[201~").once
      expect(client).not_to have_received(:send_text).with('worker-session', "\r")
    end

    it 'reports failure when the text lands but the Return does not' do
      allow(client).to receive(:send_text).with('worker-session', pasted).and_return(true)
      allow(client).to receive(:send_text).with('worker-session', "\r").and_return(false)

      expect(described_class.send_to_session('worker-session', 'do the thing')).to be false
    end

    it 'does not try to press Return when the text itself failed to send' do
      allow(client).to receive(:send_text).with('worker-session', pasted).and_return(false)

      expect(described_class.send_to_session('worker-session', 'do the thing')).to be false
      expect(client).not_to have_received(:send_text).with('worker-session', "\r")
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

    # Raise on Run (driver-worker-runner round 2): once a step prompt is
    # actually SENT, the worker's tab and window should come to front --
    # Run should feel like handing control to the agent, not something the
    # user has to go find. Scoped to the one seam where every legit send
    # raises and every refused/degraded send does not: activation only ever
    # happens after both writes (text, then Return) succeed.
    describe 'raise on Run (activate_session)' do
      # activate_session has shipped since iterm2_ruby 0.1.0 (confirmed live
      # against the installed 0.3.0), so unlike get_window_frame above this
      # stays on the outer instance_double(ITerm2::Client) -- the
      # respond_to? guard in production is cheap insurance, not a version
      # gate, so nothing here needs a moving-target workaround.
      before do
        allow(client).to receive(:activate_session).and_return(true)
      end

      it 'activates the session after a successful send' do
        described_class.send_to_session('worker-session', 'do the thing')

        expect(client).to have_received(:activate_session).with('worker-session').ordered
      end

      it 'activates only after both writes land, not before' do
        described_class.send_to_session('worker-session', 'do the thing')

        expect(client).to have_received(:send_text).with('worker-session', pasted).ordered
        expect(client).to have_received(:send_text).with('worker-session', "\r").ordered
        expect(client).to have_received(:activate_session).ordered
      end

      it 'does not activate when the text write itself failed' do
        allow(client).to receive(:send_text).with('worker-session', pasted).and_return(false)

        described_class.send_to_session('worker-session', 'do the thing')

        expect(client).not_to have_received(:activate_session)
      end

      it 'does not activate when the text lands but the Return does not (send_failed)' do
        allow(client).to receive(:send_text).with('worker-session', pasted).and_return(true)
        allow(client).to receive(:send_text).with('worker-session', "\r").and_return(false)

        described_class.send_to_session('worker-session', 'do the thing')

        expect(client).not_to have_received(:activate_session)
      end

      it 'does not activate when submit: false (nothing was run)' do
        described_class.send_to_session('worker-session', 'half a thought', submit: false)

        expect(client).not_to have_received(:activate_session)
      end

      it 'does not connect at all -- and so cannot activate -- without a session id (degraded mode)' do
        described_class.send_to_session(nil, 'do the thing')

        expect(ITerm2).not_to have_received(:connect)
      end

      it 'does not connect at all -- and so cannot activate -- when iTerm2 is unavailable (degraded mode)' do
        allow(described_class).to receive(:available?).and_return(false)

        described_class.send_to_session('worker-session', 'do the thing')

        expect(ITerm2).not_to have_received(:connect)
      end

      it 'still reports the send as successful even if activation itself blows up' do
        allow(client).to receive(:activate_session).and_raise(ITerm2::Error, 'boom')

        expect(described_class.send_to_session('worker-session', 'do the thing')).to be true
      end

      it 'degrades silently, with one memoized stderr hint, when the client lacks activate_session' do
        allow(client).to receive(:respond_to?).with(:activate_session).and_return(false)
        allow(described_class).to receive(:warn)

        described_class.send_to_session('worker-session', 'first')
        described_class.send_to_session('worker-session', 'second')

        expect(client).not_to have_received(:activate_session)
        expect(described_class).to have_received(:warn)
          .with('StreamWeaver: raise-on-run needs an iterm2_ruby client with activate_session (gem install iterm2_ruby)').once
      end
    end
  end

  # Public wrapper around the same activate_session RPC raise-on-Run uses
  # internally (round-7 UAT): `streamweaver canvas-raise` needs to bring an
  # existing pane forward from OUTSIDE a `connect` block, and without
  # calling `panel` again (which would split a second one).
  describe '.activate_session' do
    let(:client) { instance_double(ITerm2::Client) }

    before do
      allow(described_class).to receive(:available?).and_return(true)
      allow(ITerm2).to receive(:connect).and_yield(client)
      allow(client).to receive(:activate_session).and_return(true)
    end

    it 'activates exactly the given session id' do
      described_class.activate_session('canvas-pane')

      expect(client).to have_received(:activate_session).with('canvas-pane')
    end

    it 'returns true once it has attempted the activation' do
      expect(described_class.activate_session('canvas-pane')).to be true
    end

    it 'returns false without connecting when no session id is given' do
      expect(described_class.activate_session(nil)).to be false
      expect(ITerm2).not_to have_received(:connect)
    end

    it 'returns false without connecting when iTerm2 is unavailable' do
      allow(described_class).to receive(:available?).and_return(false)

      expect(described_class.activate_session('canvas-pane')).to be false
      expect(ITerm2).not_to have_received(:connect)
    end

    it 'still reports true even if the activation RPC itself blows up (fire-and-forget)' do
      allow(client).to receive(:activate_session).and_raise(ITerm2::Error, 'boom')

      expect(described_class.activate_session('canvas-pane')).to be true
    end

    it 'degrades silently when the installed client lacks activate_session' do
      allow(client).to receive(:respond_to?).with(:activate_session).and_return(false)

      expect { described_class.activate_session('canvas-pane') }.not_to raise_error
      expect(client).not_to have_received(:activate_session)
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

  # Design decision 2026-08-31: the University canvas is the CONTROLLER and
  # gets a window of its own, rather than riding as a pane inside the worker
  # tab. The worker tab is then just the agent, free to acquire its own demo
  # canvas pane per step. Built from primitives already proven in this file:
  # create_tab with no window_id makes a new window, split_pane with the
  # browser profile makes the browser, and the leftover shell is closed so
  # the window holds only the canvas.
  describe '.open_browser_window' do
    let(:client) { instance_double(ITerm2::Client) }

    before do
      allow(described_class).to receive(:available?).and_return(true)
      allow(ITerm2).to receive(:connect).and_yield(client)
      allow(client).to receive(:create_tab)
        .and_return(session_id: 'shell-1', window_id: 'win-new', tab_id: 'tab-1')
      allow(client).to receive(:split_pane).and_return('browser-1')
      allow(client).to receive(:close_session).and_return(true)
      allow(client).to receive(:set_window_frame)
    end

    it 'creates a NEW window, not a tab in the calling one' do
      allow(described_class).to receive(:current_session_guid).and_return('calling-session')

      described_class.open_browser_window('http://example/canvas/university')

      expect(client).to have_received(:create_tab).with(no_args)
    end

    it 'puts the browser in that window, pointed at the url' do
      described_class.open_browser_window('http://example/canvas/university')

      expect(client).to have_received(:split_pane).with(
        'shell-1', vertical: true, profile_name: 'Web Browser',
        profile_customizations: { 'Initial URL' => 'http://example/canvas/university' }
      )
    end

    it 'closes the leftover shell so the window holds only the canvas' do
      described_class.open_browser_window('http://example/canvas/university')

      expect(client).to have_received(:close_session).with('shell-1', force: true)
    end

    it 'returns the browser session id' do
      expect(described_class.open_browser_window('http://example/canvas')).to eq('browser-1')
    end

    # A failed close must never cost us the pane id: without it nothing
    # records set_pane_id, and the canvas window becomes unclosable.
    it 'still returns the pane id when closing the shell raises' do
      allow(client).to receive(:close_session).and_raise(ITerm2::Error, 'boom')

      expect(described_class.open_browser_window('http://example/canvas')).to eq('browser-1')
    end

    # The real client RAISES on a failed split; it returns nil only for an
    # OK response carrying no session. Both mean the same thing here.
    it 'takes the window down with it when the browser split raises' do
      allow(client).to receive(:split_pane).and_raise(ITerm2::Error, 'boom')

      expect(described_class.open_browser_window('http://example/canvas')).to be_nil
      expect(client).to have_received(:close_session).with('shell-1', force: true)
    end

    it 'takes the window down with it when the browser split returns nothing' do
      allow(client).to receive(:split_pane).and_return(nil)

      expect(described_class.open_browser_window('http://example/canvas')).to be_nil
      expect(client).to have_received(:close_session).with('shell-1', force: true)
    end

    it 'returns nil without connecting when the gem is unavailable' do
      allow(described_class).to receive(:available?).and_return(false)

      expect(described_class.open_browser_window('http://example/canvas')).to be_nil
      expect(ITerm2).not_to have_received(:connect)
    end

    it 'returns nil rather than raising when the RPC blows up' do
      allow(client).to receive(:create_tab).and_raise(ITerm2::Error, 'boom')

      expect(described_class.open_browser_window('http://example/canvas')).to be_nil
    end

    # window-frame sizing (driver-worker-runner): the controller always gets
    # its own new window, so it always sizes it (unlike open_worker_tab,
    # which only sizes on the no-window-to-inherit path).
    describe 'window frame sizing' do
      it 'sizes the new window to the default narrow controller frame' do
        described_class.open_browser_window('http://example/canvas')

        expect(client).to have_received(:set_window_frame).with('win-new', x: 40, y: 40, width: 760, height: 1200)
      end

      it 'honors SW_CONTROLLER_FRAME when set to a valid "x,y,w,h" value' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('SW_CONTROLLER_FRAME').and_return('5,5,500,900')

        described_class.open_browser_window('http://example/canvas')

        expect(client).to have_received(:set_window_frame).with('win-new', x: 5, y: 5, width: 500, height: 900)
      end

      it 'falls back to defaults when SW_CONTROLLER_FRAME is garbage' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('SW_CONTROLLER_FRAME').and_return('1,2,3')

        described_class.open_browser_window('http://example/canvas')

        expect(client).to have_received(:set_window_frame).with('win-new', x: 40, y: 40, width: 760, height: 1200)
      end

      it 'degrades silently when the installed client lacks set_window_frame' do
        allow(client).to receive(:respond_to?).with(:set_window_frame).and_return(false)

        expect { described_class.open_browser_window('http://example/canvas') }.not_to raise_error
        expect(client).not_to have_received(:set_window_frame)
      end
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
