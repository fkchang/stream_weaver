# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'rack/test'
require 'tmpdir'
require 'stream_weaver/canvas/bridge_server'

# Named page regions (canvas-annotate-review): the bridge renders a "side"
# region in Ruby from the session's notes and /poll hands it out on its own
# version, separately from the main doc.
RSpec.describe StreamWeaver::Canvas::BridgeServer, 'regions', type: :request do
  include Rack::Test::Methods

  def app = described_class

  let(:bridge) { described_class.bridge }

  around do |ex|
    prev_bridge = described_class.bridge
    prev_conns = described_class.claude_connections
    described_class.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    begin
      ex.run
    ensure
      described_class.bridge = prev_bridge
      described_class.claude_connections = prev_conns
    end
  end

  def post_note(name, text)
    post "/canvas/#{name}/note", { text: text }.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  def poll(name, versions = nil)
    query = versions ? { rv: versions } : {}
    get "/canvas/#{name}/poll", query
    JSON.parse(last_response.body)
  end

  def push(name, dsl)
    bridge.handle_claude_message(type: 'push', name: name, dsl: dsl)
  end

  before { bridge.create_session('plan') }

  it 'renders the side region in Ruby from the notes, with the Send buttons' do
    post_note('plan', 'make this clearer')
    html = poll('plan')['regions']['side']['html']
    expect(html).to include('make this clearer', 'Queued', 'data-sw-action="send"', 'data-sw-action="send-end"')
  end

  it 'poll returns only regions newer than the page copy' do
    first = poll('plan')['regions']['side']['version']
    expect(poll('plan', { side: first })['regions']).to eq({})
    post_note('plan', 'x')
    again = poll('plan', { side: first })['regions']
    expect(again['side']['version']).to be > first
    expect(poll('plan', { side: again['side']['version'] })['regions']).to eq({})
  end

  it 'ignores a malformed versions parameter instead of failing' do
    get '/canvas/plan/poll?rv=junk'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['regions']).to have_key('side')
  end

  it 'a main-doc push leaves the region version and html unchanged' do
    post_note('plan', 'keep me')
    before_region = bridge.get_session('plan').region('side')
    expect(push('plan', 'text "hello"')[:type]).to eq('push_ok')
    expect(bridge.get_session('plan').region('side')).to eq(before_region)
    expect(poll('plan')['html']).to include('hello')
  end

  it 'a region update leaves the main doc html and version unchanged' do
    push('plan', 'text "hello"')
    session = bridge.get_session('plan')
    html, version = session.html, session.html_version
    post_note('plan', 'a comment')
    expect([session.html, session.html_version]).to eq([html, version])
  end

  it 'puts the region element outside #app-container, composer-free, and seeds it from stored state' do
    post_note('plan', 'draft survives')
    get '/canvas/plan'
    page = last_response.body
    expect(page).to match(%r{</div>\s*<!--[^>]*-->\s*<aside data-sw-region="side">.*draft survives.*</aside>}m)
    region = page[%r{<aside data-sw-region="side">.*?</aside>}m]
    expect(region).not_to include('<textarea')
    container = page[/<div id="app-container".*?<aside data-sw-region/m]
    expect(container).not_to include('draft survives')
  end

  it 'escapes viewer text and the session name in the region' do
    bridge.create_session('a"b')
    bridge.get_session('a"b').add_note(text: '<script>alert(1)</script>')
    html = bridge.get_session('a"b').region('side')[:html]
    expect(html).not_to include('<script>')
    expect(html).to include('&lt;script&gt;')
  end

  it 'keeps region markup out of the saved doc and canvas exports' do
    post_note('plan', 'comment')
    push('plan', 'text "hello"')
    session = bridge.get_session('plan')
    expect(session.dsl).not_to include('data-sw-region')
    # save-doc writes a real file: point the doc store at a tmpdir so the spec
    # never leaves a doc in the repo or the home store.
    Dir.mktmpdir do |dir|
      prev = ENV['STREAMWEAVER_DOC_ROOT']
      ENV['STREAMWEAVER_DOC_ROOT'] = dir
      begin
        post '/canvas/plan/save-doc', { name: 'x' }.to_json, 'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq(200)
        expect(last_response.body).not_to include('data-sw-region')
        expect(Dir[File.join(dir, '**/x.rb')]).not_to be_empty
        expect(File.read(Dir[File.join(dir, '**/x.rb')].first)).not_to include('data-sw-region')
      ensure
        ENV['STREAMWEAVER_DOC_ROOT'] = prev
      end
    end
    expect(bridge.handle_claude_message(type: 'get_dsl', name: 'plan').to_json).not_to include('data-sw-region')
  end

  it 'the Reader and exporter have no region mechanism' do
    lib = File.expand_path('../../lib/stream_weaver', __dir__)
    offenders = Dir[File.join(lib, '**/*.{rb,erb}')].select { |f| File.read(f).include?('data-sw-region') }
    expect(offenders.map { |f| File.basename(f) }).to contain_exactly('bridge_server.rb')
  end
end
