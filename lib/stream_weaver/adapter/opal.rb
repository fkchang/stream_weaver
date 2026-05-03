# frozen_string_literal: true

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
        view.div(class: "sw-markdown") { view.raw(content.to_s) }
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
    end
  end
end
