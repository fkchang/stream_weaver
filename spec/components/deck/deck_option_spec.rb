# frozen_string_literal: true

RSpec.describe "DeckOption Component (T7)" do
  describe StreamWeaver::Components::Deck::DeckOption do
    it "initializes with label" do
      opt = described_class.new("Monolith")
      expect(opt.label).to eq("Monolith")
    end

    it "defaults aside to nil" do
      opt = described_class.new("Monolith")
      expect(opt.aside).to be_nil
    end

    it "defaults recommended to false" do
      opt = described_class.new("Monolith")
      expect(opt.recommended).to eq(false)
    end

    it "defaults description to nil" do
      opt = described_class.new("Monolith")
      expect(opt.description).to be_nil
    end

    it "accepts aside option" do
      opt = described_class.new("Monolith", aside: "Simple deployment")
      expect(opt.aside).to eq("Simple deployment")
    end

    it "accepts recommended option" do
      opt = described_class.new("Microservices", recommended: true)
      expect(opt.recommended).to eq(true)
    end

    it "accepts description option" do
      opt = described_class.new("Monolith", description: "Traditional architecture")
      expect(opt.description).to eq("Traditional architecture")
    end

    it "has empty children by default" do
      opt = described_class.new("Monolith")
      expect(opt.children).to eq([])
    end

    it "allows setting children" do
      opt = described_class.new("Monolith")
      child = StreamWeaver::Components::Text.new("Preview")
      opt.children = [child]
      expect(opt.children.length).to eq(1)
    end

    describe "#css_classes" do
      it "includes sw-deck-option" do
        opt = described_class.new("A")
        expect(opt.css_classes).to include("sw-deck-option")
      end

      it "includes recommended modifier when recommended" do
        opt = described_class.new("A", recommended: true)
        expect(opt.css_classes).to include("sw-deck-option--recommended")
      end

      it "does not include recommended modifier when not recommended" do
        opt = described_class.new("A")
        expect(opt.css_classes).not_to include("sw-deck-option--recommended")
      end
    end

    describe "#render" do
      it "delegates to adapter" do
        opt = described_class.new("Test")
        adapter = double("adapter")
        view = double("view", adapter: adapter)
        expect(adapter).to receive(:render_deck_option).with(view, opt, {})
        opt.render(view, {})
      end
    end
  end

  # =========================================
  # HTML Rendering
  # =========================================

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders with radio role" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("Test")
      html = render_html(opt)
      expect(html).to include('role="radio"')
    end

    it "renders with aria-checked=false" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("Test")
      html = render_html(opt)
      expect(html).to include('aria-checked="false"')
    end

    it "renders radio indicator" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("Test")
      html = render_html(opt)
      expect(html).to include("sw-deck-option__radio")
    end

    it "renders label" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("PostgreSQL")
      html = render_html(opt)
      expect(html).to include("PostgreSQL")
      expect(html).to include("sw-deck-option__label")
    end

    it "renders recommended badge when recommended" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("Best", recommended: true)
      html = render_html(opt)
      expect(html).to include("Recommended")
      expect(html).to include("sw-deck-option__badge")
    end

    it "does not render badge when not recommended" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("Normal")
      html = render_html(opt)
      # Check no actual badge element (CSS may mention the class)
      expect(html).not_to include('class="sw-deck-option__badge"')
    end

    it "renders aside text" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("A", aside: "ACID compliance")
      html = render_html(opt)
      expect(html).to include("ACID compliance")
      expect(html).to include("sw-deck-option__aside")
    end

    it "does not render aside when nil" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("A")
      html = render_html(opt)
      # Check no actual aside element (CSS may mention the class)
      expect(html).not_to include('class="sw-deck-option__aside"')
    end

    it "renders notes textarea" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("A")
      html = render_html(opt)
      expect(html).to include("sw-deck-option__notes")
      expect(html).to include("sw-deck-option__notes-input")
      expect(html).to include("Add notes...")
    end

    it "renders preview content from children" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("A")
      opt.children = [StreamWeaver::Components::Text.new("Preview text")]
      html = render_html(opt)
      expect(html).to include("sw-deck-option__preview")
      expect(html).to include("Preview text")
    end

    it "does not render preview area when no children" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("A")
      html = render_html(opt)
      # Check no actual preview element (CSS may mention the class)
      expect(html).not_to include('class="sw-deck-option__preview"')
    end

    it "renders aria-label from description" do
      opt = StreamWeaver::Components::Deck::DeckOption.new("A", description: "Detailed explanation")
      html = render_html(opt)
      expect(html).to include('aria-label="Detailed explanation"')
    end
  end
end
