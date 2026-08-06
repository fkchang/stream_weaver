# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/renderer"
require "stream_weaver/adapter/opal"

RSpec.describe StreamWeaver::Adapter::Opal do
  let(:adapter) { described_class.new }
  let(:state) { {} }
  let(:view) { StreamWeaver::Opal::OpalRenderer.new(adapter, state) }

  describe "#render_header" do
    it "renders h1 for level 1" do
      adapter.render_header(view, "Hello", 1, state)
      expect(view.to_html).to eq("<h1>Hello</h1>")
    end

    it "renders h3 for level 3" do
      adapter.render_header(view, "Sub", 3, state)
      expect(view.to_html).to eq("<h3>Sub</h3>")
    end
  end

  describe "#render_text_field" do
    it "renders an input with data-sw-update attribute" do
      adapter.render_text_field(view, :name, {}, state)
      html = view.to_html
      expect(html).to include('name="name"')
      expect(html).to include('type="text"')
      expect(html).to include('data-sw-update="name"')
      expect(html).not_to include("oninput")
    end

    it "sets value from state" do
      adapter.render_text_field(view, :name, {}, { name: "Alice" })
      expect(view.to_html).to include('value="Alice"')
    end

    it "uses placeholder option" do
      adapter.render_text_field(view, :q, { placeholder: "Search..." }, state)
      expect(view.to_html).to include('placeholder="Search..."')
    end
  end

  describe "#render_date_field" do
    it "renders a date input with data-sw-update attribute" do
      adapter.render_date_field(view, :due_on, {}, state)
      html = view.to_html
      expect(html).to include('type="date"')
      expect(html).to include('name="due_on"')
      expect(html).to include('data-sw-update="due_on"')
    end

    it "sets value from state" do
      adapter.render_date_field(view, :due_on, {}, { due_on: "2026-07-09" })
      expect(view.to_html).to include('value="2026-07-09"')
    end

    it "renders min/max attributes when provided" do
      adapter.render_date_field(view, :due_on, { min: "2020-01-01", max: "2030-12-31" }, state)
      html = view.to_html
      expect(html).to include('min="2020-01-01"')
      expect(html).to include('max="2030-12-31"')
    end

    it "renders the label when provided" do
      adapter.render_date_field(view, :due_on, { label: "Due" }, state)
      html = view.to_html
      expect(html).to include("<label")
      expect(html).to include("Due")
    end
  end

  describe "#render_checkbox" do
    it "renders a checkbox input" do
      adapter.render_checkbox(view, :agree, "I agree", {}, state)
      html = view.to_html
      expect(html).to include('type="checkbox"')
      expect(html).to include("I agree")
    end

    it "marks checked when state is true" do
      adapter.render_checkbox(view, :agree, "I agree", {}, { agree: true })
      expect(view.to_html).to include("checked")
    end

    it "omits checked attribute when state is false" do
      adapter.render_checkbox(view, :agree, "I agree", {}, { agree: false })
      expect(view.to_html).not_to include(' checked')
    end

    it "uses data-sw-toggle attribute instead of inline JS" do
      adapter.render_checkbox(view, :agree, "I agree", {}, state)
      html = view.to_html
      expect(html).to include('data-sw-toggle="agree"')
      expect(html).not_to include("onchange")
    end
  end

  describe "#render_button" do
    it "renders a button with data-sw-invoke attribute" do
      adapter.render_button(view, "btn-1", "Click me", {})
      html = view.to_html
      expect(html).to include("Click me")
      expect(html).to include('data-sw-invoke="btn-1"')
      expect(html).not_to include("onclick")
    end
  end

  describe "#render_div" do
    it "renders a div container" do
      component = double("Div", children: [], html_options: { class: "foo" })
      adapter.render_div(view, component, state)
      expect(view.to_html).to include('<div class="foo">')
    end
  end

  describe "#render_markdown" do
    it "wraps content in a sw-markdown div" do
      adapter.render_markdown(view, "**bold**", state)
      expect(view.to_html).to include('class="sw-markdown"')
    end
  end

  describe "#render_cdn_scripts" do
    it "emits nothing — morphdom is loaded by OpalShell" do
      adapter.render_cdn_scripts(view)
      expect(view.to_html).to eq("")
    end
  end

  describe "#render_tabs" do
    def make_tabs(key, labels)
      tabs = StreamWeaver::Components::Tabs.new(key)
      labels.each do |label|
        tab = StreamWeaver::Components::Tab.new(label)
        tabs.instance_variable_get(:@children) << tab
      end
      tabs
    end

    it "emits .sw-tabs wrapper" do
      tabs = make_tabs(:view, ["A", "B"])
      adapter.render_tabs(view, tabs, {})
      expect(view.to_html).to include('class="sw-tabs')
    end

    it "includes variant class" do
      tabs = StreamWeaver::Components::Tabs.new(:view, variant: :pills)
      adapter.render_tabs(view, tabs, {})
      expect(view.to_html).to include("sw-tabs-pills")
    end

    it "defaults to sw-tabs-line when no variant given (Tabs constructor default)" do
      tabs = StreamWeaver::Components::Tabs.new(:view)
      adapter.render_tabs(view, tabs, {})
      expect(view.to_html).to include("sw-tabs-line")
    end

    it "emits .sw-tabs__nav with a button per tab" do
      tabs = make_tabs(:view, ["Alpha", "Beta"])
      adapter.render_tabs(view, tabs, {})
      html = view.to_html
      expect(html).to include('data-sw-invoke="view_tab_0"')
      expect(html).to include('data-sw-invoke="view_tab_1"')
      expect(html).to include("Alpha")
      expect(html).to include("Beta")
    end

    it "marks tab 0 active by default when state key absent" do
      tabs = make_tabs(:view, ["X", "Y"])
      adapter.render_tabs(view, tabs, {})
      expect(view.to_html).to include("sw-tab-active")
    end

    it "marks the correct tab active based on state" do
      tabs = make_tabs(:view, ["X", "Y", "Z"])
      adapter.render_tabs(view, tabs, { view: 2 })
      html = view.to_html
      # Count active markers — exactly one
      expect(html.scan("sw-tab-active").length).to eq(1)
      # The third button gets the active class
      buttons = html.scan(/class="sw-tab-trigger[^"]*"/)
      expect(buttons[2]).to include("sw-tab-active")
    end
  end

  describe "#render_table" do
    let(:headers) { ["Name", "Score"] }
    let(:rows)    { [["Alice", 90], ["Bob", 75], ["Carol", 85]] }
    let(:options) { { key: :scores, sortable: false, striped: false, bordered: false,
                      scrollable: false, sticky_header: false } }

    def render_table(opts_override = {}, state_override = {})
      adapter.render_table(view, headers, rows, options.merge(opts_override), state.merge(state_override))
    end

    it "emits a .sw-table wrapper div" do
      render_table
      expect(view.to_html).to include('class="sw-table"')
    end

    it "emits header cells as plain th when not sortable" do
      render_table
      html = view.to_html
      expect(html).to include("Name")
      expect(html).to include("Score")
      expect(html).not_to include("data-sw-invoke")
    end

    it "emits th buttons with data-sw-invoke when sortable: true" do
      render_table(sortable: true)
      html = view.to_html
      expect(html).to include('data-sw-invoke="scores_sort_0"')
      expect(html).to include('data-sw-invoke="scores_sort_1"')
    end

    it "adds sw-row-striped to odd rows when striped: true" do
      render_table(striped: true)
      expect(view.to_html).to include("sw-row-striped")
    end

    it "adds sw-table-bordered class when bordered: true" do
      render_table(bordered: true)
      expect(view.to_html).to include("sw-table-bordered")
    end

    it "adds sw-table--scrollable class when scrollable: true" do
      render_table(scrollable: true)
      expect(view.to_html).to include("sw-table--scrollable")
    end

    it "sorts rows ascending by sort_col when sort state present" do
      render_table(
        { sortable: true },
        { "scores_sort_col" => 0, "scores_sort_dir" => :asc }
      )
      html = view.to_html
      alice_pos = html.index("Alice")
      bob_pos   = html.index("Bob")
      carol_pos = html.index("Carol")
      expect(alice_pos).to be < bob_pos
      expect(bob_pos).to be < carol_pos
    end

    it "reverses sort when sort_dir is :desc" do
      render_table(
        { sortable: true },
        { "scores_sort_col" => 0, "scores_sort_dir" => :desc }
      )
      html = view.to_html
      alice_pos = html.index("Alice")
      carol_pos = html.index("Carol")
      expect(carol_pos).to be < alice_pos
    end

    it "emits sort indicator on active column" do
      render_table(
        { sortable: true },
        { "scores_sort_col" => 0, "scores_sort_dir" => :asc }
      )
      expect(view.to_html).to include("↑")
    end

    it "emits ↓ when sort_dir is :desc" do
      render_table(
        { sortable: true },
        { "scores_sort_col" => 0, "scores_sort_dir" => :desc }
      )
      expect(view.to_html).to include("↓")
    end

    it "appends cell_styles onto the td style attribute" do
      render_table(cell_styles: [["background: yellow;", nil], [nil, nil], [nil, nil]])
      html = view.to_html
      alice_cell = html[/<td[^>]*>Alice<\/td>/]
      expect(alice_cell).to include("background: yellow;")
    end

    it "does not emit accent/mono styling regardless of id_column/id_style options" do
      render_table(id_column: 0)
      html = view.to_html
      expect(html).not_to include("--sw-color-accent")
      expect(html).not_to include("--sw-font-mono")
    end
  end

  describe "#render_theme_preset" do
    it "renders nothing — preset CSS vars in dist/sw-theme.css" do
      component = double("ThemePreset")
      adapter.render_theme_preset(view, component, state)
      expect(view.to_html).to eq("")
    end
  end

  describe "#render_theme_toggle" do
    it "emits a button with data-sw-action='toggle-theme'" do
      component = double("ThemeToggle")
      adapter.render_theme_toggle(view, component, state)
      html = view.to_html
      expect(html).to include('data-sw-action="toggle-theme"')
      expect(html).to include("🌓")
    end
  end

  describe "#render_theme_switcher" do
    it "renders nothing — deferred to Phase 3" do
      component = double("ThemeSwitcher")
      adapter.render_theme_switcher(view, component, state)
      expect(view.to_html).to eq("")
    end
  end
end
