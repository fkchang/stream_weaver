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
          id: "input-#{key}",  # Stable ID for HTMX focus restoration
          type: "text",
          name: key.to_s,
          value: state[key] || "",
          placeholder: options[:placeholder] || "",
          "x-model" => key.to_s,  # Alpine.js two-way binding
          "hx-post" => "/update",
          "hx-include" => input_selector,
          "hx-target" => "#app-container",
          "hx-swap" => "innerHTML scroll:false",
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
          id: "input-#{key}",  # Stable ID for HTMX focus restoration
          name: key.to_s,
          placeholder: options[:placeholder] || "",
          rows: options[:rows] || 3,
          "x-model" => key.to_s,  # Alpine.js two-way binding
          "hx-post" => "/update",
          "hx-include" => input_selector,
          "hx-target" => "#app-container",
          "hx-swap" => "innerHTML scroll:false",
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
            "hx-swap" => "innerHTML scroll:false",
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
      # @option options [String] :default Default selected value when state is nil
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_select(view, key, choices, options, state)
        # Use state value, or fall back to default option
        current_value = state[key] || options[:default]

        view.select(
          name: key.to_s,
          "x-model" => key.to_s,  # Alpine.js two-way binding
          "hx-post" => "/update",
          "hx-include" => input_selector,
          "hx-target" => "#app-container",
          "hx-swap" => "innerHTML scroll:false",
          "hx-trigger" => "change"  # Immediate update on change
        ) do
          choices.each do |choice|
            view.option(
              value: choice,
              selected: current_value == choice
            ) { choice }
          end
        end
      end

      # Render a radio button group with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this radio group
      # @param choices [Array<String>] The available choices
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_radio_group(view, key, choices, options, state)
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
                "hx-post" => "/update",
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
                "hx-post" => "/update",
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
      # @return [void] Renders to view
      def render_button(view, button_id, label, options)
        style_class = options[:style] == :secondary ? "secondary" : "primary"

        view.button(
          class: "btn btn-#{style_class}",
          "hx-post" => "/action/#{button_id}",     # HTMX POST to server
          "hx-include" => input_selector,          # Include all inputs with x-model
          "hx-target" => "#app-container",         # Replace app container
          "hx-swap" => "innerHTML scroll:false"    # Replace inner HTML, preserve scroll
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
        # Focus and scroll restoration script - preserves state across HTMX swaps
        view.script do
          view.raw(view.safe(<<~JS))
            (function() {
              let focusState = null;
              let scrollState = null;

              // Before swap: save focus and scroll state
              document.addEventListener('htmx:beforeSwap', function(e) {
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

              // After swap: restore focus and scroll state
              document.addEventListener('htmx:afterSwap', function(e) {
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
              "hx-post" => "/update",
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
            "hx-post" => "/submit",
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

    end
  end
end
