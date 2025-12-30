# frozen_string_literal: true

# Events Demo - demonstrates on_change, on_blur, debounce, and hover callbacks
#
# Run with: ruby examples/events_demo.rb

require_relative '../lib/stream_weaver'

app = StreamWeaver.app "Events Demo" do
  header1 "Events & Callbacks Demo"

  md "This example demonstrates **event callbacks** for form components and **hover effects** for containers."

  # Initialize state
  state[:change_count] ||= 0
  state[:blur_count] ||= 0
  state[:last_change] ||= ""
  state[:validated_email] ||= ""
  state[:email_valid] ||= nil
  state[:search_results] ||= []

  # =========================================
  # on_change Example
  # =========================================
  header2 "on_change Callback"
  md "The text field below triggers a callback on every change (debounced):"

  text_field :search_query,
    placeholder: "Type to search...",
    debounce: 300,
    on_change: ->(s, value) {
      s[:change_count] += 1
      s[:last_change] = value

      # Simulate search results
      if value.length >= 2
        s[:search_results] = [
          "Result for '#{value}' #1",
          "Result for '#{value}' #2",
          "Result for '#{value}' #3"
        ]
      else
        s[:search_results] = []
      end
    }

  card do
    text "Change count: #{state[:change_count]}"
    text "Last change: #{state[:last_change]}"

    if state[:search_results].any?
      header4 "Search Results:"
      vstack spacing: :xs do
        state[:search_results].each do |result|
          text "• #{result}"
        end
      end
    end
  end

  # =========================================
  # on_blur Example
  # =========================================
  header2 "on_blur Callback"
  md "The email field below validates when you leave the field (blur):"

  text_field :email,
    placeholder: "Enter email address...",
    on_blur: ->(s, value) {
      s[:blur_count] += 1
      s[:validated_email] = value

      # Simple email validation
      if value.empty?
        s[:email_valid] = nil
      elsif value.include?("@") && value.include?(".")
        s[:email_valid] = true
      else
        s[:email_valid] = false
      end
    }

  card do
    text "Blur count: #{state[:blur_count]}"

    if state[:email_valid] == true
      text "✅ Valid email: #{state[:validated_email]}"
    elsif state[:email_valid] == false
      text "❌ Invalid email format"
    else
      text "Enter an email and click outside the field to validate"
    end
  end

  # =========================================
  # Checkbox on_change
  # =========================================
  header2 "Checkbox on_change"
  md "Checkboxes can also have change callbacks:"

  state[:features] ||= []

  checkbox :dark_mode, "Enable dark mode",
    on_change: ->(s, value) {
      if value
        s[:features] << "dark_mode" unless s[:features].include?("dark_mode")
      else
        s[:features].delete("dark_mode")
      end
    }

  checkbox :notifications, "Enable notifications",
    on_change: ->(s, value) {
      if value
        s[:features] << "notifications" unless s[:features].include?("notifications")
      else
        s[:features].delete("notifications")
      end
    }

  card do
    text "Enabled features: #{state[:features].empty? ? 'none' : state[:features].join(', ')}"
  end

  # =========================================
  # Select on_change
  # =========================================
  header2 "Select on_change"
  md "Select dropdowns also support change callbacks:"

  state[:theme_history] ||= []

  select :theme, %w[Light Dark System],
    default: "Light",
    on_change: ->(s, value) {
      s[:theme_history] << value
      s[:theme_history] = s[:theme_history].last(5) # Keep last 5
    }

  card do
    text "Theme history: #{state[:theme_history].join(' → ')}"
  end

  # =========================================
  # Hover Effects
  # =========================================
  header2 "Hover Effects"
  md "Containers can have hover classes for visual feedback:"

  hstack spacing: :md do
    div hover_class: "sw-hover-highlight", class: "hover-demo-box" do
      text "Hover me!"
    end

    div hover_class: "sw-hover-lift", class: "hover-demo-box" do
      text "I lift on hover"
    end

    div hover_class: "sw-hover-glow", class: "hover-demo-box" do
      text "I glow on hover"
    end
  end

  # =========================================
  # Custom CSS for demo
  # =========================================
  md """
---
**How it works:**
- **on_change**: Callback fires when input value changes (with optional debounce delay)
- **on_blur**: Callback fires when input loses focus (good for validation)
- **debounce**: Milliseconds to wait before firing on_change (default: 500ms)
- **hover_class**: CSS class added on mouseenter, removed on mouseleave

Built-in hover classes: `sw-hover-highlight`, `sw-hover-lift`, `sw-hover-glow`
"""

  md "---"
  button "Reset Demo", style: :secondary do |s|
    s.clear
  end
end

app.run!
