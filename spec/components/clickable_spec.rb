# frozen_string_literal: true

require "spec_helper"

# clickable(action:|href:, key:) { ...any composed content... } -- a single
# click target wrapping arbitrary children, wired exactly like a
# named-action button for action:, or a plain navigation <a> for href:
# (stream_weaver-1lo, catalog finding #2: tyrion's own board cards are one
# giant <a> wrapping title/tags/priority dot; StreamWeaver's only
# action-dispatching primitive was `button`, whose block is the action
# handler, not child markup, so a whole card could never be one click target).
RSpec.describe StreamWeaver::Components::Clickable do
  it "initializes with empty children" do
    expect(described_class.new(href: "/x").children).to eq([])
  end

  it "stores href" do
    expect(described_class.new(href: "/stories/42").href).to eq("/stories/42")
  end

  it "is nil href when built for the action: form" do
    expect(described_class.new(wrapper_id: "clickable_select_ab12").href).to be_nil
  end
end

RSpec.describe "clickable HTML rendering" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state) { {} }

  def render_html(component)
    StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
  end

  describe "href: form" do
    it "renders a plain navigation <a> wrapping its children" do
      component = StreamWeaver::Components::Clickable.new(href: "/stories/42")
      component.children = [StreamWeaver::Components::Text.new("Story 42")]
      html = render_html(component)

      expect(html).to include('href="/stories/42"')
      expect(html).to match(%r{<a[^>]*><p>Story 42</p></a>})
      expect(html).not_to include("hx-post")
    end

    it "merges class:/style:" do
      component = StreamWeaver::Components::Clickable.new(href: "/x", class: "tyrion-card", style: "opacity: .9;")
      html = render_html(component)
      expect(html).to include("tyrion-card")
      expect(html).to include("opacity: .9;")
    end
  end

  describe "action: form (wrapper_id set the way App#clickable sets it)" do
    let(:component) do
      c = StreamWeaver::Components::Clickable.new(wrapper_id: "clickable_select_ab12", action_token: "tok123")
      c.children = [StreamWeaver::Components::Text.new("Row content")]
      c
    end

    it "renders a div wired like a named-action button: id, hx-post to the token, hx-target, hx-swap" do
      html = render_html(component)
      expect(html).to include('id="clickable_select_ab12"')
      expect(html).to include('hx-post="/action/tok123"')
      expect(html).to include("hx-target=")
      expect(html).to include("hx-swap=")
      expect(html).to include("Row content")
    end

    it "is keyboard accessible: role=button and tabindex=0" do
      html = render_html(component)
      expect(html).to include('role="button"')
      expect(html).to include('tabindex="0"')
    end

    it "wires a loading indicator on the wrapper itself" do
      html = render_html(component)
      expect(html).to include("clickable_select_ab12")
      expect(html.scan(/hx-indicator="([^"]*)"/).flatten.first).to include("#clickable_select_ab12")
    end

    it "filters its own click/keydown trigger so a nested interactive element dispatches independently" do
      html = render_html(component)
      trigger = html[/hx-trigger="([^"]*)"/, 1]
      expect(trigger).to include("closest(")
      expect(trigger).to include("button")
    end
  end

  describe "a button nested inside a clickable" do
    it "keeps its own distinct hx-post target, separate from the wrapper's" do
      inner_button = StreamWeaver::Components::Button.new("Inner", "innerid")
      inner_button.instance_variable_set(:@options, { action_token: "inner-token" })
      wrapper = StreamWeaver::Components::Clickable.new(wrapper_id: "clickable_x", action_token: "outer-token")
      wrapper.children = [inner_button]

      html = render_html(wrapper)
      expect(html).to include('hx-post="/action/outer-token"')
      expect(html).to include('hx-post="/action/inner-token"')
    end
  end
end

RSpec.describe "clickable DSL end-to-end" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:generation) { "session-clk" }

  def token_from(html)
    html[%r{hx-post="/action/([^"]+)"}, 1]
  end

  def run_action(app, state, token)
    StreamWeaver::InteractionRunner.new(
      app: app, state: state, params: {}, interaction: :action, target: token,
      adapter: adapter, persist: ->(_value) {}, action_manifest: app.render_state.action_tokens,
      generation: generation
    ).call
  end

  it "dispatches exactly like a named-action button" do
    app = StreamWeaver::App.new("Clickable") do
      action(:select) { |state, key| state[:selected] = key }
      clickable(action: :select, key: 42) { text "Row 42" }
    end
    app.rebuild_with_state({}, generation: generation)
    html = StreamWeaver::Views::AppView.new(app, {}, adapter).call
    token = token_from(html)
    expect(token).not_to be_nil

    state = {}
    run_action(app, state, token)
    expect(state[:selected]).to eq(42)
  end

  it "dispatches from inside a table cell, keyed by the row (fragment/table-row context)" do
    app = StreamWeaver::App.new("Clickable table") do
      action(:select) { |state, key| state[:selected] = key }
      people = [{ id: 7, name: "Nora" }]
      table people, row_key: ->(p) { p[:id] } do
        column :name
        column(:actions, header: "") do |p|
          clickable(action: :select) { text "View" }
        end
      end
    end
    app.rebuild_with_state({}, generation: generation)
    html = StreamWeaver::Views::AppView.new(app, {}, adapter).call
    token = token_from(html)
    expect(token).not_to be_nil

    state = {}
    run_action(app, state, token)
    expect(state[:selected]).to eq(7)
  end

  it "raises when neither action: nor href: is given" do
    expect do
      StreamWeaver::App.new("Bad") { clickable { text "x" } }.rebuild_with_state({})
    end.to raise_error(ArgumentError, /exactly one of action: or href:/)
  end

  it "raises when both action: and href: are given" do
    expect do
      StreamWeaver::App.new("Bad") { clickable(action: :select, href: "/x", key: 1) { text "x" } }.rebuild_with_state({})
    end.to raise_error(ArgumentError, /exactly one of action: or href:/)
  end

  it "href: form renders a real <a> for routed-page navigation" do
    app = StreamWeaver::App.new("Clickable href") do
      clickable(href: "/stories/9") { text "Story 9" }
    end
    app.rebuild_with_state({})
    html = StreamWeaver::Views::AppView.new(app, {}, adapter).call
    expect(html).to include('href="/stories/9"')
    expect(html).to include("Story 9")
  end
end
