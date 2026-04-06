# frozen_string_literal: true

RSpec.describe "KpiDashboard Component (T12)" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::KpiDashboard do
    let(:metrics) do
      [
        { value: "99.9%", label: "Uptime", color: :green, trend: :up },
        { value: "42ms", label: "Latency", trend: :down },
        { value: "1.2M", label: "Requests", trend: :flat }
      ]
    end

    it "initializes with metrics" do
      d = described_class.new(metrics: metrics)
      expect(d.metrics.length).to eq(3)
    end

    it "normalizes value to string" do
      d = described_class.new(metrics: [{ value: 42, label: "Count" }])
      expect(d.metrics.first[:value]).to eq("42")
    end

    it "normalizes color to symbol" do
      d = described_class.new(metrics: [{ value: "X", label: "Y", color: "green" }])
      expect(d.metrics.first[:color]).to eq(:green)
    end

    it "normalizes trend to symbol" do
      d = described_class.new(metrics: [{ value: "X", label: "Y", trend: "up" }])
      expect(d.metrics.first[:trend]).to eq(:up)
    end

    it "allows nil color and trend" do
      d = described_class.new(metrics: [{ value: "X", label: "Y" }])
      expect(d.metrics.first[:color]).to be_nil
      expect(d.metrics.first[:trend]).to be_nil
    end

    describe "#trend_arrow" do
      it "returns up arrow for :up" do
        d = described_class.new(metrics: metrics)
        expect(d.trend_arrow(d.metrics[0])).to eq("\u2191")
      end

      it "returns down arrow for :down" do
        d = described_class.new(metrics: metrics)
        expect(d.trend_arrow(d.metrics[1])).to eq("\u2193")
      end

      it "returns right arrow for :flat" do
        d = described_class.new(metrics: metrics)
        expect(d.trend_arrow(d.metrics[2])).to eq("\u2192")
      end

      it "returns nil for no trend" do
        d = described_class.new(metrics: [{ value: "X", label: "Y" }])
        expect(d.trend_arrow(d.metrics[0])).to be_nil
      end
    end

    describe "#card_css_class" do
      it "includes base class" do
        d = described_class.new(metrics: metrics)
        expect(d.card_css_class(d.metrics[0])).to include("sw-kpi-card")
      end

      it "includes color modifier when set" do
        d = described_class.new(metrics: metrics)
        expect(d.card_css_class(d.metrics[0])).to include("sw-kpi-card--green")
      end

      it "does not include color modifier when nil" do
        d = described_class.new(metrics: [{ value: "X", label: "Y" }])
        expect(d.card_css_class(d.metrics[0])).to eq("sw-kpi-card")
      end
    end

    describe "#trend_css_class" do
      it "includes trend modifier for :up" do
        d = described_class.new(metrics: metrics)
        expect(d.trend_css_class(d.metrics[0])).to include("sw-kpi-card__trend--up")
      end

      it "includes trend modifier for :down" do
        d = described_class.new(metrics: metrics)
        expect(d.trend_css_class(d.metrics[1])).to include("sw-kpi-card__trend--down")
      end

      it "includes trend modifier for :flat" do
        d = described_class.new(metrics: metrics)
        expect(d.trend_css_class(d.metrics[2])).to include("sw-kpi-card__trend--flat")
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

    it "renders dashboard container with sw-kpi-dashboard class" do
      d = StreamWeaver::Components::KpiDashboard.new(metrics: [{ value: "99.9%", label: "Uptime" }])
      html = render_html(d)
      expect(html).to include('class="sw-kpi-dashboard"')
    end

    it "renders metric cards" do
      d = StreamWeaver::Components::KpiDashboard.new(metrics: [
        { value: "99.9%", label: "Uptime", color: :green, trend: :up }
      ])
      html = render_html(d)
      expect(html).to include("99.9%")
      expect(html).to include("Uptime")
      expect(html).to include("sw-kpi-card--green")
    end

    it "renders trend arrows" do
      d = StreamWeaver::Components::KpiDashboard.new(metrics: [
        { value: "X", label: "Y", trend: :up }
      ])
      html = render_html(d)
      expect(html).to include("sw-kpi-card__trend--up")
    end

    it "does not render trend div when trend is nil" do
      d = StreamWeaver::Components::KpiDashboard.new(metrics: [
        { value: "X", label: "Y" }
      ])
      html = render_html(d)
      # Check only the rendered container, not the injected CSS
      container_start = html.index('class="sw-kpi-dashboard"')
      container_html = container_start ? html[container_start..] : html
      expect(container_html).not_to include("sw-kpi-card__trend")
    end

    it "includes staggered animation delay" do
      d = StreamWeaver::Components::KpiDashboard.new(metrics: [
        { value: "A", label: "L1" },
        { value: "B", label: "L2" }
      ])
      html = render_html(d)
      expect(html).to include("animation-delay: 0ms")
      expect(html).to include("animation-delay: 80ms")
    end

    it "renders value in sw-kpi-card__value" do
      d = StreamWeaver::Components::KpiDashboard.new(metrics: [{ value: "42", label: "Count" }])
      html = render_html(d)
      expect(html).to include("sw-kpi-card__value")
      expect(html).to include("42")
    end

    it "renders label in sw-kpi-card__label" do
      d = StreamWeaver::Components::KpiDashboard.new(metrics: [{ value: "42", label: "Count" }])
      html = render_html(d)
      expect(html).to include("sw-kpi-card__label")
      expect(html).to include("Count")
    end
  end

  # =========================================
  # CSS
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:css) { StreamWeaver::Adapter::AlpineJS::KPI_DASHBOARD_CSS }

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

    it "includes fadeIn animation" do
      expect(css).to include("sw-kpi-fadeIn")
      expect(css).to include("@keyframes")
    end

    it "uses --sw-* color variables" do
      expect(css).to include("--sw-success")
      expect(css).to include("--sw-info")
      expect(css).to include("--sw-error")
    end
  end

  # =========================================
  # Lazy CSS injection
  # =========================================

  describe "lazy CSS injection" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }

    it "injects KPI CSS on first render" do
      d = StreamWeaver::Components::KpiDashboard.new(metrics: [{ value: "X", label: "Y" }])
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [d], state)
      expect(html).to include(".sw-kpi-dashboard {")
    end

    it "only injects CSS once for multiple dashboards" do
      d1 = StreamWeaver::Components::KpiDashboard.new(metrics: [{ value: "A", label: "L1" }])
      d2 = StreamWeaver::Components::KpiDashboard.new(metrics: [{ value: "B", label: "L2" }])
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [d1, d2], state)
      css_occurrences = html.scan(".sw-kpi-dashboard {").count
      expect(css_occurrences).to eq(1)
    end
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#kpi_dashboard" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        kpi_dashboard metrics: [{ value: "99.9%", label: "Uptime", color: :green, trend: :up }]
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::KpiDashboard) }
      expect(component).not_to be_nil
      expect(component.metrics.first[:value]).to eq("99.9%")
    end

    it "passes all metric options" do
      app = StreamWeaver::App.new("Test") do
        kpi_dashboard metrics: [{ value: "42", label: "Count", color: :blue, trend: :down }]
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::KpiDashboard) }
      metric = component.metrics.first
      expect(metric[:color]).to eq(:blue)
      expect(metric[:trend]).to eq(:down)
    end
  end

  # =========================================
  # Adapter base interface
  # =========================================

  describe "Adapter::Base#render_kpi_dashboard" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_kpi_dashboard(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_kpi_dashboard/)
    end
  end
end
