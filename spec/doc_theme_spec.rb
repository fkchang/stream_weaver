# frozen_string_literal: true

RSpec.describe "Doc theme (sw-theme-doc)" do
  def render_app(app)
    state = {}
    app.rebuild_with_state(state)
    adapter = StreamWeaver::Adapter::AlpineJS.new
    StreamWeaver::Views::AppView.new(app, state, adapter).call
  end

  describe "body class" do
    it "applies sw-theme-doc class to body when theme: :doc is used" do
      a = StreamWeaver::App.new("Title", theme: :doc) {}
      html = render_app(a)
      expect(html).to match(/class="[^"]*sw-theme-doc(?!ument)[^"]*"/)
    end
  end

  describe "CSS token block presence" do
    it "doc CSS block is emitted in the page stylesheet" do
      a = StreamWeaver::App.new("Title", theme: :doc) {}
      html = render_app(a)
      expect(html).to include("body.sw-theme-doc {")
      expect(html).to include("--sw-color-bg: #F5F4EF")
      expect(html).to include("--sw-color-accent: #1E4ED8")
      expect(html).to include("Charter")
      expect(html).to include("SFMono-Regular")
      expect(html).to include("--sw-font-size-base: 15px")
      expect(html).to include("body.sw-theme-doc h2")
      expect(html).to include("1.45rem")
      expect(html).to include("margin-bottom: 52px")
    end
  end

  describe "dark mode" do
    it "doc dark-mode CSS overrides are emitted in the page stylesheet" do
      a = StreamWeaver::App.new("Title", theme: :doc) {}
      html = render_app(a)
      expect(html).to include('html[data-sw-theme="dark"] body.sw-theme-doc {')
      expect(html).to include("--sw-color-bg: #1A1714")
      expect(html).to include("--sw-color-bg-card: #232019")
      expect(html).to include("--sw-color-text: #ECEAE3")
      expect(html).to include("--sw-color-accent: #6699FF")
      expect(html).to include("--sw-color-border: #3A352D")
      expect(html).to include("--sw-color-bg-elevated: #2A251F")
    end
  end

  describe "code block contrast" do
    # Forrest, live UAT screenshot 2026-09-03: doc-theme code blocks were
    # washed-out pastel-on-light -- .sw-code-block reads --sw-surface,
    # which theme.rb bridges to the doc theme's own warm near-white
    # --sw-color-bg-card, and Prism's tomorrow-theme token colors assume a
    # dark background that light card colour never provided. Fixed with a
    # doc-theme-scoped override (its own --sw-doc-code-* tokens) that
    # always renders code blocks in the dark reverse-video scheme,
    # regardless of the page's own light/dark toggle.
    it "forces a dark .sw-code-block background, scoped to the doc theme" do
      a = StreamWeaver::App.new("Title", theme: :doc) {}
      html = render_app(a)
      expect(html).to include("--sw-doc-code-bg: #1e1e1e")
      expect(html).to include("body.sw-theme-doc .sw-code-block {")
      expect(html).to include("background: var(--sw-doc-code-bg)")
    end

    it "sets light text on the dark code block background" do
      a = StreamWeaver::App.new("Title", theme: :doc) {}
      html = render_app(a)
      expect(html).to include("--sw-doc-code-text: #d4d4d4")
      expect(html).to include("body.sw-theme-doc .sw-code-block__pre")
      expect(html).to include("color: var(--sw-doc-code-text)")
    end

    # The page stylesheet is one master CSS block covering every built-in
    # theme (themes differ by body class, not by what's emitted server-side)
    # -- so the real scope check is that no OTHER theme's selector picked up
    # the same override, not that the doc-theme rule is merely present.
    it "does not restyle .sw-code-block under any other theme's selector" do
      a = StreamWeaver::App.new("Title", theme: :default) {}
      html = render_app(a)
      expect(html).not_to include("body.sw-theme-default .sw-code-block")
      expect(html).not_to include("body.sw-theme-dashboard .sw-code-block")
      expect(html).not_to include("body.sw-theme-document .sw-code-block")
    end
  end

  describe "theme isolation" do
    it "body class is sw-theme-default when theme: :default — doc class absent" do
      a = StreamWeaver::App.new("Title", theme: :default) {}
      html = render_app(a)
      expect(html).to include("sw-theme-default")
      expect(html).not_to match(/class="[^"]*sw-theme-doc[^"]*"/)
    end

    it "body class is sw-theme-dashboard when theme: :dashboard — doc class absent" do
      a = StreamWeaver::App.new("Title", theme: :dashboard) {}
      html = render_app(a)
      expect(html).to include("sw-theme-dashboard")
      expect(html).not_to match(/class="[^"]*sw-theme-doc[^"]*"/)
    end

    it "body class is sw-theme-document when theme: :document — doc class absent" do
      a = StreamWeaver::App.new("Title", theme: :document) {}
      html = render_app(a)
      expect(html).to include("sw-theme-document")
      expect(html).not_to match(/class="[^"]*sw-theme-doc(?!ument)[^"]*"/)
    end

    it "sw-theme-default bg token (#f2ede4) still present in CSS" do
      a = StreamWeaver::App.new("Title", theme: :default) {}
      html = render_app(a)
      expect(html).to include("--sw-color-bg: #f2ede4")
    end
  end

  describe "theme registration" do
    it "is a recognized built-in theme" do
      expect(StreamWeaver::App::BUILT_IN_THEMES).to include(:doc)
      expect(StreamWeaver.theme_exists?(:doc)).to be true
    end

    it "boots an app without falling back to :default" do
      a = StreamWeaver::App.new("Title", theme: :doc) {}
      expect(a.theme).to eq(:doc)
    end

    it "is available to ThemeSwitcher via all_themes_for_switcher" do
      switcher_entry = StreamWeaver.all_themes_for_switcher.find { |t| t[:id] == :doc }
      expect(switcher_entry).not_to be_nil
      expect(switcher_entry[:label]).to eq("Doc")
    end
  end
end
