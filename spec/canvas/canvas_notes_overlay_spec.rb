# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tmpdir'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'

# Server-provable half of the comment overlay: where it is mounted and that it
# never leaks into content. The interactive behavior needs a real browser.
RSpec.describe StreamWeaver::Canvas::BridgeServer, 'comment overlay', type: :request do
  include Rack::Test::Methods

  def app = described_class

  let(:js_path) { File.expand_path('../../lib/stream_weaver/assets/js/sw-canvas-notes.js', __dir__) }

  around do |ex|
    prev = described_class.bridge
    described_class.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    begin
      ex.run
    ensure
      described_class.bridge = prev
    end
  end

  before do
    described_class.bridge.create_session('plan')
    described_class.bridge.handle_claude_message(type: 'push', name: 'plan', dsl: "header1 'Hi'\nbutton 'Go'")
  end

  it 'mounts the overlay script after #app-container closes, not inside it' do
    get '/canvas/plan'
    page = last_response.body
    start = page.index('<div id="app-container"') || page.index("<div id='app-container'") || page.index('id="app-container"')
    expect(start).not_to be_nil
    marker = page.index('__swCanvasNotes')
    expect(marker).not_to be_nil
    widget = page.index('Save this canvas as a persistent doc')
    expect(marker).to be > widget
    expect(page.scan('window.__swCanvasNotes = true').size).to eq(1)
  end

  it 'keeps the overlay out of the polled content that replaces #app-container' do
    get '/canvas/plan/poll'
    expect(JSON.parse(last_response.body)['html'].to_s).not_to include('swCanvasNotes')
    expect(JSON.parse(last_response.body)['html'].to_s).not_to include('sw-notes')
  end

  it 'is referenced only by the live canvas page, not by export, canvas-read or save-doc code' do
    users = Dir[File.expand_path('../../lib/**/*.rb', __dir__)].select { |f| File.read(f).include?('sw-canvas-notes') }
    expect(users.map { |f| File.basename(f) }).to eq(['bridge_server.rb'])
  end

  it 'posts to a relative note URL (no session name interpolated into the script)' do
    src = File.read(js_path)
    expect(src).to include("'/note'")
    expect(src).not_to include('#{')
    expect(src).not_to include('</script')
  end

  it 'does not put the Save-as-doc DSL through the overlay: saved doc has no overlay markup' do
    Dir.mktmpdir do |d|
      prev = ENV['STREAMWEAVER_DOC_ROOT']
      ENV['STREAMWEAVER_DOC_ROOT'] = d
      post '/canvas/plan/save-doc', { name: 'x', scope: 'global' }.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response.status).to eq(200), last_response.body
      saved = File.read(JSON.parse(last_response.body)['path'])
      expect(saved).not_to be_empty
      expect(saved).not_to include('swCanvasNotes')
    ensure
      ENV['STREAMWEAVER_DOC_ROOT'] = prev
    end
  end
end
