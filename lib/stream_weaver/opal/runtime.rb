# frozen_string_literal: true

require_relative "reactive_state"

module StreamWeaver
  module Opal
    class OpalRuntime
      class << self
        attr_accessor :current
      end

      attr_reader :state

      def initialize(adapter:)
        @adapter              = adapter
        @state                = ReactiveState.new
        @callbacks            = {}
        @block                = nil
        @start_hooks          = []
        @start_hooks_fired    = false
        @watchers_initialized = false
        @sync_rendering       = false
        @rerender_pending     = false
      end

      def watchers_initialized? = @watchers_initialized

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

      def register_start_hook(block)
        @start_hooks << block unless @start_hooks_fired
      end

      def render_html
        @callbacks.clear
        OpalRuntime.current = self

        app = StreamWeaver::App.new("__opal__", &@block)
        app.rebuild_with_state(@state)
        @watchers_initialized = true

        register_component_callbacks(app.components)

        renderer = OpalRenderer.new(@adapter, @state)
        app.components.each { |c| c.render(renderer, @state) }
        renderer.to_html
      ensure
        OpalRuntime.current = nil
      end

      def register_component_callbacks(components)
        Array(components).each do |c|
          c.register_callbacks(@callbacks)
          register_component_callbacks(c.children)
        end
      end

      def render_and_patch
        @sync_rendering = true
        html = render_html
        patch_dom(html)
        @sync_rendering = false
        fire_start_hooks_once
      end

      def invoke_and_patch(dom_id)
        @sync_rendering = true
        invoke_callback(dom_id)
        html = render_html
        patch_dom(html)
        @sync_rendering = false
      end

      def update_and_patch(key, value)
        @sync_rendering = true
        update_state(key, value)
        html = render_html
        patch_dom(html)
        @sync_rendering = false
      end

      def fire_start_hooks_once
        return if @start_hooks_fired
        @start_hooks_fired = true
        hooks = @start_hooks.dup
        schedule_start_hooks(hooks)
      end

      def schedule_start_hooks(hooks)
        # :nocov:
        runtime = self
        %x{
          setTimeout(function() {
            #{hooks.each(&:call)};
            #{runtime.schedule_rerender};
          }, 0);
        }
        # :nocov:
      end

      def schedule_rerender
        return if @sync_rendering || @rerender_pending
        @rerender_pending = true
        runtime = self
        # :nocov:
        %x{
          setTimeout(function() {
            #{runtime.perform_async_render};
          }, 0);
        }
        # :nocov:
      end

      def perform_async_render
        @rerender_pending = false
        render_and_patch
      end

      def patch_dom(html)
        # :nocov:
        %x{ morphdom(document.getElementById('sw-app'), '<div id="sw-app">' + #{html} + '</div>') }
        # :nocov:
      end
    end
  end
end
