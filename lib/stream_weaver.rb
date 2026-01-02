# frozen_string_literal: true

require_relative "stream_weaver/version"
require_relative "stream_weaver/adapter/base"
require_relative "stream_weaver/adapter/alpinejs"
require_relative "stream_weaver/theme"
require_relative "stream_weaver/app"
require_relative "stream_weaver/components"
require_relative "stream_weaver/views"
require_relative "stream_weaver/server"
require_relative "stream_weaver/service"
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
  end

  # Global app helper method for DSL
  #
  # @param title [String] The title of the application
  # @param layout [Symbol] Layout mode (:default, :wide, :full, :fluid)
  # @param theme [Symbol] Theme (:default, :dashboard, :document)
  # @param theme_overrides [Hash] CSS variable overrides (e.g., { primary: "#0066cc" })
  # @param components [Array<Module>] Custom component modules to include
  # @param block [Proc] The DSL block defining the UI
  # @return [StreamWeaver::SinatraApp] The generated Sinatra application
  # @example
  #   my_app = app "My App", theme: :dashboard do
  #     text "Hello, world!"
  #   end
  def self.app(title, layout: :default, theme: :default, theme_overrides: {}, components: [], scripts: [], stylesheets: [], &block)
    app = App.new(title, layout: layout, theme: theme, theme_overrides: theme_overrides, components: components, scripts: scripts, stylesheets: stylesheets, &block)
    sinatra_app = app.generate
    # Capture for service mode
    @last_generated_app = sinatra_app
    sinatra_app
  end
end

# Global helper method (exported to main namespace)
def app(title, layout: :default, theme: :default, theme_overrides: {}, components: [], scripts: [], stylesheets: [], &block)
  StreamWeaver.app(title, layout: layout, theme: theme, theme_overrides: theme_overrides, components: components, scripts: scripts, stylesheets: stylesheets, &block)
end
