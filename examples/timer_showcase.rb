#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Dev Machine Monitor
# Live system metrics from YOUR machine — CPU, Memory, Disk — updated every few seconds.
# Run with: bundle exec ruby examples/timer_showcase.rb

require_relative "../lib/stream_weaver"
require "etc"

THRESHOLD = {
  cpu:    { green: 2.0, yellow: 4.0 },
  memory: { green: 70.0, yellow: 85.0 },
  disk:   { green: 80.0, yellow: 90.0 }
}.freeze

LABEL = { cpu: "CPU LOAD (1m avg)", memory: "MEMORY %", disk: "DISK %" }.freeze
UNIT  = { cpu: "", memory: "%", disk: "%" }.freeze
METRIC_KEYS = %i[cpu memory disk].freeze
MAX_ALERTS  = 50

SPOTLIGHT_CSS = "<style>.sw-spotlight{box-shadow:0 0 0 3px var(--sw-color-primary,#c2410c)," \
                "0 0 12px rgba(194,65,12,0.3) !important;transition:box-shadow 0.3s ease}</style>"

CPU_PERCENT_PER_UNIT = (100.0 / Etc.nprocessors).freeze
EMOJI = { red: "\u{1F534}", yellow: "\u{1F7E1}", green: "\u{1F7E2}" }.freeze

def color_for(key, value)
  t = THRESHOLD[key]
  if value > t[:yellow] then :red
  elsif value > t[:green] then :yellow
  else :green
  end
end

def read_cpu    = `sysctl -n vm.loadavg`.scan(/[\d.]+/)[0].to_f
def read_memory = `ps -A -o %mem`.lines.drop(1).map(&:to_f).sum.round(1)
def read_disk   = `df -h /`.lines.last.split[4].to_i

def read_all_metrics
  { cpu: read_cpu, memory: read_memory, disk: read_disk }
end

def cpu_as_percent(load_avg)
  (load_avg * CPU_PERCENT_PER_UNIT).clamp(0, 100)
end

App = app "Dev Machine Monitor", theme: :dark, layout: :wide do
  app_header "Dev Machine Monitor", variant: :primary do
    pulse_indicator color: :green, label: "Live"
  end

  grid columns: 3, gap: :lg do
    METRIC_KEYS.each do |key|
      expandable_card key: key, title: key.to_s.capitalize, status: :green, initially_expanded: true do
        div id: "metric-#{key}" do
          stat_display value: "\u2014", label: LABEL[key], color: :blue
        end
      end
    end
  end

  div id: "spotlight-css", style: "display:none"

  header2 "Alerts"
  div id: "alert-feed" do
    text "Watching for threshold crossings..."
  end

  latest      = { cpu: 0.0, memory: 0.0, disk: 0.0 }
  prev_status = { cpu: :green, memory: :green, disk: :green }
  spotlight   = nil
  alert_count = 0

  every(3) do |streamer|
    latest.merge!(read_all_metrics)

    METRIC_KEYS.each do |key|
      value   = latest[key]
      color   = color_for(key, value)
      display = "#{value}#{UNIT[key]}"

      streamer.replace("#metric-#{key}") do
        div id: "metric-#{key}" do
          stat_display value: display, label: LABEL[key], color: color
          status_dot status: color, pulse: color != :green
        end
      end
    end
  end

  every(5) do |streamer|
    streamer.replace("#spotlight-css", SPOTLIGHT_CSS)

    scores  = { cpu: cpu_as_percent(latest[:cpu]), memory: latest[:memory], disk: latest[:disk] }
    hottest = scores.max_by { |_, v| v }.first

    if hottest != spotlight
      streamer.remove_class("#card-#{spotlight}", "sw-spotlight") if spotlight
      spotlight = hottest
    end
    streamer.add_class("#card-#{hottest}", "sw-spotlight")
  end

  every(10) do |streamer|
    now = Time.now.strftime("%H:%M:%S")

    METRIC_KEYS.each do |key|
      value = latest[key]
      color = color_for(key, value)
      prev  = prev_status[key]

      next if color == prev
      next if alert_count >= MAX_ALERTS

      direction = %i[yellow red].include?(color) ? "exceeded" : "dropped below"
      threshold = color == :green ? THRESHOLD[key][:green] : THRESHOLD[key][:yellow]

      streamer.prepend("#alert-feed") do
        div style: "padding:4px 8px;border-bottom:1px solid rgba(255,255,255,0.1)" do
          text "#{EMOJI[color]} #{key.to_s.capitalize} #{direction} #{threshold}#{UNIT[key]} (now #{value}#{UNIT[key]}) at #{now}"
        end
      end

      alert_count += 1
      prev_status[key] = color
    end
  end
end

App.run! if __FILE__ == $0
