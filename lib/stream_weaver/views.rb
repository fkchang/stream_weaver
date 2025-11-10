# frozen_string_literal: true

require 'phlex'
require 'json'

module StreamWeaver
  module Views
    # Full page view for initial load (includes <html>, <head>, <body>)
    class AppView < Phlex::HTML
      attr_reader :adapter

      # @param app [StreamWeaver::App] The app instance
      # @param state [Hash] The current state
      # @param adapter [StreamWeaver::Adapter::Base] The adapter for rendering
      # @param is_agentic [Boolean] Whether running in agentic mode
      def initialize(app, state, adapter, is_agentic = false)
        @app = app
        @state = state
        @adapter = adapter
        @is_agentic = is_agentic
      end

      def view_template
        html do
          head do
            title { @app.title }
            # Inject adapter-specific CDN scripts using Phlex methods
            @adapter.render_cdn_scripts(self)
            style do
              plain <<~CSS
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
                  margin-bottom: 10px;
                }
                h2 {
                  color: #444;
                  font-size: 20px;
                  margin-top: 24px;
                  margin-bottom: 12px;
                }
                p {
                  color: #666;
                  line-height: 1.6;
                  margin: 12px 0 24px 0;
                }
                p + input, p + select, p + textarea {
                  margin-top: 4px;
                }
                p:has(+ input), p:has(+ select), p:has(+ textarea) {
                  margin-bottom: 4px;
                  font-weight: 500;
                  color: #333;
                }
                input[type="text"], input[type="email"], select, textarea {
                  padding: 12px 16px;
                  margin: 8px 0 16px 0;
                  border: 2px solid #e0e0e0;
                  border-radius: 6px;
                  font-size: 15px;
                  width: 100%;
                  box-sizing: border-box;
                  font-family: inherit;
                  transition: border-color 0.2s, box-shadow 0.2s;
                }
                input[type="text"]:focus, input[type="email"]:focus, select:focus, textarea:focus {
                  outline: none;
                  border-color: #007bff;
                  box-shadow: 0 0 0 3px rgba(0,123,255,0.1);
                }
                input[type="text"]::placeholder, input[type="email"]::placeholder, textarea::placeholder {
                  color: #999;
                }
                textarea {
                  resize: vertical;
                  min-height: 60px;
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
                  display: flex;
                  align-items: center;
                  margin: 16px 0;
                  cursor: pointer;
                  user-select: none;
                }
                input[type="checkbox"] {
                  margin-right: 10px;
                  width: 18px;
                  height: 18px;
                  cursor: pointer;
                }
                select {
                  cursor: pointer;
                }
              CSS
            end
          end
          body do
            h1 { @app.title }
            # Merge adapter-specific container attributes with container id
            div(id: "app-container", **@adapter.container_attributes(@state)) do
              render_components
            end
          end
        end
      end

      private

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
            "hx-include" => @adapter.input_selector
          ) { "🤖 Submit to Agent" }
        end
      end
    end

    # Partial view for HTMX updates (just the app-container content)
    class AppContentView < Phlex::HTML
      attr_reader :adapter

      # @param app [StreamWeaver::App] The app instance
      # @param state [Hash] The current state
      # @param adapter [StreamWeaver::Adapter::Base] The adapter for rendering
      # @param is_agentic [Boolean] Whether running in agentic mode
      def initialize(app, state, adapter, is_agentic = false)
        @app = app
        @state = state
        @adapter = adapter
        @is_agentic = is_agentic
      end

      def view_template
        @app.components.each do |component|
          component.render(self, @state)
        end

        # Add submit button for agentic mode
        render_agentic_submit_button if @is_agentic
      end

      private

      # Render the submit button for agentic mode
      def render_agentic_submit_button
        div(style: "margin-top: 30px; padding-top: 20px; border-top: 2px solid #e0e0e0;") do
          p(style: "color: #666; font-size: 14px;") { "Submit this form to return data to the calling agent:" }
          button(
            type: "button",
            class: "btn btn-primary",
            style: "background: #28a745; font-weight: bold;",
            "hx-post" => "/submit",
            "hx-include" => @adapter.input_selector
          ) { "🤖 Submit to Agent" }
        end
      end
    end
  end
end
