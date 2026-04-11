# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

SK = StreamWeaver::Resource::StateKeys unless defined?(SK)

module FakeStore
  @records = [{ id: '1', title: 'Foo', status: 'active' }]

  def self.reset!
    @records = [{ id: '1', title: 'Foo', status: 'active' }]
  end

  def self.all;              @records.dup; end
  def self.find(id);         @records.find { |r| r[:id] == id }; end
  def self.create(attrs);    id = SecureRandom.hex(4); @records << { id: id, **attrs }; id; end
  def self.update(id, attrs) r = find(id); r&.merge!(attrs); !!r; end
  def self.destroy(id);      @records.reject! { |r| r[:id] == id }; true; end
end

RSpec.describe "Resource::Store validation (T3)" do
  describe ".validate!" do
    it "raises ArgumentError listing missing methods for incomplete store" do
      bad_store = Module.new
      # bad_store has none of the required methods

      expect {
        StreamWeaver::Resource::Store.validate!(bad_store, :post)
      }.to raise_error(ArgumentError, /missing required methods/)
    end

    it "error message lists all missing method names" do
      bad_store = Module.new
      expect {
        StreamWeaver::Resource::Store.validate!(bad_store, :post)
      }.to raise_error(ArgumentError) do |e|
        %w[all find create update destroy].each do |m|
          expect(e.message).to include(m)
        end
      end
    end

    it "error message includes the resource name" do
      bad_store = Module.new
      expect {
        StreamWeaver::Resource::Store.validate!(bad_store, :post)
      }.to raise_error(ArgumentError, /:post/)
    end

    it "error mentions only the missing methods, not already-present ones, in the 'missing' list" do
      partial_store = Module.new do
        def self.all;   []; end
        def self.find(id); nil; end
      end
      expect {
        StreamWeaver::Resource::Store.validate!(partial_store, :post)
      }.to raise_error(ArgumentError) do |e|
        # 'create', 'update', 'destroy' should appear in the missing list
        expect(e.message).to include("create")
        expect(e.message).to include("update")
        expect(e.message).to include("destroy")
        # The missing list should NOT include 'all' or 'find' (they are present)
        missing_section = e.message.match(/missing required methods: (.*?)\./m)&.[](1) || ''
        expect(missing_section).not_to include("all")
        expect(missing_section).not_to include("find")
      end
    end

    it "passes for a store with all required methods" do
      good_store = Module.new do
        def self.all;              []; end
        def self.find(id);         nil; end
        def self.create(attrs);    '1'; end
        def self.update(id, attrs) true; end
        def self.destroy(id);      true; end
      end

      expect {
        StreamWeaver::Resource::Store.validate!(good_store, :post)
      }.not_to raise_error
    end

    it "raises ArgumentError during ResourceDefinition initialization for bad store" do
      bad_store = Object.new
      expect {
        StreamWeaver::ResourceDefinition.new(:post, bad_store)
      }.to raise_error(ArgumentError, /missing required methods/)
    end
  end
end

RSpec.describe "Resource::DefaultViews CRUD callbacks (T3)" do
  before(:each) { FakeStore.reset! }

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

  describe "DefaultViews.new form submit" do
    it "renders a Form component in new view" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :new) do
        resource :post, store: FakeStore do
          field :title, :string
          field :status, :enum, values: %w[active inactive]
        end
      end

      all_components = flatten_components(app.components)
      form_components = all_components.select { |c| c.is_a?(StreamWeaver::Components::Form) }
      expect(form_components).not_to be_empty
    end

    it "calls store.create and transitions state to :show on submit" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :new) do
        resource :post, store: FakeStore do
          field :title, :string
        end
      end

      all_components = flatten_components(app.components)
      form = all_components.find { |c| c.is_a?(StreamWeaver::Components::Form) }
      expect(form).not_to be_nil

      initial_count = FakeStore.all.length
      submit_block = form.instance_variable_get(:@submit_action)
      expect(submit_block).not_to be_nil

      form_values = { 'title' => 'New Post' }
      submit_block.call(form_values)

      expect(FakeStore.all.length).to eq(initial_count + 1)
      expect(app.state[SK::ACTION]).to eq(:show)
      expect(app.state[SK::RESOURCE]).to eq(:post)
      expect(app.state[SK::ID]).not_to be_nil
    end
  end

  describe "DefaultViews.edit form submit" do
    it "renders a Form component in edit view" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :edit, SK::ID => '1') do
        resource :post, store: FakeStore do
          field :title, :string
        end
      end

      all_components = flatten_components(app.components)
      form_components = all_components.select { |c| c.is_a?(StreamWeaver::Components::Form) }
      expect(form_components).not_to be_empty
    end

    it "calls store.update and transitions state to :show on submit" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :edit, SK::ID => '1') do
        resource :post, store: FakeStore do
          field :title, :string
        end
      end

      all_components = flatten_components(app.components)
      form = all_components.find { |c| c.is_a?(StreamWeaver::Components::Form) }
      expect(form).not_to be_nil

      submit_block = form.instance_variable_get(:@submit_action)
      expect(submit_block).not_to be_nil

      form_values = { 'title' => 'Updated Title' }
      submit_block.call(form_values)

      expect(FakeStore.find('1')[:title]).to eq('Updated Title')
      expect(app.state[SK::ACTION]).to eq(:show)
    end

    it "seeds form state from record on first load" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :edit, SK::ID => '1') do
        resource :post, store: FakeStore do
          field :title, :string
        end
      end

      # Form state should be seeded from the record
      form_state = app.state[:post_form]
      expect(form_state).not_to be_nil
      expect(form_state[:title]).to eq('Foo')
    end

    it "returns early (renders nothing) when item is nil" do
      app = build_app_with_state(SK::RESOURCE => :post, SK::ACTION => :edit, SK::ID => 'missing') do
        resource :post, store: FakeStore do
          field :title, :string
        end
      end

      expect(app.components).to be_empty
    end
  end

  describe "destroy confirmation flow" do
    it "renders an Alert component when action is :destroy_confirm" do
      app = build_app_with_state(
        SK::RESOURCE => :post,
        SK::ACTION => :destroy_confirm,
        SK::ID => '1'
      ) do
        resource :post, store: FakeStore do
          field :title, :string
        end
      end

      all_components = flatten_components(app.components)
      alert_components = all_components.select { |c| c.is_a?(StreamWeaver::Components::Alert) }
      expect(alert_components).not_to be_empty
    end

    it "calls store.destroy and transitions to :index on confirm" do
      app = build_app_with_state(
        SK::RESOURCE => :post,
        SK::ACTION => :destroy_confirm,
        SK::ID => '1'
      ) do
        resource :post, store: FakeStore do
          field :title, :string
        end
      end

      all_components = flatten_components(app.components)
      buttons = all_components.select { |c| c.is_a?(StreamWeaver::Components::Button) }
      confirm_button = buttons.find { |b| b.instance_variable_get(:@label)&.include?("Confirm") }
      expect(confirm_button).not_to be_nil

      initial_count = FakeStore.all.length
      confirm_callback = confirm_button.instance_variable_get(:@action)
      expect(confirm_callback).not_to be_nil

      confirm_callback.call(app.state)

      expect(FakeStore.all.length).to eq(initial_count - 1)
      expect(app.state[SK::ACTION]).to eq(:index)
      expect(app.state[SK::ID]).to be_nil
    end

    it "cancel button navigates to index without destroying" do
      app = build_app_with_state(
        SK::RESOURCE => :post,
        SK::ACTION => :destroy_confirm,
        SK::ID => '1'
      ) do
        resource :post, store: FakeStore do
          field :title, :string
        end
      end

      all_components = flatten_components(app.components)
      buttons = all_components.select { |c| c.is_a?(StreamWeaver::Components::Button) }
      cancel_button = buttons.find { |b| b.instance_variable_get(:@label) == "Cancel" }
      expect(cancel_button).not_to be_nil

      initial_count = FakeStore.all.length
      cancel_callback = cancel_button.instance_variable_get(:@action)
      cancel_callback.call(app.state)

      expect(FakeStore.all.length).to eq(initial_count)
      expect(app.state[SK::ACTION]).to eq(:index)
    end
  end
end
