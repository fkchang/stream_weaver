# frozen_string_literal: true

RSpec.describe StreamWeaver::Components::ThemeSwitcher do
  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "sets data-sw-theme (in addition to the .dark class) so mermaid re-renders on toggle" do
      switcher = described_class.new
      html = render_html(switcher)

      expect(html).to include("setAttribute('data-sw-theme'")
    end
  end
end
