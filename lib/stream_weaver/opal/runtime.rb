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
        # IMPORTANT: Read lib/stream_weaver/app.rb before implementing this method.
        # The block is the same block passed to `app "Title" do...end`. It must be
        # executed in a context where `state`, `text_field`, `button`, etc. are all
        # available as methods — exactly as App does server-side.
        #
        # The exact implementation depends on how App executes the block — check
        # app.rb first, then model this after it. The test below uses an empty block
        # so it passes regardless of context; Task 7 (integration) validates the real DSL.
        @callbacks.clear
        raise NotImplementedError, "implement render_html using App's block execution pattern"
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

      private

      def patch_dom(html)
        # :nocov:
        %x{ morphdom(document.getElementById('sw-app'), '<div id="sw-app">' + #{html} + '</div>') }
        # :nocov:
      end
    end
  end
end
