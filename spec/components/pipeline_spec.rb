# frozen_string_literal: true

RSpec.describe "Pipeline Component (T12)" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::Pipeline do
    let(:steps) do
      [
        { label: "Build", status: :complete },
        { label: "Test", status: :active },
        { label: "Deploy", status: :pending }
      ]
    end

    it "initializes with steps" do
      p = described_class.new(steps: steps)
      expect(p.steps.length).to eq(3)
    end

    it "normalizes step status to symbols" do
      p = described_class.new(steps: [{ label: "A", status: "complete" }])
      expect(p.steps.first[:status]).to eq(:complete)
    end

    it "defaults status to :pending" do
      p = described_class.new(steps: [{ label: "A" }])
      expect(p.steps.first[:status]).to eq(:pending)
    end

    it "defaults label to 'Step'" do
      p = described_class.new(steps: [{ status: :active }])
      expect(p.steps.first[:label]).to eq("Step")
    end

    it "preserves optional description" do
      p = described_class.new(steps: [{ label: "Build", description: "Compile sources", status: :complete }])
      expect(p.steps.first[:description]).to eq("Compile sources")
    end

    describe "#step_css_class" do
      it "returns complete class for :complete" do
        p = described_class.new(steps: steps)
        expect(p.step_css_class(p.steps[0])).to include("sw-pipeline__step--complete")
      end

      it "returns active class for :active" do
        p = described_class.new(steps: steps)
        expect(p.step_css_class(p.steps[1])).to include("sw-pipeline__step--active")
      end

      it "returns pending class for :pending" do
        p = described_class.new(steps: steps)
        expect(p.step_css_class(p.steps[2])).to include("sw-pipeline__step--pending")
      end

      it "always includes base class" do
        p = described_class.new(steps: steps)
        p.steps.each do |step|
          expect(p.step_css_class(step)).to include("sw-pipeline__step")
        end
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

    it "renders a pipeline container with sw-pipeline class" do
      p = StreamWeaver::Components::Pipeline.new(steps: [{ label: "A", status: :active }])
      html = render_html(p)
      expect(html).to include('class="sw-pipeline"')
    end

    it "renders steps with correct status classes" do
      steps = [
        { label: "Build", status: :complete },
        { label: "Test", status: :active },
        { label: "Deploy", status: :pending }
      ]
      p = StreamWeaver::Components::Pipeline.new(steps: steps)
      html = render_html(p)
      expect(html).to include("sw-pipeline__step--complete")
      expect(html).to include("sw-pipeline__step--active")
      expect(html).to include("sw-pipeline__step--pending")
    end

    it "renders step labels" do
      p = StreamWeaver::Components::Pipeline.new(steps: [
        { label: "Build", status: :complete },
        { label: "Test", status: :active }
      ])
      html = render_html(p)
      expect(html).to include("Build")
      expect(html).to include("Test")
    end

    it "renders step descriptions when provided" do
      p = StreamWeaver::Components::Pipeline.new(steps: [
        { label: "Build", description: "Compile sources", status: :complete }
      ])
      html = render_html(p)
      expect(html).to include("Compile sources")
      expect(html).to include("sw-pipeline__desc")
    end

    it "renders arrow connectors between steps" do
      p = StreamWeaver::Components::Pipeline.new(steps: [
        { label: "A", status: :complete },
        { label: "B", status: :active }
      ])
      html = render_html(p)
      expect(html).to include("sw-pipeline__arrow")
    end

    it "does not render arrow before first step" do
      p = StreamWeaver::Components::Pipeline.new(steps: [{ label: "A", status: :complete }])
      html = render_html(p)
      # Check only the rendered container, not the injected CSS
      container_start = html.index('class="sw-pipeline"')
      container_html = container_start ? html[container_start..] : html
      expect(container_html).not_to include("sw-pipeline__arrow")
    end

    it "has role=list on container" do
      p = StreamWeaver::Components::Pipeline.new(steps: [{ label: "A", status: :active }])
      html = render_html(p)
      expect(html).to include('role="list"')
    end

    it "has role=listitem on steps" do
      p = StreamWeaver::Components::Pipeline.new(steps: [{ label: "A", status: :active }])
      html = render_html(p)
      expect(html).to include('role="listitem"')
    end
  end

  # =========================================
  # CSS
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:css) { StreamWeaver::Adapter::AlpineJS::PIPELINE_CSS }

    it "all CSS class selectors use sw- prefix" do
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") && !l.strip.start_with?("@") }
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

    it "includes responsive media query for vertical layout" do
      expect(css).to include("@media")
      expect(css).to include("flex-direction: column")
    end
  end

  # =========================================
  # Lazy CSS injection
  # =========================================

  describe "lazy CSS injection" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    it "injects pipeline CSS on first render" do
      p = StreamWeaver::Components::Pipeline.new(steps: [{ label: "A", status: :active }])
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [p], state)
      expect(html).to include(".sw-pipeline {")
    end

    it "only injects CSS once for multiple pipelines" do
      # Use a fresh adapter for this test to avoid CSS from other tests
      fresh_adapter = StreamWeaver::Adapter::AlpineJS.new
      p1 = StreamWeaver::Components::Pipeline.new(steps: [{ label: "A", status: :active }])
      p2 = StreamWeaver::Components::Pipeline.new(steps: [{ label: "B", status: :complete }])
      html = StreamWeaver::ComponentRenderer.render_html(fresh_adapter, [p1, p2], {})
      # The CSS comment header appears exactly once per injection
      css_occurrences = html.scan("Pipeline Component Styles").count
      expect(css_occurrences).to eq(1)
    end
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#pipeline" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        pipeline steps: [{ label: "Build", status: :complete }]
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Pipeline) }
      expect(component).not_to be_nil
      expect(component.steps.first[:label]).to eq("Build")
    end

    it "passes steps with correct status" do
      app = StreamWeaver::App.new("Test") do
        pipeline steps: [
          { label: "Build", status: :complete },
          { label: "Test", status: :active }
        ]
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Pipeline) }
      expect(component.steps[0][:status]).to eq(:complete)
      expect(component.steps[1][:status]).to eq(:active)
    end
  end

  # =========================================
  # Adapter base interface
  # =========================================

  describe "Adapter::Base#render_pipeline" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_pipeline(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_pipeline/)
    end
  end
end
