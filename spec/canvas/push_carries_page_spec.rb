# frozen_string_literal: true

require_relative '../support/body_class_helper'
require 'spec_helper'
require 'json'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/reader'

# disc-127: a canvas push carries its resolved page (theme, layout, body
# class, head assets), so a plain session renders a pushed `use_theme`
# without being created with that theme, and the open page picks it up
# from the poll without a reload.
RSpec.describe 'A canvas push carries its page', type: :request do
  include Rack::Test::Methods

  IDE_BODY = <<~RUBY
    use_theme :ide
    theme_tokens color_primary: '#a21caf'
    header1 'Themed'
  RUBY

  def app
    StreamWeaver::Canvas::BridgeServer
  end

  def bridge
    StreamWeaver::Canvas::BridgeServer.bridge
  end

  def push(dsl, name: 's1')
    bridge.handle_claude_message(type: 'push', name: name, dsl: dsl)
  end

  def poll(name = 's1')
    get "/canvas/#{name}/poll"
    JSON.parse(last_response.body)
  end

  around do |ex|
    previous = StreamWeaver::Canvas::BridgeServer.bridge
    StreamWeaver::Canvas::BridgeServer.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    ex.run
  ensure
    StreamWeaver::Canvas::BridgeServer.bridge = previous
  end

  before { bridge.create_session('s1') }

  it "renders a pushed use_theme on a plain default session's page" do
    push(IDE_BODY)
    get '/canvas/s1'
    expect(body_classes(last_response.body)).to match_array(%w[sw-layout-fluid sw-theme-ide])
    expect(last_response.body).to include('JetBrains+Mono')
  end

  it 'keeps the create-time theme for a body that declares none' do
    push("header1 'Plain'")
    expect(poll.dig('page', 'body_class').split).to match_array(%w[sw-layout-fluid sw-theme-default])
  end

  it 'honours a pushed use_layout' do
    push("use_layout :wide\nheader1 'Wide'")
    expect(poll.dig('page', 'body_class').split).to include('sw-layout-wide')
  end

  it "polls the pushed page: body class, the theme's head assets and the push CSS" do
    push(IDE_BODY)
    page = poll['page']
    expect(page['body_class'].split).to match_array(%w[sw-layout-fluid sw-theme-ide])
    expect(page['assets'].map { |a| a['html'] }.join).to include('JetBrains+Mono', 'geist')
    expect(page['push_css'].join).to include('#a21caf')
  end

  it 'keys each asset by its tag, so the same tag always has the same key' do
    push(IDE_BODY)
    first = poll.dig('page', 'assets')
    push("#{IDE_BODY}\ntext 'again'")
    second = poll.dig('page', 'assets')
    expect(first).to eq(second)
    expect(first.map { |a| a['key'] }.uniq.size).to eq(first.size)
  end

  it "tells the open page which asset keys its head already has, so a push never re-appends them" do
    get '/canvas/s1'
    initial_keys = last_response.body[/const pageAssets = new Set\((\[.*?\])\)/, 1]
    expect(initial_keys).not_to be_nil
    push("header1 'Plain'")
    expect(JSON.parse(initial_keys)).to match_array(poll.dig('page', 'assets').map { |a| a['key'] })
  end

  it 'marks the push CSS on the page so the next push replaces it instead of stacking it' do
    push(IDE_BODY)
    get '/canvas/s1'
    expect(last_response.body).to match(/<style data-sw-push-css>[^<]*#a21caf/)
  end

  describe 'a push that fails to evaluate' do
    before { push(IDE_BODY) }

    it 'leaves the previous page untouched: content, version, body class and assets' do
      before_poll = poll
      result = push("use_theme :doc\nraise 'boom'")
      expect(result[:type]).to eq('push_error')
      after_poll = poll
      expect(after_poll.values_at('html', 'version', 'page')).to eq(before_poll.values_at('html', 'version', 'page'))
      get '/canvas/s1'
      expect(body_classes(last_response.body)).to include('sw-theme-ide')
    end

    it 'leaves a never-pushed session waiting' do
      bridge.create_session('fresh')
      push("raise 'boom'", name: 'fresh')
      expect(poll('fresh')['html']).to be_nil
      expect(poll('fresh')['version']).to eq(0)
    end
  end

  it 'keeps two sessions apart' do
    bridge.create_session('s2')
    push(IDE_BODY)
    push("header1 'Other'", name: 's2')
    expect(poll('s2').dig('page', 'body_class').split).to include('sw-theme-default')
    expect(poll('s1').dig('page', 'body_class').split).to include('sw-theme-ide')
  end

  it 'forgets the pushed page on reset' do
    push(IDE_BODY)
    bridge.handle_claude_message(type: 'reset', name: 's1')
    expect(poll.dig('page', 'body_class').split).to include('sw-theme-default')
  end

  describe 'agreement with canvas-read' do
    [
      IDE_BODY,
      "header1 'Plain'",
      "use_theme :doc\nuse_layout :wide\nuse_stylesheet '.x { color: red; }'\nheader1 'Doc'"
    ].each do |body|
      it "resolves the same page for #{body.lines.first.strip.inspect}" do
        push(body)
        canvas = bridge.get_session('s1').page
        reader = StreamWeaver::Canvas::Reader.page_for(StreamWeaver::Canvas::Reader.render_doc(body))
        reader_assets = reader.assets.with(body_classes: reader.assets.body_classes - %w[sw-reader])
        expect([canvas.theme, canvas.layout]).to eq([reader.theme, reader.layout])
        expect(canvas.assets).to eq(reader_assets)
      end
    end
  end
end
