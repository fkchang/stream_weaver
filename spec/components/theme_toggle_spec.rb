# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::ThemeToggle do
  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "flows the component's mode through as the x-data preference fallback" do
      toggle = described_class.new(mode: :light)
      html = render_html(toggle)

      expect(html).to include("localStorage.getItem('sw-theme-preference') || 'light'")
    end
  end
end
