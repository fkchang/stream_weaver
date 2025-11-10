#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/stream_weaver'

# Agentic mode example - collect data and return to agent
App = app "User Survey" do
  text "## User Information Survey"
  text "Please fill out this form. When you click Submit, the data will be returned to the calling process."

  text "Your Name:"
  text_field :name, placeholder: "Enter your full name"

  text "Your Email:"
  text_field :email, placeholder: "Enter your email address"

  text "Priority Level:"
  select :priority, ["Low", "Medium", "High", "Critical"]

  checkbox :agree, "I agree to terms and conditions"

end

# Run in agentic mode - blocks until form submitted, outputs JSON, then exits
# The form will automatically show a "Submit to Agent" button
result = App.run_once!

# This line will execute after form submission
puts "\n✅ Agent received data:"
puts JSON.pretty_generate(result)
