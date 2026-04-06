# frozen_string_literal: true

RSpec.describe "Chart Component (T12)" do
  # =========================================
  # Component class
  # =========================================

  describe StreamWeaver::Components::Chart do
    let(:data) do
      { labels: ["A", "B", "C"], datasets: [{ label: "Values", data: [1, 2, 3] }] }
    end

    it "initializes with type and data" do
      c = described_class.new(type: :bar, data: data)
      expect(c.chart_type).to eq(:bar)
      expect(c.data).to eq(data)
    end

    it "defaults height to 300" do
      c = described_class.new(type: :bar, data: data)
      expect(c.height).to eq(300)
    end

    it "accepts custom height" do
      c = described_class.new(type: :bar, data: data, height: 500)
      expect(c.height).to eq(500)
    end

    it "accepts custom options" do
      opts = { responsive: true }
      c = described_class.new(type: :bar, data: data, options: opts)
      expect(c.chart_options).to eq(opts)
    end

    it "defaults options to empty hash" do
      c = described_class.new(type: :bar, data: data)
      expect(c.chart_options).to eq({})
    end

    it "normalizes type to symbol" do
      c = described_class.new(type: "line", data: data)
      expect(c.chart_type).to eq(:line)
    end

    it "raises on invalid chart type" do
      expect {
        described_class.new(type: :scatter, data: data)
      }.to raise_error(ArgumentError, /Invalid chart type/)
    end

    describe "valid chart types" do
      %i[bar line pie doughnut radar].each do |type|
        it "accepts :#{type}" do
          c = described_class.new(type: type, data: data)
          expect(c.chart_type).to eq(type)
        end
      end
    end

    describe "#canvas_id" do
      it "generates unique IDs" do
        c1 = described_class.new(type: :bar, data: data)
        c2 = described_class.new(type: :bar, data: data)
        expect(c1.canvas_id).not_to eq(c2.canvas_id)
      end

      it "starts with sw-chart-" do
        c = described_class.new(type: :bar, data: data)
        expect(c.canvas_id).to start_with("sw-chart-")
      end
    end

    describe "#data_json" do
      it "returns valid JSON" do
        c = described_class.new(type: :bar, data: data)
        parsed = JSON.parse(c.data_json)
        expect(parsed["labels"]).to eq(["A", "B", "C"])
        expect(parsed["datasets"].first["data"]).to eq([1, 2, 3])
      end

      it "deep-stringifies symbol keys" do
        c = described_class.new(type: :bar, data: { labels: ["X"], datasets: [{ data: [1] }] })
        json = c.data_json
        parsed = JSON.parse(json)
        expect(parsed).to have_key("labels")
        expect(parsed).to have_key("datasets")
      end
    end

    describe "#options_json" do
      it "returns valid JSON for empty options" do
        c = described_class.new(type: :bar, data: data)
        expect(c.options_json).to eq("{}")
      end

      it "returns valid JSON for non-empty options" do
        c = described_class.new(type: :bar, data: data, options: { responsive: true })
        parsed = JSON.parse(c.options_json)
        expect(parsed["responsive"]).to eq(true)
      end
    end
  end

  # =========================================
  # HTML rendering via adapter
  # =========================================

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }
    let(:data) do
      { labels: ["A", "B"], datasets: [{ data: [1, 2] }] }
    end

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    it "renders a chart container with sw-chart class" do
      c = StreamWeaver::Components::Chart.new(type: :bar, data: data)
      html = render_html(c)
      expect(html).to include('class="sw-chart"')
    end

    it "renders a canvas element" do
      c = StreamWeaver::Components::Chart.new(type: :bar, data: data)
      html = render_html(c)
      expect(html).to include("<canvas")
      expect(html).to include("sw-chart__canvas")
    end

    it "sets canvas height attribute" do
      c = StreamWeaver::Components::Chart.new(type: :bar, data: data, height: 400)
      html = render_html(c)
      expect(html).to include('height="400"')
    end

    it "sets chart type data attribute" do
      c = StreamWeaver::Components::Chart.new(type: :bar, data: data)
      html = render_html(c)
      expect(html).to include('data-sw-chart-type="bar"')
    end

    it "sets chart data as JSON data attribute" do
      c = StreamWeaver::Components::Chart.new(type: :bar, data: data)
      html = render_html(c)
      expect(html).to include("data-sw-chart-data=")
    end

    it "sets chart options as JSON data attribute" do
      c = StreamWeaver::Components::Chart.new(type: :bar, data: data, options: { responsive: true })
      html = render_html(c)
      expect(html).to include("data-sw-chart-options=")
    end

    it "sets unique canvas ID" do
      c = StreamWeaver::Components::Chart.new(type: :bar, data: data)
      html = render_html(c)
      expect(html).to match(/id="sw-chart-\d+"/)
    end
  end

  # =========================================
  # Chart.js CDN lazy loading
  # =========================================

  describe "lazy CDN loading" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state) { {} }
    let(:data) { { labels: ["A"], datasets: [{ data: [1] }] } }

    it "injects Chart.js CDN loader script on first render" do
      c = StreamWeaver::Components::Chart.new(type: :bar, data: data)
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [c], state)
      expect(html).to include("chart.js@4")
      expect(html).to include("cdn.jsdelivr.net")
    end

    it "injects chart init script with dark mode awareness" do
      c = StreamWeaver::Components::Chart.new(type: :bar, data: data)
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [c], state)
      expect(html).to include("--sw-text")
      expect(html).to include("--sw-border")
      expect(html).to include("getThemeColors")
    end

    it "only injects CDN/CSS once for multiple charts" do
      c1 = StreamWeaver::Components::Chart.new(type: :bar, data: data)
      c2 = StreamWeaver::Components::Chart.new(type: :line, data: data)
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [c1, c2], state)
      css_occurrences = html.scan(".sw-chart {").count
      expect(css_occurrences).to eq(1)
      cdn_occurrences = html.scan("chart.js@4").count
      expect(cdn_occurrences).to eq(1)
    end
  end

  # =========================================
  # CSS
  # =========================================

  describe "sw- CSS prefix convention" do
    let(:css) { StreamWeaver::Adapter::AlpineJS::CHART_CSS }

    it "all CSS class selectors use sw- prefix" do
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") }
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
  # Dark mode awareness
  # =========================================

  describe "dark mode awareness" do
    let(:js) { StreamWeaver::Adapter::AlpineJS::CHART_JS_INIT }

    it "reads --sw-text CSS custom property" do
      expect(js).to include("--sw-text")
    end

    it "reads --sw-border CSS custom property" do
      expect(js).to include("--sw-border")
    end

    it "applies theme colors to legend labels" do
      expect(js).to include("legend")
      expect(js).to include("labels")
    end

    it "applies theme colors to scale grids and ticks" do
      expect(js).to include("ticks")
      expect(js).to include("grid")
    end
  end

  # =========================================
  # DSL integration
  # =========================================

  describe "DisplayDSL#chart" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        chart type: :bar, data: { labels: ["A", "B"], datasets: [{ data: [1, 2] }] }
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Chart) }
      expect(component).not_to be_nil
      expect(component.chart_type).to eq(:bar)
    end

    it "passes custom height" do
      app = StreamWeaver::App.new("Test") do
        chart type: :line, data: { labels: ["X"], datasets: [{ data: [1] }] }, height: 500
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Chart) }
      expect(component.height).to eq(500)
    end

    it "passes chart options" do
      app = StreamWeaver::App.new("Test") do
        chart type: :pie, data: { labels: ["X", "Y"], datasets: [{ data: [60, 40] }] },
              options: { responsive: true }
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::Chart) }
      expect(component.chart_options[:responsive]).to eq(true)
    end
  end

  # =========================================
  # Adapter base interface
  # =========================================

  describe "Adapter::Base#render_chartjs" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_chartjs(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_chartjs/)
    end
  end
end
