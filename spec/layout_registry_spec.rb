# frozen_string_literal: true

RSpec.describe StreamWeaver::LayoutRegistry do
  after do
    StreamWeaver::LayoutRegistry.reset!
  end

  def render_app(app)
    state = {}
    app.rebuild_with_state(state)
    adapter = StreamWeaver::Adapter::AlpineJS.new
    StreamWeaver::Views::AppView.new(app, state, adapter).call
  end

  describe ".register" do
    it "stores the layout by symbol name" do
      StreamWeaver::LayoutRegistry.register(:my_layout) {}
      expect(StreamWeaver::LayoutRegistry.registered?(:my_layout)).to be true
    end

    it "normalises string names to symbols" do
      StreamWeaver::LayoutRegistry.register("str_layout") {}
      expect(StreamWeaver::LayoutRegistry.registered?(:str_layout)).to be true
    end

    it "stores exclusive flag" do
      StreamWeaver::LayoutRegistry.register(:excl, exclusive: true) {}
      expect(StreamWeaver::LayoutRegistry[:excl][:exclusive]).to be true
    end

    it "stores body_classes as array" do
      StreamWeaver::LayoutRegistry.register(:cls, body_classes: %w[foo bar]) {}
      expect(StreamWeaver::LayoutRegistry[:cls][:body_classes]).to eq(%w[foo bar])
    end

    it "stores the render block" do
      blk = proc {}
      StreamWeaver::LayoutRegistry.register(:blk_layout, &blk)
      expect(StreamWeaver::LayoutRegistry[:blk_layout][:render_block]).to eq(blk)
    end
  end

  describe "StreamWeaver.register_layout (public API)" do
    it "delegates to LayoutRegistry.register" do
      expect(StreamWeaver::LayoutRegistry).to receive(:register)
        .with(:my_layout, exclusive: true, body_classes: [], css_path: nil)
      StreamWeaver.register_layout(:my_layout, exclusive: true) {}
    end
  end

  describe "App#layout_slot" do
    it "captures components into the named slot" do
      a = StreamWeaver::App.new("Test") do
        layout_slot(:header) { text "I am the header" }
        text "Main content"
      end
      a.rebuild_with_state({})
      expect(a.layout_slots[:header]).not_to be_empty
      expect(a.layout_slots[:header].first).to be_a(StreamWeaver::Components::Text)
      expect(a.components.first.instance_variable_get(:@content)).to eq("Main content")
    end

    it "does not include slot components in @components" do
      a = StreamWeaver::App.new("Test") do
        layout_slot(:sidebar) { text "Sidebar" }
        text "Body"
      end
      a.rebuild_with_state({})
      expect(a.components.map(&:class)).to eq([StreamWeaver::Components::Text])
    end

    it "resets slots on rebuild_with_state" do
      a = StreamWeaver::App.new("Test") { layout_slot(:header) { text "H" } }
      a.rebuild_with_state({})
      a.rebuild_with_state({})
      # Should still have exactly one component in the slot, not two
      expect(a.layout_slots[:header].length).to eq(1)
    end
  end

  describe "HTML rendering — default (non-exclusive) layout" do
    it "renders the default h1 + #app-container chrome" do
      a = StreamWeaver::App.new("Default Chrome") { text "hello" }
      html = render_app(a)
      expect(html).to include("<h1>")
      expect(html).to include('id="app-container"')
    end

    it "adds sw-layout-* and sw-theme-* to body" do
      a = StreamWeaver::App.new("Body Classes", layout: :wide) {}
      html = render_app(a)
      expect(html).to include("sw-layout-wide")
      expect(html).to include("sw-theme-default")
    end

    it "ignores a registered non-exclusive layout (no render_block override)" do
      StreamWeaver::LayoutRegistry.register(:non_excl, exclusive: false) { div(class: "custom") {} }
      a = StreamWeaver::App.new("Test", layout: :non_excl) {}
      html = render_app(a)
      # Non-exclusive layout does NOT replace default chrome
      expect(html).to include("<h1>")
      expect(html).to include('id="app-container"')
    end
  end

  describe "HTML rendering — chrome opt-out" do
    it "renders content bare in #app-container without the title or layout chrome class" do
      a = StreamWeaver::App.new("No Chrome", chrome: false) { text "bare content" }
      html = render_app(a)

      expect(html).not_to include("<h1>No Chrome</h1>")
      expect(html).to include('<body class="sw-chromeless sw-theme-default">')
      expect(html).to match(/<div id="app-container"[^>]*><p>bare content<\/p><\/div>/)
    end

    it "the sw-chromeless CSS rule gives bare mode a token-driven, non-zero padding baseline (FAC-9u2)" do
      css = StreamWeaver::Views::AppView.master_theme_css
      expect(css).to match(/body\.sw-chromeless\s*\{[^}]*padding:\s*var\(--sw-spacing/m)
    end

    it "leaves default app chrome unchanged" do
      a = StreamWeaver::App.new("Default Chrome") { text "content" }
      html = render_app(a)

      expect(html).to include("<h1>Default Chrome</h1>")
      expect(html).to include('<body class="sw-layout-default sw-theme-default">')
      expect(html).to include('id="app-container"')
    end
  end

  describe "HTML rendering — h1 dedup (FAC-9u2)" do
    it "suppresses the chrome h1 when the app's first content element is its own header1" do
      a = StreamWeaver::App.new("Rivet People (parity slice)") do
        header1 "People"
        text "hello"
      end
      html = render_app(a)

      expect(html).not_to include("<h1>Rivet People (parity slice)</h1>")
      expect(html.scan("<h1>").length).to eq(1)
      expect(html).to include("<h1>People</h1>")
    end

    it "leaves the chrome h1 in place when the app has no leading header1 (backward compatible)" do
      a = StreamWeaver::App.new("Default Chrome") { text "content" }
      html = render_app(a)

      expect(html).to include("<h1>Default Chrome</h1>")
      expect(html.scan("<h1>").length).to eq(1)
    end

    it "leaves the chrome h1 in place when header1 exists but isn't the first content element" do
      a = StreamWeaver::App.new("Default Chrome") do
        text "before"
        header1 "Later Header"
      end
      html = render_app(a)

      expect(html).to include("<h1>Default Chrome</h1>")
      expect(html).to include("<h1>Later Header</h1>")
      expect(html.scan("<h1>").length).to eq(2)
    end
  end

  describe "HTML rendering — exclusive layout" do
    before do
      StreamWeaver::LayoutRegistry.register(
        :shell_test,
        exclusive: true,
        body_classes: %w[test-shell]
      ) do
        div(class: "test-header") { render_slot(:header) }
        div(class: "test-main")   { main_content_region }
      end
    end

    it "calls the registered render block (omitting default h1/app-container)" do
      a = StreamWeaver::App.new("X", layout: :shell_test) do
        layout_slot(:header) { text "Top" }
        text "Body"
      end
      html = render_app(a)
      # Custom chrome present
      expect(html).to include('class="test-header"')
      expect(html).to include('class="test-main"')
      # Default chrome absent
      expect(html).not_to include("<h1>")
    end

    it "renders slot components in the correct region" do
      a = StreamWeaver::App.new("X", layout: :shell_test) do
        layout_slot(:header) { text "My Header" }
        text "My Body"
      end
      html = render_app(a)
      expect(html).to include("My Header")
      expect(html).to include("My Body")
      # Header text should appear before body text in the HTML
      expect(html.index("My Header")).to be < html.index("My Body")
    end

    it "still wraps main content in #app-container for HTMX" do
      a = StreamWeaver::App.new("X", layout: :shell_test) { text "Main" }
      html = render_app(a)
      expect(html).to include('id="app-container"')
    end

    it "sets custom body classes instead of sw-layout-*" do
      a = StreamWeaver::App.new("X", layout: :shell_test) {}
      html = render_app(a)
      expect(html).to include("test-shell")
      expect(html).not_to include("sw-layout-shell_test")
    end

    it "still includes sw-theme-* alongside the custom body classes" do
      a = StreamWeaver::App.new("X", layout: :shell_test, theme: :dark) {}
      html = render_app(a)
      expect(html).to include("sw-theme-dark")
    end
  end

  describe "backward compatibility" do
    it "layout: :wide still works after reset (no registry entry = default path)" do
      a = StreamWeaver::App.new("Compat", layout: :wide) { text "ok" }
      html = render_app(a)
      expect(html).to include("sw-layout-wide")
      expect(html).to include('id="app-container"')
    end

    it "layout: :fluid still works" do
      a = StreamWeaver::App.new("Fluid", layout: :fluid) { text "ok" }
      html = render_app(a)
      expect(html).to include("sw-layout-fluid")
    end
  end
end
