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
