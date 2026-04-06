# frozen_string_literal: true

require "json"

module StreamWeaver
  module Components
    # Chart.js wrapper component.
    # Renders a Chart.js chart (bar, line, pie, doughnut, radar).
    # CDN loads lazily -- Chart.js 4 is only loaded when this component is used.
    # Dark mode aware: reads --sw-text and --sw-border for grid/text colors.
    #
    # sw- CSS classes:
    #   sw-chart              - outer container
    #   sw-chart__canvas      - the canvas element
    #
    # @example Bar chart
    #   chart type: :bar, data: {
    #     labels: ["A", "B", "C"],
    #     datasets: [{ label: "Values", data: [1, 2, 3] }]
    #   }
    #
    # @example Line chart with custom height
    #   chart type: :line, data: { labels: [...], datasets: [...] }, height: 400
    #
    # @example Pie chart
    #   chart type: :pie, data: { labels: ["X", "Y"], datasets: [{ data: [60, 40] }] }
    class Chart < Base
      VALID_TYPES = %i[bar line pie doughnut radar].freeze
      CHART_JS_CDN = "https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js"

      attr_reader :chart_type, :data, :chart_options, :height

      # @param type [Symbol] Chart type (:bar, :line, :pie, :doughnut, :radar)
      # @param data [Hash] Chart.js data config (labels, datasets)
      # @param options [Hash] Chart.js options config
      # @param height [Integer] Canvas height in pixels (default: 300)
      def initialize(type:, data:, options: {}, height: 300, **extra)
        @chart_type = type.to_sym
        unless VALID_TYPES.include?(@chart_type)
          raise ArgumentError, "Invalid chart type: #{@chart_type}. Must be one of: #{VALID_TYPES.join(', ')}"
        end
        @data = data
        @chart_options = options
        @height = height
        super(**extra)
      end

      def render(view, state)
        view.adapter.render_chartjs(view, self, state)
      end

      # Generate a unique canvas ID for this chart instance
      def canvas_id
        @canvas_id ||= "sw-chart-#{object_id}"
      end

      # Serialize data to JSON for the JS initializer
      def data_json
        JSON.generate(deep_stringify(@data))
      end

      # Serialize options to JSON for the JS initializer
      def options_json
        JSON.generate(deep_stringify(@chart_options))
      end

      private

      # Deep-convert symbol keys to strings for JSON compatibility
      def deep_stringify(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(k, v), h|
            h[k.to_s] = deep_stringify(v)
          end
        when Array
          obj.map { |v| deep_stringify(v) }
        else
          obj
        end
      end
    end
  end
end
