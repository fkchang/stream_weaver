#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Cabinet Control-style Dashboard
# Demonstrates all dashboard + layout components
# Run with: ./exe/streamweaver examples/cabinet_control_demo.rb

app "Cabinet Control", theme: :dark, layout: :fluid do
  app_shell sidebar_width: "340px" do
    main do
      # Header
      app_header "Cabinet Control", variant: :primary do
        pulse_indicator color: :green, label: "System Active"
      end

      # Section header
      hstack justify: :between, align: :center do
        text "SECRETARIES"
        hstack spacing: :sm do
          button "Grid", variant: :secondary
          button "List", variant: :secondary
        end
      end

      # Secretary cards grid
      grid cols: 2, gap: :lg do
        # Scheduler card
        expandable_card key: :scheduler_expanded,
                        title: "Scheduler",
                        subtitle: "Time Management",
                        badge_text: "5 activities",
                        status: :red,
                        initially_expanded: true do
          hstack spacing: :xl, justify: :start do
            stat_display value: 1, label: "RESEARCH", color: :blue
            stat_display value: 2, label: "TASKS", color: :purple
          end

          card variant: :outlined do
            text "Jira rolling issues crisis - 65 issues (71% of sprint)"
          end

          vstack spacing: :none do
            activity_item time: "15:00", title: "Sprint planning review",
                          summary: "Analyze rolling issues, identify blockers",
                          type: :research

            activity_item time: "14:30", title: "Calendar sync complete",
                          summary: "All events synced with mobile",
                          type: :task
          end
        end

        # Martial Arts card
        expandable_card key: :martial_arts_expanded,
                        title: "Martial Arts",
                        subtitle: "BJJ, MMA, Teaching",
                        badge_text: "4 activities",
                        status: :green do
          hstack spacing: :xl, justify: :start do
            stat_display value: 1, label: "RESEARCH", color: :blue
            stat_display value: 1, label: "TASKS", color: :purple
          end

          card variant: :outlined do
            text "Balanced all tracks - curriculum planning underway"
          end

          vstack spacing: :none do
            activity_item time: "15:00", title: "BJJ curriculum & recovery research",
                          summary: "4-6 month cycles, weekly focus subjects, over-35 needs deloads",
                          type: :research

            activity_item time: "15:05", title: "Need teaching sequence context",
                          summary: "Curriculum exists but lacks YOUR sequencing",
                          type: :escalation
          end
        end

        # Finance card
        expandable_card key: :finance_expanded,
                        title: "Finance",
                        subtitle: "Money Awareness",
                        badge_text: "4 activities",
                        status: :yellow do
          hstack spacing: :xl, justify: :start do
            stat_display value: 1, label: "RESEARCH", color: :blue
            stat_display value: 1, label: "TASKS", color: :purple
          end

          card variant: :outlined do
            text "Establish visibility into spending patterns"
          end
        end

        # Cultiv Dev card
        expandable_card key: :cultiv_dev_expanded,
                        title: "Cultiv Dev",
                        subtitle: "System Architecture",
                        badge_text: "4 activities",
                        status: :green do
          hstack spacing: :xl, justify: :start do
            stat_display value: 1, label: "RESEARCH", color: :blue
            stat_display value: 1, label: "TASKS", color: :purple
          end

          card variant: :outlined do
            text "Track cultiv-ai as coherent system of systems"
          end
        end
      end

      # Summary stats
      header2 "THIS WEEK"
      hstack spacing: :xl do
        card do
          stat_display value: 24, label: "ACTIVITIES", color: :blue, size: :lg
        end
        card do
          stat_display value: 7, label: "RESEARCH", color: :blue, size: :lg
        end
        card do
          stat_display value: 12, label: "TASKS", color: :purple, size: :lg
        end
        card do
          stat_display value: 5, label: "ESCALATIONS", color: :red, size: :lg
        end
      end
    end

    sidebar header: "Escalations" do
      badge "5", variant: :danger

      vstack spacing: :md do
        priority_item priority: :critical,
                      title: "Needs /covey-interview",
                      description: "Cannot proceed without roles, values, mission defined. This blocks all habit tracking.",
                      meta_left: "covey",
                      meta_right: "Run /covey-interview"

        priority_item priority: :urgent,
                      title: "Jira RED Status",
                      description: "65 rolling issues (71% of sprint). HEDG-2613 rolling 11 sprints.",
                      meta_left: "scheduler",
                      meta_right: "Triage session"

        priority_item priority: :high,
                      title: "Clutter zones undefined",
                      description: "Cannot track decluttering progress without zone definitions.",
                      meta_left: "home",
                      meta_right: "Define zones"

        priority_item priority: :high,
                      title: "Platform decision",
                      description: "Need to choose: Substack vs Medium vs Ghost for blogging.",
                      meta_left: "creator",
                      meta_right: "Make decision"

        priority_item priority: :high,
                      title: "ADR bootstrap",
                      description: "Missing architecture decision records for system choices.",
                      meta_left: "cultiv_dev",
                      meta_right: "Create ADR template"
      end
    end
  end
end
