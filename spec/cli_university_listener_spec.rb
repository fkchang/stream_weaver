# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'stream_weaver/cli'
require 'stream_weaver/university/listener'

# Covers `streamweaver university-listener [start|stop|status]` and the
# get-started wiring that starts it. UAT 2026-08-29 found every canvas button
# doing nothing because nobody was running the listener -- get-started opened
# the experience and then left it inert, so starting it is part of opening the
# door, not a manual step in a runbook.
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

  let(:listener) { StreamWeaver::University::Listener }

  describe '.university_listener' do
    it 'starts the listener and reports the pid and log' do
      allow(listener).to receive(:start!).and_return(9001)
      allow(listener).to receive(:log_path).and_return('/tmp/listener.log')

      out, _err = capture_io { described_class.university_listener(['start']) }

      expect(listener).to have_received(:start!)
      expect(out).to include('9001')
      expect(out).to include('/tmp/listener.log')
    end

    it 'stops a running listener' do
      allow(listener).to receive(:stop!).and_return(true)

      out, _err = capture_io { described_class.university_listener(['stop']) }

      expect(listener).to have_received(:stop!)
      expect(out).to match(/stopped/i)
    end

    it 'says so when there was nothing to stop' do
      allow(listener).to receive(:stop!).and_return(false)

      out, _err = capture_io { described_class.university_listener(['stop']) }

      expect(out).to match(/not running/i)
    end

    it 'reports a running listener with its pid' do
      allow(listener).to receive(:status).and_return(running: true, pid: 4242, log: '/tmp/l.log')

      out, _err = capture_io { described_class.university_listener(['status']) }

      expect(out).to include('4242')
      expect(out).to match(/running/i)
    end

    it 'reports a stopped listener' do
      allow(listener).to receive(:status).and_return(running: false, pid: nil, log: '/tmp/l.log')

      out, _err = capture_io { described_class.university_listener(['status']) }

      expect(out).to match(/not running/i)
    end

    it 'defaults to status when given no action' do
      allow(listener).to receive(:status).and_return(running: false, pid: nil, log: '/tmp/l.log')

      capture_io { described_class.university_listener([]) }

      expect(listener).to have_received(:status)
    end

    it 'exits with an error for an unknown action, without touching the listener' do
      allow(listener).to receive(:start!)
      allow(listener).to receive(:stop!)

      expect { capture_io { described_class.university_listener(['frobnicate']) } }
        .to raise_error(SystemExit)
      expect(listener).not_to have_received(:start!)
      expect(listener).not_to have_received(:stop!)
    end
  end

  describe 'get-started starts the listener' do
    before do
      allow(described_class).to receive(:push_get_started_placeholder_canvas)
      allow(described_class).to receive(:get_started_create_university_canvas).and_return('http://x/canvas/university')
      allow(listener).to receive(:start!).and_return(9001)
    end

    it 'starts it on the degraded path, after the canvas is pushed' do
      order = []
      allow(described_class).to receive(:push_get_started_placeholder_canvas) { order << :push }
      allow(listener).to receive(:start!) { order << :listener; 9001 }

      capture_io { described_class.get_started_degraded }

      expect(order).to eq(%i[push listener])
    end

    it 'starts it on the premier path, after the canvas is pushed' do
      order = []
      allow(described_class).to receive(:push_get_started_placeholder_canvas) { order << :push }
      allow(listener).to receive(:start!) { order << :listener; 9001 }
      allow(described_class).to receive(:command_on_path?).and_return(true)
      allow(StreamWeaver::ITerm).to receive(:open_worker_tab).and_return('w-1')
      allow(described_class).to receive(:get_started_split_canvas_into).and_return('pane-1')
      allow(described_class).to receive(:write_get_started_worker_json).and_return('/tmp/worker.json')

      capture_io { described_class.get_started_premier('claude') }

      expect(order).to eq(%i[push listener])
    end

    # The premier path bails out early when the agent CLI is missing; the
    # canvas is still pushed, so its buttons still need a listener.
    it 'still starts it when the premier path falls back to the placeholder canvas' do
      allow(described_class).to receive(:command_on_path?).and_return(false)

      capture_io { described_class.get_started_premier('claude') }

      expect(listener).to have_received(:start!)
    end
  end
end
