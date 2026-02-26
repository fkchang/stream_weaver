# frozen_string_literal: true

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

    # Button component that executes actions on click
    class Button < Base
      attr_reader :id, :modal_context

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
        @button_id = "btn_#{label.downcase.gsub(/\s+/, '_')}_#{stable_id}"
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
    end

    # Text component for displaying literal content (no markdown parsing)
    class Text < Base
      # @param content [String, Proc] The text content (can be a proc for dynamic content)
      def initialize(content)
        @content = content
      end

      def render(view, state)
        content = @content.is_a?(Proc) ? @content.call(state) : @content
        view.p { content.to_s }
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
      attr_reader :key

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
      attr_accessor :children

      # @param options [Hash] Options (e.g., class: "question-card")
      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        css_class = ["card", @options[:class]].compact.join(" ")
        view.div(class: css_class) do
          @children.each { |child| child.render(view, state) }
        end
      end
    end

    # CardHeader component for card header section
    class CardHeader < Base
      attr_accessor :children

      # @param content [String, nil] Optional string content (renders as h4)
      # @param options [Hash] Additional options
      def initialize(content = nil, **options)
        @content = content
        @options = options
        @children = []
      end

      def render(view, state)
        view.div(class: "card-header") do
          if @content
            view.h4 { @content }
          end
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
      attr_reader :columns, :gap, :options
      attr_accessor :children

      def initialize(columns: 3, gap: :md, **options)
        @columns = columns
        @gap = gap
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_grid(view, self, state)
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
      attr_reader :key, :header, :format, :align, :style

      def initialize(key, header: nil, format: nil, align: nil, style: nil, &block)
        @key = key
        @header = header || key.to_s.split("_").map(&:capitalize).join(" ")
        @format = format
        @align = align
        @style = style
        @value_block = block
      end

      def extract_value(item, index = nil)
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
      attr_reader :columns

      def initialize(data = nil, headers: nil, rows: nil, file: nil, path: nil,
                     striped: false, bordered: false, hoverable: true, compact: false,
                     sortable: false, sticky_header: false, markdown: false, caption: nil, **options, &block)
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
      def column(key, header: nil, format: nil, align: nil, style: nil, &block)
        @columns << TableColumn.new(key, header: header, format: format, align: align, style: style, &block)
      end

      def render(view, state)
        resolved = resolve_data(state)
        view.adapter.render_table(view, resolved[:headers], resolved[:rows], table_options, state)
      end

      private

      def resolve_data(state)
        raw = raw_data(state)
        normalize(raw)
      end

      def raw_data(state)
        return file_data if @file
        return state[@data] if @data.is_a?(Symbol)
        return @data if @data
        # Original API: headers + rows
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

      def normalize(data)
        return data if data.is_a?(Hash) && data.key?(:headers) && data.key?(:rows)

        case data
        when Array
          normalize_array(data)
        when Hash
          normalize_hash_of_arrays(data)
        else
          { headers: [], rows: [] }
        end
      end

      def normalize_array(data)
        return { headers: [], rows: [] } if data.empty?

        first = data.first
        if first.is_a?(Hash)
          # Array of hashes - use column DSL if defined, otherwise infer from keys
          if @columns.any?
            headers = @columns.map(&:header)
            rows = data.each_with_index.map do |item, idx|
              @columns.map { |col| col.extract_value(item, idx) }
            end
          else
            keys = first.keys
            headers = keys.map { |k| k.to_s.split("_").map(&:capitalize).join(" ") }
            rows = data.map { |item| keys.map { |k| (item[k] || item[k.to_s]).to_s } }
          end
          { headers: headers, rows: rows }
        elsif first.is_a?(Array)
          # Array of arrays - original format, no headers unless provided
          { headers: @headers || [], rows: data }
        else
          # Simple array - single column
          { headers: @headers || ["Value"], rows: data.map { |v| [v.to_s] } }
        end
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
          striped: @striped,
          bordered: @bordered,
          hoverable: @hoverable,
          compact: @compact,
          sortable: @sortable,
          sticky_header: @sticky_header,
          markdown: @markdown,
          caption: @caption,
          columns: @columns
        )
      end
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
      attr_reader :key, :variant, :options
      attr_accessor :children

      # @param key [Symbol] The state key for active tab index
      # @param variant [Symbol] Visual variant (:line, :enclosed, :soft-rounded)
      # @param options [Hash] Additional options
      def initialize(key, variant: :line, **options)
        @key = key
        @variant = variant
        @options = options
        @children = []
      end

      def render(view, state)
        view.adapter.render_tabs(view, self, state)
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
      attr_accessor :children, :main_children, :sidebar_children

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
        @children = []
        @main_children = []
        @sidebar_children = []
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
  end
end
