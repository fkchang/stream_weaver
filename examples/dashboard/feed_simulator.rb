#!/usr/bin/env ruby
# frozen_string_literal: true

# External Feed Simulator - pushes targeted updates to a running StreamWeaver app.
#
# Demonstrates the Feed DSL: connect by app name (via portfile) and push
# updates using the same component DSL as the app itself. Zero raw HTML.
#
# Usage:
#   1. Start the dashboard: bundle exec ruby examples/dashboard/live_dashboard.rb
#   2. In another terminal:  bundle exec ruby examples/dashboard/feed_simulator.rb

require_relative '../../lib/stream_weaver'

feed = StreamWeaver.connect("Live Monitor")

ACTIVITIES = [
  ["Deploy v2.14.3 completed",        "Zero-downtime rolling deploy to production"],
  ["Anomaly detected in API gateway",  "Latency spike on /api/v2/users (p99 > 200ms)"],
  ["Auto-scaler triggered",           "Added 2 instances to web-pool (CPU > 75%)"],
  ["SSL certificate renewed",         "Wildcard cert renewed for 90 days"],
  ["Database failover test passed",    "RDS Multi-AZ failover completed in 28s"],
  ["Rate limiter adjusted",           "API rate limit increased to 1000 req/min"],
  ["Cache hit ratio improved",        "Redis cache hit ratio now at 94.2%"],
  ["Backup verification passed",      "Nightly snapshot restored and validated"],
].freeze

ALERTS = [
  [:critical, "High error rate on API",        "Error rate exceeded 5% threshold for 3 minutes"],
  [:urgent,   "Memory pressure detected",      "Worker nodes approaching OOM limits"],
  [:high,     "Slow query detected",           "Query on orders table taking >5s"],
  [:normal,   "Log volume increasing",         "Log ingestion rate up 40% this week"],
  [:critical, "Disk usage critical",           "Production DB volume at 94% capacity"],
  [:urgent,   "SSL cert expiring soon",        "Certificate expires in 7 days"],
].freeze

puts "Feed simulator started - connected to #{feed.url}"
puts "Press Ctrl+C to stop\n\n"

loop do
  # Push a new activity event (prepend to feed)
  act = ACTIVITIES.sample
  time_str = Time.now.strftime("%H:%M:%S")

  feed.prepend("#activity-feed") do
    activity_item time: time_str, title: act[0], summary: act[1], type: :task
  end
  puts "  [activity] #{time_str} #{act[0]}"
  sleep rand(3.0..6.0)

  # Occasionally push an alert update
  if rand < 0.4
    alert = ALERTS.sample
    feed.prepend("#alerts-panel") do
      priority_item priority: alert[0], title: alert[1], description: alert[2]
    end
    puts "  [alert]    #{alert[0].upcase}: #{alert[1]}"
  end
  sleep rand(2.0..5.0)
end
