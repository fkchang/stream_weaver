#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script showing agentic mode behavior
# This simulates an AI agent collecting user input

require_relative 'lib/stream_weaver'
require 'json'

puts "\n" + "="*60
puts "AGENTIC MODE DEMO"
puts "="*60
puts "\nThis demo shows how an AI agent would collect user input:"
puts "1. Browser will open with a form"
puts "2. Fill out the form fields"
puts "3. Click the '🤖 Submit to Agent' button"
puts "4. The agent receives the data as JSON and exits"
puts "\n" + "="*60 + "\n"

# Create a survey form
survey_app = app "User Feedback Survey" do
  text "## Please provide your feedback"

  text_field :name, placeholder: "Your name"
  text_field :email, placeholder: "Your email"
  text_field :company, placeholder: "Company name (optional)"

  select :rating, ["⭐", "⭐⭐", "⭐⭐⭐", "⭐⭐⭐⭐", "⭐⭐⭐⭐⭐"]

  checkbox :newsletter, "Subscribe to our newsletter"
  checkbox :followup, "I'd like a follow-up call"
end

# Run in agentic mode - blocks until user submits
puts "[Agent] Waiting for user input...\n"
result = survey_app.run_once!(timeout: 300)

# Agent received the data!
puts "\n" + "="*60
puts "[Agent] ✅ Data received from user!"
puts "="*60
puts "\nStructured data:"
puts JSON.pretty_generate(result)
puts "\n" + "="*60

# Agent can now process the data
puts "\n[Agent] Processing feedback..."
puts "  - User: #{result[:name] || 'Anonymous'}"
puts "  - Email: #{result[:email] || 'Not provided'}"
puts "  - Company: #{result[:company] || 'N/A'}"
puts "  - Rating: #{result[:rating] || 'Not rated'}"
puts "  - Newsletter: #{result[:newsletter] ? 'Yes' : 'No'}"
puts "  - Follow-up: #{result[:followup] ? 'Yes' : 'No'}"
puts "\n[Agent] ✅ Feedback processed successfully!\n"
