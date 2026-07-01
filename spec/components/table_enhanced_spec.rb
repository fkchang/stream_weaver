# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::Table do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state) { {} }
  let(:headers) { ["Name", "Age"] }
  let(:rows) { [["Alice", "30"], ["Bob", "25"], ["Carol", "28"]] }

  # Helper to capture rendered HTML via Phlex
  def render_table_html(**options)
    table = described_class.new(headers: headers, rows: rows, **options)
    view_class = Class.new(Phlex::HTML) do
      define_method(:initialize) do |table_component, adapter_instance, state_hash|
        @table = table_component
        @adapter = adapter_instance
        @state = state_hash
        super()
      end

      define_method(:adapter) { @adapter }
      define_method(:view_template) { @table.render(self, @state) }
    end
    view_class.new(table, adapter, state).call
  end

  describe "backward compatibility" do
    it "works with just headers and rows" do
      table = described_class.new(headers: headers, rows: rows)
      html = render_table_html
      expect(html).to include("Alice")
      expect(html).to include("Bob")
      expect(html).to include("Name")
      expect(html).to include("Age")
    end

    it "renders sw-table class by default" do
      html = render_table_html
      expect(html).to include("sw-table")
    end

    it "does not include enhancement classes by default" do
      html = render_table_html
      expect(html).not_to include("sw-table--alternating")
      expect(html).not_to include("sw-table--hover")
      expect(html).not_to include("sw-table--scrollable")
    end
  end

  describe "header caps and first-column accent styling" do
    it "renders th with uppercase, letter-spacing, and dim color" do
      html = render_table_html
      expect(html).to include("text-transform: uppercase")
      expect(html).to include("letter-spacing: .07em")
      expect(html).to include("--sw-color-text-dim")
      expect(html).to include("--sw-color-text-muted")
    end

    it "renders first column cells in accent monospace" do
      html = render_table_html
      expect(html).to include("var(--sw-color-accent, #1E4ED8)")
      expect(html).to include("var(--sw-font-mono, monospace)")
    end

    it "does not apply accent monospace styling to non-first columns" do
      html = render_table_html
      age_cell = html[/<td[^>]*>30<\/td>/]
      expect(age_cell).not_to include("--sw-color-accent")
    end
  end

  describe "sticky_header option" do
    it "adds sw-table--sticky-header class when true" do
      html = render_table_html(sticky_header: true)
      expect(html).to include("sw-table--sticky-header")
    end

    it "applies sticky positioning on thead" do
      html = render_table_html(sticky_header: true)
      expect(html).to include("position: sticky")
    end

    it "does not add sticky class when false" do
      html = render_table_html(sticky_header: false)
      expect(html).not_to include("sw-table--sticky-header")
    end
  end

  describe "alternating option" do
    it "adds sw-table--alternating class when true" do
      html = render_table_html(alternating: true)
      expect(html).to include("sw-table--alternating")
    end

    it "adds sw-table__row--alt class to odd rows" do
      html = render_table_html(alternating: true)
      expect(html).to include("sw-table__row--alt")
    end

    it "does not add alternating classes when false" do
      html = render_table_html(alternating: false)
      expect(html).not_to include("sw-table--alternating")
      expect(html).not_to include("sw-table__row--alt")
    end
  end

  describe "scrollable option" do
    it "adds sw-table--scrollable wrapper class when true" do
      html = render_table_html(scrollable: true)
      expect(html).to include("sw-table--scrollable")
    end

    it "sets overflow: auto on wrapper" do
      html = render_table_html(scrollable: true)
      expect(html).to include("overflow: auto")
    end

    it "does not add scrollable class when false" do
      html = render_table_html(scrollable: false)
      expect(html).not_to include("sw-table--scrollable")
    end
  end

  describe "hover option" do
    it "adds sw-table--hover class when true" do
      html = render_table_html(hover: true)
      expect(html).to include("sw-table--hover")
    end

    it "adds sw-table__row--hover class to rows" do
      html = render_table_html(hover: true)
      expect(html).to include("sw-table__row--hover")
    end

    it "does not add hover classes when false" do
      html = render_table_html(hover: false)
      expect(html).not_to include("sw-table--hover")
      expect(html).not_to include("sw-table__row--hover")
    end
  end

  describe "combined options" do
    it "supports all enhancement options together" do
      html = render_table_html(
        sticky_header: true,
        alternating: true,
        scrollable: true,
        hover: true
      )
      expect(html).to include("sw-table--sticky-header")
      expect(html).to include("sw-table--alternating")
      expect(html).to include("sw-table--scrollable")
      expect(html).to include("sw-table--hover")
    end

    it "works with existing options alongside enhancements" do
      html = render_table_html(
        striped: true,
        bordered: true,
        alternating: true,
        hover: true
      )
      expect(html).to include("sw-table-striped")
      expect(html).to include("sw-table-bordered")
      expect(html).to include("sw-table--alternating")
      expect(html).to include("sw-table--hover")
    end
  end

  describe "table_options includes new options" do
    it "includes alternating in table_options" do
      table = described_class.new(headers: headers, rows: rows, alternating: true)
      opts = table.send(:table_options)
      expect(opts[:alternating]).to be true
    end

    it "includes scrollable in table_options" do
      table = described_class.new(headers: headers, rows: rows, scrollable: true)
      opts = table.send(:table_options)
      expect(opts[:scrollable]).to be true
    end

    it "includes hover in table_options" do
      table = described_class.new(headers: headers, rows: rows, hover: true)
      opts = table.send(:table_options)
      expect(opts[:hover]).to be true
    end

    it "defaults new options to false" do
      table = described_class.new(headers: headers, rows: rows)
      opts = table.send(:table_options)
      expect(opts[:alternating]).to be false
      expect(opts[:scrollable]).to be false
      expect(opts[:hover]).to be false
    end
  end

  describe "CSS classes use sw- prefix" do
    it "all new table classes use sw- prefix" do
      html = render_table_html(alternating: true, hover: true, scrollable: true, sticky_header: true)
      # Extract all classes that are enhancement-related
      new_classes = html.scan(/sw-table--[\w-]+/)
      new_classes.each do |cls|
        expect(cls).to start_with("sw-")
      end
      expect(new_classes).to include("sw-table--alternating")
      expect(new_classes).to include("sw-table--hover")
      expect(new_classes).to include("sw-table--scrollable")
      expect(new_classes).to include("sw-table--sticky-header")
    end
  end
end
