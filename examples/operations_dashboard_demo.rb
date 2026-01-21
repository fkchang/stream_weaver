#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Operations Dashboard
# Demonstrates app_shell layout with sidebar, expandable cards, and dashboard components
# Run with: ./exe/streamweaver examples/operations_dashboard_demo.rb

app "Operations Dashboard", theme: :dark, layout: :fluid do
  app_shell sidebar_width: "340px" do
    main do
      # Header
      app_header "Operations Dashboard", variant: :primary do
        pulse_indicator color: :green, label: "All Systems Operational"
      end

      # Section header
      hstack justify: :between, align: :center do
        text "TEAMS"
        hstack spacing: :sm do
          button "Grid", variant: :secondary
          button "List", variant: :secondary
        end
      end

      # Team cards grid
      grid cols: 2, gap: :lg do
        # Engineering card
        expandable_card key: :engineering_expanded,
                        title: "Engineering",
                        subtitle: "Product Development",
                        badge_text: "5 activities",
                        status: :red,
                        initially_expanded: true do
          hstack spacing: :xl, justify: :start do
            stat_display value: 1, label: "RESEARCH", color: :blue
            stat_display value: 2, label: "TASKS", color: :purple
          end

          card variant: :outlined do
            text "Sprint velocity below target - 3 blockers identified"
          end

          vstack spacing: :none do
            activity_item time: "15:00", title: "Architecture review",
                          summary: "Evaluate microservices migration approach",
                          type: :research

            activity_item time: "14:30", title: "CI pipeline fixed",
                          summary: "Flaky tests resolved, builds stable",
                          type: :task
          end
        end

        # Design card
        expandable_card key: :design_expanded,
                        title: "Design",
                        subtitle: "UX & Visual",
                        badge_text: "4 activities",
                        status: :green do
          hstack spacing: :xl, justify: :start do
            stat_display value: 1, label: "RESEARCH", color: :blue
            stat_display value: 1, label: "TASKS", color: :purple
          end

          card variant: :outlined do
            text "Design system v2 on track - components finalized"
          end

          vstack spacing: :none do
            activity_item time: "15:00", title: "User research synthesis",
                          summary: "Interview findings compiled, patterns identified",
                          type: :research

            activity_item time: "15:05", title: "Accessibility review needed",
                          summary: "WCAG compliance check for new components",
                          type: :escalation
          end
        end

        # Operations card
        expandable_card key: :ops_expanded,
                        title: "Operations",
                        subtitle: "Infrastructure & SRE",
                        badge_text: "4 activities",
                        status: :yellow do
          hstack spacing: :xl, justify: :start do
            stat_display value: 1, label: "RESEARCH", color: :blue
            stat_display value: 1, label: "TASKS", color: :purple
          end

          card variant: :outlined do
            text "Monitoring upgrade in progress - 70% complete"
          end
        end

        # Product card
        expandable_card key: :product_expanded,
                        title: "Product",
                        subtitle: "Strategy & Roadmap",
                        badge_text: "4 activities",
                        status: :green do
          hstack spacing: :xl, justify: :start do
            stat_display value: 1, label: "RESEARCH", color: :blue
            stat_display value: 1, label: "TASKS", color: :purple
          end

          card variant: :outlined do
            text "Q2 roadmap finalized - stakeholder alignment complete"
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

    sidebar header: "Blockers" do
      badge "5", variant: :danger

      vstack spacing: :md do
        priority_item priority: :critical,
                      title: "Database capacity limit",
                      description: "Primary DB at 92% storage. Need immediate expansion or archival.",
                      meta_left: "ops",
                      meta_right: "Expand storage"

        priority_item priority: :urgent,
                      title: "Third-party API outage",
                      description: "Payment provider experiencing degraded performance.",
                      meta_left: "backend",
                      meta_right: "Monitor status"

        priority_item priority: :high,
                      title: "Security patch required",
                      description: "CVE-2024-1234 affects auth library. Update needed.",
                      meta_left: "security",
                      meta_right: "Apply patch"

        priority_item priority: :high,
                      title: "Mobile app store review",
                      description: "iOS submission rejected - privacy manifest missing.",
                      meta_left: "mobile",
                      meta_right: "Update manifest"

        priority_item priority: :high,
                      title: "Customer escalation",
                      description: "Enterprise client reporting data sync delays.",
                      meta_left: "support",
                      meta_right: "Investigate"
      end
    end
  end
end
