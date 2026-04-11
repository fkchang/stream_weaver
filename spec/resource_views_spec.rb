# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

SK = StreamWeaver::Resource::StateKeys unless defined?(SK)

module FakeStoreForViews
  @records = [
    { id: '1', title: 'Foo', status: 'active' },
    { id: '2', title: 'Bar', status: 'inactive' }
  ]

  def self.all;              @records.dup; end
  def self.find(id);         @records.find { |r| r[:id] == id }; end
  def self.create(attrs);    id = SecureRandom.hex(4); @records << { id: id, **attrs }; id; end
  def self.update(id, attrs) r = find(id); r&.merge!(attrs); !!r; end
  def self.destroy(id);      @records.reject! { |r| r[:id] == id }; true; end
end

RSpec.describe "Resource::DefaultViews (T3)" do
  def build_app_with_state(state = {}, &block)
    the_block = block
    app = StreamWeaver::App.new("Test", &the_block)
    app.rebuild_with_state(state)
    app
  end

  def flatten_components(components)
    components.flat_map do |c|
      children = c.respond_to?(:children) ? Array(c.children) : []
      [c, *flatten_components(children)]
    end
  end

  describe "DefaultViews.index" do
    let(:defn) do
      d = StreamWeaver::ResourceDefinition.new(:post, FakeStoreForViews)
      d.field :title,  :string
      d.field :status, :enum, values: %w[active inactive]
      d
    end

    it "renders a Table component in app components" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :index) do
        resource :post, store: FakeStoreForViews do
          field :title,  :string
          field :status, :enum, values: %w[active inactive]
        end
      end

      all_components = flatten_components(app.components)
      table_components = all_components.select { |c| c.is_a?(StreamWeaver::Components::Table) }
      expect(table_components).not_to be_empty
    end

    it "renders a 'New' button in app components" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :index) do
        resource :post, store: FakeStoreForViews do
          field :title, :string
        end
      end

      all_components = flatten_components(app.components)
      buttons = all_components.select { |c| c.is_a?(StreamWeaver::Components::Button) }
      new_button = buttons.find { |b| b.instance_variable_get(:@label)&.include?("New") }
      expect(new_button).not_to be_nil
    end

    it "renders gracefully with empty items list" do
      empty_store = Object.new
      def empty_store.all;              []; end
      def empty_store.find(id);         nil; end
      def empty_store.create(attrs);    '1'; end
      def empty_store.update(id, attrs) true; end
      def empty_store.destroy(id);      true; end

      expect do
        build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :index) do
          resource :post, store: empty_store do
            field :title, :string
          end
        end
      end.not_to raise_error
    end

    it "renders gracefully when items is nil" do
      nil_store = Object.new
      def nil_store.all;              nil; end
      def nil_store.find(id);         nil; end
      def nil_store.create(attrs);    '1'; end
      def nil_store.update(id, attrs) true; end
      def nil_store.destroy(id);      true; end

      expect do
        build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :index) do
          resource :post, store: nil_store do
            field :title, :string
          end
        end
      end.not_to raise_error
    end

    it "renders a Table component with an actions column (markdown links)" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :index) do
        resource :post, store: FakeStoreForViews do
          field :title, :string
        end
      end

      all_components = flatten_components(app.components)
      tables = all_components.select { |c| c.is_a?(StreamWeaver::Components::Table) }
      expect(tables).not_to be_empty

      actions_col = tables.first.columns.find { |col| col.key == :_sw_actions }
      expect(actions_col).not_to be_nil

      # Actions column should produce markdown link text for a sample item
      sample_item = { id: '1', title: 'Test' }
      cell_text = actions_col.extract_value(sample_item)
      expect(cell_text).to include("[View]")
      expect(cell_text).to include("[Edit]")
      expect(cell_text).to include("[Delete]")
    end
  end

  describe "DefaultViews.show" do
    it "renders a Card component in app components" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :show, SK::ID => '1') do
        resource :post, store: FakeStoreForViews do
          field :title,  :string
          field :status, :enum, values: %w[active inactive]
        end
      end

      all_components = flatten_components(app.components)
      card_components = all_components.select { |c| c.is_a?(StreamWeaver::Components::Card) }
      expect(card_components).not_to be_empty
    end

    it "renders nothing when item is nil" do
      missing_store = Object.new
      def missing_store.all;              []; end
      def missing_store.find(id);         nil; end
      def missing_store.create(attrs);    '1'; end
      def missing_store.update(id, attrs) true; end
      def missing_store.destroy(id);      true; end

      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :show, SK::ID => 'missing') do
        resource :post, store: missing_store do
          field :title, :string
        end
      end

      expect(app.components).to be_empty
    end

    it "renders Edit and Delete buttons in the card" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :show, SK::ID => '1') do
        resource :post, store: FakeStoreForViews do
          field :title, :string
        end
      end

      all_components = flatten_components(app.components)
      buttons = all_components.select { |c| c.is_a?(StreamWeaver::Components::Button) }
      labels = buttons.map { |b| b.instance_variable_get(:@label) }

      expect(labels).to include("Edit")
      expect(labels).to include("Delete")
    end
  end

  describe "override blocks (T4 collapsed into T3)" do
    it "override block fully replaces default index" do
      override_ran = false
      fake_store = FakeStoreForViews

      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :index) do
        resource :post, store: fake_store do
          field :title, :string
          index do |items|
            override_ran = true
            text "Custom index"
          end
        end
      end

      expect(override_ran).to be true
      all_components = flatten_components(app.components)
      # No Table component — override replaced the default
      table_components = all_components.select { |c| c.is_a?(StreamWeaver::Components::Table) }
      expect(table_components).to be_empty
    end

    it "override block receives correct data (items array for index)" do
      received_items = nil
      fake_store = FakeStoreForViews

      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :index) do
        resource :post, store: fake_store do
          field :title, :string
          index do |items|
            received_items = items
          end
        end
      end

      expect(received_items).to be_an(Array)
    end

    it "after override runs, @current_form is same as before" do
      fake_store = FakeStoreForViews

      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :index) do
        resource :post, store: fake_store do
          index do |items|
            form :override_form do
              text_field :name, submit: false
            end
          end
        end
      end

      # After the override ran (which created a form), @current_form should be nil (restored)
      expect(app.instance_variable_get(:@current_form)).to be_nil
    end
  end
end
