# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'socket'
require 'stream_weaver/canvas/client'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/protocol'
require_relative '../support/env_helper'

# Two things the University listener needs from the client, both added for
# driver-worker-runner:
#
# 1. An overridable socket/pid path. Without it, ANY spec that boots a bridge
#    boots it over the developer's real ~/.streamweaver/canvas.sock, killing
#    the live bridge and every canvas session open in their browser.
# 2. A persistent event stream. `send_and_wait` opens a socket, takes one
#    event, and closes it -- a long-lived listener built on it drops every
#    click that lands while it is re-pushing.
RSpec.describe StreamWeaver::Canvas::Client do
  include EnvHelper

  describe 'isolatable socket and pid paths' do
    it 'honors STREAMWEAVER_CANVAS_SOCKET' do
      with_env('STREAMWEAVER_CANVAS_SOCKET' => '/tmp/elsewhere/canvas.sock') do
        expect(described_class.socket_path).to eq('/tmp/elsewhere/canvas.sock')
      end
    end

    it 'honors STREAMWEAVER_CANVAS_PID' do
      with_env('STREAMWEAVER_CANVAS_PID' => '/tmp/elsewhere/canvas.pid') do
        expect(described_class.pid_file_path).to eq('/tmp/elsewhere/canvas.pid')
      end
    end

    it 'falls back to ~/.streamweaver when unset' do
      with_env('STREAMWEAVER_CANVAS_SOCKET' => nil, 'STREAMWEAVER_CANVAS_PID' => nil) do
        expect(described_class.socket_path).to eq(File.expand_path('~/.streamweaver/canvas.sock'))
        expect(described_class.pid_file_path).to eq(File.expand_path('~/.streamweaver/canvas.pid'))
      end
    end

    # The server half must agree, or a redirected client talks to a socket
    # the server never created.
    it 'is the same path the bridge server binds' do
      with_env('STREAMWEAVER_CANVAS_SOCKET' => '/tmp/elsewhere/canvas.sock',
               'STREAMWEAVER_CANVAS_PID' => '/tmp/elsewhere/canvas.pid') do
        expect(StreamWeaver::Canvas::BridgeServer.socket_path).to eq(described_class.socket_path)
        expect(StreamWeaver::Canvas::BridgeServer.pid_file_path).to eq(described_class.pid_file_path)
      end
    end
  end

  describe '.each_event' do
    # Deliberately NOT under Dir.mktmpdir: a unix socket path caps at 104
    # bytes and macOS's per-user /var/folders tmpdir alone eats half of that.
    around do |example|
      dir = File.join('/tmp', "sw-evt-#{Process.pid}-#{rand(100_000)}")
      FileUtils.mkdir_p(dir)
      @socket_path = File.join(dir, 'c.sock')
      @pid_path = File.join(dir, 'c.pid')
      File.write(@pid_path, "pid=#{Process.pid}\nport=4700\n")
      @server = UNIXServer.new(@socket_path)
      with_env('STREAMWEAVER_CANVAS_SOCKET' => @socket_path,
               'STREAMWEAVER_CANVAS_PID' => @pid_path) { example.run }
    ensure
      @server&.close
      FileUtils.rm_rf(dir)
    end

    def event(name, button)
      StreamWeaver::Canvas::Protocol.encode(
        StreamWeaver::Canvas::Protocol::Messages.event(name, 'action', { button: button })
      )
    end

    it 'yields every event from ONE connection, without reconnecting per event' do
      seen = []
      thread = Thread.new do
        described_class.each_event('university') do |msg|
          seen << msg.dig(:data, :button)
          break if seen.size == 2
        end
      end

      conn = @server.accept
      conn.write(event('university', 'btn_run_run-1'))
      conn.write(event('university', 'btn_run_run-2'))
      thread.join(5)

      expect(seen).to eq(%w[btn_run_run-1 btn_run_run-2])
      # One accepted connection served both events. A second accept would
      # mean it reconnected -- the gap where clicks get lost.
      expect(@server.accept_nonblock(exception: false)).to eq(:wait_readable)
    ensure
      thread&.kill
      conn&.close
    end

    # The bridge broadcasts every session's events to every connected client
    # (docs/bug-2026-08-24-canvas-bridge-broadcasts-no-session-filtering.md),
    # so the listener must not act on another session's clicks.
    it 'ignores events belonging to a different session' do
      seen = []
      thread = Thread.new do
        described_class.each_event('university') do |msg|
          seen << msg.dig(:data, :button)
          break
        end
      end

      conn = @server.accept
      conn.write(event('some-other-canvas', 'btn_run_run-9'))
      conn.write(event('university', 'btn_run_run-1'))
      thread.join(5)

      expect(seen).to eq(['btn_run_run-1'])
    ensure
      thread&.kill
      conn&.close
    end

    it 'returns rather than spinning when the bridge closes the connection' do
      thread = Thread.new { described_class.each_event('university') { |_| } }
      conn = @server.accept
      conn.close

      expect(thread.join(5)).to eq(thread)
    ensure
      thread&.kill
    end

    it 'raises NotRunningError when there is no bridge at all' do
      with_env('STREAMWEAVER_CANVAS_PID' => File.join(Dir.tmpdir, 'definitely-absent.pid')) do
        expect { described_class.each_event('university') { |_| } }
          .to raise_error(described_class::NotRunningError)
      end
    end
  end
end
