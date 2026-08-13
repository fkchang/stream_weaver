# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'base64'
require 'stream_weaver/cli'
require 'stream_weaver/export/html_exporter'

# `streamweaver export <file.rb> [-o out.html] [--inline-images]`
# (stream_weaver-65z).
RSpec.describe StreamWeaver::CLI, '.export_html' do
  around do |ex|
    Dir.mktmpdir do |dir|
      @dir = dir
      Dir.chdir(dir) { ex.run }
    end
  end

  let(:doc) do
    File.join(@dir, 'my doc.rb').tap do |path|
      File.write(path, "header1 'Exported Doc'\ntext 'Paragraph.'")
    end
  end

  it 'writes the doc to the given output path' do
    out = File.join(@dir, 'out.html')
    expect { described_class.export_html([doc, '-o', out]) }
      .to output(/Exported/).to_stdout

    expect(File.read(out)).to include('Exported Doc')
    expect(File.read(out)).to include('Paragraph.')
  end

  it 'accepts --output=PATH as well as -o PATH' do
    out = File.join(@dir, 'other.html')
    expect { described_class.export_html([doc, "--output=#{out}"]) }.to output(/Exported/).to_stdout

    expect(File.exist?(out)).to be true
  end

  it 'defaults the output name to the sanitized doc name in the working directory' do
    expect { described_class.export_html([doc]) }.to output(/Exported/).to_stdout

    expect(File.exist?(File.join(@dir, 'my-doc.html'))).to be true
  end

  it 'embeds local images with --inline-images, resolved from the doc directory' do
    File.binwrite(
      File.join(@dir, 'pic.png'),
      Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==')
    )
    File.write(File.join(@dir, 'pic-doc.rb'), %(image_block "pic.png", alt: "p"))
    out = File.join(@dir, 'pic.html')

    Dir.chdir('/') do
      expect { described_class.export_html([File.join(@dir, 'pic-doc.rb'), '-o', out, '--inline-images']) }
        .to output(/Exported/).to_stdout
    end

    expect(File.read(out)).to include('data:image/png;base64,')
  end

  it 'exits 1 with usage when the file is missing' do
    expect { described_class.export_html([File.join(@dir, 'nope.rb')]) }
      .to raise_error(SystemExit)
      .and output(/Usage: streamweaver export/).to_stderr
  end

  it 'exits 1 with a clear message when handed a full app file' do
    full = File.join(@dir, 'full.rb')
    File.write(full, "app = StreamWeaver::App.new('X')\napp.run!")

    expect { described_class.export_html([full]) }
      .to raise_error(SystemExit)
      .and output(/canvas-doc DSL fragment/).to_stderr
  end

  # --offline (stream_weaver-dnq): inlines mermaid's library instead of
  # referencing its CDN, for viewers whose CSP blocks external scripts
  # entirely. Stubs the network fetch -- these specs are about the flag
  # being wired through, not about actually reaching jsdelivr.
  describe '--offline' do
    let(:mermaid_doc) do
      File.join(@dir, 'diagram.rb').tap do |path|
        File.write(path, %(mermaid "graph TD; A-->B;"))
      end
    end

    it 'inlines mermaid instead of referencing its CDN' do
      allow_any_instance_of(StreamWeaver::Export::HtmlExporter)
        .to receive(:fetch_url).and_return("/* stubbed mermaid global */")
      out = File.join(@dir, 'diagram.html')

      expect { described_class.export_html([mermaid_doc, '-o', out, '--offline']) }
        .to output(/Exported/).to_stdout

      html = File.read(out)
      expect(html).to include("/* stubbed mermaid global */")
      expect(html).not_to match(%r{<script[^>]*mermaid\.esm})
    end

    it 'exits 1 with a clear message when the fetch fails' do
      allow_any_instance_of(StreamWeaver::Export::HtmlExporter)
        .to receive(:fetch_url).and_raise(Timeout::Error, "execution expired")
      out = File.join(@dir, 'diagram.html')

      expect { described_class.export_html([mermaid_doc, '-o', out, '--offline']) }
        .to raise_error(SystemExit)
        .and output(/offline export couldn.t fetch mermaid/).to_stderr
    end
  end
end
