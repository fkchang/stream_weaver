# frozen_string_literal: true

require "spec_helper"
require "rack/test"

RSpec.describe "named stateless actions" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:generation) { "session-7" }

  def build_app(extra_action: false)
    StreamWeaver::App.new("Actions") do
      action(:select) { |state, key| state[:selected] = key }
      action(:later) { |_state, _key| } if extra_action
      button "Select", action: :select, key: 42
    end
  end

  def rendered_token(app)
    app.rebuild_with_state({}, generation: generation)
    app.components.first.instance_variable_get(:@options).fetch(:action_token)
  end

  def run(app, state, token, manifest: nil, generation: self.generation)
    manifest ||= app.render_state.action_tokens
    described_class = StreamWeaver::InteractionRunner
    described_class.new(
      app: app, state: state, params: {}, interaction: :action, target: token,
      adapter: adapter, persist: ->(_value) {}, action_manifest: manifest,
      generation: generation
    ).call
  end

  it "round-trips a signed token containing action, key, definition digest, and generation" do
    app = build_app
    token = rendered_token(app)

    payload = StreamWeaver::ActionToken.decode(token)
    expect(payload).to include(a: "select", k: 42, d: app.action_definition_digest, g: generation)

    state = {}
    run(app, state, token)
    expect(state[:selected]).to eq(42)
  end

  it "rejects a tampered signature" do
    app = build_app
    token = rendered_token(app)
    tampered = token.sub(/.$/, token.end_with?("A") ? "B" : "A")

    expect { run(app, {}, tampered, manifest: Set[StreamWeaver::ActionToken.fingerprint(tampered)]) }
      .not_to change { app.state[:selected] }
  end

  it "rejects an action absent from the render manifest" do
    app = build_app
    token = rendered_token(app)
    state = {}

    run(app, state, token, manifest: Set.new)
    expect(state).not_to have_key(:selected)
  end

  it "raises stale-definition for a valid manifested token after definitions change" do
    original = build_app
    token = rendered_token(original)
    changed = build_app(extra_action: true)
    changed.rebuild_with_state({}, generation: generation)

    expect { run(changed, {}, token, manifest: original.render_state.action_tokens) }
      .to raise_error(StreamWeaver::StaleActionDefinition)
  end

  it "accepts another worker's token with the same definition, secret, and session generation" do
    previous = ENV["SW_SECRET"]
    ENV["SW_SECRET"] = "shared-worker-secret"
    begin
      StreamWeaver::ActionToken.reset_secret!
      worker_one = build_app
      token = rendered_token(worker_one)
      worker_two = build_app
      worker_two.rebuild_with_state({}, generation: generation)
      state = {}

      run(worker_two, state, token, manifest: worker_one.render_state.action_tokens)
      expect(state[:selected]).to eq(42)
    ensure
      ENV["SW_SECRET"] = previous
      StreamWeaver::ActionToken.reset_secret!
    end
  end

  it "raises when the same name is registered at a different definition site" do
    app = StreamWeaver::App.new("Duplicate") do
      action(:save) { |_state, _key| }
      action(:save) { |_state, _key| }
    end
    expect { app.rebuild_with_state({}) }.to raise_error(ArgumentError, /already registered/)
  end

  it "requires a stable scalar key" do
    missing = StreamWeaver::App.new("Missing") do
      action(:save) { |_state, _key| }
      button "Save", action: :save
    end
    invalid = StreamWeaver::App.new("Invalid") do
      action(:save) { |_state, _key| }
      button "Save", action: :save, key: Object.new
    end

    expect { missing.rebuild_with_state({}) }.to raise_error(ArgumentError, /key: is required/)
    expect { invalid.rebuild_with_state({}) }.to raise_error(ArgumentError, /stable scalar|String, Symbol, or Integer/)
  end

  it "uses one rebuild for named actions and two for legacy blocks" do
    named = build_app
    token = rendered_token(named)
    allow(named).to receive(:rebuild_with_state).and_call_original
    run(named, {}, token)
    expect(named).to have_received(:rebuild_with_state).once

    legacy = StreamWeaver::App.new("Legacy") { button("Go") { |state| state[:went] = true } }
    legacy.rebuild_with_state({})
    legacy_id = legacy.components.first.id
    allow(legacy).to receive(:rebuild_with_state).and_call_original
    run(legacy, {}, legacy_id)
    expect(legacy).to have_received(:rebuild_with_state).twice
  end

  it "does not lose a flash write made via the App#flash accessor inside a named action" do
    app = StreamWeaver::App.new("Flash") do
      action(:trigger) { |_state, _key| flash[:notice] = "Saved!" }
      button "Go", action: :trigger, key: 1
    end
    token = rendered_token(app)
    state = {}

    run(app, state, token)
    expect(state[:_flash]).to eq(notice: "Saved!")
  end

  it "does not lose open_modal/close_modal writes made inside a named action" do
    app = StreamWeaver::App.new("Modal") do
      action(:open) { |_state, _key| open_modal(:confirm) }
      action(:close) { |_state, _key| close_modal(:confirm) }
      button "Open", action: :open, key: 1
      button "Close", action: :close, key: 2
    end

    open_token = rendered_token(app)
    state = { confirm_open: false }
    run(app, state, open_token)
    expect(state[:confirm_open]).to eq(true)

    app.rebuild_with_state(state, generation: generation)
    close_token = app.components.last.instance_variable_get(:@options).fetch(:action_token)
    run(app, state, close_token)
    expect(state[:confirm_open]).to eq(false)
  end

  it "still binds app-level state helpers even when a named action's key argument is unused" do
    app = StreamWeaver::App.new("Toast") do
      action(:notify) { |_state, _key| show_toast("Hi") }
      button "Go", action: :notify, key: 1
    end
    token = rendered_token(app)
    state = {}

    run(app, state, token)
    expect(state[:_toasts]&.map { |t| t[:message] }).to eq(["Hi"])
  end

  it "works inside a table cell using the row key" do
    app = StreamWeaver::App.new("Table") do
      action(:choose) { |state, key| state[:chosen] = key }
      table([{ id: 9, name: "Ada" }], row_key: ->(row) { row[:id] }) do
        column(:name)
        column(:action) { |_row| button("Choose", action: :choose) }
      end
    end
    app.rebuild_with_state({}, generation: generation)
    button = app.find_component_by_key(nil)&.then { nil }
    html = StreamWeaver::Views::AppContentView.new(app, {}, adapter, false).call
    token = html[%r{/action/([^"']+)}, 1]
    state = {}

    run(app, state, token)
    expect(state[:chosen]).to eq(9)
  end
end

RSpec.describe "named actions over HTTP" do
  include Rack::Test::Methods

  let(:definition) do
    StreamWeaver::App.new("HTTP Actions") do
      action(:select) { |state, key| state[:selected] = key }
      button "Select", action: :select, key: 17
      text state[:selected].to_s
    end
  end
  let(:app) { definition.generate }

  it "stores token fingerprints in the manifest and dispatches the rendered token" do
    get "/"
    token = last_response.body[%r{/action/([^"']+)}, 1]

    expect(last_request.session[:sw_action_manifest]).to contain_exactly(StreamWeaver::ActionToken.fingerprint(token))
    expect(last_request.session[:sw_action_manifest].join).not_to include(token)

    env "rack.session", last_request.session.to_h
    post "/action/#{token}"
    expect(last_response).to be_ok
    expect(last_request.session[:streamlit_state][:selected]).to eq(17)
  end

  it "returns 409 and a full-container refresh for a stale definition digest" do
    get "/"
    token = last_response.body[%r{/action/([^"']+)}, 1]
    session = last_request.session.to_h
    definition.action(:deployed_later) { |_state, _key| }

    env "rack.session", session
    post "/action/#{token}"
    expect(last_response.status).to eq(409)
    expect(last_response.headers["HX-Retarget"]).to eq("#app-container")
    expect(last_response.body).to include("Select")
  end
end
