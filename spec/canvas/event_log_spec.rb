# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/canvas/event_log'

RSpec.describe StreamWeaver::Canvas::EventLog do
  let(:dir) { Dir.mktmpdir('event-log-spec') }
  let(:log) { File.join(dir, 'canvas-events.jsonl') }

  around do |example|
    old = ENV['STREAMWEAVER_CANVAS_EVENTS']
    ENV['STREAMWEAVER_CANVAS_EVENTS'] = log
    example.run
  ensure
    ENV['STREAMWEAVER_CANVAS_EVENTS'] = old
    FileUtils.rm_rf(dir)
  end

  def lines
    File.readlines(log).map { |l| JSON.parse(l) }
  end

  it 'appends one JSON line per event with the documented fields' do
    described_class.record(:session_close, session_name: 'a', pane_id: 'p1', cause: 'cli_close')

    expect(lines.size).to eq(1)
    expect(lines.first).to include('event' => 'session_close', 'session_name' => 'a', 'pane_id' => 'p1',
                                   'cause' => 'cli_close', 'caller' => 'unknown',
                                   'bridge_pid' => Process.pid, 'version' => StreamWeaver::VERSION)
    expect(Time.iso8601(lines.first['ts'])).to be_within(5).of(Time.now.utc)
  end

  it 'never guesses: a missing cause is unknown and an unrecognised one is other' do
    described_class.record(:x)
    described_class.record(:y, cause: 'because')

    expect(lines.map { |l| l['cause'] }).to eq(%w[unknown other])
  end

  it 'never raises into the caller when the log cannot be written' do
    ENV['STREAMWEAVER_CANVAS_EVENTS'] = File.join(log, 'not-a-dir', 'x.jsonl')
    File.write(log, 'a file where a directory is needed')

    expect(described_class.record(:session_close)).to be(false)
  end

  it 'keeps lines whole under concurrent appends' do
    threads = Array.new(8) { |t| Thread.new { 25.times { |i| described_class.record(:e, session_name: "t#{t}-#{i}") } } }
    threads.each(&:join)

    expect(lines.size).to eq(200)
    expect(lines.map { |l| l['session_name'] }.uniq.size).to eq(200)
  end

  it 'rotates to .1 past MAX_BYTES and keeps writing to a fresh file' do
    stub_const("#{described_class}::MAX_BYTES", 200)
    10.times { |i| described_class.record(:e, session_name: "s#{i}") }

    expect(File).to exist("#{log}.1")
    expect(lines).not_to be_empty
    all = described_class.read.map { |e| e['session_name'] }
    expect(all).to include('s9')
  end

  describe '.caller_info' do
    it 'names the process, its ppid chain and cwd' do
      info = described_class.caller_info

      expect(info).to include(pid: Process.pid, cwd: Dir.pwd)
      expect(info[:command]).to be_a(String)
      expect(info[:ppid_chain].size).to be <= described_class::PPID_LEVELS
    end

    it 'records the two session ids and no other environment value' do
      saved = ENV.values_at('CLAUDE_CODE_SESSION_ID', 'CODEX_THREAD_ID')
      ENV['CLAUDE_CODE_SESSION_ID'] = 'sess-1'
      ENV['CODEX_THREAD_ID'] = 'thr-2'
      info = described_class.caller_info

      expect(info).to include(claude_code_session_id: 'sess-1', codex_thread_id: 'thr-2')
      expect(info.keys).to match_array(%i[pid command ppid_chain cwd claude_code_session_id codex_thread_id])
    ensure
      ENV['CLAUDE_CODE_SESSION_ID'], ENV['CODEX_THREAD_ID'] = saved
    end

    it 'stays valid JSON when a command line holds non-UTF-8 bytes (LANG=C)' do
      raw = (+"claude \xE2\x80\x94 prompt").force_encoding(Encoding::US_ASCII)
      allow(described_class).to receive(:`).and_return(raw)

      expect { JSON.generate(described_class.caller_info) }.not_to raise_error
    end
  end

  describe '.scrub_command' do
    it 'redacts credentials passed on a command line' do
      out = described_class.scrub_command('curl --token abc123 -H Authorization: Bearer xyz API_KEY=hunter2 sk-abcdefgh12345')

      expect(out).not_to include('abc123', 'xyz', 'hunter2', 'abcdefgh12345')
      expect(out).to include('[REDACTED]')
    end

    it 'truncates a long command line (a parent can be a whole prompt)' do
      out = described_class.scrub_command('x ' * 500)

      expect(out.length).to eq(described_class::COMMAND_MAX + 3)
    end
  end

  describe '.read' do
    it 'filters by session and by time' do
      File.write(log, [
        { ts: (Time.now.utc - 7200).iso8601, event: 'old', session_name: 'a' },
        { ts: Time.now.utc.iso8601, event: 'new', session_name: 'a' },
        { ts: Time.now.utc.iso8601, event: 'other', session_name: 'b' }
      ].map { |e| JSON.generate(e) + "\n" }.join)

      expect(described_class.read(session: 'a').map { |e| e['event'] }).to eq(%w[old new])
      expect(described_class.read(since: described_class.parse_since('1h')).map { |e| e['event'] }).to eq(%w[new other])
    end

    it 'skips lines that are not JSON' do
      File.write(log, "garbage\n#{JSON.generate(ts: Time.now.utc.iso8601, event: 'ok')}\n")

      expect(described_class.read.map { |e| e['event'] }).to eq(['ok'])
    end
  end

  describe '.parse_since' do
    it('reads s/m/h/d') { expect(described_class.parse_since('2h', now: Time.at(10_000))).to eq(Time.at(10_000 - 7200)) }
    it('rejects junk') { expect(described_class.parse_since('soon')).to be_nil }
  end
end
