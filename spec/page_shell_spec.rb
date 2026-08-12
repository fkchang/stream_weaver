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

  it "loads standalone without requiring the full stream_weaver.rb entrypoint" do
    lib_path = File.expand_path("../lib", __dir__)
    cmd = "ruby -I#{lib_path} -r stream_weaver/page_shell -e 'print StreamWeaver::PageShell.framework_css_html.bytesize'"
    out = `#{cmd}`
    expect($?).to be_success
    expect(out.to_i).to be > 0
  end
end
