# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

# Pie chart, doughnut chart, and area chart demonstration
app "Pie & Area Charts Demo" do
  header2 "StreamWeaver Charts - Pie, Doughnut & Area"

  columns widths: ['50%', '50%'] do
    column do
      # Example 1: Pie chart
      card do
        header3 "Pie Chart"
        pie_chart data: {
          "Calendar" => 45,
          "News" => 120,
          "Tasks" => 30,
          "Email" => 65
        }, title: "Time Distribution"
      end
    end

    column do
      # Example 2: Doughnut chart
      card do
        header3 "Doughnut Chart"
        doughnut_chart data: {
          "Frontend" => 40,
          "Backend" => 35,
          "DevOps" => 25
        }, title: "Team Allocation"
      end
    end
  end

  # Example 3: Area chart (line with fill)
  card do
    header3 "Area Chart"
    area_chart data: { Mon: 45, Tue: 52, Wed: 48, Thu: 61, Fri: 55, Sat: 67, Sun: 72 },
               title: "Weekly Trend",
               colors: ["#4a90d9"]
  end

  columns widths: ['50%', '50%'] do
    column do
      # Example 4: Custom cutout for doughnut
      card do
        header3 "Thin Doughnut (75% cutout)"
        doughnut_chart data: { A: 30, B: 50, C: 20 },
                       cutout: '75%',
                       height: "180px"
      end
    end

    column do
      # Example 5: Legend position
      card do
        header3 "Legend Bottom"
        pie_chart data: { Sales: 100, Marketing: 60, Engineering: 80 },
                  legend_position: 'bottom',
                  height: "180px"
      end
    end
  end

  # Example 6: Comparing area charts
  card do
    header3 "Smooth vs Straight Area"
    columns widths: ['50%', '50%'] do
      column do
        text "Smooth (default)"
        area_chart data: [10, 25, 15, 30, 20, 35],
                   colors: ["#10b981"],
                   height: "120px"
      end
      column do
        text "Straight lines"
        area_chart data: [10, 25, 15, 30, 20, 35],
                   smooth: false,
                   colors: ["#f59e0b"],
                   height: "120px"
      end
    end
  end

  text "Pie/doughnut show proportions. Area charts show cumulative trends."
end.run!
