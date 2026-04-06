# frozen_string_literal: true

module StreamWeaver
  module Components
    # KPI Dashboard component.
    # Renders an auto-fit grid of metric cards, each showing a large value,
    # label, optional trend arrow, and optional color accent.
    # Entry animation via CSS fadeIn.
    #
    # sw- CSS classes:
    #   sw-kpi-dashboard         - outer grid container (auto-fit)
    #   sw-kpi-card              - individual metric card
    #   sw-kpi-card--{color}     - color accent variant
    #   sw-kpi-card__value       - large value display
    #   sw-kpi-card__label       - label below value
    #   sw-kpi-card__trend       - trend arrow indicator
    #   sw-kpi-card__trend--up   - green up arrow
    #   sw-kpi-card__trend--down - red down arrow
    #   sw-kpi-card__trend--flat - gray flat arrow
    #
    # @example
    #   kpi_dashboard metrics: [
    #     { value: "99.9%", label: "Uptime", color: :green, trend: :up },
    #     { value: "42ms",  label: "Latency", trend: :down },
    #     { value: "1.2M",  label: "Requests", trend: :flat }
    #   ]
    class KpiDashboard < Base
      attr_reader :metrics

      # @param metrics [Array<Hash>] Array of metric hashes with :value, :label, :color (optional), :trend (optional)
      #   trend values: :up, :down, :flat, nil
      #   color values: :green, :blue, :red, :orange, :purple, nil
      # @param options [Hash] Additional options
      def initialize(metrics:, **options)
        @metrics = metrics.map { |m| normalize_metric(m) }
        super(**options)
      end

      def render(view, state)
        view.adapter.render_kpi_dashboard(view, self, state)
      end

      # Trend arrow character for a metric
      def trend_arrow(metric)
        case metric[:trend]
        when :up   then "\u2191" # up arrow
        when :down then "\u2193" # down arrow
        when :flat then "\u2192" # right arrow
        end
      end

      # CSS class for trend indicator
      def trend_css_class(metric)
        base = "sw-kpi-card__trend"
        return base unless metric[:trend]
        "#{base} sw-kpi-card__trend--#{metric[:trend]}"
      end

      # CSS class for the card (with optional color)
      def card_css_class(metric)
        classes = ["sw-kpi-card"]
        classes << "sw-kpi-card--#{metric[:color]}" if metric[:color]
        classes.join(" ")
      end

      private

      def normalize_metric(m)
        {
          value: m[:value].to_s,
          label: m[:label] || "",
          color: m[:color] ? m[:color].to_sym : nil,
          trend: m[:trend] ? m[:trend].to_sym : nil
        }
      end
    end
  end
end
