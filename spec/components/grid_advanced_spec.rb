# frozen_string_literal: true

RSpec.describe "Advanced grid primitives" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

  # Render a single component to HTML using the AlpineJS adapter
  def render_component(component)
    view = StreamWeaver::Views::AppView.new(
      StreamWeaver::App.new("T") {},
      {},
      adapter
    )
    # Capture the Phlex output by rendering just the component
    out = +""
    view.instance_eval do
      component.render(self, {})
    end
    # Use call on a tiny wrapper to get HTML string
    klass = Class.new(Phlex::HTML) do
      define_method(:view_template) { component.render(self, {}) }
      define_method(:adapter) { adapter }
    end
    klass.new.call
  end

  # Simpler helper: build an app, rebuild, render full page, return html
  def app_html(&block)
    a = StreamWeaver::App.new("Test", &block)
    a.rebuild_with_state({})
    StreamWeaver::Views::AppView.new(a, {}, adapter).call
  end

  describe "Grid — template_areas" do
    it "emits grid-template-areas CSS" do
      html = app_html do
        grid template_areas: ["header header", "sidebar main"],
             template_rows: "60px 1fr",
             template_columns: "200px 1fr" do
          grid_area(:header) { text "Header" }
          grid_area(:sidebar) { text "Sidebar" }
          grid_area(:main) { text "Main" }
        end
      end
      # Phlex HTML-entity-escapes quotes inside style attributes
      expect(html).to include("grid-template-areas:")
      expect(html).to match(/header header.*sidebar main/)
      expect(html).to include("grid-template-rows: 60px 1fr")
      expect(html).to include("grid-template-columns: 200px 1fr")
    end

    it "renders grid-area on each area child" do
      html = app_html do
        grid template_areas: ["a b"] do
          grid_area(:a) { text "A" }
          grid_area(:b) { text "B" }
        end
      end
      expect(html).to include("grid-area: a")
      expect(html).to include("grid-area: b")
    end
  end

  describe "Grid — template hash" do
    it "emits grid-template-rows and grid-template-columns from template hash" do
      html = app_html do
        grid template: { rows: "68px 1fr", columns: "240px 1fr" } do
          text "content"
        end
      end
      expect(html).to include("grid-template-rows: 68px 1fr")
      expect(html).to include("grid-template-columns: 240px 1fr")
    end
  end

  describe "Grid — template_rows / template_columns standalone" do
    it "accepts template_rows and template_columns as plain strings" do
      html = app_html do
        grid template_rows: "auto 1fr", template_columns: "300px auto" do
          text "x"
        end
      end
      expect(html).to include("grid-template-rows: auto 1fr")
      expect(html).to include("grid-template-columns: 300px auto")
    end
  end

  describe "Grid — backward compatibility" do
    it "still supports integer column count" do
      html = app_html { grid(columns: 4) { text "cell" } }
      expect(html).to include("grid-template-columns: repeat(4, 1fr)")
    end

    it "still supports responsive array" do
      html = app_html { grid(columns: [1, 2, 3]) { text "cell" } }
      expect(html).to include("data-cols-sm")
    end
  end

  describe "GridArea" do
    it "renders with grid-area style" do
      html = app_html { grid_area(:header) { text "Top" } }
      expect(html).to include("grid-area: header")
      expect(html).to include("sw-grid-area")
    end

    it "converts symbol to string" do
      c = StreamWeaver::Components::GridArea.new(:my_area)
      expect(c.area_name).to eq("my_area")
    end
  end

  describe "Sticky" do
    it "renders position: sticky with top" do
      html = app_html { sticky(top: 0) { text "nav" } }
      expect(html).to include("position: sticky")
      expect(html).to include("top: 0px")
    end

    it "renders z-index when specified" do
      html = app_html { sticky(top: 0, z_index: 10) { text "x" } }
      expect(html).to include("z-index: 10")
    end

    it "renders bottom variant" do
      html = app_html { sticky(bottom: 0) { text "footer" } }
      expect(html).to include("bottom: 0px")
    end
  end

  describe "Overlay" do
    it "renders position: absolute with z-index" do
      html = app_html { overlay(z: 5) { text "x" } }
      expect(html).to include("position: absolute")
      expect(html).to include("z-index: 5")
    end

    it "renders pointer-events when specified" do
      html = app_html { overlay(z: 1, pointer_events: :none) { text "x" } }
      expect(html).to include("pointer-events: none")
    end
  end

  describe "Fullbleed" do
    it "renders with full-width override styles" do
      html = app_html { fullbleed { text "wide" } }
      expect(html).to include("sw-fullbleed")
      expect(html).to include("max-width: none")
    end
  end
end
