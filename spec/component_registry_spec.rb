# frozen_string_literal: true

RSpec.describe StreamWeaver::ComponentRegistry do
  # Stub component class defined once at file scope to avoid class-redefinition warnings
  class RegistryTestBanner < StreamWeaver::Components::Base
    attr_reader :text

    def initialize(text:, **opts)
      @text = text
      super(**opts)
    end

    def render(view, _state)
      view.div(class: "test-banner") { view.plain text }
    end

    def children=(ch); @children = ch; end
    def children; @children ||= []; end
  end

  class RegistryTestContainer < StreamWeaver::Components::Base
    def render(view, state)
      view.div(class: "test-container") do
        children.each { |c| c.render(view, state) }
      end
    end

    def children=(ch); @children = ch; end
    def children; @children ||= []; end
  end

  after do
    # Remove registrations made in this spec without nuking other test state
    [:test_banner, :test_container].each do |name|
      if StreamWeaver::ComponentRegistry.registered?(name)
        StreamWeaver::DisplayDSL.undef_method(name) if StreamWeaver::DisplayDSL.method_defined?(name)
        StreamWeaver::ComponentRegistry.instance_variable_get(:@registry).delete(name)
      end
    end
  end

  describe ".register" do
    it "adds the dsl name to the registry" do
      StreamWeaver::ComponentRegistry.register(RegistryTestBanner, dsl: :test_banner)
      expect(StreamWeaver::ComponentRegistry.registered?(:test_banner)).to be true
    end

    it "stores the class reference" do
      StreamWeaver::ComponentRegistry.register(RegistryTestBanner, dsl: :test_banner)
      expect(StreamWeaver::ComponentRegistry[:test_banner][:class]).to eq(RegistryTestBanner)
    end

    it "stores the adapter hint" do
      StreamWeaver::ComponentRegistry.register(RegistryTestBanner, dsl: :test_banner, adapter: :alpinejs)
      expect(StreamWeaver::ComponentRegistry[:test_banner][:adapter]).to eq(:alpinejs)
    end

    it "defines the method on DisplayDSL" do
      StreamWeaver::ComponentRegistry.register(RegistryTestBanner, dsl: :test_banner)
      expect(StreamWeaver::DisplayDSL.method_defined?(:test_banner)).to be true
    end

    it "accepts string dsl name and normalises to symbol" do
      StreamWeaver::ComponentRegistry.register(RegistryTestBanner, dsl: "test_banner")
      expect(StreamWeaver::ComponentRegistry.registered?(:test_banner)).to be true
    end
  end

  describe "generated DSL method on App" do
    before { StreamWeaver::ComponentRegistry.register(RegistryTestBanner, dsl: :test_banner) }

    it "adds a leaf component to the app's component list" do
      a = StreamWeaver::App.new("Test") {}
      a.test_banner(text: "Hello")
      expect(a.components.length).to eq(1)
      expect(a.components.first).to be_a(RegistryTestBanner)
      expect(a.components.first.text).to eq("Hello")
    end

    it "supports being called in the DSL block" do
      a = StreamWeaver::App.new("Test") { test_banner(text: "World") }
      a.rebuild_with_state({})
      expect(a.components.first).to be_a(RegistryTestBanner)
    end
  end

  describe "container component via DSL" do
    before { StreamWeaver::ComponentRegistry.register(RegistryTestContainer, dsl: :test_container) }

    it "attaches children when block given" do
      a = StreamWeaver::App.new("Test") {}
      a.test_container do
        a.send(:with_container, StreamWeaver::Components::Text.new("inner"))
      end
      container = a.components.first
      expect(container).to be_a(RegistryTestContainer)
      expect(container.children.length).to eq(1)
    end
  end

  describe "StreamWeaver.register_component (public API)" do
    it "delegates to ComponentRegistry.register" do
      expect(StreamWeaver::ComponentRegistry).to receive(:register)
        .with(RegistryTestBanner, dsl: :test_banner, adapter: :alpinejs)
      StreamWeaver.register_component(RegistryTestBanner, dsl: :test_banner, adapter: :alpinejs)
    end
  end

  describe ".all" do
    it "returns a copy of the registry" do
      StreamWeaver::ComponentRegistry.register(RegistryTestBanner, dsl: :test_banner)
      result = StreamWeaver::ComponentRegistry.all
      expect(result).to include(test_banner: hash_including(class: RegistryTestBanner))
    end
  end
end
