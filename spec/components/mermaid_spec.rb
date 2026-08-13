# frozen_string_literal: true

RSpec.describe "Mermaid Component (T3)" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::Mermaid do
    it "initializes with code" do
      m = described_class.new("graph LR; A-->B")
      expect(m.code).to eq("graph LR; A-->B")
    end

    it "defaults zoom to false" do
      m = described_class.new("graph LR; A-->B")
      expect(m.zoom).to eq(false)
    end

    it "defaults compact to false" do
      m = described_class.new("graph LR; A-->B")
      expect(m.compact).to eq(false)
    end

    it "defaults layout to :default" do
      m = described_class.new("graph LR; A-->B")
      expect(m.layout).to eq(:default)
    end

    it "accepts zoom: true" do
      m = described_class.new("graph LR; A-->B", zoom: true)
      expect(m.zoom).to eq(true)
    end

    it "accepts compact: true" do
      m = described_class.new("graph LR; A-->B", compact: true)
      expect(m.compact).to eq(true)
    end

    it "accepts layout: :elk" do
      m = described_class.new("graph LR; A-->B", layout: :elk)
      expect(m.layout).to eq(:elk)
      expect(m.elk?).to eq(true)
    end

    it "accepts theme_vars hash" do
      vars = { primaryColor: "#ff0000" }
      m = described_class.new("graph LR; A-->B", theme_vars: vars)
      expect(m.theme_vars).to eq(vars)
    end

    it "returns null for theme_vars_json when nil" do
      m = described_class.new("graph LR; A-->B")
      expect(m.theme_vars_json).to eq("null")
    end

    it "returns JSON for theme_vars_json when set" do
      m = described_class.new("graph LR; A-->B", theme_vars: { primaryColor: "#ff0000" })
      parsed = JSON.parse(m.theme_vars_json)
      expect(parsed["primaryColor"]).to eq("#ff0000")
    end

    it "generates unique diagram_id" do
      m1 = described_class.new("graph LR; A-->B")
      m2 = described_class.new("graph LR; C-->D")
      expect(m1.diagram_id).not_to eq(m2.diagram_id)
    end

    describe "#css_classes" do
      it "returns sw-mermaid for basic" do
        m = described_class.new("graph LR; A-->B")
        expect(m.css_classes).to eq("sw-mermaid")
      end

      it "includes sw-mermaid--compact" do
        m = described_class.new("graph LR; A-->B", compact: true)
        expect(m.css_classes).to include("sw-mermaid--compact")
      end

      it "includes sw-mermaid--zoom" do
        m = described_class.new("graph LR; A-->B", zoom: true)
        expect(m.css_classes).to include("sw-mermaid--zoom")
      end

      it "includes both compact and zoom" do
        m = described_class.new("graph LR; A-->B", compact: true, zoom: true)
        expect(m.css_classes).to include("sw-mermaid--compact")
        expect(m.css_classes).to include("sw-mermaid--zoom")
      end
    end

    describe "#elk?" do
      it "returns false for default layout" do
        m = described_class.new("graph LR; A-->B")
        expect(m.elk?).to eq(false)
      end

      it "returns true for elk layout" do
        m = described_class.new("graph LR; A-->B", layout: :elk)
        expect(m.elk?).to eq(true)
      end
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

    it "renders a mermaid container with sw-mermaid class" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html(m)
      expect(html).to include('class="sw-mermaid"')
    end

    it "stores code in data attribute" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html(m)
      # Phlex may or may not HTML-escape the data attribute value
      expect(html).to include("data-sw-mermaid-code=")
      expect(html).to include("graph LR; A")
    end

    it "carries no Alpine directive -- sw-mermaid-zoom.js self-inits instead" do
      # Rendering has no dependency on Alpine being loaded (stream_weaver-4gs):
      # the engine calls swMermaidInit() itself on DOMContentLoaded/htmx:afterSwap.
      # Checked as attribute forms, not bare substrings -- the inlined JS's own
      # comments legitimately mention "x-init" as prose.
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html(m)
      expect(html).not_to include('x-init="')
      expect(html).not_to include('x-data="')
    end

    it "renders diagram area with sw-mermaid__diagram class" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html(m)
      expect(html).to include('class="sw-mermaid__diagram"')
    end

    it "renders zoom controls when zoom: true" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B", zoom: true)
      html = render_html(m)
      expect(html).to include('class="sw-mermaid__controls"')
      expect(html).to include('data-sw-zoom="in"')
      expect(html).to include('data-sw-zoom="out"')
      expect(html).to include('data-sw-zoom="reset"')
    end

    it "does not render in/out/reset zoom controls when zoom: false" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html(m)
      container_html = html[html.index('class="sw-mermaid"')..]
      expect(container_html).not_to include('data-sw-zoom="in"')
      expect(container_html).not_to include('data-sw-zoom="out"')
      expect(container_html).not_to include('data-sw-zoom="reset"')
    end

    # Expand always renders, regardless of zoom: -- the in-place zoom
    # mechanism doesn't fix the real problem (the container itself is
    # still small), so it needs no opt-in the way in/out/reset do
    # (stream_weaver-yjv).
    #
    # Asserted against the container slice, not the full document: the
    # inlined sw-mermaid-zoom.js contains its own
    # querySelector('[data-sw-zoom="expand"]'), which satisfies a bare
    # substring check on the full HTML even with the button deleted --
    # the same trap the negative spec above already dodges.
    it "renders the expand control even when zoom: false" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html(m)
      container_html = html[html.index('class="sw-mermaid"')..]
      expect(container_html).to include('class="sw-mermaid__controls"')
      expect(container_html).to include('data-sw-zoom="expand"')
    end

    it "renders the expand control alongside in/out/reset when zoom: true" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B", zoom: true)
      html = render_html(m)
      container_html = html[html.index('class="sw-mermaid"')..]
      expect(container_html).to include('data-sw-zoom="expand"')
    end

    # Regression guard, revised twice:
    # 1. Bare width="14"/height="14" attributes rendered as a literally
    #    invisible 0-width icon -- the button is display: flex, which
    #    makes the SVG a flex item, and a flex item's used width comes
    #    from its flex-basis before width/height attributes are ever
    #    consulted.
    # 2. Switching to an inline style="" attribute fixed that locally but
    #    broke again specifically on SharePoint, whose CSP restricts
    #    style-src-attr (inline style="") independently of style-src (the
    #    <style> block this rule now lives in, already proven working
    #    since the rest of the page's CSS renders there).
    # A real stylesheet class rule dodges both: normal author-stylesheet
    # specificity settles the flex-basis question, and it's governed by
    # style-src, not style-src-attr.
    it "sizes the expand icon via a stylesheet class, not attributes or inline style" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html(m)
      container_html = html[html.index('class="sw-mermaid"')..]
      svg_tag = container_html[/<svg[^>]*>/]
      expect(svg_tag).to include('class="sw-mermaid__expand-icon"')
      expect(svg_tag).not_to include("style=")
      expect(svg_tag).not_to include('width="14"')
      expect(html).to include(".sw-mermaid__expand-icon {")
    end

    it "adds compact class" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B", compact: true)
      html = render_html(m)
      expect(html).to include("sw-mermaid--compact")
    end

    it "adds zoom class" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B", zoom: true)
      html = render_html(m)
      expect(html).to include("sw-mermaid--zoom")
    end

    it "adds ELK data attribute" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B", layout: :elk)
      html = render_html(m)
      expect(html).to include('data-sw-mermaid-elk="true"')
    end

    it "does not add ELK data attribute for default layout" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html(m)
      # Check the container div, not the entire output (which includes JS)
      container_start = html.index('class="sw-mermaid"')
      container_html = container_start ? html[container_start..] : html
      expect(container_html).not_to include("data-sw-mermaid-elk")
    end

    it "adds theme_vars data attribute when provided" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B", theme_vars: { primaryColor: "#ff0000" })
      html = render_html(m)
      expect(html).to include("data-sw-mermaid-vars")
      expect(html).to include("primaryColor")
    end

    it "does not add theme_vars data attribute when nil" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html(m)
      # Check the container div, not the entire output (which includes JS mentioning the attr)
      container_start = html.index('class="sw-mermaid"')
      container_html = container_start ? html[container_start..container_start + 500] : html
      expect(container_html).not_to include("data-sw-mermaid-vars")
    end
  end

  # =========================================
  # Lazy CDN loading
  # =========================================

  describe "lazy CDN loading" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(components)
      StreamWeaver::ComponentRenderer.render_html(adapter, components, state)
    end

    it "injects mermaid CSS on first render" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html([m])
      expect(html).to include(".sw-mermaid {")
      expect(html).to include(".sw-mermaid__diagram")
    end

    it "injects zoom JS on first render" do
      m = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      html = render_html([m])
      expect(html).to include("swMermaidInit")
      expect(html).to include("ZOOM_MIN")
    end

    it "only injects CSS/JS once for multiple mermaid components" do
      m1 = StreamWeaver::Components::Mermaid.new("graph LR; A-->B")
      m2 = StreamWeaver::Components::Mermaid.new("graph LR; C-->D")
      html = render_html([m1, m2])
      # CSS should appear exactly once
      css_occurrences = html.scan(".sw-mermaid {").count
      expect(css_occurrences).to eq(1)
    end
  end

  # =========================================
  # CSS prefix convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:css) { StreamWeaver::Adapter::AlpineJS::MERMAID_CSS }

    it "all CSS class selectors use sw- prefix" do
      # Extract class names from selector lines
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") }
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
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#mermaid" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        mermaid("graph LR; A-->B")
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Mermaid) }
      expect(component).not_to be_nil
      expect(component.code).to eq("graph LR; A-->B")
    end

    it "passes zoom option" do
      app = StreamWeaver::App.new("Test") do
        mermaid("graph LR; A-->B", zoom: true)
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Mermaid) }
      expect(component.zoom).to eq(true)
    end

    it "passes compact option" do
      app = StreamWeaver::App.new("Test") do
        mermaid("graph LR; A-->B", compact: true)
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Mermaid) }
      expect(component.compact).to eq(true)
    end

    it "passes layout option" do
      app = StreamWeaver::App.new("Test") do
        mermaid("graph LR; A-->B", layout: :elk)
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Mermaid) }
      expect(component.layout).to eq(:elk)
    end

    it "passes theme_vars option" do
      app = StreamWeaver::App.new("Test") do
        mermaid("graph LR; A-->B", theme_vars: { primaryColor: "#ff0000" })
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Mermaid) }
      expect(component.theme_vars).to eq({ primaryColor: "#ff0000" })
    end
  end

  # =========================================
  # Adapter base interface
  # =========================================

  describe "Adapter::Base#render_mermaid" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_mermaid(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_mermaid/)
    end
  end

  # =========================================
  # Theme awareness
  # =========================================

  describe "theme awareness" do
    it "zoom JS reads data-sw-theme attribute" do
      js_path = File.join(
        File.dirname(__FILE__), '..', '..', 'lib', 'stream_weaver', 'assets', 'js', 'sw-mermaid-zoom.js'
      )
      js = File.read(js_path)
      expect(js).to include("data-sw-theme")
      expect(js).to include("getMermaidTheme")
      expect(js).to include("getThemeVariables")
    end

    it "zoom JS observes theme changes via MutationObserver" do
      js_path = File.join(
        File.dirname(__FILE__), '..', '..', 'lib', 'stream_weaver', 'assets', 'js', 'sw-mermaid-zoom.js'
      )
      js = File.read(js_path)
      expect(js).to include("MutationObserver")
      expect(js).to include("observeThemeChanges")
    end

    it "zoom JS reads --sw-node-a/b/c CSS custom properties" do
      js_path = File.join(
        File.dirname(__FILE__), '..', '..', 'lib', 'stream_weaver', 'assets', 'js', 'sw-mermaid-zoom.js'
      )
      js = File.read(js_path)
      expect(js).to include("--sw-node-a")
      expect(js).to include("--sw-node-b")
      expect(js).to include("--sw-node-c")
    end
  end

  # =========================================
  # Zoom/Pan JS
  # =========================================

  describe "sw-mermaid-zoom.js" do
    let(:js_path) {
      File.join(
        File.dirname(__FILE__), '..', '..', 'lib', 'stream_weaver', 'assets', 'js', 'sw-mermaid-zoom.js'
      )
    }
    let(:js) { File.read(js_path) }

    it "exists as a file" do
      expect(File.exist?(js_path)).to be true
    end

    it "defines swMermaidInit global function" do
      expect(js).to include("swMermaidInit")
    end

    it "loads Mermaid from CDN lazily" do
      # CDN URL is constructed dynamically from CDN_BASE + version
      expect(js).to include("cdn.jsdelivr.net/npm")
      expect(js).to include("MERMAID_VERSION")
      # Uses dynamic ESM import
      expect(js).to match(/import\s*\(/)
    end

    it "supports ELK layout via CDN" do
      expect(js).to include("layout-elk")
    end

    it "implements zoom controls" do
      expect(js).to include("ZOOM_MIN")
      expect(js).to include("ZOOM_MAX")
      expect(js).to include("ZOOM_STEP")
    end

    it "implements pan via mousedown/mousemove" do
      expect(js).to include("mousedown")
      expect(js).to include("mousemove")
      expect(js).to include("mouseup")
    end

    it "implements Ctrl+scroll zoom" do
      expect(js).to include("ctrlKey")
      expect(js).to include("wheel")
    end

    it "handles render errors gracefully" do
      expect(js).to include("sw-mermaid__error")
    end

    it "implements a fullscreen expand overlay (stream_weaver-yjv)" do
      expect(js).to include("sw-mermaid-fullscreen-overlay")
      expect(js).to include("data-sw-zoom=\"expand\"")
      # Native <dialog>.showModal() rather than a hand-rolled overlay --
      # gets Escape-to-close, focus management, and an inert background
      # from the platform instead of reimplementing them.
      expect(js).to include("showModal")
    end

    it "guards against re-wiring the expand button on every theme switch" do
      # reRenderAll() (a theme toggle) re-runs initExpand against the same
      # button without recreating it -- without an idempotency guard, every
      # toggle stacks another click handler on it.
      expect(js).to include("data-sw-expand-wired")
    end

    it "ties every fullscreen listener to one AbortController per open" do
      # A first draft added document-level mousemove/mouseup listeners with
      # no way to remove them, leaking two per expand/close cycle plus the
      # entire cloned SVG each one's closure retained.
      expect(js).to include("AbortController")
    end

    it "re-namespaces cloned SVG ids instead of duplicating them" do
      # cloneNode(true) alone would duplicate every internal id (arrowhead
      # markers, gradients) into the document while the original is still
      # there; url(#...) resolves to the first match in document order --
      # the original's -- so the clone's markers silently point at
      # whatever the original happens to still have, which breaks the
      # moment the original re-renders or is swapped out from under an
      # open overlay.
      expect(js).to include("fullscreenSeq")
    end

    # Regression guard, revised twice:
    # 1. Mermaid's root <svg> carries width="100%" plus an inline
    #    max-width -- fine in the original in-place container (a normal
    #    block div with a concrete width), not in the overlay, where
    #    .content is a flex item with no explicit width for "100%" to
    #    resolve against. Verified live: the diagram rendered a few px
    #    wide instead of natural size.
    # 2. Fixing that via svgEl.style.width/height worked locally but broke
    #    again on SharePoint, whose CSP restricts style-src-attr (inline
    #    style="", including writes through the .style DOM API)
    #    independently of style-src.
    # setAttribute('width'/'height', ...) are plain SVG geometry
    # attributes, not CSS -- no style-src directive governs them at all.
    it "sizes the cloned SVG via width/height attributes, not .style" do
      expect(js).to include("getAttribute('viewBox')")
      expect(js).to include("svgEl.setAttribute('width'")
      expect(js).to include("svgEl.setAttribute('height'")
      expect(js).not_to include("svgEl.style.width")
      expect(js).not_to include("svgEl.style.height")
    end
  end
end
