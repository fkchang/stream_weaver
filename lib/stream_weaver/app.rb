# frozen_string_literal: true

module StreamWeaver
  # Main app class that holds the DSL block and manages the component tree
  class App
    attr_reader :title, :components, :block, :layout

    # Initialize a new StreamWeaver application
    #
    # @param title [String] The title of the application
    # @param layout [Symbol] Layout mode (:default, :wide, :full)
    # @param block [Proc] The DSL block defining the UI structure
    def initialize(title, layout: :default, &block)
      @title = title
      @layout = layout
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
      # Inject form context if inside a form block
      options[:form_context] = @form_context if @form_context

      if @form_context
        # Inside form: initialize in form's state hash
        form_name = @form_context[:name]
        @_state[form_name] ||= {}
        @_state[form_name][key] ||= ""
      else
        # Standalone: initialize at top level
        @_state[key] = @_state[key] || ""
      end
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

    # DSL method: Add a text display component (literal, no markdown parsing)
    #
    # @param content [String] The text content to display
    def text(content)
      @components << Components::Text.new(content)
    end

    # DSL method: Add a markdown content component
    #
    # @param content [String] The markdown content to render
    def md(content)
      @components << Components::Markdown.new(content)
    end

    # Alias for md
    alias_method :markdown, :md

    # DSL method: Add a header component (default h2)
    #
    # @param content [String] The header text
    def header(content)
      @components << Components::Header.new(content, level: 2)
    end

    # DSL method: Add an h1 header
    #
    # @param content [String] The header text
    def header1(content)
      @components << Components::Header.new(content, level: 1)
    end

    # DSL method: Add an h2 header
    #
    # @param content [String] The header text
    def header2(content)
      @components << Components::Header.new(content, level: 2)
    end

    # DSL method: Add an h3 header
    #
    # @param content [String] The header text
    def header3(content)
      @components << Components::Header.new(content, level: 3)
    end

    # DSL method: Add an h4 header
    #
    # @param content [String] The header text
    def header4(content)
      @components << Components::Header.new(content, level: 4)
    end

    # DSL method: Add an h5 header
    #
    # @param content [String] The header text
    def header5(content)
      @components << Components::Header.new(content, level: 5)
    end

    # DSL method: Add an h6 header
    #
    # @param content [String] The header text
    def header6(content)
      @components << Components::Header.new(content, level: 6)
    end

    # DSL method: Add a text area component
    #
    # @param key [Symbol] The state key for this text area
    # @param options [Hash] Options (e.g., placeholder, rows)
    def text_area(key, **options)
      # Inject form context if inside a form block
      options[:form_context] = @form_context if @form_context

      if @form_context
        # Inside form: initialize in form's state hash
        form_name = @form_context[:name]
        @_state[form_name] ||= {}
        @_state[form_name][key] ||= ""
      else
        # Standalone: initialize at top level
        @_state[key] = @_state[key] || ""
      end
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
      # Inject form context if inside a form block
      options[:form_context] = @form_context if @form_context

      if @form_context
        # Inside form: initialize in form's state hash
        form_name = @form_context[:name]
        @_state[form_name] ||= {}
        @_state[form_name][key] = @_state[form_name][key] || false
      else
        # Standalone: initialize at top level
        @_state[key] = @_state[key] || false
      end
      @components << Components::Checkbox.new(key, label, **options)
    end

    # DSL method: Add a select dropdown component
    #
    # @param key [Symbol] The state key for this select
    # @param choices [Array<String>] The available choices
    # @param options [Hash] Additional options (e.g., default: "value")
    def select(key, choices, **options)
      # Inject form context if inside a form block
      options[:form_context] = @form_context if @form_context

      if @form_context
        # Inside form: initialize in form's state hash
        form_name = @form_context[:name]
        @_state[form_name] ||= {}
        if !@_state[form_name].key?(key)
          @_state[form_name][key] = options[:default] || ""
        end
      else
        # Standalone: initialize at top level
        if !@_state.key?(key)
          @_state[key] = options[:default] || ""
        end
      end
      @components << Components::Select.new(key, choices, **options)
    end

    # DSL method: Add a radio button group component
    #
    # @param key [Symbol] The state key for this radio group
    # @param choices [Array<String>] The available choices
    # @param options [Hash] Additional options (e.g., placeholder)
    def radio_group(key, choices, **options)
      # Inject form context if inside a form block
      options[:form_context] = @form_context if @form_context

      if @form_context
        # Inside form: initialize in form's state hash
        form_name = @form_context[:name]
        @_state[form_name] ||= {}
        @_state[form_name][key] ||= ""
      else
        # Standalone: initialize at top level
        @_state[key] = @_state[key] || ""
      end
      @components << Components::RadioGroup.new(key, choices, **options)
    end

    # DSL method: Add a card container component
    #
    # @param options [Hash] Options (e.g., class: "question-card")
    # @param block [Proc] Nested DSL block for children
    def card(**options, &block)
      card_component = Components::Card.new(**options)
      @components << card_component

      # Temporarily switch context to capture nested components
      parent_components = @components
      @components = []
      instance_eval(&block) if block
      card_component.children = @components
      @components = parent_components
    end

    # DSL method: Add a checkbox group with select all/none functionality
    # State is stored as an array of selected values
    #
    # @param key [Symbol] The state key (stores array of selected values)
    # @param options [Hash] Options (select_all:, select_none:, default:)
    # @param block [Proc] Nested DSL block containing item() calls
    def checkbox_group(key, **options, &block)
      # Initialize state as array if not set
      if !@_state.key?(key)
        @_state[key] = options[:default] || []
      end

      group_component = Components::CheckboxGroup.new(key, **options)
      @components << group_component

      # Save current context and set up for capturing items
      parent_components = @components
      @current_checkbox_group = group_component
      @components = []

      instance_eval(&block) if block

      group_component.children = @components
      @components = parent_components
      @current_checkbox_group = nil
    end

    # DSL method: Add an item within a checkbox_group
    # Each item gets a checkbox with the specified value
    #
    # @param value [String] The value added to the group's array when checked
    # @param block [Proc] Nested DSL block for item content
    def item(value, &block)
      item_component = Components::CheckboxItem.new(value)

      # Capture nested components for this item
      parent_components = @components
      @components = []
      instance_eval(&block) if block
      item_component.children = @components
      @components = parent_components

      @components << item_component
    end

    # DSL method: Add a phrase (plain text span) within lesson_text
    #
    # @param content [String] The text content
    def phrase(content)
      @components << Components::Phrase.new(content)
    end

    # DSL method: Add a hoverable term within lesson_text
    #
    # @param term_key [String] The glossary term key
    # @param options [Hash] Options (e.g., display: "alternate text")
    def term(term_key, **options)
      @components << Components::Term.new(term_key, **options)
    end

    # DSL method: Add a lesson text container with interactive glossary terms
    #
    # @param content_or_options [String, Hash] Either a string with {term} markers, or options hash
    # @param options [Hash] Options when content is a string (e.g., glossary:)
    # @param block [Proc] Nested DSL block for phrase/term children
    def lesson_text(content_or_options = nil, **options, &block)
      # Handle both string content and block-based content
      if content_or_options.is_a?(String)
        # Parse string with {term} markers
        glossary = options[:glossary] || {}
        lesson_component = Components::LessonText.new(glossary: glossary)
        @components << lesson_component

        # Parse the string and create children
        parsed_children = parse_lesson_string(content_or_options, glossary)
        lesson_component.children = parsed_children
      else
        # Block-based content
        opts = content_or_options.is_a?(Hash) ? content_or_options.merge(options) : options
        glossary = opts[:glossary] || {}
        lesson_component = Components::LessonText.new(glossary: glossary)
        @components << lesson_component

        # Temporarily switch context to capture nested components
        parent_components = @components
        @components = []
        instance_eval(&block) if block
        lesson_component.children = @components
        @components = parent_components
      end
    end

    # DSL method: Add a collapsible container component
    #
    # @param label [String] The header label text
    # @param expanded [Boolean] Whether to start expanded (default: false)
    # @param options [Hash] Additional options
    # @param block [Proc] Nested DSL block for children
    def collapsible(label, expanded: false, **options, &block)
      component = Components::Collapsible.new(label, expanded: expanded, **options)
      @components << component

      # Temporarily switch context to capture nested components
      parent_components = @components
      @components = []
      instance_eval(&block) if block
      component.children = @components
      @components = parent_components
    end

    # DSL method: Add a score table component
    #
    # @param scores [Array<Hash>] Array of {label:, value:, max:} hashes
    # @param options [Hash] Additional options
    def score_table(scores:, **options)
      @components << Components::ScoreTable.new(scores: scores, **options)
    end

    # DSL method: Add a status badge component
    #
    # @param status [Symbol] One of :strong, :maybe, :skip
    # @param reasoning [String] Explanation text
    def status_badge(status, reasoning)
      @components << Components::StatusBadge.new(status, reasoning)
    end

    # DSL method: Add a tag buttons component for quick selection
    #
    # @param key [Symbol] The state key for selected tag
    # @param tags [Array<String>] The available tag labels
    # @param options [Hash] Options (e.g., style: :destructive)
    def tag_buttons(key, tags, **options)
      @_state[key] = @_state[key] || nil
      @components << Components::TagButtons.new(key, tags, **options)
    end

    # DSL method: Add an external link button
    #
    # @param label [String] Button label
    # @param url [String] URL to open in new tab
    # @param submit [Boolean] Whether to also submit form (default: false)
    def external_link_button(label, url:, submit: false)
      @components << Components::ExternalLinkButton.new(label, url: url, submit: submit)
    end

    # DSL method: Add a multi-column layout container
    #
    # @param widths [Array<String>, nil] Optional column widths (e.g., ['30%', '70%'])
    # @param options [Hash] Additional options (e.g., gap)
    # @param block [Proc] Nested DSL block containing column() calls
    def columns(widths: nil, **options, &block)
      columns_component = Components::Columns.new(widths: widths, **options)
      @components << columns_component

      # Save current context and set up for capturing columns
      parent_components = @components
      @current_columns = columns_component
      @components = []

      instance_eval(&block) if block

      columns_component.children = @components
      @components = parent_components
      @current_columns = nil
    end

    # DSL method: Add an individual column within a columns container
    #
    # @param options [Hash] Additional options (e.g., class)
    # @param block [Proc] Nested DSL block for column content
    def column(**options, &block)
      column_component = Components::Column.new(**options)

      # Capture nested components for this column
      parent_components = @components
      @components = []
      instance_eval(&block) if block
      column_component.children = @components
      @components = parent_components

      @components << column_component
    end

    # DSL method: Add a form block with deferred submission
    # Form elements inside use client-side only state until submit
    #
    # @param name [Symbol] The form name (used as state key, e.g., :edit_person)
    # @param options [Hash] Additional options
    # @param block [Proc] Nested DSL block containing form fields, submit, cancel
    def form(name, **options, &block)
      form_component = Components::Form.new(name, **options)
      @components << form_component

      # Initialize form state as empty hash if not present
      @_state[name] ||= {}

      # Save current context and set up form context
      parent_components = @components
      @current_form = form_component
      @form_context = { name: name }
      @components = []

      instance_eval(&block) if block

      form_component.children = @components
      @components = parent_components
      @current_form = nil
      @form_context = nil
    end

    # DSL method: Add a submit button within a form block
    # On click: sends all form values to server, auto-updates state, runs block
    #
    # @param label [String] Button label text
    # @param block [Proc] Action to execute after state is updated (receives form_values)
    def submit(label, &block)
      raise "submit can only be used inside a form block" unless @current_form

      @current_form.set_submit(label, &block)
    end

    # DSL method: Add a cancel button within a form block
    # On click: resets form to original values (client-side only, no server request)
    #
    # @param label [String] Button label text
    def cancel(label)
      raise "cancel can only be used inside a form block" unless @current_form

      @current_form.set_cancel(label)
    end

    # Check if currently inside a form block
    # Used by adapters to determine rendering behavior
    #
    # @return [Hash, nil] Form context with :name key, or nil if not in form
    def form_context
      @form_context
    end

    private

    # Parse a string with {term} markers into Phrase and Term components
    #
    # @param content [String] The content with {term} markers
    # @param glossary [Hash] The glossary to validate terms against
    # @return [Array] Array of Phrase and Term components
    def parse_lesson_string(content, glossary)
      children = []
      # Match text outside braces and text inside braces
      parts = content.split(/(\{[^}]+\})/)

      parts.each do |part|
        if part.start_with?('{') && part.end_with?('}')
          # This is a term
          term_key = part[1..-2] # Remove braces
          children << Components::Term.new(term_key)
        elsif !part.empty?
          # This is plain text
          children << Components::Phrase.new(part)
        end
      end

      children
    end
  end
end
