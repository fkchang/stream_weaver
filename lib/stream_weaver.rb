# frozen_string_literal: true

require_relative "stream_weaver/version"
require_relative "stream_weaver/adapter/base"
require_relative "stream_weaver/adapter/alpinejs"
require_relative "stream_weaver/app"
require_relative "stream_weaver/components"
require_relative "stream_weaver/views"
require_relative "stream_weaver/server"

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

  # Global app helper method for DSL
  #
  # @param title [String] The title of the application
  # @param block [Proc] The DSL block defining the UI
  # @return [StreamWeaver::SinatraApp] The generated Sinatra application
  # @example
  #   my_app = app "My App" do
  #     text "Hello, world!"
  #   end
  def self.app(title, &block)
    app = App.new(title, &block)
    app.generate
  end
end

# Global helper method (exported to main namespace)
def app(title, &block)
  StreamWeaver.app(title, &block)
end
