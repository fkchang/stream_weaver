# frozen_string_literal: true

RSpec.describe "IDE theme (sw-theme-ide)" do
  def render_app(app)
    state = {}
    app.rebuild_with_state(state)
    adapter = StreamWeaver::Adapter::AlpineJS.new
    StreamWeaver::Views::AppView.new(app, state, adapter).call
  end

  # The CSS rule whose selector list starts with `selector`, as one string.
  def rule(html, selector)
    start = html.index(selector) or raise "missing rule #{selector.inspect}"
    html[start, html.index("}", start) - start]
  end

  let(:palette_tokens) do
    %w[chrome elevated border border2 hover input text muted hint
       accent accent-hover on-accent blue gold green red]
  end

  let(:html) { render_app(StreamWeaver::App.new("Title", theme: :ide) {}) }

  describe "registration" do
    it "is a recognized built-in theme" do
      expect(StreamWeaver::App::BUILT_IN_THEMES).to include(:ide)
      expect(StreamWeaver.theme_exists?(:ide)).to be true
    end

    it "is available to the theme switcher" do
      entry = StreamWeaver.all_themes_for_switcher.find { |t| t[:id] == :ide }
      expect(entry[:label]).to eq("IDE")
    end

    it "applies sw-theme-ide to body" do
      expect(html).to match(/<body[^>]*class="[^"]*\bsw-theme-ide\b/)
    end

    it "can be selected from the DSL with use_theme :ide" do
      app = StreamWeaver::App.new("Title") { use_theme :ide }
      expect(render_app(app)).to match(/<body[^>]*class="[^"]*\bsw-theme-ide\b/)
    end
  end

  describe "light palette on body.sw-theme-ide" do
    it "declares every --ide-* palette token" do
      light = rule(html, "body.sw-theme-ide {")
      palette_tokens.each { |t| expect(light).to include("--ide-#{t}:") }
    end

    it "carries the light values" do
      light = rule(html, "body.sw-theme-ide {")
      expect(light).to include("--ide-chrome: #f2f3f5")
      expect(light).to include("--ide-text: #1a1a1e")
      expect(light).to include("--ide-accent: #2e7d16")
    end

    it "uses Geist for text and JetBrains Mono for chrome" do
      light = rule(html, "body.sw-theme-ide {")
      expect(light).to include("--ide-font-sans: 'Geist'")
      expect(light).to include("--ide-font-mono: 'JetBrains Mono'")
    end
  end

  describe "dark palette" do
    let(:dark_selector) { %(html.dark body.sw-theme-ide,\nhtml[data-sw-theme="dark"] body.sw-theme-ide {) }
    let(:dark) { rule(html, dark_selector) }

    it "is declared under html.dark body.sw-theme-ide and the data-sw-theme twin" do
      expect(html).to include(dark_selector)
    end

    it "redeclares every --ide-* palette token with the dark values" do
      palette_tokens.each { |t| expect(dark).to include("--ide-#{t}:") }
      expect(dark).to include("--ide-chrome: #171719")
      expect(dark).to include("--ide-text: #dfe1e5")
      expect(dark).to include("--ide-accent: #8dff4f")
    end
  end

  describe "--sw-* mapping" do
    # html.dark body (views.rb) resets --sw-color-* in dark mode and outranks
    # body.sw-theme-ide, so the mapping must name the dark selectors as well.
    it "maps --sw-* onto --ide-* in both light and dark selectors" do
      mapping = rule(html, "body.sw-theme-ide,\nhtml.dark body.sw-theme-ide,")
      expect(mapping).to include("--sw-color-bg: var(--ide-workspace)")
      expect(mapping).to include("--sw-color-text: var(--ide-text)")
      expect(mapping).to include("--sw-color-accent: var(--ide-accent)")
      expect(mapping).to include("--sw-color-border: var(--ide-border)")
    end
  end

  describe "fonts" do
    it "loads Geist and JetBrains Mono when the theme is active" do
      expect(html).to include(StreamWeaver::Views::AppView::IDE_FONTS_HREF)
    end

    it "does not load them for other themes" do
      other = render_app(StreamWeaver::App.new("Title", theme: :doc) {})
      expect(other).not_to include("family=Geist")
    end
  end

  describe "theme_toggle" do
    it "renders a toggle wired to swToggleTheme, which flips html.dark" do
      page = render_app(StreamWeaver::App.new("Title", theme: :ide) { theme_toggle })
      expect(page).to include("swToggleTheme")
      expect(page).to include("html.classList.toggle('dark'")
    end
  end
end
