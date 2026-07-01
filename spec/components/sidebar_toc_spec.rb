# frozen_string_literal: true

RSpec.describe "SidebarToc Component (T11)" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::SidebarToc do
    let(:sections) do
      [
        { id: "intro", label: "Introduction" },
        { id: "arch", label: "Architecture" },
        { id: "risks", label: "Risks" }
      ]
    end

    it "initializes with sections" do
      toc = described_class.new(sections: sections)
      expect(toc.sections.length).to eq(3)
    end

    it "normalizes section ids to strings" do
      toc = described_class.new(sections: [{ id: :summary, label: "Summary" }])
      expect(toc.sections.first[:id]).to eq("summary")
    end

    it "normalizes section labels to strings" do
      toc = described_class.new(sections: [{ id: "s1", label: :intro }])
      expect(toc.sections.first[:label]).to eq("intro")
    end

    it "handles string keys in section hashes" do
      toc = described_class.new(sections: [{ "id" => "s1", "label" => "Section 1" }])
      expect(toc.sections.first[:id]).to eq("s1")
      expect(toc.sections.first[:label]).to eq("Section 1")
    end

    it "preserves section order" do
      toc = described_class.new(sections: sections)
      expect(toc.sections.map { |s| s[:id] }).to eq(%w[intro arch risks])
    end
  end

  # =========================================
  # HTML rendering via adapter
  # =========================================

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }
    let(:sections) do
      [
        { id: "s1", label: "Intro" },
        { id: "s2", label: "Details" }
      ]
    end

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders a nav element with sw-sidebar-toc class" do
      toc = StreamWeaver::Components::SidebarToc.new(sections: sections)
      html = render_html(toc)
      expect(html).to include('class="sw-sidebar-toc"')
    end

    it "renders an aria-label for accessibility" do
      toc = StreamWeaver::Components::SidebarToc.new(sections: sections)
      html = render_html(toc)
      expect(html).to include('aria-label="Table of contents"')
    end

    it "renders links for each section" do
      toc = StreamWeaver::Components::SidebarToc.new(sections: sections)
      html = render_html(toc)
      expect(html).to include('href="#s1"')
      expect(html).to include('href="#s2"')
      expect(html).to include("Intro")
      expect(html).to include("Details")
    end

    it "renders data-sw-toc-target attributes" do
      toc = StreamWeaver::Components::SidebarToc.new(sections: sections)
      html = render_html(toc)
      expect(html).to include('data-sw-toc-target="s1"')
      expect(html).to include('data-sw-toc-target="s2"')
    end

    it "renders sw-sidebar-toc__link class on links" do
      toc = StreamWeaver::Components::SidebarToc.new(sections: sections)
      html = render_html(toc)
      expect(html).to include('class="sw-sidebar-toc__link"')
    end

    it "injects scroll spy JS" do
      toc = StreamWeaver::Components::SidebarToc.new(sections: sections)
      html = render_html(toc)
      expect(html).to include("IntersectionObserver")
    end

    it "injects sidebar toc CSS" do
      toc = StreamWeaver::Components::SidebarToc.new(sections: sections)
      html = render_html(toc)
      expect(html).to include("sw-sidebar-toc")
      expect(html).to include("position: sticky")
    end
  end

  # =========================================
  # CSS prefix convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:css) { adapter.send(:sidebar_toc_css) }

    it "all CSS class selectors use sw- prefix" do
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") && !l.strip.start_with?("@") }
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/\.([\w][\w-]*)/).flatten
      }.uniq

      # Filter out non-class selectors (pseudo-elements, etc.)
      class_selectors.reject! { |cls| cls.start_with?("-") }

      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"),
          "CSS class '.#{cls}' does not use sw- prefix"
      end
    end
  end

  # =========================================
  # TOC numbers (CSS counters)
  # =========================================

  describe "CSS counters for TOC numbering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:css) { adapter.send(:sidebar_toc_css) }
    let(:sections) do
      [
        { id: "s1", label: "Intro" },
        { id: "s2", label: "Details" }
      ]
    end

    it "resets the counter on .sw-sidebar-toc__nav" do
      expect(css).to match(/\.sw-sidebar-toc__nav\s*\{[^}]*counter-reset:\s*sw-toc-counter/m)
    end

    it "increments the counter on each .sw-sidebar-toc__link" do
      expect(css).to match(/\.sw-sidebar-toc__link\s*\{[^}]*counter-increment:\s*sw-toc-counter/m)
    end

    it "displays a zero-padded number via ::before" do
      expect(css).to include(".sw-sidebar-toc__link::before")
      expect(css).to match(/content:\s*counter\(sw-toc-counter,\s*decimal-leading-zero\)/)
    end

    it "renders the counter number in a mono/faint color, not hardcoded per link" do
      expect(css).to match(/\.sw-sidebar-toc__link::before\s*\{[^}]*font-family:\s*var\(--sw-font-mono/m)
      expect(css).to match(/\.sw-sidebar-toc__link::before\s*\{[^}]*color:\s*var\(--sw-text-dim/m)
    end

    it "is purely presentational — rendered HTML for links is unchanged by the counter CSS" do
      toc = StreamWeaver::Components::SidebarToc.new(sections: sections)
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [toc], {})
      expect(html).to include('href="#s1"')
      expect(html).to include("Intro")
      link_texts = html.scan(%r{<a[^>]*class="sw-sidebar-toc__link"[^>]*>(.*?)</a>}m).flatten
      expect(link_texts).to eq(%w[Intro Details])
    end
  end

  # =========================================
  # Sticky grid layout (replaces float + negative-margin hack)
  # =========================================

  describe "sticky grid layout" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:css) { adapter.send(:sidebar_toc_css) }

    it "does not use the old float + negative-margin hack" do
      expect(css).not_to match(/float:\s*left/)
      expect(css).not_to match(/margin-left:\s*-224px/)
    end

    it "turns the doc container into a grid when sidebar_toc is present" do
      expect(css).to match(/#app-container:has\(\.sw-sidebar-toc\)\s*\{[^}]*display:\s*grid/m)
      expect(css).to match(/#app-container:has\(\.sw-sidebar-toc\)\s*\{[^}]*grid-template-columns:\s*var\(--sw-toc-width\) minmax\(0,\s*1fr\)/m)
    end

    it "pins the sidebar to column 1, sticky and self-aligned to start" do
      expect(css).to match(/\.sw-sidebar-toc\s*\{[^}]*grid-column:\s*1/m)
      expect(css).to match(/\.sw-sidebar-toc\s*\{[^}]*align-self:\s*start/m)
      expect(css).to match(/\.sw-sidebar-toc\s*\{[^}]*top:\s*2rem/m)
    end

    it "bleeds the doc_header full-width via negative margin" do
      # not grid-column — that would block the sidebar's row-span
      expect(css).to match(/#app-container:has\(\.sw-sidebar-toc\)\s*>\s*\.sw-doc-header\s*\{[^}]*margin-left:\s*calc\(-1 \* \(var\(--sw-toc-width\) \+ var\(--sw-toc-gap\)\)\)/m)
      expect(css).to match(/#app-container:has\(\.sw-sidebar-toc\)\s*>\s*\.sw-doc-header\s*\{[^}]*padding-left:\s*calc\(var\(--sw-toc-width\) \+ var\(--sw-toc-gap\)\)/m)
    end

    it "defines --sw-toc-width and --sw-toc-gap as the single source of truth for sidebar sizing" do
      expect(css).to match(/#app-container:has\(\.sw-sidebar-toc\)\s*\{[^}]*--sw-toc-width:\s*220px/m)
      expect(css).to match(/#app-container:has\(\.sw-sidebar-toc\)\s*\{[^}]*--sw-toc-gap:\s*2rem/m)
    end

    it "restores overflow to visible on the grid container" do
      # position:sticky won't position relative to the page otherwise
      expect(css).to match(/#app-container:has\(\.sw-sidebar-toc\)\s*\{[^}]*overflow:\s*visible/m)
    end

    it "preserves the horizontal-bar responsive layout below 1000px" do
      expect(css).to match(/@media \(max-width:\s*999px\)\s*\{[^@]*\.sw-sidebar-toc\s*\{[^}]*top:\s*0/m)
      expect(css).to match(/\.sw-sidebar-toc__nav\s*\{[^}]*flex-direction:\s*row/m)
    end
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#sidebar_toc" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        sidebar_toc sections: [{ id: "s1", label: "Intro" }]
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::SidebarToc) }
      expect(component).not_to be_nil
      expect(component.sections.length).to eq(1)
    end
  end

  # =========================================
  # Adapter base interface
  # =========================================

  describe "Adapter::Base#render_sidebar_toc" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_sidebar_toc(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_sidebar_toc/)
    end
  end
end
