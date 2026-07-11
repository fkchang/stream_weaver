# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::ChipGroup do
  describe "initialization" do
    it "stores key, choices, and multi" do
      group = described_class.new(:tags, %w[Ruby Rails], multi: true)
      expect(group.key).to eq(:tags)
      expect(group.choices).to eq(%w[Ruby Rails])
      expect(group.multi).to eq(true)
    end

    it "defaults multi to true" do
      group = described_class.new(:tags, %w[Ruby Rails])
      expect(group.multi).to eq(true)
    end

    it "supports multi: false for single-select" do
      group = described_class.new(:tag, %w[Ruby Rails], multi: false)
      expect(group.multi).to eq(false)
    end

    it "stores additional options" do
      group = described_class.new(:tags, %w[Ruby], submit: false)
      expect(group.options).to include(submit: false)
    end
  end
end

RSpec.describe "chip_group DSL" do
  it "adds a ChipGroup component" do
    app = StreamWeaver::App.new("Test") { chip_group :tags, %w[Ruby Rails] }
    app.rebuild_with_state({})
    component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ChipGroup) }
    expect(component).not_to be_nil
    expect(component.choices).to eq(%w[Ruby Rails])
  end

  it "initializes state to an empty array for multi: true" do
    app = StreamWeaver::App.new("Test") { chip_group :tags, %w[Ruby Rails] }
    app.rebuild_with_state({})
    expect(app.state[:tags]).to eq([])
  end

  it "initializes state to nil for multi: false" do
    app = StreamWeaver::App.new("Test") { chip_group :tag, %w[Ruby Rails], multi: false }
    app.rebuild_with_state({})
    expect(app.state[:tag]).to be_nil
  end

  it "does not clobber an existing array value" do
    app = StreamWeaver::App.new("Test") { chip_group :tags, %w[Ruby Rails] }
    app.rebuild_with_state({ tags: ["Rails"] })
    expect(app.state[:tags]).to eq(["Rails"])
  end

  it "works inside a form block (form-scoped, no top-level state key)" do
    app = StreamWeaver::App.new("Test") do
      form :prefs do
        chip_group :tags, %w[Ruby Rails]
      end
    end
    app.rebuild_with_state({})
    component = app.components.first.children.find { |c| c.is_a?(StreamWeaver::Components::ChipGroup) }
    expect(component).not_to be_nil
    expect(component.options[:form_context]).to eq(name: :prefs)
    expect(app.state[:prefs][:tags]).to eq([])
  end

  it "works inside a scope block (scope-scoped)" do
    app = StreamWeaver::App.new("Test") do
      scope :filters, kind: :fragment do |_s|
        chip_group :tags, %w[Ruby Rails]
      end
    end
    app.rebuild_with_state({})
    component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ChipGroup) }
    expect(component.options[:scope_name]).to eq(:filters)
    expect(app.state[:filters][:tags]).to eq([])
  end
end

RSpec.describe "chip_group HTML rendering" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

  def render_html(component, state)
    StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
  end

  it "renders one checkbox chip per choice for multi: true" do
    group = StreamWeaver::Components::ChipGroup.new(:tags, %w[Ruby Rails])
    html = render_html(group, { tags: [] })
    expect(html.scan('type="checkbox"').length).to eq(2)
    expect(html).to include("Ruby")
    expect(html).to include("Rails")
  end

  it "marks selected chips as checked" do
    group = StreamWeaver::Components::ChipGroup.new(:tags, %w[Ruby Rails])
    html = render_html(group, { tags: ["Rails"] })
    rails_chip = html[/<label class="sw-chip">.*?Rails.*?<\/label>/m]
    expect(rails_chip).to include("checked")
  end

  it "renders radio inputs for multi: false" do
    group = StreamWeaver::Components::ChipGroup.new(:tag, %w[Ruby Rails], multi: false)
    html = render_html(group, { tag: "Ruby" })
    expect(html.scan('type="radio"').length).to eq(2)
  end

  it "wraps chips in a sw-chip-group container" do
    group = StreamWeaver::Components::ChipGroup.new(:tags, %w[Ruby])
    html = render_html(group, { tags: [] })
    expect(html).to include("sw-chip-group")
  end
end
