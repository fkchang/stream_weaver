# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::DateField do
  describe "initialization" do
    it "stores the state key" do
      field = described_class.new(:birthday)
      expect(field.key).to eq(:birthday)
    end

    it "folds label/min/max into options" do
      field = described_class.new(:birthday, label: "Birthday", min: "2020-01-01", max: "2030-12-31")
      options = field.instance_variable_get(:@options)
      expect(options).to include(label: "Birthday", min: "2020-01-01", max: "2030-12-31")
    end

    it "defaults label/min/max to nil" do
      field = described_class.new(:birthday)
      options = field.instance_variable_get(:@options)
      expect(options[:label]).to be_nil
      expect(options[:min]).to be_nil
      expect(options[:max]).to be_nil
    end
  end

  describe ".to_date" do
    it "parses a valid ISO date string" do
      expect(described_class.to_date("2026-07-09")).to eq(Date.new(2026, 7, 9))
    end

    it "returns nil for blank input" do
      expect(described_class.to_date("")).to be_nil
      expect(described_class.to_date(nil)).to be_nil
    end

    it "returns nil for an invalid date string" do
      expect(described_class.to_date("not-a-date")).to be_nil
    end
  end

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { { birthday: "2026-07-09" } }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders a native date input" do
      field = described_class.new(:birthday)
      html = render_html(field)
      expect(html).to include('type="date"')
    end

    it "renders the current state value" do
      field = described_class.new(:birthday)
      html = render_html(field)
      expect(html).to include('value="2026-07-09"')
    end

    it "renders the label when provided" do
      field = described_class.new(:birthday, label: "Birthday")
      html = render_html(field)
      expect(html).to include("Birthday")
      expect(html).to include("<label")
    end

    it "omits the label element when not provided" do
      field = described_class.new(:birthday)
      html = render_html(field)
      expect(html).not_to include("<label")
    end

    it "renders min/max attributes when provided" do
      field = described_class.new(:birthday, min: "2020-01-01", max: "2030-12-31")
      html = render_html(field)
      expect(html).to include('min="2020-01-01"')
      expect(html).to include('max="2030-12-31"')
    end

    it "omits min/max attributes when not provided" do
      field = described_class.new(:birthday)
      html = render_html(field)
      expect(html).not_to include("min=")
      expect(html).not_to include("max=")
    end

    it "defaults to the change-aware trigger and /update endpoint" do
      field = described_class.new(:birthday)
      html = render_html(field)
      expect(html).to include('hx-trigger="keyup changed delay:500ms, change"')
      expect(html).to include('hx-post="/update"')
    end

    it "routes to /event/:key when on_change is given" do
      field = described_class.new(:birthday, on_change: ->(_s, _v) {})
      html = render_html(field)
      expect(html).to include('hx-post="/event/birthday"')
    end

    it "renders nested name/x-model when inside a form block" do
      field = described_class.new(:due_on, form_context: { name: :prefs })
      html = render_html(field)
      expect(html).to include('name="prefs[due_on]"')
      expect(html).to include('x-model="_form.due_on"')
    end

    it "renders nested name/x-model when inside a scope block" do
      field = described_class.new(:due_on, scope_name: :filters)
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [field], { filters: { due_on: "2026-07-09" } })
      expect(html).to include('name="filters[due_on]"')
      expect(html).to include('x-model="filters.due_on"')
    end
  end
end

RSpec.describe "date_field DSL" do
  it "adds a DateField component" do
    app = StreamWeaver::App.new("Test") { date_field :birthday }
    app.rebuild_with_state({})
    component = app.components.find { |c| c.is_a?(StreamWeaver::Components::DateField) }
    expect(component).not_to be_nil
    expect(component.key).to eq(:birthday)
  end

  it "initializes state to an empty string" do
    app = StreamWeaver::App.new("Test") { date_field :birthday }
    app.rebuild_with_state({})
    expect(app.state[:birthday]).to eq("")
  end

  it "does not clobber an existing state value" do
    app = StreamWeaver::App.new("Test") { date_field :birthday }
    app.rebuild_with_state({ birthday: "2026-01-01" })
    expect(app.state[:birthday]).to eq("2026-01-01")
  end

  it "passes label/min/max through to the component" do
    app = StreamWeaver::App.new("Test") { date_field :birthday, label: "Birthday", min: "2020-01-01", max: "2030-12-31" }
    app.rebuild_with_state({})
    component = app.components.find { |c| c.is_a?(StreamWeaver::Components::DateField) }
    options = component.instance_variable_get(:@options)
    expect(options).to include(label: "Birthday", min: "2020-01-01", max: "2030-12-31")
  end

  it "works inside a form block (form-scoped, no top-level state key)" do
    app = StreamWeaver::App.new("Test") do
      form :prefs do
        date_field :due_on
      end
    end
    app.rebuild_with_state({})
    component = app.components.first.children.find { |c| c.is_a?(StreamWeaver::Components::DateField) }
    expect(component).not_to be_nil
    options = component.instance_variable_get(:@options)
    expect(options[:form_context]).to eq(name: :prefs)
    expect(app.state[:prefs][:due_on]).to eq("")
  end

  it "works inside a scope block (scope-scoped)" do
    app = StreamWeaver::App.new("Test") do
      scope :filters, kind: :fragment do |_s|
        date_field :due_on
      end
    end
    app.rebuild_with_state({})
    component = app.components.find { |c| c.is_a?(StreamWeaver::Components::DateField) }
    options = component.instance_variable_get(:@options)
    expect(options[:scope_name]).to eq(:filters)
    expect(app.state[:filters][:due_on]).to eq("")
  end
end
