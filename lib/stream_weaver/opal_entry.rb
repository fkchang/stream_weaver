# frozen_string_literal: true
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

# Opal-specific patches: fix methods that break in the browser.

# App#button and DisplayDSL#button use block.source_location.join(':').
# In Opal, source_location returns nil (no source maps in compiled JS).
# Override button in App to use a counter-based stable_id instead.
module StreamWeaver
  class App
    def button(label, id: nil, **options, &block)
      if block
        # Opal: source_location is nil — fall back to counter-based ID
        @button_counter += 1
        stable_id = "opal_#{@button_counter}"
      else
        @button_counter += 1
        stable_id = @button_counter.to_s
      end
      options[:modal_context] = @modal_context if @modal_context
      @components << Components::Button.new(label, stable_id, **options, &block)
    end
  end
end

# Opal-mode global `app` helper — replaces the Sinatra-wired StreamWeaver.app.
# Creates an OpalRuntime with the DSL block and exposes it to JS as SWRuntime.
def app(title, **_opts, &block)
  adapter = StreamWeaver::Adapter::Opal.new
  runtime = StreamWeaver::Opal::OpalRuntime.new(adapter: adapter)
  runtime.set_block(&block)
  StreamWeaver::Opal::OpalRuntime.expose_to_js(runtime)
  runtime
end
