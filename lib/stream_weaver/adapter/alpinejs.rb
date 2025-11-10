# frozen_string_literal: true

require_relative 'base'

module StreamWeaver
  module Adapter
    # Alpine.js + HTMX adapter
    # Maintains 100% backward compatibility with StreamWeaver v0.1.0
    #
    # This adapter uses:
    # - Alpine.js for client-side reactive state (x-model, x-data)
    # - HTMX for server interactions (hx-post, hx-include, hx-target, hx-swap)
    #
    # @example
    #   app = StreamWeaver::App.new("My App", adapter: Adapter::AlpineJS.new) do
    #     text_field :name
    #     button "Submit" { |state| puts state[:name] }
    #   end
    class AlpineJS < Base
      # Render a single-line text input field with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this input
      # @param options [Hash] Component options
      # @option options [String] :placeholder Placeholder text
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_text_field(view, key, options, state)
        view.input(
          type: "text",
          name: key.to_s,
          value: state[key] || "",
          placeholder: options[:placeholder] || "",
          "x-model" => key.to_s,  # Alpine.js two-way binding
          "hx-post" => "/update",
          "hx-include" => input_selector,
          "hx-target" => "#app-container",
          "hx-swap" => "innerHTML",
          "hx-trigger" => "keyup changed delay:500ms"  # Debounced auto-update
        )
      end

      # Render a multi-line text area with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this textarea
      # @param options [Hash] Component options
      # @option options [String] :placeholder Placeholder text
      # @option options [Integer] :rows Number of rows (default: 3)
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_text_area(view, key, options, state)
        view.textarea(
          name: key.to_s,
          placeholder: options[:placeholder] || "",
          rows: options[:rows] || 3,
          "x-model" => key.to_s,  # Alpine.js two-way binding
          "hx-post" => "/update",
          "hx-include" => input_selector,
          "hx-target" => "#app-container",
          "hx-swap" => "innerHTML",
          "hx-trigger" => "keyup changed delay:500ms"  # Debounced auto-update
        ) { state[key] || "" }
      end

      # Render a checkbox input with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this checkbox
      # @param label [String] The label text
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_checkbox(view, key, label, options, state)
        view.label do
          view.input(
            type: "checkbox",
            name: key.to_s,
            checked: state[key],
            "x-model" => key.to_s,  # Alpine.js two-way binding
            "hx-post" => "/update",
            "hx-include" => input_selector,
            "hx-target" => "#app-container",
            "hx-swap" => "innerHTML",
            "hx-trigger" => "change"  # Immediate update on change
          )
          view.plain " #{label}"
        end
      end

      # Render a select dropdown with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this select
      # @param choices [Array<String>] The available choices
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_select(view, key, choices, options, state)
        view.select(
          name: key.to_s,
          "x-model" => key.to_s,  # Alpine.js two-way binding
          "hx-post" => "/update",
          "hx-include" => input_selector,
          "hx-target" => "#app-container",
          "hx-swap" => "innerHTML",
          "hx-trigger" => "change"  # Immediate update on change
        ) do
          choices.each do |choice|
            view.option(
              value: choice,
              selected: state[key] == choice
            ) { choice }
          end
        end
      end

      # Render a button with HTMX attributes for server interaction
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param button_id [String] The deterministic button ID (e.g., "btn_submit_1")
      # @param label [String] The button label text
      # @param options [Hash] Component options
      # @option options [Symbol] :style Button style (:primary or :secondary)
      # @return [void] Renders to view
      def render_button(view, button_id, label, options)
        style_class = options[:style] == :secondary ? "secondary" : "primary"

        view.button(
          class: "btn btn-#{style_class}",
          "hx-post" => "/action/#{button_id}",     # HTMX POST to server
          "hx-include" => input_selector,          # Include all inputs with x-model
          "hx-target" => "#app-container",         # Replace app container
          "hx-swap" => "innerHTML"                 # Replace inner HTML
        ) { label }
      end

      # Get HTML attributes for the app container with Alpine.js initialization
      #
      # @param state [Hash] Current state hash (symbol keys)
      # @return [Hash] HTML attributes containing x-data with JSON state
      def container_attributes(state)
        # Initialize Alpine.js with current state
        # Convert all keys to strings and values to JSON-compatible format
        state_data = {}

        state.each do |key, value|
          state_data[key.to_s] = value
        end

        { "x-data" => JSON.generate(state_data) }
      end

      # Get CDN script tags for Alpine.js and HTMX
      #
      # @return [Array<String>] Array of HTML script tags
      def cdn_scripts
        [
          '<script src="https://unpkg.com/htmx.org@2.0.4"></script>',
          '<script src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js" defer></script>'
        ]
      end

      # Render CDN scripts for Alpine.js and HTMX using Phlex methods
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @return [void] Renders script tags to the view
      def render_cdn_scripts(view)
        view.script(src: "https://unpkg.com/htmx.org@2.0.4")
        view.script(src: "https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js", defer: true)
      end

      # Get the CSS selector for Alpine.js bound inputs
      #
      # @return [String] CSS selector "[x-model]"
      def input_selector
        "[x-model]"  # Alpine.js selector for all bound inputs
      end
    end
  end
end
