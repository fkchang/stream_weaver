# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::ExpandableCard do
  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders the title" do
      card = described_class.new(key: :card1, title: "My Card")
      html = render_html(card)

      expect(html).to include('class="sw-expandable-card-title"')
      expect(html).to include("My Card")
    end

    it "renders the subtitle when present" do
      card = described_class.new(key: :card1, title: "My Card", subtitle: "A short blurb")
      html = render_html(card)

      expect(html).to include('class="sw-expandable-card-subtitle"')
      expect(html).to include("A short blurb")
    end

    it "omits the subtitle when not present" do
      card = described_class.new(key: :card1, title: "My Card")
      html = render_html(card)

      expect(html).not_to include("sw-expandable-card-subtitle")
    end

    it "renders a badge with the given text and variant when present" do
      card = described_class.new(key: :card1, title: "My Card", badge_text: "5 activities", badge_variant: :info)
      html = render_html(card)

      expect(html).to include("sw-badge-info")
      expect(html).to include("5 activities")
    end

    it "omits the badge when badge_text is not present" do
      card = described_class.new(key: :card1, title: "My Card")
      html = render_html(card)

      expect(html).not_to include("sw-badge")
    end

    it "renders a status dot when status: is given" do
      card = described_class.new(key: :card1, title: "My Card", status: :red)
      html = render_html(card)

      expect(html).to include("sw-status-dot-red")
    end

    it "omits the status dot when status: is not given" do
      card = described_class.new(key: :card1, title: "My Card")
      html = render_html(card)

      expect(html).not_to include("sw-status-dot")
    end

    it "reflects initially_expanded: true in the initial x-data state" do
      card = described_class.new(key: :card1, title: "My Card", initially_expanded: true)
      html = render_html(card)

      expect(html).to include('x-data="{ expanded: true }"')
    end

    it "defaults to collapsed when initially_expanded is not given" do
      card = described_class.new(key: :card1, title: "My Card")
      html = render_html(card)

      expect(html).to include('x-data="{ expanded: false }"')
    end

    it "always renders the chevron indicator" do
      card = described_class.new(key: :card1, title: "My Card")
      html = render_html(card)

      expect(html).to include('class="sw-expandable-card-chevron"')
    end
  end
end
