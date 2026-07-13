# frozen_string_literal: true

require 'date'

module StreamWeaver
  # Component classes for UI elements
  module Components
    # Shared callback behavior for form components
    module Callbacks
      attr_reader :on_change, :on_blur, :debounce

      def execute_on_change(state, value)
        on_change&.call(state, value)
      end

      def execute_on_blur(state, value)
        on_blur&.call(state, value)
      end

      private

      def init_callbacks(on_change: nil, on_blur: nil, debounce: nil)
        @on_change = on_change
        @on_blur = on_blur
        @debounce = debounce
      end
    end

    # Base component class that all components inherit from
    class Base
      # Class-level macro: declare inline CSS for this component.
      # Multiple calls accumulate; all strings are emitted once per class per page.
      #
      # @example
      #   css ".my-banner { color: red }"
      def self.css(string)
        @component_css_strings ||= []
        @component_css_strings << string
      end

      # Class-level macro: declare a CSS file to serve alongside this component.
      # The file is served via the /sw-asset/ route (registered once at declaration time).
      #
      # @param path [String] Absolute path to the CSS file
      def self.css_path(path)
        @component_css_path = path
        ComponentAssets.register_file(path)
      end

      # Class-level macro: declare a JS file to serve alongside this component.
      #
      # @param path [String] Absolute path to the JS file
      def self.js_path(path)
        @component_js_path = path
        ComponentAssets.register_file(path)
      end

      def self.component_css_strings
        @component_css_strings || []
      end

      def self.component_css_path
        @component_css_path
      end

      def self.component_js_path
        @component_js_path
      end

      def initialize(**options)
        @options = options
      end

      # Render the component using Phlex view
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param state [Hash] The current state hash
      # @raise [NotImplementedError] if not implemented by subclass
      def render(view, state)
        raise NotImplementedError, "#{self.class} must implement #render"
      end

      # Return the state key for this component (if applicable)
      #
      # @return [Symbol, nil] The state key or nil
      def key
        nil
      end

      # Return child components (if applicable)
      #
      # @return [Array] Array of child components
      def children
        []
      end

      # Register interactive callbacks with the given registry.
      # Default: no-op — most components have no callbacks.
      # Interactive components override this to self-register.
      #
      # @param registry [Hash] Mutable hash mapping dom_id => callable
      def register_callbacks(registry)
        # Default: no interactive callbacks. Override in interactive components.
      end
    end

    class Fragment < Base
      attr_accessor :children
      attr_reader :name, :id

      def initialize(name, id)
        @name = name.to_sym
        @id = id
        @children = []
      end

      def render(view, state)
        view.div(id: id) do
          view.with_fragment(id) { children.each { |child| child.render(view, state) } }
        end
      end
    end

    # TextField component for single-line text input
    class TextField < Base
      include Callbacks
      attr_reader :key

      # @param key [Symbol] The state key
      # @param on_change [Proc, nil] Callback when value changes: ->(state, value) { ... }
      # @param on_blur [Proc, nil] Callback when field loses focus: ->(state, value) { ... }
      # @param debounce [Integer, nil] Milliseconds to wait before triggering on_change
      # @param options [Hash] Options (e.g., placeholder)
      def initialize(key, on_change: nil, on_blur: nil, debounce: nil, **options)
        @key = key
        @options = options
        init_callbacks(on_change: on_change, on_blur: on_blur, debounce: debounce)
      end

      def render(view, state)
        view.adapter.render_text_field(view, @key, callback_options, state)
      end

      private

      def callback_options
        @options.merge(on_change: on_change, on_blur: on_blur, debounce: debounce)
      end
    end

    # TextArea component for multi-line text input
    class TextArea < Base
      include Callbacks
      attr_reader :key

      # @param key [Symbol] The state key
      # @param on_change [Proc, nil] Callback when value changes: ->(state, value) { ... }
      # @param on_blur [Proc, nil] Callback when field loses focus: ->(state, value) { ... }
      # @param debounce [Integer, nil] Milliseconds to wait before triggering on_change
      # @param options [Hash] Options (e.g., placeholder, rows)
      def initialize(key, on_change: nil, on_blur: nil, debounce: nil, **options)
        @key = key
        @options = options
        init_callbacks(on_change: on_change, on_blur: on_blur, debounce: debounce)
      end

      def render(view, state)
        view.adapter.render_text_area(view, @key, callback_options, state)
      end

      private

      def callback_options
        @options.merge(on_change: on_change, on_blur: on_blur, debounce: debounce)
      end
    end

    # DateField component for native date input, state-bound like TextField.
    # Value is stored/read as an ISO 8601 string ("YYYY-MM-DD").
    class DateField < Base
      attr_reader :key

      # @param key [Symbol] The state key
      # @param label [String, nil] Optional label rendered above the input
      # @param min [String, nil] Minimum selectable date (ISO 8601)
      # @param max [String, nil] Maximum selectable date (ISO 8601)
      # @param options [Hash] Additional options (e.g. submit: false)
      def initialize(key, label: nil, min: nil, max: nil, **options)
        @key = key
        @options = options.merge(label: label, min: min, max: max)
      end

      def render(view, state)
        view.adapter.render_date_field(view, @key, @options, state)
      end

      # Coerce an ISO 8601 date string (as stored in state) to a Date.
      # Returns nil for blank or unparsable input instead of raising.
      #
      # @param value [String, nil]
      # @return [Date, nil]
      def self.to_date(value)
        return nil if value.nil? || value.to_s.strip.empty?

        Date.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end
    end

    # Button component that executes actions on click
    class Button < Base
      attr_reader :id, :modal_context, :options

      # @param label [String] Button label
      # @param stable_id [String] Stable ID suffix (hash of source location or counter)
      # @param options [Hash] Options (e.g., style: :primary or :secondary, modal_context: {key: :name})
      # @param block [Proc] Action block to execute
      def initialize(label, stable_id, **options, &block)
        @label = label
        @action = block
        @modal_context = options.delete(:modal_context)
        @options = options
        # stable_id is derived from source location (for buttons with blocks) or counter (for blockless)
        @button_id = "btn_#{label.downcase.gsub(/[^a-z0-9]+/, '_')}_#{stable_id}"
      end

      # Fill in options the author didn't already set (e.g. a table action
      # cell defaulting to size: :sm, variant: :quiet). Explicit @options
      # values always win.
      #
      # @param defaults [Hash]
      def apply_default_options(defaults)
        @options = defaults.merge(@options)
      end

      def render(view, state)
        # Delegate to adapter - no framework knowledge in component
        view.adapter.render_button(view, @button_id, @label, @options, @modal_context)
      end

      # Execute the button's action block
      #
      # @param state [Hash] The current state
      def execute(state)
        @action.call(state) if @action
      end

      def id
        @button_id
      end

      # Reassign id after duplicate-id auto-disambiguation (FAC-P0.1) -- see
      # App#disambiguate_component_id.
      def id=(new_id)
        @button_id = new_id
      end

      def register_callbacks(registry)
        registry[id] = @action if @action
      end
    end

    # Text component for displaying literal content (no markdown parsing)
    class Text < Base
      TONES = %i[muted caption error success].freeze

      attr_reader :tone

      # @param content [String, Proc] The text content (can be a proc for dynamic content)
      # @param tone [Symbol, nil] Visual tone -- :muted, :caption, :error, :success (03
      #   honorable mention: hand-coded hex/padding divs standing in for text variants)
      def initialize(content, tone: nil)
        @content = content
        @tone = TONES.include?(tone) ? tone : nil
      end

      def render(view, state)
        content = @content.is_a?(Proc) ? @content.call(state) : @content
        if @tone
          view.adapter.render_text(view, content.to_s, @tone)
        else
          view.p { content.to_s }
        end
      end
    end

    # AppHeader component for app header bars (full-width header with brand/actions)
    class AppHeader < Base
      attr_accessor :children
      attr_reader :title, :subtitle, :variant

      # @param title [String] The header title
      # @param subtitle [String, nil] Optional subtitle
      # @param variant [Symbol] Style variant (:dark, :light, :primary)
      def initialize(title, subtitle: nil, variant: :dark)
        @title = title
        @subtitle = subtitle
        @variant = variant
        @children = []
      end

      def render(view, state)
        view.adapter.render_app_header(view, self, state)
      end
    end

    # Div component for layout containers with optional hover support
    class Div < Base
      attr_accessor :children
      attr_reader :hover_class

      # @param options [Hash] Options (e.g., class: "container")
      # @option options [String] :hover_class CSS class to add on hover (client-side)
      def initialize(hover_class: nil, **options)
        @hover_class = hover_class
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_div(view, self, state)
      end
    end

    # Checkbox component for boolean input
    class Checkbox < Base
      include Callbacks
      attr_reader :key, :options

      # @param key [Symbol] The state key
      # @param label [String] The label text
      # @param on_change [Proc, nil] Callback when checkbox changes: ->(state, value) { ... }
      # @param options [Hash] Additional options
      def initialize(key, label, on_change: nil, **options)
        @key = key
        @label = label
        @options = options
        init_callbacks(on_change: on_change)
      end

      def render(view, state)
        view.adapter.render_checkbox(view, @key, @label, @options.merge(on_change: on_change), state)
      end
    end

    # Select component for dropdown selection
    class Select < Base
      include Callbacks
      attr_reader :key

      # @param key [Symbol] The state key
      # @param choices [Array<String>] The available choices
      # @param on_change [Proc, nil] Callback when selection changes: ->(state, value) { ... }
      # @param options [Hash] Additional options
      def initialize(key, choices, on_change: nil, **options)
        @key = key
        @choices = choices
        @options = options
        init_callbacks(on_change: on_change)
      end

      def render(view, state)
        view.adapter.render_select(view, @key, @choices, @options.merge(on_change: on_change), state)
      end
    end

    # RadioGroup component for single-choice selection (radio buttons)
    # Unlike Select, radio buttons show all options at once and have no pre-selected value
    class RadioGroup < Base
      attr_reader :key

      # @param key [Symbol] The state key
      # @param choices [Array<String>] The available choices
      # @param options [Hash] Additional options (e.g., placeholder)
      def initialize(key, choices, **options)
        @key = key
        @choices = choices
        @options = options
      end

      def render(view, state)
        # Delegate to adapter - no framework knowledge in component
        view.adapter.render_radio_group(view, @key, @choices, @options, state)
      end
    end

    # Card component for visual grouping of content
    class Card < Base
      VALID_DEPTHS = %i[hero elevated default recessed glass].freeze

      attr_accessor :children
      attr_reader :depth, :accent, :label

      # @param depth [Symbol] Depth tier (:hero, :elevated, :default, :recessed, :glass)
      # @param accent [Symbol, String, nil] Accent color for left border (:a, :b, :c or CSS color)
      # @param label [String, nil] Corner label text (e.g. "RISK", "NEW")
      # @param options [Hash] Options (e.g., class: "question-card")
      def initialize(depth: nil, accent: nil, label: nil, **options)
        @depth = depth
        @accent = accent
        @label = label
        @options = options
        @children = []
      end

      def render(view, state)
        classes = ["card"]
        classes << "sw-card--#{@depth}" if @depth && VALID_DEPTHS.include?(@depth)
        classes << "sw-card--accent-#{@accent}" if @accent.is_a?(Symbol)
        classes << "sw-card--accent" if @accent && !@accent.is_a?(Symbol)
        classes << @options[:class] if @options[:class]
        attrs = { class: classes.join(" ") }

        # Build inline style for custom accent and/or label positioning
        styles = []
        styles << "border-left-color: #{@accent};" if @accent && !@accent.is_a?(Symbol)
        styles << "position: relative;" if @label
        styles << @options[:style] if @options[:style]
        attrs[:style] = styles.join(" ") unless styles.empty?

        view.div(**attrs) do
          if @label
            view.span(class: "sw-card__label") { @label }
          end
          @children.each { |child| child.render(view, state) }
        end
      end
    end

    # CardHeader component for card header section
    class CardHeader < Base
      attr_accessor :children

      # @param content [String, nil] Optional string content (renders as h4)
      # @param options [Hash] Additional options
      # @option options [String] :badge Optional badge text (e.g. "C1") rendered before the title
      # @option options [String] :meta Optional right-aligned meta text
      def initialize(content = nil, **options)
        @content = content
        @options = options
        @badge = options[:badge]
        @meta = options[:meta]
        @children = []
      end

      def render(view, state)
        badged = @badge || @meta
        view.div(class: badged ? "card-header card-header--badged" : "card-header") do
          view.span(class: "card-header__badge") { @badge } if @badge
          if @content
            badged ? view.h4(class: "card-header__title") { @content } : view.h4 { @content }
          end
          view.span(class: "card-header__meta") { @meta } if @meta
          @children.each { |child| child.render(view, state) }
        end
      end
    end

    # CardBody component for card main content section
    class CardBody < Base
      attr_accessor :children

      # @param options [Hash] Additional options
      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        view.div(class: "card-body") do
          @children.each { |child| child.render(view, state) }
        end
      end
    end

    # CardFooter component for card footer section (typically for actions)
    class CardFooter < Base
      attr_accessor :children

      # @param options [Hash] Additional options
      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        view.div(class: "card-footer") do
          @children.each { |child| child.render(view, state) }
        end
      end
    end

    # VStack component for vertical stacking with spacing
    class VStack < Base
      attr_reader :spacing, :align, :divider, :options
      attr_accessor :children

      def initialize(spacing: :md, align: nil, divider: false, **options)
        @spacing = spacing
        @align = align
        @divider = divider
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_vstack(view, self, state)
      end
    end

    # HStack component for horizontal stacking with spacing
    class HStack < Base
      attr_reader :spacing, :align, :justify, :divider, :options
      attr_accessor :children

      def initialize(spacing: :sm, align: nil, justify: nil, divider: false, **options)
        @spacing = spacing
        @align = align
        @justify = justify
        @divider = divider
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_hstack(view, self, state)
      end
    end

    # Grid component for responsive grid layouts
    class Grid < Base
      attr_reader :columns, :gap, :template, :template_areas, :template_rows, :template_columns, :options
      attr_accessor :children

      def initialize(columns: 3, gap: :md, template: nil, template_areas: nil, template_rows: nil, template_columns: nil, **options)
        @columns = columns
        @gap = gap
        @template = template
        @template_areas = template_areas
        @template_rows = template_rows
        @template_columns = template_columns
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_grid(view, self, state)
      end
    end

    # GridArea — sets grid-area on its container div, for use inside named-area grids.
    class GridArea < Base
      attr_reader :area_name, :options
      attr_accessor :children

      def initialize(area_name, **options)
        @area_name = area_name.to_s
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_grid_area(view, self, state)
      end
    end

    # Sticky — wraps content in a position:sticky container.
    class Sticky < Base
      attr_reader :top, :bottom, :left, :right, :z_index, :options
      attr_accessor :children

      def initialize(top: nil, bottom: nil, left: nil, right: nil, z_index: nil, **options)
        @top    = top
        @bottom = bottom
        @left   = left
        @right  = right
        @z_index = z_index
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_sticky(view, self, state)
      end
    end

    # Overlay — wraps content in a position:absolute overlay.
    class Overlay < Base
      attr_reader :z, :pointer_events, :options
      attr_accessor :children

      def initialize(z: 1, pointer_events: nil, **options)
        @z = z
        @pointer_events = pointer_events
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_overlay(view, self, state)
      end
    end

    # Fullbleed — escapes parent max-width constraints for a full-width region.
    class Fullbleed < Base
      attr_reader :options
      attr_accessor :children

      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_fullbleed(view, self, state)
      end
    end

    # Phrase component for plain text within lesson content
    class Phrase < Base
      # @param content [String] The text content
      def initialize(content)
        @content = content
      end

      def render(view, state)
        view.span { @content }
      end
    end

    # Term component for hoverable glossary terms with tooltips
    class Term < Base
      attr_reader :term_key

      # @param term_key [String] The term to display (also used as glossary key)
      # @param options [Hash] Options (e.g., display: "alternate text")
      def initialize(term_key, **options)
        @term_key = term_key
        @options = options
      end

      def render(view, state)
        # Delegate to adapter - no framework knowledge in component
        view.adapter.render_term(view, @term_key, @options, state)
      end
    end

    # LessonText component for interactive educational content with glossary tooltips
    class LessonText < Base
      attr_accessor :children
      attr_reader :glossary

      # @param glossary [Hash] Glossary definitions {term => {simple:, detailed:}}
      # @param options [Hash] Additional options
      def initialize(glossary: {}, **options)
        @glossary = glossary
        @options = options
        @children = []
      end

      def render(view, state)
        # Delegate to adapter - no framework knowledge in component
        view.adapter.render_lesson_text(view, @glossary, @children, @options, state)
      end
    end

    # ScrollBox component for scrollable content with max-height
    class ScrollBox < Base
      attr_reader :max_height, :options
      attr_accessor :children

      def initialize(max_height: "300px", **options)
        @max_height = max_height
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_scroll_box(view, self, state)
      end
    end

    # Collapsible component for expandable/collapsible content sections
    class Collapsible < Base
      attr_accessor :children

      # @param label [String] The header label text
      # @param expanded [Boolean] Whether to start expanded (default: false)
      # @param options [Hash] Additional options
      def initialize(label, expanded: false, **options)
        @label = label
        @expanded = expanded
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_collapsible(view, @label, @expanded, @children, @options, state)
      end
    end

    # Accordion container -- groups AccordionSection children. Native
    # <details>/<summary>, no state key, no JS (03 gap #7).
    class Accordion < Base
      attr_accessor :children

      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_accordion(view, @children, @options, state)
      end
    end

    # Single disclosure panel within an Accordion.
    class AccordionSection < Base
      attr_accessor :children
      attr_reader :title, :open

      # @param title [String] Always-visible summary text
      # @param open [Boolean] Whether the panel starts expanded (default: false)
      # @param options [Hash] Additional options
      def initialize(title, open: false, **options)
        @title = title
        @open = open
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_accordion_section(view, self, state)
      end
    end

    # Semantic accent tones shared by Lane headers and BoardCard accents --
    # reuse the existing --sw-success/warning/error/info theme tokens (FAC-8mj
    # tyrion parity: per-lane color identity -- gold/red/green -- had no
    # first-class option before this) rather than inventing app-specific
    # color names. An app that wants tyrion's exact gold/red/green still
    # picks the closest tone (:warning/:error/:success) and layers its own
    # CSS on top for the exact hue.
    BOARD_TONES = %i[neutral success warning error info].freeze

    # Static Kanban board -- groups Lane children. No drag-and-drop (03 gap
    # #9); a future primitive can add it without changing this shape.
    class Board < Base
      attr_accessor :children
      attr_reader :options

      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_board(view, @children, @options, state)
      end
    end

    # Single column within a Board. Children are typically BoardCards, but
    # any component is accepted directly (e.g. an empty-state text).
    #
    # @option tone [Symbol] one of BOARD_TONES -- colors the lane header band
    # @option subtitle [String] small text under the title (e.g. "In Progress")
    class Lane < Base
      attr_accessor :children
      attr_reader :title, :tone, :subtitle

      def initialize(title, tone: nil, subtitle: nil, **options)
        @title = title
        @tone = tone if BOARD_TONES.include?(tone)
        @subtitle = subtitle
        @options = options
        @children = []
      end

      # Card count for the lane header -- derived from children so it can
      # never drift from what's actually rendered (Forrest's Law: anything
      # that can happen automatically, must).
      def count = @children.size

      def render(view, state)
        view.adapter.render_lane(view, self, state)
      end
    end

    # A single card within a Lane.
    #
    # @option tone [Symbol] one of BOARD_TONES -- left-border accent color
    class BoardCard < Base
      attr_accessor :children
      attr_reader :tone, :options

      def initialize(tone: nil, **options)
        @tone = tone if BOARD_TONES.include?(tone)
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_board_card(view, @children, @options.merge(tone: @tone), state)
      end
    end

    # ScoreTable component for displaying metrics with color-coded scores
    class ScoreTable < Base
      # @param scores [Array<Hash>] Array of {label:, value:, max:} hashes
      # @param options [Hash] Additional options
      def initialize(scores:, **options)
        @scores = scores
        @options = options
      end

      def render(view, state)
        view.adapter.render_score_table(view, @scores, @options, state)
      end
    end

    # Built-in formatters for table cell values
    module TableFormatters
      FORMATTERS = {
        date: ->(v) { v.respond_to?(:strftime) ? v.strftime("%b %d, %Y") : v.to_s },
        datetime: ->(v) { v.respond_to?(:strftime) ? v.strftime("%b %d, %Y %l:%M %p") : v.to_s },
        currency: ->(v) { "$#{format_number(v.to_f, 2)}" },
        number: ->(v) { format_number(v.to_f, 0) },
        percent: ->(v) { "#{(v.to_f * 100).round}%" }
      }.freeze

      def self.format_number(num, decimals)
        parts = format("%.#{decimals}f", num).split(".")
        parts[0] = parts[0].reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
        decimals.positive? ? parts.join(".") : parts[0]
      end

      def self.apply(value, format_spec)
        return value.to_s if format_spec.nil?

        formatter = format_spec.is_a?(Proc) ? format_spec : FORMATTERS[format_spec]
        formatter ? formatter.call(value) : value.to_s
      end
    end

    # Column definition for table DSL
    class TableColumn
      attr_reader :key, :header, :format, :align, :style, :sort_value

      def initialize(key, header: nil, format: nil, align: nil, style: nil, sort_value: nil, &block)
        @key = key
        @header = header || key.to_s.split("_").map(&:capitalize).join(" ")
        @format = format
        @align = align
        @style = style
        @sort_value = sort_value
        @value_block = block
      end

      # @param item [Object] The row's item
      # @param index [Integer, nil] The row's index
      # @param app [StreamWeaver::App, nil] When given, the block is executed via
      #   app.instance_exec so it can call component-builder DSL methods
      #   (button, badge, hstack, ...); anything it builds is captured and
      #   returned as an Array<Components::Base> instead of a formatted scalar
      #   (FAC-P2.1 decision 1). Without an app, behavior is unchanged.
      def extract_value(item, index = nil, app: nil, fragment: nil)
        return extract_component_cell(item, index, app, fragment) if app && @value_block

        raw = if @value_block
                @value_block.arity == 2 ? @value_block.call(item, index) : @value_block.call(item)
              elsif item.respond_to?(@key)
                item.send(@key)
              elsif item.respond_to?(:[])
                item[@key] || item[@key.to_s]
              else
                nil
              end
        TableFormatters.apply(raw, @format)
      end

      private

      def extract_component_cell(item, index, app, fragment)
        parent_components = app.components
        pushed_fragment = fragment && app.render_state.fragment_stack.last != fragment
        app.render_state.fragment_stack << fragment if pushed_fragment
        app.components = []
        raw = @value_block.arity == 2 ? app.instance_exec(item, index, &@value_block) : app.instance_exec(item, &@value_block)
        built = app.components
        app.components = parent_components

        built.any? ? built : TableFormatters.apply(raw, @format)
      ensure
        app.render_state.fragment_stack.pop if pushed_fragment
      end
    end

    # Table component for displaying tabular data with smart data inference
    # @example Basic usage (original API)
    #   table headers: ["Name", "Size"], rows: [["app.rb", "12kb"], ["cli.rb", "8kb"]]
    # @example Array of hashes (auto-infer headers)
    #   table data: [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }]
    # @example Hash of arrays
    #   table data: { name: ["Alice", "Bob"], age: [30, 25] }
    # @example File loading
    #   table file: "users.yaml", path: "data.users"
    # @example State binding
    #   table data: :users
    # @example Column DSL
    #   table users do
    #     column :name
    #     column :balance, format: :currency, align: :right
    #   end
    class Table < Base
      attr_reader :columns, :resolved_rows
      # Deterministic DOM id assigned by the `table` DSL method (display_dsl.rb)
      # for column-DSL tables, used to build stable `<tr id="#{dom_id}-row-#{key}">`
      # ids that survive across rebuilds (see that method for why -- FAC row-granular
      # narrowing, stream_weaver-95k). nil for tables that don't need row addressing.
      attr_accessor :dom_id

      # Lazily resolves and memoizes a row's key, so column blocks that never
      # build a button never pay the cost (or the ArgumentError) of an
      # unresolvable row_key (FAC-P2.1 decision 3).
      class RowKeyThunk
        def initialize(&resolver)
          @resolver = resolver
        end

        def value
          return @value if defined?(@value)
          @value = @resolver.call
        end
      end

      def key
        @data
      end

      def children
        @children || []
      end

      def initialize(data = nil, headers: nil, rows: nil, file: nil, path: nil,
                     striped: false, bordered: false, hoverable: true, compact: false,
                     sortable: false, sticky_header: false, markdown: false, caption: nil,
                     alternating: false, scrollable: false, hover: false, row_key: nil, **options, &block)
        @data = data
        @headers = headers
        @rows = rows
        @file = file
        @path = path
        @striped = striped
        @bordered = bordered
        @hoverable = hoverable
        @compact = compact
        @sortable = sortable
        @sticky_header = sticky_header
        @markdown = markdown
        @caption = caption
        @alternating = alternating
        @scrollable = scrollable
        @hover = hover
        @row_key_proc = row_key
        @options = options
        @columns = []
        @transform_block = nil

        if block_given?
          if block.arity == 1
            # Transform block: table file: "data.yaml" do |data| data.map {...} end
            @transform_block = block
          else
            # Column DSL block
            instance_eval(&block)
          end
        end
      end

      # Column DSL method
      def column(key, header: nil, format: nil, align: nil, style: nil, sort_value: nil, &block)
        @columns << TableColumn.new(key, header: header, format: format, align: align, style: style, sort_value: sort_value, &block)
      end

      # Resolves headers/rows (and, for the column DSL, cell components/sort
      # values/row ids) once. Called eagerly by the `table` DSL method with the
      # owning app so component cells and their buttons exist before dispatch
      # ever runs (FAC-P2.1 decision 4) -- and lazily, without an app, from
      # #render for Table instances built directly (legacy/scalar-only path).
      def resolve!(app, state, fragment: nil)
        return self if @resolved

        resolved = resolve_data(state, app, fragment)
        @resolved_headers = resolved[:headers]
        @resolved_rows = resolved[:rows]
        @sort_values = resolved[:sort_values] || []
        @component_columns = resolved[:component_columns] || []
        @row_ids = resolved[:row_ids] || []
        @children = @resolved_rows.flat_map { |row| row.flat_map { |cell| cell.is_a?(Array) ? cell : [] } }
        @resolved = true
        self
      end

      def render(view, state)
        resolve!(nil, state) unless @resolved
        view.adapter.render_table(view, @resolved_headers, @resolved_rows, table_options, state)
      end

      def register_callbacks(registry)
        # Sort is client-side only. Only supported when @data is a Symbol (state-bound key).
        # Direct-data tables (headers:/rows: without state key) cannot sort — @data would be nil.
        # Server-paginated sort requires app-level state + re-query; this only sorts in-memory rows.
        # Sort state uses string keys to avoid collision with update_state, which symbolizes all keys.
        return unless @sortable && @data.is_a?(Symbol)
        col_count = @headers ? @headers.length : Array(@columns).length
        col_count.times do |col_index|
          registry["#{key}_sort_#{col_index}"] = ->(state) {
            if state["#{key}_sort_col"] == col_index
              state["#{key}_sort_dir"] = state["#{key}_sort_dir"] == :asc ? :desc : :asc
            else
              state["#{key}_sort_col"] = col_index
              state["#{key}_sort_dir"] = :asc
            end
          }
        end
      end

      private

      def resolve_data(state, app = nil, fragment = nil)
        raw = raw_data(state)
        normalize(raw, app, fragment)
      end

      def raw_data(state)
        return file_data if @file
        return state[@data] if @data.is_a?(Symbol) && @rows.nil?
        return @data if @data && !@data.is_a?(Symbol)
        { headers: @headers || [], rows: @rows || [] }
      end

      def file_data
        raw = load_file(@file)
        @transform_block ? @transform_block.call(raw) : extract_path(raw, @path)
      end

      def load_file(path)
        require "yaml"
        require "json"
        expanded = File.expand_path(path)

        case File.extname(expanded).downcase
        when ".yaml", ".yml" then YAML.safe_load_file(expanded, symbolize_names: true, permitted_classes: [Symbol, Date, Time])
        when ".json" then JSON.parse(File.read(expanded), symbolize_names: true)
        else raise ArgumentError, "Unsupported file type: #{path}. Use .yaml, .yml, or .json"
        end
      end

      def extract_path(data, path)
        return data unless path

        path.split(".").reduce(data) do |obj, key|
          break if obj.nil?
          key.match?(/\A-?\d+\z/) ? obj[key.to_i] : obj.fetch(key.to_sym) { obj[key] }
        end
      end

      def normalize(data, app = nil, fragment = nil)
        return data if data.is_a?(Hash) && data.key?(:headers) && data.key?(:rows)

        case data
        when Array
          normalize_array(data, app, fragment)
        when Hash
          normalize_hash_of_arrays(data)
        else
          { headers: [], rows: [] }
        end
      end

      def normalize_array(data, app, fragment)
        return { headers: [], rows: [] } if data.empty?

        first = data.first
        if @columns.any?
          # Column DSL - works for Hash rows and for any object the columns'
          # keys/blocks know how to read (structs, records, ...).
          build_column_rows(data, app, fragment)
        elsif first.is_a?(Hash)
          keys = first.keys
          headers = keys.map { |k| k.to_s.split("_").map(&:capitalize).join(" ") }
          rows = data.map { |item| keys.map { |k| (item[k] || item[k.to_s]).to_s } }
          { headers: headers, rows: rows }
        elsif first.is_a?(Array)
          # Array of arrays - original format, no headers unless provided
          { headers: @headers || [], rows: data }
        else
          # Simple array - single column
          { headers: @headers || ["Value"], rows: data.map { |v| [v.to_s] } }
        end
      end

      def build_column_rows(data, app, fragment)
        headers = @columns.map(&:header)
        rows = []
        sort_values = []
        row_ids = []

        data.each_with_index do |item, idx|
          row_key_thunk = RowKeyThunk.new { resolve_row_key(item) }
          had_render_state = app.respond_to?(:render_state)
          saved_thunk = app.render_state.current_row_key_thunk if had_render_state
          app.render_state.current_row_key_thunk = row_key_thunk if had_render_state

          rows << @columns.map { |col| col.extract_value(item, idx, app: app, fragment: fragment) }
          sort_values << @columns.map { |col| col.sort_value ? col.sort_value.call(item) : nil }
          row_ids << row_dom_key(item)

          app.render_state.current_row_key_thunk = saved_thunk if had_render_state
        end

        component_columns = @columns.each_index.map { |ci| rows.any? { |row| row[ci].is_a?(Array) } }

        { headers: headers, rows: rows, sort_values: sort_values, component_columns: component_columns, row_ids: row_ids }
      end

      # @raise [ArgumentError] when no row_key: proc was given and the item has
      #   neither #id nor a :id/"id" Hash key (FAC-P2.1 decision 3). Only
      #   invoked when something actually needs the key (a button built inside
      #   a cell, or DOM row-id assignment) -- rows whose cells stay scalar
      #   never pay for this.
      def resolve_row_key(item)
        return @row_key_proc.call(item) if @row_key_proc
        return item.id if item.respond_to?(:id)
        if item.is_a?(Hash)
          return item[:id] if item.key?(:id)
          return item["id"] if item.key?("id")
        end

        raise ArgumentError,
              "table: cannot derive a row_key for #{item.inspect} -- pass row_key: ->(item) { ... } " \
              "to `table`, or give each item an #id method or :id/\"id\" key."
      end

      # DOM row ids are best-effort: an unresolvable row_key just means no
      # <tr id> is assigned, never a raise (FAC-P2.1 decision 7).
      def row_dom_key(item)
        resolve_row_key(item)
      rescue ArgumentError
        nil
      end

      def normalize_hash_of_arrays(data)
        # Hash of arrays: { name: ["Alice", "Bob"], age: [30, 25] }
        keys = data.keys
        headers = keys.map { |k| k.to_s.split("_").map(&:capitalize).join(" ") }
        max_len = data.values.map(&:length).max || 0
        rows = (0...max_len).map do |i|
          keys.map { |k| (data[k][i] || "").to_s }
        end
        { headers: headers, rows: rows }
      end

      def table_options
        @options.merge(
          key: @data,
          striped: @striped,
          bordered: @bordered,
          hoverable: @hoverable,
          compact: @compact,
          sortable: @sortable,
          sticky_header: @sticky_header,
          markdown: @markdown,
          caption: @caption,
          columns: @columns,
          alternating: @alternating,
          scrollable: @scrollable,
          hover: @hover,
          sort_values: @sort_values || [],
          component_columns: @component_columns || [],
          row_ids: @row_ids || [],
          dom_id: @dom_id
        )
      end
      # #table_options is a pure derived-data reader (no side effects); the
      # adapter calls it, and InteractionRunner's row-narrowing (stream_weaver-95k)
      # needs it too to compare a table's pre/post-mutation row identity.
      public :table_options
    end

    # Markdown component for rendering markdown-formatted content
    class Markdown < Base
      # @param content [String, Proc] The markdown content (can be a proc for dynamic content)
      def initialize(content)
        @content = content
      end

      def render(view, state)
        content = @content.is_a?(Proc) ? @content.call(state) : @content
        view.adapter.render_markdown(view, content.to_s, state)
      end
    end

    # Header component for semantic headers (h1-h6)
    class Header < Base
      attr_reader :level

      # @param content [String, Proc] The header text (can be a proc for dynamic content)
      # @param level [Integer] Header level (1-6, default: 2)
      def initialize(content, level: 2)
        @content = content
        @level = level.clamp(1, 6)
      end

      def render(view, state)
        content = @content.is_a?(Proc) ? @content.call(state) : @content
        view.adapter.render_header(view, content.to_s, @level, state)
      end
    end

    # CheckboxGroup component for multi-select with select all/none
    # State is stored as an array of selected values
    class CheckboxGroup < Base
      attr_reader :key
      attr_accessor :children

      # @param key [Symbol] The state key (stores array of selected values)
      # @param options [Hash] Options including select_all, select_none labels
      def initialize(key, **options)
        @key = key
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_checkbox_group(view, @key, @children, @options, state)
      end
    end

    # CheckboxItem component - individual item within a CheckboxGroup
    class CheckboxItem < Base
      attr_reader :value
      attr_accessor :children

      # @param value [String] The value added to the group's array when checked
      def initialize(value)
        @value = value
        @children = []
      end
    end

    # StatusBadge component for visual match indicators
    # Displays: 🟢 Strong / 🟡 Maybe / 🔴 Skip with reasoning
    class StatusBadge < Base
      # @param status [Symbol] One of :strong, :maybe, :skip
      # @param reasoning [String] Explanation text
      def initialize(status, reasoning)
        @status = status
        @reasoning = reasoning
      end

      def render(view, state)
        view.adapter.render_status_badge(view, @status, @reasoning, state)
      end
    end

    # TagButtons component for quick-select tag groups
    # Single-select: clicking a tag selects it (and deselects others)
    class TagButtons < Base
      attr_reader :key

      # @param key [Symbol] The state key for selected tag
      # @param tags [Array<String>] The available tag labels
      # @param options [Hash] Options (e.g., style: :destructive)
      def initialize(key, tags, **options)
        @key = key
        @tags = tags
        @options = options
      end

      def render(view, state)
        view.adapter.render_tag_buttons(view, @key, @tags, @options, state)
      end
    end

    # ChipGroup component for tag/chip multi-select bound to a state array.
    # multi: true (default) stores an Array of selected values; multi: false
    # stores a single scalar (radio-style exclusive selection).
    class ChipGroup < Base
      attr_reader :key, :choices, :multi, :options

      # @param key [Symbol] The state key (Array when multi, scalar otherwise)
      # @param choices [Array<String>, Array<Array(String, Object)>] Chip labels,
      #   or [label, value] pairs
      # @param multi [Boolean] Multi-select (Array state) vs single-select (default: true)
      # @param options [Hash] Additional options (e.g. submit: false)
      def initialize(key, choices = [], multi: true, **options)
        @key = key
        @choices = choices
        @multi = multi
        @options = options
      end

      def render(view, state)
        view.adapter.render_chip_group(view, self, state)
      end
    end

    # ExternalLinkButton component - opens URL and optionally submits form
    class ExternalLinkButton < Base
      # @param label [String] Button label
      # @param url [String] URL to open in new tab
      # @param submit [Boolean] Whether to also submit the form (default: false)
      def initialize(label, url:, submit: false)
        @label = label
        @url = url
        @submit = submit
      end

      def render(view, state)
        view.adapter.render_external_link_button(view, @label, @url, @submit, state)
      end
    end

    # Columns component for multi-column layouts
    # Contains Column children for flexible sidebar/content arrangements
    class Columns < Base
      attr_accessor :children
      attr_reader :widths

      # @param widths [Array<String>, nil] Optional column widths (e.g., ['30%', '70%'])
      # @param options [Hash] Additional options (e.g., gap)
      def initialize(widths: nil, **options)
        @widths = widths
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_columns(view, @widths, @children, @options, state)
      end
    end

    # Column component - individual column within a Columns container
    class Column < Base
      attr_accessor :children, :width

      # @param options [Hash] Options (e.g., class for additional styling)
      def initialize(**options)
        @options = options
        @children = []
        @width = nil # Set by parent Columns during render
      end

      def render(view, state)
        view.adapter.render_column(view, @width, @children, @options, state)
      end
    end

    # Form component for deferred submission forms
    # Groups multiple form elements together, uses client-side only state until submission,
    # and sends all values in a single HTMX POST on submit.
    class Form < Base
      attr_reader :name, :submit_label, :cancel_label, :submit_action
      attr_accessor :children

      # @param name [Symbol] The form name (used as state key, e.g., :edit_person)
      # @param options [Hash] Additional options
      def initialize(name, **options)
        @name = name
        @options = options
        @children = []
        @submit_label = nil
        @cancel_label = nil
        @submit_action = nil
      end

      # Set the submit button configuration
      # @param label [String] Button label text
      # @param block [Proc] Action to execute on submit (receives form_values hash)
      def set_submit(label, &block)
        @submit_label = label
        @submit_action = block
      end

      # Set the cancel button configuration
      # @param label [String] Button label text
      def set_cancel(label)
        @cancel_label = label
      end

      # Execute the submit action block
      # @param state [Hash] Current state hash
      # @param form_values [Hash] The submitted form values
      def execute_submit(state, form_values)
        @submit_action&.call(form_values)
      end

      def render(view, state)
        view.adapter.render_form(view, @name, @children, @submit_label, @cancel_label, @options, state)
      end
    end

    # =========================================
    # Navigation Components
    # =========================================

    # Tabs container component for tabbed navigation
    # Contains Tab children, manages active tab state via state key
    class Tabs < Base
      attr_reader :key, :variant, :lazy, :options
      attr_accessor :children

      # @param key [Symbol] The state key for active tab index
      # @param variant [Symbol] Visual variant (:line, :enclosed, :soft-rounded)
      # @param lazy [Boolean] When true, only render active tab content and morph on switch
      # @param options [Hash] Additional options
      def initialize(key, variant: :line, lazy: false, **options)
        @key = key
        @variant = variant
        @lazy = lazy
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_tabs(view, self, state)
      end

      def register_callbacks(registry)
        children.each_with_index do |_tab, index|
          registry["#{@key}_tab_#{index}"] = ->(state) { state[@key] = index }
        end
      end
    end

    # Tab component - individual tab within a Tabs container
    class Tab < Base
      attr_reader :label, :options
      attr_accessor :children

      # @param label [String] The tab label text
      # @param options [Hash] Additional options
      def initialize(label, **options)
        @label = label
        @options = options
        @children = []
      end
    end

    # Breadcrumbs container component for navigation trail
    class Breadcrumbs < Base
      attr_reader :separator, :options
      attr_accessor :children

      # @param separator [String] Separator character between crumbs (default: "/")
      # @param options [Hash] Additional options
      def initialize(separator: "/", **options)
        @separator = separator
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_breadcrumbs(view, self, state)
      end
    end

    # Crumb component - individual item within Breadcrumbs
    class Crumb < Base
      attr_reader :label, :href, :options

      # @param label [String] The crumb text
      # @param href [String, nil] Optional link URL (nil for current/last crumb)
      # @param options [Hash] Additional options
      def initialize(label, href: nil, **options)
        @label = label
        @href = href
        @options = options
      end
    end

    # Dropdown container component for menus
    class Dropdown < Base
      attr_reader :options
      attr_accessor :trigger_component, :menu_component

      # @param options [Hash] Additional options
      def initialize(**options)
        @options = options
        @trigger_component = nil
        @menu_component = nil
      end

      # Union of trigger/menu, so component-tree walkers (button/menu_item lookup
      # in server.rb) that only know about `children` can still find the trigger
      # button and menu_items nested inside a dropdown's trigger/menu blocks.
      # Same fix as AppShell#children -- see that class for the full rationale.
      def children
        [trigger_component, menu_component].compact
      end

      def render(view, state)
        view.adapter.render_dropdown(view, self, state)
      end
    end

    # DropdownTrigger component - the clickable element that opens the menu
    class DropdownTrigger < Base
      attr_accessor :children

      def initialize
        @children = []
      end
    end

    # Menu component - the dropdown menu container
    class Menu < Base
      attr_reader :options
      attr_accessor :children

      # @param options [Hash] Additional options
      def initialize(**options)
        @options = options
        @children = []
      end
    end

    # MenuItem component - individual item within a Menu
    class MenuItem < Base
      attr_reader :label, :style, :action, :options

      # @param label [String] The menu item text
      # @param style [Symbol] Visual style (:default, :destructive)
      # @param options [Hash] Additional options
      # @param block [Proc] Action to execute on click
      def initialize(label, style: :default, **options, &block)
        @label = label
        @style = style
        @action = block
        @options = options
      end

      # The DSL's `menu_item` method sets @id via instance_variable_set (see
      # App#menu_item) rather than passing it through the constructor -- expose
      # it so find_button_recursive can match on it the same way it matches
      # Components::Button#id.
      def id
        @id
      end

      def execute(state)
        @action&.call(state)
      end
    end

    # MenuDivider component - visual separator between menu items
    class MenuDivider < Base
      def render(view, state)
        view.hr(class: "sw-menu-divider")
      end
    end

    # =========================================
    # Link / Navbar / NavItem Components
    # =========================================

    class Link < Base
      attr_reader :label, :href, :options

      def initialize(label, href:, **options)
        @label = label
        @href = href
        @options = options
      end

      def render(view, state)
        view.adapter.render_link(view, self, state)
      end
    end

    class Navbar < Base
      attr_accessor :children
      attr_reader :options

      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_navbar(view, self, state)
      end
    end

    class NavItem < Base
      attr_reader :label, :href, :options

      def initialize(label, href: nil, active: false, **options)
        @label = label
        @href = href
        @active = active
        @options = options
      end

      def active? = @active

      def render(view, state)
        view.adapter.render_nav_item(view, self, state)
      end
    end

    # =========================================
    # Modal Components
    # =========================================

    # Modal container component for dialog overlays
    # State key: :{key}_open controls visibility (true/false)
    class Modal < Base
      attr_reader :key, :title, :size, :options
      attr_accessor :children, :footer_component

      # @param key [Symbol] State key for modal (opens when state[:"#{key}_open"] is true)
      # @param title [String, nil] Optional modal title
      # @param size [Symbol] Modal size (:sm, :md, :lg, :xl) - default :md
      # @param options [Hash] Additional options
      def initialize(key, title: nil, size: :md, **options)
        @key = key
        @title = title
        @size = size
        @options = options
        @children = []
        @footer_component = nil
      end

      def render(view, state)
        view.adapter.render_modal(view, self, state)
      end

      def register_callbacks(registry)
        return unless footer_component
        # footer_component (ModalFooter) is not in children — traverse its children explicitly.
        # ModalFooter is a plain container; its children are the interactive components (buttons).
        Array(footer_component.children).each { |c| c.register_callbacks(registry) }
      end
    end

    # ModalFooter component - footer section with action buttons
    class ModalFooter < Base
      attr_accessor :children

      def initialize(**options)
        @options = options
        @children = []
      end
    end

    # =========================================
    # Feedback Components
    # =========================================

    # Alert component for static feedback messages
    # Displays contextual messages with variant styling
    class Alert < Base
      attr_reader :variant, :title, :dismissible
      attr_accessor :children

      # @param variant [Symbol] Alert type (:info, :success, :warning, :error)
      # @param title [String, nil] Optional alert title
      # @param dismissible [Boolean] Whether alert can be dismissed (default: false)
      # @param options [Hash] Additional options
      def initialize(variant: :info, title: nil, dismissible: false, **options)
        @variant = variant
        @title = title
        @dismissible = dismissible
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_alert(view, self, state)
      end
    end

    # ToastContainer component for displaying multiple stacked notifications
    # Renders all active toasts from state[:_toasts] array
    class ToastContainer < Base
      attr_reader :position, :duration

      # @param position [Symbol] Screen position (:top_right, :top_left, :bottom_right, :bottom_left)
      # @param duration [Integer] Default auto-dismiss duration in milliseconds (0 = no auto-dismiss)
      # @param options [Hash] Additional options
      def initialize(position: :top_right, duration: 5000, **options)
        @position = position
        @duration = duration
        @options = options
      end

      def render(view, state)
        view.adapter.render_toast_container(view, self, state)
      end
    end

    # ProgressBar component for visual progress indication
    class ProgressBar < Base
      attr_reader :value, :max, :variant, :show_label, :animated

      # @param value [Integer, Symbol] Current value (0-100) or state key
      # @param max [Integer] Maximum value (default: 100)
      # @param variant [Symbol] Style (:default, :success, :warning, :error)
      # @param show_label [Boolean] Show percentage label (default: false)
      # @param animated [Boolean] Show animation (default: false)
      # @param options [Hash] Additional options
      def initialize(value:, max: 100, variant: :default, show_label: false, animated: false, **options)
        @value = value
        @max = max
        @variant = variant
        @show_label = show_label
        @animated = animated
        @options = options
      end

      def render(view, state)
        # Resolve value from state if it's a symbol
        actual_value = @value.is_a?(Symbol) ? (state[@value] || 0) : @value
        view.adapter.render_progress_bar(view, actual_value, @max, @variant, @show_label, @animated, @options, state)
      end
    end

    # Spinner component for loading states
    class Spinner < Base
      attr_reader :size, :label

      # @param size [Symbol] Spinner size (:sm, :md, :lg)
      # @param label [String, nil] Optional loading text
      # @param options [Hash] Additional options
      def initialize(size: :md, label: nil, **options)
        @size = size
        @label = label
        @options = options
      end

      def render(view, state)
        view.adapter.render_spinner(view, @size, @label, @options, state)
      end
    end

    # CanvasContinue marker - tells JavaScript to show spinner instead of "close window"
    # Used in multi-phase canvas flows where more content is coming
    class CanvasContinue < Base
      attr_reader :message

      # @param message [String] Message to show while processing
      def initialize(message: "Processing...")
        @message = message
      end

      def render(view, state)
        view.adapter.render_canvas_continue(view, @message, state)
      end
    end

    # ThemeSwitcher component for runtime theme selection
    # Renders a dropdown to switch between available themes
    class ThemeSwitcher < Base
      attr_reader :position, :show_label

      # Built-in themes (for backwards compatibility)
      THEMES = [
        { id: :default, label: "Default", description: "Warm Industrial" },
        { id: :dashboard, label: "Dashboard", description: "Data Dense" },
        { id: :document, label: "Document", description: "Reading Mode" }
      ].freeze

      # @param position [Symbol] Position (:inline, :fixed_top_right)
      # @param show_label [Boolean] Show "Theme:" label
      # @param options [Hash] Additional options
      def initialize(position: :inline, show_label: true, **options)
        @position = position
        @show_label = show_label
        @options = options
      end

      # Get all available themes (built-in + custom registered)
      def themes
        StreamWeaver.all_themes_for_switcher
      end

      def render(view, state)
        view.adapter.render_theme_switcher(view, self, state)
      end
    end

    # ThemeToggle component for visual skills auto-mode theme switching.
    # Manages data-sw-theme attribute on <html>, <meta name="theme-color">,
    # and localStorage persistence.
    #
    # Unlike ThemeSwitcher (which handles theme _selection_ among presets),
    # ThemeToggle handles dark/light/auto _mode_ switching.
    #
    # sw- CSS classes:
    #   sw-theme-toggle           - toggle button container
    #   sw-theme-toggle--auto     - when in auto mode
    #   sw-theme-toggle__btn      - the button element
    #   sw-theme-toggle__icon     - sun/moon icon span
    class ThemeToggle < Base
      attr_reader :mode, :hotkey, :persist

      # @param mode [Symbol] Initial mode (:dark, :light, :auto)
      # @param hotkey [String, nil] Keyboard shortcut (e.g. "mod+shift+l")
      # @param persist [Boolean] Persist preference in localStorage
      # @param options [Hash] Additional options
      def initialize(mode: :auto, hotkey: nil, persist: true, **options)
        @mode = mode
        @hotkey = hotkey
        @persist = persist
        @options = options
      end

      def render(view, state)
        view.adapter.render_theme_toggle(view, self, state)
      end
    end

    # ThemePreset component for applying curated theme presets.
    # Injects a Google Fonts <link> tag and a <style> block with
    # CSS custom property overrides for both light and dark modes.
    #
    # This is a non-visual "head-level" component: it renders CSS
    # infrastructure, not visible DOM elements.
    #
    # @example DSL usage
    #   theme_preset :editorial
    #   theme_preset :warm
    class ThemePreset < Base
      attr_reader :preset_name, :preset

      # @param name [Symbol] Preset name (:editorial, :technical, :warm, :minimal, :terminal)
      # @param options [Hash] Additional options
      # @raise [ArgumentError] if preset name is not recognized
      def initialize(name, **options)
        @preset_name = name.to_sym
        @preset = Theme::Presets.get(@preset_name)
        raise ArgumentError, "Unknown theme preset: #{name}. Available: #{Theme::Presets.available.join(', ')}" unless @preset
        @options = options
      end

      def render(view, state)
        view.adapter.render_theme_preset(view, self, state)
      end
    end

    # =========================================
    # Chart Components
    # =========================================

    # Shared functionality for all chart types
    class ChartBase < Base
      attr_reader :options

      def initialize(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
        @data = data
        @file = file
        @path = path
        @labels = labels
        @values = values
        @transform_block = block
        @options = options
      end

      def resolve_data(state)
        normalize(raw_data(state))
      end

      private

      def raw_data(state)
        return file_data if @file
        return state[@data] if @data.is_a?(Symbol)
        return @data if @data
        { labels: @labels || [], values: @values || [] }
      end

      def file_data
        raw = load_file(@file)
        @transform_block ? @transform_block.call(raw) : extract_path(raw, @path)
      end

      def load_file(path)
        require 'yaml'
        require 'json'
        expanded = File.expand_path(path)

        case File.extname(expanded).downcase
        when '.yaml', '.yml' then YAML.safe_load_file(expanded, symbolize_names: true, permitted_classes: [Symbol, Date, Time])
        when '.json'         then JSON.parse(File.read(expanded), symbolize_names: true)
        else raise ArgumentError, "Unsupported file type: #{path}. Use .yaml, .yml, or .json"
        end
      end

      def extract_path(data, path)
        return data unless path

        path.split('.').reduce(data) do |obj, key|
          break if obj.nil?
          key.match?(/\A-?\d+\z/) ? obj[key.to_i] : obj.fetch(key.to_sym) { obj[key] }
        end
      end

      def normalize(data)
        case data
        when Hash  then { labels: data.keys.map(&:to_s), values: data.values }
        when Array then normalize_array(data)
        else { labels: [], values: [] }
        end
      end

      def normalize_array(data)
        return { labels: data.map { _1[:label] }, values: data.map { _1[:value] } } if labeled_array?(data)
        { labels: data.each_index.map(&:to_s), values: data }
      end

      def labeled_array?(data)
        data.first.is_a?(Hash) && data.first.key?(:label)
      end
    end

    class BarChart < ChartBase
      def render(view, state)
        view.adapter.render_bar_chart(view, self, state)
      end
    end

    class LineChart < ChartBase
      def render(view, state)
        view.adapter.render_line_chart(view, self, state)
      end
    end

    class PieChart < ChartBase
      def render(view, state)
        view.adapter.render_pie_chart(view, self, state)
      end
    end

    class StackedBarChart < ChartBase
      def render(view, state)
        view.adapter.render_stacked_bar_chart(view, self, state)
      end

      def resolve_data(state)
        normalize_stacked(raw_data(state))
      end

      private

      def normalize_stacked(data)
        case data
        when Array then normalize_array_to_stacked(data)
        when Hash  then normalize_hash_to_stacked(data)
        else { labels: [], series: {} }
        end
      end

      def normalize_hash_to_stacked(data)
        return normalize_series_hash(data) if data.values.first.is_a?(Array)
        normalize_single_hash(data)
      end

      def normalize_series_hash(data)
        labels = (0...data.values.first.length).map(&:to_s)
        { labels: labels, series: data.transform_keys(&:to_s) }
      end

      def normalize_single_hash(data)
        { labels: data.keys.map(&:to_s), series: { "Value" => data.values } }
      end

      def normalize_array_to_stacked(data)
        return { labels: [], series: {} } if data.empty?

        first = data.first
        return normalize_labeled_records(data) if first.is_a?(Hash) && first.key?(:label)

        { labels: data.each_index.map(&:to_s), series: { "Value" => data } }
      end

      def normalize_labeled_records(data)
        labels = data.map { _1[:label].to_s }
        series_keys = data.first.keys.reject { _1 == :label }.map(&:to_s)
        series = series_keys.to_h { |key| [key, data.map { _1[key.to_sym] || _1[key] || 0 }] }
        { labels: labels, series: series }
      end
    end

    # =========================================
    # Dashboard Components (Cabinet Control style)
    # =========================================

    # StatusDot component for colored status indicators
    # Displays a small colored dot with optional glow effect and label
    class StatusDot < Base
      attr_reader :status, :pulse, :size, :label

      # Status colors: red (alert), yellow (warning), green (ok), gray (inactive)
      STATUSES = %i[red yellow green gray].freeze
      SIZES = %i[sm md lg].freeze

      # @param status [Symbol] Status color (:red, :yellow, :green, :gray)
      # @param pulse [Boolean] Whether to animate with pulse effect (default: false)
      # @param size [Symbol] Size (:sm, :md, :lg) - default :md
      # @param label [String, nil] Optional label to display below the dot
      # @param options [Hash] Additional options
      def initialize(status: :gray, pulse: false, size: :md, label: nil, **options)
        @status = STATUSES.include?(status.to_sym) ? status.to_sym : :gray
        @pulse = pulse
        @size = SIZES.include?(size.to_sym) ? size.to_sym : :md
        @label = label
        @options = options
      end

      def render(view, state)
        view.adapter.render_status_dot(view, self, state)
      end
    end

    # Badge component for small count/label indicators
    # Displays pill-shaped badges with variant colors
    class Badge < Base
      attr_reader :text, :variant, :size

      VARIANTS = %i[default danger warning success info].freeze
      SIZES = %i[sm md].freeze

      # @param text [String] Badge text/count
      # @param variant [Symbol] Color variant (:default, :danger, :warning, :success, :info)
      # @param size [Symbol] Size (:sm, :md) - default :sm
      # @param options [Hash] Additional options
      def initialize(text, variant: :default, size: :sm, **options)
        @text = text.to_s
        @variant = VARIANTS.include?(variant.to_sym) ? variant.to_sym : :default
        @size = SIZES.include?(size.to_sym) ? size.to_sym : :sm
        @options = options
      end

      def render(view, state)
        view.adapter.render_badge(view, self, state)
      end
    end

    # StatDisplay component for large metric numbers with labels
    # Displays a prominent value with a small label below
    class StatDisplay < Base
      attr_reader :value, :label, :color, :size

      COLORS = %i[default blue purple green red yellow].freeze
      SIZES = %i[sm md lg].freeze

      # @param value [String, Integer] The main value to display
      # @param label [String] Label text below the value
      # @param color [Symbol] Value color (:default, :blue, :purple, :green, :red, :yellow)
      # @param size [Symbol] Size (:sm, :md, :lg) - default :md
      # @param options [Hash] Additional options
      def initialize(value:, label:, color: :blue, size: :md, **options)
        @value = value.to_s
        @label = label
        @color = COLORS.include?(color.to_sym) ? color.to_sym : :default
        @size = SIZES.include?(size.to_sym) ? size.to_sym : :md
        @options = options
      end

      def render(view, state)
        view.adapter.render_stat_display(view, self, state)
      end
    end

    # TypeTag component for activity type badges
    # Colored pills showing type like RESEARCH, TASK, ESCALATION
    class TypeTag < Base
      attr_reader :type_name, :custom_color

      # Predefined types with colors
      TYPES = {
        research: :blue,
        task: :green,
        escalation: :red,
        communication: :purple,
        warning: :yellow,
        info: :gray
      }.freeze

      # @param type_name [Symbol, String] The type (:research, :task, :escalation, etc.) or custom text
      # @param color [Symbol, nil] Override color for custom types
      # @param options [Hash] Additional options
      def initialize(type_name, color: nil, **options)
        @type_name = type_name.to_s.downcase
        @custom_color = color
        @options = options
      end

      def color
        return @custom_color if @custom_color
        TYPES[@type_name.to_sym] || :gray
      end

      def display_text
        @type_name.upcase
      end

      def render(view, state)
        view.adapter.render_type_tag(view, self, state)
      end
    end

    # PulseIndicator component for animated status with label
    # Shows a pulsing dot with accompanying text
    class PulseIndicator < Base
      attr_reader :color, :label

      COLORS = %i[green red yellow blue].freeze

      # @param color [Symbol] Dot color (:green, :red, :yellow, :blue) - default :green
      # @param label [String] Status text next to the dot
      # @param options [Hash] Additional options
      def initialize(color: :green, label: nil, **options)
        @color = COLORS.include?(color.to_sym) ? color.to_sym : :green
        @label = label
        @options = options
      end

      def render(view, state)
        view.adapter.render_pulse_indicator(view, self, state)
      end
    end

    # PriorityItem component for escalation-style items
    # Items with priority-colored left border
    class PriorityItem < Base
      attr_reader :priority, :title, :description, :meta_left, :meta_right
      attr_accessor :children

      PRIORITIES = %i[critical urgent high normal low].freeze

      # @param priority [Symbol] Priority level (:critical, :urgent, :high, :normal, :low)
      # @param title [String] Item title
      # @param description [String, nil] Optional description text
      # @param meta_left [String, nil] Left-side metadata (e.g., secretary name)
      # @param meta_right [String, nil] Right-side metadata (e.g., action link)
      # @param options [Hash] Additional options
      def initialize(priority: :normal, title:, description: nil, meta_left: nil, meta_right: nil, **options)
        @priority = PRIORITIES.include?(priority.to_sym) ? priority.to_sym : :normal
        @title = title
        @description = description
        @meta_left = meta_left
        @meta_right = meta_right
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_priority_item(view, self, state)
      end
    end

    # ActivityItem component for activity feed items
    # Shows time, title, summary, and type badge
    class ActivityItem < Base
      attr_reader :time, :title, :summary, :type

      # @param time [String] Time display (e.g., "15:00")
      # @param title [String] Activity title
      # @param summary [String, nil] Optional summary text
      # @param type [Symbol, nil] Activity type for TypeTag (:research, :task, etc.)
      # @param options [Hash] Additional options
      def initialize(time:, title:, summary: nil, type: nil, **options)
        @time = time
        @title = title
        @summary = summary
        @type = type
        @options = options
      end

      def render(view, state)
        view.adapter.render_activity_item(view, self, state)
      end
    end

    # =========================================
    # Layout Components (Cabinet Control style)
    # =========================================

    # AppShell component for two-column app layouts
    # Provides a main content area with optional fixed sidebar
    class AppShell < Base
      attr_reader :sidebar_width, :sidebar_position, :gap
      attr_accessor :main_children, :sidebar_children

      POSITIONS = %i[left right].freeze

      # @param sidebar_width [String] CSS width for sidebar (default: "320px")
      # @param sidebar_position [Symbol] Sidebar position (:left, :right) - default :right
      # @param gap [String] Gap between main and sidebar (default: "1.5rem")
      # @param options [Hash] Additional options
      def initialize(sidebar_width: "320px", sidebar_position: :right, gap: "1.5rem", **options)
        @sidebar_width = sidebar_width
        @sidebar_position = POSITIONS.include?(sidebar_position.to_sym) ? sidebar_position.to_sym : :right
        @gap = gap
        @options = options
        @main_children = []
        @sidebar_children = []
      end

      # Union of main/sidebar content, so component-tree walkers (button/form/input
      # lookup in server.rb) that only know about `children` can still find buttons,
      # forms, and inputs nested inside an app_shell's main/sidebar blocks.
      def children
        main_children + sidebar_children
      end

      def render(view, state)
        view.adapter.render_app_shell(view, self, state)
      end
    end

    # Sidebar component for fixed sidebar content
    # Used within AppShell to define sidebar content
    class Sidebar < Base
      attr_reader :header, :sticky
      attr_accessor :children

      # @param header [String, nil] Optional header text for sidebar
      # @param sticky [Boolean] Whether sidebar content is sticky (default: true)
      # @param options [Hash] Additional options
      def initialize(header: nil, sticky: true, **options)
        @header = header
        @sticky = sticky
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_sidebar(view, self, state)
      end
    end

    # MainContent component for main content area in AppShell
    # Used within AppShell to define main content
    class MainContent < Base
      attr_accessor :children

      # @param options [Hash] Additional options
      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_main_content(view, self, state)
      end
    end

    # ExpandableCard component for cards that expand/collapse
    # Displays header always, body toggles on click
    class ExpandableCard < Base
      attr_reader :key, :title, :subtitle, :badge_text, :badge_variant, :status, :initially_expanded, :extra_classes
      attr_accessor :children, :header_children

      # @param key [Symbol] State key for expanded state
      # @param title [String] Card title (always visible)
      # @param subtitle [String, nil] Optional subtitle
      # @param badge_text [String, nil] Optional badge text (e.g., "5 activities")
      # @param badge_variant [Symbol] Badge color variant
      # @param status [Symbol, nil] Status indicator color (:red, :yellow, :green, :gray)
      # @param initially_expanded [Boolean] Whether card starts expanded (default: false)
      # @param extra_classes [String, nil] Additional CSS classes for the card container
      # @param options [Hash] Additional options
      def initialize(key:, title:, subtitle: nil, badge_text: nil, badge_variant: :default,
                     status: nil, initially_expanded: false, extra_classes: nil, **options)
        @key = key
        @title = title
        @subtitle = subtitle
        @badge_text = badge_text
        @badge_variant = badge_variant
        @status = status
        @initially_expanded = initially_expanded
        @extra_classes = extra_classes
        @options = options
        @children = []
        @header_children = []
      end

      def render(view, state)
        view.adapter.render_expandable_card(view, self, state)
      end
    end

    # CodeEditor component for syntax-highlighted code display/editing
    # Uses CodeMirror 5 with hx-preserve to survive HTMX swaps
    class CodeEditor < Base
      attr_reader :key, :language, :readonly, :height, :options

      # Supported languages (CodeMirror 5 modes)
      LANGUAGES = {
        ruby: { mode: 'ruby', mime: 'text/x-ruby' },
        javascript: { mode: 'javascript', mime: 'text/javascript' },
        html: { mode: 'htmlmixed', mime: 'text/html' },
        css: { mode: 'css', mime: 'text/css' },
        markdown: { mode: 'markdown', mime: 'text/x-markdown' },
        json: { mode: 'javascript', mime: 'application/json' }
      }.freeze

      # @param key [Symbol] State key for the editor content
      # @param language [Symbol] Syntax highlighting language (:ruby, :javascript, etc.)
      # @param readonly [Boolean] Whether the editor is read-only
      # @param height [String] CSS height value (default: "400px")
      # @param options [Hash] Additional options
      def initialize(key, language: :ruby, readonly: true, height: "400px", **options)
        @key = key
        @language = language.to_sym
        @readonly = readonly
        @height = height
        @options = options
      end

      def language_config
        LANGUAGES[@language] || LANGUAGES[:ruby]
      end

      def render(view, state)
        view.adapter.render_code_editor(view, self, state)
      end
    end

    # =========================================
    # CSS-Only Helpers (T13)
    # Thin wrappers around divs with sw- CSS classes.
    # Per DHH: "a div with a CSS class is still a div."
    # =========================================

    # Hero section -- large padded area with accent background tint
    class Hero < Base
      attr_accessor :children

      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_hero(view, self, state)
      end
    end

    # Prose container -- reading-optimized text (max-width ~65ch, comfortable line-height)
    class Prose < Base
      attr_accessor :children
      attr_reader :dropcap

      def initialize(dropcap: false, **options)
        @dropcap = dropcap
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_prose(view, self, state)
      end
    end

    # Pullquote -- highlighted quotation with optional attribution
    class Pullquote < Base
      attr_reader :text, :attribution

      def initialize(text, attribution: nil, **options)
        @text = text
        @attribution = attribution
        @options = options
      end

      def render(view, state)
        view.adapter.render_pullquote(view, self, state)
      end
    end

    # DirTree -- monospace file tree display with color-coded status
    # Status markers: [new] (green), [modified] (amber), [deleted] (red)
    class DirTree < Base
      attr_reader :tree_text

      def initialize(tree_text, **options)
        @tree_text = tree_text
        @options = options
      end

      # Parse lines and annotate with status
      def parsed_lines
        @tree_text.lines.map do |line|
          stripped = line.rstrip
          if stripped =~ /\[new\]\s*$/i
            { text: stripped.sub(/\s*\[new\]\s*$/i, ''), status: :new }
          elsif stripped =~ /\[modified\]\s*$/i
            { text: stripped.sub(/\s*\[modified\]\s*$/i, ''), status: :modified }
          elsif stripped =~ /\[deleted\]\s*$/i
            { text: stripped.sub(/\s*\[deleted\]\s*$/i, ''), status: :deleted }
          else
            { text: stripped, status: nil }
          end
        end
      end

      def render(view, state)
        view.adapter.render_dir_tree(view, self, state)
      end
    end

    # Legend -- horizontal row of color dots with labels
    class Legend < Base
      attr_reader :items

      # @param items [Array<Hash>] Array of { color: "#hex", label: "text" }
      def initialize(items:, **options)
        @items = items
        @options = options
      end

      def render(view, state)
        view.adapter.render_legend(view, self, state)
      end
    end

    # FlowArrow -- vertical arrow connector between sections
    class FlowArrow < Base
      attr_reader :label

      def initialize(label: nil, **options)
        @label = label
        @options = options
      end

      def render(view, state)
        view.adapter.render_flow_arrow(view, self, state)
      end
    end

    # LayoutToggle -- column count override buttons (1/2/3/4)
    class LayoutToggle < Base
      attr_reader :target, :columns

      # @param target [String] CSS selector of the grid to control
      # @param columns [Array<Integer>] Available column counts (default: [1, 2, 3, 4])
      def initialize(target: ".sw-layout-target", columns: [1, 2, 3, 4], **options)
        @target = target
        @columns = columns
        @options = options
      end

      def render(view, state)
        view.adapter.render_layout_toggle(view, self, state)
      end
    end
  end
end

# Load component files from components/ directory
require_relative "components/code_block"
require_relative "components/image_block"
require_relative "components/mermaid"
require_relative "components/keyboard_shortcuts"
require_relative "components/slide_container"
require_relative "components/sidebar_toc"
require_relative "components/callout"
require_relative "components/doc_header"
require_relative "components/comparison"
require_relative "components/implementation_map"
require_relative "components/decision"
require_relative "components/wireframe_block"
require_relative "components/wireframe"
require_relative "components/annotated_code"
require_relative "components/diff_block"
require_relative "components/api_endpoint"
require_relative "components/pipeline"
require_relative "components/kpi_dashboard"
require_relative "components/chart"
require_relative "components/timeline_event"
require_relative "components/deck/design_deck"
require_relative "components/deck/deck_slide"
require_relative "components/deck/deck_option"
require_relative "components/deck/deck_state"
require_relative "components/deck/deck_summary"
require_relative "components/deck/generate_more_controls"
require_relative "components/deck/skeleton_placeholder"
require_relative "components/deck/model_selector"
require_relative "components/deck/confirmation_bar"
require_relative "components/deck/close_overlay"
