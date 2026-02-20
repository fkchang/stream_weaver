# frozen_string_literal: true

# Example config.ru for running StreamWeaver apps with Puma-dev
#
# Usage:
#   1. Create this file in your app directory
#   2. Symlink to Puma-dev: `puma-dev link`
#   3. Access at http://[directory-name].test
#
# The app will use the PORT environment variable set by Puma-dev
# and will not auto-open the browser.

require 'bundler/setup'
require 'stream_weaver'

# Define your StreamWeaver app
App = app "Hello from Puma-dev" do
  header1 "Welcome to StreamWeaver on Puma-dev!"
  
  text "This app is running on Puma-dev with a memorable URL."
  
  text_field :name, placeholder: "Enter your name"
  
  if state[:name] && state[:name].strip != ""
    text "Hello, #{state[:name]}! 👋"
  end
  
  button "Clear" do |state|
    state[:name] = ""
  end
end

# Run the app (browser won't auto-open when PORT env var is set by Puma-dev)
run App
