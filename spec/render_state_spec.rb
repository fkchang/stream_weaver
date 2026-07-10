# frozen_string_literal: true

RSpec.describe StreamWeaver::App::RenderState do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

  it "is replaced, rather than cleared in place, on every rebuild" do
    app = StreamWeaver::App.new("Render state") do
      layout_slot(:sidebar) { text "Sidebar" }
      form(:profile) { text_field :name }
      button("Save", submit: false)
    end

    initial_render_state = app.render_state
    app.rebuild_with_state({})
    first_render_state = app.render_state
    app.rebuild_with_state({})
    second_render_state = app.render_state

    expect([first_render_state, second_render_state]).not_to include(initial_render_state)
    expect(second_render_state).not_to equal(first_render_state)
    expect(second_render_state.components).not_to equal(first_render_state.components)
    expect(second_render_state.layout_slots).not_to equal(first_render_state.layout_slots)
    expect(second_render_state.current_form).to be_nil
    expect(second_render_state.form_context).to be_nil
  end

  it "leaves app-definition data intact across fresh render states" do
    parser = ->(path) { path == "/reports" ? { page: :reports } : nil }
    builder = ->(state) { "/reports" if state[:page] == :reports }
    store = Class.new do
      class << self
        def all = []
        def find(_id) = nil
        def create(_attributes) = nil
        def update(_id, _attributes) = nil
        def destroy(_id) = nil
      end
    end
    endpoint_handler = ->(_request) { "ok" }
    app = StreamWeaver::App.new("Definitions") do
      route_with parser: parser, builder: builder
      resource :report, store: store
      endpoint :get, "/health", &endpoint_handler
    end

    app.rebuild_with_state({})
    definitions = [app.route_rules, app.resource_defs, app.endpoints].map(&:object_id)
    app.rebuild_with_state({})

    expect([app.route_rules, app.resource_defs, app.endpoints].map(&:object_id)).to eq(definitions)
    expect(app.state_for_path("/reports")).to eq(page: :reports)
    expect(app.resource_defs).to have_key(:report)
    expect(app.find_endpoint(:get, "/health")[:block]).to equal(endpoint_handler)
  end

  it "serializes each interaction's rebuild-callback-rebuild-render span" do
    app = StreamWeaver::App.new("Concurrent interactions") do
      request_id = state.fetch(:request_id)
      sleep(0.0005)
      text "before-#{request_id}"
      button("Execute") { |current_state| current_state[:result] = "result-#{current_state.fetch(:request_id)}" }
      text state[:result].to_s
      text "after-#{state.fetch(:request_id)}"
    end

    run_interaction = lambda do |request_id|
      state = { request_id: request_id }
      app.with_render_lock do
        app.rebuild_with_state(state)
        button = app.components.find { |component| component.is_a?(StreamWeaver::Components::Button) }
        Thread.pass
        button.execute(state)
        app.rebuild_with_state(state)
        StreamWeaver::Views::AppContentView.new(app, state, adapter, false).call
      end
    end

    50.times do |round|
      request_ids = ["#{round}-left", "#{round}-right"]
      rendered = request_ids.map { |request_id| Thread.new { run_interaction.call(request_id) } }.map(&:value)

      rendered.zip(request_ids, request_ids.reverse_each).each do |html, own_id, other_id|
        expect(html).to include("before-#{own_id}", "result-#{own_id}", "after-#{own_id}")
        expect(html).not_to include("before-#{other_id}", "result-#{other_id}", "after-#{other_id}")
      end
    end
  end
end
