# frozen_string_literal: true

RSpec.describe "SlideContainer Component (T5)" do
  # =========================================
  # Slide Class
  # =========================================

  describe StreamWeaver::Components::Slide do
    it "initializes with id" do
      slide = described_class.new("intro")
      expect(slide.id).to eq("intro")
      expect(slide.title).to be_nil
      expect(slide.type).to eq(:content)
    end

    it "initializes with id and title" do
      slide = described_class.new("arch", "Architecture")
      expect(slide.id).to eq("arch")
      expect(slide.title).to eq("Architecture")
    end

    it "accepts type option" do
      slide = described_class.new("title_slide", "Title", type: :title)
      expect(slide.type).to eq(:title)
    end

    it "converts id to string" do
      slide = described_class.new(:my_slide)
      expect(slide.id).to eq("my_slide")
    end

    it "has empty children by default" do
      slide = described_class.new("s1")
      expect(slide.children).to eq([])
    end

    it "allows setting children" do
      slide = described_class.new("s1")
      child = StreamWeaver::Components::Text.new("Hello")
      slide.children = [child]
      expect(slide.children.length).to eq(1)
    end

    describe "#css_classes" do
      it "includes sw-slide base class" do
        slide = described_class.new("s1")
        expect(slide.css_classes).to include("sw-slide")
      end

      it "includes type modifier class" do
        slide = described_class.new("s1", type: :title)
        expect(slide.css_classes).to include("sw-slide--title")
      end

      it "defaults to content type" do
        slide = described_class.new("s1")
        expect(slide.css_classes).to include("sw-slide--content")
      end
    end

    describe "#render" do
      it "delegates to adapter" do
        slide = described_class.new("s1", "Test")
        adapter = double("adapter")
        view = double("view", adapter: adapter)
        expect(adapter).to receive(:render_slide).with(view, slide, {})
        slide.render(view, {})
      end
    end
  end

  # =========================================
  # SlideContainer Class
  # =========================================

  describe StreamWeaver::Components::SlideContainer do
    it "initializes with default options" do
      sc = described_class.new
      expect(sc.mode).to eq(:swap)
      expect(sc.progress_bar).to eq(true)
      expect(sc.keyboard_nav).to eq(true)
      expect(sc.nav_dots).to eq(false)
      expect(sc.counter).to eq(false)
    end

    it "accepts custom options" do
      sc = described_class.new(
        mode: :scroll_snap,
        progress_bar: false,
        keyboard_nav: false,
        nav_dots: true,
        counter: true
      )
      expect(sc.mode).to eq(:scroll_snap)
      expect(sc.progress_bar).to eq(false)
      expect(sc.keyboard_nav).to eq(false)
      expect(sc.nav_dots).to eq(true)
      expect(sc.counter).to eq(true)
    end

    it "has empty children by default" do
      sc = described_class.new
      expect(sc.children).to eq([])
    end

    describe "#swap?" do
      it "returns true for swap mode" do
        sc = described_class.new(mode: :swap)
        expect(sc.swap?).to be true
      end

      it "returns false for scroll_snap mode" do
        sc = described_class.new(mode: :scroll_snap)
        expect(sc.swap?).to be false
      end
    end

    describe "#scroll_snap?" do
      it "returns true for scroll_snap mode" do
        sc = described_class.new(mode: :scroll_snap)
        expect(sc.scroll_snap?).to be true
      end

      it "returns false for swap mode" do
        sc = described_class.new(mode: :swap)
        expect(sc.scroll_snap?).to be false
      end
    end

    describe "#slide_count" do
      it "returns 0 when empty" do
        sc = described_class.new
        expect(sc.slide_count).to eq(0)
      end

      it "returns number of children" do
        sc = described_class.new
        sc.children = [
          StreamWeaver::Components::Slide.new("s1"),
          StreamWeaver::Components::Slide.new("s2"),
          StreamWeaver::Components::Slide.new("s3")
        ]
        expect(sc.slide_count).to eq(3)
      end
    end

    describe "#css_classes" do
      it "includes base class" do
        sc = described_class.new
        expect(sc.css_classes).to include("sw-slide-container")
      end

      it "includes swap mode modifier" do
        sc = described_class.new(mode: :swap)
        expect(sc.css_classes).to include("sw-slide-container--swap")
      end

      it "includes scroll-snap mode modifier" do
        sc = described_class.new(mode: :scroll_snap)
        expect(sc.css_classes).to include("sw-slide-container--scroll-snap")
      end
    end

    describe "#container_id" do
      it "returns a unique string id" do
        sc = described_class.new
        expect(sc.container_id).to start_with("sw-slides-")
      end

      it "returns same id on repeated calls" do
        sc = described_class.new
        id1 = sc.container_id
        id2 = sc.container_id
        expect(id1).to eq(id2)
      end
    end

    describe "#render" do
      it "delegates to adapter" do
        sc = described_class.new
        adapter = double("adapter")
        view = double("view", adapter: adapter)
        expect(adapter).to receive(:render_slide_container).with(view, sc, {})
        sc.render(view, {})
      end
    end
  end

  # =========================================
  # sw-slide-nav.js content
  # =========================================

  describe "sw-slide-nav.js" do
    let(:js_path) { File.join(__dir__, '../../lib/stream_weaver/assets/js/sw-slide-nav.js') }
    let(:js_content) { File.read(js_path) }

    it "exists" do
      expect(File.exist?(js_path)).to be true
    end

    it "defines swSlideNav global function" do
      expect(js_content).to include("window.swSlideNav")
    end

    it "tracks current slide index" do
      expect(js_content).to include("current:")
    end

    it "has next method" do
      expect(js_content).to include("next:")
    end

    it "has prev method" do
      expect(js_content).to include("prev:")
    end

    it "has goTo method" do
      expect(js_content).to include("goTo:")
    end

    it "has progress method" do
      expect(js_content).to include("progress:")
    end

    it "registers arrow key shortcuts via swKeyboard" do
      expect(js_content).to include("arrowright")
      expect(js_content).to include("arrowleft")
    end

    it "registers space key for navigation" do
      expect(js_content).to include("' '")
    end

    it "handles scroll-snap mode navigation" do
      expect(js_content).to include("scroll_snap")
      expect(js_content).to include("scrollIntoView")
    end
  end

  # =========================================
  # DSL Integration
  # =========================================

  describe "DisplayDSL#slide_container" do
    it "creates a slide container via DSL" do
      app = StreamWeaver::App.new("Test") do
        slide_container mode: :swap do
          slide "intro", "Introduction" do
            text "Hello"
          end
          slide "arch", "Architecture" do
            text "Design"
          end
        end
      end
      app.rebuild_with_state({})
      sc = app.components.find { |c| c.is_a?(StreamWeaver::Components::SlideContainer) }
      expect(sc).not_to be_nil
      expect(sc.mode).to eq(:swap)
      expect(sc.children.length).to eq(2)
      expect(sc.children[0]).to be_a(StreamWeaver::Components::Slide)
      expect(sc.children[0].id).to eq("intro")
      expect(sc.children[0].title).to eq("Introduction")
      expect(sc.children[1].id).to eq("arch")
    end

    it "supports scroll_snap mode" do
      app = StreamWeaver::App.new("Test") do
        slide_container mode: :scroll_snap, nav_dots: true do
          slide "s1" do
            text "Slide 1"
          end
        end
      end
      app.rebuild_with_state({})
      sc = app.components.find { |c| c.is_a?(StreamWeaver::Components::SlideContainer) }
      expect(sc.mode).to eq(:scroll_snap)
      expect(sc.nav_dots).to eq(true)
    end

    it "nests slide children correctly" do
      app = StreamWeaver::App.new("Test") do
        slide_container do
          slide "s1", "Slide 1" do
            text "Content 1"
            text "Content 2"
          end
        end
      end
      app.rebuild_with_state({})
      sc = app.components.find { |c| c.is_a?(StreamWeaver::Components::SlideContainer) }
      slide = sc.children.first
      expect(slide.children.length).to eq(2)
      expect(slide.children[0]).to be_a(StreamWeaver::Components::Text)
    end
  end

  # =========================================
  # AlpineJS Adapter Rendering: Swap Mode
  # =========================================

  describe "AlpineJS adapter rendering - swap mode" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(components)
      StreamWeaver::ComponentRenderer.render_html(adapter, Array(components), state)
    end

    def build_slide_container(**options, &block)
      # Build component tree using DSL
      app = StreamWeaver::App.new("Test") do
        slide_container(**options, &block)
      end
      app.rebuild_with_state(state)
      app.components.find { |c| c.is_a?(StreamWeaver::Components::SlideContainer) }
    end

    it "renders container with x-data for slide navigation" do
      sc = build_slide_container(mode: :swap) do
        slide "s1", "Slide 1" do
          text "Hello"
        end
        slide "s2", "Slide 2" do
          text "World"
        end
      end
      html = render_html(sc)
      expect(html).to include("swSlideNav(2")
      expect(html).to include("sw-slide-container--swap")
    end

    it "renders Back and Next buttons in swap mode" do
      sc = build_slide_container(mode: :swap) do
        slide "s1" do
          text "A"
        end
        slide "s2" do
          text "B"
        end
      end
      html = render_html(sc)
      expect(html).to include("Back")
      expect(html).to include("Next")
      expect(html).to include("sw-slide-nav__btn")
    end

    it "renders x-show for slide visibility" do
      sc = build_slide_container(mode: :swap) do
        slide "s1" do
          text "A"
        end
        slide "s2" do
          text "B"
        end
      end
      html = render_html(sc)
      expect(html).to include('x-show="current === 0"')
      expect(html).to include('x-show="current === 1"')
    end

    it "renders progress bar by default" do
      sc = build_slide_container do
        slide "s1" do
          text "A"
        end
      end
      html = render_html(sc)
      expect(html).to include("sw-slide-progress")
      expect(html).to include("sw-slide-progress--fixed")
      expect(html).to include("sw-slide-progress__bar")
    end

    it "omits progress bar when disabled" do
      sc = build_slide_container(progress_bar: false) do
        slide "s1" do
          text "A"
        end
      end
      html = render_html(sc)
      # The CSS definition will mention sw-slide-progress, but there should be
      # no actual progress bar element with the class as an HTML attribute
      expect(html).not_to include('class="sw-slide-progress sw-slide-progress--fixed"')
    end

    it "renders slide titles" do
      sc = build_slide_container do
        slide "s1", "My Title" do
          text "A"
        end
      end
      html = render_html(sc)
      expect(html).to include("My Title")
      expect(html).to include("sw-slide__title")
    end
  end

  # =========================================
  # AlpineJS Adapter Rendering: Scroll-Snap Mode
  # =========================================

  describe "AlpineJS adapter rendering - scroll_snap mode" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(components)
      StreamWeaver::ComponentRenderer.render_html(adapter, Array(components), state)
    end

    def build_slide_container(**options, &block)
      app = StreamWeaver::App.new("Test") do
        slide_container(**options, &block)
      end
      app.rebuild_with_state(state)
      app.components.find { |c| c.is_a?(StreamWeaver::Components::SlideContainer) }
    end

    it "renders with scroll-snap CSS class" do
      sc = build_slide_container(mode: :scroll_snap) do
        slide "s1" do
          text "A"
        end
        slide "s2" do
          text "B"
        end
      end
      html = render_html(sc)
      expect(html).to include("sw-slide-container--scroll-snap")
      expect(html).to include("sw-slide--snap")
    end

    it "renders all slides (no x-show)" do
      sc = build_slide_container(mode: :scroll_snap) do
        slide "s1" do
          text "Visible A"
        end
        slide "s2" do
          text "Visible B"
        end
      end
      html = render_html(sc)
      expect(html).to include("Visible A")
      expect(html).to include("Visible B")
      # Scroll-snap mode should not use x-show for slides
      expect(html).not_to include('x-show="current === 0"')
    end

    it "does not render Back/Next buttons in scroll-snap mode" do
      sc = build_slide_container(mode: :scroll_snap) do
        slide "s1" do
          text "A"
        end
      end
      html = render_html(sc)
      # Check no actual Back/Next button elements (CSS may mention the class)
      expect(html).not_to include('>Back</button>')
      expect(html).not_to include('>Next</button>')
    end
  end

  # =========================================
  # Optional UI: Dots, Counter
  # =========================================

  describe "optional UI elements" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(components)
      StreamWeaver::ComponentRenderer.render_html(adapter, Array(components), state)
    end

    def build_slide_container(**options, &block)
      app = StreamWeaver::App.new("Test") do
        slide_container(**options, &block)
      end
      app.rebuild_with_state(state)
      app.components.find { |c| c.is_a?(StreamWeaver::Components::SlideContainer) }
    end

    it "renders navigation dots when enabled" do
      sc = build_slide_container(nav_dots: true) do
        slide "s1" do
          text "A"
        end
        slide "s2" do
          text "B"
        end
      end
      html = render_html(sc)
      expect(html).to include("sw-slide-dots")
      expect(html).to include("sw-slide-dots__dot")
    end

    it "does not render navigation dots by default" do
      sc = build_slide_container do
        slide "s1" do
          text "A"
        end
      end
      html = render_html(sc)
      # Check no actual dots element (CSS may mention the class)
      expect(html).not_to include('class="sw-slide-dots"')
    end

    it "renders counter when enabled" do
      sc = build_slide_container(counter: true) do
        slide "s1" do
          text "A"
        end
      end
      html = render_html(sc)
      expect(html).to include("sw-slide-counter")
    end

    it "does not render counter by default" do
      sc = build_slide_container do
        slide "s1" do
          text "A"
        end
      end
      html = render_html(sc)
      # Check no actual counter element (CSS may mention the class)
      expect(html).not_to include('class="sw-slide-counter"')
    end
  end

  # =========================================
  # CSS Class Prefix Convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:css) { StreamWeaver::Adapter::AlpineJS::SLIDE_CONTAINER_CSS }

    it "all CSS class selectors use sw- prefix" do
      # Extract class selectors from CSS
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") }
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/\.([\w][\w-]*)/).flatten
      }.uniq

      # Filter out pseudo-elements that might look like classes
      class_selectors.reject! { |c| c.start_with?("not") }

      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        next if cls == "x-cloak" # Alpine.js internal

        expect(cls).to start_with("sw-"),
          "CSS class '.#{cls}' does not use sw- prefix"
      end
    end
  end

  # =========================================
  # Keyboard Navigation Integration
  # =========================================

  describe "keyboard navigation" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(components)
      StreamWeaver::ComponentRenderer.render_html(adapter, Array(components), state)
    end

    def build_slide_container(**options, &block)
      app = StreamWeaver::App.new("Test") do
        slide_container(**options, &block)
      end
      app.rebuild_with_state(state)
      app.components.find { |c| c.is_a?(StreamWeaver::Components::SlideContainer) }
    end

    it "injects sw-keyboard.js when keyboard_nav is true" do
      sc = build_slide_container(keyboard_nav: true) do
        slide "s1" do
          text "A"
        end
      end
      html = render_html(sc)
      expect(html).to include("window.swKeyboard")
    end

    it "injects sw-slide-nav.js" do
      sc = build_slide_container do
        slide "s1" do
          text "A"
        end
      end
      html = render_html(sc)
      expect(html).to include("window.swSlideNav")
    end
  end
end
