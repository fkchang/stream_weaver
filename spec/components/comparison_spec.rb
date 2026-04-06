# frozen_string_literal: true

RSpec.describe "Comparison Component (T11)" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::Comparison do
    it "initializes with default labels" do
      c = described_class.new
      expect(c.before_label).to eq("Before")
      expect(c.after_label).to eq("After")
    end

    it "initializes with custom labels" do
      c = described_class.new(before_label: "Old", after_label: "New")
      expect(c.before_label).to eq("Old")
      expect(c.after_label).to eq("New")
    end

    it "initializes children to empty arrays" do
      c = described_class.new
      expect(c.children).to eq([])
      expect(c.before_children).to eq([])
      expect(c.after_children).to eq([])
    end

    it "allows setting before_children" do
      c = described_class.new
      text = StreamWeaver::Components::Text.new("hello")
      c.before_children = [text]
      expect(c.before_children.length).to eq(1)
    end

    it "allows setting after_children" do
      c = described_class.new
      text = StreamWeaver::Components::Text.new("world")
      c.after_children = [text]
      expect(c.after_children.length).to eq(1)
    end
  end

  # =========================================
  # HTML rendering via adapter
  # =========================================

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders a comparison container with sw-comparison class" do
      c = StreamWeaver::Components::Comparison.new
      html = render_html(c)
      expect(html).to include('class="sw-comparison"')
    end

    it "renders before panel" do
      c = StreamWeaver::Components::Comparison.new(before_label: "Old")
      html = render_html(c)
      expect(html).to include("sw-comparison__panel--before")
      expect(html).to include("Old")
    end

    it "renders after panel" do
      c = StreamWeaver::Components::Comparison.new(after_label: "New")
      html = render_html(c)
      expect(html).to include("sw-comparison__panel--after")
      expect(html).to include("New")
    end

    it "renders labels" do
      c = StreamWeaver::Components::Comparison.new(
        before_label: "Current", after_label: "Proposed"
      )
      html = render_html(c)
      expect(html).to include("Current")
      expect(html).to include("Proposed")
    end

    it "renders before children" do
      c = StreamWeaver::Components::Comparison.new
      c.before_children = [StreamWeaver::Components::Text.new("Version A")]
      html = render_html(c)
      expect(html).to include("Version A")
    end

    it "renders after children" do
      c = StreamWeaver::Components::Comparison.new
      c.after_children = [StreamWeaver::Components::Text.new("Version B")]
      html = render_html(c)
      expect(html).to include("Version B")
    end

    it "renders both panels side by side" do
      c = StreamWeaver::Components::Comparison.new(
        before_label: "Before", after_label: "After"
      )
      c.before_children = [StreamWeaver::Components::Text.new("A")]
      c.after_children = [StreamWeaver::Components::Text.new("B")]
      html = render_html(c)
      expect(html).to include("sw-comparison__panel--before")
      expect(html).to include("sw-comparison__panel--after")
      expect(html).to include("A")
      expect(html).to include("B")
    end
  end

  # =========================================
  # CSS prefix convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:css) { adapter.send(:comparison_css) }

    it "all CSS class selectors use sw- prefix" do
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") && !l.strip.start_with?("@") }
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/\.([\w][\w-]*)/).flatten
      }.uniq

      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"),
          "CSS class '.#{cls}' does not use sw- prefix"
      end
    end

    it "includes responsive stacking rule" do
      expect(css).to include("max-width: 767px")
      expect(css).to include("flex-direction: column")
    end
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#comparison" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        comparison(before_label: "Old", after_label: "New") do
          before { text "A" }
          after { text "B" }
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Comparison) }
      expect(component).not_to be_nil
      expect(component.before_label).to eq("Old")
      expect(component.after_label).to eq("New")
    end

    it "captures before children from named block" do
      app = StreamWeaver::App.new("Test") do
        comparison do
          before { text "Version 1" }
          after { text "Version 2" }
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Comparison) }
      expect(component.before_children.length).to eq(1)
      expect(component.before_children.first).to be_a(StreamWeaver::Components::Text)
    end

    it "captures after children from named block" do
      app = StreamWeaver::App.new("Test") do
        comparison do
          before { text "V1" }
          after { text "V2" }
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Comparison) }
      expect(component.after_children.length).to eq(1)
      expect(component.after_children.first).to be_a(StreamWeaver::Components::Text)
    end

    it "renders side-by-side with content from both blocks" do
      adapter = StreamWeaver::Adapter::AlpineJS.new
      app = StreamWeaver::App.new("Test") do
        comparison(before_label: "Old", after_label: "New") do
          before { text "A" }
          after { text "B" }
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Comparison) }
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [component], {})
      expect(html).to include("A")
      expect(html).to include("B")
      expect(html).to include("Old")
      expect(html).to include("New")
    end
  end

  # =========================================
  # Adapter base interface
  # =========================================

  describe "Adapter::Base#render_comparison" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_comparison(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_comparison/)
    end
  end
end
