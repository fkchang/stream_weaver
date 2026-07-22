# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'stream_weaver/canvas/bridge_server'

RSpec.describe 'Canvas inline stylesheets (stream_weaver-9uk)' do
  describe StreamWeaver::App do
    it 'inlines literal CSS text passed to use_stylesheet' do
      app = described_class.new('t') { use_stylesheet(".sw-x { color: red; }") }
      app.rebuild_with_state({})
      expect(app.inline_stylesheets).to eq([".sw-x { color: red; }"])
    end

    it 'reads a local file path relative to the script directory' do
      Dir.mktmpdir do |dir|
        css_path = File.join(dir, 'x.css')
        File.write(css_path, '.sw-y { color: blue; }')
        app = described_class.new('t', assets_dirs: [dir]) { use_stylesheet(css_path) }
        app.rebuild_with_state({})
        expect(app.inline_stylesheets).to eq(['.sw-y { color: blue; }'])
      end
    end

    it 'dedupes identical CSS content within one app' do
      app = described_class.new('t') do
        use_stylesheet(".sw-x { color: red; }")
        use_stylesheet(".sw-x { color: red; }")
      end
      app.rebuild_with_state({})
      expect(app.inline_stylesheets).to eq([".sw-x { color: red; }"])
    end
  end

  describe StreamWeaver::Canvas::Session do
    it 'starts with no stylesheets and replaces (not accumulates) on set_stylesheets' do
      session = described_class.new('x')
      expect(session.stylesheets).to eq([])

      session.set_stylesheets(['.a {}'])
      expect(session.stylesheets).to eq(['.a {}'])

      session.set_stylesheets(['.b {}'])
      expect(session.stylesheets).to eq(['.b {}'])
    end

    it 'dedupes on set_stylesheets' do
      session = described_class.new('x')
      session.set_stylesheets(['.a {}', '.a {}'])
      expect(session.stylesheets).to eq(['.a {}'])
    end

    it 'clears stylesheets on reset!' do
      session = described_class.new('x')
      session.set_stylesheets(['.a {}'])
      session.reset!
      expect(session.stylesheets).to eq([])
    end
  end

  describe StreamWeaver::Canvas::Bridge do
    let(:bridge) { described_class.new(port: 0) }

    it 'carries use_stylesheet CSS from a push into the session' do
      bridge.create_session('x')
      bridge.handle_claude_message(
        type: 'push', name: 'x',
        dsl: "use_stylesheet('.sw-bespoke { color: hotpink; }')\nheader1 'Hi'"
      )
      expect(bridge.get_session('x').stylesheets).to eq(['.sw-bespoke { color: hotpink; }'])
    end

    it 'does not clobber the last-good stylesheet when a later push fails to render' do
      bridge.create_session('x')
      bridge.handle_claude_message(
        type: 'push', name: 'x',
        dsl: "use_stylesheet('.sw-good { color: green; }')\nheader1 'Hi'"
      )
      bridge.handle_claude_message(type: 'push', name: 'x', dsl: "raise 'boom'")
      expect(bridge.get_session('x').stylesheets).to eq(['.sw-good { color: green; }'])
    end
  end

  describe 'GET /canvas/:name', type: :request do
    include Rack::Test::Methods

    def app
      StreamWeaver::Canvas::BridgeServer
    end

    around do |ex|
      prev_bridge = StreamWeaver::Canvas::BridgeServer.bridge
      StreamWeaver::Canvas::BridgeServer.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      ex.run
    ensure
      StreamWeaver::Canvas::BridgeServer.bridge = prev_bridge
    end

    it 'inlines the pushed stylesheet into the canvas head as a <style> block' do
      StreamWeaver::Canvas::BridgeServer.bridge.create_session('styled')
      StreamWeaver::Canvas::BridgeServer.bridge.handle_claude_message(
        type: 'push', name: 'styled',
        dsl: "use_stylesheet('.sw-bespoke-card { border: 4px solid hotpink; }')\nheader1 'Bespoke'"
      )
      get '/canvas/styled'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('<style>.sw-bespoke-card { border: 4px solid hotpink; }</style>')
    end

    it 're-pushing the same DSL does not stack duplicate <style> tags' do
      dsl = "use_stylesheet('.sw-bespoke-card { border: 4px solid hotpink; }')\nheader1 'Bespoke'"
      StreamWeaver::Canvas::BridgeServer.bridge.create_session('styled2')
      StreamWeaver::Canvas::BridgeServer.bridge.handle_claude_message(type: 'push', name: 'styled2', dsl: dsl)
      StreamWeaver::Canvas::BridgeServer.bridge.handle_claude_message(type: 'push', name: 'styled2', dsl: dsl)
      get '/canvas/styled2'
      expect(last_response.body.scan('.sw-bespoke-card').size).to eq(1)
    end

    it 'has no bespoke <style> block for a canvas session with no use_stylesheet calls (regression guard)' do
      StreamWeaver::Canvas::BridgeServer.bridge.create_session('plain')
      StreamWeaver::Canvas::BridgeServer.bridge.handle_claude_message(type: 'push', name: 'plain', dsl: "header1 'Plain'")
      get '/canvas/plain'
      expect(last_response.body).not_to include('sw-bespoke')
    end
  end

  describe 'the design-review shared-DSL as a real bespoke-CSS case (read-only fixture use)' do
    include Rack::Test::Methods

    def app
      StreamWeaver::Canvas::BridgeServer
    end

    around do |ex|
      prev_bridge = StreamWeaver::Canvas::BridgeServer.bridge
      StreamWeaver::Canvas::BridgeServer.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      ex.run
    ensure
      StreamWeaver::Canvas::BridgeServer.bridge = prev_bridge
    end

    it 'renders the design-review example bespoke CSS on canvas without editing the example files' do
      examples_dir = File.expand_path('../../lib/stream_weaver/skills/streamweaver-visual-companion/examples', __dir__)
      css_path = File.join(examples_dir, 'design-review-example.css')
      dsl_path = File.join(examples_dir, 'design-review-example_dsl.rb')

      css = File.read(css_path)
      dsl = File.read(dsl_path)
      pushed_dsl = "use_stylesheet(#{css.inspect})\ntheme_toggle mode: :auto\n#{dsl}"

      StreamWeaver::Canvas::BridgeServer.bridge.create_session('design-review', theme: :doc)
      response = StreamWeaver::Canvas::BridgeServer.bridge.handle_claude_message(
        type: 'push', name: 'design-review', dsl: pushed_dsl
      )
      expect(response[:type]).to eq('push_ok')

      get '/canvas/design-review'
      expect(last_response.status).to eq(200)
      # A selector pulled straight from the real design-review-example.css --
      # if this is present, the bespoke stylesheet made it into the canvas head.
      expect(css).to include('.ad-doc .sw-doc-header__title')
      expect(last_response.body).to include('.ad-doc .sw-doc-header__title')
    end
  end
end
