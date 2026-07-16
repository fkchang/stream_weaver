# frozen_string_literal: true

RSpec.describe "framework CSS lives in @layer stream-weaver (stream_weaver-oeo)" do
  def render_app(app)
    state = {}
    app.rebuild_with_state(state)
    adapter = StreamWeaver::Adapter::AlpineJS.new
    StreamWeaver::Views::AppView.new(app, state, adapter).call
  end

  it "pins layer order with a bare @layer statement in the very first <style> tag in <head>" do
    app = StreamWeaver::App.new("Title") { text "hi" }
    html = render_app(app)
    head, = html.split("</head>", 2)

    first_style_index = head.index("<style>")
    expect(first_style_index).not_to be_nil
    expect(head[first_style_index, 60]).to include("@layer stream-weaver;")
  end

  it "wraps master_theme_css in @layer stream-weaver" do
    app = StreamWeaver::App.new("Title") { text "hi" }
    html = render_app(app)
    head, = html.split("</head>", 2)

    expect(head).to match(/@layer stream-weaver \{[^}]*:root \{/m)
  end

  it "wraps component-injected CSS (e.g. callout) in @layer stream-weaver" do
    app = StreamWeaver::App.new("Title") { callout "Heads up", variant: :info }
    html = render_app(app)
    head, = html.split("</head>", 2)

    layer_open = head.index("@layer stream-weaver {")
    callout_index = head.index(".sw-callout")
    layer_close = head.index("\n}", callout_index)
    expect(layer_open).not_to be_nil
    expect(callout_index).to be > layer_open
    expect(layer_close).not_to be_nil
  end

  it "does not wrap user stylesheets: (a plain <link>, always unlayered per the CSS spec)" do
    app = StreamWeaver::App.new("Title", stylesheets: ["/my-app.css"]) { text "hi" }
    html = render_app(app)
    head, = html.split("</head>", 2)

    expect(head).to include('<link rel="stylesheet" href="/my-app.css">')
    # Sanity: the link tag itself is never inside an @layer block (links aren't
    # CSS text at all, so this is really just confirming no accidental wrapping
    # happened around it in the surrounding markup).
    link_index = head.index('href="/my-app.css"')
    surrounding = head[[link_index - 30, 0].max...link_index]
    expect(surrounding).not_to include("@layer")
  end

  it "does not wrap user-declared component CSS (the css/css_path class macro)" do
    custom_class = Class.new(StreamWeaver::Components::Base) do
      css ".my-custom-widget { color: red; }"

      def render(view, _state)
        view.div(class: "my-custom-widget") {}
      end

      def children
        []
      end
    end

    # Bypasses rebuild_with_state (which would re-evaluate the DSL block and
    # discard this manually-set component list) -- same pattern as
    # component_assets_spec.rb's render_with_components.
    app = StreamWeaver::App.new("Title") {}
    app.components = [custom_class.new]
    adapter = StreamWeaver::Adapter::AlpineJS.new
    html = StreamWeaver::Views::AppView.new(app, {}, adapter).call

    expect(html).to include(".my-custom-widget { color: red; }")
    layer_wrapped = html[/@layer stream-weaver \{.*?\n\}/m]
    expect(layer_wrapped.to_s).not_to include(".my-custom-widget")
  end

  it "theme_overrides still beat theme_preset tokens for the same custom property, inside the shared layer" do
    app = StreamWeaver::App.new("Title", theme_overrides: { color_primary: "#ff00ff" }) do
      theme_preset :editorial
      text "hi"
    end
    html = render_app(app)

    override_index = html.index("--sw-color-primary: #ff00ff;")
    expect(override_index).not_to be_nil

    # Both blocks live in the shared layer -- no sub-layering needed, since
    # the override targets `body.sw-theme-*` directly while the preset sets
    # `:root`/`html.dark`; body's own directly-declared value always beats
    # an inherited value from an ancestor selector, regardless of cascade
    # layer or specificity (stream_weaver-oeo commit message has the full
    # writeup).
    expect(html).to match(/@layer stream-weaver \{[^@]*--sw-color-primary: #ff00ff;/m)
  end
end
