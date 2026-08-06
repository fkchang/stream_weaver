# frozen_string_literal: true
# backtick_javascript: true

require "cgi"

module StreamWeaver
  module Adapter
    class Opal < Base
      # Not in Base — defined fresh here
      def render_header(view, content, level, _state, options = {})
        level = [[level.to_i, 1].max, 6].min
        attrs = {}
        attrs[:class] = options[:class] if options[:class]
        attrs[:style] = options[:style] if options[:style]
        view.send(:"h#{level}", **attrs) { view.plain(content.to_s) }
      end

      # Not in Base — defined fresh here
      def render_div(view, component, state)
        opts = component.respond_to?(:html_options) ? component.html_options : {}
        view.div(**opts) do
          Array(component.children).each { |c| c.render(view, state) }
        end
      end

      # Not in Base — defined fresh here
      def render_markdown(view, content, _state, options = {})
        css_classes = ["sw-markdown"]
        css_classes << options[:class] if options[:class]
        attrs = { class: css_classes.join(" ") }
        attrs[:style] = options[:style] if options[:style]
        view.div(**attrs) { view.raw(md_to_html(content.to_s)) }
      end

      # Overrides Base
      def render_text_field(view, key, options, state)
        label_text = options[:label]
        input_type = (options[:type] || :text).to_s
        if label_text
          view.div(style: "margin-bottom:8px") do
            view.label(style: "display:block;font-weight:500;margin-bottom:4px") { view.plain(label_text) }
            view.input(
              type: input_type, name: key.to_s, value: state[key] || "",
              placeholder: options[:placeholder] || "", data_sw_update: key.to_s
            )
          end
        else
          view.input(
            type: input_type, name: key.to_s, value: state[key] || "",
            placeholder: options[:placeholder] || "", data_sw_update: key.to_s
          )
        end
      end

      # Overrides Base
      def render_date_field(view, key, options, state)
        bounds = { min: options[:min], max: options[:max] }.compact
        attrs = { type: "date", name: key.to_s, value: state[key] || "", data_sw_update: key.to_s, **bounds }

        if options[:label]
          view.div(style: "margin-bottom:8px") do
            view.label(style: "display:block;font-weight:500;margin-bottom:4px") { view.plain(options[:label]) }
            view.input(**attrs)
          end
        else
          view.input(**attrs)
        end
      end

      # Overrides Base
      def render_checkbox(view, key, label, _options, state)
        view.label do
          view.input(type: "checkbox", name: key.to_s,
                     data_sw_toggle: key.to_s, checked: state[key] ? true : false)
          view.plain(" #{label}")
        end
      end

      # Overrides Base — 5 args: (view, button_id, label, options, modal_context)
      def render_button(view, button_id, label, _options, _modal_context = nil)
        view.button(data_sw_invoke: button_id) { view.plain(label.to_s) }
      end

      # Overrides Base — morphdom.js comes from OpalShell, nothing to emit here
      def render_cdn_scripts(_view)
      end

      def render_badge(view, component, _state)
        view.span(class: "sw-badge sw-badge-#{component.variant} sw-badge-#{component.size}") { view.plain(component.text) }
      end

      # Not in Base — defined fresh here
      def render_tabs(view, component, state)
        active_index = state[component.key] || 0
        view.div(class: "sw-tabs sw-tabs-#{component.variant || 'line'}") do
          view.div(class: "sw-tabs-list") do
            component.children.each_with_index do |tab, index|
              tab_classes = index == active_index ? "sw-tab-trigger sw-tab-active" : "sw-tab-trigger"
              view.button(
                class: tab_classes,
                data_sw_invoke: "#{component.key}_tab_#{index}"
              ) { view.plain(tab.label) }
            end
          end
          view.div(class: "sw-tab-panel") do
            active_tab = component.children[active_index]
            Array(active_tab&.children).each { |c| c.render(view, state) }
          end
        end
      end

      # Not in Base — defined fresh here
      def render_table(view, headers, rows, options, state)
        key      = options[:key]
        sort_col = state["#{key}_sort_col"]
        sort_dir = (state["#{key}_sort_dir"] || :asc).to_sym

        if options[:sortable] && sort_col
          rows = rows.sort_by { |row| row[sort_col].to_s }
          rows = rows.reverse if sort_dir == :desc
        end

        table_classes = ["sw-table"]
        table_classes << "sw-table-bordered" if options[:bordered]

        wrapper_attrs = {}
        if options[:scrollable]
          wrapper_attrs[:class] = "sw-table--scrollable"
          wrapper_attrs[:style] = "max-height:400px;overflow:auto;"
        elsif options[:sticky_header]
          wrapper_attrs[:style] = "max-height:400px;overflow-y:auto;"
        end

        th_style = "padding:0.75rem 1rem;text-align:left;border-bottom:2px solid var(--sw-color-border,#e0e0e0);font-weight:600;"
        td_style = "padding:0.75rem 1rem;border-bottom:1px solid var(--sw-color-border,#e0e0e0);"

        view.div(**wrapper_attrs) do
          view.table(class: table_classes.join(" ")) do
            view.thead do
              view.tr do
                headers.each_with_index do |header, index|
                  if options[:sortable]
                    indicator = sort_col == index ? (sort_dir == :asc ? " ↑" : " ↓") : ""
                    view.th(style: th_style + "cursor:pointer;user-select:none;") do
                      view.button(data_sw_invoke: "#{key}_sort_#{index}") do
                        view.plain("#{header}#{indicator}")
                      end
                    end
                  else
                    view.th(style: th_style) { view.plain(header.to_s) }
                  end
                end
              end
            end
            view.tbody do
              rows.each_with_index do |row, idx|
                row_classes = []
                row_classes << "sw-row-striped"   if options[:striped] && idx.odd?
                row_classes << "sw-row-hoverable" if options[:hoverable]
                tr_attrs = row_classes.any? ? { class: row_classes.join(" ") } : {}
                view.tr(**tr_attrs) do
                  Array(row).each_with_index do |cell, col_idx|
                    custom_style = options[:cell_styles]&.dig(idx, col_idx)
                    style = custom_style && !custom_style.to_s.empty? ? "#{td_style} #{custom_style}" : td_style
                    view.td(style: style) { view.plain(cell.to_s) }
                  end
                end
              end
            end
          end
        end
      end

      # Not in Base — defined fresh here
      def render_columns(view, widths, children, _options, state)
        view.div(class: "sw-columns", style: "display:flex;gap:var(--sw-spacing-lg,1rem);") do
          children.each_with_index do |column, index|
            column.width = widths&.[](index)
            column.render(view, state)
          end
        end
      end

      # Not in Base — defined fresh here
      def render_column(view, width, children, _options, state)
        # "fr" is a CSS Grid unit, not a valid flex-basis -- using it there makes the
        # whole `flex` shorthand invalid and silently falls back to shrink-to-content.
        # Translate the fraction to flex-grow instead. See alpinejs.rb#render_column.
        fr_match = width && width.match(/\A(\d+(?:\.\d+)?)fr\z/)
        style = if width.nil?
          "flex:1 1 0;min-width:0;"
        elsif fr_match
          "flex:#{fr_match[1]} 1 0%;min-width:0;"
        else
          # Fixed length -- pin the width, don't grow. See alpinejs.rb#render_column.
          "flex:0 1 #{width};min-width:0;"
        end
        view.div(class: "sw-column", style: style) do
          children.each { |child| child.render(view, state) }
        end
      end

      # Not in Base — defined fresh here
      def render_theme_preset(view, component, state)
      end

      # Not in Base — defined fresh here
      def render_theme_toggle(view, component, state)
        view.button(data_sw_action: "toggle-theme") { view.plain("🌓") }
      end

      # Not in Base — defined fresh here
      def render_theme_switcher(view, component, state)
      end

      private

      if RUBY_ENGINE == "opal"
        def md_to_html(text)
          %x{ return marked.parse(#{text}) }
        end
      else
        def md_to_html(text)
          require "kramdown"
          Kramdown::Document.new(text, input: "GFM", hard_wrap: false).to_html
        end
      end
    end
  end
end
