# frozen_string_literal: true

require 'spec_helper'

# FAC-P2.1: table cells accept real components (per-row action buttons,
# conditional badges) via side-effect detection on the column block, per
# gsd/analysis/decisions/table-cells.md.
RSpec.describe "StreamWeaver table cell composition (FAC-P2.1)" do
  def build_app(state = {}, &block)
    app = StreamWeaver::App.new("Test", &block)
    app.rebuild_with_state(state)
    app
  end

  def find_table(app)
    app.components.find { |c| c.is_a?(StreamWeaver::Components::Table) }
  end

  describe "scalar column blocks (backward compatibility)" do
    it "still renders a scalar cell for a block that never builds a component" do
      app = build_app do
        table [{ id: 1, balance: 42 }] do
          column :balance, format: :currency do |item|
            item[:balance]
          end
        end
      end

      table = find_table(app)
      expect(table.children).to eq([])

      view = Class.new(Phlex::HTML) do
        define_method(:initialize) { |t, a, s| @t, @a, @s = t, a, s; super() }
        define_method(:adapter) { @a }
        define_method(:view_template) { @t.render(self, @s) }
      end.new(table, StreamWeaver::Adapter::AlpineJS.new, {})
      html = view.call
      expect(html).to include("$42")
    end
  end

  describe "component cells" do
    it "captures components built inside a column block into the cell" do
      app = build_app do
        table [{ id: 1, name: "Alice" }], row_key: ->(item) { item[:id] } do
          column :name
          column :actions do |item|
            badge("VIP", variant: :success)
          end
        end
      end

      table = find_table(app)
      expect(table.children.length).to eq(1)
      expect(table.children.first).to be_a(StreamWeaver::Components::Badge)
    end

    it "joins the app's component tree so dispatch can find nested buttons" do
      app = build_app do
        table [{ id: 1 }, { id: 2 }], row_key: ->(item) { item[:id] } do
          column :id
          column :actions do |item|
            button("Delete", key: item[:id]) { |state| state[:deleted] = item[:id] }
          end
        end
      end

      table = find_table(app)
      all_buttons = table.children.select { |c| c.is_a?(StreamWeaver::Components::Button) }
      expect(all_buttons.length).to eq(2)
      expect(all_buttons.map(&:id).uniq.length).to eq(2)

      found = StreamWeaver::SinatraApp.find_button_recursive(app.components, all_buttons.first.id)
      expect(found).to eq(all_buttons.first)
    end

    it "dispatches per-row buttons to the right row's callback via automatic row_key mixing" do
      app = build_app do
        table [{ id: 1 }, { id: 2 }, { id: 3 }], row_key: ->(item) { item[:id] } do
          column :id
          column :actions do |item|
            # Same label, same block source_location, no explicit key: --
            # row_key: alone must disambiguate (FAC-P0.1-style collision).
            button("Remove") { |state| state[:removed] = item[:id] }
          end
        end
      end

      table = find_table(app)
      buttons = table.children.select { |c| c.is_a?(StreamWeaver::Components::Button) }
      expect(buttons.map(&:id).uniq.length).to eq(3)

      state = {}
      buttons[1].execute(state)
      expect(state[:removed]).to eq(2)
    end

    it "keeps a component cell's button id stable across rebuilds (order-independent)" do
      build = lambda do |order|
        build_app do
          table order.map { |i| { id: i } }, row_key: ->(item) { item[:id] } do
            column :actions do |item|
              button("Merge") { |state| state[:merged] = item[:id] }
            end
          end
        end
      end

      forward = build.call([1, 2])
      reversed = build.call([2, 1])

      forward_buttons = find_table(forward).children.select { |c| c.is_a?(StreamWeaver::Components::Button) }
      reversed_buttons = find_table(reversed).children.select { |c| c.is_a?(StreamWeaver::Components::Button) }

      forward_id_for_1 = forward_buttons.first.id
      reversed_id_for_1 = reversed_buttons.last.id
      expect(reversed_id_for_1).to eq(forward_id_for_1)
    end
  end

  describe "row_key resolution" do
    it "auto-derives row_key from #id when no row_key: proc is given" do
      item_class = Struct.new(:id, :name)
      app = build_app do
        table [item_class.new(1, "Alice")] do
          column :name
          column :actions do |item|
            button("Ping", key: item.id) {}
          end
        end
      end

      table = find_table(app)
      expect(table.children.select { |c| c.is_a?(StreamWeaver::Components::Button) }.length).to eq(1)
    end

    it "auto-derives row_key from a Hash :id key" do
      app = build_app do
        table [{ id: "abc", name: "Bob" }] do
          column :name
          column :actions do |item|
            button("Ping") {}
          end
        end
      end

      table = find_table(app)
      expect(table.children.select { |c| c.is_a?(StreamWeaver::Components::Button) }.length).to eq(1)
    end

    it "raises ArgumentError when a component cell builds a button but no row_key is resolvable" do
      expect do
        build_app do
          table [{ name: "no id here" }] do
            column :name
            column :actions do |item|
              button("Ping") {}
            end
          end
        end
      end.to raise_error(ArgumentError, /row_key/)
    end

    it "does not raise for unresolvable row_key when the column block never builds a component" do
      expect do
        build_app do
          table [{ name: "no id here", balance: 5 }] do
            column :name
            column :balance, format: :currency do |item|
              item[:balance]
            end
          end
        end
      end.not_to raise_error
    end
  end

  describe "value-based sorting" do
    it "sorts by declared sort_value, not rendered cell content" do
      app = build_app(users: [{ id: 1, balance: -5 }, { id: 2, balance: 100 }]) do
        table :users, sortable: true do
          column :balance, format: :currency, sort_value: ->(item) { item[:balance] } do |item|
            item[:balance].negative? ? badge("neg", variant: :danger) : item[:balance]
          end
        end
      end

      table = find_table(app)
      html = render_table_to_html(table)
      expect(html).to include('data-sort-value="-5"')
      expect(html).to include('data-sort-value="100"')
    end

    it "excludes a component column with no declared sort_value from click-to-sort" do
      app = build_app(users: [{ id: 1, balance: -5 }]) do
        table :users, sortable: true do
          column :balance do |item|
            item[:balance].negative? ? badge("neg", variant: :danger) : item[:balance]
          end
        end
      end

      table = find_table(app)
      html = render_table_to_html(table)
      expect(html).not_to include("@click")
    end

    def render_table_to_html(table)
      view = Class.new(Phlex::HTML) do
        define_method(:initialize) { |t, a, s| @t, @a, @s = t, a, s; super() }
        define_method(:adapter) { @a }
        define_method(:view_template) { @t.render(self, @s) }
      end.new(table, StreamWeaver::Adapter::AlpineJS.new, {})
      view.call
    end
  end
end
