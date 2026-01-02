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
      # @param counter [Integer] Button counter for unique ID
      # @param options [Hash] Options (e.g., style: :primary or :secondary, modal_context: {key: :name})
      # @param block [Proc] Action block to execute
      def initialize(label, counter, **options, &block)
        @label = label
        @action = block
        @modal_context = options.delete(:modal_context)
        @options = options
        # Use counter for deterministic IDs that remain consistent across rebuilds
        @button_id = "btn_#{label.downcase.gsub(/\s+/, '_')}_#{counter}"
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

    class BarChart < Base
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

      def render(view, state)
        view.adapter.render_bar_chart(view, self, state)
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
