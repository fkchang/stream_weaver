# frozen_string_literal: true

module StreamWeaver
  # Component classes for UI elements
  module Components
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
      attr_reader :key

      # @param key [Symbol] The state key
      # @param options [Hash] Options (e.g., placeholder)
      def initialize(key, **options)
        @key = key
        @options = options
      end

      def render(view, state)
        # Delegate to adapter - no framework knowledge in component
        view.adapter.render_text_field(view, @key, @options, state)
      end
    end

    # TextArea component for multi-line text input
    class TextArea < Base
      attr_reader :key

      # @param key [Symbol] The state key
      # @param options [Hash] Options (e.g., placeholder, rows)
      def initialize(key, **options)
        @key = key
        @options = options
      end

      def render(view, state)
        # Delegate to adapter - no framework knowledge in component
        view.adapter.render_text_area(view, @key, @options, state)
      end
    end

    # Button component that executes actions on click
    class Button < Base
      attr_reader :id

      # @param label [String] Button label
      # @param counter [Integer] Button counter for unique ID
      # @param options [Hash] Options (e.g., style: :primary or :secondary)
      # @param block [Proc] Action block to execute
      def initialize(label, counter, **options, &block)
        @label = label
        @action = block
        @options = options
        # Use counter for deterministic IDs that remain consistent across rebuilds
        @button_id = "btn_#{label.downcase.gsub(/\s+/, '_')}_#{counter}"
      end

      def render(view, state)
        # Delegate to adapter - no framework knowledge in component
        view.adapter.render_button(view, @button_id, @label, @options)
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

    # Div component for layout containers
    class Div < Base
      attr_accessor :children

      # @param options [Hash] Options (e.g., class: "container")
      def initialize(**options)
        @options = options
        @children = []
      end

      def render(view, state)
        view.div(class: @options[:class]) do
          @children.each { |child| child.render(view, state) }
        end
      end
    end

    # Checkbox component for boolean input
    class Checkbox < Base
      attr_reader :key

      # @param key [Symbol] The state key
      # @param label [String] The label text
      # @param options [Hash] Additional options
      def initialize(key, label, **options)
        @key = key
        @label = label
        @options = options
      end

      def render(view, state)
        # Delegate to adapter - no framework knowledge in component
        view.adapter.render_checkbox(view, @key, @label, @options, state)
      end
    end

    # Select component for dropdown selection
    class Select < Base
      attr_reader :key

      # @param key [Symbol] The state key
      # @param choices [Array<String>] The available choices
      # @param options [Hash] Additional options
      def initialize(key, choices, **options)
        @key = key
        @choices = choices
        @options = options
      end

      def render(view, state)
        # Delegate to adapter - no framework knowledge in component
        view.adapter.render_select(view, @key, @choices, @options, state)
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
  end
end
