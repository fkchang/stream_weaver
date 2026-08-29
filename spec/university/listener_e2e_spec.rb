# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'net/http'
require 'json'
require 'stream_weaver/canvas/client'
require 'stream_weaver/university/listener'
require 'stream_weaver/university/progress'
require_relative '../support/env_helper'

# The end-to-end check the unit specs can't make: a REAL bridge process, the
# REAL listener process started the REAL way (Listener.start!), and the exact
# HTTP event the canvas's button emits.
#
# UAT 2026-08-29 failed on the seam between two individually-correct halves --
# every button blanked the page and nothing moved, because the canvas carried
# no continue marker and nobody was running the listener. Both were green in
# unit tests. This spec exercises the whole loop: POST the button's event ->
# listener updates progress.yml -> listener re-pushes -> the served content is
# the course list again, not the terminal "Submitted" screen.
#
# Everything is isolated by env: STREAMWEAVER_CANVAS_SOCKET/_PID point the
# bridge at a throwaway socket, so this never touches the developer's live
# bridge or the canvas sessions open in their browser.
RSpec.describe 'University listener end to end', :unstubbed_listener_start do
  include EnvHelper

  # A session of its own, so this can never disturb a real `university`
  # canvas the developer has open. A method, not a constant in a block --
  # that would land on Object and collide with the next spec that wants
  # the name.
  def session_name = 'university-e2e'

  # Short /tmp path, not Dir.mktmpdir: a unix socket path caps at 104 bytes
  # and macOS's per-user tmpdir alone eats half of that.
  #
  # Teardown runs INSIDE with_env. Outside it, ENV is already restored to the
  # suite-wide paths from spec_helper, so `stop!` would read the wrong pid
  # file -- leaving this spec's listener alive and deleting the shared one.
  around do |example|
    @dir = File.join('/tmp', "sw-e2e-#{Process.pid}-#{rand(100_000)}")
    FileUtils.mkdir_p(@dir)
    with_env(
      'STREAMWEAVER_CANVAS_SOCKET' => File.join(@dir, 'c.sock'),
      'STREAMWEAVER_CANVAS_PID' => File.join(@dir, 'c.pid'),
      'STREAMWEAVER_UNIVERSITY_PROGRESS' => File.join(@dir, 'progress.yml'),
      'STREAMWEAVER_UNIVERSITY_WORKER' => File.join(@dir, 'worker.json'),
      'STREAMWEAVER_UNIVERSITY_LISTENER_PID' => File.join(@dir, 'listener.pid'),
      'STREAMWEAVER_UNIVERSITY_LISTENER_LOG' => File.join(@dir, 'listener.log')
    ) do
      example.run
    ensure
      stop_everything
    end
  ensure
    FileUtils.rm_rf(@dir)
  end

  def stop_everything
    StreamWeaver::University::Listener.stop!
    pid = File.read(File.join(@dir, 'c.pid'))[/pid=(\d+)/, 1].to_i
    Process.kill('TERM', pid) if pid.positive?
  rescue SystemCallError, IOError
    nil
  end

  def wait_until(seconds = 20)
    deadline = Time.now + seconds
    until (result = yield) || Time.now > deadline
      sleep 0.1
    end
    result
  end

  def bridge_port
    File.read(File.join(@dir, 'c.pid'))[/port=(\d+)/, 1].to_i
  end

  def get(path)
    Net::HTTP.get_response(URI("http://127.0.0.1:#{bridge_port}#{path}"))
  end

  def poll_html
    JSON.parse(get("/canvas/#{session_name}/poll").body)
  end

  # Byte-for-byte the payload adapter/alpinejs.rb's sendEvent('action', ...)
  # POSTs when the browser has no websocket -- the button click itself.
  def click(button)
    uri = URI("http://127.0.0.1:#{bridge_port}/canvas/#{session_name}/event")
    Net::HTTP.post(uri, JSON.dump(type: 'action', button: button, state: {}),
                   'Content-Type' => 'application/json')
  end

  def progress
    StreamWeaver::University::Progress.new(File.join(@dir, 'progress.yml'))
  end

  it 'turns a real button click into a ledger write and a re-rendered canvas' do
    StreamWeaver::Canvas::Client.ensure_bridge_running
    expect(wait_until { File.exist?(File.join(@dir, 'c.pid')) && bridge_port.positive? }).to be_truthy

    StreamWeaver::Canvas::Client.send_message(
      StreamWeaver::Canvas::Protocol::Messages.create(session_name, layout: :fluid, theme: :doc)
    )
    StreamWeaver::Canvas::Client.send_message(
      StreamWeaver::Canvas::Protocol::Messages.push(
        session_name,
        File.read(File.expand_path('../../lib/stream_weaver/university/canvas.rb', __dir__)),
        source_dir: nil
      )
    )

    first = get("/canvas/#{session_name}")
    expect(first.code).to eq('200')
    expect(first.body).to include('Getting Started')
    # The fix for the blanking: the marker showFeedback() looks for.
    expect(first.body).to include('sw-canvas-continue')

    # The production spawn, not a hand-copied approximation of it -- so this
    # also covers start!'s own argument list.
    StreamWeaver::University::Listener.start!(session_name: session_name)

    expect(progress.done?(2)).to be(false)

    # No sleep-and-hope for listener boot: mark_done! is idempotent, so
    # retrying the click until the ledger moves proves readiness instead of
    # assuming it, and can't flake on a slow cold `ruby -r`.
    expect(wait_until { click('btn_mark_done_mark-done-2'); progress.done?(2) }).to be_truthy

    after = get("/canvas/#{session_name}")
    expect(after.code).to eq('200')
    # Re-pushed: the ledger change is visible in the served page...
    expect(after.body).to include('uni-step uni-step--done')
    expect(after.body).to include('Getting Started')

    # ...and the CONTENT the browser swaps in is the course list, not the
    # terminal screen the UAT hit. Asserted against the poll payload, which
    # is exactly what replaces #app-container -- the full page always
    # contains that string inside showFeedback()'s own source.
    body = poll_html
    expect(body['html']).to include('Getting Started')
    expect(body['html']).to include('uni-step uni-step--done')
    expect(body['html']).not_to include('You can close this window')
    expect(body['version']).to be > 1

    # Second leg: a Run click drives the Runner too. No worker.json exists
    # here, so this is the degraded outcome -- which must reach the canvas as
    # the prompt plus a Copy button, not silence.
    run_body = wait_until do
      click('btn_run_run-1')
      body = poll_html
      body if body['html'].include?('uni-run-notice')
    end

    expect(run_body).to be_truthy
    expect(run_body['html']).to include('sw-copy-button')
    expect(progress.last_run['status']).to eq('no_worker')
    expect(progress.requested_at(1)).to be_nil # nothing was sent anywhere
  end
end
