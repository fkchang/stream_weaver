# frozen_string_literal: true

RSpec.describe "Callout Component (T11)" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::Callout do
    it "initializes with default variant :info" do
      c = described_class.new
      expect(c.variant).to eq(:info)
    end

    it "initializes with a custom variant" do
      c = described_class.new(variant: :warning)
      expect(c.variant).to eq(:warning)
    end

    it "falls back to :info for unknown variants" do
      c = described_class.new(variant: :unknown)
      expect(c.variant).to eq(:info)
    end

    it "initializes with title" do
      c = described_class.new(title: "Heads Up")
      expect(c.title).to eq("Heads Up")
    end

    it "defaults title to nil" do
      c = described_class.new
      expect(c.title).to be_nil
    end

    it "initializes children to empty array" do
      c = described_class.new
      expect(c.children).to eq([])
    end

    describe "#icon" do
      it "returns info icon for :info" do
        c = described_class.new(variant: :info)
        expect(c.icon).not_to be_nil
        expect(c.icon).not_to be_empty
      end

      it "returns warning icon for :warning" do
        c = described_class.new(variant: :warning)
        expect(c.icon).not_to be_nil
      end

      it "returns success icon for :success" do
        c = described_class.new(variant: :success)
        expect(c.icon).not_to be_nil
      end

      it "returns error icon for :error" do
        c = described_class.new(variant: :error)
        expect(c.icon).not_to be_nil
      end

      it "returns tip icon for :tip" do
        c = described_class.new(variant: :tip)
        expect(c.icon).not_to be_nil
      end

      it "returns decision icon for :decision" do
        c = described_class.new(variant: :decision)
        expect(c.icon).to eq("⚖️")
      end

      it "returns risk icon for :risk" do
        c = described_class.new(variant: :risk)
        expect(c.icon).to eq("\u{1F53A}")
      end

      it "returns different icons for different variants" do
        icons = StreamWeaver::Components::Callout::VARIANTS.map do |v|
          described_class.new(variant: v).icon
        end
        # At least some should be different (info and warning differ)
        expect(icons.uniq.length).to be > 1
      end
    end

    describe "#variant_class" do
      it "returns sw-callout--info for :info" do
        c = described_class.new(variant: :info)
        expect(c.variant_class).to eq("sw-callout--info")
      end

      it "returns sw-callout--warning for :warning" do
        c = described_class.new(variant: :warning)
        expect(c.variant_class).to eq("sw-callout--warning")
      end

      it "returns sw-callout--success for :success" do
        c = described_class.new(variant: :success)
        expect(c.variant_class).to eq("sw-callout--success")
      end

      it "returns sw-callout--error for :error" do
        c = described_class.new(variant: :error)
        expect(c.variant_class).to eq("sw-callout--error")
      end

      it "returns sw-callout--tip for :tip" do
        c = described_class.new(variant: :tip)
        expect(c.variant_class).to eq("sw-callout--tip")
      end

      it "returns sw-callout--decision for :decision" do
        c = described_class.new(variant: :decision)
        expect(c.variant_class).to eq("sw-callout--decision")
      end

      it "returns sw-callout--risk for :risk" do
        c = described_class.new(variant: :risk)
        expect(c.variant_class).to eq("sw-callout--risk")
      end
    end
  end

  # =========================================
  # HTML rendering via adapter
  # =========================================

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders a callout container with sw-callout class" do
      c = StreamWeaver::Components::Callout.new(variant: :info)
      html = render_html(c)
      expect(html).to include("sw-callout")
    end

    it "renders the variant class" do
      c = StreamWeaver::Components::Callout.new(variant: :warning)
      html = render_html(c)
      expect(html).to include("sw-callout--warning")
    end

    it "renders the title when provided" do
      c = StreamWeaver::Components::Callout.new(variant: :info, title: "Note")
      html = render_html(c)
      expect(html).to include("sw-callout__title")
      expect(html).to include("Note")
    end

    it "does not render title div when title is nil" do
      c = StreamWeaver::Components::Callout.new(variant: :info)
      html = render_html(c)
      expect(html).not_to include('class="sw-callout__title"')
    end

    it "renders the icon area" do
      c = StreamWeaver::Components::Callout.new(variant: :info)
      html = render_html(c)
      expect(html).to include("sw-callout__icon")
    end

    it "renders content area" do
      c = StreamWeaver::Components::Callout.new(variant: :info)
      html = render_html(c)
      expect(html).to include("sw-callout__content")
    end

    it "renders role=note for accessibility" do
      c = StreamWeaver::Components::Callout.new(variant: :info)
      html = render_html(c)
      expect(html).to include('role="note"')
    end

    it "renders children inside the content area" do
      c = StreamWeaver::Components::Callout.new(variant: :warning, title: "Caution")
      c.children = [StreamWeaver::Components::Text.new("Be careful")]
      html = render_html(c)
      expect(html).to include("Be careful")
    end

    StreamWeaver::Components::Callout::VARIANTS.each do |variant|
      it "renders #{variant} variant with correct class" do
        c = StreamWeaver::Components::Callout.new(variant: variant)
        html = render_html(c)
        expect(html).to include("sw-callout--#{variant}")
      end
    end
  end

  # =========================================
  # CSS prefix convention
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:css) { adapter.send(:callout_css) }

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
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#callout" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        callout(variant: :warning, title: "Caution") do
          text "Be careful"
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Callout) }
      expect(component).not_to be_nil
      expect(component.variant).to eq(:warning)
      expect(component.title).to eq("Caution")
    end

    it "captures children from block" do
      app = StreamWeaver::App.new("Test") do
        callout(variant: :info) do
          text "Some info"
        end
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Callout) }
      expect(component.children.length).to eq(1)
      expect(component.children.first).to be_a(StreamWeaver::Components::Text)
    end
  end

  # =========================================
  # Adapter base interface
  # =========================================

  describe "Adapter::Base#render_callout" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_callout(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_callout/)
    end
  end
end
