# frozen_string_literal: true
# Browser-only require tree. Does NOT require Sinatra, Phlex, AlpineJS,
# iTerm, service, service_client, admin, streamer, feed, or cli.

require_relative "stream_weaver/version"
require_relative "stream_weaver/utils"
require_relative "stream_weaver/theme"
require_relative "stream_weaver/display_dsl"
require_relative "stream_weaver/app"
require_relative "stream_weaver/components"
require_relative "stream_weaver/adapter/base"
# Phase 1 placeholders — implemented in subsequent tasks:
require_relative "stream_weaver/adapter/opal"
require_relative "stream_weaver/opal/renderer"
require_relative "stream_weaver/opal/runtime"
