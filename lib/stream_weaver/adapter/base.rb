# frozen_string_literal: true

module StreamWeaver
  module Adapter
    # Base adapter class that all adapters must inherit from
    # Defines the interface that components use to render themselves
    #
    # This adapter pattern decouples components from specific frontend frameworks
    # (Alpine.js, HTMX, React, Opal, etc.), allowing pluggable implementations.
    #
    # @abstract Subclass and override all methods to implement a new adapter
    #
    # @example Creating a custom adapter
    #   class MyAdapter < StreamWeaver::Adapter::Base
    #     def render_text_field(view, key, options, state)
    #       view.input(type: "text", "my-binding" => key.to_s)
    #     end
    #     # ... implement all other methods
    #   end
    #
    # @example Using an adapter
    #   app = StreamWeaver::App.new("My App", adapter: MyAdapter.new) do
    #     text_field :name
    #   end
    class Base
      # Render a single-line text input field
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this input
      # @param options [Hash] Component options
      # @option options [String] :placeholder Placeholder text
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_text_field(view, :email, { placeholder: "Email" }, state)
      def render_text_field(view, key, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_text_field"
      end

      # Render a multi-line text area
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this textarea
      # @param options [Hash] Component options
      # @option options [String] :placeholder Placeholder text
      # @option options [Integer] :rows Number of rows (default: 3)
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_text_area(view, :bio, { rows: 5 }, state)
      def render_text_area(view, key, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_text_area"
      end

      # Render a checkbox input
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this checkbox
      # @param label [String] The label text
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_checkbox(view, :agree, "I agree", {}, state)
      def render_checkbox(view, key, label, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_checkbox"
      end

      # Render a select dropdown
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this select
      # @param choices [Array<String>] The available choices
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_select(view, :color, ["Red", "Green", "Blue"], {}, state)
      def render_select(view, key, choices, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_select"
      end

      # Render a radio button group for single-choice selection
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this radio group
      # @param choices [Array<String>] The available choices
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_radio_group(view, :answer, ["Option A", "Option B"], {}, state)
      def render_radio_group(view, key, choices, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_radio_group"
      end

      # Render a button that executes an action
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param button_id [String] The deterministic button ID (e.g., "btn_submit_1")
      # @param label [String] The button label text
      # @param options [Hash] Component options
      # @option options [Symbol] :style Button style (:primary or :secondary)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_button(view, "btn_submit_1", "Submit", { style: :primary })
      def render_button(view, button_id, label, options)
        raise NotImplementedError, "#{self.class} must implement #render_button"
      end

      # Get HTML attributes for the app container (e.g., x-data for Alpine.js)
      #
      # @param state [Hash] Current state hash (symbol keys)
      # @return [Hash] HTML attributes to apply to container div
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   attrs = adapter.container_attributes({ name: "Alice" })
      #   # => { "x-data" => '{"name":"Alice"}' }
      def container_attributes(state)
        raise NotImplementedError, "#{self.class} must implement #container_attributes"
      end

      # Get CDN script tags or inline scripts needed by this adapter
      #
      # @return [Array<String>] Array of HTML script tags
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.cdn_scripts
      #   # => ['<script src="..."></script>', '<script>...</script>']
      def cdn_scripts
        raise NotImplementedError, "#{self.class} must implement #cdn_scripts"
      end

      # Render CDN scripts directly to the view using Phlex methods
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @return [void] Renders script tags to the view
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.render_cdn_scripts(view)
      def render_cdn_scripts(view)
        raise NotImplementedError, "#{self.class} must implement #render_cdn_scripts"
      end

      # Get the input selector for including form data (e.g., "[x-model]" for Alpine.js)
      # Used by buttons to know which inputs to include when submitting
      #
      # @return [String] CSS selector for input elements
      # @raise [NotImplementedError] if not implemented by subclass
      #
      # @example
      #   adapter.input_selector
      #   # => "[x-model]"
      def input_selector
        raise NotImplementedError, "#{self.class} must implement #input_selector"
      end

      # Render a checkbox group with select all/none functionality
      # State is stored as an array of selected values
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this group (stores array)
      # @param children [Array<CheckboxItem>] The checkbox items
      # @param options [Hash] Component options (select_all, select_none labels)
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_checkbox_group(view, key, children, options, state)
        raise NotImplementedError, "#{self.class} must implement #render_checkbox_group"
      end

      # Render a vertical stack container
      def render_vstack(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_vstack"
      end

      # Render a horizontal stack container
      def render_hstack(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_hstack"
      end

      # Render a responsive grid container
      def render_grid(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_grid"
      end

      # =========================================
      # Navigation component rendering
      # =========================================

      # Render a tabbed navigation container
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Tabs] The tabs component with children
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_tabs(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_tabs"
      end

      # Render a breadcrumbs navigation trail
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Breadcrumbs] The breadcrumbs component with children
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_breadcrumbs(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_breadcrumbs"
      end

      # Render a dropdown menu container
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Dropdown] The dropdown component with trigger and menu
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      # @raise [NotImplementedError] if not implemented by subclass
      def render_dropdown(view, component, state)
        raise NotImplementedError, "#{self.class} must implement #render_dropdown"
      end

      protected

      # Convert spacing symbol to CSS value
      #
      # @param spacing [Symbol, String] Spacing value (:xs, :sm, :md, :lg, :xl or raw CSS)
      # @return [String] CSS value
      def spacing_to_css(spacing)
        case spacing
        when :xs then "var(--sw-spacing-xs)"
        when :sm then "var(--sw-spacing-sm)"
        when :md then "var(--sw-spacing-md)"
        when :lg then "var(--sw-spacing-lg)"
        when :xl then "var(--sw-spacing-xl)"
        else spacing.to_s
        end
      end
    end
  end
end
