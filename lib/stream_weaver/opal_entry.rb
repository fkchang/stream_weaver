# frozen_string_literal: true
# backtick_javascript: true
# Browser-only require tree. Does NOT require Sinatra, Phlex, AlpineJS,
# iTerm, service, service_client, admin, streamer, feed, or cli.

require "stream_weaver/version"
require "stream_weaver/utils"
require "stream_weaver/css"   # layer_wrap, for per-component CSS injection
require "stream_weaver/theme"
require "stream_weaver/display_dsl"
require "stream_weaver/app"
require "stream_weaver/components"
require "stream_weaver/adapter/base"
# Phase 1 placeholders — implemented in subsequent tasks:
require "stream_weaver/adapter/opal"
require "stream_weaver/opal/renderer"
require "stream_weaver/opal/runtime"
require "stream_weaver/opal/bridge"
require "stream_weaver/opal/string_bridge"

# Opal-specific patches: fix methods that break in the browser.

# App#button and DisplayDSL#button use block.source_location.join(':').
# In Opal, source_location returns nil (no source maps in compiled JS).
# Override button in App to use a counter-based stable_id instead.
module StreamWeaver
  module Opal
    module AppButtonPatch
      # Opal: source_location is nil — use counter-based IDs. Counter ids are
      # already unique per render, so there is nothing to disambiguate here;
      # id:/key: are still honored (same id: > key: > auto precedence) so a
      # keyed button keeps its identity across rerenders, and so neither
      # option leaks into the rendered element's attributes.
      def button(label, key: nil, id: nil, **options, &block)
        @button_counter += 1
        identity = id || key
        stable_id = identity ? "opal_#{identity}" : "opal_#{@button_counter}"
        options[:modal_context] = @modal_context if @modal_context
        @components << Components::Button.new(label, stable_id, **options, &block)
      end
    end
  end
end
StreamWeaver::App.prepend StreamWeaver::Opal::AppButtonPatch

module StreamWeaver
  module Opal
    module AppReactivePatch
      def watch(key, &block)
        rt = OpalRuntime.current
        return unless rt && !rt.watchers_initialized?
        rt.state.watch(key) do |val|
          block.call(val)
          rt.schedule_rerender
        end
      end

      def on_start(&block)
        OpalRuntime.current&.register_start_hook(block)
      end

      def after(seconds, &block)
        return unless RUBY_ENGINE == "opal"
        ms = (seconds * 1000).to_i
        cb = block
        # :nocov:
        %x{ setTimeout(function() { #{cb.call} }, #{ms}) }
        # :nocov:
      end

      def every(seconds, &block)
        return unless RUBY_ENGINE == "opal"
        ms = (seconds * 1000).to_i
        cb = block
        # :nocov:
        %x{ setInterval(function() { #{cb.call} }, #{ms}) }
        # :nocov:
      end

      def defer(&block)
        return unless RUBY_ENGINE == "opal"
        cb = block
        # :nocov:
        %x{ setTimeout(function() { #{cb.call} }, 0) }
        # :nocov:
      end
    end
  end
end
StreamWeaver::App.prepend StreamWeaver::Opal::AppReactivePatch

# Opal-mode global `app` helper — replaces the Sinatra-wired StreamWeaver.app.
# Creates an OpalRuntime with the DSL block, publishes it to JavaScript, and
# returns the runtime.
#
# Two bridges, because the same compiled bundle runs in two hosts. OpalBridge
# (window.SWRuntime: patching, event delegation) needs a DOM and installs only
# when it finds one, so loading this bundle in Node no longer explodes on the
# missing `window`. StringBridge (globalThis.SWRender) needs nothing and always
# installs, which is what gives a Node process a way to render the doc to a
# string. `app()` keeps its original signature so existing browser builds and
# opal-build output are unaffected.
module StreamWeaver
  module Opal
    module Kernel
      def app(title, **_opts, &block)
        adapter = Adapter::Opal.new
        runtime = OpalRuntime.new(adapter: adapter)
        runtime.set_block(&block)
        OpalBridge.new(runtime).install
        StringBridge.new(runtime, title: title).install
        runtime
      end
    end
  end
end
include StreamWeaver::Opal::Kernel
