# frozen_string_literal: true

RSpec.describe "Decision Block Component" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::Decision do
    it "initializes with a question" do
      c = described_class.new(question: "Which DB?")
      expect(c.question).to eq("Which DB?")
    end

    it "initializes with empty options" do
      c = described_class.new(question: "Which DB?")
      expect(c.options).to eq([])
    end

    it "adds options via add_option" do
      c = described_class.new(question: "Which DB?")
      c.add_option(id: :pg, label: "PostgreSQL", detail: "Full ACID", recommended: true)
      expect(c.options.length).to eq(1)
      expect(c.options.first.label).to eq("PostgreSQL")
      expect(c.options.first.recommended).to be(true)
    end

    it "defaults recommended to false" do
      c = described_class.new(question: "Which DB?")
      c.add_option(id: :sqlite, label: "SQLite", detail: "Zero-dep")
      expect(c.options.first.recommended).to be(false)
    end

    it "holds multiple options" do
      c = described_class.new(question: "Which DB?")
      c.add_option(id: :pg, label: "PostgreSQL", detail: "Full ACID", recommended: true)
      c.add_option(id: :sqlite, label: "SQLite", detail: "Zero-dep")
      expect(c.options.length).to eq(2)
    end

    it "Option struct has id, label, detail, recommended" do
      opt = StreamWeaver::Components::Decision::Option.new(
        id: :pg, label: "PostgreSQL", detail: "Full ACID", recommended: true
      )
      expect(opt.id).to eq(:pg)
      expect(opt.label).to eq("PostgreSQL")
      expect(opt.detail).to eq("Full ACID")
      expect(opt.recommended).to be(true)
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

    def build_decision
      c = StreamWeaver::Components::Decision.new(question: "Which database should we use?")
      c.add_option(id: :pg, label: "PostgreSQL", detail: "Full ACID, rich extensions", recommended: true)
      c.add_option(id: :sqlite, label: "SQLite", detail: "Zero-dependency, great for dev")
      c
    end

    it "renders the sw-decision container" do
      html = render_html(build_decision)
      expect(html).to include("sw-decision")
    end

    it "renders the question as a heading" do
      html = render_html(build_decision)
      expect(html).to include("sw-decision__question")
      expect(html).to include("Which database should we use?")
    end

    it "renders each option as a card with label and detail" do
      html = render_html(build_decision)
      expect(html).to include("sw-decision__option")
      expect(html).to include("PostgreSQL")
      expect(html).to include("Full ACID, rich extensions")
      expect(html).to include("SQLite")
      expect(html).to include("Zero-dependency, great for dev")
    end

    it "renders the recommended badge on recommended option" do
      html = render_html(build_decision)
      expect(html).to include("sw-decision__badge")
      expect(html).to include("Recommended")
    end

    it "does not render badge on non-recommended options" do
      c = StreamWeaver::Components::Decision.new(question: "Q")
      c.add_option(id: :a, label: "A", detail: "detail A")
      html = render_html(c)
      expect(html).not_to include('class="sw-decision__badge"')
    end

    it "applies recommended class to recommended option" do
      html = render_html(build_decision)
      expect(html).to include("sw-decision__option--recommended")
    end

    it "applies muted class to non-recommended options" do
      html = render_html(build_decision)
      expect(html).to include("sw-decision__option--muted")
    end

    it "does not apply muted class to recommended option" do
      html = render_html(build_decision)
      # A single class attribute should not contain both modifiers on the same element
      expect(html).not_to include("sw-decision__option--recommended sw-decision__option--muted")
    end
  end

  # =========================================
  # CSS prefix convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:css) { adapter.send(:decision_css) }

    it "all CSS class selectors use sw- prefix" do
      selector_lines = css.lines.select { |l|
        l.include?("{") && !l.strip.start_with?("/*") &&
          !l.strip.start_with?("@") && !l.strip.start_with?("html")
      }
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

  describe "DisplayDSL#decision" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        decision(question: "Which DB?") do
          option(id: :pg, label: "PostgreSQL", detail: "Full ACID", recommended: true)
          option(id: :sqlite, label: "SQLite", detail: "Zero-dep")
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Decision) }
      expect(component).not_to be_nil
      expect(component.question).to eq("Which DB?")
      expect(component.options.length).to eq(2)
    end

    it "captures recommended option from DSL block" do
      app = StreamWeaver::App.new("Test") do
        decision(question: "Q") do
          option(id: :a, label: "A", detail: "detail A", recommended: true)
          option(id: :b, label: "B", detail: "detail B")
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Decision) }
      expect(component.options.first.recommended).to be(true)
      expect(component.options.last.recommended).to be(false)
    end
  end

  # =========================================
  # Adapter::Base interface
  # =========================================

  describe "Adapter::Base#render_decision" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_decision(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_decision/)
    end
  end
end
