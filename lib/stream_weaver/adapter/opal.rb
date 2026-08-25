# frozen_string_literal: true
# backtick_javascript: true

require "cgi"
require_relative "static"
require_relative "../opal/env"

module StreamWeaver
  module Adapter
    class Opal < Base
      # Document renderers with no framework behavior, shared with the AlpineJS
      # adapter. See adapter/static.rb.
      include Static
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

      # Every component stylesheet this adapter has been asked to emit, keyed by
      # component so re-renders and repeated instances contribute exactly once.
      #
      # The DOM path writes these into <head> and forgets them; the DOM-free
      # path has no <head> to write to, so the adapter is where the CSS lives
      # and OpalRuntime#collected_css reads it back out after a render. Values
      # are already @layer-wrapped, i.e. ready to drop into a <style> tag.
      def collected_css
        @collected_css ||= {}
      end

      # The collected stylesheets as one blob, in first-seen order.
      def collected_css_text
        collected_css.values.join("\n")
      end

      # Satisfies the Adapter::Static contract.
      #
      # Server-side this writes a <style> tag into the rendered fragment. In the
      # browser that would re-emit on every re-render, since each render pass
      # builds fresh renderers and replaces the region's innerHTML. So instead
      # we append to <head> keyed by component, which is idempotent and survives
      # re-renders untouched.
      #
      # Collection happens unconditionally, before the DOM write: it is the only
      # channel available when there is no <head> (Node, render-to-string), and
      # it is what makes this hook observable under MRI.
      def inject_component_css(view, key, css)
        return if css.nil? || css.strip.empty?

        wrapped = StreamWeaver::CSS.layer_wrap(css)
        collected_css[key.to_sym] ||= wrapped

        return unless StreamWeaver::Opal::Env.dom?

        # :nocov:
        %x{
          var id = "sw-css-" + #{key.to_s};
          if (!document.getElementById(id)) {
            var el = document.createElement("style");
            el.id = id;
            el.textContent = #{wrapped};
            document.head.appendChild(el);
          }
        }
        # :nocov:
        nil
      end

      # #render_mermaid now lives in Static, shared with AlpineJS
      # (stream_weaver-mermaid-extension) -- it used to be adapter-specific
      # here on the theory that mermaid was behavior (Alpine's x-data/
      # x-init), but sw-mermaid-zoom.js self-inits on DOMContentLoaded with
      # no Alpine dependency at all, so the markup itself was never
      # adapter-specific. What stayed here is only the JS gap below.

      # The remaining Adapter::Static seams. All four are asset/behavior
      # concerns that a rendered document does not need:
      #
      # - scroll-spy JS is bundled by the host (bin/build_extension), not
      #   inlined per render -- a host with no <base target> override (e.g.
      #   opal-build's standalone HTML) still gets working, unhighlighted
      #   anchors without it; a host that does (the browser extension's
      #   sandbox, for outbound-doc-link safety) needs its own fragment-link
      #   click handler regardless, since that override affects every
      #   `#anchor` link on the page, not just sidebar_toc's
      # - Prism cannot be pulled from a CDN here (a browser-extension host
      #   forbids remote script), so highlighting waits until it is bundled
      # - copy-to-clipboard is Alpine-driven behavior, not document structure
      # - sw-mermaid-zoom.js is bundled by the host the same way
      #   sw-sidebar-toc.js is, not inlined per render -- Opal-compiled code
      #   runs in the browser, where File.read (how AlpineJS inlines it) does
      #   not exist. Only the CSS is injectable here. Unlike the other three,
      #   this one is not optional: mermaid's source lives in a data
      #   attribute the shared markup writes, not visible text, so a host
      #   that skips bundling the engine gets an empty box per diagram, not
      #   a degraded-but-working render. Both real Opal hosts bundle it
      #   unconditionally (bin/build_extension, OpalBuilder#copy_browser_
      #   assets) -- this hook staying CSS-only is about *where* the JS gets
      #   loaded from, not whether it does.
      #
      # Each is a deliberate no-op (or partial no-op) rather than a missing
      # method, so the document renders instead of raising NotImplementedError.
      def inject_sidebar_toc_assets(view)
        inject_component_css(view, :sidebar_toc, sidebar_toc_css)
      end

      def inject_code_highlighting(view)
        nil
      end

      def render_code_block_copy_button(view, component)
        nil
      end

      def inject_mermaid_assets(view)
        inject_component_css(view, :mermaid, mermaid_css)
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
