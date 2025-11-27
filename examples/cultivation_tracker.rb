#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/stream_weaver'

# Daily Cultivation Tracking Form
cultivation_app = app "Daily Cultivation Tracker" do
  header "🌱 Daily Cultivation Reflection"
  text "Track your mastery journey with intention and awareness"

  # Question 1: Energy level today
  header3 "1. How is your cultivation energy today?"
  select :energy_today, ["1 - Very Low", "2", "3", "4", "5 - Moderate", "6", "7", "8", "9", "10 - Peak Energy"]
  text_area :energy_description, placeholder: "Brief description of your energy state...", rows: 2

  # Question 2: Three achievements
  header3 "2. What are 3 cultivation achievements from today?"
  text "(Progress of any size counts)"
  text_field :achievement_1, placeholder: "Achievement #1"
  text_field :achievement_2, placeholder: "Achievement #2"
  text_field :achievement_3, placeholder: "Achievement #3"

  # Question 3: Tomorrow's priority
  header3 "3. What's your #1 cultivation priority for tomorrow?"
  text_area :priority_tomorrow, placeholder: "Your top priority...", rows: 2

  # Question 4: Tomorrow's energy forecast
  header3 "4. Energy level for tomorrow's practice:"
  select :energy_tomorrow, ["1 - Very Low", "2", "3", "4", "5 - Moderate", "6", "7", "8", "9", "10 - Peak Energy"]

  # Question 5: Obstacles
  header3 "5. Any cultivation obstacles or resistances you faced?"
  text_area :obstacles, placeholder: "Describe any challenges or resistances...", rows: 3

  # Question 6: Gratitude
  header3 "6. What cultivation insights are you grateful for today?"
  text_area :gratitude, placeholder: "Insights, breakthroughs, or learnings...", rows: 3

  # Question 7: Other reflections
  header3 "7. Any other reflections on your mastery journey?"
  text_area :reflections, placeholder: "Additional thoughts, observations, or notes...", rows: 4
end

# Run in agentic mode - agent collects the reflection data
puts "\n╔══════════════════════════════════════════════════════════╗"
puts "║     🌱 Daily Cultivation Tracker (Agentic Mode)        ║"
puts "╚══════════════════════════════════════════════════════════╝\n"
puts "Fill out your daily reflection form."
puts "Click '🤖 Submit to Agent' when complete.\n"

result = cultivation_app.run_once!(timeout: 600)

# Agent processes the cultivation data
puts "\n╔══════════════════════════════════════════════════════════╗"
puts "║              ✅ Cultivation Data Received               ║"
puts "╚══════════════════════════════════════════════════════════╝\n"

puts "📊 Daily Summary:"
puts "  Energy Today: #{result[:energy_today]}"
puts "  Energy Tomorrow: #{result[:energy_tomorrow]}"
puts "\n🎯 Achievements:"
puts "  1. #{result[:achievement_1]}"
puts "  2. #{result[:achievement_2]}"
puts "  3. #{result[:achievement_3]}"
puts "\n🔮 Tomorrow's Priority:"
puts "  #{result[:priority_tomorrow]}"
puts "\n💪 Obstacles Faced:"
puts "  #{result[:obstacles]}"
puts "\n🙏 Gratitude:"
puts "  #{result[:gratitude]}"
puts "\n💭 Reflections:"
puts "  #{result[:reflections]}"

puts "\n" + "="*60
puts "Raw JSON data:"
puts JSON.pretty_generate(result)
puts "="*60

puts "\n✨ Cultivation tracking complete. Keep growing! 🌱\n"
