# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/canvas/bridge'

RSpec.describe StreamWeaver::CLI, '.canvas_annotate' do
  def capture_io
    old_out, old_err = $stdout, $stderr
    $stdout, $stderr = StringIO.new, StringIO.new
    yield
    [$stdout.string, $stderr.string]
  rescue SystemExit
    [$stdout.string, $stderr.string]
  ensure
    $stdout, $stderr = old_out, old_err
  end

  let(:bridge) { StreamWeaver::Canvas::Bridge.new(port: 0) }
  let(:tmp) { Dir.mktmpdir }

  around do |ex|
    env = ENV.to_h.slice('STREAMWEAVER_HISTORY_ROOT', 'SW_NO_OPEN')
    ENV['STREAMWEAVER_HISTORY_ROOT'] = File.join(tmp, 'history')
    ENV['SW_NO_OPEN'] = '1'
    ex.run
  ensure
    %w[STREAMWEAVER_HISTORY_ROOT SW_NO_OPEN].each { |k| env.key?(k) ? ENV[k] = env[k] : ENV.delete(k) }
    FileUtils.remove_entry(tmp)
  end

  before do
    allow(StreamWeaver::Canvas::Client).to receive(:ensure_bridge_running).and_return({})
    allow(StreamWeaver::Canvas::Client).to receive(:send_message) { |msg| bridge.handle_claude_message(msg) }
  end

  it 'pushes a file, turns annotate on and prints the background wait command' do
    path = File.join(tmp, 'plan.rb')
    File.write(path, "header1 'Plan'\n")
    out, = capture_io { described_class.canvas_annotate([path]) }

    expect(bridge.get_session('plan')).to be_annotate
    expect(bridge.get_session('plan').html).to include('Plan')
    expect(out).to include('streamweaver canvas-notes plan --wait-submit').and include('BACKGROUND')
    expect(out).to include('canvas-notes reply plan')
  end

  it 'uses a named canvas as is' do
    bridge.create_session('demo')
    out, = capture_io { described_class.canvas_annotate(['demo']) }
    expect(bridge.get_session('demo')).to be_annotate
    expect(out).to include('canvas-notes demo --wait-submit')
  end

  it 'with no argument uses the only live canvas' do
    bridge.create_session('solo')
    capture_io { described_class.canvas_annotate([]) }
    expect(bridge.get_session('solo')).to be_annotate
  end

  it 'with no argument and several canvases lists them and exits without changing any' do
    %w[a b].each { |n| bridge.create_session(n) }
    _, err = capture_io { described_class.canvas_annotate([]) }
    expect(err).to include('Several live canvases').and include('  a').and include('  b')
    expect(%w[a b].map { |n| bridge.get_session(n).annotate? }).to eq([false, false])
  end

  it 'with no argument and no canvas says so' do
    _, err = capture_io { described_class.canvas_annotate([]) }
    expect(err).to include('No live canvas')
  end

  it 'does not turn annotate on when the file fails to render' do
    path = File.join(tmp, 'bad.rb')
    File.write(path, "raise 'boom'\n")
    _, err = capture_io { described_class.canvas_annotate([path]) }
    expect(err).to include('DSL Error')
    expect(bridge.get_session('bad')).not_to be_annotate
  end
end

RSpec.describe 'sw-annotate skill' do
  let(:skill) { File.read(File.join(__dir__, '../lib/stream_weaver/skills/sw-annotate/SKILL.md')) }

  it 'has frontmatter and teaches the whole loop in a short file' do
    expect(skill).to start_with("---\nname: sw-annotate\n")
    expect(skill.lines.size).to be <= 50
    %w[canvas-annotate --wait-submit run_in_background canvas-push reply].each { |w| expect(skill).to include(w) }
    expect(skill).to include('THIS doc').and include('Proc-generated').and include('ended the review')
  end

  it 'is installed by install-skill' do
    expect(File.read(File.join(__dir__, '../lib/stream_weaver/cli.rb'))).to include("'sw-annotate' =>")
  end
end
