# frozen_string_literal: true
# backtick_javascript: true
# Browser-only require tree. Does NOT require Sinatra, Phlex, AlpineJS,
# iTerm, service, service_client, admin, streamer, feed, or cli.

require "stream_weaver/version"
require "stream_weaver/utils"
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

# Opal-specific patches: fix methods that break in the browser.

# App#button and DisplayDSL#button use block.source_location.join(':').
# In Opal, source_location returns nil (no source maps in compiled JS).
# Override button in App to use a counter-based stable_id instead.
module StreamWeaver
  module Opal
    module AppButtonPatch
      # Opal: source_location is nil — use counter-based IDs.
      def button(label, id: nil, **options, &block)
        @button_counter += 1
        stable_id = id ? "opal_#{id}" : "opal_#{@button_counter}"
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
# Creates an OpalRuntime with the DSL block, installs delegated event listeners
# via OpalBridge, and returns the runtime.
module StreamWeaver
  module Opal
    module Kernel
      def app(title, **_opts, &block)
        adapter = Adapter::Opal.new
        runtime = OpalRuntime.new(adapter: adapter)
        runtime.set_block(&block)
        OpalBridge.new(runtime).install
        runtime
      end
    end
  end
end
include StreamWeaver::Opal::Kernel
