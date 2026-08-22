# frozen_string_literal: true

require 'fileutils'

require_relative "stream_weaver/version"
require_relative "stream_weaver/action_token"
require_relative "stream_weaver/utils"
require_relative "stream_weaver/adapter/base"
require_relative "stream_weaver/adapter/alpinejs"
require_relative "stream_weaver/theme"
require_relative "stream_weaver/component_assets"
require_relative "stream_weaver/fonts"
require_relative "stream_weaver/display_dsl"
require_relative "stream_weaver/component_registry"
require_relative "stream_weaver/layout_registry"
require_relative "stream_weaver/app"
require_relative "stream_weaver/components"
require_relative "stream_weaver/views"
require_relative "stream_weaver/page_shell"
require_relative "stream_weaver/interaction_runner"
require_relative "stream_weaver/component_renderer"
require_relative "stream_weaver/feed_builder"
require_relative "stream_weaver/pushable"
require_relative "stream_weaver/portfile"
require_relative "stream_weaver/feed"
require_relative "stream_weaver/streamer"
require_relative "stream_weaver/resource"
require_relative "stream_weaver/dev_fallback_overlay"
require_relative "stream_weaver/server"
require_relative "stream_weaver/service"
require_relative "stream_weaver/service_client"
require_relative "stream_weaver/admin"
require_relative "stream_weaver/export/html_exporter"
require_relative "stream_weaver/iterm"
require_relative "stream_weaver/cli"

# StreamWeaver - Declarative Ruby DSL for building interactive web UIs
#
# @example Basic usage
#   require 'stream_weaver'
#
#   app "Hello World" do
#     text_field :name, placeholder: "Your name"
#     button "Submit" do |state|
#       puts "Hello, #{state[:name]}!"
#     end
#   end.run!
module StreamWeaver
  class Error < StandardError; end

  # Stores the last generated app for service mode to capture
  class << self
    attr_accessor :last_generated_app

    # True while Service.load_app is evaluating an app file. Makes run! a
    # warn-and-no-op so a file ending in `end.run!` (the documented standalone
    # pattern) can be loaded into a running service without starting a second
    # server inside it and killing the service.
    attr_accessor :service_loading

    # Opts every App into strict interactive-id checking without threading
    # strict_ids: through each construction site. An explicit
    # App.new(strict_ids: true/false) always wins over this global; the
    # SW_STRICT_IDS env var is the fallback so CI can turn it on for a run.
    attr_writer :strict_ids

    def strict_ids?
      return @strict_ids unless @strict_ids.nil?
      %w[1 true yes].include?(ENV['SW_STRICT_IDS'].to_s.downcase)
    end

    # Mirrors server.rb's RACK_ENV convention. Strict-id violations raise
    # everywhere except production, where taking a live page down over an id
    # the framework has already auto-disambiguated would be the worse failure.
    def production_env?
      ENV['RACK_ENV'] == 'production'
    end
  end

  def self.default_adapter
    Adapter::AlpineJS.new
  end

  # Connect to a running StreamWeaver app and return a Feed client.
  #
  # @param name [String, nil] App title to look up via portfile
  # @param port [Integer, nil] Explicit port number
  # @param url [String, nil] Explicit URL
  # @return [StreamWeaver::Feed] Feed client for pushing updates
  # @example By name (reads portfile)
  #   feed = StreamWeaver.connect("Live Monitor")
  # @example Single running app (auto-discover)
  #   feed = StreamWeaver.connect
  # @example Explicit port
  #   feed = StreamWeaver.connect(port: 4569)
  # @example Explicit URL
  #   feed = StreamWeaver.connect(url: "http://myhost:4569")
  def self.connect(name = nil, port: nil, url: nil)
    if url
      Feed.new(url)
    elsif port
      Feed.new("http://127.0.0.1:#{port}")
    elsif name
      Feed.new(Portfile.read(name))
    else
      Feed.new(Portfile.discover_single)
    end
  end

  # Global app helper method for DSL
  def self.app(title, layout: :default, theme: :default, theme_overrides: {}, components: [], scripts: [], stylesheets: [], fonts: [], &block)
    app = App.new(title, layout: layout, theme: theme, theme_overrides: theme_overrides, components: components, scripts: scripts, stylesheets: stylesheets, fonts: fonts, &block)
    sinatra_app = app.generate
    @last_generated_app = sinatra_app
    sinatra_app
  end
end

# Global helper method (exported to main namespace)
def app(title, layout: :default, theme: :default, theme_overrides: {}, components: [], scripts: [], stylesheets: [], fonts: [], &block)
  StreamWeaver.app(title, layout: layout, theme: theme, theme_overrides: theme_overrides, components: components, scripts: scripts, stylesheets: stylesheets, fonts: fonts, &block)
end
