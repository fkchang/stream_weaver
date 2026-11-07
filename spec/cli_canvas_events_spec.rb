# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/event_log'
require 'stream_weaver/canvas/client'

RSpec.describe StreamWeaver::CLI, '.canvas_events' do
  let(:dir) { Dir.mktmpdir('cli-events-spec') }
  let(:log) { File.join(dir, 'canvas-events.jsonl') }

  around do |example|
    old = ENV['STREAMWEAVER_CANVAS_EVENTS']
    ENV['STREAMWEAVER_CANVAS_EVENTS'] = log
    example.run
  ensure
    ENV['STREAMWEAVER_CANVAS_EVENTS'] = old
    FileUtils.rm_rf(dir)
  end

  def run(args)
    out = StringIO.new
    old = $stdout
    $stdout = out
    described_class.canvas_events(args)
    out.string
  ensure
    $stdout = old
  end

  before do
    StreamWeaver::Canvas::EventLog.record(:session_close, session_name: 'a', cause: 'cli_close',
                                                          caller_info: { command: 'streamweaver canvas-close a', pid: 7, claude_code_session_id: 'sess-9' })
    StreamWeaver::Canvas::EventLog.record(:session_create, session_name: 'b')
  end

  it 'never touches the bridge (a bridge call can restart it)' do
    expect(StreamWeaver::Canvas::Client).not_to receive(:send_message)
    expect(StreamWeaver::Canvas::Client).not_to receive(:ensure_bridge_running)
    expect(StreamWeaver::Canvas::StalenessGuard).not_to receive(:ensure_current!)

    run([])
  end

  it 'prints a readable line naming cause, caller and session id' do
    out = run([])

    expect(out).to include('session_close', 'cause=cli_close', 'streamweaver canvas-close a', 'session=sess-9')
  end

  it 'filters with --session' do
    out = run(%w[--session b])

    expect(out).to include('session_create')
    expect(out).not_to include('session_close')
  end

  it 'prints raw JSON lines with --json' do
    lines = run(%w[--json]).lines.map { |l| JSON.parse(l) }

    expect(lines.map { |l| l['event'] }).to eq(%w[session_close session_create])
  end

  it 'accepts --since and rejects junk' do
    expect(run(%w[--since 1h])).to include('session_close')
    expect { run(%w[--since soon]) }.to raise_error(SystemExit)
  end

  it 'says so when there is nothing recorded' do
    File.delete(log)

    expect(run([])).to include('No canvas events recorded')
  end
end
