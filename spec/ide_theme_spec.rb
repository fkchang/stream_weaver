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
    %w[chrome workspace header elevated border border2 hover input text muted hint
       accent accent-hover on-accent blue gold green red shadow]
  end

  let(:html) { render_app(StreamWeaver::App.new("Title", theme: :ide) {}) }

  describe "registration" do
    it "is a recognized built-in theme" do
      expect(StreamWeaver.built_in_themes).to include(:ide)
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
      expect(light).to include("--ide-font-sans: 'Geist Variable'")
      expect(light).to include("--ide-font-mono: 'JetBrains Mono'")
    end
  end

  describe "dark palette" do
    let(:dark_selector) { %(html.dark body.sw-theme-ide,\nhtml[data-sw-theme="dark"] body.sw-theme-ide {) }
    let(:dark) { rule(html, dark_selector) }

    # Same specificity question as the mapping below: the generic dark
    # palette (html.dark body) must come first so the IDE rule wins the
    # cascade even where the two tie.
    it "comes after the generic html.dark body palette" do
      generic = html.index("html.dark body {")
      expect(generic).not_to be_nil
      expect(html.index(dark_selector)).to be > generic
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
    let(:geist) { "https://cdn.jsdelivr.net/npm/@fontsource-variable/geist@5.2.8/index.css" }

    it "loads a version-pinned Geist stylesheet and JetBrains Mono through the fonts path" do
      expect(html).to include(%(<link rel="stylesheet" href="#{geist}">))
      expect(html).to include(StreamWeaver::Fonts.google_fonts_href(["JetBrains+Mono:wght@400;500;600;700"]))
    end

    it "merges the theme's fonts with the app's own" do
      page = render_app(StreamWeaver::App.new("Title", theme: :ide, fonts: ["Orbitron:wght@700"]) {})
      expect(page).to include("family=Orbitron:wght@700&family=JetBrains+Mono")
    end

    it "does not load them for other themes" do
      other = render_app(StreamWeaver::App.new("Title", theme: :doc) {})
      expect(other).not_to include("fontsource-variable/geist")
      expect(other).not_to include("JetBrains+Mono")
    end
  end

  # The page stylesheet carries every built-in theme, so the scope check is
  # that no other theme's selector picked up an --ide-* token.
  describe "theme isolation" do
    it "keeps --ide-* tokens inside sw-theme-ide selectors" do
      other = render_app(StreamWeaver::App.new("Title", theme: :doc) {})
      ide_rules = other.scan(/([^{}]*)\{([^{}]*)\}/).select { |_selector, body| body.include?("--ide-") }
      expect(ide_rules).not_to be_empty
      ide_rules.each { |selector, _body| expect(selector).to include("body.sw-theme-ide") }
    end

    it "gives a :doc page no sw-theme-ide body class" do
      other = render_app(StreamWeaver::App.new("Title", theme: :doc) {})
      expect(other).not_to match(/<body[^>]*class="[^"]*\bsw-theme-ide\b/)
    end
  end
end
