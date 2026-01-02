# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

# Stacked bar chart demonstration
app "Stacked Bar Chart Demo" do
  header2 "StreamWeaver Charts - Phase 3"

  # Example 1: Array of hashes (most common format)
  card do
    header3 "Daily Timing by Phase"
    stacked_bar_chart data: [
      { label: "Mon", calendar: 45, news: 120, tasks: 30 },
      { label: "Tue", calendar: 50, news: 100, tasks: 35 },
      { label: "Wed", calendar: 40, news: 140, tasks: 25 },
      { label: "Thu", calendar: 55, news: 90, tasks: 40 },
      { label: "Fri", calendar: 35, news: 110, tasks: 45 }
    ], title: "Time Breakdown (seconds)"
  end

  columns widths: ['50%', '50%'] do
    column do
      # Example 2: Grouped (not stacked)
      card do
        header3 "Grouped Bars"
        stacked_bar_chart data: [
          { label: "Q1", sales: 100, costs: 60 },
          { label: "Q2", sales: 120, costs: 70 },
          { label: "Q3", sales: 140, costs: 75 },
          { label: "Q4", sales: 180, costs: 90 }
        ], stack: false, height: "200px"
      end
    end

    column do
      # Example 3: Horizontal stacked
      card do
        header3 "Horizontal Stacked"
        stacked_bar_chart data: [
          { label: "Team A", frontend: 40, backend: 35, devops: 25 },
          { label: "Team B", frontend: 30, backend: 45, devops: 25 },
          { label: "Team C", frontend: 50, backend: 30, devops: 20 }
        ], horizontal: true, height: "200px"
      end
    end
  end

  # Example 4: Hash of series format
  card do
    header3 "Series Format (Hash of Arrays)"
    stacked_bar_chart data: {
      "Revenue" => [100, 120, 140, 160, 180],
      "Expenses" => [60, 70, 75, 80, 90],
      "Profit" => [40, 50, 65, 80, 90]
    }, title: "Financial Overview"
  end

  # Example 5: Custom colors
  card do
    header3 "Custom Colors"
    stacked_bar_chart data: [
      { label: "Jan", a: 30, b: 20, c: 10 },
      { label: "Feb", a: 35, b: 25, c: 15 },
      { label: "Mar", a: 40, b: 30, c: 20 }
    ], colors: ["#1e40af", "#3b82f6", "#93c5fd"], height: "180px"
  end

  text "Stacked bar charts compare distributions across categories. Use stack: false for grouped bars."
end.run!
