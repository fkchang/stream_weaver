#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/stream_weaver'

# Agentic mode example with auto-close window feature
App = app "Quick Survey" do
  text "## Quick User Survey"
  text "Fill out this form. The window will close automatically after submission."

  text "Your Name:"
  text_field :name, placeholder: "Enter your full name"

  text "Your Email:"
  text_field :email, placeholder: "Enter your email address"

  text "Priority Level:"
  select :priority, ["Low", "Medium", "High", "Critical"]

  checkbox :agree, "I agree to terms and conditions"

end

# Run in agentic mode with auto-close enabled
# The browser window will close automatically 1 second after clicking submit
result = App.run_once!(auto_close_window: true)

# This line will execute after form submission
puts "\n✅ Agent received data:"
puts JSON.pretty_generate(result)
