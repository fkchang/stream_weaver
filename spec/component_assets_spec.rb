# frozen_string_literal: true

require 'tempfile'
require 'tmpdir'

RSpec.describe "Component-scoped CSS/JS macros" do
  # ---------------------------------------------------------------
  # Test component classes
  # ---------------------------------------------------------------
  class AssetTestBannerWithInlineCss < StreamWeaver::Components::Base
    css ".asset-test-banner { color: red; }"
    css ".asset-test-banner:hover { color: blue; }"

    def render(view, _state)
      view.div(class: "asset-test-banner") {}
    end

    def children; []; end
  end

  class AssetTestChild < StreamWeaver::Components::Base
    css ".asset-test-child { margin: 0; }"

    def render(view, _state); end
    def children; []; end
  end

  class AssetTestParent < StreamWeaver::Components::Base
    def render(view, state)
      children.each { |c| c.render(view, state) }
    end

    def children; @children ||= []; end
    def children=(ch); @children = ch; end
  end

  describe StreamWeaver::Components::Base do
    describe ".css" do
      it "accumulates inline CSS strings" do
        expect(AssetTestBannerWithInlineCss.component_css_strings).to eq([
          ".asset-test-banner { color: red; }",
          ".asset-test-banner:hover { color: blue; }"
        ])
      end

      it "does not bleed between sibling classes" do
        expect(AssetTestChild.component_css_strings).to eq([".asset-test-child { margin: 0; }"])
      end

      it "returns empty array for classes with no css declared" do
        expect(AssetTestParent.component_css_strings).to eq([])
      end
    end

    describe ".css_path" do
      it "stores the path and registers it in ComponentAssets" do
        Dir.mktmpdir do |dir|
          css_file = File.join(dir, "test.css")
          File.write(css_file, ".foo { color: green; }")

          klass = Class.new(StreamWeaver::Components::Base) do
            def render(view, _state); end
            def children; []; end
          end
          klass.css_path(css_file)

          expect(klass.component_css_path).to eq(css_file)
          key = StreamWeaver::ComponentAssets.file_key(css_file)
          expect(StreamWeaver::ComponentAssets.resolve_file(key)).to eq(css_file)
        end
      end
    end

    describe ".js_path" do
      it "stores the path and registers it in ComponentAssets" do
        Dir.mktmpdir do |dir|
          js_file = File.join(dir, "widget.js")
          File.write(js_file, "console.log('hi')")

          klass = Class.new(StreamWeaver::Components::Base) do
            def render(view, _state); end
            def children; []; end
          end
          klass.js_path(js_file)

          expect(klass.component_js_path).to eq(js_file)
        end
      end
    end
  end

  describe StreamWeaver::ComponentAssets do
    describe ".assets" do
      it "collects inline CSS from a flat list of components, as unlayered user CSS" do
        components = [
          AssetTestBannerWithInlineCss.new,
          AssetTestChild.new
        ]
        assets = StreamWeaver::ComponentAssets.assets(components)
        expect(assets.user_css).to include(".asset-test-banner { color: red; }")
        expect(assets.user_css).to include(".asset-test-child { margin: 0; }")
        expect(assets.framework_css).to be_empty
      end

      it "deduplicates — same class appearing twice only yields its CSS once" do
        components = [
          AssetTestBannerWithInlineCss.new,
          AssetTestBannerWithInlineCss.new
        ]
        count = StreamWeaver::ComponentAssets.assets(components).user_css.count(".asset-test-banner { color: red; }")
        expect(count).to eq(1)
      end

      it "recurses into children" do
        parent = AssetTestParent.new
        parent.children = [AssetTestChild.new]
        expect(StreamWeaver::ComponentAssets.assets([parent]).user_css).to include(".asset-test-child { margin: 0; }")
      end

      it "returns empty buckets when no assets declared" do
        parent = AssetTestParent.new
        assets = StreamWeaver::ComponentAssets.assets([parent])
        expect([assets.user_css, assets.framework_css, assets.stylesheets, assets.scripts, assets.fonts]).to all(be_empty)
      end

      it "keeps layered (framework) CSS apart, and carries files and fonts" do
        Dir.mktmpdir do |dir|
          css_file = File.join(dir, "w.css")
          js_file = File.join(dir, "w.js")
          File.write(css_file, ".w{}")
          File.write(js_file, "")
          klass = Class.new(StreamWeaver::Components::Base) do
            css ".framework-w {}", layered: true
            def render(view, _state); end
            def children; []; end
          end
          klass.css_path(css_file)
          klass.js_path(js_file)
          klass.font(family: "Probe", src: File.join(dir, "probe.woff2"))

          assets = StreamWeaver::ComponentAssets.assets([klass.new])
          expect(assets.framework_css).to eq([".framework-w {}"])
          expect(assets.stylesheets).to eq([css_file])
          expect(assets.scripts).to eq([js_file])
          expect(assets.fonts).to eq([{ family: "Probe", src: File.join(dir, "probe.woff2") }])
        end
      end
    end

    describe ".font" do
      it "resolves a relative src against the file that declares the component" do
        klass = Class.new(StreamWeaver::Components::Base) { font family: "Rel", src: "fonts/rel.woff2" }
        expect(klass.component_fonts).to eq([{ family: "Rel", src: File.expand_path("fonts/rel.woff2", __dir__) }])
      end
    end

    describe ".file_key / .resolve_file" do
      it "round-trips a registered path" do
        Dir.mktmpdir do |dir|
          path = File.join(dir, "my.css")
          File.write(path, "/* ok */")
          key = StreamWeaver::ComponentAssets.register_file(path)
          expect(StreamWeaver::ComponentAssets.resolve_file(key)).to eq(path)
        end
      end
    end
  end

  describe "HTML rendering — inline CSS injected into <head>" do
    # Build an app with the given components pre-set, bypassing rebuild_with_state
    # (which would replace the render state). The AppView only reads app.components.
    def render_with_components(*components)
      a = StreamWeaver::App.new("Test") {}
      a.components = components
      adapter = StreamWeaver::Adapter::AlpineJS.new
      StreamWeaver::Views::AppView.new(a, {}, adapter).call
    end

    it "emits one <style> tag per class with inline css" do
      html = render_with_components(AssetTestBannerWithInlineCss.new)
      expect(html).to include(".asset-test-banner { color: red; }")
      expect(html).to include(".asset-test-banner:hover { color: blue; }")
    end

    it "does not duplicate when the same component class appears multiple times" do
      html = render_with_components(
        AssetTestBannerWithInlineCss.new,
        AssetTestBannerWithInlineCss.new
      )
      count = html.scan(".asset-test-banner { color: red; }").length
      expect(count).to eq(1)
    end

    it "emits a <link> tag for css_path components" do
      Dir.mktmpdir do |dir|
        css_file = File.join(dir, "path_component.css")
        File.write(css_file, ".path-thing { color: purple; }")

        klass = Class.new(StreamWeaver::Components::Base) do
          def render(v, _s); end
          def children; []; end
        end
        klass.css_path(css_file)

        html = render_with_components(klass.new)
        expect(html).to match(%r{<link [^>]*rel="stylesheet"[^>]*/sw-asset/[a-f0-9]+/path_component\.css})
      end
    end
  end
end
