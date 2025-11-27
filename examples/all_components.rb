#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/stream_weaver'

# Demo of all StreamWeaver components
App = app "Component Showcase" do
  header "StreamWeaver Component Showcase"

  # --- Text Components ---
  header3 "Text (Literal)"
  text "Plain text renders literally - **asterisks** stay as asterisks"

  header3 "Markdown (Parsed)"
  md "**Bold**, *italic*, `code`, and [links](https://example.com) are parsed"

  header3 "Headers"
  text "header (h2 default), header1-header6 for explicit levels"

  # --- Form Components ---
  header3 "Text Field"
  text_field :username, placeholder: "Enter username"

  header3 "Text Area"
  text_area :bio, placeholder: "Enter bio", rows: 3

  header3 "Checkbox"
  checkbox :enabled, "Enable feature"

  header3 "Select Dropdown (with default)"
  select :color, ["Red", "Green", "Blue", "Yellow"], default: "Green"

  header3 "Radio Group"
  radio_group :size, ["Small", "Medium", "Large"]

  header3 "Checkbox Group (Multi-Select)"
  checkbox_group :selected_items, select_all: "Select All", select_none: "Clear" do
    item "item_1" do
      text "First item"
    end
    item "item_2" do
      text "Second item"
    end
    item "item_3" do
      text "Third item"
    end
  end

  # --- Layout Components ---
  header3 "Div Container"
  div class: "todo-item" do
    text "This is inside a div container"
    text "Multiple components can be nested"
  end

  header3 "Card"
  card do
    text "Cards provide styled containers"
    text "Great for grouping related content"
  end

  # --- Interactive Components ---
  header3 "Buttons"
  button "Primary Action" do |state|
    state[:clicked] ||= 0
    state[:clicked] += 1
  end

  button "Secondary Action", style: :secondary do |state|
    state[:secondary_clicked] = true
  end

  if state[:clicked] && state[:clicked] > 0
    md "Primary button clicked **#{state[:clicked]}** times"
  end

  if state[:secondary_clicked]
    text "Secondary button was clicked!"
  end

  # --- Current State ---
  header3 "Current State"
  text "Username: #{state[:username] || '(none)'}"
  text "Bio: #{state[:bio] || '(none)'}"
  text "Enabled: #{state[:enabled] ? 'Yes' : 'No'}"
  text "Color: #{state[:color] || '(none)'}"
  text "Size: #{state[:size] || '(none)'}"
  text "Selected items: #{(state[:selected_items] || []).join(', ').then { |s| s.empty? ? '(none)' : s }}"
end

App.run! if __FILE__ == $0
