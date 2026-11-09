# frozen_string_literal: true

require "rack/test"

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

    # A registered theme's body wears its base theme's class too
    # ('sw-theme-document sw-theme-harbor'), so a regex that rewrites one
    # sw-theme-* class leaves the other behind. The server's answer is the
    # class set; the page keeps only its own non-theme classes.
    it "takes the theme classes from the POST /theme response instead of rewriting one class" do
      html = CGI.unescapeHTML(render_html(described_class.new))

      expect(html).not_to include("replace(/sw-theme-")
      expect(html).to include("fetch('/theme/' + id, {method: 'POST'")
      expect(html).to include("filter(c => !c.startsWith('sw-theme-'))")
      expect(html).to include("document.body.className = [...new Set([...classes.split(' '), ...kept])]")
    end
  end

  describe "POST /theme/:name" do
    include Rack::Test::Methods

    before do
      StreamWeaver.register_theme :switcher_spec_harbor, { color_primary: "#0e7490" }, base: :document
    end
    after { StreamWeaver.themes.delete(:switcher_spec_harbor) }

    def app
      StreamWeaver::SinatraApp.create(StreamWeaver::App.new("Switcher") { theme_switcher })
    end

    it "answers a registered theme with its base class and its own" do
      post "/theme/switcher_spec_harbor"

      expect(last_response.status).to eq(200)
      expect(last_response.body.split).to include("sw-theme-document", "sw-theme-switcher_spec_harbor")
    end

    it "answers a built-in theme with that theme's class alone" do
      post "/theme/dark"

      expect(last_response.body.split.grep(/\Asw-theme-/)).to eq(["sw-theme-dark"])
    end
  end
end
