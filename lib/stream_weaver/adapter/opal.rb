# frozen_string_literal: true
# backtick_javascript: true

require "cgi"

module StreamWeaver
  module Adapter
    class Opal < Base
      # Not in Base — defined fresh here
      def render_header(view, content, level, _state)
        level = [[level.to_i, 1].max, 6].min
        view.send(:"h#{level}") { view.plain(content.to_s) }
      end

      # Not in Base — defined fresh here
      def render_div(view, component, state)
        opts = component.respond_to?(:html_options) ? component.html_options : {}
        view.div(**opts) do
          Array(component.children).each { |c| c.render(view, state) }
        end
      end

      # Not in Base — defined fresh here
      def render_markdown(view, content, _state)
        view.div(class: "sw-markdown") { view.raw(md_to_html(content.to_s)) }
      end

      # Overrides Base
      def render_text_field(view, key, options, state)
        view.input(
          type: "text",
          name: key.to_s,
          value: state[key] || "",
          placeholder: options[:placeholder] || "",
          data_sw_update: key.to_s
        )
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

      # Not in Base — defined fresh here
      def render_tabs(view, component, state)
        active_index = state[component.key] || 0
        view.div(class: "sw-tabs sw-tabs--#{component.variant || 'line'}") do
          view.div(class: "sw-tabs__nav") do
            component.children.each_with_index do |tab, index|
              active_class = index == active_index ? " sw-tabs__tab--active" : ""
              view.button(
                class: "sw-tabs__tab#{active_class}",
                data_sw_invoke: "#{component.key}_tab_#{index}"
              ) { view.plain(tab.label) }
            end
          end
          view.div(class: "sw-tabs__content") do
            active_tab = component.children[active_index]
            Array(active_tab&.children).each { |c| c.render(view, state) }
          end
        end
      end

      # Not in Base — defined fresh here
      def render_table(view, headers, rows, options, state)
        key       = options[:key]
        sort_col  = state["#{key}_sort_col"]
        sort_dir  = (state["#{key}_sort_dir"] || :asc).to_sym

        if options[:sortable] && sort_col
          rows = rows.sort_by { |row| row[sort_col].to_s }
          rows = rows.reverse if sort_dir == :desc
        end

        css_classes = ["sw-table"]
        css_classes << "sw-table--striped"    if options[:striped]
        css_classes << "sw-table--bordered"   if options[:bordered]
        css_classes << "sw-table--scrollable" if options[:scrollable]

        wrapper_style = options[:sticky_header] ? "max-height:400px;overflow-y:auto;" : nil

        attrs = { class: css_classes.join(" ") }
        attrs[:style] = wrapper_style if wrapper_style
        view.div(**attrs) do
          view.table do
            view.thead do
              view.tr do
                headers.each_with_index do |header, index|
                  if options[:sortable]
                    indicator = if sort_col == index
                      sort_dir == :asc ? " ↑" : " ↓"
                    else
                      ""
                    end
                    view.th do
                      view.button(data_sw_invoke: "#{key}_sort_#{index}") do
                        view.plain("#{header}#{indicator}")
                      end
                    end
                  else
                    view.th { view.plain(header.to_s) }
                  end
                end
              end
            end
            view.tbody do
              rows.each do |row|
                view.tr do
                  Array(row).each { |cell| view.td { view.plain(cell.to_s) } }
                end
              end
            end
          end
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
