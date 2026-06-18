# frozen_string_literal: true

RSpec.describe "ImplementationMap Component" do
  describe StreamWeaver::Components::ImplementationMap do
    it "initializes with empty files by default" do
      c = described_class.new
      expect(c.files).to eq([])
    end

    it "normalizes symbol-key hashes" do
      c = described_class.new(files: [{ path: "lib/foo.rb", note: "Core logic" }])
      expect(c.files).to eq([{ path: "lib/foo.rb", note: "Core logic" }])
    end

    it "normalizes string-key hashes" do
      c = described_class.new(files: [{ "path" => "lib/bar.rb", "note" => "Tests" }])
      expect(c.files).to eq([{ path: "lib/bar.rb", note: "Tests" }])
    end

    it "accepts multiple entries" do
      c = described_class.new(files: [
        { path: "lib/a.rb", note: "note a" },
        { path: "lib/b.rb", note: "note b" }
      ])
      expect(c.files.length).to eq(2)
    end
  end

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders sw-impl-map container" do
      c = StreamWeaver::Components::ImplementationMap.new(files: [{ path: "lib/foo.rb", note: "logic" }])
      html = render_html(c)
      expect(html).to include("sw-impl-map")
    end

    it "renders each file path in monospace code element" do
      c = StreamWeaver::Components::ImplementationMap.new(files: [
        { path: "lib/stream_weaver/foo.rb", note: "some note" }
      ])
      html = render_html(c)
      expect(html).to include("<code>")
      expect(html).to include("lib/stream_weaver/foo.rb")
    end

    it "renders the rationale note" do
      c = StreamWeaver::Components::ImplementationMap.new(files: [
        { path: "lib/foo.rb", note: "Core business logic lives here" }
      ])
      html = render_html(c)
      expect(html).to include("Core business logic lives here")
    end

    it "renders file paths with distinct visual treatment (sw-impl-map__path class)" do
      c = StreamWeaver::Components::ImplementationMap.new(files: [{ path: "lib/foo.rb", note: "x" }])
      html = render_html(c)
      expect(html).to include("sw-impl-map__path")
    end

    it "renders notes with muted class (sw-impl-map__note)" do
      c = StreamWeaver::Components::ImplementationMap.new(files: [{ path: "lib/foo.rb", note: "x" }])
      html = render_html(c)
      expect(html).to include("sw-impl-map__note")
    end

    it "renders an icon in the path entry" do
      c = StreamWeaver::Components::ImplementationMap.new(files: [{ path: "lib/foo.rb", note: "x" }])
      html = render_html(c)
      expect(html).to include("sw-impl-map__icon")
    end

    it "renders multiple entries" do
      c = StreamWeaver::Components::ImplementationMap.new(files: [
        { path: "lib/a.rb", note: "note a" },
        { path: "lib/b.rb", note: "note b" }
      ])
      html = render_html(c)
      expect(html).to include("lib/a.rb")
      expect(html).to include("lib/b.rb")
      expect(html).to include("note a")
      expect(html).to include("note b")
    end

    it "renders empty list gracefully" do
      c = StreamWeaver::Components::ImplementationMap.new(files: [])
      html = render_html(c)
      expect(html).to include("sw-impl-map")
    end
  end

  describe "sw- CSS prefix convention" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:css) { adapter.send(:implementation_map_css) }

    it "all CSS class selectors use sw- prefix" do
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") && !l.strip.start_with?("@") && !l.strip.start_with?("html") }
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/\.([\w][\w-]*)/).flatten
      }.uniq

      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"),
          "CSS class '.#{cls}' does not use sw- prefix"
      end
    end

    it "container has overflow-y for scrollability" do
      expect(css).to include("overflow-y")
    end

    it "container has max-height for scrollability" do
      expect(css).to include("max-height")
    end

    it "path code uses monospace font family" do
      expect(css).to include("monospace")
    end
  end

  describe "DisplayDSL#implementation_map" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        implementation_map(files: [{ path: "lib/foo.rb", note: "logic" }])
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ImplementationMap) }
      expect(component).not_to be_nil
      expect(component.files.length).to eq(1)
      expect(component.files.first[:path]).to eq("lib/foo.rb")
    end

    it "renders correctly via DSL" do
      adapter = StreamWeaver::Adapter::AlpineJS.new
      app = StreamWeaver::App.new("Test") do
        implementation_map(files: [
          { path: "lib/foo.rb", note: "Core logic" },
          { path: "spec/foo_spec.rb", note: "Tests" }
        ])
      end
      app.rebuild_with_state({})
      html = StreamWeaver::ComponentRenderer.render_html(adapter, app.components, {})
      expect(html).to include("lib/foo.rb")
      expect(html).to include("spec/foo_spec.rb")
      expect(html).to include("Core logic")
      expect(html).to include("Tests")
    end
  end

  describe "Adapter::Base#render_implementation_map" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_implementation_map(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_implementation_map/)
    end
  end
end
