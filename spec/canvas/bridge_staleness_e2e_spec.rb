# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'net/http'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/canvas/staleness_guard'
require 'stream_weaver/canvas/code_stamp'
require_relative '../support/env_helper'
require_relative '../support/output_helper'

# The check the unit specs cannot make: a REAL bridge process, a REAL
# canvas-push, and a pid file doctored to look like the developer just ran
# `rake install` underneath it (disc-171). The heal has to leave the operator
# with a bridge on current code, the sessions they had open still holding
# their content, and the push they actually asked for done.
#
# Isolated by env -- throwaway socket, pid file, snapshot root and history
# root -- so it never touches the bridge the developer has open in a browser.
RSpec.describe 'Canvas bridge staleness auto-heal end to end' do
  include EnvHelper
  include OutputHelper

  let(:keep_session) { 'stale-e2e-keep' }
  let(:push_session) { 'stale-e2e-push' }

  # Short /tmp path, not Dir.mktmpdir: a unix socket path caps at 104 bytes
  # and macOS's per-user tmpdir alone eats half of that.
  around do |example|
    @dir = File.join('/tmp', "sw-stale-e2e-#{Process.pid}-#{rand(100_000)}")
    FileUtils.mkdir_p(@dir)
    with_env(
      'STREAMWEAVER_CANVAS_SOCKET' => File.join(@dir, 'c.sock'),
      'STREAMWEAVER_CANVAS_PID' => File.join(@dir, 'c.pid'),
      'STREAMWEAVER_SNAPSHOT_ROOT' => File.join(@dir, 'snapshots'),
      'STREAMWEAVER_HISTORY_ROOT' => File.join(@dir, 'history'),
      # Cleared from the suite-wide default (spec_helper) because the heal is
      # what this spec exists to exercise; safe because every path above is a
      # throwaway, so the only bridge in reach is the one this spec started.
      'SW_NO_AUTO_RESTART' => nil
    ) do
      StreamWeaver::Canvas::StalenessGuard.reset!
      example.run
    ensure
      kill_bridge
      StreamWeaver::Canvas::StalenessGuard.reset!
    end
  ensure
    FileUtils.rm_rf(@dir)
  end

  def pid_file = File.join(@dir, 'c.pid')
  def bridge_pid = File.read(pid_file)[/pid=(\d+)/, 1].to_i
  def bridge_port = File.read(pid_file)[/port=(\d+)/, 1].to_i

  def kill_bridge
    Process.kill('TERM', bridge_pid) if File.exist?(pid_file) && bridge_pid.positive?
  rescue SystemCallError, IOError
    nil
  end

  def get(path)
    Net::HTTP.get_response(URI("http://127.0.0.1:#{bridge_port}#{path}"))
  end

  def push(name, dsl)
    StreamWeaver::Canvas::Client.send_message(
      StreamWeaver::Canvas::Protocol::Messages.create(name, layout: :fluid, theme: :default)
    )
    StreamWeaver::Canvas::Client.send_message(
      StreamWeaver::Canvas::Protocol::Messages.push(name, dsl, source_dir: nil)
    )
  end

  def wait_until(seconds = 20)
    deadline = Time.now + seconds
    until (result = yield) || Time.now > deadline
      sleep 0.1
    end
    result
  end

  def start_bridge_with_two_sessions
    StreamWeaver::Canvas::Client.ensure_bridge_running
    expect(wait_until { File.exist?(pid_file) && bridge_port.positive? }).to be_truthy

    push(keep_session, "header1 'Original content'")
    push(push_session, "header1 'Placeholder'")
  end

  # Exactly what an install underneath a running bridge looks like from the
  # outside: same pid, same port, a code stamp that is no longer ours.
  def make_pid_file_look_stale
    File.write(pid_file, File.read(pid_file).sub(/^code=.*$/, 'code=/gone/lib/stream_weaver.rb:1'))
    StreamWeaver::Canvas::StalenessGuard.reset!
  end

  # The push a developer or agent actually runs, streams and all.
  def run_canvas_push(dsl)
    out = nil
    err = capture_stderr { out = capture_stdout { with_stdin(dsl) { StreamWeaver::CLI.canvas_push([push_session]) } } }
    [out, err]
  end

  it 'restarts the bridge under a canvas-push, keeps the other sessions, and lands the push' do
    start_bridge_with_two_sessions

    # The stamp is what makes any of this possible.
    expect(StreamWeaver::Canvas::CodeStamp.parse(File.read(pid_file)))
      .to eq(version: StreamWeaver::Canvas::CodeStamp.version,
             code: StreamWeaver::Canvas::CodeStamp.fingerprint)
    expect(get("/canvas/#{keep_session}").body).to include('Original content')

    old_pid = bridge_pid
    make_pid_file_look_stale

    out, err = run_canvas_push("header1 'Pushed after the heal'")

    # One line about the restart, on stderr so a JSON-emitting command's
    # stdout stays parseable, and the push the operator actually asked for.
    heal_lines = err.lines.grep(/canvas bridge was running older code/)
    expect(heal_lines.size).to eq(1)
    expect(heal_lines.first).to include('sessions preserved')
    expect(out).to eq("Pushed to #{push_session}\n")

    # A different process is serving now, and it carries a current stamp.
    expect(bridge_pid).not_to eq(old_pid)
    expect(StreamWeaver::Canvas::CodeStamp.stale?(StreamWeaver::Canvas::Client.read_bridge_info)).to be(false)

    # The session nobody touched came back with its content...
    expect(get("/canvas/#{keep_session}").body).to include('Original content')
    # ...and the push landed on the new bridge, not the one that was killed.
    expect(get("/canvas/#{push_session}").body).to include('Pushed after the heal')
  end

  it 'leaves a matching bridge completely alone' do
    start_bridge_with_two_sessions
    old_pid = bridge_pid
    StreamWeaver::Canvas::StalenessGuard.reset!

    _out, err = run_canvas_push("header1 'No restart wanted'")

    # canvas-push's own history line is the only thing on stderr; the guard
    # said nothing at all.
    expect(err).not_to include('StreamWeaver:')
    expect(bridge_pid).to eq(old_pid)
    expect(get("/canvas/#{push_session}").body).to include('No restart wanted')
  end

  it 'warns instead of restarting under SW_NO_AUTO_RESTART' do
    start_bridge_with_two_sessions
    old_pid = bridge_pid
    make_pid_file_look_stale

    err = nil
    with_env('SW_NO_AUTO_RESTART' => '1') do
      _out, err = run_canvas_push("header1 'Still pushed'")
    end

    expect(err).to include('canvas-restart')
    expect(bridge_pid).to eq(old_pid)
    expect(get("/canvas/#{push_session}").body).to include('Still pushed')
  end

  it 'refuses to restart twice in a row, so two disagreeing installs cannot ping-pong the bridge' do
    start_bridge_with_two_sessions
    make_pid_file_look_stale
    run_canvas_push("header1 'First heal'")

    healed_pid = bridge_pid
    make_pid_file_look_stale

    _out, err = run_canvas_push("header1 'Second push'")

    expect(err).to include('was just restarted')
    expect(bridge_pid).to eq(healed_pid)
    expect(get("/canvas/#{push_session}").body).to include('Second push')
  end
end
