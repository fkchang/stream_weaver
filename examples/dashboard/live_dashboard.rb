#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Live Dashboard with Server-Push via StreamWeaver Streams
#
# This dashboard sets up a shell with stable DOM target IDs.
# It receives real-time updates via SSE from:
#   - An internal stream thread (built-in data source, using component DSL)
#   - External scripts via POST /stream/push (pluggable data sources)
#
# Run with: bundle exec ruby examples/dashboard/live_dashboard.rb
#
# To push updates externally:
#   bundle exec ruby examples/dashboard/feed_simulator.rb
# Or manually:
#   curl -X POST localhost:4567/stream/push \
#     -d 'target=#metric-rps&html=<div>MANUAL</div>'

require_relative '../../lib/stream_weaver'

App = app "Live Monitor", theme: :dark, layout: :fluid do
  app_shell sidebar_width: "360px" do
    main do
      app_header "System Monitor", variant: :primary do
        pulse_indicator color: :green, label: "Live"
      end

      header2 "KEY METRICS"
      grid cols: 3, gap: :md do
        div(id: "metric-rps") do
          card { stat_display value: "---", label: "REQ/SEC", color: :blue, size: :lg }
        end
        div(id: "metric-latency") do
          card { stat_display value: "---", label: "LATENCY", color: :purple, size: :lg }
        end
        div(id: "metric-errors") do
          card { stat_display value: "---", label: "ERROR RATE", color: :green, size: :lg }
        end
      end

      header2 "ACTIVITY"
      div(id: "activity-feed") do
        text "Waiting for events..."
      end
    end

    sidebar header: "Alerts" do
      div(id: "alerts-panel") do
        text "Monitoring..."
      end
    end
  end

  # Internal stream thread - pushes simulated metrics using component DSL.
  # No raw HTML needed - same components as the app definition.
  stream do |streamer|
    loop do
      rps = rand(1200..3500)
      streamer.replace("#metric-rps") do
        card { stat_display value: rps, label: "REQ/SEC", color: :blue, size: :lg }
      end
      sleep rand(1.5..3.0)

      latency = rand(12..85)
      streamer.replace("#metric-latency") do
        card { stat_display value: "#{latency}ms", label: "LATENCY", color: :purple, size: :lg }
      end
      sleep rand(1.5..3.0)

      err = (rand * 2.5).round(2)
      color = err > 1.5 ? :red : :green
      streamer.replace("#metric-errors") do
        card { stat_display value: "#{err}%", label: "ERROR RATE", color: color, size: :lg }
      end
      sleep rand(2.0..4.0)
    end
  end
end

App.run! if __FILE__ == $0
