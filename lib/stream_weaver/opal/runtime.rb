# frozen_string_literal: true

require "cgi"

require_relative "reactive_state"
require_relative "shell"

module StreamWeaver
  module Opal
    class OpalRuntime
      class << self
        attr_accessor :current

        # Installs the actual browser timer. The only part of the every/after
        # path that needs a browser; everything that decides *whether* to
        # install runs in every host, which is what makes the lifecycle
        # behaviour provable without one.
        def install_browser_timer(kind, seconds, &block)
          return nil unless RUBY_ENGINE == "opal"

          ms = (seconds * 1000).to_i
          cb = block
          # :nocov:
          if kind == :every
            %x{ return setInterval(function() { #{cb.call} }, #{ms}) }
          else
            %x{ return setTimeout(function() { #{cb.call} }, #{ms}) }
          end
          # :nocov:
        end
      end

      # The element every patch morphs into, by id.
      #
      # Configurable rather than fixed because the two Opal hosts disagree and
      # only one of them can be changed: OpalShell's standalone page owns its
      # own markup and uses this default, while the browser extension's
      # sandbox.html has to keep `id="app-container"` -- a large amount of
      # :doc-theme CSS is scoped to `body[class*="sw-layout-"] > #app-container`
      # (adapter/static.rb's sidebar_toc_css), and renaming it to match this
      # default was tried in 2026-08 and silently dropped the sidebar's grid
      # column. So the runtime is told where to mount instead of the page being
      # renamed to suit the runtime.
      DEFAULT_MOUNT_ID = "sw-app"

      attr_reader :state, :mount_id

      # nil/empty means "whatever the default is" rather than an error: the JS
      # side calls start() with no argument in the standalone host, and an
      # absent argument arrives here as nil.
      def mount_id=(id)
        value = id.to_s.strip
        @mount_id = value.empty? ? DEFAULT_MOUNT_ID : value
      end

      def initialize(adapter:)
        self.mount_id         = nil
        @adapter              = adapter
        @state                = ReactiveState.new
        @callbacks            = {}
        @timers               = {}
        @timer_blocks         = {}
        @block                = nil
        @start_hooks          = []
        @start_hooks_fired    = false
        @watchers_initialized = false
        @sync_rendering       = false
        @rerender_pending     = false
        @state_loop_error     = nil
        @state.on_any_change { schedule_rerender }
        @state.on_state_loop { |message, _key| report_state_loop(message) }
      end

      # --- every/after timer lifecycle ---------------------------------------
      #
      # At most one timer per callsite, however many times the DSL block runs.
      #
      # Not clear-and-reinstall-per-render, the other option: that resets each
      # interval's phase on every render, so `every(60)` in a doc re-rendering
      # more often than once a minute would never fire at all. The cost of that
      # choice is that `seconds` is read only on first install -- a callsite
      # keeps the period it was created with (see AppTimers#next_timer_callsite,
      # which documents `key:` as the way to ask for a new one).
      #
      # The block, however, must NOT be frozen at the first execution -- a timer
      # block closes over DSL-time data, so a stale one polls the state the doc
      # had on render #1 forever. The installed timer calls through
      # @timer_blocks, which every registration overwrites: one timer per
      # callsite, latest block wins, phase untouched.
      def register_timer(kind, callsite, seconds, &block)
        @timer_blocks[callsite] = block
        return if @timers.key?(callsite)

        # The handle is kept, not merely counted: it is what a future teardown
        # (doc swap in the same runtime) needs to actually clear the timer.
        @timers[callsite] =
          OpalRuntime.install_browser_timer(kind, seconds) { fire_timer(callsite) }
      end

      def fire_timer(callsite)
        @timer_blocks[callsite]&.call
      end

      def timer_callsites = @timers.keys

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
        state_loop_banner + parts.join
      ensure
        OpalRuntime.current = nil
      end

      # Render a one-shot document without reactive region tracking.
      #
      # Static hosts never patch individual components, so rebuilding the
      # complete App once per region only repeats DSL work without creating a
      # capability they can use. Build the component tree once, then render
      # that tree in document order through the same adapter and component
      # renderers as the live path.
      def render_static_html
        @callbacks.clear
        @state.reset_tracking
        OpalRuntime.current = self

        app = StreamWeaver::App.new("__opal__", &@block)
        app.rebuild_with_state(@state)
        @watchers_initialized = true

        renderer = OpalRenderer.new(@adapter, @state)
        app.components.each { |component| component.render(renderer, @state) }
        renderer.to_html
      ensure
        OpalRuntime.current = nil
      end

      # --- state-update-loop reporting ---------------------------------------
      #
      # A tripped loop guard has to be seen, not just survived -- the symptom it
      # replaces is a tab that stops responding with nothing to explain why. So
      # the message goes two places: the console, for whoever has devtools open,
      # and the top of the document, for whoever does not. It stays until the
      # runtime is rebuilt; a doc with a feedback loop is broken until its
      # author fixes it, so there is nothing for the banner to clear on.
      def report_state_loop(message)
        @state_loop_error = message
        return unless RUBY_ENGINE == "opal"

        # :nocov:
        %x{ console.error(#{message}) }
        # :nocov:
      end

      # Styling is inline rather than a base-stylesheet rule on purpose: this
      # banner has to be legible in a bare standalone document and in the
      # extension sandbox, neither of which is guaranteed to have loaded the
      # framework CSS that defines the --sw-color-* tokens.
      def state_loop_banner
        return "" unless @state_loop_error

        "<div class=\"sw-state-loop-error\" role=\"alert\" style=\"" \
          "background:#7f1d1d;color:#fff;padding:0.75rem 1rem;margin:0 0 1rem;" \
          "border-radius:4px;font:600 0.875rem/1.5 ui-monospace,monospace\">" \
          "#{CGI.escapeHTML(@state_loop_error)}</div>"
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

      # What window.SWRuntime.start(mountId) calls: mount where the host says,
      # then render and patch. Here rather than assembled in the bridge so the
      # bridge stays a thin JS surface over named runtime methods.
      def start(id = nil)
        self.mount_id = id
        render_and_patch
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
        regions = @state.dependencies_for_key(key.to_sym)
        html    = render_html
        # A tripped loop banner is emitted outside every sw-region-N wrapper, so
        # a region-scoped patch would morph past it and never put it on screen.
        # That matters most here: OpalBridge routes input events through this
        # method, so a text_field whose watcher writes its own key is both the
        # likeliest way to trip the guard and the path that would hide it.
        if regions.empty? || @state_loop_error
          patch_dom(html)
        else
          patch_regions(regions, html)
        end
      ensure
        @sync_rendering = false
      end

      # morphdom options shared by both patch paths.
      #
      # A subtree some host library has already decorated must not be morphed
      # from freshly rendered markup, because that markup is the *undecorated*
      # version. Mermaid is the case that forces this: the DSL emits an empty
      # diagram container and sw-mermaid-zoom.js renders the SVG into it
      # afterwards, so morphing deletes the diagram on every patch and leaves
      # an async re-render to put it back -- a flicker per keystroke at best,
      # and no diagram at all when patches arrive faster than mermaid renders
      # (observed in real Chrome). Returning false from onBeforeElUpdated skips
      # the element and its children.
      #
      # This is only safe because such a container's id is derived from its
      # content (Components::Mermaid#diagram_id): edit the diagram and the id
      # changes, so morphdom never pairs the old node with the new one and the
      # new one renders normally. An id that merely happened to be unique would
      # make this a way to pin stale output on screen.
      def morph_options
        @morph_options ||= build_morph_options
      end

      # Its own method so the x-string is the whole body: Opal only gives a
      # multi-line x-string an implicit return in that position (same shape as
      # .install_browser_timer above).
      def build_morph_options
        # :nocov:
        %x{
          return {
            onBeforeElUpdated: function(fromEl) {
              return !(fromEl.hasAttribute && fromEl.hasAttribute('data-sw-mermaid-done'));
            }
          };
        }
        # :nocov:
      end

      # The markup both patch paths morph into: the rendered body inside a
      # stand-in for the mount element, so morphdom compares like with like.
      def mounted_html(html)
        "<div id=\"#{@mount_id}\">#{html}</div>"
      end

      def patch_regions(region_ids, full_html)
        options = morph_options
        parse_source = mounted_html(full_html)
        # :nocov:
        %x{
          var parser = new DOMParser();
          var doc = parser.parseFromString(#{parse_source}, 'text/html');
          var ids = #{region_ids};
          for (var i = 0; i < ids.length; i++) {
            var regionId = ids[i];
            var newRegion = doc.getElementById(regionId);
            var oldRegion = document.getElementById(regionId);
            if (newRegion && oldRegion) { morphdom(oldRegion, newRegion, #{options}); }
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

      # A missing mount element throws rather than no-oping: the failure mode it
      # replaces is a page that renders, accepts clicks, and silently never
      # patches anything, which is far harder to diagnose than a message naming
      # the id nothing matched. Both hosts wrap start() in a handler that shows
      # the message (the extension's error box, sandbox.js).
      def patch_dom(html)
        mount   = @mount_id
        options = morph_options
        patched = mounted_html(html)
        # :nocov:
        %x{
          var root = document.getElementById(#{mount});
          if (!root) throw new Error("StreamWeaver: no mount element with id '" + #{mount} + "'");
          morphdom(root, #{patched}, #{options});
        }
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
