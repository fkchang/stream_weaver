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

    describe "CSS token declarations via css macro" do
      let(:css) { described_class.component_css_strings.join("\n") }

      it "declares all required --wf-* tokens" do
        %w[--wf-ink --wf-muted --wf-line --wf-paper --wf-card
           --wf-accent --wf-accent-fg --wf-accent-soft
           --wf-warn --wf-ok --wf-radius].each do |token|
          expect(css).to include(token), "Missing token: #{token}"
        end
      end

      it "scopes light-mode tokens to .sw-wireframe-surface" do
        light_block = css[/\.sw-wireframe-surface\s*\{[^}]*--wf-ink/m]
        expect(light_block).not_to be_nil, "Light mode tokens not found in .sw-wireframe-surface block"
      end

      it "scopes dark-mode tokens to html.dark .sw-wireframe-surface" do
        expect(css).to include("html.dark .sw-wireframe-surface")
        dark_block = css[/html\.dark \.sw-wireframe-surface\s*\{[^}]*--wf-ink/m]
        expect(dark_block).not_to be_nil, "Dark mode tokens not found in html.dark .sw-wireframe-surface block"
      end

      it "defines .wf-card helper class scoped to .sw-wireframe-surface" do
        expect(css).to include(".sw-wireframe-surface .wf-card")
      end

      it "defines .wf-box helper class scoped to .sw-wireframe-surface" do
        expect(css).to include(".sw-wireframe-surface .wf-box")
      end

      it "defines .wf-pill helper class scoped to .sw-wireframe-surface" do
        expect(css).to include(".sw-wireframe-surface .wf-pill")
      end

      it "defines .wf-chip helper class scoped to .sw-wireframe-surface" do
        expect(css).to include(".sw-wireframe-surface .wf-chip")
      end

      it "defines .wf-muted helper class scoped to .sw-wireframe-surface" do
        expect(css).to include(".sw-wireframe-surface .wf-muted")
      end

      it "defines button.primary scoped to .sw-wireframe-surface" do
        expect(css).to include(".sw-wireframe-surface button.primary")
      end

      it "defines [data-primary] scoped to .sw-wireframe-surface" do
        expect(css).to include(".sw-wireframe-surface [data-primary]")
      end

      it "does not have any top-level helper class selectors that would leak" do
        # No bare .wf-* or button.primary selectors outside .sw-wireframe-surface
        lines_with_selectors = css.lines.select { |l|
          l.match?(/^\s*\.(wf-|sw-)/) || l.match?(/^\s*button\.primary/)
        }
        lines_with_selectors.each do |line|
          expect(line).to include("sw-wireframe-surface"),
            "Selector may leak outside .sw-wireframe-surface: #{line.strip}"
        end
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

  describe "CSS injection via ComponentAssets" do
    it "registers CSS strings on the class" do
      expect(StreamWeaver::Components::WireframeBlock.component_css_strings).not_to be_empty
    end

    it "collects CSS strings when component is in the tree" do
      c = StreamWeaver::Components::WireframeBlock.new(html: "")
      css_strings, = StreamWeaver::ComponentAssets.collect([c])
      combined = css_strings.join("\n")
      expect(combined).to include("--wf-ink")
      expect(combined).to include(".sw-wireframe-surface")
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
