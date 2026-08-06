# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::Collapsible do
  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders both legacy and sw- prefixed classes by default (backward compat)" do
      collapsible = described_class.new("Details")
      html = render_html(collapsible)

      expect(html).to include('class="collapsible sw-collapsible"')
      expect(html).to include('class="collapsible-header sw-collapsible-header"')
      expect(html).to include('class="collapsible-icon sw-collapsible-icon"')
      expect(html).to include('class="collapsible-label sw-collapsible-label"')
      expect(html).to include('class="collapsible-content sw-collapsible-content"')
    end

    it "reflects expanded: true in the x-data initial state" do
      collapsible = described_class.new("Details", expanded: true)
      html = render_html(collapsible)

      expect(html).to include('x-data="{ open: true }"')
    end

    it "renders the subtitle span when subtitle: is given" do
      collapsible = described_class.new("Details", subtitle: "Extra info")
      html = render_html(collapsible)

      expect(html).to include('class="sw-collapsible-subtitle"')
      expect(html).to include("Extra info")
    end

    it "omits the subtitle span when subtitle: is not given" do
      collapsible = described_class.new("Details")
      html = render_html(collapsible)

      expect(html).not_to include("sw-collapsible-subtitle")
    end

    it "renders a badge reflecting badge_text and badge_variant" do
      collapsible = described_class.new("Details", badge_text: "5 new", badge_variant: :success)
      html = render_html(collapsible)

      expect(html).to include('class="sw-collapsible-badge"')
      expect(html).to include("sw-badge-success")
      expect(html).to include("5 new")
    end

    it "forwards class: and style: options onto the outer div" do
      collapsible = described_class.new("Details", class: "my-extra", style: "margin-top: 1rem;")
      html = render_html(collapsible)

      expect(html).to include('class="collapsible sw-collapsible my-extra"')
      expect(html).to include('style="margin-top: 1rem;"')
    end
  end

  describe "readers" do
    it "exposes label, expanded, subtitle, badge_text, badge_variant, and options" do
      collapsible = described_class.new(
        "Details",
        expanded: true,
        subtitle: "Extra info",
        badge_text: "5 new",
        badge_variant: :success,
        class: "my-extra"
      )

      expect(collapsible.label).to eq("Details")
      expect(collapsible.expanded).to eq(true)
      expect(collapsible.subtitle).to eq("Extra info")
      expect(collapsible.badge_text).to eq("5 new")
      expect(collapsible.badge_variant).to eq(:success)
      expect(collapsible.options).to eq(class: "my-extra")
    end
  end
end
