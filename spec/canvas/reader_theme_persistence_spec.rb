# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'rack/test'
require 'stream_weaver/canvas/reader'

# A DSL file instance_eval'd by canvas-push/canvas-read never runs its own
# App.new, so `theme:`/`layout:` kwargs are unreachable in that path. These
# DSL setters are how a doc carries its own look everywhere it's rendered
# (stream_weaver-csf).
RSpec.describe StreamWeaver::App, 'theme/layout DSL setters' do
  subject(:app) { described_class.new('t') }

  it 'use_theme sets the theme the readers already use' do
    app.use_theme(:doc)
    expect(app.theme).to eq(:doc)
  end

  it 'use_theme accepts a string and validates through the same path as App.new' do
    app.use_theme('dark')
    expect(app.theme).to eq(:dark)
  end

  it 'use_theme falls back to :default on an unknown theme (with a warning)' do
    expect { app.use_theme(:nope) }.to output(/Unknown theme/).to_stderr
    expect(app.theme).to eq(:default)
  end

  it 'use_layout sets the layout' do
    app.use_layout(:wide)
    expect(app.layout).to eq(:wide)
  end

  it 'use_layout accepts a string' do
    app.use_layout('fluid')
    expect(app.layout).to eq(:fluid)
  end

  it 'leaves the theme/layout readers intact (views.rb reads them everywhere)' do
    expect(described_class.instance_method(:theme).arity).to eq(0)
    expect(described_class.new('t', theme: :doc, layout: :wide).theme).to eq(:doc)
  end
end

RSpec.describe StreamWeaver::Canvas::Reader, '.render_doc' do
  after { described_class.configure_defaults!(theme: nil, layout: nil) }

  it 'exposes html, theme, layout and inline_stylesheets off the evaluated app' do
    doc = described_class.render_doc(
      "use_theme :doc\nuse_layout :wide\nuse_stylesheet('.x{color:red}')\nheader1 'Hi'"
    )
    expect(doc.html).to include('Hi')
    expect(doc.theme).to eq(:doc)
    expect(doc.layout).to eq(:wide)
    expect(doc.inline_stylesheets).to eq(['.x{color:red}'])
  end

  it 'defaults to :default/:fluid with no declaration and no CLI flag' do
    doc = described_class.render_doc("header1 'Hi'")
    expect(doc.theme).to eq(:default)
    expect(doc.layout).to eq(:fluid)
  end

  it 'falls back to the canvas-read CLI flags when the DSL declares nothing' do
    described_class.configure_defaults!(theme: 'doc', layout: 'wide')
    doc = described_class.render_doc("header1 'Hi'")
    expect(doc.theme).to eq(:doc)
    expect(doc.layout).to eq(:wide)
  end

  it 'lets the DSL win over the CLI flags' do
    described_class.configure_defaults!(theme: 'dark', layout: 'full')
    doc = described_class.render_doc("use_theme :doc\nuse_layout :wide\nheader1 'Hi'")
    expect(doc.theme).to eq(:doc)
    expect(doc.layout).to eq(:wide)
  end

  it 'returns an error Doc rather than raising on a broken DSL' do
    doc = described_class.render_doc('this is not valid !@#')
    expect(doc.html).to include('error')
    expect(doc.theme).to eq(:default)
    expect(doc.inline_stylesheets).to eq([])
  end

  it 'render_dsl stays a thin wrapper returning just the HTML' do
    expect(described_class.render_dsl("header1 'Hi'")).to be_a(String)
    expect(described_class.render_dsl("header1 'Hi'")).to include('Hi')
  end
end

RSpec.describe StreamWeaver::Canvas::Reader, 'theme reaches the rendered page' do
  include Rack::Test::Methods
  def app = described_class

  around do |ex|
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'plain.rb'), "header1 'Plain'")
      File.write(File.join(dir, 'themed.rb'), "use_theme :doc\nuse_layout :wide\nheader1 'Themed'")
      prev = described_class.file_list
      described_class.configure_files!(described_class::FileList.build([dir]))
      begin
        ex.run
      ensure
        described_class.configure_files!(prev)
        described_class.configure_defaults!(theme: nil, layout: nil)
      end
    end
  end

  it 'uses the doc-declared theme/layout in the body class' do
    get '/?file=1'
    expect(last_response.body).to include('<body class="sw-theme-doc sw-layout-wide sw-reader">')
  end

  it 'uses the default theme/layout for a doc that declares none' do
    get '/?file=0'
    expect(last_response.body).to include('<body class="sw-theme-default sw-layout-fluid sw-reader">')
  end

  it 'mirrors the body class onto #app-container so afterSwap can restore it' do
    get '/?file=1'
    expect(last_response.body)
      .to include('data-sw-body-class="sw-theme-doc sw-layout-wide sw-reader"')
  end
end
