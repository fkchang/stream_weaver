# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'json'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/iterm'

# Covers `streamweaver get-started` (lib/stream_weaver/cli.rb): the
# dependency report across its three tiers (core / agent skills / premier
# iTerm2 surface), the --degraded / interactive-confirm gating, worker.json
# being written on the premier path, and that SW_NO_OPEN=1 suppresses the
# browser tab on the degraded path. Every probe is a separately stubbable
# class method (get_started_*_ok?/present?) so these specs never touch a
# real bridge, iTerm2, or the developer's actual $HOME.
RSpec.describe StreamWeaver::CLI do
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
    end

    it 'prints a skipped mark, not a fail mark, for a premier tier that was never probed' do
      report = { premier: { darwin: nil, in_iterm: nil, gem_loadable: nil, python_api: nil } }
      out, _err = capture_io { described_class.print_get_started_report(report.merge(
        core: { ruby_ok: true, ruby_version: RUBY_VERSION, bridge_ok: true },
        skills: { claude_root: true, agents_root: true, agent_cli: true }
      )) }

      expect(out).not_to include('❌ macOS')
      expect(out.scan('⏭ ').size).to eq(4)
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
    it 'writes session id, agent, and an ISO8601 timestamp under ~/.streamweaver/university/worker.json' do
      Dir.mktmpdir do |home|
        prev_home = ENV['HOME']
        ENV['HOME'] = home
        begin
          path = described_class.write_get_started_worker_json('w-session-1', 'claude')

          expect(path).to eq(File.join(home, '.streamweaver', 'university', 'worker.json'))
          data = JSON.parse(File.read(path))
          expect(data['session_id']).to eq('w-session-1')
          expect(data['agent']).to eq('claude')
          expect(data['created_at']).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
        ensure
          ENV['HOME'] = prev_home
        end
      end
    end
  end

  describe '.get_started_premier' do
    it 'opens the panel, starts the worker tab, records worker.json, then pushes the canvas last' do
      order = []
      allow(described_class).to receive(:panel) { order << :panel }
      allow(StreamWeaver::ITerm).to receive(:open_worker_tab).with('claude') { order << :worker; 'w-session-1' }
      allow(described_class).to receive(:write_get_started_worker_json).with('w-session-1', 'claude') { order << :record; '/fake/worker.json' }
      allow(described_class).to receive(:push_get_started_placeholder_canvas) { order << :push }

      capture_io { described_class.get_started_premier('claude') }

      expect(order).to eq(%i[panel worker record push])
    end

    it 'still pushes the canvas even when no worker tab could be opened' do
      allow(described_class).to receive(:panel)
      allow(StreamWeaver::ITerm).to receive(:open_worker_tab).and_return(nil)
      expect(described_class).to receive(:push_get_started_placeholder_canvas)

      capture_io { described_class.get_started_premier('claude') }
    end

    it 'does not attempt to open a worker tab (or write worker.json) for an agent not on PATH, but still pushes the canvas' do
      allow(described_class).to receive(:panel)
      allow(described_class).to receive(:command_on_path?).with('codex').and_return(false)
      expect(StreamWeaver::ITerm).not_to receive(:open_worker_tab)
      expect(described_class).not_to receive(:write_get_started_worker_json)
      expect(described_class).to receive(:push_get_started_placeholder_canvas)

      _out, err = capture_io { described_class.get_started_premier('codex') }
      expect(err).to include('not on PATH')
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
