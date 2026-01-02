# frozen_string_literal: true

require_relative 'base'
require 'kramdown'

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
      attr_reader :url_prefix

      # Initialize with optional URL prefix for service mode
      # @param url_prefix [String] URL prefix for all endpoints (e.g., "/apps/abc123")
      def initialize(url_prefix: "")
        @url_prefix = url_prefix
      end

      # Generate URL with prefix
      # @param path [String] The endpoint path (e.g., "/update")
      # @return [String] Prefixed URL (e.g., "/apps/abc123/update")
      def url(path)
        "#{@url_prefix}#{path}"
      end

      # Render a single-line text input field with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this input
      # @param options [Hash] Component options
      # @option options [String] :placeholder Placeholder text
      # @option options [Hash] :form_context Form context if inside a form block
      # @option options [Boolean] :submit Whether to auto-submit on change (default: true)
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_text_field(view, key, options, state)
        form_context = options[:form_context]
        should_submit = options.fetch(:submit, true)

        if form_context
          # Inside form: use form-scoped x-model, no HTMX
          form_name = form_context[:name]
          form_state = state[form_name] || {}
          view.input(
            id: "input-#{form_name}-#{key}",
            type: "text",
            name: "#{form_name}[#{key}]",  # Rails-style nested params
            value: form_state[key] || "",
            placeholder: options[:placeholder] || "",
            "x-model" => "_form.#{key}"  # Form-local Alpine scope
          )
        elsif should_submit
          trigger_str, endpoint = build_input_triggers(key, options)

          view.input(
            id: "input-#{key}",
            type: "text",
            name: key.to_s,
            value: state[key] || "",
            placeholder: options[:placeholder] || "",
            "x-model" => key.to_s,
            "hx-post" => endpoint,
            "hx-include" => input_selector,
            "hx-target" => "#app-container",
            "hx-swap" => "innerHTML scroll:false",
            "hx-trigger" => trigger_str
          )
        else
          # No auto-submit: just Alpine.js binding, no HTMX
          view.input(
            id: "input-#{key}",
            type: "text",
            name: key.to_s,
            value: state[key] || "",
            placeholder: options[:placeholder] || "",
            "x-model" => key.to_s
          )
        end
      end

      # Render a multi-line text area with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this textarea
      # @param options [Hash] Component options
      # @option options [String] :placeholder Placeholder text
      # @option options [Integer] :rows Number of rows (default: 3)
      # @option options [Hash] :form_context Form context if inside a form block
      # @option options [Boolean] :submit Whether to auto-submit on change (default: true)
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_text_area(view, key, options, state)
        form_context = options[:form_context]
        should_submit = options.fetch(:submit, true)

        if form_context
          # Inside form: use form-scoped x-model, no HTMX
          form_name = form_context[:name]
          form_state = state[form_name] || {}
          view.textarea(
            id: "input-#{form_name}-#{key}",
            name: "#{form_name}[#{key}]",  # Rails-style nested params
            placeholder: options[:placeholder] || "",
            rows: options[:rows] || 3,
            "x-model" => "_form.#{key}"  # Form-local Alpine scope
          ) { form_state[key] || "" }
        elsif should_submit
          trigger_str, endpoint = build_input_triggers(key, options)

          view.textarea(
            id: "input-#{key}",
            name: key.to_s,
            placeholder: options[:placeholder] || "",
            rows: options[:rows] || 3,
            "x-model" => key.to_s,
            "hx-post" => endpoint,
            "hx-include" => input_selector,
            "hx-target" => "#app-container",
            "hx-swap" => "innerHTML scroll:false",
            "hx-trigger" => trigger_str
          ) { state[key] || "" }
        else
          # No auto-submit: just Alpine.js binding, no HTMX
          view.textarea(
            id: "input-#{key}",
            name: key.to_s,
            placeholder: options[:placeholder] || "",
            rows: options[:rows] || 3,
            "x-model" => key.to_s
          ) { state[key] || "" }
        end
      end

      # Render a checkbox input with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this checkbox
      # @param label [String] The label text
      # @param options [Hash] Component options
      # @option options [Hash] :form_context Form context if inside a form block
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_checkbox(view, key, label, options, state)
        form_context = options[:form_context]
        should_submit = options.fetch(:submit, true)

        if form_context
          # Inside form: use form-scoped x-model, no HTMX
          form_name = form_context[:name]
          form_state = state[form_name] || {}
          view.label do
            view.input(
              type: "checkbox",
              name: "#{form_name}[#{key}]",
              value: "true",
              checked: form_state[key],
              "x-model" => "_form.#{key}"  # Form-local Alpine scope
            )
            view.plain " #{label}"
          end
        elsif should_submit
          # Use /event endpoint if there's a callback
          has_on_change = options[:on_change]
          endpoint = has_on_change ? url("/event/#{key}") : url("/update")

          view.label do
            view.input(
              type: "checkbox",
              name: key.to_s,
              value: "true",
              checked: state[key],
              "x-model" => key.to_s,
              "hx-post" => endpoint,
              "hx-include" => input_selector,
              "hx-target" => "#app-container",
              "hx-swap" => "innerHTML scroll:false",
              "hx-trigger" => "change"
            )
            view.plain " #{label}"
          end
        else
          # No auto-submit: just Alpine.js binding, no HTMX
          view.label do
            view.input(
              type: "checkbox",
              name: key.to_s,
              value: "true",
              checked: state[key],
              "x-model" => key.to_s
            )
            view.plain " #{label}"
          end
        end
      end

      # Render a select dropdown with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this select
      # @param choices [Array<String>] The available choices
      # @param options [Hash] Component options
      # @option options [String] :default Default selected value when state is nil
      # @option options [Hash] :form_context Form context if inside a form block
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_select(view, key, choices, options, state)
        form_context = options[:form_context]
        should_submit = options.fetch(:submit, true)

        if form_context
          # Inside form: use form-scoped x-model, no HTMX
          form_name = form_context[:name]
          form_state = state[form_name] || {}
          current_value = form_state[key] || options[:default]

          view.select(
            name: "#{form_name}[#{key}]",  # Rails-style nested params
            "x-model" => "_form.#{key}"  # Form-local Alpine scope
          ) do
            choices.each do |choice|
              view.option(
                value: choice,
                selected: current_value == choice
              ) { choice }
            end
          end
        elsif should_submit
          # Use /event endpoint if there's a callback
          has_on_change = options[:on_change]
          endpoint = has_on_change ? url("/event/#{key}") : url("/update")
          current_value = state[key] || options[:default]

          view.select(
            name: key.to_s,
            "x-model" => key.to_s,
            "hx-post" => endpoint,
            "hx-include" => input_selector,
            "hx-target" => "#app-container",
            "hx-swap" => "innerHTML scroll:false",
            "hx-trigger" => "change"
          ) do
            choices.each do |choice|
              view.option(
                value: choice,
                selected: current_value == choice
              ) { choice }
            end
          end
        else
          # No auto-submit: just Alpine.js binding, no HTMX
          current_value = state[key] || options[:default]

          view.select(
            name: key.to_s,
            "x-model" => key.to_s
          ) do
            choices.each do |choice|
              view.option(
                value: choice,
                selected: current_value == choice
              ) { choice }
            end
          end
        end
      end

      # Render a radio button group with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this radio group
      # @param choices [Array<String>] The available choices
      # @param options [Hash] Component options
      # @option options [Hash] :form_context Form context if inside a form block
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_radio_group(view, key, choices, options, state)
        form_context = options[:form_context]

        if form_context
          # Inside form: use form-scoped x-model, no HTMX
          form_name = form_context[:name]
          form_state = state[form_name] || {}
          current_value = form_state[key]

          view.div(class: "radio-group") do
            choices.each do |choice|
              view.label(class: "radio-option") do
                view.input(
                  type: "radio",
                  name: "#{form_name}[#{key}]",
                  value: choice,
                  checked: current_value == choice,
                  "x-model" => "_form.#{key}"  # Form-local Alpine scope
                )
                view.span { choice }
              end
            end
          end
        else
          # Standalone: immediate HTMX sync on change
          current_value = state[key]

          view.div(class: "radio-group") do
            choices.each do |choice|
              view.label(class: "radio-option") do
                view.input(
                  type: "radio",
                  name: key.to_s,
                  value: choice,
                  checked: current_value == choice,
                  "x-model" => key.to_s,  # Alpine.js two-way binding
                  "hx-post" => url("/update"),
                  "hx-include" => input_selector,
                  "hx-target" => "#app-container",
                  "hx-swap" => "innerHTML scroll:false",
                  "hx-trigger" => "change"  # Immediate update on change
                )
                view.span { choice }
              end
            end
          end
        end
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
      def render_checkbox_group(view, key, children, options, state)
        current_values = state[key] || []
        all_values = children.map(&:value)

        view.div(class: "checkbox-group") do
          # Render select all/none buttons if options provided
          if options[:select_all] || options[:select_none]
            view.div(class: "checkbox-group-actions") do
              if options[:select_all]
                view.button(
                  type: "button",
                  class: "btn btn-sm",
                  "@click" => "#{key} = #{JSON.generate(all_values)}"
                ) { options[:select_all] }
              end

              if options[:select_none]
                view.button(
                  type: "button",
                  class: "btn btn-sm",
                  "@click" => "#{key} = []"
                ) { options[:select_none] }
              end
            end
          end

          # Render each checkbox item
          children.each do |item|
            view.label(class: "checkbox-item") do
              view.input(
                type: "checkbox",
                name: key.to_s,
                value: item.value,
                checked: current_values.include?(item.value),
                "x-model" => key.to_s,  # Alpine.js array binding
                "hx-post" => url("/update"),
                "hx-include" => input_selector,
                "hx-target" => "#app-container",
                "hx-swap" => "innerHTML scroll:false",
                "hx-trigger" => "change"
              )

              # Render item's nested content
              item.children.each do |child|
                child.render(view, state)
              end
            end
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
      # @param modal_context [Hash, nil] Modal context if button is inside a modal
      # @return [void] Renders to view
      def render_button(view, button_id, label, options, modal_context = nil)
        # Support :none style for unstyled buttons, or string styles for inline CSS
        style_option = options[:style]
        if style_option == :none || style_option.is_a?(String)
          # Custom/unstyled button - use inline style if provided
          button_class = options[:class]
          inline_style = style_option.is_a?(String) ? style_option : nil
        else
          style_class = style_option == :secondary ? "secondary" : "primary"
          button_class = "btn btn-#{style_class}"
          inline_style = nil
        end
        should_submit = options.fetch(:submit, true)

        if !should_submit
          # Display-only button: no HTMX, just visual
          attrs = { type: "button" }
          attrs[:class] = button_class if button_class
          attrs[:style] = inline_style if inline_style
          view.button(**attrs) { label }
        elsif modal_context
          # Inside a modal: close via Alpine before HTMX request fires
          # hx-on::before-request runs before HTMX sends, allowing Alpine to close modal
          attrs = {
            "hx-post" => url("/action/#{button_id}"),
            "hx-include" => input_selector,
            "hx-target" => "#app-container",
            "hx-swap" => "innerHTML scroll:false",
            "hx-on::before-request" => "open = false"
          }
          attrs[:class] = button_class if button_class
          attrs[:style] = inline_style if inline_style
          view.button(**attrs) { label }
        else
          # Normal button: use standard HTMX
          attrs = {
            "hx-post" => url("/action/#{button_id}"),     # HTMX POST to server
            "hx-include" => input_selector,          # Include all inputs with x-model
            "hx-target" => "#app-container",         # Replace app container
            "hx-swap" => "innerHTML scroll:false"    # Replace inner HTML, preserve scroll
          }
          attrs[:class] = button_class if button_class
          attrs[:style] = inline_style if inline_style
          view.button(**attrs) { label }
        end
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

      # Render an app header bar
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [AppHeader] The app header component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_app_header(view, component, state)
        view.div(class: "sw-app-header sw-app-header-#{component.variant}") do
          view.div(class: "sw-app-header-brand") do
            view.span(class: "sw-app-header-title") { component.title }
            if component.subtitle
              view.span(class: "sw-app-header-subtitle") { component.subtitle }
            end
          end
          if component.children.any?
            view.div(class: "sw-app-header-actions") do
              component.children.each { |child| child.render(view, state) }
            end
          end
        end
      end

      # Render a div container with optional hover support
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Div] The div component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_div(view, component, state)
        options = component.instance_variable_get(:@options)
        css_class = options[:class]
        css_style = options[:style]
        css_id = options[:id]
        hover_class = component.hover_class

        attrs = {}
        attrs[:class] = css_class if css_class
        attrs[:style] = css_style if css_style
        attrs[:id] = css_id if css_id

        # Client-side hover class toggle (no server round-trip for performance)
        if hover_class
          attrs["x-data"] = "{ hovered: false }"
          attrs["@mouseenter"] = "hovered = true"
          attrs["@mouseleave"] = "hovered = false"
          attrs[":class"] = "{ '#{hover_class}': hovered }"
        end

        view.div(**attrs) do
          component.children.each { |child| child.render(view, state) }
        end
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
        # Focus, scroll restoration, and Alpine.js state sync script
        view.script do
          view.raw(view.safe(<<~JS))
            (function() {
              let focusState = null;
              let scrollState = null;

              // =============================================================
              // Alpine.js Defer Mutations Pattern for HTMX Integration
              // =============================================================
              // Problem: HTMX swaps innerHTML but Alpine's x-data on outer
              // container keeps stale values. Alpine's x-model then overwrites
              // correct server-rendered values with old data.
              //
              // Solution: Pause Alpine's MutationObserver during HTMX swap,
              // then resume after DOM settles. This lets Alpine reinitialize
              // with fresh x-data from server response.
              //
              // References:
              // - https://github.com/alpinejs/alpine/discussions/3985
              // - https://github.com/bigskysoftware/htmx/discussions/1367
              // =============================================================

              // Before swap: save focus/scroll state and pause Alpine mutations
              document.addEventListener('htmx:beforeSwap', function(e) {
                // Defer Alpine mutations during swap to prevent stale state conflicts
                if (typeof Alpine !== 'undefined' && Alpine.deferMutations) {
                  Alpine.deferMutations();
                }

                // Save focus
                const active = document.activeElement;
                if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA')) {
                  focusState = {
                    id: active.id,
                    selectionStart: active.selectionStart,
                    selectionEnd: active.selectionEnd
                  };
                } else {
                  focusState = null;
                }

                // Save scroll position
                scrollState = {
                  x: window.scrollX,
                  y: window.scrollY
                };
              });

              // After settle: reinitialize Alpine with fresh state, restore focus/scroll
              // afterSettle fires after DOM is fully updated, safer than afterSwap
              document.addEventListener('htmx:afterSettle', function(e) {
                // Reinitialize Alpine with fresh state from server response
                // The partial includes a script#sw-state-data with the new state JSON
                const stateEl = document.getElementById('sw-state-data');
                const container = document.getElementById('app-container');

                if (stateEl && container && typeof Alpine !== 'undefined') {
                  try {
                    const newState = JSON.parse(stateEl.textContent);
                    // Update Alpine's reactive data on the container
                    // Alpine.$data gives access to the component's reactive data proxy
                    const alpineData = Alpine.$data(container);
                    if (alpineData) {
                      // Merge new state into existing Alpine data
                      Object.keys(newState).forEach(key => {
                        alpineData[key] = newState[key];
                      });
                    }
                  } catch (err) {
                    console.warn('StreamWeaver: Failed to reinitialize Alpine state', err);
                  }
                }

                // Resume Alpine mutations after state is updated
                if (typeof Alpine !== 'undefined' && Alpine.flushAndStopDeferringMutations) {
                  Alpine.flushAndStopDeferringMutations();
                }

                // Restore focus
                if (focusState && focusState.id) {
                  const el = document.getElementById(focusState.id);
                  if (el) {
                    el.focus();
                    if (typeof el.setSelectionRange === 'function' && focusState.selectionStart !== null) {
                      el.setSelectionRange(focusState.selectionStart, focusState.selectionEnd);
                    }
                  }
                  focusState = null;
                }

                // Restore scroll position
                if (scrollState) {
                  window.scrollTo(scrollState.x, scrollState.y);
                  scrollState = null;
                }
              });
            })();
          JS
        end
      end

      # Get the CSS selector for Alpine.js bound inputs
      #
      # @return [String] CSS selector "[x-model]"
      def input_selector
        "[x-model]"  # Alpine.js selector for all bound inputs
      end

      # Render a term with tooltip functionality
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param term_key [String] The glossary term key
      # @param options [Hash] Component options
      # @option options [String] :display Alternative display text
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_term(view, term_key, options, state)
        display_text = options[:display] || term_key
        # Normalize the term key for use as an identifier (lowercase, underscores)
        term_id = term_key.to_s.downcase.gsub(/\s+/, '_')

        view.span(
          class: "term",
          "data-term" => term_id,
          "@mouseenter" => "showTooltip('#{term_id}', $el)",
          "@mouseleave" => "hideTooltip()",
          "@focus" => "showTooltip('#{term_id}', $el)",
          "@blur" => "hideTooltip()",
          "tabindex" => "0"
        ) { display_text }
      end

      # Render a lesson text container with glossary support
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param glossary [Hash] Glossary definitions {term => {simple:, detailed:}}
      # @param children [Array] Child components (Phrase and Term)
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_lesson_text(view, glossary, children, options, state)
        # Convert glossary to JSON for Alpine.js
        # Normalize keys to match term_id format
        normalized_glossary = {}
        glossary.each do |term, definitions|
          term_id = term.to_s.downcase.gsub(/\s+/, '_')
          normalized_glossary[term_id] = {
            term: term.to_s,
            simple: definitions[:simple] || definitions["simple"] || "",
            detailed: definitions[:detailed] || definitions["detailed"] || ""
          }
        end
        glossary_json = JSON.generate(normalized_glossary)

        view.div(
          class: "lesson-text",
          "x-data" => "{
            activeTooltip: null,
            tooltipContent: '',
            tooltipDetailed: '',
            showDetailed: false,
            tooltipX: 0,
            tooltipY: 0,
            glossary: #{glossary_json},
            showTooltip(termId, el) {
              this.activeTooltip = termId;
              const def = this.glossary[termId];
              if (def) {
                this.tooltipContent = def.simple;
                this.tooltipDetailed = def.detailed;
              }
              this.showDetailed = false;
              // Position tooltip above the term
              const rect = el.getBoundingClientRect();
              this.tooltipX = rect.left + (rect.width / 2);
              this.tooltipY = rect.top - 8;
            },
            hideTooltip() {
              this.activeTooltip = null;
              this.showDetailed = false;
            },
            toggleDetailed() {
              this.showDetailed = !this.showDetailed;
            }
          }"
        ) do
          # Render child components (Phrase and Term)
          children.each do |child|
            child.render(view, state)
          end

          # Render the floating tooltip (positioned dynamically via Alpine.js)
          view.div(
            class: "tooltip",
            "x-show" => "activeTooltip !== null",
            "x-cloak" => true,
            "@click" => "toggleDetailed()",
            ":style" => "'left: ' + tooltipX + 'px; top: ' + tooltipY + 'px;'"
          ) do
            view.div(class: "tooltip-content") do
              view.span("x-text" => "showDetailed ? tooltipDetailed : tooltipContent")
            end
            view.div(class: "tooltip-hint", "x-show" => "tooltipDetailed && !showDetailed") do
              view.plain "Tap for more detail"
            end
          end
        end
      end

      # Render a collapsible section with expand/collapse functionality
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param label [String] The header label text
      # @param expanded [Boolean] Whether to start expanded
      # @param children [Array] Child components to render inside
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_collapsible(view, label, expanded, children, options, state)
        view.div(class: "collapsible", "x-data" => "{ open: #{expanded} }") do
          view.div(class: "collapsible-header", "@click" => "open = !open") do
            view.span(class: "collapsible-icon", "x-text" => "open ? '▼' : '▶'")
            view.span(class: "collapsible-label") { label }
          end
          view.div(class: "collapsible-content", "x-show" => "open", "x-cloak" => true) do
            children.each { |child| child.render(view, state) }
          end
        end
      end

      # Render a score table with color-coded metrics
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param scores [Array<Hash>] Array of {label:, value:, max:} hashes
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_score_table(view, scores, options, state)
        view.table(class: "score-table") do
          view.thead do
            view.tr do
              view.th { "Metric" }
              view.th { "Score" }
              view.th { "Meaning" }
            end
          end
          view.tbody do
            scores.each do |score|
              value = score[:value] || 0
              max = score[:max] || 10
              ratio = value.to_f / max

              color_class = ratio >= 0.7 ? "score-high" : (ratio >= 0.4 ? "score-medium" : "score-low")
              interpretation = ratio >= 0.8 ? "Excellent" : (ratio >= 0.7 ? "Strong" : (ratio >= 0.5 ? "Moderate" : "Weak"))

              view.tr do
                view.td { score[:label] }
                view.td(class: "score-cell #{color_class}") { value.to_s }
                view.td(class: "score-meaning") { interpretation }
              end
            end
          end
        end
      end

      # Render markdown content with inline parsing
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param content [String] The markdown content
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_markdown(view, content, state)
        html = Kramdown::Document.new(
          content,
          input: 'GFM',
          hard_wrap: false,
          syntax_highlighter: nil
        ).to_html
        view.div(class: "markdown-content") do
          view.raw view.safe(html)
        end
      end

      # Render a semantic header (h1-h6)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param content [String] The header text
      # @param level [Integer] Header level (1-6)
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_header(view, content, level, state)
        case level
        when 1 then view.h1 { content }
        when 2 then view.h2 { content }
        when 3 then view.h3 { content }
        when 4 then view.h4 { content }
        when 5 then view.h5 { content }
        when 6 then view.h6 { content }
        else view.h2 { content }
        end
      end

      # Render a status badge with icon and reasoning
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param status [Symbol] One of :strong, :maybe, :skip
      # @param reasoning [String] Explanation text
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_status_badge(view, status, reasoning, state)
        icon, label, css_class = case status
        when :strong then ["🟢", "Strong", "status-badge-strong"]
        when :maybe then ["🟡", "Maybe", "status-badge-maybe"]
        when :skip then ["🔴", "Skip", "status-badge-skip"]
        else ["⚪", "Unknown", "status-badge-unknown"]
        end

        view.span(class: "status-badge #{css_class}") do
          view.span(class: "status-badge-icon") { icon }
          view.span(class: "status-badge-label") { label }
          view.span(class: "status-badge-reasoning") { " — #{reasoning}" }
        end
      end

      # Render a tag button group for quick selection
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for selected tag
      # @param tags [Array<String>] The available tag labels
      # @param options [Hash] Options (style: :default or :destructive)
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_tag_buttons(view, key, tags, options, state)
        current_value = state[key]
        style_class = options[:style] == :destructive ? "tag-buttons-destructive" : "tag-buttons-default"

        view.div(class: "tag-buttons #{style_class}") do
          tags.each do |tag|
            tag_value = tag.downcase.gsub(/\s+/, '_')
            selected = current_value == tag_value

            view.button(
              type: "button",
              class: "tag-btn #{selected ? 'tag-btn-selected' : ''}",
              "hx-post" => url("/update"),
              "hx-vals" => JSON.generate({ key.to_s => tag_value }),
              "hx-include" => input_selector,
              "hx-target" => "#app-container",
              "hx-swap" => "innerHTML scroll:false"
            ) { tag }
          end
        end
      end

      # Render a button that opens external URL and optionally submits form
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param label [String] Button label
      # @param url [String] URL to open
      # @param submit [Boolean] Whether to also submit form
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_external_link_button(view, label, url, submit, state)
        if submit
          # Submit form via HTMX, then open URL
          view.button(
            type: "button",
            class: "btn btn-primary external-link-btn",
            "hx-post" => url("/submit"),
            "hx-include" => input_selector,
            "hx-target" => "#app-container",
            "hx-swap" => "innerHTML",
            "@click" => "setTimeout(() => window.open('#{url}', '_blank'), 100)"
          ) { label }
        else
          # Just open URL, no form submit
          view.a(
            href: url,
            target: "_blank",
            class: "btn btn-primary external-link-btn"
          ) { label }
        end
      end

      # Render a multi-column layout container
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param widths [Array<String>, nil] Optional column widths (e.g., ['30%', '70%'])
      # @param children [Array<Column>] Column components
      # @param options [Hash] Component options (e.g., gap)
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_columns(view, widths, children, options, state)
        gap = options[:gap] || "var(--sw-spacing-lg)"

        view.div(class: "sw-columns", style: "display: flex; gap: #{gap};") do
          children.each_with_index do |column, index|
            # Apply width if specified, otherwise equal flex
            column.width = widths&.[](index)
            column.render(view, state)
          end
        end
      end

      # Render an individual column within a Columns container
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param width [String, nil] Column width (e.g., '30%') or nil for equal flex
      # @param children [Array] Child components
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_column(view, width, children, options, state)
        css_class = ["sw-column", options[:class]].compact.join(" ")

        style = if width
          "flex: 1 1 #{width}; min-width: 0;"  # Grow/shrink proportionally from width basis
        else
          "flex: 1 1 0; min-width: 0;"  # Equal distribution
        end

        view.div(class: css_class, style: style) do
          children.each { |child| child.render(view, state) }
        end
      end

      # Render a form block with deferred submission
      # Uses Alpine.js for local state, single HTMX POST on submit
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param name [Symbol] The form name (state key)
      # @param children [Array] Child components (form fields)
      # @param submit_label [String, nil] Submit button label
      # @param cancel_label [String, nil] Cancel button label
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_form(view, name, children, submit_label, cancel_label, options, state)
        form_state = state[name] || {}

        # Build Alpine.js x-data with _form (editable) and _original (for cancel reset)
        form_json = JSON.generate(form_state.transform_keys(&:to_s))

        view.div(
          class: "sw-form",
          "x-data" => "{ _form: #{form_json}, _original: #{form_json} }"
        ) do
          # Render child components (form fields)
          children.each { |child| child.render(view, state) }

          # Render form buttons
          view.div(class: "sw-form-actions") do
            if submit_label
              view.button(
                type: "button",
                class: "btn btn-primary",
                "hx-post" => url("/form/#{name}"),
                "hx-include" => "[name^='#{name}[']",
                "hx-target" => "#app-container",
                "hx-swap" => "innerHTML scroll:false"
              ) { submit_label }
            end

            if cancel_label
              view.button(
                type: "button",
                class: "btn btn-secondary",
                "@click" => "_form = JSON.parse(JSON.stringify(_original))"
              ) { cancel_label }
            end
          end
        end
      end

      def render_vstack(view, component, state)
        render_stack(view, :vertical, component, state)
      end

      def render_hstack(view, component, state)
        render_stack(view, :horizontal, component, state)
      end

      def render_grid(view, component, state)
        css_classes = ["sw-grid"]
        css_classes << component.options[:class] if component.options[:class]

        gap_value = spacing_to_css(component.gap)
        styles = ["gap: #{gap_value};"]

        if component.columns.is_a?(Array)
          cols_sm = component.columns[0] || 1
          cols_md = component.columns[1] || cols_sm
          cols_lg = component.columns[2] || cols_md

          styles << "--sw-grid-cols-sm: #{cols_sm};"
          styles << "--sw-grid-cols-md: #{cols_md};"
          styles << "--sw-grid-cols-lg: #{cols_lg};"
          styles << "grid-template-columns: repeat(#{cols_lg}, 1fr);"

          view.div(
            class: css_classes.join(" "),
            style: styles.join(" "),
            "data-cols-sm" => cols_sm,
            "data-cols-md" => cols_md,
            "data-cols-lg" => cols_lg
          ) do
            component.children.each { |child| child.render(view, state) }
          end
        else
          styles << "grid-template-columns: repeat(#{component.columns}, 1fr);"

          view.div(class: css_classes.join(" "), style: styles.join(" ")) do
            component.children.each { |child| child.render(view, state) }
          end
        end
      end

      # =========================================
      # Navigation components rendering
      # =========================================

      # Render a tabbed navigation container
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Tabs] The tabs component with children
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_tabs(view, component, state)
        key = component.key
        active_index = state[key] || 0
        variant_class = "sw-tabs-#{component.variant}"

        view.div(
          id: "tabs-#{key}",
          class: "sw-tabs #{variant_class}",
          "x-data" => "{ activeTab: #{active_index} }"
        ) do
          # Hidden input syncs tab state with server on other HTMX requests
          view.input(type: "hidden", name: key.to_s, "x-model" => "activeTab")

          # Tab headers
          view.div(class: "sw-tabs-list") do
            component.children.each_with_index do |tab, index|
              # Pre-render active class server-side to prevent flash during HTMX swaps
              # Alpine's :class maintains it after initialization
              tab_classes = ["sw-tab-trigger"]
              tab_classes << "sw-tab-active" if index == active_index

              # Tab buttons: Alpine.js for instant UI + HTMX to sync state
              # hx-swap="none" means server response is ignored (no DOM changes)
              view.button(
                type: "button",
                class: tab_classes.join(" "),
                ":class" => "{ 'sw-tab-active': activeTab === #{index} }",
                "@click" => "activeTab = #{index}",
                "hx-post" => url("/update"),
                "hx-vals" => JSON.generate({ key.to_s => index }),
                "hx-swap" => "none"
              ) { tab.label }
            end
          end

          # Tab panels
          component.children.each_with_index do |tab, index|
            view.div(
              class: "sw-tab-panel",
              "x-show" => "activeTab === #{index}",
              "x-cloak" => true
            ) do
              tab.children.each { |child| child.render(view, state) }
            end
          end
        end
      end

      # Render a breadcrumbs navigation trail
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Breadcrumbs] The breadcrumbs component with children
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_breadcrumbs(view, component, state)
        view.nav(class: "sw-breadcrumbs", "aria-label" => "Breadcrumb") do
          view.ol(class: "sw-breadcrumbs-list") do
            component.children.each_with_index do |crumb, index|
              is_last = index == component.children.length - 1

              view.li(class: "sw-breadcrumb-item") do
                # Separator (except for first item)
                if index > 0
                  view.span(class: "sw-breadcrumb-separator", "aria-hidden" => "true") do
                    component.separator
                  end
                end

                # Crumb link or text
                if crumb.href && !is_last
                  view.a(href: crumb.href, class: "sw-breadcrumb-link") { crumb.label }
                else
                  aria = is_last ? { "aria-current" => "page" } : {}
                  view.span(class: "sw-breadcrumb-current", **aria) { crumb.label }
                end
              end
            end
          end
        end
      end

      # Render a dropdown menu container
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Dropdown] The dropdown component with trigger and menu
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_dropdown(view, component, state)
        view.div(
          class: "sw-dropdown",
          "x-data" => "{ open: false }",
          "@click.outside" => "open = false",
          "@keydown.escape.window" => "open = false"
        ) do
          # Render trigger - use @click.capture.stop to intercept click BEFORE it reaches button's HTMX
          # .capture = handle during capture phase (parent first), .stop = prevent reaching children
          if component.trigger_component
            view.div(class: "sw-dropdown-trigger", "@click.capture.stop" => "open = !open") do
              component.trigger_component.children.each { |child| child.render(view, state) }
            end
          end

          # Render menu
          if component.menu_component
            view.div(
              class: "sw-dropdown-menu",
              "x-show" => "open",
              "x-cloak" => true,
              "x-transition:enter" => "sw-transition-enter",
              "x-transition:enter-start" => "sw-transition-enter-start",
              "x-transition:enter-end" => "sw-transition-enter-end",
              "x-transition:leave" => "sw-transition-leave",
              "x-transition:leave-start" => "sw-transition-leave-start",
              "x-transition:leave-end" => "sw-transition-leave-end"
            ) do
              component.menu_component.children.each do |item|
                render_menu_item(view, item, state)
              end
            end
          end
        end
      end

      # Render a modal dialog
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Modal] The modal component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_modal(view, component, state)
        key = component.key
        open_key = :"#{key}_open"
        is_open = state[open_key] || false
        size_class = "sw-modal-#{component.size}"

        # Modal container with Alpine.js state
        # Uses a reactive binding to the state key
        view.div(
          class: "sw-modal-wrapper",
          "x-data" => "{ open: #{is_open} }",
          "x-init" => "$watch('open', v => { if(!v) htmx.ajax('POST', '#{url("/update")}', {target:'#app-container', swap:'innerHTML scroll:false', values:{'#{open_key}': 'false'}}) })",
          "@keydown.escape.window" => "open = false"
        ) do
          # Backdrop overlay
          view.div(
            class: "sw-modal-backdrop",
            "x-show" => "open",
            "x-cloak" => true,
            "x-transition:enter" => "sw-transition-fade-enter",
            "x-transition:enter-start" => "sw-transition-fade-enter-start",
            "x-transition:enter-end" => "sw-transition-fade-enter-end",
            "x-transition:leave" => "sw-transition-fade-leave",
            "x-transition:leave-start" => "sw-transition-fade-leave-start",
            "x-transition:leave-end" => "sw-transition-fade-leave-end",
            "@click" => "open = false"
          )

          # Modal dialog
          view.div(
            class: "sw-modal #{size_class}",
            "x-show" => "open",
            "x-cloak" => true,
            "x-transition:enter" => "sw-transition-modal-enter",
            "x-transition:enter-start" => "sw-transition-modal-enter-start",
            "x-transition:enter-end" => "sw-transition-modal-enter-end",
            "x-transition:leave" => "sw-transition-modal-leave",
            "x-transition:leave-start" => "sw-transition-modal-leave-start",
            "x-transition:leave-end" => "sw-transition-modal-leave-end",
            "@click.stop" => ""  # Prevent clicks inside modal from closing it
          ) do
            # Header with title and close button
            if component.title
              view.div(class: "sw-modal-header") do
                view.h3(class: "sw-modal-title") { component.title }
                render_modal_close_button(view)
              end
            else
              render_modal_close_button(view, close_only: true)
            end

            # Body content
            view.div(class: "sw-modal-body") do
              component.children.each { |child| child.render(view, state) }
            end

            # Footer (if present)
            if component.footer_component
              view.div(class: "sw-modal-footer") do
                component.footer_component.children.each { |child| child.render(view, state) }
              end
            end
          end
        end
      end

      # =========================================
      # Feedback components rendering
      # =========================================

      # Render an alert component
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Alert] The alert component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_alert(view, component, state)
        variant_class = "sw-alert-#{component.variant}"
        css_classes = ["sw-alert", variant_class]

        icon = case component.variant
        when :success then "✓"
        when :warning then "⚠"
        when :error then "✕"
        else "ℹ" # :info
        end

        if component.dismissible
          view.div(
            class: css_classes.join(" "),
            "x-data" => "{ dismissed: false }",
            "x-show" => "!dismissed",
            "x-transition:leave" => "sw-transition-fade-leave",
            "x-transition:leave-start" => "sw-transition-fade-leave-start",
            "x-transition:leave-end" => "sw-transition-fade-leave-end"
          ) do
            view.span(class: "sw-alert-icon") { icon }
            view.div(class: "sw-alert-content") do
              view.strong(class: "sw-alert-title") { component.title } if component.title
              component.children.each { |child| child.render(view, state) }
            end
            view.button(
              type: "button",
              class: "sw-alert-dismiss",
              "@click" => "dismissed = true",
              "aria-label" => "Dismiss"
            ) { "×" }
          end
        else
          view.div(class: css_classes.join(" ")) do
            view.span(class: "sw-alert-icon") { icon }
            view.div(class: "sw-alert-content") do
              view.strong(class: "sw-alert-title") { component.title } if component.title
              component.children.each { |child| child.render(view, state) }
            end
          end
        end
      end

      # Render a toast container with multiple stacked notifications
      # Each toast is rendered directly (no Alpine x-for) for reliable HTMX swap behavior
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [ToastContainer] The toast container component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_toast_container(view, component, state)
        position_class = "sw-toast-#{component.position.to_s.gsub('_', '-')}"
        toasts = state[:_toasts] || []
        default_duration = component.duration

        view.div(class: "sw-toast-container #{position_class}") do
          toasts.each do |toast|
            toast_id = toast[:id].to_s
            message = toast[:message].to_s
            variant = (toast[:variant] || :info).to_s
            duration = toast[:duration] || default_duration

            icon = case variant.to_sym
            when :success then "✓"
            when :warning then "⚠"
            when :error then "✕"
            else "ℹ"
            end

            # Each toast has its own Alpine scope for dismiss + auto-dismiss
            auto_dismiss = duration > 0 ? "setTimeout(() => dismiss(), #{duration})" : ""

            view.div(
              class: "sw-toast sw-toast-#{variant}",
              "x-data" => "{ show: true, dismiss() { this.show = false; htmx.ajax('POST', '/toast/dismiss/#{toast_id}', {target:'#app-container', swap:'none'}); } }",
              "x-show" => "show",
              "x-init" => auto_dismiss,
              "x-transition:leave" => "sw-transition-toast-leave",
              "x-transition:leave-start" => "sw-transition-toast-leave-start",
              "x-transition:leave-end" => "sw-transition-toast-leave-end"
            ) do
              view.span(class: "sw-toast-icon") { icon }
              view.span(class: "sw-toast-message") { message }
              view.button(
                type: "button",
                class: "sw-toast-dismiss",
                "@click" => "dismiss()",
                "aria-label" => "Dismiss"
              ) { "×" }
            end
          end
        end
      end

      # Render a progress bar
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param value [Integer] Current value
      # @param max [Integer] Maximum value
      # @param variant [Symbol] Style variant
      # @param show_label [Boolean] Show percentage label
      # @param animated [Boolean] Show animation
      # @param options [Hash] Additional options
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_progress_bar(view, value, max, variant, show_label, animated, options, state)
        percentage = max > 0 ? ((value.to_f / max) * 100).round : 0
        variant_class = "sw-progress-#{variant}"
        css_classes = ["sw-progress", variant_class]
        css_classes << "sw-progress-animated" if animated

        view.div(class: css_classes.join(" "), role: "progressbar", "aria-valuenow" => value, "aria-valuemin" => 0, "aria-valuemax" => max) do
          view.div(class: "sw-progress-bar", style: "width: #{percentage}%;")
          if show_label
            view.span(class: "sw-progress-label") { "#{percentage}%" }
          end
        end
      end

      # Render a spinner/loading indicator
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param size [Symbol] Spinner size (:sm, :md, :lg)
      # @param label [String, nil] Optional loading text
      # @param options [Hash] Additional options
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_spinner(view, size, label, options, state)
        size_class = "sw-spinner-#{size}"

        view.div(class: "sw-spinner-container") do
          view.div(class: "sw-spinner #{size_class}", role: "status", "aria-label" => label || "Loading")
          if label
            view.span(class: "sw-spinner-label") { label }
          end
        end
      end

      # Render a theme switcher dropdown
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [ThemeSwitcher] The theme switcher component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_theme_switcher(view, component, state)
        themes = component.themes
        position_class = component.position == :fixed_top_right ? "sw-theme-switcher-fixed" : ""

        view.div(
          class: "sw-theme-switcher #{position_class}".strip,
          "x-data" => "{ open: false }"
        ) do
          if component.show_label
            view.span(class: "sw-theme-switcher-label") { "Theme:" }
          end

          view.div(class: "sw-theme-switcher-dropdown") do
            view.button(
              type: "button",
              class: "sw-theme-switcher-trigger",
              "@click" => "open = !open",
              "@click.outside" => "open = false"
            ) do
              view.span(class: "sw-theme-switcher-current") { "Select theme" }
              view.span(class: "sw-theme-switcher-arrow") { "\u25BC" }
            end

            view.div(
              class: "sw-theme-switcher-menu",
              "x-show" => "open",
              "x-transition:enter" => "sw-transition-dropdown-enter",
              "x-transition:enter-start" => "sw-transition-dropdown-enter-start",
              "x-transition:enter-end" => "sw-transition-dropdown-enter-end",
              "x-transition:leave" => "sw-transition-dropdown-leave",
              "x-transition:leave-start" => "sw-transition-dropdown-leave-start",
              "x-transition:leave-end" => "sw-transition-dropdown-leave-end"
            ) do
              themes.each do |theme|
                view.button(
                  type: "button",
                  class: "sw-theme-switcher-option",
                  "@click" => "open = false; document.body.className = document.body.className.replace(/sw-theme-\\w+/, 'sw-theme-#{theme[:id]}'); htmx.ajax('POST', '#{url("/theme/#{theme[:id]}")}', {swap:'none'})"
                ) do
                  view.span(class: "sw-theme-switcher-option-label") { theme[:label] }
                  view.span(class: "sw-theme-switcher-option-desc") { theme[:description] }
                end
              end
            end
          end
        end
      end

      # Render a code editor using CodeMirror 5
      #
      # Reinitializes editor on each HTMX swap to ensure content is fresh.
      # The editor instance is destroyed and recreated to avoid stale state.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::CodeEditor] The code editor component
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_code_editor(view, component, state)
        key = component.key
        content = state[key].to_s
        lang_config = component.language_config
        editor_id = "sw-code-editor-#{key}"
        readonly_str = component.readonly ? "true" : "false"

        # Container - no hx-preserve, editor reinitializes on each swap
        view.div(
          id: "#{editor_id}-wrapper",
          class: "sw-code-editor-wrapper",
          style: "height: #{component.height};"
        ) do
          # CSS to hide original textarea when CodeMirror is present (use > to avoid hiding CM's internal textarea)
          view.style { ".sw-code-editor-wrapper > textarea { display: none !important; }" }
          # Textarea with content - CodeMirror will replace this
          # x-model is required for hx-include="[x-model]" to include this in button submissions
          view.textarea(
            id: editor_id,
            name: key.to_s,
            "x-model" => key.to_s,
            style: "width: 100%; height: 100%; font-family: monospace; font-size: 13px; border: none; resize: none;"
          ) { content }
        end

        # Initialization script
        view.script do
          view.raw(view.safe(<<~JS))
            (function() {
              var editorId = '#{editor_id}';
              var wrapperId = editorId + '-wrapper';

              function initCodeEditor() {
                var textarea = document.getElementById(editorId);
                var wrapper = document.getElementById(wrapperId);
                if (!textarea || !wrapper) return;

                // Destroy existing editor if present
                var existingCM = wrapper.querySelector('.CodeMirror');
                if (existingCM && existingCM.CodeMirror) {
                  existingCM.CodeMirror.toTextArea();
                }

                // Initialize CodeMirror
                if (typeof CodeMirror === 'undefined') {
                  console.warn('CodeMirror not loaded. Add CodeMirror 5 to scripts.');
                  return;
                }

                var editor = CodeMirror.fromTextArea(textarea, {
                  mode: '#{lang_config[:mode]}',
                  lineNumbers: true,
                  readOnly: #{readonly_str},
                  theme: 'default',
                  tabSize: 2,
                  indentWithTabs: false,
                  lineWrapping: false
                });

                editor.setSize('100%', '#{component.height}');

                // Sync changes back to hidden textarea (for form submission)
                editor.on('change', function(cm) {
                  textarea.value = cm.getValue();
                });

                // Store reference on wrapper for debugging
                wrapper._cmEditor = editor;
              }

              // Initialize immediately since script runs after DOM element exists
              initCodeEditor();

              // Register HTMX listener only once per editor ID (prevent accumulation)
              var listenerKey = 'sw-cm-' + editorId;
              if (!window[listenerKey]) {
                window[listenerKey] = true;
                document.body.addEventListener('htmx:afterSettle', function(evt) {
                  // Always reinitialize after HTMX swap (content may have changed)
                  var textarea = document.getElementById(editorId);
                  var wrapper = document.getElementById(wrapperId);
                  if (textarea && wrapper) {
                    initCodeEditor();
                  }
                });
              }
            })();
          JS
        end
      end

      private

      # Render a modal close button with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param close_only [Boolean] Whether this is the only element (adds extra class)
      # @return [void] Renders to view
      def render_modal_close_button(view, close_only: false)
        css_class = close_only ? "sw-modal-close sw-modal-close-only" : "sw-modal-close"
        view.button(
          type: "button",
          class: css_class,
          "@click" => "open = false",
          "aria-label" => "Close"
        ) { "×" }
      end

      # Build HTMX trigger string and endpoint for input components with callbacks
      #
      # @param key [Symbol] The state key for this input
      # @param options [Hash] Component options with optional :on_change, :on_blur, :debounce
      # @return [Array<String, String>] [trigger_string, endpoint]
      def build_input_triggers(key, options)
        debounce_ms = options[:debounce] || 500
        has_on_change = options[:on_change]
        has_on_blur = options[:on_blur]

        triggers = []
        triggers << "keyup changed delay:#{debounce_ms}ms" if has_on_change || !has_on_blur
        triggers << "blur" if has_on_blur
        trigger_str = triggers.join(", ")

        endpoint = (has_on_change || has_on_blur) ? url("/event/#{key}") : url("/update")

        [trigger_str, endpoint]
      end

      def render_menu_item(view, item, state)
        if item.is_a?(Components::MenuDivider)
          item.render(view, state)
        elsif item.is_a?(Components::MenuItem)
          style_class = item.style == :destructive ? "sw-menu-item-destructive" : ""
          item_id = item.instance_variable_get(:@id) || "menu_item_#{item.label.downcase.gsub(/\s+/, '_')}"

          if item.action
            # With action: use HTMX to trigger server-side action
            view.button(
              type: "button",
              class: "sw-menu-item #{style_class}",
              "hx-post" => url("/action/#{item_id}"),
              "hx-include" => input_selector,
              "hx-target" => "#app-container",
              "hx-swap" => "innerHTML scroll:false",
              "@click" => "open = false"
            ) { item.label }
          else
            # No action: just close the menu
            view.button(
              type: "button",
              class: "sw-menu-item #{style_class}",
              "@click" => "open = false"
            ) { item.label }
          end
        end
      end

      def render_stack(view, direction, component, state)
        base_class = direction == :vertical ? "sw-vstack" : "sw-hstack"
        css_classes = [base_class]
        css_classes << "sw-align-#{component.align}" if component.align
        css_classes << "sw-justify-#{component.justify}" if direction == :horizontal && component.justify
        css_classes << "sw-divider" if component.divider
        css_classes << component.options[:class] if component.options[:class]

        view.div(class: css_classes.join(" "), style: "gap: #{spacing_to_css(component.spacing)};") do
          component.children.each { |child| child.render(view, state) }
        end
      end

    end
  end
end
