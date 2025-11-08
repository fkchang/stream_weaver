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
        @placeholder = options[:placeholder] || ""
        @options = options
      end

      def render(view, state)
        view.input(
          type: "text",
          name: @key.to_s,
          value: state[@key] || "",
          placeholder: @placeholder,
          "x-model" => @key.to_s
        )
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
        style = @options[:style] == :secondary ? "secondary" : "primary"

        view.button(
          class: "btn btn-#{style}",
          "hx-post" => "/action/#{@button_id}",
          "hx-include" => "[x-model]",
          "hx-target" => "#app-container",
          "hx-swap" => "innerHTML"
        ) { @label }
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

    # Text component for displaying content
    class Text < Base
      # @param content [String] The text content
      def initialize(content)
        @content = content
      end

      def render(view, state)
        # Evaluate content if it's a string with interpolation context
        content = @content.is_a?(Proc) ? @content.call(state) : @content
        content_str = content.to_s

        # Check if content starts with markdown-style headers (## or ###, etc.)
        if match = content_str.match(/^(\#{1,6})\s+(.+)/)
          level = match[1].length
          text = match[2]

          case level
          when 1 then view.h1 { text }
          when 2 then view.h2 { text }
          when 3 then view.h3 { text }
          when 4 then view.h4 { text }
          when 5 then view.h5 { text }
          when 6 then view.h6 { text }
          end
        else
          view.p { content_str }
        end
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
        view.label do
          view.input(
            type: "checkbox",
            name: @key.to_s,
            checked: state[@key],
            "x-model" => @key.to_s
          )
          view.plain " #{@label}"
        end
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
        view.select(
          name: @key.to_s,
          "x-model" => @key.to_s
        ) do
          @choices.each do |choice|
            view.option(
              value: choice,
              selected: state[@key] == choice
            ) { choice }
          end
        end
      end
    end
  end
end
