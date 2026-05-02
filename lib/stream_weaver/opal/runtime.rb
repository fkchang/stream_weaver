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

        # Register callbacks via protocol — each component declares its own
        register_component_callbacks(app.components)

        renderer = OpalRenderer.new(@adapter, @state)
        app.components.each { |c| c.render(renderer, @state) }
        renderer.to_html
      end

      def register_component_callbacks(components)
        Array(components).each do |c|
          c.register_callbacks(@callbacks)
          register_component_callbacks(c.children)
        end
      end

      # :nocov:
      def render_and_patch
        patch_dom(render_html)
      end

      def invoke_and_patch(dom_id)
        invoke_callback(dom_id)
        patch_dom(render_html)
      end

      def update_and_patch(key, value)
        update_state(key, value)
        patch_dom(render_html)
      end
      # :nocov:

      def patch_dom(html)
        # :nocov:
        %x{ morphdom(document.getElementById('sw-app'), '<div id="sw-app">' + #{html} + '</div>') }
        # :nocov:
      end
    end
  end
end
