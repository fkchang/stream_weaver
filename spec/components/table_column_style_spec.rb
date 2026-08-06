# frozen_string_literal: true

require "spec_helper"

# FAC table cell style escape hatches (stream_weaver-act): column DSL `style:`
# (String or Proc), per-column `id_style:`, and table-level `id_column:` for
# raw headers:/rows: tables.
RSpec.describe "StreamWeaver table cell style escape hatches" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state) { {} }

  def render_table_html(table, adapter_instance, state_hash)
    view_class = Class.new(Phlex::HTML) do
      define_method(:initialize) do |table_component, adapter_inst, state_h|
        @table = table_component
        @adapter = adapter_inst
        @state = state_h
        super()
      end

      define_method(:adapter) { @adapter }
      define_method(:view_template) { @table.render(self, @state) }
    end
    view_class.new(table, adapter_instance, state_hash).call
  end

  def build_app(state = {}, &block)
    app = StreamWeaver::App.new("Test", &block)
    app.rebuild_with_state(state)
    app
  end

  def find_table(app)
    app.components.find { |c| c.is_a?(StreamWeaver::Components::Table) }
  end

  describe "column DSL style: as a String" do
    it "appends the static style string to the td style attribute" do
      app = build_app do
        table [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }] do
          column :name, style: "background: yellow;"
        end
      end

      table = find_table(app)
      html = render_table_html(table, adapter, state)
      html.scan(/<td[^>]*style="([^"]*)"/).flatten.each do |style|
        expect(style).to end_with("background: yellow;")
      end
    end
  end

  describe "column DSL style: as a Proc" do
    it "produces per-row style strings aligned to [row][col]" do
      app = build_app do
        table [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }] do
          column :name, style: ->(item) { "background: #{item[:name] == 'Alice' ? 'red' : 'blue'};" }
        end
      end

      table = find_table(app)
      html = render_table_html(table, adapter, state)
      styles = html.scan(/<td[^>]*style="([^"]*)"/).flatten
      expect(styles[0]).to end_with("background: red;")
      expect(styles[1]).to end_with("background: blue;")
    end
  end

  describe "custom style precedence over legacy accent styling" do
    it "appends the custom style after the accent declaration so it wins" do
      app = build_app do
        table [{ id: 1, name: "Alice" }] do
          column :id, style: "color: inherit; font-family: inherit;"
          column :name
        end
      end

      table = find_table(app)
      html = render_table_html(table, adapter, state)
      style = html.scan(/<td[^>]*style="([^"]*)"/).flatten.first
      accent_index = style.index("--sw-color-accent")
      custom_index = style.index("color: inherit; font-family: inherit;")
      expect(accent_index).not_to be_nil
      expect(custom_index).not_to be_nil
      expect(custom_index).to be > accent_index
    end
  end

  describe "id_style: false on column 0" do
    it "suppresses accent styling on that column's cells" do
      app = build_app do
        table [{ id: 1, name: "Alice" }] do
          column :id, id_style: false
          column :name
        end
      end

      table = find_table(app)
      html = render_table_html(table, adapter, state)
      id_cell = html[/<td[^>]*>1<\/td>/]
      expect(id_cell).not_to include("--sw-color-accent")
    end
  end

  describe "id_style: true on a non-zero column" do
    it "applies accent styling to that column's cells" do
      app = build_app do
        table [{ id: 1, name: "Alice" }] do
          column :id
          column :name, id_style: true
        end
      end

      table = find_table(app)
      html = render_table_html(table, adapter, state)
      name_cell = html[/<td[^>]*>Alice<\/td>/]
      expect(name_cell).to include("--sw-color-accent")
    end
  end

  describe "raw headers:/rows: table with id_column: false" do
    it "renders no accent styling anywhere" do
      table = StreamWeaver::Components::Table.new(
        headers: ["Name", "Age"], rows: [["Alice", "30"]], id_column: false
      )
      html = render_table_html(table, adapter, state)
      expect(html).not_to include("--sw-color-accent")
    end
  end

  describe "raw headers:/rows: table with id_column: 2" do
    it "applies accent styling only to column index 2" do
      table = StreamWeaver::Components::Table.new(
        headers: ["A", "B", "C"], rows: [["a1", "b1", "c1"]], id_column: 2
      )
      html = render_table_html(table, adapter, state)
      cell_a = html[/<td[^>]*>a1<\/td>/]
      cell_b = html[/<td[^>]*>b1<\/td>/]
      cell_c = html[/<td[^>]*>c1<\/td>/]
      expect(cell_a).not_to include("--sw-color-accent")
      expect(cell_b).not_to include("--sw-color-accent")
      expect(cell_c).to include("--sw-color-accent")
    end
  end

  describe "raw headers:/rows: table with no id_column: given" do
    it "still applies accent styling to column 0 (legacy default regression guard)" do
      table = StreamWeaver::Components::Table.new(
        headers: ["Name", "Age"], rows: [["Alice", "30"]]
      )
      html = render_table_html(table, adapter, state)
      name_cell = html[/<td[^>]*>Alice<\/td>/]
      expect(name_cell).to include("--sw-color-accent")
    end
  end
end
