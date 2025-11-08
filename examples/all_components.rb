#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/stream_weaver'

# Demo of all 6 MVP components
App = app "Component Showcase" do
  text "## StreamWeaver Component Showcase"

  text "### Text Field"
  text_field :username, placeholder: "Enter username"

  text "### Checkbox"
  checkbox :enabled, "Enable feature"

  text "### Select Dropdown"
  select :color, ["Red", "Green", "Blue", "Yellow"]

  text "### Div Container"
  div class: "todo-item" do
    text "This is inside a div container"
    text "Multiple components can be nested"
  end

  text "### Button (Primary)"
  button "Primary Action" do |state|
    state[:clicked] ||= 0
    state[:clicked] += 1
  end

  button "Secondary Action", style: :secondary do |state|
    state[:secondary_clicked] = true
  end

  if state[:clicked] && state[:clicked] > 0
    text "Primary button clicked #{state[:clicked]} times"
  end

  if state[:secondary_clicked]
    text "Secondary button was clicked!"
  end

  text "### Current State"
  text "Username: #{state[:username] || '(none)'}"
  text "Enabled: #{state[:enabled] ? 'Yes' : 'No'}"
  text "Color: #{state[:color] || '(none)'}"
end

App.run! if __FILE__ == $0
