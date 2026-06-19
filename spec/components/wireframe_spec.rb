# frozen_string_literal: true

RSpec.describe "Wireframe Component with Device Chrome" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
  let(:state)   { {} }

  def render_html(component)
    StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
  end

  describe StreamWeaver::Components::Wireframe do
    it "initializes with html and surface" do
      c = described_class.new(html: "<h1>Test</h1>", surface: :browser)
      expect(c.html).to eq("<h1>Test</h1>")
      expect(c.surface).to eq("browser")
    end

    it "defaults surface to browser" do
      c = described_class.new
      expect(c.surface).to eq("browser")
    end

    it "normalizes unknown surface to browser" do
      c = described_class.new(surface: :unknown)
      expect(c.surface).to eq("browser")
    end

    it "accepts all valid surfaces as symbols" do
      %i[browser desktop mobile phone tablet popover card widget panel].each do |s|
        c = described_class.new(surface: s)
        expect(c.surface).to eq(s.to_s)
      end
    end

    it "accepts surfaces as strings too" do
      c = described_class.new(surface: "mobile")
      expect(c.surface).to eq("mobile")
    end
  end

  describe "HTML rendering" do
    it "wraps content in .sw-wireframe outer container" do
      expect(render_html(StreamWeaver::Components::Wireframe.new(html: "<p>Hello</p>"))).to include("sw-wireframe")
    end

    it "sets a surface modifier class" do
      expect(render_html(StreamWeaver::Components::Wireframe.new(html: "", surface: :browser))).to include("sw-wireframe--browser")
    end

    it "sets data-surface attribute" do
      expect(render_html(StreamWeaver::Components::Wireframe.new(html: "", surface: :mobile))).to include('data-surface="mobile"')
    end

    it "renders the HTML content inside the frame" do
      expect(render_html(StreamWeaver::Components::Wireframe.new(html: "<h1>Login</h1>"))).to include("<h1>Login</h1>")
    end

    it "includes a .sw-wireframe-chrome bar" do
      expect(render_html(StreamWeaver::Components::Wireframe.new(html: ""))).to include("sw-wireframe-chrome")
    end

    it "renders browser chrome: three colored dots" do
      html = render_html(StreamWeaver::Components::Wireframe.new(html: "", surface: :browser))
      expect(html).to include("sw-wireframe-dot--red")
      expect(html).to include("sw-wireframe-dot--amber")
      expect(html).to include("sw-wireframe-dot--green")
    end

    it "renders browser chrome: address bar" do
      expect(render_html(StreamWeaver::Components::Wireframe.new(html: "", surface: :browser))).to include("sw-wireframe-addressbar")
    end

    it "renders desktop chrome: traffic lights + title" do
      html = render_html(StreamWeaver::Components::Wireframe.new(html: "", surface: :desktop))
      expect(html).to include("sw-wireframe-dot--red")
      expect(html).to include("sw-wireframe-title")
    end

    it "renders mobile chrome: status bar with time and icons" do
      html = render_html(StreamWeaver::Components::Wireframe.new(html: "", surface: :mobile))
      expect(html).to include("sw-wireframe-statusbar-time")
      expect(html).to include("sw-wireframe-statusbar-icons")
    end

    it "renders phone chrome: same as mobile" do
      html = render_html(StreamWeaver::Components::Wireframe.new(html: "", surface: :phone))
      expect(html).to include("sw-wireframe-statusbar-time")
      expect(html).to include("sw-wireframe--phone")
    end

    it "renders popover chrome: three dots (compact)" do
      html = render_html(StreamWeaver::Components::Wireframe.new(html: "", surface: :popover))
      expect(html).to include("sw-wireframe--popover")
      expect(html).to include("sw-wireframe-dot--red")
    end

    it "renders card chrome: three dots (compact)" do
      html = render_html(StreamWeaver::Components::Wireframe.new(html: "", surface: :card))
      expect(html).to include("sw-wireframe--card")
      expect(html).to include("sw-wireframe-dot--green")
    end

    it "renders panel chrome: PANEL label strip" do
      html = render_html(StreamWeaver::Components::Wireframe.new(html: "", surface: :panel))
      expect(html).to include("sw-wireframe-panel-title")
      expect(html).to include("PANEL")
    end
  end

  describe "CSS injection" do
    let(:html) { render_html(StreamWeaver::Components::Wireframe.new(html: "")) }

    it "injects wireframe token CSS (--wf-* tokens)" do
      expect(html).to include("--wf-ink")
      expect(html).to include("--wf-accent")
    end

    it "injects device chrome CSS (.sw-wireframe rules)" do
      expect(html).to include(".sw-wireframe")
      expect(html).to include(".sw-wireframe-chrome")
    end

    it "includes dark mode chrome rules" do
      expect(html).to include("html.dark .sw-wireframe")
    end

    it "renders content inside .sw-wireframe-surface so --wf-* tokens apply" do
      h = render_html(StreamWeaver::Components::Wireframe.new(html: "<span class='wf-muted'>info</span>"))
      expect(h).to include("sw-wireframe-surface")
      expect(h).to include("sw-wireframe-body")
      expect(h).to include("wf-muted")
    end

    it "injects chrome CSS once for multiple wireframe components" do
      comps = [
        StreamWeaver::Components::Wireframe.new(html: "<p>A</p>", surface: :browser),
        StreamWeaver::Components::Wireframe.new(html: "<p>B</p>", surface: :mobile)
      ]
      multi = StreamWeaver::ComponentRenderer.render_html(StreamWeaver::Adapter::AlpineJS.new, comps, state)
      expect(multi.scan("StreamWeaver Wireframe Device Chrome").length).to eq(1)
    end
  end

  describe "helper classes render inside frame" do
    it "wf-card class is in CSS scope" do
      expect(render_html(StreamWeaver::Components::Wireframe.new(html: ""))).to include(".sw-wireframe-surface .wf-card")
    end

    it "wf-pill class is in CSS scope" do
      expect(render_html(StreamWeaver::Components::Wireframe.new(html: ""))).to include(".sw-wireframe-surface .wf-pill")
    end

    it "button.primary class is in CSS scope" do
      expect(render_html(StreamWeaver::Components::Wireframe.new(html: ""))).to include(".sw-wireframe-surface button.primary")
    end
  end

  describe "Adapter::Base interface" do
    it "raises NotImplementedError for render_wireframe" do
      expect {
        StreamWeaver::Adapter::Base.new.render_wireframe(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_wireframe/)
    end
  end

  describe "Sketch mode (theme_preset :sketch)" do
    def render_sketch_page
      app = StreamWeaver::App.new("Sketch Test") do
        theme_preset :sketch
        wireframe(surface: :browser) { "<h1>Mockup</h1>" }
        text "Regular content"
      end
      app.rebuild_with_state({})
      StreamWeaver::ComponentRenderer.render_html(adapter, app.components, state)
    end

    it "accepts :sketch as a valid theme_preset argument" do
      expect { StreamWeaver::Components::ThemePreset.new(:sketch) }.not_to raise_error
    end

    it "loads rough.js CDN when sketch preset is used" do
      html = render_sketch_page
      expect(html).to include("roughjs")
    end

    it "loads Caveat (hand-drawn font) from Google Fonts" do
      html = render_sketch_page
      expect(html).to include("fonts.googleapis.com")
      expect(html).to include("Caveat")
    end

    it "injects sketch mode CSS scoped to .sw-wireframe-surface" do
      html = render_sketch_page
      expect(html).to include("sw-wireframe-surface")
      expect(html).to include("Caveat")
    end

    it "sets data-sketch on body via injected JS" do
      html = render_sketch_page
      expect(html).to include("data-sketch")
    end

    it "JS calls roughifyElement on .sw-wireframe-surface elements" do
      html = render_sketch_page
      expect(html).to include(".sw-wireframe-surface")
      expect(html).to include("roughifyElement")
    end

    it "does not inject global body font-family (non-wireframe content unaffected)" do
      html = render_sketch_page
      # The sketch CSS must scope font to wireframe surface, not body globally
      expect(html).not_to include("body {\n  font-family: 'Caveat'")
      expect(html).not_to match(/body\s*\{\s*\n?\s*font-family:\s*'Caveat'/)
    end

    it "does not duplicate rough.js injection for multiple theme_preset calls" do
      app = StreamWeaver::App.new("Dupe Test") do
        theme_preset :sketch
        theme_preset :sketch
      end
      app.rebuild_with_state({})
      html = StreamWeaver::ComponentRenderer.render_html(adapter, app.components, state)
      expect(html.scan("roughjs").length).to eq(1)
    end
  end

  describe "DisplayDSL#wireframe" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        wireframe(surface: :browser) { "<h1>Mockup</h1>" }
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Wireframe) }
      expect(component).not_to be_nil
      expect(component.html).to eq("<h1>Mockup</h1>")
      expect(component.surface).to eq("browser")
    end

    it "captures block content as the html" do
      app = StreamWeaver::App.new("Test") do
        wireframe(surface: :mobile) { "<p>Phone screen</p>" }
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Wireframe) }
      expect(component.html).to eq("<p>Phone screen</p>")
      expect(component.surface).to eq("mobile")
    end
  end
end
