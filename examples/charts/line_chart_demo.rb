# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

# Line chart and sparkline demonstration
app "Line Chart Demo" do
  header2 "StreamWeaver Charts - Phase 2"

  # Example 1: Simple line chart from array
  card do
    header3 "Trend Data (Array)"
    line_chart data: [12, 19, 8, 15, 22, 18, 25],
               title: "Weekly Progress"
  end

  columns widths: ['50%', '50%'] do
    column do
      # Example 2: Line chart with options
      card do
        header3 "With Fill"
        line_chart data: { Mon: 5, Tue: 12, Wed: 8, Thu: 15, Fri: 10 },
                   fill: true,
                   colors: ["#4a90d9"],
                   height: "180px"
      end
    end

    column do
      # Example 3: No smoothing
      card do
        header3 "Straight Lines"
        line_chart data: [10, 25, 15, 30, 20],
                   smooth: false,
                   colors: ["#10b981"],
                   height: "180px"
      end
    end
  end

  # Example 4: Sparklines (minimal, inline charts)
  card do
    header3 "Sparklines"
    text "Compact trend indicators without axes or labels:"

    columns widths: ['33%', '33%', '33%'] do
      column do
        text "Revenue"
        sparkline data: [45, 52, 48, 61, 55, 67, 72]
      end

      column do
        text "Users"
        sparkline data: [120, 135, 142, 138, 155, 162, 170], colors: ["#4a90d9"]
      end

      column do
        text "Errors"
        sparkline data: [8, 12, 6, 15, 4, 3, 2], colors: ["#dc2626"]
      end
    end
  end

  # Example 5: No points
  card do
    header3 "Clean Line (No Points)"
    line_chart data: { Jan: 100, Feb: 120, Mar: 115, Apr: 135, May: 150, Jun: 145 },
               points: false,
               colors: ["#c45b28"],
               height: "160px"
  end

  text "Charts rendered with Chart.js - line_chart for full charts, sparkline for compact trends."
end.run!
