#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Simple Authentication with Basic HTTP Auth
#
# This example demonstrates the simplest authentication approach
# using HTTP Basic Auth - perfect for internal tools and admin panels.
#
# Setup:
#   gem install stream_weaver
#
# Run:
#   ADMIN_USER=admin ADMIN_PASS=secret ruby examples/basic_auth_demo.rb
#
# Then visit http://localhost:4567 and login with admin/secret

require_relative '../lib/stream_weaver'

# Set credentials from environment (or use defaults for demo)
ADMIN_USER = ENV.fetch('ADMIN_USER', 'admin')
ADMIN_PASS = ENV.fetch('ADMIN_PASS', 'secret')

puts "\n🔐 Starting authenticated app..."
puts "📝 Login credentials:"
puts "   Username: #{ADMIN_USER}"
puts "   Password: #{ADMIN_PASS}"
puts ""

# Enable Basic Authentication
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  username == ADMIN_USER && password == ADMIN_PASS
end

# Protected App
App = app "🔒 Admin Dashboard" do
  alert(variant: :info, title: "Authentication Active") do
    text "This page is protected with HTTP Basic Authentication"
  end
  
  header1 "Admin Dashboard"
  
  text "You're successfully authenticated! This content is protected."
  
  card do
    header3 "Server Information"
    text "User: #{ADMIN_USER}"
    text "Session: Active"
    text "Auth Method: HTTP Basic"
  end
  
  card do
    header3 "Sample Admin Actions"
    
    button "View Logs" do |state|
      state[:logs] = [
        "#{Time.now} - User logged in",
        "#{Time.now - 100} - System started",
        "#{Time.now - 300} - Database connected"
      ]
    end
    
    if state[:logs]
      vstack spacing: :sm do
        state[:logs].each do |log|
          text log
        end
      end
    end
  end
  
  alert(variant: :warning) do
    text "⚠️ Note: Basic Auth sends credentials with every request. Always use HTTPS in production!"
  end
end

App.run! if __FILE__ == $0
