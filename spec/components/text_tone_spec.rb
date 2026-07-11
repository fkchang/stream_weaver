# frozen_string_literal: true

RSpec.describe "text tone variants (FAC-P2.2)" do
  describe StreamWeaver::Components::Text do
    it "defaults tone to nil" do
      expect(described_class.new("Hi").tone).to be_nil
    end

    it "accepts a known tone" do
      expect(described_class.new("Hi", tone: :muted).tone).to eq(:muted)
    end

    it "falls back to nil for an unknown tone" do
      expect(described_class.new("Hi", tone: :bogus).tone).to be_nil
    end

    StreamWeaver::Components::Text::TONES.each do |tone|
      it "accepts :#{tone}" do
        expect(described_class.new("Hi", tone: tone).tone).to eq(tone)
      end
    end
  end

  describe "text DSL" do
    it "adds a Text component with the given tone" do
      app = StreamWeaver::App.new("Test") { text "Careful", tone: :error }
      app.rebuild_with_state({})
      component = app.components.first
      expect(component).to be_a(StreamWeaver::Components::Text)
      expect(component.tone).to eq(:error)
    end

    it "defaults to no tone (unchanged behavior)" do
      app = StreamWeaver::App.new("Test") { text "Plain" }
      app.rebuild_with_state({})
      expect(app.components.first.tone).to be_nil
    end
  end

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders a plain <p> with no extra class when tone is nil" do
      html = render_html(StreamWeaver::Components::Text.new("Hi"))
      expect(html).to include("<p>Hi</p>")
    end

    StreamWeaver::Components::Text::TONES.each do |tone|
      it "renders sw-text--#{tone} for tone: :#{tone}" do
        html = render_html(StreamWeaver::Components::Text.new("Hi", tone: tone))
        expect(html).to include("sw-text--#{tone}")
      end
    end
  end
end

RSpec.describe "callout content/tone convenience (FAC-P2.2)" do
  describe "callout DSL" do
    it "accepts a positional content string as the sole child" do
      app = StreamWeaver::App.new("Test") { callout("Heads up") }
      app.rebuild_with_state({})
      component = app.components.first
      expect(component.children.length).to eq(1)
      expect(component.children.first).to be_a(StreamWeaver::Components::Text)
    end

    it "still supports the existing block form unchanged" do
      app = StreamWeaver::App.new("Test") do
        callout(variant: :warning, title: "Caution") { text "Be careful" }
      end
      app.rebuild_with_state({})
      component = app.components.first
      expect(component.variant).to eq(:warning)
      expect(component.title).to eq("Caution")
      expect(component.children.length).to eq(1)
    end

    it "accepts tone: as an alias for variant:" do
      app = StreamWeaver::App.new("Test") { callout("Oops", tone: :error) }
      app.rebuild_with_state({})
      expect(app.components.first.variant).to eq(:error)
    end

    it "prefers tone: over variant: when both given" do
      app = StreamWeaver::App.new("Test") { callout("Oops", variant: :info, tone: :error) }
      app.rebuild_with_state({})
      expect(app.components.first.variant).to eq(:error)
    end

    it "combines positional content with a block" do
      app = StreamWeaver::App.new("Test") do
        callout("Heads up") { text "More detail" }
      end
      app.rebuild_with_state({})
      component = app.components.first
      expect(component.children.length).to eq(2)
    end
  end
end
