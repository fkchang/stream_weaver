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
