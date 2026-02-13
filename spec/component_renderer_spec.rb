# frozen_string_literal: true

RSpec.describe StreamWeaver::ComponentRenderer do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

  describe ".render_html" do
    it "renders a single component to HTML" do
      components = [StreamWeaver::Components::Text.new("Hello world")]
      html = described_class.render_html(adapter, components)

      expect(html).to include("Hello world")
    end

    it "renders multiple components" do
      components = [
        StreamWeaver::Components::Text.new("First"),
        StreamWeaver::Components::Text.new("Second")
      ]
      html = described_class.render_html(adapter, components)

      expect(html).to include("First")
      expect(html).to include("Second")
    end

    it "renders nested components (card with children)" do
      card = StreamWeaver::Components::Card.new
      card.children = [
        StreamWeaver::Components::StatDisplay.new(value: 42, label: "COUNT", color: :blue, size: :md)
      ]
      html = described_class.render_html(adapter, [card])

      expect(html).to include("42")
      expect(html).to include("COUNT")
      expect(html).to include("card")
    end

    it "defaults adapter to AlpineJS when nil" do
      components = [StreamWeaver::Components::Text.new("test")]
      html = described_class.render_html(nil, components)

      expect(html).to include("test")
    end

    it "returns a String" do
      html = described_class.render_html(adapter, [])
      expect(html).to be_a(String)
    end
  end

  describe "instance" do
    it "has an adapter reader" do
      renderer = described_class.new(adapter, [])
      expect(renderer.adapter).to eq(adapter)
    end

    it "renders components via view_template" do
      components = [StreamWeaver::Components::Badge.new("5", variant: :danger, size: :sm)]
      html = described_class.new(adapter, components).call

      expect(html).to include("5")
    end
  end
end
