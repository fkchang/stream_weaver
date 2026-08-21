# frozen_string_literal: true

require_relative 'base'
require_relative 'static'
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
      # Document renderers with no framework behavior, shared with the Opal
      # adapter. See adapter/static.rb.
      include Static

      attr_reader :url_prefix, :mode

      HTMX_TARGET = "#app-container"
      HTMX_SWAP   = "morph:innerHTML"

      # Initialize with optional URL prefix for service mode
      # @param url_prefix [String] URL prefix for all endpoints (e.g., "/apps/abc123")
      # @param mode [Symbol] :http (default) for HTMX, :websocket for WebSocket canvas mode
      def initialize(url_prefix: "", mode: :http)
        @url_prefix = url_prefix
        @mode = mode
      end

      # Check if adapter is in WebSocket mode
      # @return [Boolean]
      def websocket_mode?
        @mode == :websocket
      end

      # Generate URL with prefix
      # @param path [String] The endpoint path (e.g., "/update")
      # @return [String] Prefixed URL (e.g., "/apps/abc123/update")
      def url(path)
        "#{@url_prefix}#{path}"
      end

      # Render a visible label above a labeled input, unless label is nil
      # (FAC-9u2: text_field/text_area/select/chip_group all accepted a
      # label: option but silently dropped it -- only date_field rendered
      # it). Wraps the field so label + input stack; when no label is given,
      # yields directly with no extra markup (byte-for-byte unchanged).
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param label [String, nil]
      # @param for_id [String, nil] The input's id, for the label's `for` attribute
      # @yield Renders the input/textarea/select itself
      def wrap_with_label(view, label, for_id = nil)
        return yield unless label

        view.div(class: "sw-field") do
          view.label(class: "sw-field__label", **(for_id ? { for: for_id } : {})) { label }
          yield
        end
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
        scope_name = options[:scope_name]
        should_submit = options.fetch(:submit, true)
        input_id = if form_context
          "input-#{form_context[:name]}-#{key}"
        elsif scope_name
          "input-#{scope_name}-#{key}"
        else
          "input-#{key}"
        end

        wrap_with_label(view, options[:label], input_id) do
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
          elsif scope_name
            # Inside a bare `scope` block (not `form`): nested name/x-model so a
            # "live" field's HTMX submit lands in state[scope_name][key], not a
            # same-named flat top-level key (FAC-P3.1 handoff, form-for.md).
            scope_state = state[scope_name] || {}
            trigger_str, endpoint = build_input_triggers(key, options)
            view.input(
              id: "input-#{scope_name}-#{key}",
              type: "text",
              name: "#{scope_name}[#{key}]",
              value: scope_state[key] || "",
              placeholder: options[:placeholder] || "",
              "x-model" => "#{scope_name}.#{key}",
              **(should_submit ? htmx_attrs(endpoint, view: view, loading: options.fetch(:loading, true), "hx-trigger" => trigger_str) : {})
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
              **htmx_attrs(endpoint, view: view, loading: options.fetch(:loading, true), "hx-trigger" => trigger_str)
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
        scope_name = options[:scope_name]
        should_submit = options.fetch(:submit, true)
        input_id = if form_context
          "input-#{form_context[:name]}-#{key}"
        elsif scope_name
          "input-#{scope_name}-#{key}"
        else
          "input-#{key}"
        end

        wrap_with_label(view, options[:label], input_id) do
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
          elsif scope_name
            # Inside a bare `scope` block: nested name/x-model (FAC-P3.1 handoff).
            scope_state = state[scope_name] || {}
            trigger_str, endpoint = build_input_triggers(key, options)
            view.textarea(
              id: "input-#{scope_name}-#{key}",
              name: "#{scope_name}[#{key}]",
              placeholder: options[:placeholder] || "",
              rows: options[:rows] || 3,
              "x-model" => "#{scope_name}.#{key}",
              **(should_submit ? htmx_attrs(endpoint, view: view, loading: options.fetch(:loading, true), "hx-trigger" => trigger_str) : {})
            ) { scope_state[key] || "" }
          elsif should_submit
            trigger_str, endpoint = build_input_triggers(key, options)

            view.textarea(
              id: "input-#{key}",
              name: key.to_s,
              placeholder: options[:placeholder] || "",
              rows: options[:rows] || 3,
              "x-model" => key.to_s,
              **htmx_attrs(endpoint, view: view, loading: options.fetch(:loading, true), "hx-trigger" => trigger_str)
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
      end

      # Render a native date input with Alpine.js binding
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param key [Symbol] The state key for this input
      # @param options [Hash] Component options
      # @option options [String] :label Optional label rendered above the input
      # @option options [String] :min Minimum selectable date (ISO 8601)
      # @option options [String] :max Maximum selectable date (ISO 8601)
      # @option options [Hash] :form_context Form context if inside a form block
      # @option options [Symbol] :scope_name Scope name if inside a scope block
      # @option options [Boolean] :submit Whether to auto-submit on change (default: true)
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_date_field(view, key, options, state)
        inject_date_field_css(view)
        form_context = options[:form_context]
        scope_name = options[:scope_name]
        should_submit = options.fetch(:submit, true)
        input_id = if form_context
          "input-#{form_context[:name]}-#{key}"
        elsif scope_name
          "input-#{scope_name}-#{key}"
        else
          "input-#{key}"
        end
        bounds = { min: options[:min], max: options[:max] }.compact

        wrap_with_label(view, options[:label], input_id) do
          if form_context
            # Inside form: use form-scoped x-model, no HTMX
            form_name = form_context[:name]
            form_state = state[form_name] || {}
            view.input(
              id: "input-#{form_name}-#{key}",
              type: "date",
              name: "#{form_name}[#{key}]",  # Rails-style nested params
              value: form_state[key] || "",
              class: "sw-date-input",
              "x-model" => "_form.#{key}",  # Form-local Alpine scope
              **bounds
            )
          elsif scope_name
            # Inside a bare `scope` block (not `form`): nested name/x-model so a
            # "live" field's HTMX submit lands in state[scope_name][key], not a
            # same-named flat top-level key (FAC-P3.1 handoff, form-for.md).
            scope_state = state[scope_name] || {}
            trigger_str, endpoint = date_field_triggers(key, options)
            view.input(
              id: "input-#{scope_name}-#{key}",
              type: "date",
              name: "#{scope_name}[#{key}]",
              value: scope_state[key] || "",
              class: "sw-date-input",
              "x-model" => "#{scope_name}.#{key}",
              **bounds,
              **(should_submit ? htmx_attrs(endpoint, view: view, loading: options.fetch(:loading, true), "hx-trigger" => trigger_str) : {})
            )
          elsif should_submit
            trigger_str, endpoint = date_field_triggers(key, options)
            view.input(
              id: "input-#{key}",
              type: "date",
              name: key.to_s,
              value: state[key] || "",
              class: "sw-date-input",
              "x-model" => key.to_s,
              **bounds,
              **htmx_attrs(endpoint, view: view, loading: options.fetch(:loading, true), "hx-trigger" => trigger_str)
            )
          else
            # No auto-submit: just Alpine.js binding, no HTMX
            view.input(
              id: "input-#{key}",
              type: "date",
              name: key.to_s,
              value: state[key] || "",
              class: "sw-date-input",
              "x-model" => key.to_s,
              **bounds
            )
          end
        end
      end

      # build_input_triggers plus a debounced "change" trigger: a calendar
      # picker selection fires change, not keyup, and typing into the native
      # date input's MM/DD/YYYY segments fires change repeatedly with a blank
      # value until all segments are filled -- "changed delay" collapses that
      # burst to one settled submit instead of spamming on_change with "".
      #
      # @param key [Symbol] The state key for this input
      # @param options [Hash] Component options with optional :on_change, :on_blur, :debounce
      # @return [Array<String, String>] [trigger_string, endpoint]
      def date_field_triggers(key, options)
        trigger_str, endpoint = build_input_triggers(key, options)
        debounce_ms = options[:debounce] || 500
        ["#{trigger_str}, change changed delay:#{debounce_ms}ms", endpoint]
      end

      # Render literal text (no markdown parsing), optionally with a visual
      # tone class (03 honorable mention: muted/caption/error/success text
      # variants that apps hand-coded as raw hex/padding divs).
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param content [String] Already-resolved text content
      # @param tone [Symbol, nil] :muted, :caption, :error, :success, or nil
      # @param options [Hash] :class/:style passthrough (stream_weaver-1lo)
      # @return [void] Renders to view

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
        scope_name = options[:scope_name]
        should_submit = options.fetch(:submit, true)
        parsed_label = parse_inline_markdown(label)

        if form_context
          # Inside form: use form-scoped x-model, no HTMX
          form_name = form_context[:name]
          form_state = state[form_name] || {}
          view.div(class: "checkbox-wrapper") do
            view.input(
              type: "checkbox",
              id: "checkbox_#{form_name}_#{key}",
              name: "#{form_name}[#{key}]",
              value: "true",
              checked: form_state[key],
              "x-model" => "_form.#{key}"  # Form-local Alpine scope
            )
            view.label(for: "checkbox_#{form_name}_#{key}") do
              view.raw view.safe(parsed_label)
            end
          end
        elsif scope_name
          # Inside a bare `scope` block: nested name/x-model (FAC-P3.1 handoff).
          scope_state = state[scope_name] || {}
          has_on_change = options[:on_change]
          endpoint = has_on_change ? url("/event/#{key}") : url("/update")
          view.div(class: "checkbox-wrapper") do
            view.input(
              type: "checkbox",
              id: "checkbox_#{scope_name}_#{key}",
              name: "#{scope_name}[#{key}]",
              value: "true",
              checked: scope_state[key],
              "x-model" => "#{scope_name}.#{key}",
              **(should_submit ? htmx_attrs(endpoint, view: view, loading: options.fetch(:loading, true), "hx-trigger" => "change") : {})
            )
            view.label(for: "checkbox_#{scope_name}_#{key}") do
              view.raw view.safe(parsed_label)
            end
          end
        elsif should_submit
          # Use /event endpoint if there's a callback
          has_on_change = options[:on_change]
          endpoint = has_on_change ? url("/event/#{key}") : url("/update")

          view.div(class: "checkbox-wrapper") do
            view.input(
              type: "checkbox",
              id: "checkbox_#{key}",
              name: key.to_s,
              value: "true",
              checked: state[key],
              "x-model" => key.to_s,
              **htmx_attrs(endpoint, view: view, loading: options.fetch(:loading, true), "hx-trigger" => "change")
            )
            view.label(for: "checkbox_#{key}") do
              view.raw view.safe(parsed_label)
            end
          end
        else
          # No auto-submit: just Alpine.js binding, no HTMX
          view.div(class: "checkbox-wrapper") do
            view.input(
              type: "checkbox",
              id: "checkbox_#{key}",
              name: key.to_s,
              value: "true",
              checked: state[key],
              "x-model" => key.to_s
            )
            view.label(for: "checkbox_#{key}") do
              view.raw view.safe(parsed_label)
            end
          end
        end
      end

      # Parse inline markdown (bold, italic, code, links) for use in labels
      # @param text [String] Text with markdown formatting
      # @return [String] HTML string with parsed formatting
      def parse_inline_markdown(text)
        return text.to_s if text.nil?

        result = text.to_s.dup
        # Bold: **text** or __text__
        result.gsub!(/\*\*(.+?)\*\*/) { "<strong>#{$1}</strong>" }
        result.gsub!(/__(.+?)__/) { "<strong>#{$1}</strong>" }
        # Italic: *text* or _text_
        result.gsub!(/\*(.+?)\*/) { "<em>#{$1}</em>" }
        result.gsub!(/_(.+?)_/) { "<em>#{$1}</em>" }
        # Code: `text`
        result.gsub!(/`(.+?)`/) { "<code>#{$1}</code>" }
        result
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
        scope_name = options[:scope_name]
        should_submit = options.fetch(:submit, true)
        select_id = "select-#{key}"

        wrap_with_label(view, options[:label], select_id) do
          if form_context
            # Inside form: use form-scoped x-model, no HTMX
            form_name = form_context[:name]
            form_state = state[form_name] || {}
            current_value = form_state[key] || options[:default]

            view.select(
              id: select_id,
              name: "#{form_name}[#{key}]",  # Rails-style nested params
              "x-model" => "_form.#{key}",   # Form-local Alpine scope
              autocomplete: "off",
              "x-init" => "$el.value = _form.#{key}"
            ) do
              choices.each do |choice|
                option_label, value = choice.is_a?(Array) ? choice : [choice, choice]
                view.option(
                  value: value,
                  selected: current_value == value
                ) { option_label }
              end
            end
          elsif scope_name
            # Inside a bare `scope` block: nested name/x-model (FAC-P3.1 handoff).
            scope_state = state[scope_name] || {}
            has_on_change = options[:on_change]
            endpoint = has_on_change ? url("/event/#{key}") : url("/update")
            current_value = scope_state[key] || options[:default]

            view.select(
              id: select_id,
              name: "#{scope_name}[#{key}]",
              "x-model" => "#{scope_name}.#{key}",
              autocomplete: "off",
              "x-init" => "$el.value = #{scope_name}.#{key}",
              **(should_submit ? htmx_attrs(endpoint, view: view, loading: options.fetch(:loading, true), "hx-trigger" => "change") : {})
            ) do
              choices.each do |choice|
                option_label, value = choice.is_a?(Array) ? choice : [choice, choice]
                view.option(
                  value: value,
                  selected: current_value == value
                ) { option_label }
              end
            end
          elsif should_submit
            # Use /event endpoint if there's a callback
            has_on_change = options[:on_change]
            endpoint = has_on_change ? url("/event/#{key}") : url("/update")
            current_value = state[key] || options[:default]

            view.select(
              id: select_id,
              name: key.to_s,
              "x-model" => key.to_s,
              autocomplete: "off",
              **htmx_attrs(endpoint, view: view, loading: options.fetch(:loading, true), "hx-trigger" => "change")
            ) do
              choices.each do |choice|
                option_label, value = choice.is_a?(Array) ? choice : [choice, choice]
                view.option(
                  value: value,
                  selected: current_value == value
                ) { option_label }
              end
            end
          else
            # No auto-submit: just Alpine.js binding, no HTMX
            current_value = state[key] || options[:default]

            view.select(
              id: select_id,
              name: key.to_s,
              "x-model" => key.to_s,
              autocomplete: "off",
              "x-init" => "$el.value = #{key}"
            ) do
              choices.each do |choice|
                option_label, value = choice.is_a?(Array) ? choice : [choice, choice]
                view.option(
                  value: value,
                  selected: current_value == value
                ) { option_label }
              end
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
        elsif websocket_mode?
          # WebSocket mode: use @change to send via WebSocket
          current_value = state[key]

          view.div(class: "radio-group") do
            choices.each do |choice|
              view.label(class: "radio-option") do
                view.input(
                  type: "radio",
                  name: key.to_s,
                  value: choice,
                  checked: current_value == choice,
                  "x-model" => key.to_s,
                  "@change" => "sendEvent('change', {field: '#{key}', value: '#{choice}', state: getFormState()})"
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
                  "x-model" => key.to_s,
                  **htmx_attrs(url("/update"), "hx-trigger" => "change")
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
                "x-model" => key.to_s,
                **htmx_attrs(url("/update"), "hx-trigger" => "change")
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
        view.button(**button_attrs(view, button_id, options, modal_context)) { label }
      end

      private

      def button_attrs(view, button_id, options, modal_context)
        action_target = options[:action_token] || button_id
        loading = options.fetch(:submit, true) && options.fetch(:loading, true) && loading_indicators_enabled?(view)
        style = button_style_attrs(options, loading)

        unless options.fetch(:submit, true)
          return style.merge(type: "button")
        end

        if websocket_mode?
          # Disable on click; page morph from server response replaces the element, clearing disabled
          style.merge("@click" => "$el.disabled=true; sendEvent('action', {button: '#{action_target}', state: getFormState()})")
        elsif modal_context
          # Closing must never happen before HTMX collects hx-include values --
          # doing so on before-request drops every field the modal is meant to
          # submit (stream_weaver-ho5). Instead, after the response has swapped
          # in, read the modal wrapper's fresh data-sw-open attribute (morph
          # keeps that in sync even though it leaves the `open` reactive value
          # alone) and apply it -- this naturally keeps the modal open on a
          # validation failure that re-renders it with editing state intact.
          htmx_attrs(url("/action/#{action_target}"), view: view, loading: loading, indicator: "##{button_id}",
            sw_updates: options[:updates], sw_primary: options[:primary],
            "hx-disabled-elt" => "this",
            "hx-on::after-request" => "var m=this.closest('.sw-modal-wrapper'); if(m) open=(m.dataset.swOpen==='true')").merge(id: button_id).merge(style)
        else
          htmx_attrs(url("/action/#{action_target}"), view: view, loading: loading, indicator: "##{button_id}",
            sw_updates: options[:updates], sw_primary: options[:primary], "hx-disabled-elt" => "this").merge(id: button_id).merge(style)
        end
      end

      # @option options [Symbol] :size Button size -- :md (default) or :sm (compact,
      #   used by table action cells; rivet grammar -- small quiet inline actions)
      # @option options [Symbol] :variant Button chrome -- :quiet or :outline, composes
      #   with :style (which still picks the color intent)
      def button_style_attrs(options, loading = true)
        style_option = options[:style]
        attrs = if style_option == :none || style_option.is_a?(String)
          { class: ["sw-button", options[:class]].compact.join(" "), style: (style_option if style_option.is_a?(String)) }.compact
        else
          style_class = style_option == :secondary ? "secondary" : "primary"
          # "btn"/"btn-primary" etc. are the legacy, unprefixed hooks (still
          # emitted for back-compat -- deprecated, removed at 1.0);
          # "sw-button" is the documented stable hook (stream_weaver-oeo /
          # stream_weaver-lyb). No CSS rule targets sw-button itself --
          # styling stays keyed off .btn* so style: :none's "no framework
          # look" contract is unaffected by this identifying hook.
          classes = ["sw-button", "btn", "btn-#{style_class}"]
          classes << "btn-#{options[:variant]}" if %i[quiet outline].include?(options[:variant])
          classes << "btn-sm" if options[:size] == :sm
          classes << options[:class] if options[:class]
          { class: classes.join(" ") }
        end
        attrs[:class] = [attrs[:class], "sw-no-loading-indicator"].compact.join(" ") unless loading
        attrs
      end

      public

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

        if websocket_mode?
          # Add WebSocket-related data for canvas mode
          state_data['wsConnected'] = false
          state_data['wsReconnecting'] = false
        end

        { "x-data" => JSON.generate(state_data), "hx-ext" => "alpine-morph" }
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
        scripts = [
          '<script src="https://unpkg.com/htmx.org@2.0.4"></script>',
          '<script src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js" defer></script>'
        ]

        if websocket_mode?
          scripts << websocket_init_script
        end

        scripts
      end

      # Generate WebSocket initialization script for canvas mode
      # @return [String] Script tag with WebSocket setup
      def websocket_init_script
        <<~HTML
          <script>
            // StreamWeaver Canvas WebSocket
            (function() {
              let ws = null;
              let reconnectAttempts = 0;
              const maxReconnectAttempts = 5;

              function connect() {
                const wsUrl = 'ws://' + window.location.host + '#{@url_prefix}/ws';
                ws = new WebSocket(wsUrl);

                ws.onopen = function() {
                  console.log('StreamWeaver Canvas connected');
                  reconnectAttempts = 0;
                  if (typeof Alpine !== 'undefined') {
                    const container = document.getElementById('app-container');
                    if (container) {
                      const data = Alpine.$data(container);
                      if (data) {
                        data.wsConnected = true;
                        data.wsReconnecting = false;
                      }
                    }
                  }
                };

                ws.onmessage = function(event) {
                  const msg = JSON.parse(event.data);
                  if (msg.type === 'update' && msg.html) {
                    const container = document.getElementById('app-container');
                    if (container) container.innerHTML = msg.html;
                    // Clear any existing toast when content updates
                    const existingToast = document.getElementById('sw-toast-overlay');
                    if (existingToast) existingToast.remove();
                  } else if (msg.type === 'toast') {
                    showToast(msg.message, msg.variant, msg.duration);
                  } else if (msg.type === 'closed') {
                    const _cc = document.getElementById('app-container');
                    if (_cc) _cc.innerHTML = '<div style="text-align:center;padding:60px;color:#374151;"><div style="font-size:3rem;margin-bottom:16px;">✓</div><h2 style="margin:0 0 12px">Session Complete</h2><p style="color:#666;margin:0">This StreamWeaver canvas session has closed.</p></div>';
                    ws.close();
                  }
                };

                ws.onclose = function() {
                  console.log('StreamWeaver Canvas disconnected');
                  if (typeof Alpine !== 'undefined') {
                    const container = document.getElementById('app-container');
                    if (container) {
                      const data = Alpine.$data(container);
                      if (data) data.wsConnected = false;
                    }
                  }
                  // Attempt reconnect
                  if (reconnectAttempts < maxReconnectAttempts) {
                    reconnectAttempts++;
                    setTimeout(connect, 1000 * reconnectAttempts);
                  }
                };
              }

              // Global functions for components
              window.sendEvent = function(type, data) {
                const payload = JSON.stringify({ type: type, ...data });
                const dl = window._dbgLog || function(){};

                function showFeedback() {
                  if (type !== 'action') return;

                  // Guard: don't clobber content from a newer version.
                  // If the poll already rendered a newer push, skip feedback.
                  const clickVersion = window._swContentVersion || 0;
                  if (window._swFeedbackActive) {
                    dl('FEEDBACK skip: already active');
                    return;
                  }

                  const container = document.getElementById('app-container');
                  if (!container) return;

                  const continueMarker = document.getElementById('sw-canvas-continue');
                  dl('FEEDBACK v=' + clickVersion + ' marker=' + (continueMarker ? continueMarker.getAttribute('data-continue-message') : 'null'));

                  if (continueMarker) {
                    const message = continueMarker.getAttribute('data-continue-message') || 'Processing...';
                    window._swFeedbackActive = true;
                    container.innerHTML = '<div style="text-align:center;padding:40px;"><div class="sw-spinner" style="margin:0 auto 20px;width:40px;height:40px;border:3px solid #e5e7eb;border-top-color:#6366f1;border-radius:50%;animation:sw-spin 0.8s linear infinite;"></div><p style="color:#666;">' + message + '</p></div>';
                  } else {
                    container.innerHTML = '<div style="text-align:center;padding:40px;"><h2 style="color:#10b981;">✓ Submitted</h2><p style="color:#666;">You can close this window.</p></div>';
                  }
                }

                dl('EVENT type=' + type + ' btn=' + (data && data.button || '-'));
                if (ws && ws.readyState === WebSocket.OPEN) {
                  ws.send(payload);
                  showFeedback();
                } else {
                  // Show feedback immediately, then send event.
                  showFeedback();
                  fetch('#{@url_prefix}/event', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: payload
                  }).catch(err => console.error('HTTP event error:', err));
                }
              };

              window.getFormState = function() {
                const state = {};
                document.querySelectorAll('[x-model]').forEach(el => {
                  const key = el.getAttribute('x-model');
                  if (el.type === 'checkbox') {
                    state[key] = el.checked;
                  } else if (el.type === 'radio') {
                    if (el.checked) state[key] = el.value;
                  } else {
                    state[key] = el.value;
                  }
                });
                return state;
              };

              // Show toast overlay (doesn't replace main content)
              window.showToast = function(message, variant, duration) {
                // Remove existing toast if any
                const existing = document.getElementById('sw-toast-overlay');
                if (existing) existing.remove();

                // Color based on variant
                const colors = {
                  info: { bg: '#3b82f6', border: '#2563eb' },
                  success: { bg: '#10b981', border: '#059669' },
                  warning: { bg: '#f59e0b', border: '#d97706' },
                  error: { bg: '#ef4444', border: '#dc2626' }
                };
                const color = colors[variant] || colors.warning;

                // Create toast element
                const toast = document.createElement('div');
                toast.id = 'sw-toast-overlay';
                toast.innerHTML = `
                  <div style="
                    position: fixed;
                    top: 20px;
                    left: 50%;
                    transform: translateX(-50%);
                    background: ${color.bg};
                    color: white;
                    padding: 16px 24px;
                    border-radius: 8px;
                    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
                    border: 2px solid ${color.border};
                    z-index: 10000;
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    font-family: system-ui, -apple-system, sans-serif;
                    font-size: 14px;
                    font-weight: 500;
                    animation: sw-toast-in 0.3s ease-out;
                  ">
                    <div class="sw-spinner" style="width:20px;height:20px;border:2px solid rgba(255,255,255,0.3);border-top-color:white;border-radius:50%;animation:sw-spin 0.8s linear infinite;"></div>
                    <span>${message}</span>
                  </div>
                `;
                document.body.appendChild(toast);

                // Auto-dismiss if duration > 0
                if (duration && duration > 0) {
                  setTimeout(() => {
                    const el = document.getElementById('sw-toast-overlay');
                    if (el) el.remove();
                  }, duration);
                }
              };

              // Connect when DOM is ready
              if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', connect);
              } else {
                connect();
              }
            })();
          </script>
        HTML
      end

      # Render CDN scripts for Alpine.js and HTMX using Phlex methods
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @return [void] Renders script tags to the view
      def render_cdn_scripts(view)
        # CDN load order: htmx → Alpine morph plugin → HTMX alpine-morph extension → Alpine core
        # Plugins must load before Alpine core; Alpine must have defer:true
        view.script(src: "https://unpkg.com/htmx.org@2.0.4")
        view.script(src: "https://cdn.jsdelivr.net/npm/@alpinejs/morph@3.x.x/dist/cdn.min.js")
        view.script(src: "https://cdn.jsdelivr.net/npm/htmx-ext-alpine-morph@2.0.0/alpine-morph.js")
        view.script(src: "https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js", defer: true)
        # Focus and scroll restoration script
        # alpine-morph handles state preservation natively via DOM morphing,
        # but has documented issues with input focus, so we save/restore manually.
        view.script do
          view.raw(view.safe(<<~JS))
            (function() {
              let focusState = null;
              let scrollState = null;

              // =============================================================
              // Focus & Scroll Restoration for HTMX + Alpine Morph
              // =============================================================
              // alpine-morph (via hx-swap="morph:innerHTML") preserves Alpine
              // state natively by morphing the DOM instead of replacing it.
              // However, input focus and scroll position can still be lost
              // during morphing, so we save and restore them manually.
              //
              // References:
              // - https://alpinejs.dev/plugins/morph
              // - https://github.com/bigskysoftware/htmx-extensions/tree/main/ext/alpine-morph
              // =============================================================

              // Before swap: save focus/scroll state + freeze viewport to prevent flash,
              // and sync Alpine reactive data from the server response.
              //
              // The data sync MUST happen here, before the swap, not in
              // afterSettle: alpine-morph initializes newly-morphed-in elements
              // (evaluating their x-model/x-bind/x-text directives) as part of
              // the swap itself, which runs after this event but before
              // afterSettle. A field that becomes visible for the first time in
              // this response (e.g. a modal's fields, seeded server-side by the
              // action that opened it) references a state key the client's
              // Alpine store has never held -- if the store isn't updated until
              // afterSettle, Alpine throws "ReferenceError: <key> is not
              // defined" while initializing that element, before the sync code
              // ever runs (stream_weaver-ho5).
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

                // Freeze viewport to prevent visual flash during morph.
                // Without this, the browser may paint at scroll=0 for one frame
                // before afterSettle restores the position.
                var container = document.getElementById('app-container');
                if (container) {
                  container.style.minHeight = container.offsetHeight + 'px';
                }

                // Parse the incoming response (not yet in the live DOM) so we
                // can read #sw-state-data / #sw-state-patch and merge them into
                // Alpine's reactive store before the morph inserts any element
                // that binds to those keys. A <template> keeps embedded
                // <script> tags inert while still queryable.
                var raw = e.detail && e.detail.serverResponse;
                if (!container || typeof raw !== 'string') return;
                var data = Alpine.$data(container);
                if (!data) return;
                var incoming = document.createElement('template');
                incoming.innerHTML = raw;

                // Full state snapshot (plain `/update` responses).
                var stateEl = incoming.content.getElementById('sw-state-data');
                if (stateEl) {
                  try {
                    var fresh = JSON.parse(stateEl.textContent);
                    var transientKeys = new Set(fresh._transient || []);
                    if (typeof fresh._sw_version === 'number') {
                      window.StreamWeaverStateVersion = fresh._sw_version;
                    }
                    Object.keys(fresh).forEach(function(k) {
                      if (k === '_transient' || k === '_sw_version') return;
                      if (transientKeys.has(k)) return;
                      if (data[k] !== fresh[k]) data[k] = fresh[k];
                    });
                  } catch(err) {}
                }

                // Scoped swaps carry a versioned top-level patch instead of a
                // full state snapshot. Deletions are authoritative; nested
                // changed values arrive whole in `set`.
                var patchEl = incoming.content.getElementById('sw-state-patch');
                if (patchEl) {
                  try {
                    var patch = JSON.parse(patchEl.textContent);
                    var currentVersion = window.StreamWeaverStateVersion;
                    if (typeof currentVersion !== 'number') {
                      currentVersion = Number(container.dataset.swStateVersion || 0);
                    }
                    if (typeof patch.version !== 'number' || patch.version !== currentVersion + 1) {
                      window.location.reload();
                      return;
                    }
                    Object.keys(patch.set || {}).forEach(function(k) { data[k] = patch.set[k]; });
                    (patch.delete || []).forEach(function(k) { delete data[k]; });
                    window.StreamWeaverStateVersion = patch.version;
                  } catch(err) {
                    window.location.reload();
                  }
                }
              });

              // After settle: restore focus and scroll, unfreeze viewport, and
              // remove the now-morphed-in #sw-state-patch node (its data was
              // already applied pre-swap; #sw-state-data stays -- morph updates
              // it in place by id on every response instead of duplicating it).
              document.addEventListener('htmx:afterSettle', function(e) {
                // Restore focus. A live field (e.g. a debounced search input)
                // re-triggers this on every keystroke; wrapped in try/catch so
                // a focus/selection failure (stream_weaver-tv4: e.g. a stale
                // selectionStart past the new value's length) can never abort
                // the rest of this listener -- scroll restore and viewport
                // unfreeze below must still run even if this does not.
                if (focusState && focusState.id) {
                  try {
                    const el = document.getElementById(focusState.id);
                    if (el) {
                      el.focus();
                      if (typeof el.setSelectionRange === 'function' && focusState.selectionStart !== null) {
                        el.setSelectionRange(focusState.selectionStart, focusState.selectionEnd);
                      }
                    }
                  } catch(err) {}
                  focusState = null;
                }

                // Restore scroll position
                if (scrollState) {
                  window.scrollTo(scrollState.x, scrollState.y);
                  scrollState = null;
                }

                // Unfreeze viewport height
                var container = document.getElementById('app-container');
                if (container) {
                  container.style.minHeight = '';
                }

                var patchEl = document.getElementById('sw-state-patch');
                if (patchEl) patchEl.remove();
              });
            })();
          JS
        end
      end

      # Render SSE client script for streaming push updates.
      # Connects to GET /stream and applies targeted DOM updates.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @return [void] Renders script tag to the view
      def render_sse_client(view)
        view.script do
          view.raw(view.safe(<<~JS))
            (function() {
              var source = new EventSource('/stream');
              source.onmessage = function(e) {
                var msg = JSON.parse(e.data);
                if (msg.type === 'connected') return;
                var el = document.querySelector(msg.target);
                if (!el) return;
                switch(msg.action) {
                  case 'replace':
                    var _focusedId = document.activeElement ? document.activeElement.id : null;
                    var _focusSel = (_focusedId && document.activeElement.selectionStart !== undefined)
                      ? [document.activeElement.selectionStart, document.activeElement.selectionEnd]
                      : null;
                    var _inputVals = {};
                    el.querySelectorAll('input[id], textarea[id]').forEach(function(inp) {
                      _inputVals[inp.id] = inp.value;
                    });
                    el.innerHTML = msg.html;
                    el.querySelectorAll('input[id], textarea[id]').forEach(function(inp) {
                      if (_inputVals[inp.id] !== undefined) inp.value = _inputVals[inp.id];
                    });
                    if (_focusedId) {
                      var fe = document.getElementById(_focusedId);
                      if (fe) {
                        fe.focus();
                        if (_focusSel && typeof fe.setSelectionRange === 'function') {
                          fe.setSelectionRange(_focusSel[0], _focusSel[1]);
                        }
                      }
                    }
                    break;
                  case 'append':       el.insertAdjacentHTML('beforeend', msg.html); break;
                  case 'prepend':      el.insertAdjacentHTML('afterbegin', msg.html); break;
                  case 'remove':       el.remove(); break;
                  case 'add_class':    el.classList.add(msg.value); break;
                  case 'remove_class': el.classList.remove(msg.value); break;
                }
              };
            })();
          JS
        end
      end

      # URL routing: handle browser back/forward via popstate
      def render_routing_scripts(view)
        view.script do
          view.raw(view.safe(<<~JS))
            window.addEventListener('popstate', function(e) {
              htmx.ajax('GET', window.location.pathname, {
                target: '#{HTMX_TARGET}', swap: 'morph:innerHTML'
              });
            });
          JS
        end
      end

      # Get the CSS selector for Alpine.js bound inputs
      #
      # @return [String] CSS selector "[x-model]"
      def input_selector
        "[x-model]"  # Alpine.js selector for all bound inputs
      end

      # Standard HTMX attributes for server interactions
      #
      # @param post_url [String] The POST endpoint
      # @param view [Phlex::HTML, nil] The current view, used to check the app-level
      #   `loading_indicators:` option (FAC-P1.5). Pass whenever the caller has one.
      # @param loading [Boolean] Component-level opt-out (`loading: false`) -- when
      #   false, no `hx-indicator` is emitted for this element at all (FAC-P1.5)
      # @param indicator [String, nil] Extra CSS selector (typically `"##{element_id}"`)
      #   added alongside the swap target. htmx's `hx-indicator`, when present, REPLACES
      #   its default self-targeting rather than adding to it -- so any element with its
      #   own `.htmx-request`-keyed CSS (e.g. the button spinner) must list its own id
      #   here or lose that styling once `hx-indicator` is set.
      # @param overrides [Hash] Any attribute overrides
      # @return [Hash] HTMX attribute hash
      def htmx_attrs(post_url, view: nil, loading: true, indicator: nil, **overrides)
        fragment_updates = Array(overrides.delete(:sw_updates)).compact.map(&:to_s)
        fragment_primary = overrides.delete(:sw_primary)
        fragment_id = view.current_fragment_id if view&.respond_to?(:current_fragment_id)
        target = fragment_id ? "##{fragment_id}" : HTMX_TARGET
        named_action_scope = begin
          candidate = post_url.to_s[%r{/action/([^?]+)}, 1]
          candidate && ActionToken.decode(candidate)[:f]
        rescue ActionToken::Invalid
          nil
        end
        if fragment_id && !named_action_scope && !post_url.to_s.include?("_sw_fragment=")
          separator = post_url.to_s.include?("?") ? "&" : "?"
          fragment_payload = { f: fragment_id }
          fragment_payload[:u] = fragment_updates unless fragment_updates.empty?
          fragment_payload[:p] = fragment_primary.to_s if fragment_primary
          signed_fragment = ActionToken.encode(fragment_payload)
          post_url = "#{post_url}#{separator}_sw_fragment=#{CGI.escape(signed_fragment)}"
        end
        attrs = {
          "hx-post" => post_url,
          "hx-include" => input_selector,
          "hx-target" => target,
          "hx-swap" => HTMX_SWAP
        }
        if loading && loading_indicators_enabled?(view)
          attrs["hx-indicator"] = [indicator, target].compact.join(", ")
        end
        attrs.merge(overrides)
      end

      # App-level `loading_indicators: false` opt-out check (FAC-P1.5). Fails open
      # (true) when the view/app aren't available, e.g. bare test doubles.
      #
      # @param view [Phlex::HTML, nil]
      # @return [Boolean]
      def loading_indicators_enabled?(view)
        return true unless view.respond_to?(:app)
        app = view.app
        return true unless app.respond_to?(:loading_indicators)
        app.loading_indicators != false
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
      # @param component [Components::Collapsible] The collapsible component
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_collapsible(view, component, state)
        subtitle = component.subtitle
        badge_text = component.badge_text
        badge_variant = component.badge_variant

        outer_classes = ["collapsible", "sw-collapsible"]
        outer_classes << component.options[:class] if component.options[:class]
        outer_attrs = { class: outer_classes.join(" "), "x-data" => "{ open: #{component.expanded} }" }
        outer_attrs[:style] = component.options[:style] if component.options[:style]

        view.div(**outer_attrs) do
          view.div(class: "collapsible-header sw-collapsible-header", "@click" => "open = !open") do
            view.span(class: "collapsible-icon sw-collapsible-icon", "x-text" => "open ? '▼' : '▶'")
            view.span(class: "collapsible-label sw-collapsible-label") { component.label }
            if subtitle
              view.span(class: "sw-collapsible-subtitle") { subtitle }
            end
            if badge_text
              view.span(class: "sw-collapsible-badge") do
                badge = Components::Badge.new(badge_text, variant: badge_variant)
                render_badge(view, badge, state)
              end
            end
          end
          view.div(class: "collapsible-content sw-collapsible-content", "x-show" => "open", "x-cloak" => true) do
            component.children.each { |child| child.render(view, state) }
          end
        end
      end

      # Render an accordion -- a plain wrapper around native <details> sections.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param children [Array<Components::AccordionSection>] The sections
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_accordion(view, children, options, state)
        inject_accordion_css(view)

        view.div(class: "sw-accordion") do
          children.each { |section| section.render(view, state) }
        end
      end

      # Render a single accordion section as native <details>/<summary> --
      # expand/collapse is handled entirely by the browser, no JS required.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::AccordionSection]
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_accordion_section(view, component, state)
        attrs = { class: "sw-accordion__section" }
        attrs[:open] = true if component.open

        view.details(**attrs) do
          view.summary(class: "sw-accordion__summary") { component.title }
          view.div(class: "sw-accordion__body") do
            component.children.each { |child| child.render(view, state) }
          end
        end
      end

      # Render a static Kanban board -- a row of Lane columns.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param children [Array<Components::Lane>] The lanes
      # @param options [Hash] Component options
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_board(view, children, options, state)
        inject_board_css(view)

        pinned_headers = options[:pinned_headers]
        css_classes = ["sw-board"]
        css_classes << "sw-board--pinned-headers" if pinned_headers
        css_classes << options[:class] if options[:class]
        style = [options[:style]].compact.join(" ")
        attrs = { class: css_classes.join(" ") }
        attrs["data-sw-pinned-headers"] = "true" if pinned_headers
        attrs[:style] = style unless style.empty?

        view.div(**attrs) do
          children.each { |lane| lane.render(view, state) }
        end
      end

      # Render a single board lane (column): header (title + optional
      # subtitle + auto card count, tinted by tone:) + stacked cards.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::Lane]
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_lane(view, component, state)
        header_classes = ["sw-board__lane-header"]
        header_classes << "sw-board__lane-header--#{component.tone}" if component.tone

        lane_classes = ["sw-board__lane"]
        lane_classes << component.options[:class] if component.options[:class]
        attrs = { class: lane_classes.join(" ") }
        attrs[:style] = component.options[:style] if component.options[:style]

        view.div(**attrs) do
          view.div(class: header_classes.join(" ")) do
            render_icon_hook(view, component.icon, "sw-board__lane-icon") if component.icon
            view.div(class: "sw-board__lane-heading") do
              view.div(class: "sw-board__lane-title") { component.title }
              view.div(class: "sw-board__lane-subtitle") { component.subtitle } if component.subtitle
            end
            view.div(class: "sw-board__lane-count") { component.count.to_s }
          end
          view.div(class: "sw-board__lane-body") do
            component.children.each { |child| child.render(view, state) }
          end
        end
      end

      # Renders an icon/glyph slot shared by Lane and Topbar: a URL/path
      # (local_asset result, /sw-asset/..., http(s)/data URI) becomes an
      # <img>; anything else (an emoji or short text glyph) is rendered as
      # plain text. Both branches carry the same hook class so a theming
      # stylesheet can size/position either without caring which it got.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param icon [String] emoji/glyph text, or an image URL/path
      # @param hook_class [String] the sw- hook class to apply
      # @return [void] Renders to view
      def render_icon_hook(view, icon, hook_class)
        if icon.match?(%r{\A(https?://|/|data:)}i)
          view.img(src: icon, alt: "", class: hook_class)
        else
          view.span(class: hook_class) { icon }
        end
      end

      # Render the app-chrome topbar: brand (icon + wordmark), breadcrumb
      # trail, and trailing block content.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::Topbar]
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_topbar(view, component, state)
        inject_topbar_css(view)

        css_classes = ["sw-topbar", component.options[:class]].compact.join(" ")
        attrs = { class: css_classes }
        attrs[:style] = component.options[:style] if component.options[:style]

        view.div(**attrs) do
          if component.icon || component.wordmark
            view.div(class: "sw-topbar-brand") do
              render_icon_hook(view, component.icon, "sw-topbar-icon") if component.icon
              view.div(class: "sw-topbar-wordmark") { component.wordmark } if component.wordmark
            end
          end
          if component.breadcrumbs.any?
            view.div(class: "sw-topbar-breadcrumbs") do
              component.breadcrumbs.each_with_index do |crumb, index|
                view.span(class: "sw-topbar-separator") { "·" } if index.positive?
                crumb_classes = ["sw-topbar-crumb"]
                crumb_classes << "sw-topbar-crumb--active" if index == component.breadcrumbs.size - 1
                view.span(class: crumb_classes.join(" ")) { crumb }
              end
            end
          end
          unless component.children.empty?
            view.div(class: "sw-topbar-trailing") do
              component.children.each { |child| child.render(view, state) }
            end
          end
        end
      end

      # Render a single board card.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param children [Array] Child components
      # @param options [Hash] Component options (:tone, :class, :style)
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_board_card(view, children, options, state)
        css_classes = ["sw-board__card"]
        css_classes << "sw-board__card--#{options[:tone]}" if options[:tone]
        css_classes << options[:class] if options[:class]
        attrs = { class: css_classes.join(" ") }
        attrs[:style] = options[:style] if options[:style]

        view.div(**attrs) do
          children.each { |child| child.render(view, state) }
        end
      end

      # Render a score table with color-coded metrics
      #
      # Render a data table with configurable styling
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param headers [Array<String>] Column headers
      # @param rows [Array<Array>] Row data
      # @param options [Hash] Styling options (:striped, :bordered, :hoverable, :compact, :caption, :sortable, :sticky_header, :columns)
      # @param state [Hash] Current state hash (symbol keys)
      # @return [void] Renders to view
      def render_table(view, headers, rows, options, state)
        table_classes = ["sw-table"]
        table_classes << "sw-table-striped" if options[:striped]
        table_classes << "sw-table-bordered" if options[:bordered]
        table_classes << "sw-table-hoverable" if options[:hoverable]
        table_classes << "sw-table-compact" if options[:compact]
        table_classes << "sw-table-sortable" if options[:sortable]
        table_classes << "sw-table--alternating" if options[:alternating]
        table_classes << "sw-table--hover" if options[:hover]
        table_classes << "sw-table--sticky-header" if options[:sticky_header]
        table_classes << options[:class] if options[:class]

        columns = options[:columns] || []
        component_columns = options[:component_columns] || []
        sort_values = options[:sort_values] || []
        row_ids = options[:row_ids] || []
        # A stable per-row DOM id needs a table id to hang off of, not just a
        # sortable one (FAC-P2.1 decision 6) -- row-level targeting for
        # row-granular swaps (stream_weaver-95k). `dom_id` (deterministic,
        # assigned once per table by the `table` DSL method) is used whenever
        # present; SecureRandom stays as a fallback only for tables that
        # don't need row addressing (no column DSL / no row identity), where
        # per-render freshness doesn't matter.
        table_id = options[:dom_id] || ("table_#{SecureRandom.hex(4)}" if options[:sortable] || options[:key].is_a?(Symbol))

        # Wrapper for sticky header or scrollable
        wrapper_classes = []
        wrapper_style = nil
        if options[:scrollable]
          wrapper_classes << "sw-table--scrollable"
          wrapper_style = "max-height: 400px; overflow: auto;"
        elsif options[:sticky_header]
          wrapper_style = "max-height: 400px; overflow-y: auto;"
        end

        wrapper_attrs = {}
        wrapper_attrs[:class] = wrapper_classes.join(" ") if wrapper_classes.any?
        wrapper_attrs[:style] = wrapper_style if wrapper_style

        view.div(**wrapper_attrs) do
          alpine_data = options[:sortable] ? "{ sortCol: null, sortAsc: true }" : nil
          table_style = "width: 100%; border-collapse: collapse;"
          table_style += " #{options[:style]}" if options[:style]
          table_attrs = { class: table_classes.join(" "), style: table_style }
          table_attrs["x-data"] = alpine_data if options[:sortable]
          table_attrs[:id] = table_id if table_id

          view.table(**table_attrs) do
            if options[:caption]
              view.caption(style: "caption-side: top; text-align: left; padding: 0.5rem 0; font-weight: 600;") { options[:caption] }
            end

            if headers.any?
              thead_style = options[:sticky_header] ? "position: sticky; top: 0; background: var(--sw-color-bg, white); z-index: 1;" : nil
              view.thead(style: thead_style) do
                view.tr do
                  headers.each_with_index do |header, col_idx|
                    col = columns[col_idx]
                    align = col&.align || :left
                    # A component column with no declared sort_value: has
                    # nothing meaningful to sort by (textContent isn't the
                    # data), so it's excluded from click-to-sort entirely
                    # (FAC-P2.1 decision 5) while other columns stay sortable.
                    col_sortable = options[:sortable] && !(component_columns[col_idx] && col&.sort_value.nil?)
                    th_padding = options[:compact] ? "0.5rem 1rem" : "var(--sw-table-header-padding, 0.75rem 1rem)"
                    th_style = "padding: #{th_padding}; text-align: #{align}; border-bottom: 2px solid var(--sw-color-border, #e0e0e0); font-weight: 600; text-transform: uppercase; letter-spacing: .07em; color: var(--sw-color-text-dim, var(--sw-color-text-muted, #6B6860));"
                    th_style += " cursor: pointer; user-select: none;" if col_sortable

                    th_attrs = { style: th_style }
                    if col_sortable
                      th_attrs["@click"] = "sortCol = #{col_idx}; sortAsc = sortCol === #{col_idx} ? !sortAsc : true; $dispatch('sort-table', { col: #{col_idx}, asc: sortAsc })"
                    end

                    view.th(**th_attrs) do
                      view.span { header.to_s }
                      if col_sortable
                        view.span(
                          "x-show" => "sortCol === #{col_idx}",
                          "x-text" => "sortAsc ? ' ▲' : ' ▼'",
                          style: "font-size: 0.75em; opacity: 0.7;"
                        )
                      end
                    end
                  end
                end
              end
            end

            tbody_attrs = {}
            if options[:sortable]
              tbody_attrs["x-ref"] = "tbody"
              tbody_attrs["@sort-table.window"] = <<~JS.gsub("\n", " ").strip
                const rows = Array.from($refs.tbody.querySelectorAll('tr'));
                rows.sort((a, b) => {
                  const aCell = a.children[$event.detail.col];
                  const bCell = b.children[$event.detail.col];
                  const aVal = aCell?.dataset.sortValue ?? aCell?.textContent ?? '';
                  const bVal = bCell?.dataset.sortValue ?? bCell?.textContent ?? '';
                  const aNum = parseFloat(aVal.replace(/[^0-9.-]/g, ''));
                  const bNum = parseFloat(bVal.replace(/[^0-9.-]/g, ''));
                  const cmp = !isNaN(aNum) && !isNaN(bNum) ? aNum - bNum : aVal.localeCompare(bVal);
                  return $event.detail.asc ? cmp : -cmp;
                });
                rows.forEach(r => $refs.tbody.appendChild(r));
              JS
            end

            view.tbody(**tbody_attrs) do
              rows.each_with_index do |row, idx|
                render_table_row(view, row, idx, options, state, table_id)
              end
            end
          end
        end
      end

      # Renders one `<tr>` -- the body of the row loop in #render_table,
      # extracted so InteractionRunner's row-granular narrowing
      # (stream_weaver-95k) can render a single row's HTML standalone (for
      # an OOB row swap) instead of the whole table.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param row [Array] One row's cell values (from Table#resolved_rows)
      # @param idx [Integer] The row's index (drives striping/alternating classes and sort-value lookup)
      # @param options [Hash] Table options, as built by Components::Table#table_options
      # @param state [Object] Current state (only used to render component cells)
      # @param table_id [String, nil] The table's dom id (Components::Table#dom_id), or nil
      # @param extra_attrs [Hash] Extra `<tr>` attributes, merged in last -- used by
      #   InteractionRunner's row-granular narrowing to mark a standalone row as an
      #   out-of-band swap (`hx-swap-oob`) when it's rendered as part of a declared
      #   `updates:` fragment instead of the primary target (stream_weaver-95k)
      # @return [void] Renders to view
      def render_table_row(view, row, idx, options, state, table_id, extra_attrs: {})
        columns = options[:columns] || []
        sort_values = options[:sort_values] || []
        row_ids = options[:row_ids] || []

        row_classes = []
        row_classes << "sw-row-striped" if options[:striped] && idx.odd?
        row_classes << "sw-row-hoverable" if options[:hoverable]
        row_classes << "sw-table__row--alt" if options[:alternating] && idx.odd?
        row_classes << "sw-table__row--hover" if options[:hover]

        tr_attrs = {}
        tr_attrs[:class] = row_classes.join(" ") if row_classes.any?
        row_id = row_ids[idx]
        tr_attrs[:id] = "#{table_id}-row-#{row_id}" if table_id && row_id
        tr_attrs.merge!(extra_attrs)

        view.tr(**tr_attrs) do
          row.each_with_index do |cell, col_idx|
            col = columns[col_idx]
            align = col&.align || :left
            cell_padding = options[:compact] ? "0.5rem 1rem" : "var(--sw-table-cell-padding, 0.75rem 1rem)"
            cell_style = "padding: #{cell_padding}; text-align: #{align}; border-bottom: 1px solid var(--sw-color-border, #e0e0e0);"
            if options[:bordered]
              cell_style += " border: 1px solid var(--sw-color-border, #e0e0e0);"
            end
            show_id_style =
              if !col.nil? && !col.id_style.nil?
                col.id_style
              elsif !options[:id_column].nil?
                options[:id_column] == col_idx
              else
                col_idx.zero?
              end

            if show_id_style
              cell_style += " color: var(--sw-color-accent, #1E4ED8); font-family: var(--sw-font-mono, monospace); font-size: .8rem;"
            end

            custom_style = options[:cell_styles]&.dig(idx, col_idx)
            cell_style += " #{custom_style}" if custom_style && !custom_style.to_s.empty?

            td_attrs = { style: cell_style }
            sort_value = sort_values.dig(idx, col_idx)
            td_attrs["data-sort-value"] = sort_value.to_s unless sort_value.nil?

            if cell.is_a?(Array)
              apply_action_cell_defaults!(cell, td_attrs)
              view.td(**td_attrs) { cell.each { |component| component.render(view, state) } }
            elsif options[:markdown]
              cell_content = parse_cell_markdown(cell.to_s)
              view.td(**td_attrs) { view.raw(view.safe(cell_content)) }
            else
              view.td(**td_attrs) { cell.to_s }
            end
          end
        end
      end

      # Rivet grammar: a component cell containing at least one button is an
      # "action cell" -- default its buttons to compact/quiet unless the
      # author already set size:/variant:, and lay the cell out inline so
      # several actions read as one row instead of stacking (FAC-9u2).
      #
      # @param cell [Array<Components::Base>] The resolved component cell
      # @param td_attrs [Hash] Mutated in place to add the inline-actions class
      # @return [void]
      def apply_action_cell_defaults!(cell, td_attrs)
        buttons = []
        each_nested_component(cell) { |component| buttons << component if component.is_a?(Components::Button) }
        return if buttons.empty?

        buttons.each { |button| button.apply_default_options(size: :sm, variant: :quiet) }
        td_attrs[:class] = [td_attrs[:class], "sw-table__actions"].compact.join(" ")
      end

      # @param components [Array<Components::Base>]
      # @yieldparam component [Components::Base]
      def each_nested_component(components, &block)
        components.each do |component|
          block.call(component)
          each_nested_component(component.children, &block) if component.respond_to?(:children)
        end
      end

      # Parse markdown links [text](url) in table cell content
      # @param text [String] Cell content that may contain markdown links
      # @return [String] HTML with links converted to <a> tags
      def parse_cell_markdown(text)
        text.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do
          %(<a href="#{Regexp.last_match(2)}" style="color: var(--sw-color-link, #0066cc);">#{Regexp.last_match(1)}</a>)
        end
      end

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
              value = score[:value] || score[:score] || 0
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
      # @param options [Hash] :class/:style passthrough (stream_weaver-1lo)
      # @return [void] Renders to view
      def render_markdown(view, content, state, options = {})
        html = Kramdown::Document.new(
          content,
          input: 'GFM',
          hard_wrap: false,
          syntax_highlighter: nil,
          typographic_symbols: { mdash: '---', ndash: '--' }
        ).to_html
        css_classes = ["markdown-content"]
        css_classes << options[:class] if options[:class]
        attrs = { class: css_classes.join(" ") }
        attrs[:style] = options[:style] if options[:style]
        view.div(**attrs) do
          view.raw view.safe(html)
        end
      end

      # Render a semantic header (h1-h6)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param content [String] The header text
      # @param level [Integer] Header level (1-6)
      # @param state [Hash] Current state hash (symbol keys)
      # @param options [Hash] :class/:style passthrough (stream_weaver-1lo)
      # @return [void] Renders to view
      def render_header(view, content, level, state, options = {})
        attrs = {}
        attrs[:class] = options[:class] if options[:class]
        attrs[:style] = options[:style] if options[:style]
        case level
        when 1 then view.h1(**attrs) { content }
        when 2 then view.h2(**attrs) { content }
        when 3 then view.h3(**attrs) { content }
        when 4 then view.h4(**attrs) { content }
        when 5 then view.h5(**attrs) { content }
        when 6 then view.h6(**attrs) { content }
        else view.h2(**attrs) { content }
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
        icon, label, css_class, sw_class = case status
        when :strong then ["🟢", "Strong", "status-badge-strong", "sw-status-badge--strong"]
        when :maybe then ["🟡", "Maybe", "status-badge-maybe", "sw-status-badge--maybe"]
        when :skip then ["🔴", "Skip", "status-badge-skip", "sw-status-badge--skip"]
        else ["⚪", "Unknown", "status-badge-unknown", "sw-status-badge--unknown"]
        end

        # "status-badge"/"status-badge-*" are the legacy, unprefixed hooks
        # (still emitted for back-compat -- deprecated, removed at 1.0;
        # this is the exact collision stream_weaver-lyb was filed for --
        # tyrion's own real CSS declares its own `.status-badge`).
        # "sw-status-badge"/"sw-status-badge--*" are the documented stable
        # hooks (stream_weaver-oeo).
        view.span(class: "status-badge sw-status-badge #{css_class} #{sw_class}") do
          view.span(class: "status-badge-icon sw-status-badge__icon") { icon }
          view.span(class: "status-badge-label sw-status-badge__label") { label }
          view.span(class: "status-badge-reasoning sw-status-badge__reasoning") { " — #{reasoning}" }
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
              **htmx_attrs(url("/update"), "hx-vals" => JSON.generate({ key.to_s => tag_value }))
            ) { tag }
          end
        end
      end

      # Render a tag/chip multi-select bound to a state array (or a scalar
      # when multi: false). Mirrors the form_context/scope_name/top-level
      # branching used by render_text_field/render_select so chip_group works
      # the same way inside form/scope blocks.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::ChipGroup]
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_chip_group(view, component, state)
        inject_chip_group_css(view)
        key = component.key
        choices = component.choices
        multi = component.multi
        options = component.options
        form_context = options[:form_context]
        scope_name = options[:scope_name]

        if form_context
          form_name = form_context[:name]
          current = (state[form_name] || {})[key]
          model = "_form.#{key}"
          name = "#{form_name}[#{key}]"
          submit_attrs = {}
        elsif scope_name
          current = (state[scope_name] || {})[key]
          model = "#{scope_name}.#{key}"
          name = "#{scope_name}[#{key}]"
          submit_attrs = chip_group_submit_attrs(view, options)
        else
          current = state[key]
          model = key.to_s
          name = key.to_s
          submit_attrs = chip_group_submit_attrs(view, options)
        end
        current = multi ? Array(current) : current

        wrap_with_label(view, options[:label]) do
          view.div(class: "sw-chip-group") do
            choices.each do |choice|
              chip_label, value = choice.is_a?(Array) ? choice : [choice, choice]
              checked = multi ? current.include?(value) : current == value

              view.label(class: "sw-chip") do
                view.input(
                  type: multi ? "checkbox" : "radio",
                  name: multi ? "#{name}[]" : name,
                  value: value,
                  checked: checked,
                  "x-model" => model,
                  class: "sw-chip__input",
                  **submit_attrs
                )
                view.span(class: "sw-chip__label") { chip_label }
              end
            end
          end
        end
      end

      def chip_group_submit_attrs(view, options)
        return {} unless options.fetch(:submit, true)

        htmx_attrs(url("/update"), view: view, loading: options.fetch(:loading, true), "hx-trigger" => "change")
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
            **htmx_attrs(url("/submit"), "@click" => "setTimeout(() => window.open('#{url}', '_blank'), 100)")
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
        css_classes = ["sw-columns"]
        css_classes << options[:class] if options[:class]
        styles = ["display: flex;", "gap: #{gap};"]
        styles << options[:style] if options[:style]

        view.div(class: css_classes.join(" "), style: styles.join(" ")) do
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

        style = if width.nil?
          "flex: 1 1 0; min-width: 0;"  # Equal distribution
        elsif (fr_match = width.match(/\A(\d+(?:\.\d+)?)fr\z/))
          # "fr" is a CSS Grid unit, not a valid flex-basis -- using it there makes
          # the whole `flex` shorthand invalid, which silently falls back to
          # `flex: 0 1 auto` (shrink-to-content instead of the intended equal/
          # proportional share). Translate the fraction to flex-grow instead.
          "flex: #{fr_match[1]} 1 0%; min-width: 0;"
        else
          # A plain length (px/rem/%) means "pin this column at exactly this
          # width" (e.g. widths: ["260px", "1fr"] for a fixed sidebar + fluid
          # content pane) -- flex-grow must be 0 or this column competes
          # equally with any sibling "1fr"/no-width column for leftover
          # space instead of staying fixed, which visibly skews a supposedly
          # narrow fixed sidebar much wider than its stated width.
          "flex: 0 1 #{width}; min-width: 0;"
        end
        style = [style, options[:style]].compact.join(" ")

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
              submit_id = "form-#{name}-submit"
              loading = options.fetch(:loading, true) && loading_indicators_enabled?(view)
              submit_class = ["btn", "btn-primary"]
              submit_class << "sw-no-loading-indicator" unless loading

              view.button(
                type: "button",
                id: submit_id,
                class: submit_class.join(" "),
                **htmx_attrs(url("/form/#{name}"), view: view, loading: loading, indicator: "##{submit_id}",
                  "hx-include" => "[name^='#{name}[']")
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
        styles << component.options[:style] if component.options[:style]

        # Named template-areas mode
        if component.template_areas
          areas_css = component.template_areas.map { |row| %("#{row}") }.join(" ")
          styles << "grid-template-areas: #{areas_css};"
          styles << "grid-template-rows: #{component.template_rows};"    if component.template_rows
          styles << "grid-template-columns: #{component.template_columns};" if component.template_columns
        # Explicit template hash: { rows: ..., columns: ... }
        elsif component.template
          styles << "grid-template-rows: #{component.template[:rows]};"       if component.template[:rows]
          styles << "grid-template-columns: #{component.template[:columns]};" if component.template[:columns]
        # Loose individual row/column strings
        elsif component.template_rows || component.template_columns
          styles << "grid-template-rows: #{component.template_rows};"       if component.template_rows
          styles << "grid-template-columns: #{component.template_columns};" if component.template_columns
        # Responsive array or plain integer column count (original behaviour)
        elsif component.columns.is_a?(Array)
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
          return
        else
          styles << "grid-template-columns: repeat(#{component.columns}, 1fr);"
        end

        view.div(class: css_classes.join(" "), style: styles.join(" ")) do
          component.children.each { |child| child.render(view, state) }
        end
      end

      def render_grid_area(view, component, state)
        css_classes = ["sw-grid-area"]
        css_classes << component.options[:class] if component.options[:class]
        style = "grid-area: #{component.area_name};"
        view.div(class: css_classes.join(" "), style: style) do
          component.children.each { |child| child.render(view, state) }
        end
      end

      def render_sticky(view, component, state)
        css_classes = ["sw-sticky"]
        css_classes << component.options[:class] if component.options[:class]
        parts = ["position: sticky;"]
        parts << "top: #{component.top}px;"      if component.top
        parts << "bottom: #{component.bottom}px;" if component.bottom
        parts << "left: #{component.left}px;"    if component.left
        parts << "right: #{component.right}px;"  if component.right
        parts << "z-index: #{component.z_index};" if component.z_index
        view.div(class: css_classes.join(" "), style: parts.join(" ")) do
          component.children.each { |child| child.render(view, state) }
        end
      end

      def render_overlay(view, component, state)
        css_classes = ["sw-overlay"]
        css_classes << component.options[:class] if component.options[:class]
        parts = ["position: absolute;", "z-index: #{component.z};"]
        parts << "pointer-events: #{component.pointer_events};" if component.pointer_events
        parts << component.options[:style] if component.options[:style]
        view.div(class: css_classes.join(" "), style: parts.join(" ")) do
          component.children.each { |child| child.render(view, state) }
        end
      end

      def render_fullbleed(view, component, state)
        css_classes = ["sw-fullbleed"]
        css_classes << component.options[:class] if component.options[:class]
        style = "width: 100%; max-width: none; margin-left: calc(-1 * var(--sw-spacing-xl, 0)); margin-right: calc(-1 * var(--sw-spacing-xl, 0));"
        view.div(class: css_classes.join(" "), style: style) do
          component.children.each { |child| child.render(view, state) }
        end
      end

      # Render a scrollable container with max-height
      def render_scroll_box(view, component, state)
        css_classes = ["sw-scroll-box"]
        css_classes << component.options[:class] if component.options[:class]

        view.div(
          class: css_classes.join(" "),
          style: "max-height: #{component.max_height}; overflow-y: auto;"
        ) do
          component.children.each { |child| child.render(view, state) }
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
        active_index = (state[key] || 0).to_i
        variant_class = "sw-tabs-#{component.variant}"
        lazy = component.lazy
        routed = route_tabs?(component)
        warn_route_tabs_ignored(view) if component.url && !routed

        # For a routed group the URL decides which tab is showing -- on first
        # paint and again on every back/forward step -- so the rendered index
        # never reaches the markup.
        active_tab = routed ? "swRouteTabs.read('#{key}', #{component.children.size})" : active_index.to_s

        container_attrs = {
          id: "tabs-#{key}",
          class: "sw-tabs #{variant_class}",
          "x-data" => "{ activeTab: #{active_tab} }"
        }

        if routed
          container_attrs["@popstate.window"] = "activeTab = #{active_tab}"
          inject_route_tabs_js(view)
        end

        view.div(**container_attrs) do
          # Hidden input syncs tab state with server on other HTMX requests.
          # Route tabs skip it: the URL is their authority, so letting a form
          # submit write this index into the session would fight it.
          view.input(type: "hidden", name: key.to_s, "x-model" => "activeTab") unless routed

          # Tab headers
          view.div(class: "sw-tabs-list") do
            component.children.each_with_index do |tab, index|
              tab_classes = ["sw-tab-trigger"]
              # A routed group names no active trigger server-side: a morph that
              # rewrote this attribute would not re-run the :class effect below
              # (activeTab never changed), stranding the highlight on a stale index.
              tab_classes << "sw-tab-active" if index == active_index && !routed

              if lazy
                # Lazy mode: tab switch does Alpine UI + HTMX morph to fetch active tab content
                view.button(
                  type: "button",
                  class: tab_classes.join(" "),
                  ":class" => "{ 'sw-tab-active': activeTab === #{index} }",
                  "@click" => "activeTab = #{index}",
                  "hx-post" => url("/update"),
                  "hx-include" => input_selector,
                  "hx-vals" => JSON.generate({ key.to_s => index }),
                  "hx-target" => HTMX_TARGET,
                  "hx-swap" => HTMX_SWAP
                ) { tab.label }
              else
                # Standard mode: Alpine handles UI instantly, server response discarded
                click = "activeTab = #{index}"
                click += "; swRouteTabs.push('#{key}', #{index})" if routed

                trigger_attrs = {
                  type: "button",
                  class: tab_classes.join(" "),
                  ":class" => "{ 'sw-tab-active': activeTab === #{index} }",
                  "@click" => click
                }
                # Canvas has no server session to sync -- the next push rebuilds
                # state. Route tabs have one but must not touch it.
                unless websocket_mode? || routed
                  trigger_attrs["hx-post"] = url("/update")
                  trigger_attrs["hx-vals"] = JSON.generate({ key.to_s => index })
                  trigger_attrs["hx-swap"] = "none"
                end

                view.button(**trigger_attrs) { tab.label }
              end
            end
          end

          # Tab panels
          component.children.each_with_index do |tab, index|
            view.div(
              class: "sw-tab-panel",
              "x-show" => "activeTab === #{index}",
              "x-cloak" => true
            ) do
              if lazy && index != active_index
                # Lazy mode: skip rendering inactive tab content
                view.comment { "lazy: tab #{index} not rendered" }
              else
                tab.children.each { |child| child.render(view, state) }
              end
            end
          end
        end
      end

      # Whether this tabs group reflects its active tab in the URL. Canvas has
      # no app URL to reflect into, so `url: true` degrades there.
      #
      # @param component [Tabs] The tabs component
      # @return [Boolean]
      def route_tabs?(component)
        component.url && !websocket_mode?
      end

      # Tell the agent that pushed this page why its tabs are not in the URL.
      # Once per render pass, so every pushed page says it -- guarding on the
      # adapter would silence it after the first page a server renders.
      def warn_route_tabs_ignored(view)
        return if view.instance_variable_get(:@_route_tabs_warned)
        view.instance_variable_set(:@_route_tabs_warned, true)
        warn "StreamWeaver: tabs url: true is ignored on canvas -- a canvas page has no app URL to carry the active tab"
      end

      # Inject sw-route-tabs.js once per render
      def inject_route_tabs_js(view)
        return if view.instance_variable_get(:@_route_tabs_js_injected)
        view.instance_variable_set(:@_route_tabs_js_injected, true)
        js_path = File.join(__dir__, '..', 'assets', 'js', 'sw-route-tabs.js')
        view.script { view.raw(view.safe(File.read(js_path))) } if File.exist?(js_path)
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

      def render_link(view, component, state)
        extra_class = component.options[:class]
        css = extra_class ? "sw-link #{extra_class}" : "sw-link"
        view.a(href: component.href, class: css) { component.label }
      end

      # Render a `clickable` wrapper: any composed content as a single click
      # target. href: renders a plain navigation <a>; the action: form is
      # wired exactly like a named-action button (App#clickable already
      # built the token) via the same htmx_attrs machinery render_button
      # uses, so it dispatches identically -- including from inside a table
      # cell or fragment (stream_weaver-1lo).
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::Clickable]
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_clickable(view, component, state)
        inject_component_css(view, :clickable, clickable_css)

        if component.href
          css_classes = ["sw-clickable", "sw-clickable--link"]
          css_classes << component.options[:class] if component.options[:class]
          attrs = { class: css_classes.join(" "), href: component.href }
          attrs[:style] = component.options[:style] if component.options[:style]

          view.a(**attrs) do
            component.children.each { |child| child.render(view, state) }
          end
          return
        end

        wrapper_id = component.id
        action_target = component.options[:action_token] || wrapper_id
        loading = loading_indicators_enabled?(view)

        css_classes = ["sw-clickable"]
        css_classes << component.options[:class] if component.options[:class]
        attrs = { class: css_classes.join(" ") }
        attrs[:style] = component.options[:style] if component.options[:style]

        # A click (or Enter) that originates inside a nested interactive
        # element -- e.g. a `button` glued to a board_card for its own
        # action -- dispatches only that element's own request, not the
        # wrapper's; otherwise every click on a nested control would also
        # fire the wrapper's action.
        not_nested_interactive = "!event.target.closest('a,button,input,select,textarea,label,[data-sw-stop]')"
        trigger = "click[#{not_nested_interactive}], keydown[event.key=='Enter'&&#{not_nested_interactive}]"

        attrs.merge!(htmx_attrs(
          url("/action/#{action_target}"), view: view, loading: loading, indicator: "##{wrapper_id}",
          sw_updates: component.options[:updates], sw_primary: component.options[:primary],
          "hx-disabled-elt" => "this", "hx-trigger" => trigger
        ))
        attrs[:id] = wrapper_id
        attrs[:role] = "button"
        attrs[:tabindex] = "0"

        view.div(**attrs) do
          component.children.each { |child| child.render(view, state) }
        end
      end

      def clickable_css
        <<~CSS
          .sw-clickable {
            cursor: pointer;
          }
          .sw-clickable:focus-visible {
            outline: 2px solid var(--sw-color-primary, #3b82f6);
            outline-offset: 2px;
          }
          .sw-clickable--link {
            display: block;
            text-decoration: none;
            color: inherit;
          }
        CSS
      end

      def render_navbar(view, component, state)
        css_classes = ["sw-navbar"]
        css_classes << component.options[:class] if component.options[:class]

        attrs = { class: css_classes.join(" ") }
        attrs[:style] = component.options[:style] if component.options[:style]

        view.nav(**attrs) do
          component.children.each { |child| child.render(view, state) }
        end
      end

      def render_nav_item(view, component, state)
        classes = ["sw-navbar-item"]
        classes << "sw-navbar-item-active" if component.active?
        classes << component.options[:class] if component.options[:class]
        attrs = { class: classes.join(" ") }
        attrs[:style] = component.options[:style] if component.options[:style]

        content = proc do
          if component.close_label
            view.span(class: "sw-navbar-item__label") { component.label }
            view.span(class: "sw-navbar-item__close", "aria-hidden" => "true") { component.close_label }
          else
            component.label
          end
        end

        component.active? ? view.span(**attrs, &content) : view.a(**attrs.merge(href: component.href), &content)
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
        #
        # data-sw-open mirrors the server's current open/closed decision as a
        # plain attribute. Alpine morph preserves the local `open` reactive
        # value across re-renders of this node (that's the point of morph --
        # it never re-runs x-data), so a fresh server value alone can't move
        # the modal; button handlers read data-sw-open post-swap and assign it
        # into `open` explicitly (stream_weaver-ho5).
        view.div(
          class: "sw-modal-wrapper",
          "data-sw-open" => is_open.to_s,
          "x-data" => "{ open: #{is_open} }",
          "x-init" => "$watch('open', v => { if(!v) htmx.ajax('POST', '#{url("/update")}', {target:'#app-container', swap:'morph:innerHTML', values:{'#{open_key}': 'false'}}) })",
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
          dialog_classes = ["sw-modal", size_class]
          dialog_classes << component.options[:class] if component.options[:class]
          dialog_attrs = {
            class: dialog_classes.join(" "),
            "x-show" => "open",
            "x-cloak" => true,
            "x-transition:enter" => "sw-transition-modal-enter",
            "x-transition:enter-start" => "sw-transition-modal-enter-start",
            "x-transition:enter-end" => "sw-transition-modal-enter-end",
            "x-transition:leave" => "sw-transition-modal-leave",
            "x-transition:leave-start" => "sw-transition-modal-leave-start",
            "x-transition:leave-end" => "sw-transition-modal-leave-end",
            "@click.stop" => ""  # Prevent clicks inside modal from closing it
          }
          dialog_attrs[:style] = component.options[:style] if component.options[:style]

          view.div(**dialog_attrs) do
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

      # Render canvas continue marker - hidden element that tells JS to show spinner after submit
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param message [String] Message to show while processing
      # @param state [Hash] Current state hash
      def render_canvas_continue(view, message, state)
        view.div(
          id: "sw-canvas-continue",
          "data-continue-message" => message,
          style: "display:none"
        )
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
          "x-data" => theme_switcher_alpine_data(themes),
          "x-init" => "applyDark(dark); $watch('dark', v => { applyDark(v); localStorage.setItem('sw-dark-mode', v) })"
        ) do
          view.button(
            type: "button",
            class: "sw-dark-mode-toggle btn-ghost",
            "aria-label" => "Toggle dark mode",
            "@click" => "dark = !dark",
            style: "padding: 0.4rem 0.6rem; margin: 0; font-size: 1.1rem; line-height: 1;"
          ) do
            view.span("x-show" => "!dark") { "\u{2600}\u{FE0F}" }
            view.span("x-show" => "dark") { "\u{1F319}" }
          end

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
                  "@click" => "switchTheme('#{theme[:id]}')"
                ) do
                  view.span(class: "sw-theme-switcher-option-label") { theme[:label] }
                  view.span(class: "sw-theme-switcher-option-desc") { theme[:description] }
                end
              end
            end
          end
        end
      end

      def theme_switcher_alpine_data(themes)
        <<~JS.gsub(/\s+/, " ").strip
          {
            open: false,
            dark: localStorage.getItem('sw-dark-mode') === 'true' ||
                  (localStorage.getItem('sw-dark-mode') === null &&
                   window.matchMedia('(prefers-color-scheme: dark)').matches),
            applyDark(v) {
              document.documentElement.classList.toggle('dark', v);
              document.documentElement.setAttribute('data-sw-theme', v ? 'dark' : 'light');
            },
            switchTheme(id) {
              this.open = false;
              document.body.className = document.body.className.replace(/sw-theme-\\w+/, 'sw-theme-' + id);
              htmx.ajax('POST', '#{url("/theme/")}' + id, {swap:'none'});
            }
          }
        JS
      end

      # =========================================
      # Theme toggle rendering (visual skills auto-mode)
      # =========================================

      # Render a dark/light/auto mode toggle button.
      # Uses sw- prefixed CSS classes following BEM convention.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [ThemeToggle] The theme toggle component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_theme_toggle(view, component, state)
        alpine_data = StreamWeaver::Theme::AutoMode.alpine_data(default_mode: component.mode)

        view.div(
          class: "sw-theme-toggle",
          "x-data" => alpine_data
        ) do
          view.button(
            type: "button",
            class: "sw-theme-toggle__btn",
            "aria-label" => "Toggle theme (dark/light/system)",
            "@click" => "toggle()"
          ) do
            # Sun icon (shown in dark mode)
            view.span(
              class: "sw-theme-toggle__icon",
              "x-show" => "effective === 'dark'",
              "aria-hidden" => "true"
            ) do
              view.raw(view.safe("\u{2600}\u{FE0F}"))
            end
            # Moon icon (shown in light mode)
            view.span(
              class: "sw-theme-toggle__icon",
              "x-show" => "effective === 'light'",
              "aria-hidden" => "true"
            ) do
              view.raw(view.safe("\u{1F319}"))
            end
          end

          # Show current mode label
          view.span(
            class: "sw-theme-toggle__label",
            "x-text" => "preference === 'auto' ? 'System' : preference === 'dark' ? 'Dark' : 'Light'"
          )
        end
      end

      # =========================================
      # Theme preset rendering (visual skills T15)
      # =========================================

      # Render a theme preset: injects Google Fonts <link> and CSS custom
      # property overrides for both light and dark modes.
      # Also injects animation keyframes CSS on first use.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [ThemePreset] The theme preset component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_theme_preset(view, component, state)
        preset = component.preset

        if preset[:sketch]
          inject_sketch_mode(view)
          return
        end

        # Inject Google Fonts <link>
        fonts_url = StreamWeaver::Theme::Presets.google_fonts_url(preset)
        view.link(rel: "stylesheet", href: fonts_url)

        # Inject CSS custom properties for both modes + font-family rules
        css = StreamWeaver::Theme::Presets.generate_preset_css(component.preset_name)
        view.style { view.raw(view.safe(StreamWeaver::CSS.layer_wrap(css))) }

        # Inject animation CSS (once per render)
        unless view.instance_variable_get(:@_sw_animations_injected)
          view.instance_variable_set(:@_sw_animations_injected, true)
          animations_css = StreamWeaver::Theme::Presets.animations_css
          view.style { view.raw(view.safe(StreamWeaver::CSS.layer_wrap(animations_css))) }
        end
      end

      def inject_sketch_mode(view)
        return if view.instance_variable_get(:@_sketch_injected)

        view.instance_variable_set(:@_sketch_injected, true)

        # Caveat hand-drawn font from Google Fonts (Excalifont-style, or similar)
        view.link(
          rel: "stylesheet",
          href: "https://fonts.googleapis.com/css2?family=Caveat:wght@400;500;600;700&display=swap"
        )

        # rough.js CDN for hand-drawn border treatment
        view.script(src: "https://cdn.jsdelivr.net/npm/roughjs@4/bundled/rough.js")

        # Sketch mode CSS: hand-drawn font scoped to wireframe surfaces only
        view.style { view.raw(view.safe(StreamWeaver::CSS.layer_wrap(sketch_mode_css))) }

        # Sketch mode JS: set data-sketch on body + roughify wireframe surfaces
        view.script { view.raw(view.safe(sketch_mode_js)) }
      end

      def sketch_mode_css
        <<~CSS
          /* StreamWeaver Sketch Mode — scoped to .sw-wireframe-surface only */
          body[data-sketch] .sw-wireframe-surface,
          body[data-sketch] .sw-wireframe-surface * {
            font-family: 'Caveat', cursive;
          }
        CSS
      end

      def sketch_mode_js
        <<~JS
          document.addEventListener('DOMContentLoaded', function() {
            document.body.setAttribute('data-sketch', '');
            if (typeof rough === 'undefined') return;
            document.querySelectorAll('.sw-wireframe-surface').forEach(function(el) {
              roughifyElement(el);
            });
          });

          function roughifyElement(el) {
            el.style.position = 'relative';
            var rect = el.getBoundingClientRect();
            if (!rect.width || !rect.height) return;
            var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            svg.style.cssText = 'position:absolute;top:0;left:0;pointer-events:none;overflow:visible;z-index:0';
            svg.setAttribute('width', rect.width);
            svg.setAttribute('height', rect.height);
            var rc = rough.svg(svg);
            var ink = getComputedStyle(el).getPropertyValue('--wf-ink').trim() || '#1a1a2e';
            var node = rc.rectangle(2, 2, rect.width - 4, rect.height - 4, {
              roughness: 2.5,
              stroke: ink,
              strokeWidth: 1.5,
              fill: 'none'
            });
            svg.appendChild(node);
            el.insertBefore(svg, el.firstChild);
          }
        JS
      end

      # =========================================
      # CodeBlock rendering (visual skills T4)
      # =========================================

      # Track whether Prism.js CDN has been injected in the current page render.
      # Lazily loaded -- only when a code_block component is actually used.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [CodeBlock] The code block component
      # @param state [Hash] Current state hash

      # Small copy-to-clipboard control rendered inside the code block header
      # when `copy: true`. Reuses window.swCopy (via copy_button_attrs) --
      # the same safety mechanism as the standalone copy_button component.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [CodeBlock] The code block component
      def render_code_block_copy_button(view, component)
        inject_copy_js(view)
        classes = ["sw-code-block__copy", "sw-copy-button"].join(" ")
        view.button(**copy_button_attrs(component.code, classes), "aria-label" => "Copy code") do
          view.span("x-show" => "!copied") { "Copy" }
          view.span("x-show" => "copied", "x-cloak" => true) { "Copied!" }
        end
      end

      # =========================================
      # ImageBlock rendering (visual skills T4)
      # =========================================

      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [ImageBlock] The image block component
      # @param state [Hash] Current state hash
      def render_image_block(view, component, state)
        view.figure(class: "sw-image-block") do
          view.img(
            src: component.resolved_src,
            alt: component.alt,
            class: "sw-image-block__img"
          )
          if component.caption
            view.figcaption(class: "sw-image-block__caption") do
              view.plain(component.caption)
            end
          end
        end
      end

      # =========================================
      # Mermaid diagram rendering
      # =========================================

      def render_mermaid(view, component, state)
        # Lazy-inject CSS and JS on first mermaid component render
        unless view.instance_variable_get(:@_mermaid_assets_injected)
          view.instance_variable_set(:@_mermaid_assets_injected, true)
          view.style { view.raw(view.safe(StreamWeaver::CSS.layer_wrap(MERMAID_CSS))) }
          inject_mermaid_engine(view)
        end

        # No Alpine directive here: sw-mermaid-zoom.js self-inits on
        # DOMContentLoaded and re-inits on every htmx:afterSwap, so
        # rendering has no dependency on Alpine being loaded at all --
        # important for the exporter, which only loads Alpine when a
        # collapsible/theme_toggle needs its reactivity (stream_weaver-4gs).
        attrs = {
          id: component.diagram_id,
          class: component.css_classes
        }

        # ELK layout flag for the JS loader
        attrs["data-sw-mermaid-elk"] = "true" if component.elk?

        # Per-block theme variable overrides
        if component.theme_vars
          attrs["data-sw-mermaid-vars"] = component.theme_vars_json
        end

        view.div(**attrs) do
          # Controls: expand is always available (stream_weaver-yjv) --
          # the in-place zoom mechanism (zoom: true) helps but doesn't fix
          # the actual problem, which is the container itself: a wide
          # diagram's fixed-px labels shrink proportionally to fit an
          # 800-1400px doc column regardless of pan/zoom. Expand opens the
          # diagram in a full-viewport overlay instead, with no container
          # width to shrink against. +/-/reset stay opt-in via zoom: true;
          # expand needs no opt-in since it has no in-place layout cost.
          view.div(class: "sw-mermaid__controls") do
            if component.zoom
              view.button(
                type: "button",
                class: "sw-mermaid__btn",
                "data-sw-zoom" => "in",
                "aria-label" => "Zoom in",
                title: "Zoom in"
              ) { "+" }
              view.button(
                type: "button",
                class: "sw-mermaid__btn",
                "data-sw-zoom" => "out",
                "aria-label" => "Zoom out",
                title: "Zoom out"
              ) { "\u2212" }
              view.button(
                type: "button",
                class: "sw-mermaid__btn",
                "data-sw-zoom" => "reset",
                "aria-label" => "Reset zoom",
                title: "Reset"
              ) { "\u21BA" }
            end
            # A plain unicode glyph, like the other three buttons -- not
            # an inline SVG. Two SVG-based attempts in a row went blank
            # specifically on SharePoint (once via bare width/height
            # attributes, once via a stylesheet class after ruling out an
            # inline-style CSP restriction) while +/-/reset, plain text
            # the whole time, never had a problem. The common factor
            # across both failures wasn't styling -- it was that this was
            # the one button whose content was markup (<svg><path>...)
            # rather than a text node. SharePoint's HTML preview most
            # likely sanitizes uploaded HTML before rendering it (a
            # standard XSS defense for untrusted-content previews, and
            # <svg> is a common target -- it can carry event handlers and
            # <script>/<foreignObject>), which would strip the whole icon
            # silently regardless of what CSS sizes it or how. A unicode
            # character is a text node, immune to that class of
            # sanitization the same way the other three buttons already
            # are.
            view.button(
              type: "button",
              class: "sw-mermaid__btn",
              "data-sw-zoom" => "expand",
              "aria-label" => "Expand to full screen",
              title: "Expand to full screen"
            ) { "⛶" }
          end

          # The diagram rendering area.
          # Mermaid code stored as data attribute; JS reads it to render.
          view.div(
            class: "sw-mermaid__diagram",
            "data-sw-mermaid-code" => component.code
          )
        end
      end

      # Inlines sw-mermaid-zoom.js verbatim as a <script> -- not a CDN
      # reference. This is what makes mermaid rendering have zero external
      # script dependency of its own (stream_weaver-4gs): the engine that
      # loads mermaid's actual library is always local, whether or not
      # that library itself comes from the CDN or is inlined too
      # (--offline, stream_weaver-dnq).
      def inject_mermaid_engine(view)
        js_path = File.join(__dir__, '..', 'assets', 'js', 'sw-mermaid-zoom.js')
        if File.exist?(js_path)
          view.script { view.raw(view.safe(File.read(js_path))) }
        end
      end

      # CSS for Mermaid containers
      MERMAID_CSS = <<~CSS
        /* ===========================================
           Mermaid Component Styles (sw- prefix)
           =========================================== */
        .sw-mermaid {
          position: relative;
          overflow: hidden;
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-md, 6px);
          background: var(--sw-surface, #ffffff);
          padding: 1rem;
          margin: 0.5rem 0;
        }

        .sw-mermaid--compact {
          padding: 0.25rem;
          margin: 0;
          border: none;
          background: transparent;
        }

        .sw-mermaid--zoom {
          cursor: grab;
          min-height: 200px;
        }

        .sw-mermaid--zoom:active {
          cursor: grabbing;
        }

        .sw-mermaid__diagram {
          display: flex;
          justify-content: center;
          align-items: center;
          min-height: 60px;
        }

        .sw-mermaid__diagram svg {
          max-width: 100%;
          height: auto;
        }

        /* views.rb's global `p { color: var(--sw-color-text-muted) }` typography rule
           is unscoped and beats Mermaid's own inline node-label color (mermaid renders
           HTML labels as <p> inside a foreignObject) -- inheritance loses to any rule
           that targets the element directly, even one set via a colored `style X
           color:#fff` directive on an ancestor. Net effect: every mermaid node label
           renders the same muted gray regardless of the diagram author's color choice,
           unreadable on a dark-filled node. Force these <p> tags back to inheriting
           from Mermaid's own label wrapper. */
        .sw-mermaid__diagram svg foreignObject p {
          color: inherit !important;
        }

        .sw-mermaid--compact .sw-mermaid__diagram svg {
          max-height: 150px;
        }

        .sw-mermaid__controls {
          position: absolute;
          top: 0.5rem;
          right: 0.5rem;
          display: flex;
          gap: 0.25rem;
          z-index: 10;
        }

        .sw-mermaid__btn {
          width: 28px;
          height: 28px;
          display: flex;
          align-items: center;
          justify-content: center;
          background: var(--sw-surface-elevated, #f3f3f3);
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-sm, 4px);
          cursor: pointer;
          font-size: 1rem;
          line-height: 1;
          color: var(--sw-text, #111);
          transition: background 150ms ease-out;
        }

        .sw-mermaid__btn:hover {
          background: var(--sw-accent, #0d9488);
          color: #fff;
          border-color: var(--sw-accent, #0d9488);
        }

        .sw-mermaid__error {
          color: var(--sw-error, #dc2626);
          font-family: var(--sw-font-mono, monospace);
          font-size: 0.85rem;
          padding: 1rem;
        }

        /* Fullscreen expand overlay (stream_weaver-yjv) -- the doc column's
           max-width shrinks a wide diagram's fixed-px labels proportionally
           no matter how the layout is tuned; the overlay removes that
           constraint entirely instead of trying to out-negotiate it.
           A <dialog> via showModal(), not a hand-rolled div: the browser's
           top layer means no z-index arms race with this file's own
           toasts/nav (see page_shell.rb, alpinejs.rb elsewhere), plus
           Escape-to-close, focus management, and an inert background for
           free -- overriding only the UA default box (border/padding/
           background/position) that a plain <dialog> ships with. */
        dialog.sw-mermaid-fullscreen-overlay {
          max-width: none;
          max-height: none;
          width: 100%;
          height: 100%;
          margin: 0;
          border: 0;
          padding: 4rem 2rem 2rem;
          background: transparent;
          /* The dialog itself does NOT scroll -- .content does (below).
             A first version had overflow: auto here, which made the
             dialog the scroll container; close/hint are positioned
             against the dialog, so they scrolled away with the diagram
             instead of staying pinned to the viewport. Caught live: opened
             a tall diagram and scrolled down past the hint text. */
          overflow: hidden;
        }

        dialog.sw-mermaid-fullscreen-overlay[open] {
          display: flex;
          align-items: flex-start;
          justify-content: center;
        }

        dialog.sw-mermaid-fullscreen-overlay::backdrop {
          background: rgba(0, 0, 0, 0.75);
        }

        .sw-mermaid-fullscreen-overlay__content {
          position: relative;
          background: var(--sw-surface, #fff);
          border-radius: var(--sw-radius-md, 6px);
          padding: 1.5rem;
          cursor: grab;
          /* No max-width: the whole point is to render the diagram at
             natural (or zoomed) size rather than shrink the SVG to fit.
             max-height IS bounded, to the space the dialog's own padding
             leaves -- that's what makes this the scroll container instead
             of the dialog (see the dialog rule above). */
          max-height: 100%;
          overflow: auto;
          overscroll-behavior: contain;
        }

        .sw-mermaid-fullscreen-overlay__svg-wrapper svg {
          display: block;
          height: auto; /* fallback only -- see cloneSvgWrapper for the real fix */
          /* The real sizing (concrete px width/height from the SVG's own
             viewBox) is set inline via JS (cloneSvgWrapper) -- mermaid's
             width="100%" has nothing solid to resolve against inside
             .content's flex layout otherwise, and no stylesheet rule can
             outrank an inline style regardless. max-width: none here is
             belt-and-suspenders for the same reason. */
          max-width: none;
        }

        /* Positioned against the dialog itself (its nearest positioned
           ancestor once it's the top-layer element), not the viewport --
           no z-index needed inside a top-layer dialog. */
        .sw-mermaid-fullscreen-overlay__close {
          position: absolute;
          top: 1rem;
          right: 1.5rem;
          width: 40px;
          height: 40px;
          display: flex;
          align-items: center;
          justify-content: center;
          background: var(--sw-surface-elevated, #f3f3f3);
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-sm, 4px);
          cursor: pointer;
          font-size: 1.25rem;
          line-height: 1;
          color: var(--sw-text, #111);
        }

        .sw-mermaid-fullscreen-overlay__close:hover {
          background: var(--sw-accent, #0d9488);
          color: #fff;
          border-color: var(--sw-accent, #0d9488);
        }

        .sw-mermaid-fullscreen-overlay__hint {
          position: absolute;
          bottom: 1rem;
          left: 50%;
          transform: translateX(-50%);
          background: var(--sw-surface-elevated, #f3f3f3);
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-sm, 4px);
          padding: 0.35rem 0.75rem;
          font-size: 0.8rem;
          color: var(--sw-text-dim, #6b6860);
          white-space: nowrap;
        }

        /* views.rb sets `html { overflow-x: auto }` on every StreamWeaver
           page, which makes <html> its own scroll container and stops
           <body>'s overflow from propagating to the viewport -- so the
           scroll lock has to sit on <html>, or it locks an element that
           was never the one scrolling in the first place. */
        html.sw-mermaid-fullscreen-open,
        html.sw-mermaid-fullscreen-open body {
          overflow: hidden;
        }

        @media print {
          .sw-mermaid__controls { display: none; }
        }
      CSS

      # =========================================
      # Pipeline rendering (visual skills T12)
      # =========================================

      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Pipeline] The pipeline component
      # @param state [Hash] Current state hash
      def render_pipeline(view, component, state)
        inject_component_css(view, :pipeline, PIPELINE_CSS)

        view.div(class: "sw-pipeline", role: "list") do
          component.steps.each_with_index do |step, idx|
            # Arrow connector between steps (not before first)
            if idx > 0
              view.div(class: "sw-pipeline__arrow", "aria-hidden" => "true") do
                view.raw(view.safe("&#9654;")) # right-pointing triangle
              end
            end

            view.div(class: component.step_css_class(step), role: "listitem") do
              view.div(class: "sw-pipeline__label") { step[:label] }
              if step[:description]
                view.div(class: "sw-pipeline__desc") { step[:description] }
              end
            end
          end
        end
      end

      PIPELINE_CSS = <<~CSS
        /* ===========================================
           Pipeline Component Styles (sw- prefix, T12)
           =========================================== */
        .sw-pipeline {
          display: flex;
          align-items: center;
          gap: 0;
          flex-wrap: nowrap;
          margin: 0.75rem 0;
          overflow-x: auto;
        }

        .sw-pipeline__step {
          flex: 1 1 0;
          min-width: 100px;
          padding: 0.75rem 1rem;
          border-radius: var(--sw-radius-md, 6px);
          text-align: center;
          border: 2px solid transparent;
          transition: background 200ms ease-out, border-color 200ms ease-out;
        }

        .sw-pipeline__step--complete {
          background: color-mix(in oklch, var(--sw-success, #16a34a) 12%, var(--sw-surface, #fff));
          border-color: var(--sw-success, #16a34a);
          color: var(--sw-text, #111);
        }

        .sw-pipeline__step--active {
          background: color-mix(in oklch, var(--sw-info, #2563eb) 12%, var(--sw-surface, #fff));
          border-color: var(--sw-info, #2563eb);
          color: var(--sw-text, #111);
        }

        .sw-pipeline__step--pending {
          background: var(--sw-surface-elevated, #f3f3f3);
          border-color: var(--sw-border, #e0e0e0);
          color: var(--sw-text-dim, #444);
        }

        .sw-pipeline__label {
          font-weight: 600;
          font-size: 0.9rem;
        }

        .sw-pipeline__desc {
          font-size: 0.75rem;
          color: var(--sw-text-dim, #444);
          margin-top: 0.25rem;
        }

        .sw-pipeline__arrow {
          flex: 0 0 auto;
          padding: 0 0.375rem;
          font-size: 0.875rem;
          color: var(--sw-text-dim, #444);
          line-height: 1;
        }

        /* Responsive: vertical layout on narrow screens */
        @media (max-width: 600px) {
          .sw-pipeline {
            flex-direction: column;
            align-items: stretch;
          }

          .sw-pipeline__step {
            min-width: unset;
          }

          .sw-pipeline__arrow {
            transform: rotate(90deg);
            text-align: center;
            padding: 0.25rem 0;
          }
        }
      CSS

      # =========================================
      # KpiDashboard rendering (visual skills T12)
      # =========================================

      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [KpiDashboard] The KPI dashboard component
      # @param state [Hash] Current state hash
      def render_kpi_dashboard(view, component, state)
        inject_component_css(view, :kpi, KPI_DASHBOARD_CSS)

        view.div(class: "sw-kpi-dashboard") do
          component.metrics.each_with_index do |metric, idx|
            view.div(
              class: component.card_css_class(metric),
              style: "animation-delay: #{idx * 80}ms"
            ) do
              view.div(class: "sw-kpi-card__value") { metric[:value] }
              view.div(class: "sw-kpi-card__label") { metric[:label] }
              if metric[:trend]
                view.div(class: component.trend_css_class(metric)) do
                  component.trend_arrow(metric)
                end
              end
            end
          end
        end
      end

      KPI_DASHBOARD_CSS = <<~CSS
        /* ===========================================
           KPI Dashboard Component Styles (sw- prefix, T12)
           =========================================== */
        .sw-kpi-dashboard {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
          gap: var(--sw-spacing-md, 1rem);
          margin: 0.75rem 0;
        }

        @keyframes sw-kpi-fadeIn {
          from {
            opacity: 0;
            transform: translateY(8px) scale(0.97);
          }
          to {
            opacity: 1;
            transform: translateY(0) scale(1);
          }
        }

        .sw-kpi-card {
          background: var(--sw-surface, #fff);
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-md, 6px);
          padding: 1rem;
          text-align: center;
          position: relative;
          animation: sw-kpi-fadeIn 400ms ease-out both;
        }

        .sw-kpi-card--green  { border-left: 4px solid var(--sw-success, #16a34a); }
        .sw-kpi-card--blue   { border-left: 4px solid var(--sw-info, #2563eb); }
        .sw-kpi-card--red    { border-left: 4px solid var(--sw-error, #dc2626); }
        .sw-kpi-card--orange { border-left: 4px solid var(--sw-warning, #d97706); }
        .sw-kpi-card--purple { border-left: 4px solid var(--sw-node-c, #7c3aed); }

        .sw-kpi-card__value {
          font-size: 1.75rem;
          font-weight: 700;
          color: var(--sw-text, #111);
          line-height: 1.2;
        }

        .sw-kpi-card__label {
          font-size: 0.8rem;
          color: var(--sw-text-dim, #444);
          margin-top: 0.25rem;
          text-transform: uppercase;
          letter-spacing: 0.04em;
        }

        .sw-kpi-card__trend {
          font-size: 0.9rem;
          margin-top: 0.375rem;
          font-weight: 600;
        }

        .sw-kpi-card__trend--up   { color: var(--sw-success, #16a34a); }
        .sw-kpi-card__trend--down { color: var(--sw-error, #dc2626); }
        .sw-kpi-card__trend--flat { color: var(--sw-text-dim, #444); }
      CSS

      # =========================================
      # Chart rendering (visual skills T12)
      # =========================================

      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Chart] The chart component
      # @param state [Hash] Current state hash
      def render_chartjs(view, component, state)
        # Inject CSS and Chart.js CDN loader once per render
        unless view.instance_variable_get(:@_chart_assets_injected)
          view.instance_variable_set(:@_chart_assets_injected, true)
          view.style { view.raw(view.safe(StreamWeaver::CSS.layer_wrap(CHART_CSS))) }
          render_chart_cdn_scripts(view)
        end

        view.div(class: "sw-chart") do
          view.canvas(
            id: component.canvas_id,
            class: "sw-chart__canvas",
            height: component.height,
            "data-sw-chart-type" => component.chart_type.to_s,
            "data-sw-chart-data" => component.data_json,
            "data-sw-chart-options" => component.options_json
          )
        end
      end

      # Chart.js CDN loader + dark mode aware init script
      def render_chart_cdn_scripts(view)
        view.script { view.raw(view.safe(CHART_JS_INIT)) }
      end

      CHART_CSS = <<~CSS
        /* ===========================================
           Chart Component Styles (sw- prefix, T12)
           =========================================== */
        .sw-chart {
          position: relative;
          margin: 0.75rem 0;
          padding: 0.5rem;
          background: var(--sw-surface, #fff);
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-md, 6px);
        }

        .sw-chart__canvas {
          width: 100% !important;
        }
      CSS

      CHART_JS_INIT = <<~'JS'
        /* Chart.js lazy loader + dark mode aware init (T12) */
        (function() {
          var SW_CHART_CDN = "https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js";
          var _chartJsLoaded = false;
          var _chartJsLoading = false;

          function getThemeColors() {
            var style = getComputedStyle(document.documentElement);
            return {
              text: style.getPropertyValue('--sw-text').trim() || '#111',
              border: style.getPropertyValue('--sw-border').trim() || '#e0e0e0',
              textDim: style.getPropertyValue('--sw-text-dim').trim() || '#444'
            };
          }

          function initChart(canvas) {
            if (!window.Chart) return;
            var type = canvas.getAttribute('data-sw-chart-type');
            var data = JSON.parse(canvas.getAttribute('data-sw-chart-data'));
            var opts = JSON.parse(canvas.getAttribute('data-sw-chart-options') || '{}');
            var colors = getThemeColors();

            // Apply dark-mode-aware defaults
            if (!opts.plugins) opts.plugins = {};
            if (!opts.plugins.legend) opts.plugins.legend = {};
            if (!opts.plugins.legend.labels) opts.plugins.legend.labels = {};
            opts.plugins.legend.labels.color = opts.plugins.legend.labels.color || colors.text;

            // Scale colors (for bar, line, radar)
            if (['bar', 'line', 'radar'].indexOf(type) !== -1) {
              if (!opts.scales) opts.scales = {};
              ['x', 'y', 'r'].forEach(function(axis) {
                if (!opts.scales[axis]) opts.scales[axis] = {};
                if (!opts.scales[axis].ticks) opts.scales[axis].ticks = {};
                opts.scales[axis].ticks.color = opts.scales[axis].ticks.color || colors.text;
                if (!opts.scales[axis].grid) opts.scales[axis].grid = {};
                opts.scales[axis].grid.color = opts.scales[axis].grid.color || colors.border;
              });
            }

            // Provide default colors for datasets that lack them
            var palette = [
              'rgba(37, 99, 235, 0.7)',
              'rgba(22, 163, 74, 0.7)',
              'rgba(220, 38, 38, 0.7)',
              'rgba(217, 119, 6, 0.7)',
              'rgba(124, 58, 237, 0.7)',
              'rgba(13, 148, 136, 0.7)',
              'rgba(219, 39, 119, 0.7)',
              'rgba(245, 158, 11, 0.7)'
            ];
            (data.datasets || []).forEach(function(ds, i) {
              if (!ds.backgroundColor) {
                if (['pie', 'doughnut'].indexOf(type) !== -1) {
                  ds.backgroundColor = palette;
                } else {
                  ds.backgroundColor = palette[i % palette.length];
                }
              }
              if (!ds.borderColor && ['line', 'radar'].indexOf(type) !== -1) {
                ds.borderColor = palette[i % palette.length];
              }
            });

            new Chart(canvas, { type: type, data: data, options: opts });
          }

          function initAllCharts() {
            var canvases = document.querySelectorAll('.sw-chart__canvas');
            canvases.forEach(function(c) {
              if (!c._swChartInit) {
                c._swChartInit = true;
                initChart(c);
              }
            });
          }

          function loadChartJs() {
            if (_chartJsLoaded) { initAllCharts(); return; }
            if (_chartJsLoading) return;
            _chartJsLoading = true;

            var script = document.createElement('script');
            script.src = SW_CHART_CDN;
            script.onload = function() {
              _chartJsLoaded = true;
              _chartJsLoading = false;
              initAllCharts();
            };
            script.onerror = function() {
              _chartJsLoading = false;
              console.error('[StreamWeaver] Failed to load Chart.js from CDN');
            };
            document.head.appendChild(script);
          }

          // Auto-init on DOM ready
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', loadChartJs);
          } else {
            loadChartJs();
          }

          // Re-init after HTMX swaps (for dynamic content)
          document.addEventListener('htmx:afterSettle', function() {
            if (_chartJsLoaded) initAllCharts();
            else loadChartJs();
          });

          // Expose for manual init
          window.swChartInit = loadChartJs;
        })();
      JS

      # =========================================
      # KeyboardShortcuts rendering (visual skills T5)
      # =========================================

      # Render keyboard shortcuts as a non-visual <script> block.
      # Injects the sw-keyboard.js engine once, then emits registration calls.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [KeyboardShortcuts] The keyboard shortcuts component
      # @param state [Hash] Current state hash
      def render_keyboard_shortcuts(view, component, state)
        inject_keyboard_js(view)

        # Emit registration script
        js_code = component.to_js
        return if js_code.strip.empty?

        view.script do
          view.raw(view.safe("document.addEventListener('DOMContentLoaded', function() {\n#{js_code}\n});"))
        end
      end

      # Inject sw-keyboard.js once per render
      def inject_keyboard_js(view)
        return if view.instance_variable_get(:@_keyboard_js_injected)
        view.instance_variable_set(:@_keyboard_js_injected, true)
        js_path = File.join(__dir__, '..', 'assets', 'js', 'sw-keyboard.js')
        view.script { view.raw(view.safe(File.read(js_path))) } if File.exist?(js_path)
      end

      # =========================================
      # SlideContainer rendering (visual skills T5)
      # =========================================

      # Render a slide container with navigation controls.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [SlideContainer] The slide container component
      # @param state [Hash] Current state hash
      def render_slide_container(view, component, state)
        inject_slide_nav_js(view)
        inject_keyboard_js(view) if component.keyboard_nav
        inject_slide_container_css(view)

        total = component.slide_count
        alpine_data = "swSlideNav(#{total}, '#{component.mode}', #{component.keyboard_nav})"
        container_id = component.container_id

        view.div(
          id: container_id,
          class: component.css_classes,
          "x-data" => alpine_data
        ) do
          # Fixed-position progress bar
          if component.progress_bar
            view.div(
              class: "sw-slide-progress sw-slide-progress--fixed",
              "aria-hidden" => "true"
            ) do
              view.div(
                class: "sw-slide-progress__bar",
                ":style" => "'width: ' + progress() + '%'"
              )
            end
          end

          # Counter (e.g. "2 / 5")
          if component.counter
            view.div(
              class: "sw-slide-counter",
              "x-text" => "(current + 1) + ' / ' + total"
            )
          end

          if component.swap?
            # Swap mode: show one slide at a time
            component.children.each_with_index do |slide_component, index|
              view.div(
                id: "sw-slide-#{index}",
                class: slide_component.css_classes,
                "x-show" => "current === #{index}",
                "x-transition:enter" => "sw-slide-fade-enter",
                "x-transition:enter-start" => "sw-slide-fade-enter-start",
                "x-transition:enter-end" => "sw-slide-fade-enter-end",
                "x-cloak" => (index > 0 ? true : nil)
              ) do
                if slide_component.title
                  view.h2(class: "sw-slide__title") { slide_component.title }
                end
                slide_component.children.each { |child| child.render(view, state) }
              end
            end

            # Back / Next navigation buttons
            view.div(class: "sw-slide-nav") do
              view.button(
                type: "button",
                class: "sw-slide-nav__btn sw-slide-nav__btn--prev",
                "@click" => "prev()",
                ":disabled" => "!canPrev()"
              ) { "Back" }
              view.button(
                type: "button",
                class: "sw-slide-nav__btn sw-slide-nav__btn--next",
                "@click" => "next()",
                ":disabled" => "!canNext()"
              ) { "Next" }
            end
          else
            # Scroll-snap mode: all slides rendered
            view.div(class: "sw-slide-container__scroll") do
              component.children.each_with_index do |slide_component, index|
                view.div(
                  id: "sw-slide-#{index}",
                  class: "#{slide_component.css_classes} sw-slide--snap"
                ) do
                  if slide_component.title
                    view.h2(class: "sw-slide__title") { slide_component.title }
                  end
                  slide_component.children.each { |child| child.render(view, state) }
                end
              end
            end
          end

          # Navigation dots
          if component.nav_dots
            view.div(class: "sw-slide-dots") do
              total.times do |i|
                view.button(
                  type: "button",
                  class: "sw-slide-dots__dot",
                  ":class" => "{ 'sw-slide-dots__dot--active': current === #{i} }",
                  "@click" => "goTo(#{i})",
                  "aria-label" => "Go to slide #{i + 1}"
                )
              end
            end
          end
        end
      end

      # Render an individual slide (when used outside a container)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Slide] The slide component
      # @param state [Hash] Current state hash
      def render_slide(view, component, state)
        view.div(class: component.css_classes) do
          if component.title
            view.h2(class: "sw-slide__title") { component.title }
          end
          component.children.each { |child| child.render(view, state) }
        end
      end

      # =========================================
      # Explainer component rendering (T11)
      # =========================================

      # Render a sticky sidebar TOC with scroll spy.
      # Desktop: sticky 170px sidebar. Mobile: horizontal scrollable bar.

      # Render a non-dismissible callout box with colored left border and icon.

      def render_implementation_map(view, component, state)
        inject_implementation_map_css(view)

        view.div(class: "sw-impl-map") do
          view.dl(class: "sw-impl-map__list") do
            component.files.each do |entry|
              view.div(class: "sw-impl-map__entry") do
                view.dt(class: "sw-impl-map__path") do
                  view.span(class: "sw-impl-map__icon", "aria-hidden" => "true") { view.plain("📄") }
                  view.code { view.plain(entry[:path]) }
                end
                view.dd(class: "sw-impl-map__note") { view.plain(entry[:note]) }
              end
            end
          end
        end
      end

      def render_decision(view, component, state)
        inject_decision_css(view)

        view.div(class: "sw-decision", role: "group") do
          view.h3(class: "sw-decision__question") { view.plain(component.question) }
          view.div(class: "sw-decision__options") do
            component.options.each do |opt|
              modifier = opt.recommended ? "recommended" : "muted"
              view.div(class: "sw-decision__option sw-decision__option--#{modifier}") do
                view.div(class: "sw-decision__option-header") do
                  view.span(class: "sw-decision__option-label") { view.plain(opt.label) }
                  if opt.recommended
                    view.span(class: "sw-decision__badge") { view.plain("Recommended") }
                  end
                end
                view.div(class: "sw-decision__option-detail") { view.plain(opt.detail) }
              end
            end
          end
        end
      end

      # =========================================
      # AnnotatedCode rendering
      # =========================================

      # Keep in sync with .sw-annotated-code__line line-height in annotated_code_css.
      # Also load-bearing for alignment: white-space:pre (no-wrap) ensures each logical line == 1 visual row.
      ANNOTATED_CODE_LINE_HEIGHT_EM = 1.5
      # Note text (0.8125rem) at line-height 1.4, expressed in component em units (base 0.875rem).
      ANNOTATION_NOTE_LINE_HEIGHT_EM = (0.8125 / 0.875 * 1.4).round(4)
      # Conservative char/line estimate for the annotation note area (~150px at 13px font).
      ANNOTATION_CHARS_PER_LINE = 18
      # Min gap between adjacent annotation bubbles.
      ANNOTATION_GAP_EM = 0.375

      # Renders a side-by-side annotated code layout.
      # Left pane: code with line gutter; right pane: annotation bubbles in flex column.
      # Push-down layout: each bubble starts at max(natural_top, prev_bottom + gap), so
      # long notes never overlap the next bubble regardless of wrapping.
      def render_annotated_code(view, component, state)
        inject_prism_cdn(view)
        inject_annotated_code_css(view)

        annotation_margins = compute_annotation_margins(component.annotations)

        view.div(class: "sw-annotated-code") do
          view.div(class: "sw-annotated-code__code-pane") do
            view.pre(class: "sw-annotated-code__pre") do
              component.lines.each_with_index do |line_text, idx|
                line_num = idx + 1
                highlighted = component.annotated_lines.include?(line_num)
                line_class = highlighted ? "sw-annotated-code__line sw-annotated-code__line--highlighted" : "sw-annotated-code__line"
                view.span(class: line_class, "data-line": line_num.to_s) do
                  view.span(class: "sw-annotated-code__gutter") { view.plain(line_num.to_s) }
                  view.code(class: component.language_class) { view.plain(line_text) }
                end
              end
            end
          end

          view.div(class: "sw-annotated-code__panel") do
            annotation_margins.each do |(ann, margin_top)|
              view.div(
                class: "sw-annotated-code__annotation",
                "data-line": ann.line.to_s,
                style: "margin-top: #{margin_top}em;"
              ) do
                view.span(class: "sw-annotated-code__annotation-line") { view.plain(ann.line.to_s) }
                view.span(class: "sw-annotated-code__annotation-note") { view.plain(ann.note) }
              end
            end
          end
        end
      end

      # Push-down layout: returns [[annotation, margin_top_em], ...] for annotations
      # sorted by line number. Each annotation is placed at max(natural_top, prev_bottom + gap),
      # preventing overlap even when notes wrap to multiple lines.
      def compute_annotation_margins(annotations)
        prev_bottom = 0.0
        annotations.sort_by(&:line).map do |ann|
          natural_top = (ann.line - 1) * ANNOTATED_CODE_LINE_HEIGHT_EM
          top = [natural_top, prev_bottom].max
          margin_top = (top - prev_bottom).round(3)

          note_lines = (ann.note.length.to_f / ANNOTATION_CHARS_PER_LINE).ceil.clamp(1, 20)
          prev_bottom = top + note_lines * ANNOTATION_NOTE_LINE_HEIGHT_EM + ANNOTATION_GAP_EM

          [ann, margin_top]
        end
      end




      def render_api_endpoint(view, component, state)
        inject_api_endpoint_css(view)

        view.div(class: "sw-api-endpoint") do
          view.div(class: "sw-api-endpoint__header") do
            view.span(class: "sw-api-endpoint__method",
                      style: "background:#{component.badge_color}") do
              view.plain(component.http_method)
            end
            view.span(class: "sw-api-endpoint__path") { view.plain(component.path) }
          end

          view.p(class: "sw-api-endpoint__description") { view.plain(component.description) } if component.description?

          if component.params?
            view.div(class: "sw-api-endpoint__section") do
              view.p(class: "sw-api-endpoint__section-title") { view.plain("Parameters") }
              view.table(class: "sw-api-endpoint__table") do
                view.thead do
                  view.tr do
                    view.th { view.plain("Name") }
                    view.th { view.plain("Type") }
                    view.th { view.plain("Required") }
                  end
                end
                view.tbody do
                  component.params.each do |param|
                    name     = (param[:name]     || param["name"]     || "").to_s
                    type     = (param[:type]     || param["type"]     || "").to_s
                    required = param.fetch(:required) { param.fetch("required", false) }
                    view.tr do
                      view.td(class: "sw-api-endpoint__param-name") { view.plain(name) }
                      view.td(class: "sw-api-endpoint__param-type") { view.plain(type) }
                      view.td(class: "sw-api-endpoint__param-required") do
                        view.plain(required ? "yes" : "no")
                      end
                    end
                  end
                end
              end
            end
          end

          if component.response?
            view.div(class: "sw-api-endpoint__section") do
              view.p(class: "sw-api-endpoint__section-title") { view.plain("Response") }
              view.div(class: "sw-api-endpoint__response") do
                view.pre(class: "sw-api-endpoint__response-pre") do
                  lines = component.response.map { |k, v| "  #{k}: #{v}" }.join("\n")
                  view.plain("{\n#{lines}\n}")
                end
              end
            end
          end
        end
      end

      def inject_api_endpoint_css(view)
        inject_component_css(view, :api_endpoint, api_endpoint_css)
      end

      def api_endpoint_css
        <<~CSS
          /* -- ApiEndpoint -- */
          .sw-api-endpoint {
            border: 1px solid var(--sw-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            overflow: hidden;
            margin: 0.75rem 0;
            background: var(--sw-surface, #ffffff);
            font-size: 0.875rem;
          }

          .sw-api-endpoint__header {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            padding: 0.6rem 1rem;
            background: color-mix(in oklch, var(--sw-surface, #f8f9fa) 60%, #000 5%);
            border-bottom: 1px solid var(--sw-border, #e0e0e0);
          }

          .sw-api-endpoint__method {
            display: inline-block;
            padding: 0.15rem 0.5rem;
            border-radius: 4px;
            font-weight: 700;
            font-size: 0.75rem;
            letter-spacing: 0.05em;
            color: #ffffff;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            flex-shrink: 0;
          }

          .sw-api-endpoint__path {
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 0.9rem;
            color: var(--sw-text, #111111);
            word-break: break-all;
          }

          .sw-api-endpoint__description {
            padding: 0.6rem 1rem 0;
            color: var(--sw-text-dim, #6b7280);
            font-size: 0.875rem;
            margin: 0;
          }

          .sw-api-endpoint__section {
            padding: 0.75rem 1rem;
            border-top: 1px solid var(--sw-border, #e0e0e0);
          }

          .sw-api-endpoint__section-title {
            font-weight: 600;
            font-size: 0.75rem;
            letter-spacing: 0.06em;
            text-transform: uppercase;
            color: var(--sw-text-dim, #6b7280);
            margin: 0 0 0.5rem;
          }

          .sw-api-endpoint__table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.8125rem;
          }

          .sw-api-endpoint__table th {
            text-align: left;
            padding: 0.3rem 0.5rem;
            font-weight: 600;
            color: var(--sw-text-dim, #6b7280);
            border-bottom: 1px solid var(--sw-border, #e0e0e0);
          }

          .sw-api-endpoint__table td {
            padding: 0.3rem 0.5rem;
            border-bottom: 1px solid color-mix(in oklch, var(--sw-border, #e0e0e0) 50%, transparent);
            color: var(--sw-text, #111111);
          }

          .sw-api-endpoint__param-name {
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-weight: 500;
          }

          .sw-api-endpoint__param-type {
            color: var(--sw-accent-b, #7c3aed);
          }

          .sw-api-endpoint__param-required {
            color: var(--sw-text-dim, #6b7280);
            font-size: 0.75rem;
          }

          .sw-api-endpoint__response {
            background: color-mix(in oklch, var(--sw-surface, #f8f9fa) 60%, #000 3%);
            border-radius: 4px;
            overflow: hidden;
          }

          .sw-api-endpoint__response-pre {
            margin: 0;
            padding: 0.6rem 0.75rem;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 0.8125rem;
            color: var(--sw-text, #111111);
            white-space: pre;
            overflow-x: auto;
          }

          html.dark .sw-api-endpoint {
            background: var(--sw-surface, #1d1f21);
            border-color: var(--sw-border, #374151);
          }

          html.dark .sw-api-endpoint__header {
            background: color-mix(in oklch, #1d1f21 80%, #000 20%);
            border-color: var(--sw-border, #374151);
          }

          html.dark .sw-api-endpoint__path {
            color: var(--sw-text, #e5e7eb);
          }

          html.dark .sw-api-endpoint__table td {
            color: var(--sw-text, #e5e7eb);
          }

          html.dark .sw-api-endpoint__response {
            background: color-mix(in oklch, #1d1f21 80%, #000 20%);
          }

          html.dark .sw-api-endpoint__response-pre {
            color: var(--sw-text, #e5e7eb);
          }
        CSS
      end


      # =========================================
      # DocHeader and DocSectionHeader rendering
      # =========================================






      # -- T11 CSS/JS injection helpers --

      # Registers a component's CSS once per view (deduped by key). On a
      # full-page render (AppView), the view collects this CSS and hoists it
      # into <head> before user stylesheets: links, so equal-specificity
      # ties resolve in the user's favor (document order) instead of always
      # losing to the framework's own rule (stream_weaver-1lo). Fragment
      # views have no <head> to hoist into, so they keep the pre-existing
      # inline-at-first-use behavior.
      def inject_component_css(view, key, css)
        ivar = :"@_#{key}_css_injected"
        return if view.instance_variable_get(ivar)

        view.instance_variable_set(ivar, true)
        if view.respond_to?(:register_component_css)
          view.register_component_css(key, css)
        else
          view.style { view.raw(view.safe(StreamWeaver::CSS.layer_wrap(css))) }
        end
      end

      def inject_sidebar_toc_assets(view)
        return if view.instance_variable_get(:@_sidebar_toc_assets_injected)

        view.instance_variable_set(:@_sidebar_toc_assets_injected, true)
        inject_component_css(view, :sidebar_toc, sidebar_toc_css)
        js_path = File.join(__dir__, '..', 'assets', 'js', 'sw-sidebar-toc.js')
        if File.exist?(js_path)
          view.script { view.raw(view.safe(File.read(js_path))) }
        end
      end


      def inject_date_field_css(view)
        inject_component_css(view, :date_field, date_field_css)
      end

      def inject_accordion_css(view)
        inject_component_css(view, :accordion, accordion_css)
      end

      def inject_chip_group_css(view)
        inject_component_css(view, :chip_group, chip_group_css)
      end

      def inject_board_css(view)
        inject_component_css(view, :board, board_css)
      end

      def inject_topbar_css(view)
        inject_component_css(view, :topbar, topbar_css)
      end



      def inject_implementation_map_css(view)
        inject_component_css(view, :impl_map, implementation_map_css)
      end

      def inject_decision_css(view)
        inject_component_css(view, :decision, decision_css)
      end

      def decision_css
        <<~CSS
          /* ===========================================
             Decision Block Styles (sw- prefix)
             =========================================== */
          .sw-decision {
            margin: 1rem 0;
          }

          .sw-decision__question {
            font-size: 1.0625rem;
            font-weight: 600;
            color: var(--sw-text, #111111);
            margin: 0 0 0.75rem 0;
          }

          .sw-decision__options {
            display: flex;
            flex-wrap: wrap;
            gap: 0.75rem;
          }

          .sw-decision__option {
            flex: 1 1 14rem;
            border: 1px solid var(--sw-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            background: var(--sw-surface, #ffffff);
            padding: 0.875rem 1rem;
          }

          .sw-decision__option--recommended {
            border-color: var(--sw-accent, #2563eb);
            background: color-mix(in oklch, var(--sw-accent, #2563eb) 5%, var(--sw-surface, #ffffff));
          }

          .sw-decision__option--muted {
            opacity: 0.65;
          }

          .sw-decision__option-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 0.5rem;
            margin-bottom: 0.375rem;
          }

          .sw-decision__option-label {
            font-weight: 600;
            font-size: 0.9375rem;
            color: var(--sw-text, #111111);
          }

          .sw-decision__badge {
            font-size: 0.6875rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--sw-accent, #2563eb);
            background: color-mix(in oklch, var(--sw-accent, #2563eb) 12%, var(--sw-surface, #ffffff));
            border: 1px solid color-mix(in oklch, var(--sw-accent, #2563eb) 30%, transparent);
            border-radius: var(--sw-radius-sm, 4px);
            padding: 0.125rem 0.5rem;
            white-space: nowrap;
          }

          .sw-decision__option-detail {
            font-size: 0.875rem;
            color: var(--sw-text-dim, #555555);
            line-height: 1.5;
          }

          html.dark .sw-decision__option {
            background: var(--sw-surface, oklch(0.205 0 0));
          }

          html.dark .sw-decision__option--recommended {
            background: color-mix(in oklch, var(--sw-accent, #60a5fa) 10%, var(--sw-surface, oklch(0.205 0 0)));
            border-color: var(--sw-accent, #60a5fa);
          }

          html.dark .sw-decision__badge {
            color: var(--sw-accent, #60a5fa);
            background: color-mix(in oklch, var(--sw-accent, #60a5fa) 15%, var(--sw-surface, oklch(0.205 0 0)));
            border-color: color-mix(in oklch, var(--sw-accent, #60a5fa) 35%, transparent);
          }
        CSS
      end

      def inject_annotated_code_css(view)
        inject_component_css(view, :annotated_code, annotated_code_css)
      end

      def annotated_code_css
        <<~CSS
          /* ===========================================
             AnnotatedCode Styles (sw- prefix)
             =========================================== */
          .sw-annotated-code {
            display: flex;
            gap: 0;
            border: 1px solid var(--sw-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            overflow: hidden;
            margin: 0.75rem 0;
            background: var(--sw-surface, #1d1f21);
            color: #c5c8c6;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 0.875rem;
          }

          .sw-annotated-code__code-pane {
            flex: 1 1 0;
            overflow: auto;
            min-width: 0;
          }

          .sw-annotated-code__pre {
            margin: 0;
            padding: 0.75rem 0;
            background: transparent;
            white-space: pre;
            overflow-x: auto;
          }

          .sw-annotated-code__line {
            display: block;
            line-height: 1.5em;
            min-height: 1.5em;
            padding: 0 0.75rem 0 0;
          }

          .sw-annotated-code__line--highlighted {
            background: color-mix(in oklch, var(--sw-accent, #2563eb) 12%, transparent);
            border-left: 3px solid var(--sw-accent, #2563eb);
          }

          .sw-annotated-code__gutter {
            display: inline-block;
            width: 2.5rem;
            padding: 0 0.75rem;
            text-align: right;
            color: var(--sw-text-dim, #6b7280);
            user-select: none;
          }

          .sw-annotated-code__line code {
            background: transparent;
            color: inherit;
            padding: 0;
            font-size: inherit;
            font-family: inherit;
            white-space: pre;
          }

          .sw-annotated-code__panel {
            width: 14rem;
            flex-shrink: 0;
            border-left: 1px solid #3a3c3e;
            background: #252729;
            padding: 0.75rem 0;
            display: flex;
            flex-direction: column;
            overflow-x: clip;
          }

          .sw-annotated-code__annotation {
            flex-shrink: 0;
            padding: 0 0.5rem;
            display: flex;
            align-items: flex-start;
            gap: 0.25rem;
          }

          .sw-annotated-code__annotation-line {
            display: inline-block;
            width: 1.25rem;
            font-size: 0.6875rem;
            font-weight: 700;
            color: #6eb6f0;
            flex-shrink: 0;
            padding-top: 0.125rem;
          }

          .sw-annotated-code__annotation-note {
            font-size: 0.8125rem;
            color: #c5c8c6;
            line-height: 1.4;
          }
        CSS
      end


      def date_field_css
        <<~CSS
          /* ===========================================
             DateField Styles (sw- prefix, FAC-P2.2)
             Label/wrapper styling comes from the shared .sw-field /
             .sw-field__label rules (views.rb) via wrap_with_label; only the
             input itself is bespoke here.
             =========================================== */
          .sw-date-input {
            padding: 0.5rem 0.75rem;
            border: 1px solid var(--sw-color-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            background: var(--sw-color-bg-card, #ffffff);
            color: var(--sw-color-text, #111111);
            font-family: inherit;
            font-size: var(--sw-font-size-base, 1rem);
          }

          .sw-date-input:focus {
            outline: none;
            border-color: var(--sw-color-border-focus, var(--sw-color-primary));
          }

          html.dark .sw-date-input {
            color-scheme: dark;
          }
        CSS
      end

      def accordion_css
        <<~CSS
          /* ===========================================
             Accordion Styles (sw- prefix, FAC-P2.2)
             =========================================== */
          .sw-accordion {
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
            margin: 0.75rem 0;
          }

          .sw-accordion__section {
            border: 1px solid var(--sw-color-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            background: var(--sw-color-bg-card, #ffffff);
            overflow: hidden;
          }

          .sw-accordion__summary {
            padding: 0.75rem 1rem;
            font-weight: 600;
            cursor: pointer;
            list-style: none;
            user-select: none;
          }

          .sw-accordion__summary::-webkit-details-marker {
            display: none;
          }

          .sw-accordion__summary::before {
            content: "▶";
            display: inline-block;
            margin-right: 0.5rem;
            font-size: 0.75em;
            transition: transform var(--sw-transition-fast, 120ms) ease-out;
          }

          .sw-accordion__section[open] > .sw-accordion__summary::before {
            transform: rotate(90deg);
          }

          .sw-accordion__body {
            padding: 0 1rem 0.875rem;
            color: var(--sw-color-text, #111111);
          }
        CSS
      end

      def chip_group_css
        <<~CSS
          /* ===========================================
             ChipGroup Styles (sw- prefix, FAC-P2.2)
             =========================================== */
          .sw-chip-group {
            display: flex;
            flex-wrap: wrap;
            gap: 0.5rem;
            margin: 0.5rem 0;
          }

          .sw-chip {
            display: inline-flex;
            align-items: center;
            gap: 0.375rem;
            padding: 0.375rem 0.875rem;
            border: 1px solid var(--sw-color-border, #e0e0e0);
            border-radius: 999px;
            background: var(--sw-color-bg-card, #ffffff);
            color: var(--sw-color-text, #111111);
            font-size: var(--sw-font-size-sm, 0.875rem);
            cursor: pointer;
            transition: all var(--sw-transition-fast, 120ms) ease-out;
          }

          .sw-chip:has(.sw-chip__input:checked) {
            background: var(--sw-color-primary, #c2410c);
            border-color: var(--sw-color-primary, #c2410c);
            color: #ffffff;
          }

          .sw-chip:hover {
            border-color: var(--sw-color-primary, #c2410c);
          }

          .sw-chip__input {
            /* Visually hidden but still focusable/clickable via the label. */
            position: absolute;
            width: 1px;
            height: 1px;
            opacity: 0;
            pointer-events: none;
          }
        CSS
      end

      def board_css
        <<~CSS
          /* ===========================================
             Board (Kanban) Styles (sw- prefix, FAC-P2.2)
             =========================================== */
          .sw-board {
            display: flex;
            gap: var(--sw-spacing-md, 1.25rem);
            overflow-x: auto;
            margin: 0.75rem 0;
            align-items: flex-start;
          }

          .sw-board__lane {
            flex: 1 0 260px;
            min-width: 240px;
            background: var(--sw-color-bg, #f8f8f8);
            border: 1px solid var(--sw-color-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            display: flex;
            flex-direction: column;
          }

          .sw-board--pinned-headers {
            align-items: stretch;
            overflow-y: hidden;
          }

          .sw-board--pinned-headers .sw-board__lane {
            max-height: 100%;
            overflow-y: auto;
          }

          .sw-board--pinned-headers .sw-board__lane-header {
            position: sticky;
            top: 0;
            z-index: 2;
          }

          .sw-board__lane-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 0.5rem;
            padding: 0.75rem 1rem;
            font-weight: 700;
            border-bottom: 1px solid var(--sw-color-border, #e0e0e0);
          }

          .sw-board__lane-icon {
            width: 1.1em;
            height: 1.1em;
            flex-shrink: 0;
            display: inline-flex;
            align-items: center;
            font-size: 1.1em;
            line-height: 1;
            object-fit: contain;
          }

          .sw-board__lane-heading {
            display: flex;
            flex-direction: column;
            gap: 2px;
            min-width: 0;
          }

          .sw-board__lane-title {
            font-weight: 700;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }

          .sw-board__lane-subtitle {
            font-size: var(--sw-font-size-sm, 0.75rem);
            font-weight: 400;
            opacity: 0.75;
          }

          .sw-board__lane-count {
            font-size: 1.1rem;
            font-weight: 700;
            opacity: 0.85;
            flex-shrink: 0;
          }

          /* Semantic lane header tones -- reuse the existing --sw-success/
             warning/error/info tokens (Theme::VARIABLE_SCHEMA) so any theme
             or theme_overrides already flows through, no new tokens needed. */
          .sw-board__lane-header--neutral {
            background: var(--sw-color-bg-elevated, var(--sw-surface-elevated, #e5e5e5));
          }
          .sw-board__lane-header--success {
            background: linear-gradient(180deg, color-mix(in srgb, var(--sw-success, #16a34a) 35%, white), color-mix(in srgb, var(--sw-success, #16a34a) 55%, white));
          }
          .sw-board__lane-header--warning {
            background: linear-gradient(180deg, color-mix(in srgb, var(--sw-warning, #d97706) 45%, white), color-mix(in srgb, var(--sw-warning, #d97706) 65%, white));
          }
          .sw-board__lane-header--error {
            background: linear-gradient(180deg, color-mix(in srgb, var(--sw-error, #dc2626) 40%, white), color-mix(in srgb, var(--sw-error, #dc2626) 60%, white));
          }
          .sw-board__lane-header--info {
            background: linear-gradient(180deg, color-mix(in srgb, var(--sw-info, #2563eb) 35%, white), color-mix(in srgb, var(--sw-info, #2563eb) 55%, white));
          }

          .sw-board__lane-body {
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
            padding: 0.75rem;
          }

          .sw-board__card {
            background: var(--sw-color-bg-card, #ffffff);
            border: 1px solid var(--sw-color-border, #e0e0e0);
            border-radius: var(--sw-radius-sm, 4px);
            padding: 0.75rem;
            box-shadow: var(--sw-shadow-sm);
          }

          /* Semantic card accents -- same BOARD_TONES vocabulary as the lane
             header, so a card can flag itself (blocked/stale/done) without
             a bespoke style: string at every call site. */
          .sw-board__card--success { border-left: 3px solid var(--sw-success, #16a34a); }
          .sw-board__card--warning { border-left: 3px solid var(--sw-warning, #d97706); }
          .sw-board__card--error   { border-left: 3px solid var(--sw-error, #dc2626); }
          .sw-board__card--info    { border-left: 3px solid var(--sw-info, #2563eb); }
        CSS
      end

      def topbar_css
        <<~CSS
          /* ===========================================
             Topbar (app chrome) Styles (sw- prefix, stream_weaver-oeo)
             =========================================== */
          .sw-topbar {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            padding: 0.6rem 1.25rem;
            background: var(--sw-color-bg-card, #ffffff);
            border-bottom: 1px solid var(--sw-color-border, #e0e0e0);
          }

          .sw-topbar-brand {
            display: flex;
            align-items: center;
            gap: 0.5rem;
          }

          .sw-topbar-icon {
            width: 1.6em;
            height: 1.6em;
            flex-shrink: 0;
            display: inline-flex;
            align-items: center;
            font-size: 1.6em;
            line-height: 1;
            object-fit: contain;
          }

          .sw-topbar-wordmark {
            font-weight: 700;
            font-size: 1.1rem;
          }

          .sw-topbar-breadcrumbs {
            display: flex;
            align-items: center;
            gap: 0.4rem;
            font-size: var(--sw-font-size-sm, 0.875rem);
            color: var(--sw-color-text-muted, #6b7280);
            min-width: 0;
          }

          .sw-topbar-separator {
            opacity: 0.6;
          }

          .sw-topbar-crumb--active {
            color: var(--sw-color-text, #111111);
            font-weight: 600;
          }

          .sw-topbar-trailing {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            margin-left: auto;
          }
        CSS
      end



      def implementation_map_css
        <<~CSS
          /* ===========================================
             ImplementationMap Styles (sw- prefix)
             =========================================== */
          .sw-impl-map {
            max-height: 32rem;
            overflow-y: auto;
            border: 1px solid var(--sw-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            background: var(--sw-surface, #ffffff);
            margin: 0.75rem 0;
          }

          .sw-impl-map__list {
            margin: 0;
            padding: 0;
          }

          .sw-impl-map__entry {
            display: flex;
            align-items: baseline;
            gap: 1rem;
            padding: 0.5rem 1rem;
            border-bottom: 1px solid var(--sw-border, #e0e0e0);
          }

          .sw-impl-map__entry:last-child {
            border-bottom: none;
          }

          .sw-impl-map__path {
            flex: 0 0 auto;
            display: flex;
            align-items: center;
            gap: 0.375rem;
            font-size: 0.875rem;
          }

          .sw-impl-map__path code {
            font-family: var(--sw-font-mono, ui-monospace, monospace);
            font-size: 0.8125rem;
            color: var(--sw-accent, #2563eb);
            background: color-mix(in oklch, var(--sw-accent, #2563eb) 8%, var(--sw-surface, #ffffff));
            padding: 0.125rem 0.375rem;
            border-radius: var(--sw-radius-sm, 4px);
          }

          .sw-impl-map__icon {
            font-size: 0.875rem;
            flex-shrink: 0;
          }

          .sw-impl-map__note {
            flex: 1;
            min-width: 0;
            margin: 0;
            font-size: 0.875rem;
            color: var(--sw-text-dim, #555555);
            line-height: 1.5;
          }

          html.dark .sw-impl-map {
            background: var(--sw-surface, oklch(0.205 0 0));
          }

          html.dark .sw-impl-map__path code {
            background: color-mix(in oklch, var(--sw-accent, #60a5fa) 12%, var(--sw-surface, oklch(0.205 0 0)));
            color: var(--sw-accent, #60a5fa);
          }
        CSS
      end

      # =========================================
      # Design Deck rendering (T7)
      # =========================================

      # Render the top-level design deck.
      # Wraps slides in a SlideContainer with :swap mode for navigation.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::DesignDeck] The deck component
      # @param state [Hash] Current state hash
      def render_design_deck(view, component, state)
        inject_deck_css(view)
        inject_slide_nav_js(view)
        inject_keyboard_js(view)
        inject_slide_container_css(view)

        slides = component.children.select { |c| c.is_a?(Components::Deck::DeckSlide) }
        summary = component.children.find { |c| c.is_a?(Components::Deck::DeckSummary) }
        # Total includes regular slides + summary slide
        total = slides.length + (summary ? 1 : 0)
        current_slide = state[:_deck_current_slide] || 0
        alpine_data = "swSlideNav(#{total}, 'swap', true, #{current_slide})"
        container_id = "sw-deck-#{component.object_id}"

        view.div(class: component.css_classes) do
          # Slide container (swap mode)
          view.div(
            id: container_id,
            class: "sw-slide-container sw-slide-container--swap",
            "x-data" => alpine_data,
            ":data-current-slide" => "current"
          ) do
            # Fixed-position progress bar
            view.div(
              class: "sw-slide-progress sw-slide-progress--fixed",
              "aria-hidden" => "true"
            ) do
              view.div(
                class: "sw-slide-progress__bar",
                ":style" => "'width: ' + progress() + '%'"
              )
            end

            # Render each slide with x-show for swap mode
            slides.each_with_index do |deck_slide, index|
              view.div(
                id: "sw-deck-slide-#{deck_slide.id}",
                class: deck_slide.css_classes,
                "x-show" => "current === #{index}",
                "x-transition:enter" => "sw-slide-fade-enter",
                "x-transition:enter-start" => "sw-slide-fade-enter-start",
                "x-transition:enter-end" => "sw-slide-fade-enter-end",
                "x-cloak" => (index > 0 ? true : nil)
              ) do
                render_deck_slide_content(view, deck_slide, state)
              end
            end

            # Render summary slide as last slide (T9)
            if summary
              summary_index = slides.length
              view.div(
                id: "sw-deck-slide-summary",
                class: "sw-deck-slide",
                "x-show" => "current === #{summary_index}",
                "x-transition:enter" => "sw-slide-fade-enter",
                "x-transition:enter-start" => "sw-slide-fade-enter-start",
                "x-transition:enter-end" => "sw-slide-fade-enter-end",
                "x-cloak" => true
              ) do
                summary.render(view, state)
              end
            end

            # Back / Next navigation buttons
            view.div(class: "sw-slide-nav") do
              view.button(
                type: "button",
                class: "sw-slide-nav__btn sw-slide-nav__btn--prev",
                "@click" => "prev()",
                ":disabled" => "!canPrev()"
              ) { "Back" }
              view.button(
                type: "button",
                class: "sw-slide-nav__btn sw-slide-nav__btn--next",
                "@click" => "next()",
                ":disabled" => "!canNext()"
              ) { "Next" }
            end
          end
        end
      end

      # Render a standalone deck slide (when rendered outside of design_deck,
      # e.g. in tests). Normally called via render_design_deck.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::DeckSlide] The slide component
      # @param state [Hash] Current state hash
      def render_deck_slide(view, component, state)
        inject_deck_css(view)
        view.div(class: component.css_classes) do
          render_deck_slide_content(view, component, state)
        end
      end

      # Render a deck option card.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::DeckOption] The option component
      # @param state [Hash] Current state hash
      def render_deck_option(view, component, state)
        inject_deck_css(view)
        inject_deck_selection_js(view)

        # Read selection state from DeckState (T8)
        deck_state = state[:_deck_state]
        slide_id = component.slide_id
        is_selected = deck_state && slide_id && deck_state.selected?(slide_id, component.label)
        note_text = deck_state && slide_id ? deck_state.note(slide_id, component.label) : nil

        aria_hash = { checked: is_selected ? "true" : "false" }
        aria_hash[:label] = component.description if component.description

        attrs = {
          class: component.css_classes(selected: is_selected),
          role: "radio",
          aria: aria_hash,
          tabindex: "0",
          "data-slide-id" => slide_id,
          "data-option-label" => component.label,
          "data-option-index" => component.option_index.to_s,
          "@click" => "swDeckSelect($el)"
        }

        view.div(**attrs) do
          # Radio indicator
          view.div(class: "sw-deck-option__radio") do
            view.div(class: "sw-deck-option__radio-dot")
          end

          # Header with label and optional recommended badge
          view.div(class: "sw-deck-option__header") do
            view.span(class: "sw-deck-option__label") { component.label }
            if component.recommended
              view.span(class: "sw-deck-option__badge") { "Recommended" }
            end
          end

          # Preview content area (children: mermaid, code_block, etc.)
          unless component.children.empty?
            view.div(class: "sw-deck-option__preview") do
              component.children.each { |child| child.render(view, state) }
            end
          end

          # Aside text
          if component.aside
            view.div(class: "sw-deck-option__aside") { component.aside }
          end

          # Notes textarea with persistence (T8)
          view.div(class: "sw-deck-option__notes") do
            view.textarea(
              class: "sw-deck-option__notes-input",
              placeholder: "Add notes...",
              rows: "2",
              "data-slide-id" => slide_id,
              "data-option-label" => component.label,
              "@blur" => "swDeckSaveNote($el)"
            ) { note_text || "" }
          end
        end
      end

      # Render generate-more controls for a slide (T10).
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::GenerateMoreControls] The controls component
      # @param state [Hash] Current state hash
      def render_generate_more_controls(view, component, state)
        inject_deck_css(view)
        inject_generate_more_css(view)
        inject_generate_more_js(view)

        slide_id = component.slide_id
        is_generating = component.generating?
        is_timed_out = component.timed_out?

        view.div(class: component.css_classes, id: "sw-generate-more-#{slide_id}") do
          if is_generating
            # Status banner with cancel button
            view.div(class: "sw-generate-more__status") do
              view.div(class: "sw-generate-more__status-indicator") do
                view.div(class: "sw-generate-more__status-dot")
                view.span(class: "sw-generate-more__status-text") do
                  "Generating #{component.requested_count} option(s)... " \
                  "#{component.received_count}/#{component.requested_count} received"
                end
              end
              view.button(
                type: "button",
                class: "sw-generate-more__btn sw-generate-more__btn--cancel",
                "@click" => "swCancelGenerate()"
              ) { "Cancel" }
            end
          elsif is_timed_out
            # Timeout warning
            view.div(class: "sw-generate-more__timeout") do
              view.span(class: "sw-generate-more__timeout-text") do
                "Generation timed out. " \
                "#{component.received_count}/#{component.requested_count} options received. " \
                "Click Generate to try again."
              end
            end
          end

          unless is_generating
            # Generate form
            view.div(class: "sw-generate-more__form") do
              view.input(
                type: "text",
                class: "sw-generate-more__prompt",
                id: "sw-gen-prompt-#{slide_id}",
                placeholder: "e.g., Focus on event-driven patterns",
                "aria-label" => "Generation prompt"
              )
              view.select(
                class: "sw-generate-more__count",
                id: "sw-gen-count-#{slide_id}",
                "aria-label" => "Number of options"
              ) do
                (1..3).each do |n|
                  attrs = { value: n.to_s }
                  attrs[:selected] = "selected" if n == 2
                  view.option(**attrs) { "#{n} option#{'s' if n > 1}" }
                end
              end
              view.button(
                type: "button",
                class: "sw-generate-more__btn sw-generate-more__btn--generate",
                "@click" => "swGenerate('#{slide_id}')"
              ) { "Generate More" }
            end
          end
        end
      end

      # Render a skeleton placeholder card (T10).
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::SkeletonPlaceholder] The skeleton component
      # @param state [Hash] Current state hash
      def render_skeleton_placeholder(view, component, state)
        inject_generate_more_css(view)

        delay = component.index * 0.2
        view.div(class: component.css_classes) do
          view.div(
            class: "sw-skeleton__line sw-skeleton__line--title",
            style: "animation-delay: #{delay}s"
          )
          view.div(
            class: "sw-skeleton__line sw-skeleton__line--body",
            style: "animation-delay: #{delay + 0.15}s"
          )
          view.div(
            class: "sw-skeleton__line sw-skeleton__line--body sw-skeleton__line--short",
            style: "animation-delay: #{delay + 0.3}s"
          )
        end
      end

      # Render the auto-generated deck summary slide (T9).
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::DeckSummary] The summary component
      # @param state [Hash] Current state hash
      def render_deck_summary(view, component, state)
        inject_deck_css(view)
        inject_deck_summary_js(view)

        deck_state = state[:_deck_state]
        is_complete = component.all_selected?(deck_state)
        is_submitted = deck_state&.submitted? || false
        missing = component.missing_slides(deck_state)
        final_notes_text = deck_state&.final_notes || ""

        view.div(class: component.css_classes) do
          view.h2(class: "sw-deck-summary__title") { "Summary" }

          # Summary cards grid
          view.div(class: "sw-deck-summary__cards") do
            component.deck_slides.each do |slide|
              selected_label = deck_state&.selection(slide.id)
              has_selection = !selected_label.nil? && !selected_label.empty?
              note_text = has_selection ? deck_state&.note(slide.id, selected_label) : nil
              card_class = "sw-deck-summary__card"
              card_class += " sw-deck-summary__card--empty" unless has_selection

              view.div(class: card_class) do
                view.div(class: "sw-deck-summary__card-title") { slide.title || slide.id }
                if has_selection
                  view.div(class: "sw-deck-summary__card-label") { selected_label }
                  # Find the option's aside text
                  option = slide.children.find { |c|
                    c.is_a?(Components::Deck::DeckOption) && c.label == selected_label
                  }
                  if option&.aside
                    view.div(class: "sw-deck-summary__card-aside") { option.aside }
                  end
                  if note_text && !note_text.empty?
                    view.div(class: "sw-deck-summary__card-notes") do
                      view.span(class: "sw-deck-summary__card-notes-label") { "Notes: " }
                      view.span { note_text }
                    end
                  end
                else
                  view.div(class: "sw-deck-summary__card-label sw-deck-summary__card-label--none") { "No selection" }
                end
              end
            end
          end

          # Missing selections message
          unless is_complete
            view.div(class: "sw-deck-summary__missing") do
              "Still need: #{missing.join(', ')}"
            end
          end

          # Final notes textarea
          view.div(class: "sw-deck-summary__final-notes") do
            view.label(class: "sw-deck-summary__final-notes-label") { "Final notes" }
            view.textarea(
              class: "sw-deck-summary__final-notes-input",
              placeholder: "Add any overall comments...",
              rows: "3",
              "@blur" => "swDeckSaveFinalNotes($el)",
              disabled: is_submitted ? true : nil
            ) { final_notes_text }
          end

          # Submit button
          if is_submitted
            view.div(class: "sw-deck-summary__submitted") { "Submitted" }
          else
            btn_class = "sw-deck-summary__submit"
            btn_class += " sw-deck-summary__submit--disabled" unless is_complete
            view.button(
              type: "button",
              class: btn_class,
              disabled: is_complete ? nil : true,
              "@click" => "swDeckSubmit()"
            ) { "Submit" }
          end
        end
      end

      # Render an AI model selector with provider filter pills (T14).
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::ModelSelector] The model selector component
      # @param state [Hash] Current state hash
      def render_model_selector(view, component, state)
        return unless component.visible?

        inject_deck_polish_css(view)

        deck_state = state[:_deck_state]
        current_model = deck_state&.selected_model || component.default_model
        providers = ["All"] + component.providers

        alpine_data = "{ provider: 'All', selectedModel: '#{current_model}' }"

        view.div(class: component.css_classes, "x-data" => alpine_data) do
          # Provider filter pills
          view.div(class: "sw-model-selector__pills") do
            providers.each do |prov|
              pill_bind = ":class=\"provider === '#{prov}' ? 'sw-model-selector__pill sw-model-selector__pill--active' : 'sw-model-selector__pill'\""
              view.button(
                type: "button",
                class: "sw-model-selector__pill",
                ":class" => "provider === '#{prov}' ? 'sw-model-selector__pill sw-model-selector__pill--active' : 'sw-model-selector__pill'",
                "@click" => "provider = '#{prov}'"
              ) { prov }
            end
          end

          # Model list
          view.div(class: "sw-model-selector__list") do
            component.models.each do |model|
              item_show = "provider === 'All' || provider === '#{model[:provider]}'"
              view.div(
                class: "sw-model-selector__item",
                ":class" => "selectedModel === '#{model[:id]}' ? 'sw-model-selector__item sw-model-selector__item--selected' : 'sw-model-selector__item'",
                "x-show" => item_show,
                "@click" => "selectedModel = '#{model[:id]}'; fetch('/deck/set_model', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ model_id: '#{model[:id]}' }) })",
                "data-model-id" => model[:id]
              ) do
                view.span(class: "sw-model-selector__name") { model[:name] }
                view.span(class: "sw-model-selector__provider") { model[:provider] }
              end
            end
          end
        end
      end

      # Render a fixed top confirmation bar (T14).
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::ConfirmationBar] The confirmation bar component
      # @param state [Hash] Current state hash
      def render_confirmation_bar(view, component, state)
        inject_deck_polish_css(view)

        auto_hide_js = if component.auto_hide?
          "{ visible: true, remaining: #{component.auto_hide}, " \
          "init() { this.interval = setInterval(() => { this.remaining--; if (this.remaining <= 0) { this.visible = false; clearInterval(this.interval); } }, 1000); }, " \
          "dismiss() { this.visible = false; clearInterval(this.interval); } }"
        else
          "{ visible: true, remaining: null, dismiss() { this.visible = false; } }"
        end

        view.div(
          class: component.css_classes,
          "x-data" => auto_hide_js,
          "x-show" => "visible",
          "x-transition:enter" => "sw-confirmation-bar-enter",
          "x-transition:enter-start" => "sw-confirmation-bar-enter-start",
          "x-transition:enter-end" => "sw-confirmation-bar-enter-end",
          "x-transition:leave" => "sw-confirmation-bar-leave",
          "x-transition:leave-start" => "sw-confirmation-bar-leave-start",
          "x-transition:leave-end" => "sw-confirmation-bar-leave-end",
          role: "alertdialog",
          "aria-label" => component.message
        ) do
          view.span(class: "sw-confirmation-bar__message") { component.message }

          view.div(class: "sw-confirmation-bar__actions") do
            if component.auto_hide?
              view.span(
                class: "sw-confirmation-bar__timer",
                "x-text" => "remaining + 's'"
              )
            end

            view.button(
              type: "button",
              class: "sw-confirmation-bar__btn sw-confirmation-bar__btn--cancel",
              "@click" => "dismiss()"
            ) { component.cancel_label }

            view.button(
              type: "button",
              class: "sw-confirmation-bar__btn sw-confirmation-bar__btn--confirm",
              "@click" => "$dispatch('sw-confirm')"
            ) { component.confirm_label }
          end
        end
      end

      # Render a full-screen close overlay (T14).
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Deck::CloseOverlay] The overlay component
      # @param state [Hash] Current state hash
      def render_close_overlay(view, component, state)
        inject_deck_polish_css(view)

        countdown_s = (component.auto_close_delay / 1000.0).round(1)
        auto_close_js = "{ countdown: #{countdown_s}, " \
          "init() { setTimeout(() => { try { window.close(); } catch(e) {} }, #{component.auto_close_delay}); " \
          "this.interval = setInterval(() => { this.countdown = Math.max(0, (this.countdown - 0.1).toFixed(1)); }, 100); } }"

        view.div(
          class: component.css_classes,
          "x-data" => auto_close_js,
          role: "status",
          "aria-live" => "polite"
        ) do
          view.div(class: "sw-close-overlay__backdrop")

          view.div(class: "sw-close-overlay__content") do
            # Status icon
            icon_class = "sw-close-overlay__icon"
            icon_class += component.submitted? ? " sw-close-overlay__icon--success" : " sw-close-overlay__icon--cancel"
            view.div(class: icon_class) { component.icon }

            # Message
            view.div(class: "sw-close-overlay__message") { component.message }

            # Countdown
            view.div(
              class: "sw-close-overlay__countdown",
              "x-text" => "'Closing in ' + countdown + 's...'"
            )

            # Manual close button
            view.button(
              type: "button",
              class: "sw-close-overlay__close-btn",
              "@click" => "try { window.close(); } catch(e) { document.body.innerHTML = '<p style=\"text-align:center;margin-top:2rem\">You can close this tab.</p>'; }"
            ) { "Close Now" }
          end
        end
      end

      private

      # Render the inner content of a deck slide (title, context, options grid)
      def render_deck_slide_content(view, component, state)
        # Slide title
        if component.title
          view.h2(class: "sw-deck-slide__title") { component.title }
        end

        # Context text
        if component.context_text
          view.p(class: "sw-deck-slide__context") { component.context_text }
        end

        # Check for generated options and generate state from DeckState (T10)
        deck_state = state[:_deck_state]
        gen_state = deck_state ? deck_state.generate_state : { "status" => "idle" }
        generated_opts = deck_state ? deck_state.generated_options(component.id) : []
        is_generating = gen_state["status"] == "generating" && gen_state["slide_id"] == component.id
        remaining = is_generating ? [gen_state["requested_count"].to_i - gen_state["received_count"].to_i, 0].max : 0

        # Count total options (defined + generated) for auto-columns
        total_option_count = component.option_count + generated_opts.size + remaining
        cols = component.columns || (
          case total_option_count
          when 0, 1 then 1
          when 2 then 2
          when 3 then 3
          else 2
          end
        )
        grid_style = "grid-template-columns: repeat(#{cols}, 1fr);"

        view.div(
          class: "sw-deck-slide__grid",
          role: "radiogroup",
          "aria-label" => component.title || "Options",
          style: grid_style
        ) do
          # Render defined options (from DSL)
          component.children.each { |child| child.render(view, state) }

          # Render generated options (from DeckState, pushed by agent) (T10)
          generated_opts.each do |opt_data|
            gen_opt = Components::Deck::DeckOption.new(
              opt_data["label"] || "Generated",
              aside: opt_data["aside"] || opt_data["description"],
              description: opt_data["description"]
            )
            gen_opt.slide_id = component.id
            gen_opt.option_index = component.option_count + generated_opts.index(opt_data)
            gen_opt.render(view, state)
          end

          # Render skeleton placeholders for pending options (T10)
          remaining.times do |i|
            skeleton = Components::Deck::SkeletonPlaceholder.new(index: i)
            skeleton.render(view, state)
          end
        end

        # Generate-more controls (T10)
        if deck_state
          controls = Components::Deck::GenerateMoreControls.new(
            component.id,
            generate_state: gen_state
          )
          controls.render(view, state)
        end
      end

      public

      # Inject deck CSS once per render
      def inject_deck_css(view)
        inject_component_css(view, :deck, DECK_CSS)
      end

      # Inject deck selection JS once per render (T8)
      def inject_deck_selection_js(view)
        return if view.instance_variable_get(:@_deck_selection_js_injected)
        view.instance_variable_set(:@_deck_selection_js_injected, true)
        view.script { view.raw(view.safe(DECK_SELECTION_JS)) }
      end

      # JavaScript for deck option selection and note persistence (T8)
      DECK_SELECTION_JS = <<~JS
        // Read current slide index from the DOM (set by Alpine :data-current-slide binding)
        function swDeckCurrentSlide() {
          var el = document.querySelector('.sw-slide-container--swap');
          return el ? parseInt(el.dataset.currentSlide || '0', 10) : 0;
        }

        // Fetch fresh HTML from /deck/refresh, replace #app-container innerHTML,
        // and re-initialize Alpine on the new DOM tree.
        function swDeckRefresh() {
          fetch('/deck/refresh?slide=' + swDeckCurrentSlide()).then(function(resp) {
            return resp.text();
          }).then(function(html) {
            var container = document.getElementById('app-container');
            if (!container) return;
            // Destroy Alpine state on old children
            Alpine.destroyTree(container);
            container.innerHTML = html;
            // Initialize Alpine on the new DOM
            Alpine.initTree(container);
          });
        }

        // Select a deck option (radio semantics per slide)
        function swDeckSelect(el) {
          // Don't select if clicking on the notes textarea
          if (document.activeElement && document.activeElement.classList.contains('sw-deck-option__notes-input')) return;

          var slideId = el.dataset.slideId;
          var optionLabel = el.dataset.optionLabel;
          if (!slideId || !optionLabel) return;

          // Visual update: deselect all siblings in the same radiogroup
          var grid = el.closest('[role="radiogroup"]');
          if (grid) {
            grid.querySelectorAll('.sw-deck-option').forEach(function(opt) {
              opt.classList.remove('sw-deck-option--selected');
              opt.setAttribute('aria-checked', 'false');
            });
          }
          el.classList.add('sw-deck-option--selected');
          el.setAttribute('aria-checked', 'true');

          // Persist to server, then re-render (StreamWeaver model)
          fetch('/deck/select', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ slide_id: slideId, option_label: optionLabel })
          }).then(function() {
            swDeckRefresh();
          });
        }

        // Save note on blur
        function swDeckSaveNote(textarea) {
          var slideId = textarea.dataset.slideId;
          var optionLabel = textarea.dataset.optionLabel;
          if (!slideId || !optionLabel) return;

          fetch('/deck/note', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ slide_id: slideId, option_label: optionLabel, text: textarea.value })
          }).then(function() {
            swDeckRefresh();
          });
        }

        // Number key quick-select (1-9) for deck options
        document.addEventListener('keydown', function(e) {
          // Suppress when typing in inputs
          if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT') return;
          if (e.target.isContentEditable) return;
          if (e.altKey || e.ctrlKey || e.metaKey) return;

          var num = parseInt(e.key);
          if (num >= 1 && num <= 9) {
            // Find the currently visible slide
            var visibleSlide = document.querySelector('.sw-deck-slide:not([style*="display: none"])');
            if (!visibleSlide) {
              // Try x-show based visibility (Alpine)
              var allSlides = document.querySelectorAll('.sw-deck-slide');
              for (var i = 0; i < allSlides.length; i++) {
                if (allSlides[i].offsetParent !== null || allSlides[i].style.display !== 'none') {
                  visibleSlide = allSlides[i];
                  break;
                }
              }
            }
            if (!visibleSlide) return;

            var options = visibleSlide.querySelectorAll('.sw-deck-option');
            var target = options[num - 1];
            if (target) {
              e.preventDefault();
              swDeckSelect(target);
            }
          }
        });
      JS

      # Inject deck summary JS once per render (T9)
      def inject_deck_summary_js(view)
        return if view.instance_variable_get(:@_deck_summary_js_injected)
        view.instance_variable_set(:@_deck_summary_js_injected, true)
        view.script { view.raw(view.safe(DECK_SUMMARY_JS)) }
      end

      # JavaScript for deck summary submit and final notes (T9)
      DECK_SUMMARY_JS = <<~JS
        // Save final notes on blur
        function swDeckSaveFinalNotes(textarea) {
          fetch('/deck/final_notes', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ text: textarea.value })
          }).then(function() {
            swDeckRefresh();
          });
        }

        // Submit the deck (sends selections + notes as _result)
        function swDeckSubmit() {
          fetch('/deck/submit', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
          }).then(function(resp) {
            if (resp.ok) {
              // Reload to show submitted state
              window.location.reload();
            }
          });
        }
      JS

      # Inject generate-more CSS once per render (T10)
      def inject_generate_more_css(view)
        inject_component_css(view, :generate_more, GENERATE_MORE_CSS)
      end

      # Inject generate-more JS once per render (T10)
      def inject_generate_more_js(view)
        return if view.instance_variable_get(:@_generate_more_js_injected)
        view.instance_variable_set(:@_generate_more_js_injected, true)
        view.script { view.raw(view.safe(GENERATE_MORE_JS)) }
      end

      # JavaScript for generate-more controls (T10)
      GENERATE_MORE_JS = <<~JS
        // Request more options via the generate endpoint
        function swGenerate(slideId) {
          var promptEl = document.getElementById('sw-gen-prompt-' + slideId);
          var countEl = document.getElementById('sw-gen-count-' + slideId);
          var prompt = promptEl ? promptEl.value : '';
          var count = countEl ? parseInt(countEl.value) : 2;

          fetch('/deck/generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ slide_id: slideId, count: count, prompt: prompt })
          }).then(function(resp) {
            if (!resp.ok) {
              console.error('Generate request failed:', resp.status);
            }
            // SSE will push the re-render with skeletons
          }).catch(function(err) {
            console.error('Generate request error:', err);
          });
        }

        // Cancel a pending generation
        function swCancelGenerate() {
          fetch('/deck/cancel_generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
          }).then(function(resp) {
            if (!resp.ok) {
              console.error('Cancel request failed:', resp.status);
            }
            // SSE will push the re-render
          }).catch(function(err) {
            console.error('Cancel request error:', err);
          });
        }
      JS

      # CSS for generate-more controls and skeleton placeholders (T10)
      GENERATE_MORE_CSS = <<~CSS
        /* ===========================================
           Generate-More Controls (sw- prefix, T10)
           =========================================== */

        .sw-generate-more {
          margin-top: 1.25rem;
          padding-top: 1rem;
          border-top: 1px solid var(--sw-border, #e0e0e0);
        }

        .sw-generate-more__form {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          flex-wrap: wrap;
        }

        .sw-generate-more__prompt {
          flex: 1;
          min-width: 180px;
          padding: 0.5rem 0.75rem;
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-sm, 4px);
          background: var(--sw-surface, #ffffff);
          color: var(--sw-text, #1a1a2e);
          font-size: 0.875rem;
          font-family: inherit;
        }

        .sw-generate-more__prompt:focus {
          outline: 2px solid var(--sw-accent, #6366f1);
          outline-offset: -1px;
          border-color: var(--sw-accent, #6366f1);
        }

        .sw-generate-more__prompt::placeholder {
          color: var(--sw-text-dim, #999);
        }

        .sw-generate-more__count {
          padding: 0.5rem 0.75rem;
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-sm, 4px);
          background: var(--sw-surface, #ffffff);
          color: var(--sw-text, #1a1a2e);
          font-size: 0.875rem;
          font-family: inherit;
          cursor: pointer;
        }

        .sw-generate-more__btn {
          padding: 0.5rem 1rem;
          border: none;
          border-radius: var(--sw-radius-sm, 4px);
          font-size: 0.875rem;
          font-weight: 600;
          cursor: pointer;
          transition: background 0.15s, opacity 0.15s;
          font-family: inherit;
        }

        .sw-generate-more__btn--generate {
          background: var(--sw-accent, #6366f1);
          color: #ffffff;
        }

        .sw-generate-more__btn--generate:hover {
          opacity: 0.9;
        }

        .sw-generate-more__btn--cancel {
          background: #dc2626;
          color: #ffffff;
        }

        .sw-generate-more__btn--cancel:hover {
          opacity: 0.9;
        }

        /* Status banner */
        .sw-generate-more__status {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 0.75rem;
          padding: 0.75rem 1rem;
          background: color-mix(in srgb, var(--sw-accent, #6366f1) 10%, var(--sw-surface, #ffffff));
          border: 1px solid color-mix(in srgb, var(--sw-accent, #6366f1) 30%, transparent);
          border-radius: var(--sw-radius-md, 6px);
          margin-bottom: 0.75rem;
        }

        .sw-generate-more__status-indicator {
          display: flex;
          align-items: center;
          gap: 0.5rem;
        }

        .sw-generate-more__status-dot {
          width: 10px;
          height: 10px;
          border-radius: 50%;
          background: var(--sw-accent, #6366f1);
          animation: sw-pulse 1s ease-in-out infinite;
        }

        .sw-generate-more__status-text {
          font-size: 0.875rem;
          color: var(--sw-text, #1a1a2e);
        }

        /* Timeout warning */
        .sw-generate-more__timeout {
          padding: 0.75rem 1rem;
          background: color-mix(in srgb, #f59e0b 10%, var(--sw-surface, #ffffff));
          border: 1px solid color-mix(in srgb, #f59e0b 40%, transparent);
          border-radius: var(--sw-radius-md, 6px);
          margin-bottom: 0.75rem;
        }

        .sw-generate-more__timeout-text {
          font-size: 0.875rem;
          color: var(--sw-text, #1a1a2e);
        }

        /* ===========================================
           Skeleton Placeholder (sw- prefix, T10)
           =========================================== */

        .sw-skeleton {
          border: 2px dashed var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-lg, 12px);
          padding: 1rem;
          background: var(--sw-surface, #ffffff);
        }

        .sw-skeleton__line {
          border-radius: var(--sw-radius-sm, 4px);
          background: var(--sw-border, #e0e0e0);
          animation: sw-shimmer 1.5s ease-in-out infinite alternate;
        }

        .sw-skeleton__line--title {
          height: 20px;
          width: 55%;
          margin-bottom: 0.75rem;
        }

        .sw-skeleton__line--body {
          height: 14px;
          width: 85%;
          margin-bottom: 0.5rem;
        }

        .sw-skeleton__line--short {
          width: 65%;
        }

        @keyframes sw-shimmer {
          from { opacity: 0.4; }
          to { opacity: 1; }
        }

        @keyframes sw-pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.3; }
        }

        /* Responsive */
        @media (max-width: 640px) {
          .sw-generate-more__form {
            flex-direction: column;
            align-items: stretch;
          }
        }
      CSS

      # Inject deck polish CSS once per render (T14)
      def inject_deck_polish_css(view)
        inject_component_css(view, :deck_polish, DECK_POLISH_CSS)
      end

      # CSS for deck polish components: ModelSelector, ConfirmationBar, CloseOverlay (T14)
      DECK_POLISH_CSS = <<~CSS
        /* ===========================================
           Model Selector (sw- prefix, T14)
           =========================================== */

        .sw-model-selector {
          margin: 1rem 0;
          padding: 1rem;
          background: var(--sw-surface, #ffffff);
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-md, 6px);
        }

        .sw-model-selector__pills {
          display: flex;
          gap: 0.375rem;
          margin-bottom: 0.75rem;
          flex-wrap: wrap;
        }

        .sw-model-selector__pill {
          padding: 0.25rem 0.75rem;
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: 9999px;
          background: transparent;
          color: var(--sw-text-dim, #666);
          font-size: 0.8125rem;
          font-family: inherit;
          cursor: pointer;
          transition: background 150ms, color 150ms, border-color 150ms;
        }

        .sw-model-selector__pill:hover {
          background: var(--sw-surface-elevated, #f5f5f5);
          color: var(--sw-text, #1a1a2e);
        }

        .sw-model-selector__pill--active {
          background: var(--sw-accent, #6366f1);
          color: #ffffff;
          border-color: var(--sw-accent, #6366f1);
        }

        .sw-model-selector__pill--active:hover {
          background: var(--sw-accent, #6366f1);
          color: #ffffff;
        }

        .sw-model-selector__list {
          display: flex;
          flex-direction: column;
          gap: 0.25rem;
        }

        .sw-model-selector__item {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 0.5rem 0.75rem;
          border-radius: var(--sw-radius-sm, 4px);
          cursor: pointer;
          transition: background 150ms;
        }

        .sw-model-selector__item:hover {
          background: var(--sw-surface-elevated, #f5f5f5);
        }

        .sw-model-selector__item--selected {
          background: color-mix(in srgb, var(--sw-accent, #6366f1) 10%, var(--sw-surface, #ffffff));
          border: 1px solid color-mix(in srgb, var(--sw-accent, #6366f1) 30%, transparent);
        }

        .sw-model-selector__name {
          font-weight: 500;
          font-size: 0.875rem;
          color: var(--sw-text, #1a1a2e);
        }

        .sw-model-selector__provider {
          font-size: 0.75rem;
          color: var(--sw-text-dim, #999);
        }

        /* ===========================================
           Confirmation Bar (sw- prefix, T14)
           =========================================== */

        .sw-confirmation-bar {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          z-index: 9999;
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 0.75rem 1.5rem;
          background: var(--sw-surface-elevated, #2a2a3e);
          color: var(--sw-text, #ffffff);
          box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
          font-family: inherit;
        }

        .sw-confirmation-bar-enter {
          transition: transform 300ms ease-out, opacity 300ms ease-out;
        }
        .sw-confirmation-bar-enter-start {
          transform: translateY(-100%);
          opacity: 0;
        }
        .sw-confirmation-bar-enter-end {
          transform: translateY(0);
          opacity: 1;
        }
        .sw-confirmation-bar-leave {
          transition: transform 200ms ease-in, opacity 200ms ease-in;
        }
        .sw-confirmation-bar-leave-start {
          transform: translateY(0);
          opacity: 1;
        }
        .sw-confirmation-bar-leave-end {
          transform: translateY(-100%);
          opacity: 0;
        }

        .sw-confirmation-bar__message {
          font-size: 0.9375rem;
          font-weight: 500;
        }

        .sw-confirmation-bar__actions {
          display: flex;
          align-items: center;
          gap: 0.5rem;
        }

        .sw-confirmation-bar__timer {
          font-size: 0.8125rem;
          color: var(--sw-text-dim, #aaa);
          min-width: 2ch;
        }

        .sw-confirmation-bar__btn {
          padding: 0.375rem 0.875rem;
          border: none;
          border-radius: var(--sw-radius-sm, 4px);
          font-size: 0.8125rem;
          font-weight: 600;
          cursor: pointer;
          transition: opacity 150ms;
          font-family: inherit;
        }

        .sw-confirmation-bar__btn:hover {
          opacity: 0.85;
        }

        .sw-confirmation-bar__btn--confirm {
          background: #dc2626;
          color: #ffffff;
        }

        .sw-confirmation-bar__btn--cancel {
          background: var(--sw-surface, rgba(255,255,255,0.15));
          color: var(--sw-text, #ffffff);
        }

        /* ===========================================
           Close Overlay (sw- prefix, T14)
           =========================================== */

        .sw-close-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          z-index: 10000;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .sw-close-overlay__backdrop {
          position: absolute;
          inset: 0;
          background: rgba(0, 0, 0, 0.5);
          backdrop-filter: blur(8px);
          -webkit-backdrop-filter: blur(8px);
        }

        .sw-close-overlay__content {
          position: relative;
          z-index: 1;
          text-align: center;
          padding: 2.5rem;
          background: var(--sw-surface, #ffffff);
          border-radius: var(--sw-radius-lg, 12px);
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.25);
          max-width: 420px;
          width: 90%;
        }

        .sw-close-overlay__icon {
          font-size: 3rem;
          margin-bottom: 1rem;
          width: 4rem;
          height: 4rem;
          border-radius: 50%;
          display: inline-flex;
          align-items: center;
          justify-content: center;
        }

        .sw-close-overlay__icon--success {
          background: #dcfce7;
          color: #16a34a;
        }

        .sw-close-overlay__icon--cancel {
          background: #fef3c7;
          color: #d97706;
        }

        .sw-close-overlay--submitted .sw-close-overlay__content {
          border-top: 4px solid #16a34a;
        }

        .sw-close-overlay--cancelled .sw-close-overlay__content {
          border-top: 4px solid #d97706;
        }

        .sw-close-overlay__message {
          font-size: 1.125rem;
          font-weight: 600;
          color: var(--sw-text, #1a1a2e);
          margin-bottom: 0.75rem;
        }

        .sw-close-overlay__countdown {
          font-size: 0.8125rem;
          color: var(--sw-text-dim, #999);
          margin-bottom: 1rem;
        }

        .sw-close-overlay__close-btn {
          padding: 0.5rem 1.5rem;
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-sm, 4px);
          background: transparent;
          color: var(--sw-text, #1a1a2e);
          font-size: 0.875rem;
          cursor: pointer;
          transition: background 150ms;
          font-family: inherit;
        }

        .sw-close-overlay__close-btn:hover {
          background: var(--sw-surface-elevated, #f5f5f5);
        }
      CSS

      # CSS for design deck components
      DECK_CSS = <<~CSS
        /* ===========================================
           Design Deck Styles (sw- prefix, T7)
           =========================================== */

        .sw-deck {
          max-width: 1200px;
          margin: 0 auto;
          padding: 1rem;
        }

        .sw-deck__title {
          font-size: 1.75rem;
          font-weight: 700;
          margin-bottom: 1.5rem;
          color: var(--sw-text, #1a1a2e);
        }

        /* Deck container: fit within viewport so nav buttons stay visible */
        .sw-deck .sw-slide-container--swap {
          display: flex;
          flex-direction: column;
          max-height: calc(100vh - 120px);
        }

        .sw-deck .sw-slide-container--swap > .sw-deck-slide {
          flex: 1 1 auto;
          overflow-y: auto;
          min-height: 0;
        }

        .sw-deck .sw-slide-container--swap > .sw-slide-nav {
          flex-shrink: 0;
        }

        /* Deck Slide */
        .sw-deck-slide {
          padding: 1rem 0;
        }

        .sw-deck-slide__title {
          font-size: 1.375rem;
          font-weight: 600;
          margin-bottom: 0.75rem;
          color: var(--sw-text, #1a1a2e);
        }

        .sw-deck-slide__context {
          font-size: 0.9375rem;
          color: var(--sw-text-dim, #666);
          margin-bottom: 1.25rem;
          line-height: 1.5;
        }

        .sw-deck-slide__grid {
          display: grid;
          gap: 1rem;
        }

        /* Deck Option Card */
        .sw-deck-option {
          position: relative;
          border: 2px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-lg, 12px);
          padding: 1rem;
          background: var(--sw-surface, #ffffff);
          cursor: pointer;
          transition: border-color 0.2s, box-shadow 0.2s;
          min-width: 0;
          overflow: hidden;
        }

        .sw-deck-option:hover {
          border-color: var(--sw-accent, #6366f1);
          box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
        }

        .sw-deck-option:focus-visible {
          outline: 2px solid var(--sw-accent, #6366f1);
          outline-offset: 2px;
        }

        .sw-deck-option--recommended {
          border-color: var(--sw-accent, #6366f1);
        }

        /* Selected state (T8) */
        .sw-deck-option--selected {
          border-color: var(--sw-accent, #6366f1);
          box-shadow: 0 0 0 1px var(--sw-accent, #6366f1), 0 2px 8px rgba(99, 102, 241, 0.15);
        }

        .sw-deck-option--selected .sw-deck-option__radio {
          border-color: var(--sw-accent, #6366f1);
        }

        .sw-deck-option--selected .sw-deck-option__radio-dot {
          background: var(--sw-accent, #6366f1);
        }

        /* Radio indicator */
        .sw-deck-option__radio {
          display: flex;
          align-items: center;
          justify-content: center;
          width: 20px;
          height: 20px;
          border: 2px solid var(--sw-border, #ccc);
          border-radius: 50%;
          margin-bottom: 0.5rem;
          flex-shrink: 0;
        }

        .sw-deck-option__radio-dot {
          width: 10px;
          height: 10px;
          border-radius: 50%;
          background: transparent;
          transition: background 0.15s;
        }

        /* Header */
        .sw-deck-option__header {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          margin-bottom: 0.75rem;
        }

        .sw-deck-option__label {
          font-size: 1rem;
          font-weight: 600;
          color: var(--sw-text, #1a1a2e);
        }

        .sw-deck-option__badge {
          display: inline-flex;
          align-items: center;
          padding: 0.125rem 0.5rem;
          font-size: 0.75rem;
          font-weight: 600;
          color: var(--sw-accent, #6366f1);
          background: color-mix(in srgb, var(--sw-accent, #6366f1) 12%, transparent);
          border-radius: var(--sw-radius-sm, 4px);
          text-transform: uppercase;
          letter-spacing: 0.025em;
        }

        /* Preview content area */
        .sw-deck-option__preview {
          max-height: 260px;
          margin-bottom: 0.75rem;
          overflow: hidden;
          border-radius: var(--sw-radius-md, 6px);
        }

        /* Aside text */
        .sw-deck-option__aside {
          font-size: 0.875rem;
          color: var(--sw-text-dim, #666);
          margin-bottom: 0.75rem;
          line-height: 1.4;
        }

        /* Notes textarea */
        .sw-deck-option__notes {
          margin-top: 0.5rem;
        }

        .sw-deck-option__notes-input {
          width: 100%;
          padding: 0.5rem;
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-sm, 4px);
          background: var(--sw-surface, #ffffff);
          color: var(--sw-text, #1a1a2e);
          font-size: 0.8125rem;
          font-family: inherit;
          resize: vertical;
          min-height: 2.5rem;
        }

        .sw-deck-option__notes-input:focus {
          outline: 2px solid var(--sw-accent, #6366f1);
          outline-offset: -1px;
          border-color: var(--sw-accent, #6366f1);
        }

        .sw-deck-option__notes-input::placeholder {
          color: var(--sw-text-dim, #999);
        }

        /* Responsive: stack on narrow screens */
        @media (max-width: 640px) {
          .sw-deck-slide__grid {
            grid-template-columns: 1fr !important;
          }
        }

        /* ===========================================
           Deck Summary Styles (sw- prefix, T9)
           =========================================== */

        .sw-deck-summary {
          padding: 1rem 0;
        }

        .sw-deck-summary__title {
          font-size: 1.375rem;
          font-weight: 600;
          margin-bottom: 1.25rem;
          color: var(--sw-text, #1a1a2e);
        }

        .sw-deck-summary__cards {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
          gap: 1rem;
          margin-bottom: 1.5rem;
        }

        .sw-deck-summary__card {
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-lg, 12px);
          padding: 1rem;
          background: var(--sw-surface, #ffffff);
        }

        .sw-deck-summary__card--empty {
          opacity: 0.6;
          border-style: dashed;
        }

        .sw-deck-summary__card-title {
          font-size: 0.875rem;
          font-weight: 600;
          color: var(--sw-text-dim, #666);
          text-transform: uppercase;
          letter-spacing: 0.03em;
          margin-bottom: 0.5rem;
        }

        .sw-deck-summary__card-label {
          font-size: 1.0625rem;
          font-weight: 600;
          color: var(--sw-text, #1a1a2e);
          margin-bottom: 0.375rem;
        }

        .sw-deck-summary__card-label--none {
          font-style: italic;
          color: var(--sw-text-dim, #999);
          font-weight: 400;
        }

        .sw-deck-summary__card-aside {
          font-size: 0.8125rem;
          color: var(--sw-text-dim, #666);
          margin-bottom: 0.375rem;
        }

        .sw-deck-summary__card-notes {
          font-size: 0.8125rem;
          color: var(--sw-text-dim, #666);
          margin-top: 0.375rem;
          padding-top: 0.375rem;
          border-top: 1px solid var(--sw-border, #e0e0e0);
        }

        .sw-deck-summary__card-notes-label {
          font-weight: 600;
        }

        .sw-deck-summary__missing {
          color: var(--sw-status-warning, #d97706);
          font-size: 0.9375rem;
          font-weight: 500;
          margin-bottom: 1.25rem;
          padding: 0.75rem 1rem;
          background: color-mix(in srgb, var(--sw-status-warning, #d97706) 8%, transparent);
          border-radius: var(--sw-radius-md, 6px);
        }

        .sw-deck-summary__final-notes {
          margin-bottom: 1.25rem;
        }

        .sw-deck-summary__final-notes-label {
          display: block;
          font-size: 0.875rem;
          font-weight: 600;
          color: var(--sw-text, #1a1a2e);
          margin-bottom: 0.375rem;
        }

        .sw-deck-summary__final-notes-input {
          width: 100%;
          padding: 0.625rem;
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-sm, 4px);
          background: var(--sw-surface, #ffffff);
          color: var(--sw-text, #1a1a2e);
          font-size: 0.875rem;
          font-family: inherit;
          resize: vertical;
          min-height: 3rem;
        }

        .sw-deck-summary__final-notes-input:focus {
          outline: 2px solid var(--sw-accent, #6366f1);
          outline-offset: -1px;
          border-color: var(--sw-accent, #6366f1);
        }

        .sw-deck-summary__submit {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 0.625rem 2rem;
          font-size: 1rem;
          font-weight: 600;
          color: #fff;
          background: var(--sw-accent, #6366f1);
          border: none;
          border-radius: var(--sw-radius-md, 6px);
          cursor: pointer;
          transition: background 0.15s, opacity 0.15s;
        }

        .sw-deck-summary__submit:hover {
          filter: brightness(1.1);
        }

        .sw-deck-summary__submit--disabled {
          opacity: 0.5;
          cursor: not-allowed;
        }

        .sw-deck-summary__submit--disabled:hover {
          filter: none;
        }

        .sw-deck-summary__submitted {
          display: inline-flex;
          align-items: center;
          padding: 0.625rem 2rem;
          font-size: 1rem;
          font-weight: 600;
          color: var(--sw-status-success, #16a34a);
          background: color-mix(in srgb, var(--sw-status-success, #16a34a) 10%, transparent);
          border-radius: var(--sw-radius-md, 6px);
        }
      CSS

      # Inject sw-slide-nav.js once per render
      def inject_slide_nav_js(view)
        return if view.instance_variable_get(:@_slide_nav_js_injected)
        view.instance_variable_set(:@_slide_nav_js_injected, true)
        js_path = File.join(__dir__, '..', 'assets', 'js', 'sw-slide-nav.js')
        view.script { view.raw(view.safe(File.read(js_path))) } if File.exist?(js_path)
      end

      # Inject slide container CSS once per render
      def inject_slide_container_css(view)
        inject_component_css(view, :slide, SLIDE_CONTAINER_CSS)
      end

      # CSS for slide containers
      SLIDE_CONTAINER_CSS = <<~CSS
        /* ===========================================
           Slide Container Styles (sw- prefix, T5)
           =========================================== */

        .sw-slide-container {
          position: relative;
          width: 100%;
        }

        /* Progress bar */
        .sw-slide-progress {
          height: 3px;
          background: var(--sw-border, #e0e0e0);
          overflow: hidden;
        }

        .sw-slide-progress--fixed {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          z-index: 1000;
        }

        .sw-slide-progress__bar {
          height: 100%;
          background: var(--sw-accent, #0d9488);
          transition: width 300ms ease-out;
        }

        /* Slide */
        .sw-slide {
          padding: 1rem 0;
        }

        .sw-slide__title {
          margin: 0 0 1rem 0;
          font-family: var(--sw-font-display, inherit);
          color: var(--sw-text, #111);
        }

        /* Swap mode fade transition */
        .sw-slide-fade-enter {
          transition: opacity 200ms ease-out;
        }

        .sw-slide-fade-enter-start {
          opacity: 0;
        }

        .sw-slide-fade-enter-end {
          opacity: 1;
        }

        /* Navigation buttons */
        .sw-slide-nav {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 1rem 0;
          gap: 1rem;
        }

        .sw-slide-nav__btn {
          padding: 0.5rem 1.25rem;
          border: 1px solid var(--sw-border, #e0e0e0);
          border-radius: var(--sw-radius-md, 6px);
          background: var(--sw-surface, #fff);
          color: var(--sw-text, #111);
          cursor: pointer;
          font-size: 0.9rem;
          transition: background 150ms ease-out, border-color 150ms ease-out;
        }

        .sw-slide-nav__btn:hover:not(:disabled) {
          background: var(--sw-surface-elevated, #f3f3f3);
          border-color: var(--sw-accent, #0d9488);
        }

        .sw-slide-nav__btn:disabled {
          opacity: 0.4;
          cursor: not-allowed;
        }

        .sw-slide-nav__btn--next {
          margin-left: auto;
        }

        /* Scroll-snap mode */
        .sw-slide-container--scroll-snap .sw-slide-container__scroll {
          overflow-y: auto;
          scroll-snap-type: y mandatory;
          height: 100dvh;
        }

        .sw-slide--snap {
          scroll-snap-align: start;
          min-height: 100dvh;
          display: flex;
          flex-direction: column;
          justify-content: center;
          padding: 2rem;
          box-sizing: border-box;
        }

        /* Navigation dots */
        .sw-slide-dots {
          display: flex;
          justify-content: center;
          gap: 0.5rem;
          padding: 0.75rem 0;
        }

        .sw-slide-dots__dot {
          width: 10px;
          height: 10px;
          border-radius: 50%;
          border: 1px solid var(--sw-border, #e0e0e0);
          background: var(--sw-surface, #fff);
          cursor: pointer;
          padding: 0;
          transition: background 150ms ease-out, border-color 150ms ease-out;
        }

        .sw-slide-dots__dot:hover {
          border-color: var(--sw-accent, #0d9488);
        }

        .sw-slide-dots__dot--active {
          background: var(--sw-accent, #0d9488);
          border-color: var(--sw-accent, #0d9488);
        }

        /* Counter */
        .sw-slide-counter {
          text-align: center;
          font-size: 0.8rem;
          color: var(--sw-text-dim, #444);
          padding: 0.25rem 0;
        }

        /* x-cloak: hide until Alpine initializes */
        [x-cloak] { display: none !important; }
      CSS

      # =========================================
      # Chart components rendering
      # =========================================

      def render_chart(view, chart, state, config_class:)
        config = config_class.new(chart, state)
        view.div(class: "sw-chart-container", style: "height: #{config.height}; position: relative;") do
          view.canvas(id: config.id, "x-data" => "{}", "x-init" => config.init_script)
        end
      end

      def render_bar_chart(view, chart, state)         = render_chart(view, chart, state, config_class: BarChartConfig)
      def render_line_chart(view, chart, state)        = render_chart(view, chart, state, config_class: LineChartConfig)
      def render_pie_chart(view, chart, state)         = render_chart(view, chart, state, config_class: PieChartConfig)
      def render_stacked_bar_chart(view, chart, state) = render_chart(view, chart, state, config_class: StackedBarChartConfig)

      # Base class for Chart.js configuration value objects
      class ChartConfigBase
        attr_reader :id, :height

        def initialize(chart, state)
          @data = chart.resolve_data(state)
          @options = chart.options
          @id = "sw-chart-#{SecureRandom.hex(4)}"
          @height = @options[:height] || default_height
        end

        def init_script
          "if (typeof Chart !== 'undefined') { new Chart(document.getElementById('#{@id}'), #{config_json}); }"
        end

        private

        def config_json     = JSON.generate(chart_config)
        def chart_config    = { type: chart_type, data: data_config, options: options_config }
        def data_config     = { labels: @data[:labels], datasets: [dataset] }
        def primary_color   = (@options[:colors] || ["#c2410c"]).first
        def default_height  = "250px"
        def grid_style      = { display: true, color: 'rgba(0,0,0,0.05)' }
        def tick_style      = { font: { size: 12 } }

        def title_config
          return { display: false } unless @options[:title]
          { display: true, text: @options[:title], font: { size: 14, weight: '600' } }
        end
      end

      class BarChartConfig < ChartConfigBase
        def chart_type = 'bar'

        def dataset
          {
            data: @data[:values],
            backgroundColor: primary_color,
            borderColor: primary_color,
            borderWidth: 0,
            borderRadius: 4,
            barPercentage: 0.7
          }
        end

        def options_config
          {
            indexAxis: horizontal? ? 'y' : 'x',
            responsive: true,
            maintainAspectRatio: false,
            plugins: plugins_config,
            scales: scales_config
          }
        end

        private

        def horizontal? = @options[:horizontal] || false

        def plugins_config
          {
            legend: { display: @options.fetch(:show_legend, false) },
            title: title_config,
            datalabels: datalabels_config
          }.compact
        end

        def datalabels_config
          return nil unless @options[:show_values]
          { display: true, anchor: 'end', align: 'end', font: { size: 11, weight: '500' } }
        end

        def scales_config
          {
            x: { grid: { display: !horizontal?, color: 'rgba(0,0,0,0.05)' }, ticks: tick_style },
            y: { grid: { display: horizontal?, color: 'rgba(0,0,0,0.05)' }, ticks: tick_style, beginAtZero: true }
          }
        end
      end

      class LineChartConfig < ChartConfigBase
        def chart_type     = 'line'
        def default_height = sparkline? ? "60px" : "250px"

        def dataset
          {
            data: @data[:values],
            borderColor: primary_color,
            backgroundColor: fill? ? "#{primary_color}20" : 'transparent',
            borderWidth: sparkline? ? 1.5 : 2,
            fill: fill?,
            tension: smooth? ? 0.4 : 0,
            pointRadius: show_points? ? 3 : 0,
            pointHoverRadius: show_points? ? 5 : 0
          }
        end

        def options_config = sparkline? ? sparkline_options : standard_options

        private

        def sparkline?   = @options[:sparkline] || false
        def fill?        = @options[:fill] || false
        def smooth?      = @options.fetch(:smooth, true)
        def show_points? = !sparkline? && @options.fetch(:points, true)
        def begin_at_zero? = @options.fetch(:begin_at_zero, false)

        def sparkline_options
          {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false }, tooltip: { enabled: false } },
            scales: { x: { display: false }, y: { display: false, beginAtZero: begin_at_zero? } }
          }
        end

        def standard_options
          {
            responsive: true,
            maintainAspectRatio: false,
            plugins: plugins_config,
            scales: { x: { grid: grid_style, ticks: tick_style }, y: { grid: grid_style, ticks: tick_style, beginAtZero: begin_at_zero? } }
          }
        end

        def plugins_config
          {
            legend: { display: @options.fetch(:show_legend, false) },
            title: title_config
          }.compact
        end
      end

      class PieChartConfig < ChartConfigBase
        COLORS = %w[#c2410c #4a90d9 #10b981 #f59e0b #8b5cf6 #ec4899 #06b6d4 #84cc16].freeze

        def chart_type = doughnut? ? 'doughnut' : 'pie'

        def dataset
          colors = @options[:colors] || COLORS
          {
            data: @data[:values],
            backgroundColor: @data[:values].each_index.map { |i| colors[i % colors.length] },
            borderColor: '#ffffff',
            borderWidth: 2
          }
        end

        def options_config
          {
            responsive: true,
            maintainAspectRatio: false,
            cutout: cutout_value,
            plugins: plugins_config
          }
        end

        private

        def doughnut?    = @options[:doughnut] || false
        def cutout_value = doughnut? ? (@options[:cutout] || '50%') : 0

        def plugins_config
          {
            legend: legend_config,
            title: title_config
          }.compact
        end

        def legend_config
          position = @options[:legend_position] || 'right'
          { display: @options.fetch(:show_legend, true), position: position }
        end
      end

      class StackedBarChartConfig < ChartConfigBase
        COLORS = %w[#c2410c #4a90d9 #10b981 #f59e0b #8b5cf6 #ec4899 #06b6d4 #84cc16].freeze

        def chart_type = 'bar'

        def data_config
          { labels: @data[:labels], datasets: datasets }
        end

        def datasets
          colors = @options[:colors] || COLORS
          @data[:series].each_with_index.map do |(name, values), i|
            {
              label: name,
              data: values,
              backgroundColor: colors[i % colors.length],
              borderColor: colors[i % colors.length],
              borderWidth: 0,
              borderRadius: 2
            }
          end
        end

        def options_config
          {
            indexAxis: horizontal? ? 'y' : 'x',
            responsive: true,
            maintainAspectRatio: false,
            plugins: plugins_config,
            scales: scales_config
          }
        end

        private

        def horizontal?  = @options[:horizontal] || false
        def stacked?     = @options.fetch(:stack, true)
        def normalized?  = @options[:normalize] || false

        def plugins_config
          {
            legend: { display: @options.fetch(:show_legend, true), position: 'top' },
            title: title_config
          }.compact
        end

        def scales_config
          {
            x: { stacked: stacked?, grid: grid_style, ticks: tick_style },
            y: { stacked: stacked?, grid: grid_style, ticks: tick_style, beginAtZero: true, max: normalized? ? 100 : nil }.compact
          }
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
          view.style { StreamWeaver::CSS.layer_wrap(".sw-code-editor-wrapper > textarea { display: none !important; }") }
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

      # =========================================
      # Dashboard components rendering (Cabinet Control style)
      # =========================================

      # Render a status dot indicator
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::StatusDot] The status dot component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_status_dot(view, component, state)
        css_classes = ["sw-status-dot", "sw-status-dot-#{component.status}"]
        css_classes << "sw-status-dot-#{component.size}"
        css_classes << "sw-status-dot-pulse" if component.pulse

        if component.label
          view.div(class: "sw-status-dot-wrapper") do
            view.span(class: css_classes.join(" "))
            view.span(class: "sw-status-dot-label") { component.label }
          end
        else
          view.span(class: css_classes.join(" "))
        end
      end

      # Render a badge/pill component
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::Badge] The badge component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_badge(view, component, state)
        css_classes = ["sw-badge", "sw-badge-#{component.variant}", "sw-badge-#{component.size}"]

        view.span(class: css_classes.join(" ")) { component.text }
      end

      # Render a stat display (large number with label)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::StatDisplay] The stat display component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_stat_display(view, component, state)
        css_classes = ["sw-stat", "sw-stat-#{component.size}"]

        view.div(class: css_classes.join(" ")) do
          view.div(class: "sw-stat-value sw-stat-value-#{component.color}") { component.value }
          view.div(class: "sw-stat-label") { component.label }
        end
      end

      # Render a type tag (activity type badge)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::TypeTag] The type tag component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_type_tag(view, component, state)
        css_classes = ["sw-type-tag", "sw-type-tag-#{component.color}"]

        view.span(class: css_classes.join(" ")) { component.display_text }
      end

      # Render a pulse indicator (animated status with label)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::PulseIndicator] The pulse indicator component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_pulse_indicator(view, component, state)
        view.div(class: "sw-pulse-indicator") do
          view.span(class: "sw-pulse-dot sw-pulse-dot-#{component.color}")
          if component.label
            view.span(class: "sw-pulse-label") { component.label }
          end
        end
      end

      # Render a priority item (escalation-style with colored border)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::PriorityItem] The priority item component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_priority_item(view, component, state)
        css_classes = ["sw-priority-item", "sw-priority-#{component.priority}"]

        view.div(class: css_classes.join(" ")) do
          view.div(class: "sw-priority-label") { component.priority.to_s.upcase }
          view.h4(class: "sw-priority-title") { component.title }
          if component.description
            view.p(class: "sw-priority-description") { component.description }
          end
          if component.meta_left || component.meta_right
            view.div(class: "sw-priority-meta") do
              view.span(class: "sw-priority-meta-left") { component.meta_left } if component.meta_left
              view.span(class: "sw-priority-meta-right") { component.meta_right } if component.meta_right
            end
          end
          component.children.each { |child| child.render(view, state) }
        end
      end

      # Render an activity item (time + title + summary + type)
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::ActivityItem] The activity item component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_activity_item(view, component, state)
        view.div(class: "sw-activity-item") do
          view.span(class: "sw-activity-time") { component.time }
          view.div(class: "sw-activity-content") do
            view.h4(class: "sw-activity-title") { component.title }
            if component.summary
              view.p(class: "sw-activity-summary") { component.summary }
            end
          end
          if component.type
            type_tag = Components::TypeTag.new(component.type)
            render_type_tag(view, type_tag, state)
          end
        end
      end

      # Render a timeline event row with expandable details
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::TimelineEvent] The timeline event component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_timeline_event(view, component, state)
        css_classes = ["sw-timeline-event", "sw-timeline-event--#{component.event_type}"]

        view.div(
          class: css_classes.join(" "),
          "x-data" => "{ open: #{component.expanded} }",
          "@click" => "open = !open"
        ) do
          view.span(class: "sw-timeline-event__idx") { component.index.to_s }
          view.span(class: "sw-timeline-event__badge") { component.event_type.to_s }
          view.span(class: "sw-timeline-event__ts") { component.timestamp }
          view.span(class: "sw-timeline-event__label") { component.label }

          if component.fields.any?
            view.div(class: "sw-timeline-event__detail", "x-show" => "open", "x-cloak" => true) do
              component.fields.each do |key, value|
                view.div(class: "sw-timeline-event__field") do
                  view.strong(class: "sw-timeline-event__field-key") { "#{key}:" }
                  val = value.to_s
                  if val.include?("\n")
                    view.pre(class: "sw-timeline-event__field-value") { val }
                  else
                    view.span(class: "sw-timeline-event__field-value") { " #{val}" }
                  end
                end
              end
            end
          end
        end
      end

      def render_wireframe_block(view, component, state)
        inject_wireframe_css(view)
        view.div(
          class: "sw-wireframe-surface sw-wireframe-surface--#{component.surface}",
          "data-surface" => component.surface
        ) do
          view.raw(view.safe(component.html))
        end
      end

      def render_wireframe(view, component, state)
        inject_wireframe_css(view)
        inject_component_css(view, :wireframe_chrome, wireframe_chrome_css)
        view.div(
          class: "sw-wireframe sw-wireframe--#{component.surface}",
          "data-surface" => component.surface
        ) do
          view.div(class: "sw-wireframe-chrome") do
            render_wireframe_chrome_bar(view, component.surface)
          end
          view.div(class: "sw-wireframe-surface sw-wireframe-body") do
            view.raw(view.safe(component.html))
          end
        end
      end

      def inject_wireframe_css(view)
        inject_component_css(view, :wireframe, wireframe_css)
      end

      def wireframe_css
        <<~CSS
          /* =============================================
             StreamWeaver Wireframe Token Foundation
             All rules scoped to .sw-wireframe-surface
             ============================================= */

          .sw-wireframe-surface {
            --wf-ink:         #1a1a2e;
            --wf-muted:       #6b7280;
            --wf-line:        #d1d5db;
            --wf-paper:       #fafafa;
            --wf-card:        #f3f4f6;
            --wf-accent:      #3b82f6;
            --wf-accent-fg:   #ffffff;
            --wf-accent-soft: #dbeafe;
            --wf-warn:        #f59e0b;
            --wf-ok:          #10b981;
            --wf-radius:      4px;

            color: var(--wf-ink);
            background: var(--wf-paper);
            font-family: inherit;
            box-sizing: border-box;
          }

          html.dark .sw-wireframe-surface {
            --wf-ink:         #f1f5f9;
            --wf-muted:       #94a3b8;
            --wf-line:        #334155;
            --wf-paper:       #0f172a;
            --wf-card:        #1e293b;
            --wf-accent:      #60a5fa;
            --wf-accent-fg:   #0f172a;
            --wf-accent-soft: #1e3a5f;
            --wf-warn:        #fbbf24;
            --wf-ok:          #34d399;
            --wf-radius:      4px;
          }

          .sw-wireframe-surface .wf-card,
          .sw-wireframe-surface .wf-box {
            border: 1.4px solid var(--wf-line);
            border-radius: var(--wf-radius);
            padding: 12px 16px;
            background: var(--wf-card);
            box-sizing: border-box;
          }

          .sw-wireframe-surface .wf-pill,
          .sw-wireframe-surface .wf-chip {
            display: inline-flex;
            align-items: center;
            border: 1px solid var(--wf-line);
            border-radius: 999px;
            padding: 2px 10px;
            font-size: 0.75em;
            background: var(--wf-card);
            color: var(--wf-muted);
          }

          .sw-wireframe-surface .wf-pill.accent,
          .sw-wireframe-surface .wf-chip.accent {
            background: var(--wf-accent);
            color: var(--wf-accent-fg);
            border-color: var(--wf-accent);
          }

          .sw-wireframe-surface .wf-muted {
            color: var(--wf-muted);
          }

          .sw-wireframe-surface button.primary,
          .sw-wireframe-surface [data-primary] {
            background: var(--wf-accent);
            color: var(--wf-accent-fg);
            border: none;
            border-radius: var(--wf-radius);
            padding: 6px 14px;
            font-weight: 500;
            cursor: pointer;
          }

          .sw-wireframe-surface button.primary:hover,
          .sw-wireframe-surface [data-primary]:hover {
            opacity: 0.88;
          }
        CSS
      end

      def wireframe_chrome_css
        <<~CSS
          /* =============================================
             StreamWeaver Wireframe Device Chrome
             Visual device frames for each surface type
             ============================================= */

          .sw-wireframe {
            display: inline-flex;
            flex-direction: column;
            border-radius: 8px;
            overflow: hidden;
            border: 1.5px solid var(--wf-line, #d1d5db);
            box-shadow: 0 2px 12px rgba(0,0,0,0.10);
            background: var(--wf-paper, #fafafa);
            width: 100%;
          }

          .sw-wireframe-body {
            flex: 1;
            overflow: auto;
            padding: 16px;
          }

          /* Chrome bar shared base */
          .sw-wireframe-chrome {
            display: flex;
            align-items: center;
            gap: 6px;
            padding: 6px 10px;
            background: var(--wf-card, #f3f4f6);
            border-bottom: 1.5px solid var(--wf-line, #d1d5db);
            flex-shrink: 0;
          }

          /* Browser chrome: traffic dots + address bar */
          .sw-wireframe--browser .sw-wireframe-chrome {
            min-height: 28px;
          }

          .sw-wireframe-dot {
            width: 9px;
            height: 9px;
            border-radius: 50%;
            flex-shrink: 0;
          }

          .sw-wireframe-dot--red   { background: #ff5f57; }
          .sw-wireframe-dot--amber { background: #ffbd2e; }
          .sw-wireframe-dot--green { background: #28c840; }

          .sw-wireframe-addressbar {
            flex: 1;
            height: 16px;
            border-radius: 4px;
            background: var(--wf-paper, #fafafa);
            border: 1px solid var(--wf-line, #d1d5db);
            margin-left: 4px;
          }

          /* Desktop chrome: title bar with traffic lights */
          .sw-wireframe--desktop .sw-wireframe-chrome {
            min-height: 28px;
          }

          .sw-wireframe-title {
            flex: 1;
            text-align: center;
            font-size: 11px;
            color: var(--wf-muted, #6b7280);
            font-weight: 500;
            letter-spacing: 0.02em;
          }

          /* Mobile/phone chrome: status bar */
          .sw-wireframe--mobile .sw-wireframe-chrome,
          .sw-wireframe--phone .sw-wireframe-chrome {
            min-height: 20px;
            padding: 3px 10px;
            justify-content: space-between;
          }

          .sw-wireframe-statusbar-time {
            font-size: 10px;
            font-weight: 600;
            color: var(--wf-ink, #1a1a2e);
          }

          .sw-wireframe-statusbar-icons {
            display: flex;
            gap: 4px;
            align-items: center;
          }

          .sw-wireframe-statusbar-icon {
            width: 12px;
            height: 7px;
            border-radius: 1px;
            background: var(--wf-ink, #1a1a2e);
            opacity: 0.7;
          }

          /* Tablet chrome: status bar (wider) */
          .sw-wireframe--tablet .sw-wireframe-chrome {
            min-height: 22px;
            padding: 4px 12px;
            justify-content: space-between;
          }

          /* Popover/card/widget chrome: compact header strip */
          .sw-wireframe--popover .sw-wireframe-chrome,
          .sw-wireframe--card .sw-wireframe-chrome,
          .sw-wireframe--widget .sw-wireframe-chrome {
            min-height: 20px;
            padding: 4px 10px;
          }

          .sw-wireframe--popover,
          .sw-wireframe--card,
          .sw-wireframe--widget {
            width: auto;
            min-width: 180px;
            max-width: 360px;
            border-radius: 6px;
          }

          /* Panel chrome: sidebar/inspector strip */
          .sw-wireframe--panel .sw-wireframe-chrome {
            min-height: 24px;
            padding: 4px 10px;
            border-bottom: 1.5px solid var(--wf-line, #d1d5db);
          }

          .sw-wireframe-panel-title {
            font-size: 11px;
            font-weight: 600;
            color: var(--wf-muted, #6b7280);
            letter-spacing: 0.04em;
            text-transform: uppercase;
          }

          html.dark .sw-wireframe {
            border-color: var(--wf-line, #334155);
            box-shadow: 0 2px 12px rgba(0,0,0,0.30);
          }

          html.dark .sw-wireframe-chrome {
            background: var(--wf-card, #1e293b);
            border-bottom-color: var(--wf-line, #334155);
          }

          html.dark .sw-wireframe-addressbar {
            background: var(--wf-paper, #0f172a);
            border-color: var(--wf-line, #334155);
          }
        CSS
      end

      def render_wireframe_chrome_bar(view, surface)
        case surface
        when "browser"
          render_traffic_dots(view)
          view.div(class: "sw-wireframe-addressbar")
        when "desktop"
          render_traffic_dots(view)
          view.span(class: "sw-wireframe-title") { view.plain("Untitled") }
        when "mobile", "phone", "tablet"
          icon_count = surface == "tablet" ? 2 : 3
          view.span(class: "sw-wireframe-statusbar-time") { view.plain("9:41") }
          view.div(class: "sw-wireframe-statusbar-icons") do
            icon_count.times { view.span(class: "sw-wireframe-statusbar-icon") }
          end
        when "popover", "card", "widget"
          render_traffic_dots(view)
        when "panel"
          view.span(class: "sw-wireframe-panel-title") { view.plain("PANEL") }
        end
      end

      def render_traffic_dots(view)
        %w[red amber green].each do |color|
          view.span(class: "sw-wireframe-dot sw-wireframe-dot--#{color}")
        end
      end

      # =========================================
      # Layout components rendering (Cabinet Control style)
      # =========================================

      # Render an app shell with main content and sidebar
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::AppShell] The app shell component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_app_shell(view, component, state)
        css_classes = ["sw-app-shell"]
        css_classes << "sw-app-shell-sidebar-#{component.sidebar_position}"
        css_classes << component.options[:class] if component.options[:class]

        style = "--sw-shell-sidebar-width: #{component.sidebar_width}; --sw-shell-gap: #{component.gap};"
        style += " #{component.options[:style]}" if component.options[:style]

        view.div(class: css_classes.join(" "), style: style) do
          # Render main content
          view.div(class: "sw-app-shell-main") do
            component.main_children.each { |child| child.render(view, state) }
          end

          # Render sidebar
          view.aside(class: "sw-app-shell-sidebar") do
            component.sidebar_children.each { |child| child.render(view, state) }
          end
        end
      end

      # Render a sidebar component
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::Sidebar] The sidebar component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_sidebar(view, component, state)
        css_classes = ["sw-sidebar"]
        css_classes << "sw-sidebar-sticky" if component.sticky
        css_classes << component.options[:class] if component.options[:class]

        attrs = { class: css_classes.join(" ") }
        attrs[:style] = component.options[:style] if component.options[:style]

        view.div(**attrs) do
          if component.header
            view.div(class: "sw-sidebar-header") do
              view.h3(class: "sw-sidebar-title") { component.header }
            end
          end
          view.div(class: "sw-sidebar-content") do
            component.children.each { |child| child.render(view, state) }
          end
        end
      end

      # Render a main content component
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::MainContent] The main content component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_main_content(view, component, state)
        view.div(class: "sw-main-content") do
          component.children.each { |child| child.render(view, state) }
        end
      end

      # Render an expandable card with Alpine.js toggle
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [Components::ExpandableCard] The expandable card component
      # @param state [Hash] Current state hash
      # @return [void] Renders to view
      def render_expandable_card(view, component, state)
        # Initialize state for this card's expanded status
        expanded = state[component.key] || component.initially_expanded

        css_classes = ["sw-expandable-card"]
        css_classes << component.extra_classes if component.extra_classes
        card_id = "card-#{component.key}"

        view.div(
          id: card_id,
          class: css_classes.join(" "),
          "x-data" => "{ expanded: #{expanded} }"
        ) do
          # Card header (always visible, clickable)
          view.div(
            class: "sw-expandable-card-header",
            "@click" => "expanded = !expanded"
          ) do
            # Status dot if provided
            if component.status
              status_dot = Components::StatusDot.new(status: component.status)
              render_status_dot(view, status_dot, state)
            end

            # Title and subtitle
            view.div(class: "sw-expandable-card-titles") do
              view.h3(class: "sw-expandable-card-title") { component.title }
              if component.subtitle
                view.p(class: "sw-expandable-card-subtitle") { component.subtitle }
              end
            end

            # Badge if provided
            if component.badge_text
              badge = Components::Badge.new(component.badge_text, variant: component.badge_variant)
              render_badge(view, badge, state)
            end

            # Expand/collapse indicator
            view.span(class: "sw-expandable-card-chevron", "x-text" => "expanded ? '▼' : '▶'")
          end

          # Card body (toggles visibility)
          view.div(
            class: "sw-expandable-card-body",
            "x-show" => "expanded",
            "x-transition:enter" => "sw-transition-enter",
            "x-transition:enter-start" => "sw-transition-enter-start",
            "x-transition:enter-end" => "sw-transition-enter-end",
            "x-transition:leave" => "sw-transition-leave",
            "x-transition:leave-start" => "sw-transition-leave-start",
            "x-transition:leave-end" => "sw-transition-leave-end"
          ) do
            # Render header children (stats area)
            component.header_children.each { |child| child.render(view, state) }

            # Render body children
            component.children.each { |child| child.render(view, state) }
          end
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
              **htmx_attrs(url("/action/#{item_id}"), "@click" => "open = false")
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

        styles = ["gap: #{spacing_to_css(component.spacing)};"]
        styles << component.options[:style] if component.options[:style]

        view.div(class: css_classes.join(" "), style: styles.join(" ")) do
          component.children.each { |child| child.render(view, state) }
        end
      end

      # Satisfies the Adapter::Static contract. Server-side highlighting is
      # Prism, loaded from a CDN on first use.
      def inject_code_highlighting(view)
        inject_prism_cdn(view)
      end

      # Inject Prism.js CDN scripts and CSS (once per adapter instance).
      # Lazy-loaded: only included when a code_block component is actually used.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      def inject_prism_cdn(view)
        return if view.instance_variable_get(:@_prism_injected)

        view.instance_variable_set(:@_prism_injected, true)

        # Prism.js tomorrow-night theme (dark-friendly)
        view.link(
          rel: "stylesheet",
          href: "https://cdn.jsdelivr.net/npm/prismjs@1/themes/prism-tomorrow.min.css"
        )
        # Prism.js core
        view.script(
          src: "https://cdn.jsdelivr.net/npm/prismjs@1/prism.min.js",
          defer: true
        )
        # Autoloader plugin for lazy per-language loading
        view.script(
          src: "https://cdn.jsdelivr.net/npm/prismjs@1/plugins/autoloader/prism-autoloader.min.js",
          defer: true
        )

        # Inline CSS for sw-code-block and sw-image-block components
        view.style do
          view.raw(view.safe(StreamWeaver::CSS.layer_wrap(code_block_css)))
        end
      end

      # CSS for CodeBlock and ImageBlock components.
      # All classes use sw- prefix per convention.
      #
      # @return [String] CSS rules
      def code_block_css
        <<~CSS
          .sw-code-block {
            border: 1px solid var(--sw-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            overflow: hidden;
            margin: 0.75rem 0;
            background: var(--sw-surface, #ffffff);
          }
          .sw-code-block__header {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            background: var(--sw-surface-elevated, #f3f3f3);
            border-bottom: 1px solid var(--sw-border, #e0e0e0);
            padding: 0.375rem 0.75rem;
            font-family: var(--sw-font-mono, monospace);
            font-size: 0.8rem;
            color: var(--sw-text-dim, #444444);
          }
          .sw-code-block__file {
            user-select: all;
          }
          .sw-code-block__copy {
            margin-left: auto;
            flex-shrink: 0;
            border: 1px solid var(--sw-border, #e0e0e0);
            border-radius: var(--sw-radius-sm, 4px);
            background: var(--sw-surface, #ffffff);
            color: inherit;
            font: inherit;
            font-size: 0.7rem;
            padding: 2px 8px;
            cursor: pointer;
          }
          .sw-code-block__copy:hover {
            background: var(--sw-border, #e0e0e0);
          }
          .sw-code-block__body {
            margin: 0;
          }
          /* Selector doubled to raise specificity above Prism's runtime-applied
             pre[class*="language-"] (0,0,1,1) without !important. Prism's JS
             copies the language-* class from <code> up onto this <pre> at
             runtime, so the static HTML alone doesn't show the conflict. */
          .sw-code-block__pre.sw-code-block__pre {
            margin: 0;
            padding: 16px 18px;
            font-family: var(--sw-font-mono, monospace);
            font-size: .8rem;
            line-height: 1.6;
          }
          .sw-code-block__pre.sw-code-block__pre code {
            font-family: inherit;
          }
          .sw-code-block__truncated {
            background: var(--sw-surface-elevated, #f3f3f3);
            border-top: 1px solid var(--sw-border, #e0e0e0);
            padding: 0.25rem 0.75rem;
            font-size: 0.75rem;
            color: var(--sw-text-dim, #444444);
            font-style: italic;
          }

          .sw-image-block {
            margin: 0.75rem 0;
            text-align: center;
          }
          .sw-image-block__img {
            max-width: 100%;
            height: auto;
            border-radius: var(--sw-radius-md, 6px);
          }
          .sw-image-block__caption {
            margin-top: 0.5rem;
            font-size: 0.875rem;
            color: var(--sw-text-dim, #444444);
            font-style: italic;
          }
        CSS
      end

      public

      # =========================================
      # CSS-Only Helpers (T13)
      # =========================================

      def render_hero(view, component, state)
        inject_helpers_css(view)
        view.div(class: "sw-hero") do
          component.children.each { |child| child.render(view, state) }
        end
      end

      def render_prose(view, component, state)
        inject_helpers_css(view)
        css = component.dropcap ? "sw-prose sw-prose--dropcap" : "sw-prose"
        view.div(class: css) do
          component.children.each { |child| child.render(view, state) }
        end
      end

      def render_pullquote(view, component, state)
        inject_helpers_css(view)
        view.blockquote(class: "sw-pullquote") do
          view.p(class: "sw-pullquote__text") { component.text }
          if component.attribution
            view.footer(class: "sw-pullquote__attribution") do
              view.plain("-- #{component.attribution}")
            end
          end
        end
      end

      def render_dir_tree(view, component, state)
        inject_helpers_css(view)
        view.div(class: "sw-dir-tree") do
          view.pre(class: "sw-dir-tree__pre") do
            component.parsed_lines.each do |line|
              status_class = case line[:status]
                             when :new then "sw-dir-tree__line--new"
                             when :modified then "sw-dir-tree__line--modified"
                             when :deleted then "sw-dir-tree__line--deleted"
                             else ""
                             end
              view.span(class: "sw-dir-tree__line #{status_class}".strip) do
                view.plain(line[:text])
              end
              view.plain("\n")
            end
          end
        end
      end

      def render_legend(view, component, state)
        inject_helpers_css(view)
        view.div(class: "sw-legend") do
          component.items.each do |item|
            view.span(class: "sw-legend__item") do
              view.span(
                class: "sw-legend__dot",
                style: "background-color: #{item[:color]};"
              )
              view.span(class: "sw-legend__label") { item[:label] }
            end
          end
        end
      end

      def render_flow_arrow(view, component, state)
        inject_helpers_css(view)
        view.div(class: "sw-flow-arrow") do
          view.div(class: "sw-flow-arrow__line")
          view.div(class: "sw-flow-arrow__head")
          if component.label
            view.span(class: "sw-flow-arrow__label") { component.label }
          end
        end
      end

      def render_layout_toggle(view, component, state)
        inject_helpers_css(view)
        target_sel = component.target
        view.div(class: "sw-layout-toggle") do
          component.columns.each do |n|
            view.button(
              class: "sw-layout-toggle__btn",
              type: "button",
              "@click" => "document.querySelector('#{target_sel}').style.gridTemplateColumns='repeat(#{n},1fr)'"
            ) { n.to_s }
          end
        end
      end

      # Render a clipboard-copy button. The copy text is carried ONLY in the
      # data-sw-copy-text attribute (Phlex escapes attribute values) -- never
      # interpolate component.text into the @click handler or any JS string.
      #
      # @param view [Phlex::HTML] The Phlex view instance
      # @param component [CopyButton] The copy button component
      # @param state [Hash] Current state hash
      def render_copy_button(view, component, state)
        inject_copy_js(view)
        classes = ["sw-button", "sw-copy-button", "btn", "btn-secondary", component.options[:class]].compact.join(" ")
        view.button(
          **copy_button_attrs(component.text, classes),
          **(component.options[:style] ? { style: component.options[:style] } : {})
        ) do
          view.span("x-show" => "!copied") { component.label }
          view.span("x-show" => "copied", "x-cloak" => true) { component.copied_label }
        end
      end

      private

      # Shared attribute set for any clipboard-copy control. The copy text is
      # carried ONLY in the data-sw-copy-text attribute (Phlex escapes
      # attribute values) -- never interpolate text into the @click handler
      # or any JS string. Both render_copy_button and render_code_block's
      # copy affordance build on this so there is one safety mechanism.
      #
      # @param text [String] Text to copy to the clipboard
      # @param classes [String] Fully-built CSS class string for the button
      # @return [Hash] Attributes for a <button> tag wired to window.swCopy
      def copy_button_attrs(text, classes)
        {
          type: "button",
          class: classes,
          "data-sw-copy-text" => text,
          "x-data" => "{ copied: false }",
          "@click" => "swCopy($el).then(() => { copied = true; setTimeout(() => copied = false, 1500) })"
        }
      end

      # Inject sw-copy.js once per render
      def inject_copy_js(view)
        return if view.instance_variable_get(:@_copy_js_injected)
        view.instance_variable_set(:@_copy_js_injected, true)
        js_path = File.join(__dir__, '..', 'assets', 'js', 'sw-copy.js')
        view.script { view.raw(view.safe(File.read(js_path))) } if File.exist?(js_path)
      end

      # Inject CSS-only helpers stylesheet once
      def inject_helpers_css(view)
        inject_component_css(view, :helpers, helpers_css)
      end

      def helpers_css
        <<~CSS
          /* ===========================================
             CSS-Only Helpers (T13)
             All classes use sw- prefix.
             =========================================== */

          /* Hero section */
          .sw-hero {
            padding: var(--sw-spacing-2xl, 3rem) var(--sw-spacing-xl, 2rem);
            background: color-mix(in oklch, var(--sw-accent, #0d9488) 6%, var(--sw-surface, #ffffff));
            border-radius: var(--sw-radius-lg, 12px);
            text-align: center;
            margin-bottom: var(--sw-spacing-lg, 1.5rem);
          }

          .sw-hero h1, .sw-hero h2 {
            margin: 0 0 var(--sw-spacing-sm, 0.5rem) 0;
          }

          /* Prose container */
          .sw-prose {
            max-width: 65ch;
            line-height: 1.8;
            font-size: 1.05rem;
            color: var(--sw-text, #111111);
          }

          .sw-prose p {
            margin-bottom: 1em;
          }

          .sw-prose--dropcap > p:first-of-type::first-letter {
            float: left;
            font-size: 3.2em;
            line-height: 0.8;
            padding-right: 0.1em;
            font-weight: 700;
            color: var(--sw-accent, #0d9488);
          }

          /* Pullquote */
          .sw-pullquote {
            border-left: 4px solid var(--sw-accent, #0d9488);
            margin: var(--sw-spacing-lg, 1.5rem) 0;
            padding: var(--sw-spacing-md, 1rem) var(--sw-spacing-lg, 1.5rem);
            background: transparent;
          }

          .sw-pullquote__text {
            font-size: 1.25rem;
            font-style: italic;
            line-height: 1.6;
            color: var(--sw-text, #111111);
            margin: 0;
          }

          .sw-pullquote__attribution {
            margin-top: var(--sw-spacing-sm, 0.5rem);
            font-size: 0.875rem;
            color: var(--sw-text-dim, #444444);
            font-style: normal;
          }

          /* Dir tree */
          .sw-dir-tree {
            margin: var(--sw-spacing-md, 1rem) 0;
            border: 1px solid var(--sw-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            background: var(--sw-surface, #ffffff);
            overflow-x: auto;
          }

          .sw-dir-tree__pre {
            font-family: var(--sw-font-mono, monospace);
            font-size: 0.875rem;
            line-height: 1.6;
            padding: var(--sw-spacing-md, 1rem);
            margin: 0;
            white-space: pre;
          }

          .sw-dir-tree__line { display: inline; }

          .sw-dir-tree__line--new {
            color: #16a34a;
          }

          html.dark .sw-dir-tree__line--new {
            color: #22c55e;
          }

          .sw-dir-tree__line--modified {
            color: #d97706;
          }

          html.dark .sw-dir-tree__line--modified {
            color: #fbbf24;
          }

          .sw-dir-tree__line--deleted {
            color: #dc2626;
            text-decoration: line-through;
          }

          html.dark .sw-dir-tree__line--deleted {
            color: #f87171;
          }

          /* Legend */
          .sw-legend {
            display: flex;
            flex-wrap: wrap;
            gap: var(--sw-spacing-md, 1rem);
            align-items: center;
            margin: var(--sw-spacing-sm, 0.5rem) 0;
          }

          .sw-legend__item {
            display: inline-flex;
            align-items: center;
            gap: 0.375rem;
            font-size: 0.875rem;
            color: var(--sw-text-dim, #444444);
          }

          .sw-legend__dot {
            display: inline-block;
            width: 0.625rem;
            height: 0.625rem;
            border-radius: 50%;
          }

          /* Flow arrow */
          .sw-flow-arrow {
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: var(--sw-spacing-sm, 0.5rem) 0;
            position: relative;
          }

          .sw-flow-arrow__line {
            width: 2px;
            height: 2rem;
            background: var(--sw-border, #e0e0e0);
          }

          .sw-flow-arrow__head {
            width: 0;
            height: 0;
            border-left: 6px solid transparent;
            border-right: 6px solid transparent;
            border-top: 8px solid var(--sw-border, #e0e0e0);
          }

          .sw-flow-arrow__label {
            position: absolute;
            top: 50%;
            left: calc(50% + 1rem);
            transform: translateY(-50%);
            font-size: 0.75rem;
            color: var(--sw-text-dim, #444444);
            white-space: nowrap;
          }

          /* Layout toggle */
          .sw-layout-toggle {
            display: inline-flex;
            gap: 2px;
            background: var(--sw-surface-elevated, #f3f3f3);
            border-radius: var(--sw-radius-md, 6px);
            padding: 2px;
            margin: var(--sw-spacing-sm, 0.5rem) 0;
          }

          .sw-layout-toggle__btn {
            background: transparent;
            border: none;
            padding: 0.25rem 0.625rem;
            font-size: 0.8125rem;
            font-weight: 600;
            color: var(--sw-text-dim, #444444);
            border-radius: var(--sw-radius-sm, 4px);
            cursor: pointer;
            transition: background 150ms, color 150ms;
          }

          .sw-layout-toggle__btn:hover {
            background: var(--sw-surface, #ffffff);
            color: var(--sw-text, #111111);
          }
        CSS
      end

    end
  end
end
