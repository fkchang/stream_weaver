# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

# Simple bar chart demonstration
app "Bar Chart Demo" do
  header2 "StreamWeaver Charts - Phase 1"

  # Example 1: Inline hash data (simplest)
  card do
    header3 "Inline Data (Hash)"
    bar_chart data: {
      "Calendar" => 45,
      "News" => 120,
      "Tasks" => 30,
      "Email" => 65
    }, title: "Time by Activity (seconds)"
  end

  columns widths: ['50%', '50%'] do
    column do
      # Example 2: Horizontal bar chart
      card do
        header3 "Horizontal Bars"
        hbar_chart data: {
          "Phase A" => 25,
          "Phase B" => 45,
          "Phase C" => 15,
          "Phase D" => 35
        }, colors: ["#4a90d9"], height: "200px"
      end
    end

    column do
      # Example 3: Explicit labels/values
      card do
        header3 "Explicit Labels/Values"
        bar_chart labels: %w[Mon Tue Wed Thu Fri],
                  values: [12, 19, 8, 15, 22],
                  colors: ["#10b981"],
                  height: "200px"
      end
    end
  end

  # Example 4: Custom colors
  card do
    header3 "Custom Styling"
    bar_chart data: { "A" => 100, "B" => 80, "C" => 60, "D" => 40, "E" => 20 },
              colors: ["#c45b28"],
              title: "Performance Scores",
              show_values: true,
              height: "180px"
  end

  text "Charts rendered with Chart.js - loaded via CDN only when charts are present."
end.run!
