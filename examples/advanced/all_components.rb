#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

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

  header3 "Columns (Monica-style sidebar layout)"
  columns widths: ['30%', '70%'] do
    column class: "sidebar-facts" do
      div class: "sidebar-section" do
        header4 "Work"
        text "Software Engineer at Acme Corp"
      end

      div class: "sidebar-section" do
        header4 "Location"
        text "San Francisco, CA"
      end

      div class: "sidebar-section" do
        header4 "Contact"
        text "email@example.com"
        text "(555) 123-4567"
      end

      div class: "sidebar-section" do
        header4 "Significant Other"
        text "Jane Doe"
      end
    end

    column do
      collapsible "Background", expanded: true do
        md "This person has been working in tech for **10 years** and specializes in Ruby development."
      end

      collapsible "Key Facts" do
        md "- Met at RubyConf 2023\n- Interested in open source\n- Coffee enthusiast"
      end
    end
  end

  header3 "Equal-width Columns"
  columns do
    column do
      card do
        text "Column 1"
        text "Equal width flex"
      end
    end
    column do
      card do
        text "Column 2"
        text "Also equal width"
      end
    end
    column do
      card do
        text "Column 3"
        text "Three columns!"
      end
    end
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

  # --- Status & Selection Components ---
  header3 "Status Badge"
  text "Visual match indicators with reasoning:"
  div class: "status-badges-demo" do
    status_badge :strong, "Perfect match for your preferences"
    status_badge :maybe, "Good fit, but has some dark themes"
    status_badge :skip, "Not recommended - wrong genre"
  end

  header3 "Tag Buttons (Single Select)"
  text "Default style:"
  tag_buttons :category, ["Fiction", "Non-fiction", "Mystery", "Sci-Fi"]

  text "Destructive style (for elimination):"
  tag_buttons :eliminate_reason, ["Too dark", "Wrong genre", "Bad reviews", "Not interested"], style: :destructive

  text "Selected category: #{state[:category] || '(none)'}"
  text "Elimination reason: #{state[:eliminate_reason] || '(none)'}"

  header3 "External Link Button"
  text "Opens URL in new tab (no form submit):"
  external_link_button "Visit Example.com", url: "https://example.com"

  text "Opens URL AND submits form (for agentic mode):"
  external_link_button "Submit & Open Google", url: "https://google.com", submit: true

  # --- Current State ---
  header3 "Current State"
  text "Username: #{state[:username] || '(none)'}"
  text "Bio: #{state[:bio] || '(none)'}"
  text "Enabled: #{state[:enabled] ? 'Yes' : 'No'}"
  text "Color: #{state[:color] || '(none)'}"
  text "Size: #{state[:size] || '(none)'}"
  text "Selected items: #{(state[:selected_items] || []).join(', ').then { |s| s.empty? ? '(none)' : s }}"
  text "Category: #{state[:category] || '(none)'}"
  text "Elimination reason: #{state[:eliminate_reason] || '(none)'}"
end

App.run! if __FILE__ == $0
