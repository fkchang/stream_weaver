# frozen_string_literal: true

require "spec_helper"

RSpec.describe StreamWeaver::PageShell do
  describe ".framework_css_html" do
    let(:html) { described_class.framework_css_html }

    it "pins the cascade layer before any framework CSS" do
      expect(html).to start_with("<style>@layer stream-weaver;</style>")
    end

    it "wraps CANVAS_CSS, master_theme_css, and visual_skills_css in that layer, in order" do
      # Markers unique to each block's own emitted CSS (not the comments --
      # CANVAS_CSS's :root comment mentions master_theme_css by name, so a
      # comment-text marker would false-positive). Same assertion shape as
      # spec/canvas/theme_support_spec.rb's regression guard, asserted here
      # directly against the module instead of only through a canvas request.
      canvas_marker = html.index("--sw-radius-md")
      theme_marker  = html.index("shadcn Token Layer")
      skills_marker = html.index("--sw-bg")

      expect([canvas_marker, theme_marker, skills_marker]).to all(be_a(Integer))
      expect(canvas_marker).to be < theme_marker
      expect(theme_marker).to be < skills_marker

      layer_open = html.index("@layer stream-weaver {")
      expect(layer_open).to be < canvas_marker
    end

    it "accepts extra_layers and pins them after the framework layer" do
      html = described_class.framework_css_html(extra_layers: %w[sw-reader-chrome])
      expect(html).to start_with("<style>@layer stream-weaver, sw-reader-chrome;</style>")
    end
  end

  describe ".user_css_html" do
    it "emits inline stylesheets unlayered, so they outrank framework CSS" do
      html = described_class.user_css_html(inline_stylesheets: [".x { color: red; }"])
      expect(html).to eq("<style>.x { color: red; }</style>")
      expect(html).not_to include("@layer")
    end

    it "returns an empty string with no inline stylesheets" do
      expect(described_class.user_css_html).to eq("")
    end
  end

  describe StreamWeaver::PageShell::Assets do
    it "merges bucket by bucket, keeping order and dropping repeats" do
      a = described_class.of(fonts: ["Inter"], body_classes: %w[sw-layout-default])
      b = described_class.of(fonts: %w[Inter Geist], body_classes: %w[sw-theme-ide])

      merged = a + b
      expect(merged.fonts).to eq(%w[Inter Geist])
      expect(merged.body_classes).to eq(%w[sw-layout-default sw-theme-ide])
      expect(merged.stylesheets).to eq([])
    end
  end

  describe ".resolve" do
    after { StreamWeaver::LayoutRegistry.instance_variable_get(:@registry).delete(:resolve_spec_exclusive) }

    it "puts the layout class before the theme class" do
      app = StreamWeaver::App.new("p", theme: :doc, layout: :wide) {}
      expect(described_class.resolve(app, theme: app.theme).body_class).to eq("sw-layout-wide sw-theme-doc")
    end

    it "uses the theme it is given, so a session override wins over app.theme" do
      app = StreamWeaver::App.new("p", theme: :doc) {}
      expect(described_class.resolve(app, theme: :ide).body_class).to eq("sw-layout-default sw-theme-ide")
    end

    it "gives an exclusive layout its own body classes instead of sw-layout-*" do
      StreamWeaver.register_layout(:resolve_spec_exclusive, exclusive: true, body_classes: %w[a b]) {}
      app = StreamWeaver::App.new("p", layout: :resolve_spec_exclusive) {}
      expect(described_class.resolve(app, theme: :default).body_class).to eq("a b sw-theme-default")
    end

    it "resolves a host with no App from the theme and layout alone" do
      page = described_class.resolve(nil, theme: :ide, layout: :fluid)
      expect(page.body_class).to eq("sw-layout-fluid sw-theme-ide")
      expect(page.assets.fonts).to eq(StreamWeaver.theme_fonts(:ide))
      expect(page.assets.stylesheets).to eq(StreamWeaver.theme_stylesheets(:ide))
    end

    it "omits the layout class when there is no layout" do
      expect(described_class.resolve(nil, theme: :ide, layout: nil).body_class).to eq("sw-theme-ide")
    end

    it "puts the app's fonts and stylesheets before the theme's, and keeps its CSS and scripts" do
      app = StreamWeaver::App.new("p", theme: :ide, fonts: ["Inter:wght@400"],
                                       stylesheets: ["https://example.test/app.css"],
                                       scripts: ["https://example.test/app.js"]) {}
      app.use_stylesheet(".x { color: red; }")
      assets = described_class.resolve(app, theme: :ide, components: { ide: ".ide{}" }).assets

      expect(assets.fonts).to eq(["Inter:wght@400", *StreamWeaver.theme_fonts(:ide)])
      expect(assets.stylesheets.first).to eq("https://example.test/app.css")
      expect(assets.user_css).to eq([".x { color: red; }"])
      expect(assets.scripts).to eq(["https://example.test/app.js"])
      expect(assets.framework_css).to eq([".ide{}"])
    end
  end

  describe ".head" do
    let(:assets) do
      StreamWeaver::PageShell::Assets.of(
        fonts: ["Inter:wght@400"], stylesheets: ['https://example.test/a.css?x="y"'],
        framework_css: [".c{}", ".d{}"], user_css: [".u{}"], scripts: ["https://example.test/a.js"]
      )
    end
    let(:head) { described_class.head(StreamWeaver::PageShell::Page.new(theme: nil, layout: nil, assets: assets)) }

    it "emits one Google Fonts stylesheet for the declared fonts" do
      expect(head.fonts).to eq('<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400&display=swap">')
    end

    it "escapes attribute quotes the way Phlex does" do
      expect(head.stylesheets).to eq('<link rel="stylesheet" href="https://example.test/a.css?x=&quot;y&quot;">')
    end

    it "layers component CSS in one block and leaves user CSS unlayered" do
      expect(head.framework_css).to eq("<style>#{StreamWeaver::CSS.layer_wrap(".c{}\n.d{}")}</style>")
      expect(head.user_css).to eq("<style>.u{}</style>")
      expect(head.scripts).to eq('<script src="https://example.test/a.js"></script>')
    end

    it "emits nothing for empty buckets" do
      empty = described_class.head(StreamWeaver::PageShell::Page.new(theme: nil, layout: nil,
                                                                     assets: StreamWeaver::PageShell::Assets.of))
      expect(%i[fonts stylesheets framework_css user_css scripts].map { |b| empty.public_send(b) }).to all(eq(""))
    end
  end

  it "loads standalone without requiring the full stream_weaver.rb entrypoint" do
    lib_path = File.expand_path("../lib", __dir__)
    cmd = "ruby -I#{lib_path} -r stream_weaver/page_shell -e 'print StreamWeaver::PageShell.framework_css_html.bytesize'"
    out = `#{cmd}`
    expect($?).to be_success
    expect(out.to_i).to be > 0
  end
end
