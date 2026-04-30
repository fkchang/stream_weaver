# frozen_string_literal: true

module StreamWeaver
  module Opal
    class OpalRuntime
      attr_reader :state

      def initialize(adapter:)
        @adapter = adapter
        @state = {}
        @callbacks = {}
        @block = nil
      end

      def set_block(&block)
        @block = block
      end

      def update_state(key, value)
        @state[key.to_sym] = value
      end

      def register_callback(dom_id, &proc)
        @callbacks[dom_id] = proc
      end

      def invoke_callback(dom_id)
        cb = @callbacks[dom_id]
        cb&.call(@state)
      end

      def render_html
        @callbacks.clear

        # Build the App context the same way App#rebuild_with_state does:
        # create an App with the stored block, rebuild it with current state,
        # then render each component using OpalRenderer.
        app = StreamWeaver::App.new("__opal__", &@block)
        app.rebuild_with_state(@state)

        # Register button callbacks so JS SWRuntime.invoke(id) can execute them
        register_component_callbacks(app.components)

        renderer = OpalRenderer.new(@adapter, @state)
        app.components.each { |c| c.render(renderer, @state) }
        renderer.to_html
      end

      # In Opal only: expose self to JS as window.SWRuntime
      def self.expose_to_js(instance)
        # :nocov:
        return unless defined?(::Opal)
        %x{
          window.SWRuntime = {
            start: function() { #{instance.js_start} },
            invoke: function(id) { #{instance.js_invoke(`id`)} },
            update: function(key, val) { #{instance.js_update(`key`, `val`)} }
          };
        }
        # :nocov:
      end

      # :nocov:
      def js_start
        html = render_html
        patch_dom(html)
      end

      def js_invoke(dom_id)
        invoke_callback(dom_id)
        patch_dom(render_html)
      end

      def js_update(key, value)
        update_state(key, value)
        patch_dom(render_html)
      end
      # :nocov:

      private

      def register_component_callbacks(components)
        Array(components).each do |c|
          if c.is_a?(StreamWeaver::Components::Button)
            btn = c
            @callbacks[btn.id] = ->(state) { btn.execute(state) }
          end
          if c.respond_to?(:children) && c.children
            register_component_callbacks(c.children)
          end
          if c.respond_to?(:footer_component) && c.footer_component&.children
            register_component_callbacks(c.footer_component.children)
          end
        end
      end

      def patch_dom(html)
        # :nocov:
        %x{ morphdom(document.getElementById('sw-app'), '<div id="sw-app">' + #{html} + '</div>') }
        # :nocov:
      end
    end
  end
end
