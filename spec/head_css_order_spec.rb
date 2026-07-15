# frozen_string_literal: true

RSpec.describe "framework component CSS hoisted to <head> (stream_weaver-1lo)" do
  def render_app(app)
    state = {}
    app.rebuild_with_state(state)
    adapter = StreamWeaver::Adapter::AlpineJS.new
    StreamWeaver::Views::AppView.new(app, state, adapter).call
  end

  it "emits a component's injected CSS in <head>, before user stylesheets:" do
    app = StreamWeaver::App.new("Title", stylesheets: ["/my-app.css"]) do
      callout "Heads up", variant: :info
    end
    html = render_app(app)

    head, body = html.split("</head>", 2)
    expect(head).to include(".sw-callout")

    stylesheet_index = head.index('href="/my-app.css"')
    css_index = head.index(".sw-callout")
    expect(stylesheet_index).not_to be_nil
    expect(css_index).to be < stylesheet_index

    # Not re-emitted inline in the body -- it already lives in <head>.
    expect(body).not_to include(".sw-callout {")
  end

  it "dedupes a component's CSS across multiple instances on the same page" do
    app = StreamWeaver::App.new("Title") do
      callout "First", variant: :info
      callout "Second", variant: :warning
    end
    html = render_app(app)

    expect(html.scan("Callout Styles (sw- prefix").size).to eq(1)
  end

  it "fragment renders still inject CSS inline (no <head> to hoist into)" do
    app = StreamWeaver::App.new("Title") do
      callout "Heads up", variant: :info
    end
    state = {}
    app.rebuild_with_state(state)
    adapter = StreamWeaver::Adapter::AlpineJS.new
    content_html = StreamWeaver::Views::AppContentView.new(app, state, adapter).call

    expect(content_html).to include(".sw-callout {")
  end
end
