# frozen_string_literal: true

module StreamWeaver
  module Adapter
    class Opal < Base
      # Not in Base — defined fresh here
      def render_header(view, content, level, _state)
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
        value = state[key] || ""
        placeholder = options[:placeholder] || ""
        view.input(
          type: "text",
          name: key.to_s,
          value: value,
          placeholder: placeholder,
          oninput: "SWRuntime.update('#{key}', this.value)"
        )
      end

      # Overrides Base
      def render_checkbox(view, key, label, _options, state)
        checked = state[key] ? " checked" : ""
        view.raw(
          "<label>" \
          "<input type=\"checkbox\" name=\"#{key}\" " \
          "onchange=\"SWRuntime.update('#{key}', this.checked)\"#{checked}> " \
          "#{label}</label>"
        )
      end

      # Overrides Base — 4 args: (view, button_id, label, options)
      def render_button(view, button_id, label, _options)
        view.raw("<button onclick=\"SWRuntime.invoke('#{button_id}')\">#{label}</button>")
      end

      # Overrides Base — morphdom.js comes from OpalShell, nothing to emit here
      def render_cdn_scripts(_view)
      end
    end
  end
end
