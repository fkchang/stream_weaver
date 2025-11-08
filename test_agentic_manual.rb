#!/usr/bin/env ruby
require_relative 'lib/stream_weaver'

app = app "Simple Test" do
  text "## Fill this out"
  text_field :name, placeholder: "Your name"
  text_field :email, placeholder: "Your email"
  checkbox :agree, "I agree"
end

result = app.run_once!(timeout: 60, open_browser: false)
puts "\n=== RESULT ==="
puts JSON.pretty_generate(result)
puts "\n=== END ==="
