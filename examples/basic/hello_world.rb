#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

App = app "Hello World" do
  header1 "Welcome to StreamWeaver!"

  text_field :name, placeholder: "Enter your name"

  if state[:name] && state[:name].strip != ""
    text "Hello, #{state[:name]}! 👋"

    checkbox :subscribe, "Subscribe to newsletter"

    if state[:subscribe]
      text "✅ You're subscribed!"
    end
  end
end

App.run! if __FILE__ == $0
