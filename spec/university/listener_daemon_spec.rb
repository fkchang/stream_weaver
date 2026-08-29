# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/university/listener'
require 'stream_weaver/canvas/client'
require_relative '../support/env_helper'

# Covers the listener's process lifecycle (driver-worker-runner UAT
# 2026-08-29: nothing happened on a click because nobody was running the
# listener -- `get-started` has to start it). Process.spawn/kill are stubbed;
# the spawn arguments themselves are asserted because a detached background
# process that silently fails to boot looks exactly like a working one.
RSpec.describe StreamWeaver::University::Listener, :unstubbed_listener_start do
  include EnvHelper

  around do |example|
    Dir.mktmpdir('university-listener-daemon-spec') do |dir|
      @pid_path = File.join(dir, 'listener.pid')
      @log_path = File.join(dir, 'listener.log')
      with_env(
        'STREAMWEAVER_UNIVERSITY_LISTENER_PID' => @pid_path,
        'STREAMWEAVER_UNIVERSITY_LISTENER_LOG' => @log_path
      ) { example.run }
    end
  end

  describe 'paths' do
    it 'honors the env overrides so specs never touch the real pid/log' do
      expect(described_class.pid_path).to eq(@pid_path)
      expect(described_class.log_path).to eq(@log_path)
    end

    it 'defaults both under ~/.streamweaver/university' do
      with_env('STREAMWEAVER_UNIVERSITY_LISTENER_PID' => nil,
               'STREAMWEAVER_UNIVERSITY_LISTENER_LOG' => nil) do
        expect(described_class.pid_path).to eq(File.expand_path('~/.streamweaver/university/listener.pid'))
        expect(described_class.log_path).to eq(File.expand_path('~/.streamweaver/university/listener.log'))
      end
    end
  end

  describe '.running?' do
    it 'is false when no pid file exists' do
      expect(described_class.running?).to be false
    end

    it 'is false when the recorded pid is not alive' do
      File.write(@pid_path, "424242\n")
      allow(Process).to receive(:kill).with(0, 424_242).and_raise(Errno::ESRCH)

      expect(described_class.running?).to be false
    end

    it 'is true when the recorded pid is alive' do
      File.write(@pid_path, "4242\n")
      allow(Process).to receive(:kill).with(0, 4242).and_return(1)
      allow(Process).to receive(:getpgid).with(4242).and_return(4242)

      expect(described_class.running?).to be true
    end

    it 'is false rather than raising when the pid file holds garbage' do
      File.write(@pid_path, "not a pid\n")

      expect(described_class.running?).to be false
    end
  end

  # The listener is invisible to the user, so every way it can quietly stop
  # working is a way the canvas goes dead again. Worse than before this
  # story, in fact: with the canvas_continue marker in place, a click that
  # gets no re-push leaves the page on "Working..." forever AND sets
  # _swFeedbackActive, which makes the adapter swallow every later click.
  describe '.run! resilience' do
    # Escaping run! needs an exception it does NOT handle: `loop` swallows
    # StopIteration, and run!'s outer rescue deliberately takes every
    # StandardError (that breadth is the point -- see the comment there), so
    # only something outside StandardError can end the loop for a test.
    # stub_const rather than a bare `class`, which would land on Object.
    before do
      stub_const('StopTheLoop', Class.new(Exception)) # rubocop:disable Lint/InheritException
      allow(described_class).to receive(:sleep)
    end

    it 'reconnects instead of exiting when the bridge closes the connection' do
      calls = 0
      allow(StreamWeaver::Canvas::Client).to receive(:each_event) do
        calls += 1
        raise StopTheLoop if calls > 2 # let the loop turn twice, then bail
        nil                              # a clean EOF: each_event just returns
      end

      expect { described_class.run! }.to raise_error(StopTheLoop)
      expect(calls).to eq(3)
      # Without the backoff a down bridge pegs a core; assert it, or
      # deleting the sleep leaves every example here green.
      expect(described_class).to have_received(:sleep)
        .with(described_class::RECONNECT_DELAY).at_least(:once)
    end

    it 'waits and retries rather than dying when the bridge is not running yet' do
      calls = 0
      allow(StreamWeaver::Canvas::Client).to receive(:each_event) do
        calls += 1
        raise StopTheLoop if calls > 1
        raise StreamWeaver::Canvas::Client::NotRunningError, 'no bridge'
      end

      expect { described_class.run! }.to raise_error(StopTheLoop)
      expect(calls).to eq(2)
    end

    it 'survives a connection error the same way' do
      calls = 0
      allow(StreamWeaver::Canvas::Client).to receive(:each_event) do
        calls += 1
        raise StopTheLoop if calls > 1
        raise StreamWeaver::Canvas::Client::ConnectionError, 'reset'
      end

      expect { described_class.run! }.to raise_error(StopTheLoop)
      expect(calls).to eq(2)
    end
  end

  describe '.start!' do
    before do
      allow(Process).to receive(:spawn).and_return(9001)
      allow(Process).to receive(:detach)
    end

    it 'passes the session name through to the spawned process' do
      described_class.start!(session_name: 'university-alt')

      expect(Process).to have_received(:spawn).with(
        RbConfig.ruby, a_string_matching(/\A-I/), '-r', anything,
        '-e', a_string_including('"university-alt"'),
        anything
      )
    end

    it 'spawns a detached ruby that requires the listener and calls run!' do
      described_class.start!

      expect(Process).to have_received(:spawn).with(
        RbConfig.ruby,
        a_string_matching(/\A-I/),
        '-r', 'stream_weaver/university/listener',
        '-e', 'StreamWeaver::University::Listener.run!(session_name: "university")',
        hash_including(out: [@log_path, 'a'], err: %i[child out], pgroup: true)
      )
      expect(Process).to have_received(:detach).with(9001)
    end

    it 'records the pid so a later stop/status can find it' do
      expect(described_class.start!).to eq(9001)
      expect(File.read(@pid_path).to_i).to eq(9001)
    end

    it 'creates the log directory rather than failing when it does not exist' do
      nested = File.join(Dir.mktmpdir('uni-nested'), 'deeper', 'listener.log')
      with_env('STREAMWEAVER_UNIVERSITY_LISTENER_LOG' => nested) do
        described_class.start!

        expect(Dir.exist?(File.dirname(nested))).to be true
      end
    end

    # A second get-started (or a canvas-restart) must not leave the previous
    # listener running: two listeners both re-push on every click, and the
    # loser's push can land after the winner's and show stale state.
    it 'stops an already-running listener before starting a new one' do
      File.write(@pid_path, "1234\n")
      gone = false
      allow(Process).to receive(:getpgid).with(1234).and_return(1234)
      allow(Process).to receive(:kill).with(0, 1234) { raise Errno::ESRCH if gone; 1 }
      allow(Process).to receive(:kill).with('TERM', 1234) { gone = true }
      allow(described_class).to receive(:sleep)

      described_class.start!

      expect(Process).to have_received(:kill).with('TERM', 1234)
      expect(Process).not_to have_received(:kill).with('KILL', 1234)
      expect(File.read(@pid_path).to_i).to eq(9001)
    end

    # Falling through the wait and spawning anyway is the exact two-listener
    # race await_exit exists to prevent, so it escalates instead.
    it 'escalates to KILL when the old listener ignores TERM' do
      File.write(@pid_path, "1234\n")
      allow(Process).to receive(:getpgid).with(1234).and_return(1234)
      allow(Process).to receive(:kill).with(0, 1234).and_return(1) # never dies
      allow(Process).to receive(:kill).with('TERM', 1234).and_return(1)
      allow(Process).to receive(:kill).with('KILL', 1234).and_return(1)
      allow(described_class).to receive(:sleep)

      described_class.start!

      expect(Process).to have_received(:kill).with('KILL', 1234)
      expect(Process).to have_received(:spawn)
    end

    # TERM is asynchronous. Spawning the replacement while the old process
    # is still connected gives two listeners racing to re-push, and whichever
    # push lands second wins -- so the canvas can settle on stale state.
    it 'waits for the terminated listener to actually exit before spawning' do
      File.write(@pid_path, "1234\n")
      alive = 3
      allow(Process).to receive(:getpgid).with(1234).and_return(1234)
      allow(Process).to receive(:kill).with(0, 1234) do
        alive -= 1
        raise Errno::ESRCH if alive <= 0

        1
      end
      allow(Process).to receive(:kill).with('TERM', 1234).and_return(1)
      allow(described_class).to receive(:sleep)

      described_class.start!

      expect(described_class).to have_received(:sleep).at_least(:once)
      expect(Process).to have_received(:spawn)
    end

    it 'does not try to kill anything when no listener is recorded' do
      allow(Process).to receive(:kill)

      described_class.start!

      expect(Process).not_to have_received(:kill).with('TERM', anything)
    end
  end

  describe '.stop!' do
    it 'terminates the recorded pid and clears the pid file' do
      File.write(@pid_path, "1234\n")
      allow(Process).to receive(:getpgid).with(1234).and_return(1234)
      allow(Process).to receive(:kill).with(0, 1234).and_return(1)
      allow(Process).to receive(:kill).with('TERM', 1234).and_return(1)

      expect(described_class.stop!).to be true
      expect(Process).to have_received(:kill).with('TERM', 1234)
      expect(File.exist?(@pid_path)).to be false
    end

    # After a crash plus enough pid churn the recorded number can belong to
    # somebody else's process. We spawn with pgroup: true, so our listener is
    # its own process-group leader -- a recycled pid almost never is.
    it 'refuses to kill a recycled pid that is not our own process group leader' do
      File.write(@pid_path, "1234\n")
      allow(Process).to receive(:kill).with(0, 1234).and_return(1)
      allow(Process).to receive(:kill).with('TERM', 1234).and_return(1)
      allow(Process).to receive(:getpgid).with(1234).and_return(999) # someone else's group

      expect(described_class.stop!).to be false
      expect(Process).not_to have_received(:kill).with('TERM', 1234)
      expect(File.exist?(@pid_path)).to be false
    end

    it 'is false and harmless when nothing is running' do
      expect(described_class.stop!).to be false
    end

    # A pid file left behind by a crashed listener must not wedge start!.
    it 'clears a stale pid file even though there is nothing to kill' do
      File.write(@pid_path, "424242\n")
      allow(Process).to receive(:kill).with(0, 424_242).and_raise(Errno::ESRCH)

      expect(described_class.stop!).to be false
      expect(File.exist?(@pid_path)).to be false
    end
  end

  describe '.status' do
    it 'reports the running pid and log location' do
      File.write(@pid_path, "1234\n")
      allow(Process).to receive(:kill).with(0, 1234).and_return(1)
      allow(Process).to receive(:getpgid).with(1234).and_return(1234)

      expect(described_class.status).to include(running: true, pid: 1234, log: @log_path)
    end

    it 'reports not running with no pid' do
      expect(described_class.status).to include(running: false, pid: nil)
    end
  end
end
