# frozen_string_literal: true

RSpec.describe "DeckSlide Component (T7)" do
  describe StreamWeaver::Components::Deck::DeckSlide do
    it "initializes with id" do
      slide = described_class.new("arch")
      expect(slide.id).to eq("arch")
      expect(slide.title).to be_nil
    end

    it "initializes with id and title" do
      slide = described_class.new("arch", "Architecture")
      expect(slide.id).to eq("arch")
      expect(slide.title).to eq("Architecture")
    end

    it "converts id to string" do
      slide = described_class.new(:my_slide)
      expect(slide.id).to eq("my_slide")
    end

    it "accepts context option" do
      slide = described_class.new("arch", "Architecture", context: "Choose wisely")
      expect(slide.context_text).to eq("Choose wisely")
    end

    it "accepts columns option" do
      slide = described_class.new("arch", columns: 3)
      expect(slide.columns).to eq(3)
    end

    it "has empty children by default" do
      slide = described_class.new("s1")
      expect(slide.children).to eq([])
    end

    it "allows setting children" do
      slide = described_class.new("s1")
      opt = StreamWeaver::Components::Deck::DeckOption.new("Option A")
      slide.children = [opt]
      expect(slide.children.length).to eq(1)
    end

    describe "#auto_columns" do
      it "returns 1 for 0 options" do
        slide = described_class.new("s1")
        expect(slide.auto_columns).to eq(1)
      end

      it "returns 1 for 1 option" do
        slide = described_class.new("s1")
        slide.children = [StreamWeaver::Components::Deck::DeckOption.new("A")]
        expect(slide.auto_columns).to eq(1)
      end

      it "returns 2 for 2 options" do
        slide = described_class.new("s1")
        slide.children = [
          StreamWeaver::Components::Deck::DeckOption.new("A"),
          StreamWeaver::Components::Deck::DeckOption.new("B")
        ]
        expect(slide.auto_columns).to eq(2)
      end

      it "returns 3 for 3 options" do
        slide = described_class.new("s1")
        slide.children = [
          StreamWeaver::Components::Deck::DeckOption.new("A"),
          StreamWeaver::Components::Deck::DeckOption.new("B"),
          StreamWeaver::Components::Deck::DeckOption.new("C")
        ]
        expect(slide.auto_columns).to eq(3)
      end

      it "returns 2 for 4+ options" do
        slide = described_class.new("s1")
        slide.children = [
          StreamWeaver::Components::Deck::DeckOption.new("A"),
          StreamWeaver::Components::Deck::DeckOption.new("B"),
          StreamWeaver::Components::Deck::DeckOption.new("C"),
          StreamWeaver::Components::Deck::DeckOption.new("D")
        ]
        expect(slide.auto_columns).to eq(2)
      end

      it "uses explicit columns when provided" do
        slide = described_class.new("s1", columns: 4)
        slide.children = [
          StreamWeaver::Components::Deck::DeckOption.new("A"),
          StreamWeaver::Components::Deck::DeckOption.new("B")
        ]
        expect(slide.auto_columns).to eq(4)
      end
    end

    describe "#option_count" do
      it "counts only DeckOption children" do
        slide = described_class.new("s1")
        slide.children = [
          StreamWeaver::Components::Deck::DeckOption.new("A"),
          StreamWeaver::Components::Text.new("Not an option"),
          StreamWeaver::Components::Deck::DeckOption.new("B")
        ]
        expect(slide.option_count).to eq(2)
      end
    end

    describe "#css_classes" do
      it "returns sw-deck-slide" do
        slide = described_class.new("s1")
        expect(slide.css_classes).to eq("sw-deck-slide")
      end
    end

    describe "#render" do
      it "delegates to adapter" do
        slide = described_class.new("s1", "Test")
        adapter = double("adapter")
        view = double("view", adapter: adapter)
        expect(adapter).to receive(:render_deck_slide).with(view, slide, {})
        slide.render(view, {})
      end
    end
  end
end
