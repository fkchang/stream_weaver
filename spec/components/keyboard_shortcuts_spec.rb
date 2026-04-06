# frozen_string_literal: true

RSpec.describe "KeyboardShortcuts Component (T5)" do
  # =========================================
  # Component Class
  # =========================================

  describe StreamWeaver::Components::KeyboardShortcuts do
    it "initializes with empty bindings" do
      ks = described_class.new
      expect(ks.bindings).to eq([])
    end

    it "registers a shortcut with #on" do
      ks = described_class.new
      ks.on "mod+s", context: :global, js_action: "alert('save')"
      expect(ks.bindings.length).to eq(1)
      expect(ks.bindings[0][:key]).to eq("mod+s")
      expect(ks.bindings[0][:context]).to eq(:global)
      expect(ks.bindings[0][:js_action]).to eq("alert('save')")
    end

    it "defaults context to :global" do
      ks = described_class.new
      ks.on "Escape", js_action: "close()"
      expect(ks.bindings[0][:context]).to eq(:global)
    end

    it "supports multiple bindings" do
      ks = described_class.new
      ks.on "mod+s", js_action: "save()"
      ks.on "ArrowRight", context: :navigation, js_action: "next()"
      ks.on "ArrowLeft", context: :navigation, js_action: "prev()"
      expect(ks.bindings.length).to eq(3)
    end

    it "stores callback blocks" do
      callback = proc { |state| state }
      ks = described_class.new
      ks.on "mod+s", &callback
      expect(ks.bindings[0][:callback]).to eq(callback)
    end

    describe "#to_js" do
      it "generates JS registration code for a single shortcut" do
        ks = described_class.new
        ks.on "mod+s", context: :global, js_action: "save()"
        js = ks.to_js
        expect(js).to include("swKeyboard.register('mod+s', 'global'")
        expect(js).to include("save()")
      end

      it "generates JS for multiple shortcuts" do
        ks = described_class.new
        ks.on "ArrowRight", context: :navigation, js_action: "next()"
        ks.on "ArrowLeft", context: :navigation, js_action: "prev()"
        js = ks.to_js
        expect(js).to include("'ArrowRight'")
        expect(js).to include("'ArrowLeft'")
        expect(js.lines.count { |l| l.include?("swKeyboard.register") }).to eq(2)
      end

      it "expands range shortcuts (e.g. 1..9)" do
        ks = described_class.new
        ks.on "1..3", context: :selection, js_action: "selectOption(KEY)"
        js = ks.to_js
        expect(js).to include("swKeyboard.register('1'")
        expect(js).to include("swKeyboard.register('2'")
        expect(js).to include("swKeyboard.register('3'")
        expect(js).to include("selectOption(1)")
        expect(js).to include("selectOption(2)")
        expect(js).to include("selectOption(3)")
      end

      it "uses default console.log when no js_action provided" do
        ks = described_class.new
        ks.on "Escape"
        js = ks.to_js
        expect(js).to include("console.log('shortcut: Escape')")
      end
    end

    describe "#css_classes" do
      it "returns empty string (non-visual)" do
        ks = described_class.new
        expect(ks.css_classes).to eq("")
      end
    end

    describe "#render" do
      it "delegates to adapter" do
        ks = described_class.new
        adapter = double("adapter")
        view = double("view", adapter: adapter)
        state = {}
        expect(adapter).to receive(:render_keyboard_shortcuts).with(view, ks, state)
        ks.render(view, state)
      end
    end
  end

  # =========================================
  # sw-keyboard.js content
  # =========================================

  describe "sw-keyboard.js" do
    let(:js_path) { File.join(__dir__, '../../lib/stream_weaver/assets/js/sw-keyboard.js') }
    let(:js_content) { File.read(js_path) }

    it "exists" do
      expect(File.exist?(js_path)).to be true
    end

    it "defines swKeyboard global" do
      expect(js_content).to include("window.swKeyboard")
    end

    it "has register method" do
      expect(js_content).to include("register:")
    end

    it "has removeContext method" do
      expect(js_content).to include("removeContext:")
    end

    it "has clear method" do
      expect(js_content).to include("clear:")
    end

    it "maps 'mod' key based on platform" do
      expect(js_content).to include("case 'mod':")
    end

    it "checks for Mac platform" do
      expect(js_content).to include("Mac")
    end

    it "suppresses shortcuts in text inputs" do
      expect(js_content).to include("textarea")
      expect(js_content).to include('input[type="text"]')
    end

    it "suppresses shortcuts in contenteditable" do
      expect(js_content).to include("contenteditable")
    end

    it "suppresses shortcuts in Mermaid zoom containers" do
      expect(js_content).to include("sw-mermaid--zoom")
    end

    it "suppresses shortcuts in code scroll containers" do
      expect(js_content).to include("sw-code-scroll")
    end

    it "provides isMac helper" do
      expect(js_content).to include("isMac:")
    end

    it "provides modLabel helper" do
      expect(js_content).to include("modLabel:")
    end
  end

  # =========================================
  # Suppression selectors constant
  # =========================================

  describe "SUPPRESSION_SELECTORS" do
    let(:selectors) { StreamWeaver::Components::KeyboardShortcuts::SUPPRESSION_SELECTORS }

    it "includes text input types" do
      expect(selectors).to include("input[type=text]")
      expect(selectors).to include("input[type=search]")
      expect(selectors).to include("input[type=email]")
    end

    it "includes textarea" do
      expect(selectors).to include("textarea")
    end

    it "includes contenteditable" do
      expect(selectors).to include("[contenteditable=true]")
    end

    it "includes mermaid zoom container" do
      expect(selectors).to include(".sw-mermaid--zoom")
    end

    it "includes code scroll container" do
      expect(selectors).to include(".sw-code-scroll")
    end
  end

  # =========================================
  # DSL Integration
  # =========================================

  describe "DisplayDSL#keyboard_shortcuts" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        keyboard_shortcuts do |kb|
          kb.on "mod+s", js_action: "save()"
        end
      end
      app.rebuild_with_state({})
      ks = app.components.find { |c| c.is_a?(StreamWeaver::Components::KeyboardShortcuts) }
      expect(ks).not_to be_nil
      expect(ks.bindings.length).to eq(1)
      expect(ks.bindings[0][:key]).to eq("mod+s")
    end

    it "works without a block" do
      app = StreamWeaver::App.new("Test") do
        keyboard_shortcuts
      end
      app.rebuild_with_state({})
      ks = app.components.find { |c| c.is_a?(StreamWeaver::Components::KeyboardShortcuts) }
      expect(ks).not_to be_nil
      expect(ks.bindings).to be_empty
    end
  end

  # =========================================
  # AlpineJS Adapter Rendering
  # =========================================

  describe "AlpineJS adapter rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders a <script> tag with shortcut registration" do
      ks = StreamWeaver::Components::KeyboardShortcuts.new
      ks.on "mod+s", context: :global, js_action: "save()"
      html = render_html(ks)
      expect(html).to include("swKeyboard.register('mod+s'")
      expect(html).to include("save()")
    end

    it "injects sw-keyboard.js engine script" do
      ks = StreamWeaver::Components::KeyboardShortcuts.new
      ks.on "Escape", js_action: "close()"
      html = render_html(ks)
      expect(html).to include("window.swKeyboard")
    end
  end
end
