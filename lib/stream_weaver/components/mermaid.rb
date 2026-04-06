# frozen_string_literal: true

module StreamWeaver
  module Components
    # Mermaid diagram component.
    # Renders Mermaid.js diagrams with optional zoom/pan support,
    # compact mode for card embedding, and theme-aware styling.
    #
    # CDN loading is lazy: Mermaid.js 11 (ESM) is only loaded when
    # this component is present on the page.
    #
    # sw- CSS classes:
    #   sw-mermaid              - outer container
    #   sw-mermaid--compact     - compact mode for card embedding
    #   sw-mermaid--zoom        - zoom/pan enabled
    #   sw-mermaid__diagram     - the diagram rendering area
    #   sw-mermaid__controls    - zoom control buttons
    #   sw-mermaid__btn         - individual zoom button
    #
    # @example Basic usage
    #   mermaid("graph LR; A-->B")
    #
    # @example With zoom
    #   mermaid("graph TD; A-->B-->C", zoom: true)
    #
    # @example Compact for cards
    #   mermaid("graph LR; A-->B", compact: true)
    #
    # @example ELK layout
    #   mermaid("graph TD; A-->B", layout: :elk)
    class Mermaid < Base
      attr_reader :code, :zoom, :compact, :layout, :theme_vars

      # @param code [String] Mermaid diagram definition
      # @param zoom [Boolean] Enable zoom/pan controls (default: false)
      # @param compact [Boolean] Compact mode for card embedding (default: false)
      # @param layout [Symbol] Layout engine (:default or :elk)
      # @param theme_vars [Hash, nil] Per-block Mermaid themeVariables overrides
      # @param options [Hash] Additional HTML options
      def initialize(code, zoom: false, compact: false, layout: :default, theme_vars: nil, **options)
        @code = code
        @zoom = zoom
        @compact = compact
        @layout = layout.to_sym
        @theme_vars = theme_vars
        super(**options)
      end

      def render(view, state)
        view.adapter.render_mermaid(view, self, state)
      end

      # Whether ELK layout engine is requested
      def elk?
        @layout == :elk
      end

      # Generate a unique ID for this diagram instance
      def diagram_id
        @diagram_id ||= "sw-mermaid-#{object_id}"
      end

      # Serialize theme_vars to JSON for the JS initializer
      def theme_vars_json
        return "null" unless @theme_vars
        require "json"
        JSON.generate(@theme_vars)
      end

      # CSS class list for the outer container
      def css_classes
        classes = ["sw-mermaid"]
        classes << "sw-mermaid--compact" if @compact
        classes << "sw-mermaid--zoom" if @zoom
        classes.join(" ")
      end
    end
  end
end
