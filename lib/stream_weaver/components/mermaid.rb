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

      # The diagram container's DOM id -- stable across re-renders of the same
      # document, not merely unique.
      #
      # morphdom pairs old and new nodes by id, so an id derived from object_id
      # (which changes every time the component tree is rebuilt) made every
      # patch remove the diagram's container and insert a fresh one. That threw
      # away the rendered SVG, the zoom/expand wiring and the guards that keep
      # that wiring from being stacked -- and worst, left an in-flight
      # mermaid.render() resolving into a node no longer in the document, so a
      # doc re-rendering faster than mermaid renders showed no diagram at all.
      # Observed live in the browser extension once it started the live runtime.
      #
      # Derived from what this diagram renders rather than from a counter, so it
      # needs no per-render bookkeeping to stay stable: String#hash is not
      # stable across hosts and Digest is not available under Opal, hence the
      # open-coded djb2. Two diagrams with identical source AND identical
      # options would collide, so `id:` wins when given.
      def diagram_id
        @diagram_id ||= @options[:id] || "sw-mermaid-#{render_digest}"
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

      private

      # Every input that reaches the rendered container, not just the source.
      #
      # The id is what makes a re-render reuse this container instead of
      # replacing it, and OpalRuntime#morph_options then leaves an
      # already-rendered container's subtree alone entirely -- so anything the
      # id ignores can never change on screen again. `css_classes` is built
      # from `zoom` and `compact`, and `layout`/`theme_vars` ride on the
      # container as data attributes (adapter/static.rb#render_mermaid), so all
      # four belong here alongside the code. Miss one and, for example,
      # `mermaid(src, zoom: state[:zoom])` renders its first value forever.
      #
      # Joined on NUL rather than a printable separator because mermaid source
      # is full of `|`, `-` and whitespace, and a separator the source can
      # contain lets two different option sets hash to the same string.
      def render_digest
        parts = [@code, @zoom, @compact, @layout, @theme_vars].join(0.chr)
        parts.bytes.reduce(5381) { |hash, byte| ((hash * 33) ^ byte) & 0xFFFF_FFFF }.to_s(36)
      end
    end
  end
end
