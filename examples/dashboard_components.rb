#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Dashboard Components (Cabinet Control style)
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
    stat_display value: 24, label: "ACTIVITIES", color: :default
    stat_display value: 7, label: "RESEARCH", color: :blue
    stat_display value: 12, label: "TASKS", color: :purple
    stat_display value: 5, label: "ESCALATIONS", color: :red
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
  text "Escalation-style items with colored borders:"
  vstack spacing: :md do
    priority_item priority: :critical, title: "Needs /covey-interview",
                  description: "Cannot proceed without roles, values, mission defined. This blocks all habit tracking.",
                  meta_left: "covey", meta_right: "Run /covey-interview"

    priority_item priority: :urgent, title: "Jira RED Status",
                  description: "65 rolling issues (71% of sprint). HEDG-2613 rolling 11 sprints.",
                  meta_left: "scheduler", meta_right: "Triage session"

    priority_item priority: :high, title: "Platform decision",
                  description: "Need to choose: Substack vs Medium vs Ghost for blogging.",
                  meta_left: "creator", meta_right: "Make decision"

    priority_item priority: :normal, title: "Documentation update",
                  description: "Keep README files current.",
                  meta_left: "cultiv_dev", meta_right: "Update docs"
  end

  header2 "Activity Items"
  text "Activity feed with time, title, summary, and type:"
  vstack spacing: :none do
    activity_item time: "15:00", title: "BJJ curriculum & recovery research",
                  summary: "4-6 month cycles, weekly focus subjects, over-35 needs deloads",
                  type: :research

    activity_item time: "15:05", title: "Need teaching sequence context",
                  summary: "Curriculum exists but lacks YOUR sequencing for tren lock, standing grappling",
                  type: :escalation

    activity_item time: "14:00", title: "Training log framework established",
                  summary: "ROUNDS, FOCUS_CHECK, VALIDATIONS, REFINEMENTS, TEACHING",
                  type: :task

    activity_item time: "13:30", title: "Sent weekly progress update",
                  summary: "Summarized achievements and blockers",
                  type: :communication
  end
end
