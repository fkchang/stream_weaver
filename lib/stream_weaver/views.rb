# frozen_string_literal: true

require 'phlex'
require 'json'

module StreamWeaver
  module Views
    # Full page view for initial load (includes <html>, <head>, <body>)
    class AppView < Phlex::HTML
      # @param app [StreamWeaver::App] The app instance
      # @param state [Hash] The current state
      # @param is_agentic [Boolean] Whether running in agentic mode
      def initialize(app, state, is_agentic = false)
        @app = app
        @state = state
        @is_agentic = is_agentic
      end

      def view_template
        html do
          head do
            title { @app.title }
            script(src: "https://unpkg.com/htmx.org@2.0.4")
            script(src: "https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js", defer: true)
            style do
              raw safe(<<~CSS)
                body {
                  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                  max-width: 800px;
                  margin: 0 auto;
                  padding: 20px;
                  background: #f5f5f5;
                }
                #app-container {
                  background: white;
                  padding: 30px;
                  border-radius: 8px;
                  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }
                h1 {
                  color: #333;
                  margin-top: 0;
                }
                input[type="text"], select {
                  padding: 10px;
                  margin: 10px 0;
                  border: 1px solid #ddd;
                  border-radius: 4px;
                  font-size: 14px;
                  width: 100%;
                  box-sizing: border-box;
                }
                button {
                  padding: 10px 20px;
                  margin: 10px 5px 10px 0;
                  border: none;
                  border-radius: 4px;
                  font-size: 14px;
                  cursor: pointer;
                  transition: background 0.2s;
                }
                .btn-primary {
                  background: #007bff;
                  color: white;
                }
                .btn-primary:hover {
                  background: #0056b3;
                }
                .btn-secondary {
                  background: #6c757d;
                  color: white;
                }
                .btn-secondary:hover {
                  background: #545b62;
                }
                .todo-item {
                  padding: 10px;
                  margin: 5px 0;
                  background: #f8f9fa;
                  border-radius: 4px;
                  display: flex;
                  justify-content: space-between;
                  align-items: center;
                }
                label {
                  display: block;
                  margin: 10px 0;
                }
                input[type="checkbox"] {
                  margin-right: 8px;
                }
              CSS
            end
          end
          body do
            h1 { @app.title }
            div(id: "app-container", "x-data" => alpine_data) do
              render_components
            end
          end
        end
      end

      private

      # Generate Alpine.js x-data attribute with current state
      def alpine_data
        # Initialize Alpine.js with current state, ensuring all input keys are present
        state_data = {}

        # Convert existing state to strings
        @state.each do |key, value|
          state_data[key.to_s] = value
        end

        # Ensure all input components have entries
        collect_input_keys(@app.components).each do |key|
          state_data[key.to_s] ||= ""
        end

        JSON.generate(state_data)
      end

      # Collect all input component keys recursively
      def collect_input_keys(components)
        keys = []
        components.each do |comp|
          keys << comp.key if comp.respond_to?(:key) && comp.key
          keys += collect_input_keys(comp.children) if comp.respond_to?(:children) && comp.children
        end
        keys
      end

      # Render all components
      def render_components
        @app.components.each do |component|
          component.render(self, @state)
        end

        # Add submit button for agentic mode
        render_agentic_submit_button if @is_agentic
      end

      # Render the submit button for agentic mode
      def render_agentic_submit_button
        div(style: "margin-top: 30px; padding-top: 20px; border-top: 2px solid #e0e0e0;") do
          p(style: "color: #666; font-size: 14px;") { "Submit this form to return data to the calling agent:" }
          button(
            type: "button",
            class: "btn btn-primary",
            style: "background: #28a745; font-weight: bold;",
            "hx-post" => "/submit",
            "hx-include" => "[x-model]"
          ) { "🤖 Submit to Agent" }
        end
      end
    end

    # Partial view for HTMX updates (just the app-container content)
    class AppContentView < Phlex::HTML
      # @param app [StreamWeaver::App] The app instance
      # @param state [Hash] The current state
      def initialize(app, state)
        @app = app
        @state = state
      end

      def view_template
        @app.components.each do |component|
          component.render(self, @state)
        end
      end
    end
  end
end
