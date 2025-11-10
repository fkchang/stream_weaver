# frozen_string_literal: true

module StreamWeaver
  # Main app class that holds the DSL block and manages the component tree
  class App
    attr_reader :title, :components, :block

    # Initialize a new StreamWeaver application
    #
    # @param title [String] The title of the application
    # @param block [Proc] The DSL block defining the UI structure
    def initialize(title, &block)
      @title = title
      @block = block
      @components = []
      @state_key = :streamlit_state
      @_state = {}
      @button_counter = 0
    end

    # Access the current state hash
    #
    # @return [Hash] The current state (symbol keys)
    def state
      @_state
    end

    # Rebuild the component tree with the given state
    # This re-evaluates the DSL block to regenerate components based on current state
    #
    # @param current_state [Hash] The state hash (symbol keys)
    def rebuild_with_state(current_state)
      @_state = current_state
      @components = []
      @button_counter = 0  # Reset counter for deterministic IDs
      instance_eval(&@block)
    end

    # Generate a Sinatra application from this app definition
    #
    # @return [Class] A Sinatra::Base subclass
    def generate
      SinatraApp.create(self)
    end

    # DSL method: Add a text field component
    #
    # @param key [Symbol] The state key for this field
    # @param options [Hash] Options (e.g., placeholder)
    def text_field(key, **options)
      @components << Components::TextField.new(key, **options)
    end

    # DSL method: Add a button component
    #
    # @param label [String] The button label
    # @param options [Hash] Options (e.g., style: :primary or :secondary)
    # @param block [Proc] The action to execute when clicked (receives state)
    def button(label, **options, &block)
      @button_counter += 1
      @components << Components::Button.new(label, @button_counter, **options, &block)
    end

    # DSL method: Add a text display component
    #
    # @param content [String] The text content to display
    def text(content)
      @components << Components::Text.new(content)
    end

    # DSL method: Add a text area component
    #
    # @param key [Symbol] The state key for this text area
    # @param options [Hash] Options (e.g., placeholder, rows)
    def text_area(key, **options)
      @components << Components::TextArea.new(key, **options)
    end

    # DSL method: Add a div container component
    #
    # @param options [Hash] Options (e.g., class: "container")
    # @param block [Proc] Nested DSL block for children
    def div(**options, &block)
      div_component = Components::Div.new(**options)
      @components << div_component

      # Temporarily switch context to capture nested components
      parent_components = @components
      @components = []
      instance_eval(&block) if block
      div_component.children = @components
      @components = parent_components
    end

    # DSL method: Add a checkbox component
    #
    # @param key [Symbol] The state key for this checkbox
    # @param label [String] The label text
    # @param options [Hash] Additional options
    def checkbox(key, label, **options)
      @components << Components::Checkbox.new(key, label, **options)
    end

    # DSL method: Add a select dropdown component
    #
    # @param key [Symbol] The state key for this select
    # @param choices [Array<String>] The available choices
    # @param options [Hash] Additional options
    def select(key, choices, **options)
      @components << Components::Select.new(key, choices, **options)
    end
  end
end
