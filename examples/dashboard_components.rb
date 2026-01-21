#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Dashboard Components
# Showcases all dashboard-style components with dark theme
# Run with: ./exe/streamweaver examples/dashboard_components.rb

app "Dashboard Components Demo", theme: :dark, layout: :wide do
  # Header with pulse indicator
  app_header "Dashboard Components", variant: :primary do
    pulse_indicator color: :green, label: "System Active"
  end

  header2 "Status Dots"
  text "Colored indicator dots with optional glow effect:"
  hstack spacing: :lg, align: :center do
    vstack spacing: :xs, align: :center do
      status_dot status: :red
      text "Red"
    end
    vstack spacing: :xs, align: :center do
      status_dot status: :yellow
      text "Yellow"
    end
    vstack spacing: :xs, align: :center do
      status_dot status: :green
      text "Green"
    end
    vstack spacing: :xs, align: :center do
      status_dot status: :green, pulse: true
      text "Pulsing"
    end
    vstack spacing: :xs, align: :center do
      status_dot status: :gray
      text "Gray"
    end
  end

  header2 "Badges"
  text "Count/label badges in various variants:"
  hstack spacing: :md do
    badge "5", variant: :default
    badge "3", variant: :danger
    badge "12", variant: :warning
    badge "OK", variant: :success
    badge "new", variant: :info
  end

  header2 "Stat Displays"
  text "Large metric numbers with labels:"
  hstack spacing: :xl do
    stat_display value: 24, label: "TOTAL", color: :default
    stat_display value: 7, label: "PENDING", color: :blue
    stat_display value: 12, label: "IN PROGRESS", color: :purple
    stat_display value: 5, label: "BLOCKED", color: :red
  end

  header2 "Type Tags"
  text "Activity type badges:"
  hstack spacing: :md do
    type_tag :research
    type_tag :task
    type_tag :escalation
    type_tag :communication
    type_tag :warning
    type_tag :info
  end

  header2 "Priority Items"
  text "Items with priority-colored left borders (hover to see slide effect):"
  vstack spacing: :md do
    priority_item priority: :critical, title: "Database migration blocked",
                  description: "Production schema changes require downtime window approval.",
                  meta_left: "ops", meta_right: "Schedule window"

    priority_item priority: :urgent, title: "API rate limits exceeded",
                  description: "Third-party integration hitting 429 errors. Need backoff strategy.",
                  meta_left: "backend", meta_right: "Implement retry"

    priority_item priority: :high, title: "Security audit findings",
                  description: "3 medium-severity items need remediation before release.",
                  meta_left: "security", meta_right: "Review findings"

    priority_item priority: :normal, title: "Documentation update",
                  description: "API docs need refresh for v2 endpoints.",
                  meta_left: "docs", meta_right: "Update guides"
  end

  header2 "Activity Items"
  text "Activity feed with time, title, summary, and type (hover to see highlight):"
  vstack spacing: :none do
    activity_item time: "15:00", title: "Performance analysis complete",
                  summary: "Identified 3 slow queries, recommended indexes",
                  type: :research

    activity_item time: "15:05", title: "Deployment approval needed",
                  summary: "Staging verified, awaiting prod sign-off",
                  type: :escalation

    activity_item time: "14:00", title: "Feature branch merged",
                  summary: "User preferences module integrated",
                  type: :task

    activity_item time: "13:30", title: "Standup notes shared",
                  summary: "Team aligned on sprint priorities",
                  type: :communication
  end
end
