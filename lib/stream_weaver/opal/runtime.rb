# frozen_string_literal: true

require_relative "reactive_state"
require_relative "shell"

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
        @state.on_any_change { schedule_rerender }
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

      # --- DOM-free rendering -------------------------------------------------
      #
      # render_html already builds the whole document without touching the DOM;
      # everything below is what a non-browser host (Node, a CLI) needs around
      # it. Nothing here references `window` or `document`, directly or through
      # a callee, so the same compiled bundle renders in a bare Node process.

      # The document body, as a string. Same markup the browser paints.
      def render_body_html
        render_html
      end

      # Per-component CSS gathered during the last render.
      #
      # In a browser the adapter appends this to <head> and the caller never
      # needs it. With no <head> to append to, the caller has to place it, so
      # the collected text is handed back rather than dropped -- a document
      # rendered to a file is styled because of this.
      def collected_css
        return "" unless @adapter.respond_to?(:collected_css_text)

        @adapter.collected_css_text
      end

      # A complete, standalone HTML document: body markup baked in, component
      # CSS inlined, no app.js and no runtime boot. This is the artifact a
      # `streamweaver-render doc.rb > doc.html` CLI writes out.
      #
      # stylesheet: framework CSS to inline ahead of the component CSS. Defaults
      # to whatever is reachable from the current host (see CSS.base_stylesheet)
      # -- a host that ships the full theme file can pass its contents instead.
      # Remaining options are forwarded to OpalShell.render.
      def render_document(title: "StreamWeaver Document", stylesheet: nil, **shell_options)
        body = render_html
        css  = [stylesheet || StreamWeaver::CSS.base_stylesheet, collected_css]
               .reject { |c| c.nil? || c.to_s.strip.empty? }.join("\n")

        OpalShell.render(
          title: title,
          app_js: nil,
          body_html: body,
          inline_css: css,
          **shell_options
        )
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
        announce_render
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
        return unless RUBY_ENGINE == "opal"
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
        announce_render
      end

      # Signals that freshly patched markup is in the DOM.
      #
      # Libraries that decorate rendered output rather than produce it --
      # Prism, Mermaid -- have to run after a patch, and again after every
      # subsequent one, because morphdom replaces nodes and takes their
      # decoration with it. Start hooks and re-renders are scheduled through
      # setTimeout, so there is no moment after start() when a caller can
      # simply assume the DOM is settled; this event is that signal.
      def announce_render
        return unless RUBY_ENGINE == "opal"

        # :nocov:
        %x{ document.dispatchEvent(new CustomEvent("sw:render")) }
        # :nocov:
      end
    end
  end
end
