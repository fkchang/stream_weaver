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
require "stream_weaver/opal/app_timers"

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

      # A zero-delay one-shot -- the same setTimeout install every/after use,
      # so it goes through the same helper rather than a third copy of the
      # %x{} block. Not callsite-tracked: a 0ms timeout fires and is gone, so
      # there is no live timer for a later render to accumulate.
      def defer(&block)
        OpalRuntime.install_browser_timer(:after, 0, &block)
      end
    end
  end
end
StreamWeaver::App.prepend StreamWeaver::Opal::AppReactivePatch
# every/after live in their own file so their lifecycle behaviour is reachable
# without the global browser-only overrides this file also installs.
StreamWeaver::App.prepend StreamWeaver::Opal::AppTimers

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
  # App#initialize (app.rb) calls StreamWeaver.strict_ids? unconditionally
  # to seed @strict_ids when the caller doesn't pass strict_ids: explicitly.
  # The real definition (lib/stream_weaver.rb) checks an ivar + the
  # SW_STRICT_IDS env var, but that file also requires server/service/cli/
  # admin/iterm -- none of them Opal-compatible, which is exactly why this
  # file (opal_entry.rb) requires app.rb directly and never requires
  # lib/stream_weaver.rb itself. That left StreamWeaver.strict_ids?
  # undefined in every Opal build (this extension, opal-build's standalone
  # HTML output) the moment app.rb started calling it -- "undefined method
  # `strict_ids?' for StreamWeaver", reproduced live against a rebuilt
  # extension bundle. Always false here, not a stub of the real check.
  #
  # Strict mode exists to catch two DSL callsites colliding on one dom id
  # across rerenders, and the Opal hosts cannot hit that: AppButtonPatch (above)
  # replaces source_location-derived ids with a counter reset per App build, so
  # every render of a given doc assigns the same ids in the same order. This
  # holds now that the extension starts the live runtime and re-renders on every
  # interaction, not only when it rendered once statically.
  def self.strict_ids?
    false
  end

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
