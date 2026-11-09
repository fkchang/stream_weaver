# frozen_string_literal: true

require_relative '../support/body_class_helper'
require_relative '../support/node_js'
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
    let(:session) { bridge.get_session('s1') }
    let(:sent) { [] }

    before do
      bridge.handle_claude_message(type: 'push', name: 's1', dsl: IDE_BODY, source_dir: '/repo/one')
      session.add_note(text: 'a comment', target: 'h1')
      session.send_queued
      session.drain_notes # the agent has read it: 'seen', which a push would move to 'working'
      socket = Object.new
      socket.define_singleton_method(:send) { |message| sent << message }
      session.add_websocket(socket)
    end

    it 'leaves the previous page untouched: content, version, body class and assets' do
      before_poll = poll
      result = push("use_theme :doc\nraise 'boom'")
      expect(result[:type]).to eq('push_error')
      after_poll = poll
      expect(after_poll.values_at('html', 'version', 'page')).to eq(before_poll.values_at('html', 'version', 'page'))
      get '/canvas/s1'
      expect(body_classes(last_response.body)).to include('sw-theme-ide')
    end

    it 'keeps the DSL, source_dir, theme and layout, leaves the notes alone and broadcasts nothing' do
      notes = session.notes_snapshot
      push("use_theme :doc\nuse_layout :wide\nraise 'boom'")
      expect([session.dsl, session.source_dir]).to eq([IDE_BODY, '/repo/one'])
      expect([session.current_theme, session.current_layout]).to eq(%i[ide fluid])
      expect(session.notes_snapshot).to eq(notes)
      expect(sent).to be_empty
    end

    it 'answers push_error for a body that recurses without end, instead of killing the socket thread' do
      expect(push("def deep = deep\ndeep")[:type]).to eq('push_error')
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

  it 'reports the theme and layout on show, as the list and save-doc see them' do
    push("use_theme :ide\nuse_layout :wide\nheader1 'Themed'")
    expect(bridge.list_sessions.first).to include(theme: :ide, layout: :wide)
  end

  describe 'poll payload' do
    it 'leaves the page out when the client already has this version' do
      push(IDE_BODY)
      version = poll['version']
      get "/canvas/s1/poll?v=#{version}"
      expect(JSON.parse(last_response.body)).not_to have_key('page')
      get "/canvas/s1/poll?v=#{version - 1}"
      expect(JSON.parse(last_response.body)).to have_key('page')
    end

    it 'reads html, version and page as one snapshot of the session' do
      push(IDE_BODY)
      snapshot = bridge.get_session('s1').snapshot
      expect(snapshot.keys).to eq(%i[html version page])
      expect(snapshot[:page].body_class).to include('sw-theme-ide')
    end
  end

  describe 'head order: the push CSS is last, live and after a reload' do
    include NodeJS

    HEAD_TAG = %r{<!--.*?-->|<(style|script|title)\b[^>]*>.*?</\1>|<(?:link|meta)\b[^>]*>}m

    def head_tags(html)
      html[%r{<head>(.*?)</head>}m, 1].to_enum(:scan, HEAD_TAG).map { Regexp.last_match(0) }
    end

    # The poll script's applyPage (sw-canvas-page.js) against a head made
    # of `tags`, with a document shim just big enough for it.
    def apply_page_in_node(tags, page)
      shim = <<~JS
        const items = #{tags.to_json}.map(html => ({ html }));
        const classes = new Set(['sw-layout-fluid', 'sw-theme-default', 'sw-annotate-on']);
        function pushStyle() {
          const el = { textContent: '', setAttribute() {}, remove() { items.splice(items.indexOf(el), 1); } };
          Object.defineProperty(el, 'html', { get: () => '<style data-sw-push-css>' + el.textContent + '</style>' });
          return el;
        }
        global.window = global;
        global.document = {
          body: {
            get className() { return [...classes].join(' '); },
            set className(v) { classes.clear(); v.split(' ').forEach(c => classes.add(c)); },
            classList: { contains: c => classes.has(c), toggle: (c, on) => on ? classes.add(c) : classes.delete(c) }
          },
          head: {
            insertAdjacentHTML(_where, html) { items.push({ html }); },
            appendChild(el) { items.push(el); },
            querySelectorAll() {
              return items.filter(i => i.html.startsWith('<style data-sw-push-css>'))
                          .map(i => ({ remove() { items.splice(items.indexOf(i), 1); } }));
            }
          },
          createElement: pushStyle
        };
      JS
      driver = <<~JS
        swApplyPage(#{page.to_json}, new Set());
        console.log(JSON.stringify({ head: items.map(i => i.html), bodyClass: document.body.className }));
      JS
      js = File.read(File.expand_path('../../lib/stream_weaver/assets/js/sw-canvas-page.js', __dir__))
      run_node_json(shim, js, driver)
    end

    it 'puts the push CSS last in <head>, after highlight.js and the chart CSS, on a fresh render' do
      push(IDE_BODY)
      get '/canvas/s1'
      tags = head_tags(last_response.body)
      expect(tags.last).to start_with('<style data-sw-push-css>')
      highlight = tags.index { |t| t.start_with?('<link') && t.include?('highlightjs') }
      chart_css = tags.index { |t| t == "<style>#{StreamWeaver::Adapter::AlpineJS::CHART_CSS}</style>" }
      font = tags.index { |t| t.start_with?('<link') && t.include?('JetBrains') }
      expect([highlight, chart_css].max).to be < font
    end

    it 'builds the same head live (a plain page, then applyPage) as a reload of the pushed page' do
      get '/canvas/s1'
      plain_head = head_tags(last_response.body)
      push(IDE_BODY)
      live = apply_page_in_node(plain_head, poll['page'])
      get '/canvas/s1'
      expect(live['head']).to eq(head_tags(last_response.body))
      expect(live['head'].last).to start_with('<style data-sw-push-css>')
      expect(live['bodyClass'].split).to match_array(%w[sw-layout-fluid sw-theme-ide sw-annotate-on])
    end
  end

  describe 'Bridge#render and Reader.render_doc agree on the page' do
    [
      IDE_BODY,
      "header1 'Plain'",
      "use_theme :doc\nuse_layout :wide\nuse_stylesheet '.x { color: red; }'\nheader1 'Doc'"
    ].each do |body|
      it "resolves the same theme, layout and assets for #{body.lines.first.strip.inspect}" do
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
