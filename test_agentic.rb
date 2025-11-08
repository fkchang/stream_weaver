#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick test script to verify agentic mode with automated submission

require_relative 'lib/stream_weaver'
require 'net/http'
require 'uri'
require 'json'

# Create a simple form
app = app "Test Survey" do
  text "## Quick Test"
  text_field :name, placeholder: "Name"
  text_field :email, placeholder: "Email"
  checkbox :newsletter, "Subscribe to newsletter"
  select :plan, ["Free", "Pro", "Enterprise"]
end

# Simulate agent behavior: auto-submit after 3 seconds
Thread.new do
  sleep 3
  puts "\n[Test] Auto-submitting form with test data..."

  begin
    # Try ports 4567-4577 to find the running server
    port = (4567..4577).find do |p|
      begin
        TCPSocket.new('127.0.0.1', p).close
        true
      rescue
        false
      end
    end

    puts "[Test] Found server on port #{port}"
    uri = URI("http://localhost:#{port}/submit")
    response = Net::HTTP.post_form(uri, {
      'name' => 'Test User',
      'email' => 'test@example.com',
      'newsletter' => 'on',
      'plan' => 'Pro'
    })
    puts "[Test] Form submitted, response: #{response.code}"
  rescue => e
    puts "[Test] Error submitting: #{e.message}"
  end
end

# Run in agentic mode
puts "[Test] Starting agentic mode..."
result = app.run_once!(timeout: 10, open_browser: false)

puts "\n[Test] ✅ Received result:"
puts JSON.pretty_generate(result)

exit 0
