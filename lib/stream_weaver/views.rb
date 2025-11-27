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
        doctype
        html do
          head do
            title { @app.title }
            # Inject adapter-specific CDN scripts using Phlex methods
            @adapter.render_cdn_scripts(self)
            style do
              raw(safe(<<~CSS))
                /* ===========================================
                   StreamWeaver CSS Custom Properties (Theme)
                   Override these in your app's CSS to customize
                   =========================================== */
                :root {
                  /* Typography */
                  --sw-font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                  --sw-font-size-base: 16px;
                  --sw-font-size-sm: 14px;
                  --sw-font-size-lg: 18px;
                  --sw-line-height: 1.6;

                  /* Colors - Primary */
                  --sw-color-primary: #2563eb;
                  --sw-color-primary-hover: #1d4ed8;
                  --sw-color-primary-light: #dbeafe;

                  /* Colors - Neutral */
                  --sw-color-text: #1f2937;
                  --sw-color-text-muted: #6b7280;
                  --sw-color-text-light: #9ca3af;
                  --sw-color-bg: #f9fafb;
                  --sw-color-bg-card: #ffffff;
                  --sw-color-border: #e5e7eb;
                  --sw-color-border-focus: var(--sw-color-primary);

                  /* Colors - Secondary */
                  --sw-color-secondary: #6b7280;
                  --sw-color-secondary-hover: #4b5563;

                  /* Spacing */
                  --sw-spacing-xs: 0.25rem;
                  --sw-spacing-sm: 0.5rem;
                  --sw-spacing-md: 1rem;
                  --sw-spacing-lg: 1.5rem;
                  --sw-spacing-xl: 2rem;

                  /* Border Radius */
                  --sw-radius-sm: 4px;
                  --sw-radius-md: 8px;
                  --sw-radius-lg: 12px;

                  /* Shadows */
                  --sw-shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
                  --sw-shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
                  --sw-shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);

                  /* Transitions */
                  --sw-transition: 150ms ease;

                  /* Tooltip */
                  --sw-tooltip-bg: #1e293b;
                  --sw-tooltip-text: #f8fafc;

                  /* Term highlighting */
                  --sw-term-color: var(--sw-color-primary);
                  --sw-term-bg-hover: var(--sw-color-primary-light);
                }

                /* ===========================================
                   Base Styles
                   =========================================== */
                body {
                  font-family: var(--sw-font-family);
                  font-size: var(--sw-font-size-base);
                  line-height: var(--sw-line-height);
                  color: var(--sw-color-text);
                  max-width: 800px;
                  margin: 0 auto;
                  padding: var(--sw-spacing-lg);
                  background: var(--sw-color-bg);
                  -webkit-font-smoothing: antialiased;
                  -moz-osx-font-smoothing: grayscale;
                }

                #app-container {
                  background: var(--sw-color-bg-card);
                  padding: var(--sw-spacing-xl);
                  border-radius: var(--sw-radius-lg);
                  box-shadow: var(--sw-shadow-md);
                }

                /* ===========================================
                   Typography
                   =========================================== */
                h1, h2, h3, h4, h5, h6 {
                  font-family: var(--sw-font-family);
                }

                h1 {
                  color: var(--sw-color-text);
                  font-size: 1.875rem;
                  font-weight: 700;
                  letter-spacing: -0.025em;
                  margin-top: 0;
                  margin-bottom: var(--sw-spacing-sm);
                }

                h2 {
                  color: var(--sw-color-text);
                  font-size: 1.25rem;
                  font-weight: 600;
                  letter-spacing: -0.02em;
                  margin-top: var(--sw-spacing-xl);
                  margin-bottom: var(--sw-spacing-md);
                }

                h3 {
                  color: var(--sw-color-text);
                  font-size: 1.125rem;
                  font-weight: 600;
                  margin-top: var(--sw-spacing-lg);
                  margin-bottom: var(--sw-spacing-sm);
                }

                p {
                  color: var(--sw-color-text-muted);
                  line-height: var(--sw-line-height);
                  margin: var(--sw-spacing-sm) 0 var(--sw-spacing-lg) 0;
                }

                p + input, p + select, p + textarea {
                  margin-top: var(--sw-spacing-xs);
                }

                p:has(+ input), p:has(+ select), p:has(+ textarea) {
                  margin-bottom: var(--sw-spacing-xs);
                  font-weight: 500;
                  color: var(--sw-color-text);
                }

                /* ===========================================
                   Form Controls
                   =========================================== */
                input[type="text"], input[type="email"], select, textarea {
                  padding: var(--sw-spacing-sm) var(--sw-spacing-md);
                  margin: var(--sw-spacing-sm) 0 var(--sw-spacing-md) 0;
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  font-size: var(--sw-font-size-base);
                  width: 100%;
                  box-sizing: border-box;
                  font-family: inherit;
                  background: var(--sw-color-bg-card);
                  color: var(--sw-color-text);
                  transition: border-color var(--sw-transition), box-shadow var(--sw-transition);
                }

                input[type="text"]:focus, input[type="email"]:focus, select:focus, textarea:focus {
                  outline: none;
                  border-color: var(--sw-color-border-focus);
                  box-shadow: 0 0 0 3px var(--sw-color-primary-light);
                }

                input[type="text"]::placeholder, input[type="email"]::placeholder, textarea::placeholder {
                  color: var(--sw-color-text-light);
                }

                textarea {
                  resize: vertical;
                  min-height: 80px;
                }

                /* ===========================================
                   Buttons
                   =========================================== */
                button, .btn {
                  padding: var(--sw-spacing-sm) var(--sw-spacing-md);
                  margin: var(--sw-spacing-sm) var(--sw-spacing-sm) var(--sw-spacing-sm) 0;
                  border: none;
                  border-radius: var(--sw-radius-md);
                  font-size: var(--sw-font-size-sm);
                  font-weight: 500;
                  cursor: pointer;
                  transition: background var(--sw-transition), transform var(--sw-transition);
                }

                button:active {
                  transform: scale(0.98);
                }

                .btn-primary {
                  background: var(--sw-color-primary);
                  color: white;
                }

                .btn-primary:hover {
                  background: var(--sw-color-primary-hover);
                }

                .btn-secondary {
                  background: var(--sw-color-secondary);
                  color: white;
                }

                .btn-secondary:hover {
                  background: var(--sw-color-secondary-hover);
                }

                /* ===========================================
                   Checkbox & Labels
                   =========================================== */
                label {
                  display: flex;
                  align-items: center;
                  margin: var(--sw-spacing-md) 0;
                  cursor: pointer;
                  user-select: none;
                  color: var(--sw-color-text);
                }

                input[type="checkbox"] {
                  margin-right: var(--sw-spacing-sm);
                  width: 18px;
                  height: 18px;
                  cursor: pointer;
                  accent-color: var(--sw-color-primary);
                }

                select {
                  cursor: pointer;
                }

                /* ===========================================
                   Radio Group
                   =========================================== */
                .radio-group {
                  display: flex;
                  flex-direction: column;
                  gap: var(--sw-spacing-sm);
                  margin: var(--sw-spacing-sm) 0 var(--sw-spacing-md) 0;
                }

                .radio-option {
                  display: flex;
                  align-items: center;
                  gap: var(--sw-spacing-sm);
                  padding: var(--sw-spacing-sm) var(--sw-spacing-md);
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  cursor: pointer;
                  transition: background-color var(--sw-transition), border-color var(--sw-transition);
                  margin: 0;
                }

                .radio-option:hover {
                  background-color: var(--sw-color-bg);
                  border-color: var(--sw-color-text-light);
                }

                .radio-option input[type="radio"] {
                  margin: 0;
                  cursor: pointer;
                  accent-color: var(--sw-color-primary);
                }

                .radio-option input[type="radio"]:checked + span {
                  font-weight: 500;
                  color: var(--sw-color-primary);
                }

                /* ===========================================
                   Card
                   =========================================== */
                .card {
                  background: var(--sw-color-bg-card);
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                  padding: var(--sw-spacing-lg);
                  margin-bottom: var(--sw-spacing-md);
                  box-shadow: var(--sw-shadow-sm);
                }

                .card h3 {
                  margin-top: 0;
                  margin-bottom: var(--sw-spacing-sm);
                  color: var(--sw-color-text);
                }

                /* ===========================================
                   Lesson Text & Terms (Educational Content)
                   =========================================== */
                .lesson-text {
                  position: relative;
                  line-height: 1.8;
                  font-size: var(--sw-font-size-lg);
                  color: var(--sw-color-text);
                }

                .sw-term, .term {
                  text-decoration: underline;
                  text-decoration-style: dotted;
                  text-decoration-color: var(--sw-term-color);
                  text-underline-offset: 3px;
                  cursor: help;
                  color: var(--sw-term-color);
                  font-weight: 500;
                  padding: 0 2px;
                  border-radius: var(--sw-radius-sm);
                  transition: background-color var(--sw-transition), color var(--sw-transition);
                }

                .sw-term:hover, .sw-term:focus,
                .term:hover, .term:focus {
                  background-color: var(--sw-term-bg-hover);
                  outline: none;
                }

                /* ===========================================
                   Tooltip
                   =========================================== */
                .sw-tooltip, .tooltip {
                  position: fixed;
                  transform: translateX(-50%) translateY(-100%);
                  background: var(--sw-tooltip-bg);
                  color: var(--sw-tooltip-text);
                  padding: var(--sw-spacing-md);
                  border-radius: var(--sw-radius-md);
                  font-size: var(--sw-font-size-sm);
                  max-width: 350px;
                  box-shadow: var(--sw-shadow-lg);
                  z-index: 1000;
                  cursor: pointer;
                  white-space: normal;
                  word-wrap: break-word;
                }

                .sw-tooltip::after, .tooltip::after {
                  content: '';
                  position: absolute;
                  top: 100%;
                  left: 50%;
                  transform: translateX(-50%);
                  border: 8px solid transparent;
                  border-top-color: var(--sw-tooltip-bg);
                }

                .tooltip-content {
                  line-height: 1.5;
                }

                .tooltip-hint {
                  font-size: 12px;
                  color: #94a3b8;
                  margin-top: var(--sw-spacing-sm);
                  font-style: italic;
                }

                /* ===========================================
                   Collapsible
                   =========================================== */
                .collapsible {
                  margin: 12px 0;
                  border: 1px solid var(--sw-color-border);
                  border-radius: var(--sw-radius-md);
                }

                .collapsible-header {
                  display: flex;
                  align-items: center;
                  gap: 8px;
                  padding: 12px 16px;
                  background: var(--sw-color-bg);
                  cursor: pointer;
                  border-radius: var(--sw-radius-md);
                }

                .collapsible-header:hover {
                  background: var(--sw-color-border);
                }

                .collapsible-icon {
                  font-size: 12px;
                  color: var(--sw-color-text-muted);
                  width: 12px;
                }

                .collapsible-label {
                  font-weight: 500;
                  color: var(--sw-color-text);
                }

                .collapsible-content {
                  padding: 16px;
                  border-top: 1px solid var(--sw-color-border);
                  line-height: var(--sw-line-height);
                }

                /* ===========================================
                   Score Table
                   =========================================== */
                .score-table {
                  width: 100%;
                  border-collapse: collapse;
                  margin: 12px 0;
                  font-size: var(--sw-font-size-sm);
                }

                .score-table th,
                .score-table td {
                  padding: 8px 12px;
                  text-align: left;
                  border-bottom: 1px solid var(--sw-color-border);
                }

                .score-table th {
                  background: var(--sw-color-bg);
                  font-weight: 600;
                  color: var(--sw-color-text);
                }

                .score-cell {
                  font-weight: bold;
                  text-align: center !important;
                  border-radius: var(--sw-radius-sm);
                  width: 60px;
                }

                .score-high {
                  background: #d4edda;
                  color: #155724;
                }

                .score-medium {
                  background: #fff3cd;
                  color: #856404;
                }

                .score-low {
                  background: #f8d7da;
                  color: #721c24;
                }

                .score-meaning {
                  color: var(--sw-color-text-muted);
                  font-style: italic;
                }

                /* ===========================================
                   Utilities
                   =========================================== */
                .todo-item {
                  padding: var(--sw-spacing-sm);
                  margin: var(--sw-spacing-xs) 0;
                  background: var(--sw-color-bg);
                  border-radius: var(--sw-radius-sm);
                  display: flex;
                  justify-content: space-between;
                  align-items: center;
                }

                /* Alpine.js cloak */
                [x-cloak] {
                  display: none !important;
                }

                /* Mobile touch support */
                @media (hover: none) {
                  .sw-term, .term {
                    cursor: pointer;
                  }
                }

                /* ===========================================
                   Embedded Mode - Disable standalone styles
                   Add class="sw-embedded" to body to use minimal styles
                   =========================================== */
                body.sw-embedded {
                  max-width: none;
                  margin: 0;
                  padding: 0;
                  background: transparent;
                }

                body.sw-embedded #app-container {
                  background: transparent;
                  padding: 0;
                  border-radius: 0;
                  box-shadow: none;
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
