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
