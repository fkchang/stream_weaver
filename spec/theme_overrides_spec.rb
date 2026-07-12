# frozen_string_literal: true

RSpec.describe "theme_overrides (stream_weaver-ckz)" do
  def render_app(app)
    state = {}
    app.rebuild_with_state(state)
    adapter = StreamWeaver::Adapter::AlpineJS.new
    StreamWeaver::Views::AppView.new(app, state, adapter).call
  end

  describe "specificity vs. a non-default built-in theme" do
    it "scopes the override selector to body.sw-theme-<active theme> so it wins over the built-in theme's own rule" do
      app = StreamWeaver::App.new("Title", theme: :dashboard,
                                            theme_overrides: { color_primary: "#D97706" }) {}
      html = render_app(app)

      expect(html).to include("body.sw-theme-dashboard { --sw-color-primary: #D97706; }")

      # Source order: the built-in theme block (emitted in <head>) must come
      # before the override block (emitted in <body>) so that with equal
      # specificity, cascade order lets the override win.
      builtin_index = html.index("body.sw-theme-dashboard {\n")
      override_index = html.index("body.sw-theme-dashboard { --sw-color-primary: #D97706; }")
      expect(builtin_index).not_to be_nil
      expect(override_index).to be > builtin_index
    end

    it "scopes to whichever built-in theme is active, not always :dashboard" do
      app = StreamWeaver::App.new("Title", theme: :document,
                                            theme_overrides: { color_primary: "#D97706" }) {}
      html = render_app(app)

      expect(html).to include("body.sw-theme-document { --sw-color-primary: #D97706; }")
    end
  end

  describe "no-theme-overrides case" do
    it "renders nothing extra when theme_overrides is empty" do
      app = StreamWeaver::App.new("Title", theme: :dashboard) {}
      html = render_app(app)

      expect(html).not_to include("--sw-color-primary: #D97706")
    end
  end

  describe "surface tokens actually reach card/callout/alert/modal (FAC-9u2)" do
    it "master_theme_css bridges --card/--popover/--border on body, not just :root" do
      # :root is <html>, an ancestor of <body> -- the --sw-color-* tokens
      # theme_overrides: sets are declared on body, so a :root-only bridge can
      # never see them and stays stuck on its light-mode fallback. The bridge
      # must be re-declared on body itself to pick up an app's actual theme.
      css = StreamWeaver::Views::AppView.master_theme_css
      expect(css).to match(/body\s*\{[^}]*--card: var\(--sw-color-bg-card/m)
      expect(css).to match(/body\s*\{[^}]*--popover: var\(--sw-color-bg-card/m)
      expect(css).to match(/body\s*\{[^}]*--border: var\(--sw-color-border/m)
    end

    it "a dark theme_overrides color_bg_card renders both the body-scoped --card bridge and the override, with the override emitted after it" do
      app = StreamWeaver::App.new("Title", theme: :default,
                                            theme_overrides: { color_bg_card: "#1A1208", color_text: "#F5E6C8" }) {}
      html = render_app(app)

      card_bridge_index = html.index("--card: var(--sw-color-bg-card")
      override_index = html.index("--sw-color-bg-card: #1A1208;")
      expect(card_bridge_index).not_to be_nil
      expect(override_index).not_to be_nil
      expect(html).to include("body.sw-theme-default {")
      # Both are body-scoped custom properties on the same element -- as long
      # as the override actually renders (proven above by theme_overrides_spec),
      # --card's var(--sw-color-bg-card) lookup on body resolves to it
      # regardless of which rule's source order wins, because var() always
      # reads the current element's already-cascaded value of the referenced
      # property, not the declaring rule's own specificity.
      expect(html).to include("#1A1208")
    end
  end

  describe "unknown override token" do
    it "warns loudly when an override key matches no known VARIABLE_SCHEMA token" do
      app = StreamWeaver::App.new("Title", theme: :dashboard,
                                            theme_overrides: { not_a_real_token: "nope" }) {}

      expect { render_app(app) }.to output(/Unknown theme override token.*not_a_real_token/).to_stderr
    end

    it "does not warn for a known token" do
      app = StreamWeaver::App.new("Title", theme: :dashboard,
                                            theme_overrides: { color_primary: "#D97706" }) {}

      expect { render_app(app) }.not_to output.to_stderr
    end
  end
end
