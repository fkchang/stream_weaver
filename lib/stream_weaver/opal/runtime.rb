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
        @state[key] = value
      end

      def register_callback(dom_id, &proc)
        @callbacks[dom_id] = proc
      end

      def invoke_callback(dom_id)
        @callbacks[dom_id]&.call(@state)
      end

      def register_start_hook(block)
        @start_hooks << block unless @start_hooks_fired
      end

      def render_html
        @callbacks.clear
        @state.reset_tracking
        OpalRuntime.current = self

        # First pass: build components and determine count (no tracking yet)
        app = StreamWeaver::App.new("__opal__", &@block)
        app.rebuild_with_state(@state)
        @watchers_initialized = true
        n = app.components.length

        register_component_callbacks(app.components)

        # Second pass: render each component inside its own track region.
        # rebuild_with_state is called inside each track block so that state
        # reads in the DSL block (e.g. `text state[:name].to_s`) are recorded
        # against the correct region_id.
        # DSL-time reads (state[:key] inside the app block) happen during rebuild_with_state,
        # so we re-build once per region inside track() to attribute reads to the correct region.
        parts = (0...n).map do |i|
          region_html = @state.track("sw-region-#{i}") do
            scoped_app = StreamWeaver::App.new("__opal__", &@block)
            scoped_app.rebuild_with_state(@state)
            component = scoped_app.components[i]
            sub = OpalRenderer.new(@adapter, @state)
            component.render(sub, @state) if component
            sub.to_html
          end
          "<div id=\"sw-region-#{i}\">#{region_html}</div>"
        end
        parts.join
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
      ensure
        @sync_rendering = false
        fire_start_hooks_once
      end

      def invoke_and_patch(dom_id)
        @sync_rendering = true
        invoke_callback(dom_id)
        patch_dom(render_html)
      ensure
        @sync_rendering = false
      end

      def update_and_patch(key, value)
        @sync_rendering = true
        update_state(key, value)
        affected_regions = @state.dependencies_for_key(key.to_sym)
        if affected_regions.empty?
          patch_dom(render_html)
        else
          html = render_html
          patch_regions(affected_regions, html)
        end
      ensure
        @sync_rendering = false
      end

      def patch_regions(region_ids, full_html)
        # :nocov:
        %x{
          var parser = new DOMParser();
          var doc = parser.parseFromString('<div id="sw-app">' + #{full_html} + '</div>', 'text/html');
          var ids = #{region_ids};
          for (var i = 0; i < ids.length; i++) {
            var id = ids[i];
            var newRegion = doc.getElementById(id);
            var oldRegion = document.getElementById(id);
            if (newRegion && oldRegion) { morphdom(oldRegion, newRegion); }
          }
        }
        # :nocov:
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
        # State mutations during a sync render are dropped — app blocks should not
        # write state as a side effect of building the view.
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
