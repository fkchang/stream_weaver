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
    # Opal: source_location is nil — use counter-based IDs.
    # NOTE: the id: keyword is not incorporated into the stable_id here (known Phase 1 limitation).
    # Apps that use button "Label", id: loop_var will get position-based IDs instead.
    def button(label, id: nil, **options, &block)
      @button_counter += 1
      stable_id = id ? "opal_#{id}" : "opal_#{@button_counter}"
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
