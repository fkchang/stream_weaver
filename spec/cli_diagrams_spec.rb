# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/client'
require 'stream_weaver/iterm'

RSpec.describe StreamWeaver::CLI, '.diagrams' do
  around do |example|
    Dir.mktmpdir('streamweaver-diagram-atlas') do |dir|
      @gem_root = dir
      @atlas = File.join(dir, 'examples', 'stream_weaver', 'gallery.rb')
      FileUtils.mkdir_p(File.dirname(@atlas))
      File.write(@atlas, "# streamweaver-doc: v1\nheader1 'Packaged Diagram Atlas — installed'\n")

      Dir.mktmpdir('outside-source-checkout') do |cwd|
        Dir.chdir(cwd) { example.run }
      end
    end
  end

  before do
    loaded_specs = Gem.loaded_specs.dup
    loaded_specs['slim_graph_r'] = Struct.new(:full_gem_path).new(@gem_root)
    allow(Gem).to receive(:loaded_specs).and_return(loaded_specs)
  end

  it 'dispatches streamweaver diagrams' do
    allow(StreamWeaver::ITerm).to receive(:available?).and_return(false)
    expect(described_class).to receive(:canvas_read).with([@atlas])

    expect { described_class.run(['diagrams']) }.not_to raise_error
  end

  it 'opens and pushes the activated gem copy in a live canvas when the panel is available' do
    allow(StreamWeaver::ITerm).to receive(:available?).and_return(true)
    expect(described_class).to receive(:panel).with(['diagram-atlas', '--layout=wide'])
    expect(StreamWeaver::Canvas::Client).to receive(:send_message) do |message|
      expect(message[:dsl].encoding).to eq(Encoding::UTF_8)
      expect(message).to include(
        type: 'push',
        name: 'diagram-atlas',
        source_dir: nil,
        dsl: include("header1 'Packaged Diagram Atlas — installed'")
      )
      { type: 'push_ok' }
    end

    expect { described_class.diagrams([]) }
      .to output(/Diagram Atlas.*live canvas/i).to_stdout
  end

  it 'uses Canvas Reader as the portable fallback when the panel is unavailable' do
    allow(StreamWeaver::ITerm).to receive(:available?).and_return(false)
    expect(described_class).not_to receive(:panel)
    expect(StreamWeaver::Canvas::Client).not_to receive(:send_message)
    expect(described_class).to receive(:canvas_read).with([@atlas])

    described_class.diagrams([])
  end

  it 'falls back to Canvas Reader when the live push transport fails' do
    allow(StreamWeaver::ITerm).to receive(:available?).and_return(true)
    allow(described_class).to receive(:panel)
    allow(StreamWeaver::Canvas::Client).to receive(:send_message)
      .and_raise(StreamWeaver::Canvas::Client::ConnectionError, 'bridge went away')
    expect(described_class).to receive(:canvas_read).with([@atlas])

    expect { described_class.diagrams([]) }
      .to output(/live canvas unavailable.*Canvas Reader/i).to_stderr
  end

  it 'falls back to Canvas Reader when the bridge rejects the live push' do
    allow(StreamWeaver::ITerm).to receive(:available?).and_return(true)
    allow(described_class).to receive(:panel)
    allow(StreamWeaver::Canvas::Client).to receive(:send_message)
      .and_return(type: 'error', message: 'session disappeared')
    expect(described_class).to receive(:canvas_read).with([@atlas])

    expect { described_class.diagrams([]) }
      .to output(/session disappeared.*Canvas Reader/i).to_stderr
  end

  it 'falls back to Canvas Reader when the live push times out without a response' do
    allow(StreamWeaver::ITerm).to receive(:available?).and_return(true)
    allow(described_class).to receive(:panel)
    allow(StreamWeaver::Canvas::Client).to receive(:send_message).and_return(nil)
    expect(described_class).to receive(:canvas_read).with([@atlas])

    expect { described_class.diagrams([]) }
      .to output(/did not acknowledge.*Canvas Reader/i).to_stderr
  end

  it 'exits with the render error when the live atlas DSL is invalid' do
    allow(StreamWeaver::ITerm).to receive(:available?).and_return(true)
    allow(described_class).to receive(:panel)
    allow(StreamWeaver::Canvas::Client).to receive(:send_message)
      .and_return(type: 'push_error', message: 'unknown diagram type')
    expect(described_class).not_to receive(:canvas_read)

    expect { described_class.diagrams([]) }
      .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      .and output(/Diagram Atlas could not render.*unknown diagram type/i).to_stderr
  end

  it 'fails with the activated gem path and a reinstall hint when the packaged atlas is missing' do
    FileUtils.rm_f(@atlas)
    expect(described_class).not_to receive(:panel)
    expect(described_class).not_to receive(:canvas_read)

    expect { described_class.diagrams([]) }
      .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      .and output(/activated slim_graph_r gem.*examples\/stream_weaver\/gallery\.rb.*reinstall or upgrade/i).to_stderr
  end

  it 'lists the command in top-level help' do
    expect { described_class.help }
      .to output(/streamweaver diagrams.*packaged Diagram Atlas/i).to_stdout
  end
end
