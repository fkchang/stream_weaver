# frozen_string_literal: true

RSpec.describe "DocHeader & DocSectionHeader Components" do
  # =========================================
  # DocHeader component class
  # =========================================

  describe StreamWeaver::Components::DocHeader do
    it "requires title" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "initializes with title" do
      c = described_class.new(title: "My Doc")
      expect(c.title).to eq("My Doc")
    end

    it "initializes eyebrow to nil by default" do
      c = described_class.new(title: "My Doc")
      expect(c.eyebrow).to be_nil
    end

    it "accepts eyebrow string" do
      c = described_class.new(title: "My Doc", eyebrow: "cultiv-ai")
      expect(c.eyebrow).to eq("cultiv-ai")
    end

    it "initializes pills to empty array by default" do
      c = described_class.new(title: "My Doc")
      expect(c.pills).to eq([])
    end

    it "accepts mixed pills array" do
      pills = [{ text: "Draft" }, "June 25, 2026"]
      c = described_class.new(title: "My Doc", pills: pills)
      expect(c.pills).to eq(pills)
    end

    it "wraps single pill in array" do
      c = described_class.new(title: "My Doc", pills: "Draft")
      expect(c.pills).to eq(["Draft"])
    end
  end

  # =========================================
  # DocSectionHeader component class
  # =========================================

  describe StreamWeaver::Components::DocSectionHeader do
    it "initializes with number and title" do
      c = described_class.new("01", "Problem Statement")
      expect(c.number).to eq("01")
      expect(c.title).to eq("Problem Statement")
    end

    it "coerces number to string" do
      c = described_class.new(1, "Title")
      expect(c.number).to eq("1")
    end

    it "defaults anchor_id to nil" do
      c = described_class.new("01", "Title")
      expect(c.anchor_id).to be_nil
    end

    it "accepts id option" do
      c = described_class.new("01", "Title", id: "problem")
      expect(c.anchor_id).to eq("problem")
    end
  end

  # =========================================
  # HTML rendering
  # =========================================

  describe "DocHeader HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders sw-doc-header container" do
      c = StreamWeaver::Components::DocHeader.new(title: "My Doc")
      html = render_html(c)
      expect(html).to include("sw-doc-header")
    end

    it "renders the title" do
      c = StreamWeaver::Components::DocHeader.new(title: "My PRD")
      html = render_html(c)
      expect(html).to include("My PRD")
      expect(html).to include("sw-doc-header__title")
    end

    it "renders eyebrow when provided" do
      c = StreamWeaver::Components::DocHeader.new(title: "My Doc", eyebrow: "cultiv-ai")
      html = render_html(c)
      expect(html).to include("sw-doc-header__eyebrow")
      expect(html).to include("cultiv-ai")
    end

    it "omits eyebrow div when nil" do
      c = StreamWeaver::Components::DocHeader.new(title: "My Doc")
      html = render_html(c)
      expect(html).not_to include('class="sw-doc-header__eyebrow"')
    end

    it "renders plain meta text items" do
      c = StreamWeaver::Components::DocHeader.new(title: "My Doc", pills: ["June 25, 2026"])
      html = render_html(c)
      expect(html).to include("sw-doc-header__meta-item")
      expect(html).to include("June 25, 2026")
    end

    it "renders hash pills with variant class" do
      c = StreamWeaver::Components::DocHeader.new(
        title: "My Doc",
        pills: [{ text: "Draft", variant: :warn }]
      )
      html = render_html(c)
      expect(html).to include("sw-doc-header__pill--warn")
      expect(html).to include("Draft")
    end

    it "defaults pill variant to :default" do
      c = StreamWeaver::Components::DocHeader.new(
        title: "My Doc",
        pills: [{ text: "WIP" }]
      )
      html = render_html(c)
      expect(html).to include("sw-doc-header__pill--default")
    end

    it "omits meta div when pills is empty" do
      c = StreamWeaver::Components::DocHeader.new(title: "My Doc")
      html = render_html(c)
      expect(html).not_to include('class="sw-doc-header__meta"')
    end
  end

  describe "DocSectionHeader HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders sw-doc-section-header container" do
      c = StreamWeaver::Components::DocSectionHeader.new("01", "Problem")
      html = render_html(c)
      expect(html).to include("sw-doc-section-header")
    end

    it "renders the section number in the eyebrow" do
      c = StreamWeaver::Components::DocSectionHeader.new("01", "Problem")
      html = render_html(c)
      expect(html).to include("sw-doc-section-header__eyebrow")
      expect(html).to include("01")
    end

    it "renders the section title as h2" do
      c = StreamWeaver::Components::DocSectionHeader.new("01", "Problem Statement")
      html = render_html(c)
      expect(html).to include("sw-doc-section-header__title")
      expect(html).to include("Problem Statement")
    end

    it "adds id attribute when provided" do
      c = StreamWeaver::Components::DocSectionHeader.new("01", "Problem", id: "problem")
      html = render_html(c)
      expect(html).to include('id="problem"')
    end

    it "omits id attribute when nil" do
      c = StreamWeaver::Components::DocSectionHeader.new("01", "Problem")
      html = render_html(c)
      expect(html).not_to include('id=')
    end
  end

  # =========================================
  # CSS prefix convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:css) { adapter.send(:doc_header_css) }

    it "all CSS class selectors use sw- prefix" do
      selector_lines = css.lines.select { |l|
        l.include?("{") &&
          !l.strip.start_with?("/*") &&
          !l.strip.start_with?("@") &&
          !l.strip.start_with?("html") &&
          !l.strip.start_with?(".")
      }
      class_selectors = css.scan(/\.([a-zA-Z][a-zA-Z0-9_-]*)/).flatten.uniq
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

  describe "DisplayDSL#doc_header" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        doc_header(
          title: "My PRD",
          eyebrow: "cultiv-ai",
          pills: [{ text: "Draft" }, "June 2026"]
        )
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::DocHeader) }
      expect(component).not_to be_nil
      expect(component.title).to eq("My PRD")
      expect(component.eyebrow).to eq("cultiv-ai")
      expect(component.pills.length).to eq(2)
    end
  end

  describe "DisplayDSL#doc_section_header" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        doc_section_header "01", "Problem Statement", id: "problem"
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::DocSectionHeader) }
      expect(component).not_to be_nil
      expect(component.number).to eq("01")
      expect(component.title).to eq("Problem Statement")
      expect(component.anchor_id).to eq("problem")
    end
  end

  # =========================================
  # Adapter::Base interface
  # =========================================

  describe "Adapter::Base stubs" do
    let(:adapter) { StreamWeaver::Adapter::Base.new }

    it "render_doc_header raises NotImplementedError" do
      expect { adapter.render_doc_header(nil, nil, nil) }.to raise_error(NotImplementedError, /render_doc_header/)
    end

    it "render_doc_section_header raises NotImplementedError" do
      expect { adapter.render_doc_section_header(nil, nil, nil) }.to raise_error(NotImplementedError, /render_doc_section_header/)
    end
  end
end
