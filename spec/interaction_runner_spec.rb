# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamWeaver::InteractionRunner do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:persisted) { [] }
  let(:persist) { ->(state) { persisted << state.dup } }

  def run(app, state, interaction, params: {}, target: nil)
    described_class.new(
      app: app,
      state: state,
      params: params,
      interaction: interaction,
      target: target,
      adapter: adapter,
      persist: persist
    ).call
  end

  it "syncs request parameters before the post-interaction rebuild" do
    app = StreamWeaver::App.new("Sync") { text "Name: #{state[:name]}" }
    app.rebuild_with_state({})
    state = {}

    response = run(app, state, :update, params: { "name" => "Alice" })

    expect(state[:name]).to eq("Alice")
    expect(response).to include("Name: Alice")
  end

  it "sets omitted checkbox descriptors to false" do
    app = StreamWeaver::App.new("Checkbox") { checkbox :enabled, "Enabled" }
    state = { enabled: true }
    app.rebuild_with_state(state)

    run(app, state, :update)

    expect(state[:enabled]).to be(false)
  end

  it "rejects an action that is hidden in the current tree as a no-op" do
    app = StreamWeaver::App.new("Capability") do
      button("Hidden") { |s| s[:called] = true } if state[:show]
    end
    state = { show: true }
    app.rebuild_with_state(state)
    hidden_id = app.components.first.id
    state[:show] = false

    expect { run(app, state, :action, target: hidden_id) }.not_to raise_error
    expect(state[:called]).to be_nil
  end

  it "treats an unknown action id as a no-op" do
    app = StreamWeaver::App.new("Capability") { text "Visible" }
    state = {}
    app.rebuild_with_state(state)

    response = run(app, state, :action, target: "missing")

    expect(response).to include("Visible")
  end

  it "rebuilds only once for an update" do
    app = StreamWeaver::App.new("Update") { text state[:name].to_s }
    app.rebuild_with_state({})
    allow(app).to receive(:rebuild_with_state).and_call_original

    run(app, {}, :update, params: { name: "Ada" })

    expect(app).to have_received(:rebuild_with_state).once
  end

  it "dispatches an event from the current tree and rebuilds only once" do
    app = StreamWeaver::App.new("Event") do
      text_field :name, on_change: ->(s, value) { s[:changed] = value }
      text state[:changed].to_s
    end
    state = {}
    app.rebuild_with_state(state)
    allow(app).to receive(:rebuild_with_state).and_call_original

    response = run(app, state, :event, params: { name: "Grace" }, target: :name)

    expect(state[:changed]).to eq("Grace")
    expect(response).to include("Grace")
    expect(app).to have_received(:rebuild_with_state).once
  end
end
