# frozen_string_literal: true

RSpec.describe "WireframeBlock CSS Token Foundation" do
  describe StreamWeaver::Components::WireframeBlock do
    it "initializes with html and surface" do
      c = described_class.new(html: "<h1>Test</h1>", surface: "browser")
      expect(c.html).to eq("<h1>Test</h1>")
      expect(c.surface).to eq("browser")
    end

    it "defaults surface to browser" do
      c = described_class.new
      expect(c.surface).to eq("browser")
    end

    it "normalizes unknown surface to browser" do
      c = described_class.new(surface: "unknown")
      expect(c.surface).to eq("browser")
    end

    it "accepts all valid surfaces" do
      %w[browser desktop mobile popover panel].each do |s|
        c = described_class.new(surface: s)
        expect(c.surface).to eq(s)
      end
    end
  end

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state)   { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders .sw-wireframe-surface container" do
      c = StreamWeaver::Components::WireframeBlock.new(html: "<p>Hello</p>")
      html = render_html(c)
      expect(html).to include("sw-wireframe-surface")
    end

    it "includes the raw html content inside the surface" do
      c = StreamWeaver::Components::WireframeBlock.new(html: "<h1>Login</h1>")
      html = render_html(c)
      expect(html).to include("<h1>Login</h1>")
    end

    it "sets data-surface attribute" do
      c = StreamWeaver::Components::WireframeBlock.new(html: "", surface: "mobile")
      html = render_html(c)
      expect(html).to include('data-surface="mobile"')
    end

    it "includes a surface modifier class" do
      c = StreamWeaver::Components::WireframeBlock.new(html: "", surface: "browser")
      html = render_html(c)
      expect(html).to include("sw-wireframe-surface--browser")
    end
  end

  describe "CSS token injection (via adapter inline injection)" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state)   { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    let(:html) { render_html(StreamWeaver::Components::WireframeBlock.new(html: "")) }

    it "injects a <style> block into the rendered output" do
      expect(html).to include("<style>")
    end

    it "injects all required --wf-* tokens" do
      %w[--wf-ink --wf-muted --wf-line --wf-paper --wf-card
         --wf-accent --wf-accent-fg --wf-accent-soft
         --wf-warn --wf-ok --wf-radius].each do |token|
        expect(html).to include(token), "Missing token: #{token}"
      end
    end

    it "scopes light-mode tokens to .sw-wireframe-surface" do
      expect(html).to match(/\.sw-wireframe-surface\s*\{[^}]*--wf-ink/m)
    end

    it "scopes dark-mode tokens to html.dark .sw-wireframe-surface" do
      expect(html).to include("html.dark .sw-wireframe-surface")
    end

    it "defines .wf-card helper class scoped to .sw-wireframe-surface" do
      expect(html).to include(".sw-wireframe-surface .wf-card")
    end

    it "defines .wf-box helper class scoped to .sw-wireframe-surface" do
      expect(html).to include(".sw-wireframe-surface .wf-box")
    end

    it "defines .wf-pill helper class scoped to .sw-wireframe-surface" do
      expect(html).to include(".sw-wireframe-surface .wf-pill")
    end

    it "defines .wf-chip helper class scoped to .sw-wireframe-surface" do
      expect(html).to include(".sw-wireframe-surface .wf-chip")
    end

    it "defines .wf-muted helper class scoped to .sw-wireframe-surface" do
      expect(html).to include(".sw-wireframe-surface .wf-muted")
    end

    it "defines button.primary scoped to .sw-wireframe-surface" do
      expect(html).to include(".sw-wireframe-surface button.primary")
    end

    it "defines [data-primary] scoped to .sw-wireframe-surface" do
      expect(html).to include(".sw-wireframe-surface [data-primary]")
    end

    it "only injects CSS once when multiple wireframe blocks are rendered" do
      single_count = render_html(StreamWeaver::Components::WireframeBlock.new(html: "")).scan("--wf-ink").length
      components = [
        StreamWeaver::Components::WireframeBlock.new(html: "<p>A</p>"),
        StreamWeaver::Components::WireframeBlock.new(html: "<p>B</p>")
      ]
      multi_html = StreamWeaver::ComponentRenderer.render_html(StreamWeaver::Adapter::AlpineJS.new, components, state)
      expect(multi_html.scan("--wf-ink").length).to eq(single_count)
    end
  end

  describe "Adapter::Base interface" do
    it "raises NotImplementedError for render_wireframe_block" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_wireframe_block(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_wireframe_block/)
    end
  end

  describe "DisplayDSL#wireframe_block" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        wireframe_block(html: "<h1>Wireframe</h1>", surface: "browser")
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::WireframeBlock) }
      expect(component).not_to be_nil
      expect(component.html).to eq("<h1>Wireframe</h1>")
      expect(component.surface).to eq("browser")
    end
  end
end
