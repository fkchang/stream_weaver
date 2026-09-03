# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'json'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/iterm'
require_relative 'support/env_helper'

# Covers `streamweaver get-started` (lib/stream_weaver/cli.rb): the
# dependency report across its three tiers (core / agent skills / premier
# iTerm2 surface), the --degraded / interactive-confirm gating, worker.json
# being written on the premier path, and that SW_NO_OPEN=1 suppresses the
# browser tab on the degraded path. Every probe is a separately stubbable
# class method (get_started_*_ok?/present?) so these specs never touch a
# real bridge, iTerm2, or the developer's actual $HOME.
RSpec.describe StreamWeaver::CLI do
  include EnvHelper

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

  ALL_PASS_PROBES = {
    get_started_ruby_ok?: true,
    get_started_bridge_ok?: true,
    get_started_claude_skills_root?: true,
    get_started_agents_skills_root?: true,
    get_started_agent_cli_present?: true,
    get_started_gh_cli_present?: true,
    get_started_gh_authed?: true,
    get_started_premier_darwin?: true,
    get_started_premier_in_iterm?: true,
    get_started_premier_gem_loadable?: true,
    get_started_premier_python_api?: true
  }.freeze

  def stub_probes(overrides = {})
    ALL_PASS_PROBES.merge(overrides).each do |method, value|
      allow(described_class).to receive(method).and_return(value)
    end
  end

  describe '.get_started_premier_gem_loadable?' do
    # Regression: this used to delegate to ITerm.available?, which also
    # gates on darwin + ITERM_SESSION_ID -- so a macOS user with the gem
    # installed but running from Terminal.app (not iTerm2) would be told the
    # gem itself was missing. It must answer "is the gem loadable" and
    # nothing else.
    it 'is true when the iterm2 gem requires successfully (real require -- the gem is installed in this test env)' do
      expect(described_class.get_started_premier_gem_loadable?).to be(true)
    end

    it 'is false when the gem is not installed' do
      allow(described_class).to receive(:require).with('iterm2').and_raise(LoadError)

      expect(described_class.get_started_premier_gem_loadable?).to be(false)
    end
  end

  # gh is only needed by course step 5 (pushing a doc to a gist) -- neither
  # probe ever blocks get-started, so both are advisory-only in the report.
  describe '.get_started_gh_cli_present?' do
    it 'is true when gh is on PATH' do
      allow(described_class).to receive(:command_on_path?).with('gh').and_return(true)
      expect(described_class.get_started_gh_cli_present?).to be(true)
    end

    it 'is false when gh is not on PATH' do
      allow(described_class).to receive(:command_on_path?).with('gh').and_return(false)
      expect(described_class.get_started_gh_cli_present?).to be(false)
    end
  end

  describe '.get_started_gh_authed?' do
    it 'is false without even trying `gh auth status` when gh itself is missing' do
      allow(described_class).to receive(:get_started_gh_cli_present?).and_return(false)
      allow(described_class).to receive(:system)

      expect(described_class.get_started_gh_authed?).to be(false)
      expect(described_class).not_to have_received(:system)
    end

    it 'is true when gh is present and `gh auth status` exits successfully' do
      allow(described_class).to receive(:get_started_gh_cli_present?).and_return(true)
      allow(described_class).to receive(:system).with('gh', 'auth', 'status', out: File::NULL, err: File::NULL).and_return(true)

      expect(described_class.get_started_gh_authed?).to be(true)
    end

    it 'is false when gh is present but not authenticated' do
      allow(described_class).to receive(:get_started_gh_cli_present?).and_return(true)
      allow(described_class).to receive(:system).with('gh', 'auth', 'status', out: File::NULL, err: File::NULL).and_return(false)

      expect(described_class.get_started_gh_authed?).to be(false)
    end

    # A captive portal or dead network must not make the very first command
    # a new user runs (get-started) look hung over an advisory-only check.
    # The timeout constant is stubbed down so this spec doesn't itself cost
    # GH_AUTH_TIMEOUT real seconds every suite run.
    it 'is false, not hung, when `gh auth status` outlasts the timeout' do
      stub_const('StreamWeaver::CLI::GH_AUTH_TIMEOUT', 0.05)
      allow(described_class).to receive(:get_started_gh_cli_present?).and_return(true)
      allow(described_class).to receive(:system) { sleep 5 }

      expect(described_class.get_started_gh_authed?).to be(false)
    end
  end

  describe '.print_get_started_remediation' do
    it 'does not suggest enabling the Python API toggle when the real problem is not being in iTerm2' do
      report = { premier: { darwin: true, in_iterm: false, gem_loadable: true, python_api: false } }
      out, _err = capture_io { described_class.print_get_started_remediation(report) }

      expect(out).to include('Run this from inside iTerm2')
      expect(out).not_to include('Enable Python API')
      expect(out).not_to include('gem install iterm2_ruby')
    end

    it 'suggests the gem install step when the gem truly is missing' do
      report = { premier: { darwin: true, in_iterm: true, gem_loadable: false, python_api: false } }
      out, _err = capture_io { described_class.print_get_started_remediation(report) }

      expect(out).to include('gem install iterm2_ruby')
      expect(out).not_to include('Enable Python API')
    end

    it 'suggests enabling the Python API only once darwin/iterm/gem are all satisfied' do
      report = { premier: { darwin: true, in_iterm: true, gem_loadable: true, python_api: false } }
      out, _err = capture_io { described_class.print_get_started_remediation(report) }

      expect(out).to include('Enable Python API')
    end
  end

  describe '.get_started_dependency_report' do
    it 'assembles every probe into the core/skills/premier tiers, all passing' do
      stub_probes
      report = described_class.get_started_dependency_report

      expect(report[:core]).to include(ruby_ok: true, bridge_ok: true)
      expect(report[:skills]).to eq(claude_root: true, agents_root: true, agent_cli: true)
      expect(report[:premier]).to eq(darwin: true, in_iterm: true, gem_loadable: true, python_api: true)
    end

    it 'reflects a failing state per-tier without touching the other tiers' do
      stub_probes(get_started_bridge_ok?: false, get_started_agent_cli_present?: false)
      report = described_class.get_started_dependency_report

      expect(report[:core][:bridge_ok]).to be(false)
      expect(report[:core][:ruby_ok]).to be(true)
      expect(report[:skills][:agent_cli]).to be(false)
      expect(report[:skills][:claude_root]).to be(true)
    end

    it 'includes the course tier (gh CLI + auth), which never blocks the premier decision' do
      stub_probes
      report = described_class.get_started_dependency_report

      expect(report[:course]).to eq(gh_cli: true, gh_authed: true)
      expect(described_class.get_started_premier_ok?(report)).to be(true)
    end
  end

  describe '.print_get_started_report' do
    it 'prints a checklist with a pass mark for every dependency when all probes pass' do
      stub_probes
      report = described_class.get_started_dependency_report
      out, _err = capture_io { described_class.print_get_started_report(report) }

      expect(out).to include('✅ Ruby')
      expect(out).to include('✅ canvas bridge can start')
      expect(out).to include('✅ Claude skills root')
      expect(out).to include('✅ cross-tool skills root')
      expect(out).to include('✅ agent CLI on PATH')
      expect(out).to include('✅ macOS')
      expect(out).to include('✅ running inside iTerm2')
      expect(out).to include('✅ iterm2_ruby gem installed')
      expect(out).to include('✅ iTerm2 Python API reachable')
      expect(out).to include('✅ gh CLI authenticated')
    end

    it 'prints a fail mark and a distinct PATH warning when every probe fails' do
      stub_probes(ALL_PASS_PROBES.transform_values { false })
      report = described_class.get_started_dependency_report
      out, _err = capture_io { described_class.print_get_started_report(report) }

      expect(out).to include('❌ Ruby')
      expect(out).to include('❌ canvas bridge can start')
      expect(out).to include('⚠️  no agent CLI')
      expect(out).to include('❌ macOS')
      expect(out).to include('❌ running inside iTerm2')
      expect(out).to include('❌ iterm2_ruby gem installed')
      expect(out).to include('❌ iTerm2 Python API reachable')
      expect(out).to include('⚠️  gh CLI not found')
      expect(out).to include('https://cli.github.com')
    end

    it 'prints a skipped mark, not a fail mark, for a premier tier that was never probed' do
      report = { premier: { darwin: nil, in_iterm: nil, gem_loadable: nil, python_api: nil },
                 course: { gh_cli: true, gh_authed: true } }
      out, _err = capture_io { described_class.print_get_started_report(report.merge(
        core: { ruby_ok: true, ruby_version: RUBY_VERSION, bridge_ok: true },
        skills: { claude_root: true, agents_root: true, agent_cli: true }
      )) }

      expect(out).not_to include('❌ macOS')
      expect(out.scan('⏭ ').size).to eq(4)
    end

    it 'does not raise, and prints a skipped mark rather than a false "not found", when the report has no course tier at all (a hand-built partial report)' do
      report = { premier: { darwin: nil, in_iterm: nil, gem_loadable: nil, python_api: nil },
                 core: { ruby_ok: true, ruby_version: RUBY_VERSION, bridge_ok: true },
                 skills: { claude_root: true, agents_root: true, agent_cli: true } }

      out = nil
      expect { out, _err = capture_io { described_class.print_get_started_report(report) } }.not_to raise_error
      expect(out).to include('⏭  gh CLI (not checked)')
      expect(out).not_to include('gh CLI not found')
    end

    it 'always prints the Chrome extension and browser-control advisories, regardless of any probe' do
      stub_probes
      report = described_class.get_started_dependency_report
      out, _err = capture_io { described_class.print_get_started_report(report) }

      expect(out).to include('chromewebstore.google.com/detail/streamweaver-doc-viewer/odjjednfpfiagefgpcfdlelldphmpcgj')
      expect(out).to include('claude-in-chrome')
      expect(out).to include('playwright-cli')
      expect(out).to include('/browse')
    end
  end

  describe '.get_started_premier_ok?' do
    it 'is true only when every premier probe passes' do
      stub_probes
      report = described_class.get_started_dependency_report
      expect(described_class.get_started_premier_ok?(report)).to be(true)
    end

    it 'is false when a single premier probe fails' do
      stub_probes(get_started_premier_python_api?: false)
      report = described_class.get_started_dependency_report
      expect(described_class.get_started_premier_ok?(report)).to be(false)
    end

    it 'is false when the premier tier was skipped (all nil)' do
      report = { premier: { darwin: nil, in_iterm: nil, gem_loadable: nil, python_api: nil } }
      expect(described_class.get_started_premier_ok?(report)).to be(false)
    end
  end

  describe '.get_started (gating)' do
    before { allow(described_class).to receive(:setup) }

    context 'with --degraded' do
      it 'goes straight to the degraded path without running (or being able to change the outcome via) the premier probes' do
        # Stub only core/skills -- leave the 4 premier probes unstubbed and
        # asserted never-called, proving --degraded skips the real cost
        # (Python API handshake timeout, bridge boot) entirely rather than
        # just discarding the answer.
        %i[get_started_ruby_ok? get_started_bridge_ok? get_started_claude_skills_root?
           get_started_agents_skills_root? get_started_agent_cli_present?].each do |m|
          allow(described_class).to receive(m).and_return(true)
        end
        %i[get_started_premier_darwin? get_started_premier_in_iterm?
           get_started_premier_gem_loadable? get_started_premier_python_api?].each do |m|
          expect(described_class).not_to receive(m)
        end
        expect(described_class).to receive(:get_started_degraded)
        expect(described_class).not_to receive(:get_started_premier)

        capture_io { described_class.get_started(['--degraded']) }
      end
    end

    context 'premier deps missing, non-interactive, no --degraded' do
      it 'exits rather than continuing' do
        stub_probes(get_started_premier_gem_loadable?: false, get_started_premier_python_api?: false)
        allow($stdin).to receive(:tty?).and_return(false)

        expect { capture_io { described_class.get_started([]) } }.to raise_error(SystemExit)
      end
    end

    context 'premier deps missing, interactive, user declines' do
      it 'exits rather than continuing' do
        stub_probes(get_started_premier_gem_loadable?: false, get_started_premier_python_api?: false)
        allow($stdin).to receive(:tty?).and_return(true)
        allow($stdin).to receive(:gets).and_return("n\n")

        expect { capture_io { described_class.get_started([]) } }.to raise_error(SystemExit)
      end
    end

    context 'premier deps missing, interactive, user confirms "continue anyway"' do
      it 'proceeds to the degraded path' do
        stub_probes(get_started_premier_gem_loadable?: false, get_started_premier_python_api?: false)
        allow($stdin).to receive(:tty?).and_return(true)
        allow($stdin).to receive(:gets).and_return("y\n")
        expect(described_class).to receive(:get_started_degraded)

        capture_io { described_class.get_started([]) }
      end
    end

    context 'premier deps available, --yes' do
      it 'skips the confirm prompt and goes straight to the premier path with the default agent' do
        stub_probes
        expect(described_class).to receive(:get_started_premier).with('claude')
        expect($stdin).not_to receive(:gets)

        capture_io { described_class.get_started(['--yes']) }
      end
    end

    context 'premier deps available, interactive, user confirms with default (empty) answer' do
      it 'proceeds to the premier path' do
        stub_probes
        allow($stdin).to receive(:tty?).and_return(true)
        allow($stdin).to receive(:gets).and_return("\n")
        expect(described_class).to receive(:get_started_premier).with('claude')

        capture_io { described_class.get_started([]) }
      end
    end

    context 'premier deps available, interactive, user declines' do
      it 'exits without opening the premier path' do
        stub_probes
        allow($stdin).to receive(:tty?).and_return(true)
        allow($stdin).to receive(:gets).and_return("n\n")
        expect(described_class).not_to receive(:get_started_premier)

        expect { capture_io { described_class.get_started([]) } }.to raise_error(SystemExit)
      end
    end

    context '--agent codex' do
      it 'passes the chosen agent through to the premier path' do
        stub_probes
        expect(described_class).to receive(:get_started_premier).with('codex')

        capture_io { described_class.get_started(['--yes', '--agent', 'codex']) }
      end
    end

    context 'an unknown --agent value' do
      it 'exits with an error before doing anything else' do
        expect(described_class).not_to receive(:setup)

        expect { capture_io { described_class.get_started(['--agent', 'gemini']) } }.to raise_error(SystemExit)
      end
    end
  end

  describe '.write_get_started_worker_json' do
    # Unsets the override explicitly: this example is about the default
    # location, and spec_helper sets STREAMWEAVER_UNIVERSITY_WORKER
    # suite-wide, which resolves first.
    it 'writes the agent session id, the controller session id, agent, cwd, and an ISO8601 timestamp under ~/.streamweaver/university/worker.json' do
      Dir.mktmpdir do |home|
        with_env('STREAMWEAVER_UNIVERSITY_WORKER' => nil, 'HOME' => home) do
          path = described_class.write_get_started_worker_json(
            'w-session-1', 'claude', '/some/project/dir', controller_session_id: 'ctrl-1'
          )

          expect(path).to eq(File.join(home, '.streamweaver', 'university', 'worker.json'))
          data = JSON.parse(File.read(path))
          expect(data['session_id']).to eq('w-session-1')
          expect(data['agent']).to eq('claude')
          expect(data['cwd']).to eq('/some/project/dir')
          expect(data['controller_session_id']).to eq('ctrl-1')
          expect(data['created_at']).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
        end
      end
    end

    # The writer and University::Runner (the reader) must resolve the same
    # path, override included -- otherwise a spec that exercises the
    # premier path overwrites the developer's real recorded worker session
    # no matter what the env says.
    it 'writes to the path University::Runner reads, honoring STREAMWEAVER_UNIVERSITY_WORKER' do
      Dir.mktmpdir do |dir|
        redirected = File.join(dir, 'elsewhere', 'worker.json')
        with_env('STREAMWEAVER_UNIVERSITY_WORKER' => redirected) do
          path = described_class.write_get_started_worker_json('w-session-9', 'codex', '/proj')

          expect(path).to eq(redirected)
          expect(path).to eq(StreamWeaver::University::Runner.worker_path)
          expect(StreamWeaver::University::Runner.worker['session_id']).to eq('w-session-9')
        end
      end
    end

    it 'defaults controller_session_id to nil when the controller window was not opened' do
      Dir.mktmpdir do |home|
        with_env('STREAMWEAVER_UNIVERSITY_WORKER' => nil, 'HOME' => home) do
          path = described_class.write_get_started_worker_json('w-session-1', 'claude', '/some/project/dir')

          data = JSON.parse(File.read(path))
          expect(data['controller_session_id']).to be_nil
        end
      end
    end
  end

  describe '.get_started_premier' do
    # Product design (revised 2026-08-31): the calling terminal is left
    # untouched, the worker tab holds ONLY the agent -- so it stays free to
    # acquire its own demo canvas pane per step -- and the University canvas
    # is the CONTROLLER, in a window of its own.
    let(:canvas_url) { 'http://127.0.0.1:59321/canvas/university' }

    it 'never calls panel (which would split the calling terminal)' do
      allow(described_class).to receive(:get_started_create_university_canvas).and_return(canvas_url)
      allow(StreamWeaver::ITerm).to receive(:open_worker_tab).and_return('w-session-1')
      allow(described_class).to receive(:get_started_open_controller_window).and_return('ctrl-1')
      allow(described_class).to receive(:write_get_started_worker_json)
      allow(described_class).to receive(:push_get_started_placeholder_canvas)
      expect(described_class).not_to receive(:panel)

      capture_io { described_class.get_started_premier('claude') }
    end

    # The worker tab must NOT be split with the canvas any more: the agent
    # opens its own demo canvas pane there as the steps ask it to.
    it 'never splits the canvas into the worker tab' do
      allow(described_class).to receive(:get_started_create_university_canvas).and_return(canvas_url)
      allow(StreamWeaver::ITerm).to receive(:open_worker_tab).and_return('w-session-1')
      allow(described_class).to receive(:get_started_open_controller_window).and_return('ctrl-1')
      allow(described_class).to receive(:write_get_started_worker_json)
      allow(described_class).to receive(:push_get_started_placeholder_canvas)
      expect(StreamWeaver::ITerm).not_to receive(:split_vertical_with_url)

      capture_io { described_class.get_started_premier('claude') }
    end

    it 'creates the canvas, opens the agent-only worker tab in the invoking directory, opens the controller window, records worker.json, then pushes the canvas last' do
      order = []
      allow(described_class).to receive(:get_started_create_university_canvas) { order << :create_canvas; canvas_url }
      allow(Dir).to receive(:pwd).and_return('/invoking/dir')
      allow(StreamWeaver::ITerm).to receive(:open_worker_tab).with('claude', dir: '/invoking/dir') { order << :worker; 'w-session-1' }
      allow(described_class).to receive(:get_started_open_controller_window).with(canvas_url) { order << :controller; 'ctrl-1' }
      allow(described_class).to receive(:write_get_started_worker_json)
        .with('w-session-1', 'claude', '/invoking/dir', controller_session_id: 'ctrl-1') { order << :record; '/fake/worker.json' }
      allow(described_class).to receive(:push_get_started_placeholder_canvas) { order << :push }

      capture_io { described_class.get_started_premier('claude') }

      expect(order).to eq(%i[create_canvas worker controller record push])
    end

    # A bridge restart moves the port (Forrest's live canvas came back on
    # 4701). The controller window must be pointed at whatever the bridge
    # just said it was listening on, never a remembered or default port.
    it 'points the controller window at the URL the live bridge just returned' do
      allow(described_class).to receive(:get_started_create_university_canvas)
        .and_return('http://127.0.0.1:4701/canvas/university')
      allow(StreamWeaver::ITerm).to receive(:open_worker_tab).and_return('w-session-1')
      allow(described_class).to receive(:write_get_started_worker_json)
      allow(described_class).to receive(:push_get_started_placeholder_canvas)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message)
      allow(StreamWeaver::ITerm).to receive(:open_browser_window).and_return('ctrl-1')

      capture_io { described_class.get_started_premier('claude') }

      expect(StreamWeaver::ITerm).to have_received(:open_browser_window)
        .with('http://127.0.0.1:4701/canvas/university')
    end

    it 'still pushes the canvas even when no worker tab could be opened, and never opens a controller window' do
      allow(described_class).to receive(:get_started_create_university_canvas).and_return(canvas_url)
      allow(StreamWeaver::ITerm).to receive(:open_worker_tab).and_return(nil)
      expect(described_class).not_to receive(:get_started_open_controller_window)
      expect(described_class).to receive(:push_get_started_placeholder_canvas)

      capture_io { described_class.get_started_premier('claude') }
    end

    it 'does not attempt to open a worker tab (or write worker.json) for an agent not on PATH, but still pushes the canvas' do
      allow(described_class).to receive(:get_started_create_university_canvas).and_return(canvas_url)
      allow(described_class).to receive(:command_on_path?).with('codex').and_return(false)
      expect(StreamWeaver::ITerm).not_to receive(:open_worker_tab)
      expect(described_class).not_to receive(:write_get_started_worker_json)
      expect(described_class).to receive(:push_get_started_placeholder_canvas)

      _out, err = capture_io { described_class.get_started_premier('codex') }
      expect(err).to include('not on PATH')
    end
  end

  describe '.get_started_open_controller_window' do
    it 'opens the canvas in its own window and records that session as the canvas pane' do
      allow(StreamWeaver::ITerm).to receive(:open_browser_window)
        .with('http://example/canvas')
        .and_return('ctrl-1')
      expect(StreamWeaver::Canvas::Client).to receive(:send_message) do |msg|
        expect(msg).to include(type: 'set_pane_id', name: 'university', pane_id: 'ctrl-1')
      end

      expect(described_class.get_started_open_controller_window('http://example/canvas')).to eq('ctrl-1')
    end

    it 'returns nil and records nothing when the window could not be opened' do
      allow(StreamWeaver::ITerm).to receive(:open_browser_window).and_return(nil)
      expect(StreamWeaver::Canvas::Client).not_to receive(:send_message)

      expect(described_class.get_started_open_controller_window('http://example/canvas')).to be_nil
    end
  end

  describe '.get_started_create_university_canvas' do
    it 'returns the URL from a successful create response' do
      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message).and_return(
        { type: 'ready', name: 'university', url: 'http://127.0.0.1:59321/canvas/university' }
      )

      expect(described_class.get_started_create_university_canvas).to eq('http://127.0.0.1:59321/canvas/university')
    end

    it 'aborts loudly when session creation fails' do
      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message).and_return({ type: 'error', message: 'boom' })

      expect { capture_io { described_class.get_started_create_university_canvas } }.to raise_error(SystemExit)
    end
  end

  describe '.get_started_degraded' do
    before do
      allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running)
      allow(StreamWeaver::Canvas::Client).to receive(:send_message).and_return(
        { type: 'ready', name: 'university', url: 'http://127.0.0.1:59321/canvas/university' }
      )
      allow(described_class).to receive(:push_get_started_placeholder_canvas)
    end

    it 'does not open a browser tab when SW_NO_OPEN=1' do
      prev = ENV['SW_NO_OPEN']
      ENV['SW_NO_OPEN'] = '1'
      begin
        expect(described_class).not_to receive(:open_browser)
        capture_io { described_class.get_started_degraded }
      ensure
        ENV['SW_NO_OPEN'] = prev
      end
    end

    it 'opens the browser tab to the canvas URL when SW_NO_OPEN is unset' do
      prev = ENV['SW_NO_OPEN']
      ENV.delete('SW_NO_OPEN')
      begin
        expect(described_class).to receive(:open_browser).with('http://127.0.0.1:59321/canvas/university')
        capture_io { described_class.get_started_degraded }
      ensure
        ENV['SW_NO_OPEN'] = prev
      end
    end

    it 'pushes the placeholder canvas' do
      expect(described_class).to receive(:push_get_started_placeholder_canvas)
      capture_io { described_class.get_started_degraded }
    end

    it 'prints the exact URL the live bridge returned, never a locally-assumed default port' do
      # 59321 is a deliberately arbitrary fixture port -- neither
      # Service::DEFAULT_PORT (4567, the standalone app server, a different
      # subsystem entirely) nor Canvas::BridgeServer::DEFAULT_PORT (4700).
      # If this passes, the printed/opened URL came straight from
      # Canvas::Client.send_message's response (itself sourced from the
      # bridge's real port in ~/.streamweaver/canvas.pid), not a constant.
      out, _err = capture_io { described_class.get_started_degraded }

      expect(out).to include('http://127.0.0.1:59321/canvas/university')
      expect(out).not_to include('4567')
      expect(out).not_to include('4700')
    end

    it 'aborts loudly rather than pushing into a nonexistent session when creation fails' do
      allow(StreamWeaver::Canvas::Client).to receive(:send_message).and_return({ type: 'error', message: 'boom' })
      expect(described_class).not_to receive(:push_get_started_placeholder_canvas)

      expect { capture_io { described_class.get_started_degraded } }.to raise_error(SystemExit)
    end
  end
end
