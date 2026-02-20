#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone mode example - auto-detects port and opens browser
#
# Usage:
#   ruby standalone_app.rb
#
# The app will auto-detect an available port and open the browser.

require 'bundler/setup'
require 'stream_weaver'

App = app "Standalone Mode Example" do
  header1 "Running in Standalone Mode"
  
  text "This app auto-detected a port and opened the browser."
  text "Perfect for quick one-off scripts!"
  
  text_field :message, placeholder: "Type something..."
  
  if state[:message] && !state[:message].empty?
    div do
      text "You typed: #{state[:message]}"
    end
  end
  
  button "Clear" do |state|
    state[:message] = ""
  end
end

# Start the app - browser will open automatically
App.run! if __FILE__ == $0
