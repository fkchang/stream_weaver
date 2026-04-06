# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::Card do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:mock_view) { double("view", adapter: adapter) }
  let(:state) { {} }

  describe "depth option" do
    it "renders default card without depth class when no depth specified" do
      card = described_class.new
      expect(mock_view).to receive(:div).with(class: "card").and_yield
      card.render(mock_view, state)
    end

    it "renders hero depth with sw-card--hero class" do
      card = described_class.new(depth: :hero)
      expect(mock_view).to receive(:div).with(class: "card sw-card--hero").and_yield
      card.render(mock_view, state)
    end

    it "renders elevated depth with sw-card--elevated class" do
      card = described_class.new(depth: :elevated)
      expect(mock_view).to receive(:div).with(class: "card sw-card--elevated").and_yield
      card.render(mock_view, state)
    end

    it "renders default depth with sw-card--default class" do
      card = described_class.new(depth: :default)
      expect(mock_view).to receive(:div).with(class: "card sw-card--default").and_yield
      card.render(mock_view, state)
    end

    it "renders recessed depth with sw-card--recessed class" do
      card = described_class.new(depth: :recessed)
      expect(mock_view).to receive(:div).with(class: "card sw-card--recessed").and_yield
      card.render(mock_view, state)
    end

    it "renders glass depth with sw-card--glass class" do
      card = described_class.new(depth: :glass)
      expect(mock_view).to receive(:div).with(class: "card sw-card--glass").and_yield
      card.render(mock_view, state)
    end

    it "ignores invalid depth values" do
      card = described_class.new(depth: :invalid)
      expect(mock_view).to receive(:div).with(class: "card").and_yield
      card.render(mock_view, state)
    end

    it "exposes depth via attr_reader" do
      card = described_class.new(depth: :hero)
      expect(card.depth).to eq(:hero)
    end
  end

  describe "accent option" do
    it "renders accent :a with sw-card--accent-a class" do
      card = described_class.new(accent: :a)
      expect(mock_view).to receive(:div).with(class: "card sw-card--accent-a").and_yield
      card.render(mock_view, state)
    end

    it "renders accent :b with sw-card--accent-b class" do
      card = described_class.new(accent: :b)
      expect(mock_view).to receive(:div).with(class: "card sw-card--accent-b").and_yield
      card.render(mock_view, state)
    end

    it "renders accent :c with sw-card--accent-c class" do
      card = described_class.new(accent: :c)
      expect(mock_view).to receive(:div).with(class: "card sw-card--accent-c").and_yield
      card.render(mock_view, state)
    end

    it "renders custom CSS color accent with inline style" do
      card = described_class.new(accent: "#ff6600")
      expect(mock_view).to receive(:div).with(
        class: "card sw-card--accent",
        style: "border-left-color: #ff6600;"
      ).and_yield
      card.render(mock_view, state)
    end

    it "exposes accent via attr_reader" do
      card = described_class.new(accent: :a)
      expect(card.accent).to eq(:a)
    end
  end

  describe "label option" do
    it "renders a corner label span when label is provided" do
      card = described_class.new(label: "RISK")
      expect(mock_view).to receive(:div).with(class: "card", style: "position: relative;").and_yield
      expect(mock_view).to receive(:span).with(class: "sw-card__label").and_yield
      card.render(mock_view, state)
    end

    it "does not render label span when label is nil" do
      card = described_class.new
      expect(mock_view).to receive(:div).with(class: "card").and_yield
      expect(mock_view).not_to receive(:span).with(class: "sw-card__label")
      card.render(mock_view, state)
    end

    it "exposes label via attr_reader" do
      card = described_class.new(label: "NEW")
      expect(card.label).to eq("NEW")
    end
  end

  describe "combined options" do
    it "renders depth + accent together" do
      card = described_class.new(depth: :hero, accent: :a)
      expect(mock_view).to receive(:div).with(
        class: "card sw-card--hero sw-card--accent-a"
      ).and_yield
      card.render(mock_view, state)
    end

    it "renders depth + accent + custom class" do
      card = described_class.new(depth: :elevated, accent: :b, class: "my-card")
      expect(mock_view).to receive(:div).with(
        class: "card sw-card--elevated sw-card--accent-b my-card"
      ).and_yield
      card.render(mock_view, state)
    end

    it "renders depth + label + children" do
      card = described_class.new(depth: :recessed, label: "WARN")
      child = StreamWeaver::Components::Text.new("content")
      card.children = [child]

      expect(mock_view).to receive(:div).with(
        class: "card sw-card--recessed",
        style: "position: relative;"
      ).and_yield
      expect(mock_view).to receive(:span).with(class: "sw-card__label").and_yield
      expect(child).to receive(:render).with(mock_view, state)

      card.render(mock_view, state)
    end
  end

  describe "backward compatibility" do
    it "works with no arguments" do
      card = described_class.new
      expect(card.children).to eq([])
      expect(card.depth).to be_nil
      expect(card.accent).to be_nil
      expect(card.label).to be_nil
    end

    it "still accepts class: option" do
      card = described_class.new(class: "question-card")
      expect(mock_view).to receive(:div).with(class: "card question-card").and_yield
      card.render(mock_view, state)
    end

    it "still renders children" do
      card = described_class.new
      child1 = StreamWeaver::Components::Text.new("Child 1")
      child2 = StreamWeaver::Components::Text.new("Child 2")
      card.children = [child1, child2]

      expect(mock_view).to receive(:div).and_yield
      expect(child1).to receive(:render).with(mock_view, state)
      expect(child2).to receive(:render).with(mock_view, state)

      card.render(mock_view, state)
    end
  end

  describe "CSS classes use sw- prefix" do
    it "all depth classes use sw- prefix" do
      StreamWeaver::Components::Card::VALID_DEPTHS.each do |depth|
        card = described_class.new(depth: depth)
        # Verify the class includes sw-card--{depth}
        classes = []
        allow(mock_view).to receive(:div) do |**attrs, &block|
          classes = attrs[:class].split(" ")
          block&.call
        end
        card.render(mock_view, state)
        depth_class = classes.find { |c| c.start_with?("sw-card--") }
        expect(depth_class).to eq("sw-card--#{depth}")
      end
    end
  end
end
