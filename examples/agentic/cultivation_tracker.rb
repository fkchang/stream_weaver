#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

# Daily Cultivation Check-in Form (matches /daily-checkin format)
# Updated: December 2025
cultivation_app = app "Daily Cultivation Check-in" do
  header "🌱 Daily Cultivation Check-in"
  text "Reflect on today's cultivation journey"

  # Determine checkin date
  checkin_date = if Time.now.hour < 18
    (Date.today - 1).strftime("%A, %B %d, %Y")
  else
    Date.today.strftime("%A, %B %d, %Y")
  end
  header3 "📅 #{checkin_date}"

  # Question 1: Energy level today
  header3 "1. How is your cultivation energy today? (1-10)"
  select :energy_today, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"], default: "8"

  # Question 2: Daily Narrative (what happened)
  header3 "2. What happened today?"
  text "Activities, meetings, events, notable moments"
  text_area :daily_narrative, placeholder: "Describe your day - this becomes your Daily Narrative section...", rows: 6, submit: false

  # Question 3: Achievements (unlimited - 7 slots)
  header3 "3. Cultivation Achievements"
  text "List your wins - progress of any size counts! (leave extras blank)"
  text_field :achievement_1, placeholder: "Achievement #1", submit: false
  text_field :achievement_2, placeholder: "Achievement #2", submit: false
  text_field :achievement_3, placeholder: "Achievement #3", submit: false
  text_field :achievement_4, placeholder: "Achievement #4 (optional)", submit: false
  text_field :achievement_5, placeholder: "Achievement #5 (optional)", submit: false
  text_field :achievement_6, placeholder: "Achievement #6 (optional)", submit: false
  text_field :achievement_7, placeholder: "Achievement #7 (optional)", submit: false

  # Question 4: Tomorrow's priority
  header3 "4. What's your #1 cultivation priority for tomorrow?"
  text_area :priority_tomorrow, placeholder: "Your top priority for tomorrow...", rows: 2, submit: false

  # Question 5: Tomorrow's energy forecast
  header3 "5. Energy level for tomorrow's practice? (1-10)"
  select :energy_tomorrow, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"], default: "8"

  # Question 6: Obstacles
  header3 "6. Any obstacles or resistances you faced?"
  text "(or leave blank if none)"
  text_area :obstacles, placeholder: "Describe any challenges, blockers, or resistances...", rows: 3, submit: false

  # Question 7: Learnings & Patterns
  header3 "7. Any learnings or patterns you noticed?"
  text "(or leave blank if none)"
  text_area :learnings, placeholder: "Insights, patterns, things you learned today...", rows: 3, submit: false
end

# Run in agentic mode - agent collects the reflection data
puts "\n╔══════════════════════════════════════════════════════════╗"
puts "║     🌱 Daily Cultivation Check-in (StreamWeaver)        ║"
puts "╚══════════════════════════════════════════════════════════╝\n"
puts "Fill out your daily reflection form in the browser."
puts "Click '🤖 Submit to Agent' when complete.\n"

result = cultivation_app.run_once!(timeout: 1800)

# Output JSON for agent consumption
puts "\n#{result.to_json}"
