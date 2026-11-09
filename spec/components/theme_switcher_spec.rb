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
      expect(html).to include("fetch('/theme/' + encodeURIComponent(id), {method: 'POST'")
      expect(html).to include("filter(c => !c.startsWith('sw-theme-'))")
      expect(html).to include("document.body.className = [...new Set([...classes, ...kept])]")
    end

    it "ignores a response that is not class names, and a failed POST" do
      html = CGI.unescapeHTML(render_html(described_class.new))

      expect(html).to include("classes.every(c => /^[A-Za-z0-9_-]+$/.test(c))) return;")
      expect(html).to include(".catch(() => {})")
    end

    # A registered theme's CSS is on the page only for the theme it was
    # rendered with, so a switch to one reloads; a built-in swaps in place.
    describe "with a registered theme" do
      before { StreamWeaver.register_theme :switcher_spec_markup, {}, base: :document }
      after { StreamWeaver.themes.delete(:switcher_spec_markup) }

      it "reloads for a registered theme and swaps classes in place for a built-in" do
        html = CGI.unescapeHTML(render_html(described_class.new))

        expect(html).to include(%(@click="switchTheme("switcher_spec_markup", true)"))
        expect(html).to include(%(@click="switchTheme("dark", false)"))
        expect(html).to include("if (registered) { window.location.reload(); return; }")
      end
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
  describe "POST /apps/:app_id/theme/:name on Service" do
    include Rack::Test::Methods

    before do
      StreamWeaver.register_theme :switcher_spec_service, { color_primary: "#0e7490" }, base: :document
      StreamWeaver::Service.clear_apps
      StreamWeaver::Service.apps["sw01"] = {
        app: StreamWeaver::App.new("Switcher") { theme_switcher }, path: "switcher.rb",
        name: "Switcher", loaded_at: Time.now, last_accessed: Time.now
      }
    end

    after do
      StreamWeaver::Service.clear_apps
      StreamWeaver.themes.delete(:switcher_spec_service)
    end

    def app
      StreamWeaver::Service
    end

    it "answers a registered theme with its base class and its own, as plain text" do
      post "/apps/sw01/theme/switcher_spec_service"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to start_with("text/plain")
      expect(last_response.body.split).to include("sw-theme-document", "sw-theme-switcher_spec_service")
    end
  end
end
