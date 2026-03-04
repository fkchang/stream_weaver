#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Endpoint Health Checker
# A genuinely useful URL health checker — configure endpoints, see live status and response times.
# Run with: bundle exec ruby examples/timer_health_checker.rb

require_relative "../lib/stream_weaver"
require "net/http"
require "uri"

ENDPOINTS = [
  { name: "GitHub",   key: :github,   url: "https://github.com",          sla_ms: 500 },
  { name: "RubyGems", key: :rubygems, url: "https://rubygems.org",        sla_ms: 300 },
  { name: "Httpbin",  key: :httpbin,  url: "https://httpbin.org/delay/1", sla_ms: 800 },
].freeze

STATUS_BADGE = { up: { text: "UP", variant: :success }, slow: { text: "SLOW", variant: :warning }, down: { text: "DOWN", variant: :danger } }.freeze
STATUS_COLOR = { up: :green, slow: :yellow, down: :red }.freeze
STATUS_EMOJI = { up: "\u2705", slow: "\u26A0\uFE0F", down: "\u274C" }.freeze
RING_CLASS   = { down: "sw-alert-ring", slow: "sw-warn-ring" }.freeze

RING_CSS = "<style>" \
           ".sw-alert-ring{box-shadow:0 0 0 3px #ef4444,0 0 12px rgba(239,68,68,0.4) !important;transition:box-shadow 0.3s ease}" \
           ".sw-warn-ring{box-shadow:0 0 0 3px #eab308,0 0 12px rgba(234,179,8,0.3) !important;transition:box-shadow 0.3s ease}" \
           "</style>"

SKIP_SSL_VERIFY = ENV.fetch("SSL_VERIFY", "0") == "0"

def check_endpoint(ep)
  uri   = URI(ep[:url])
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = uri.scheme == "https"
  http.verify_mode  = OpenSSL::SSL::VERIFY_NONE if SKIP_SSL_VERIFY && http.use_ssl?
  http.open_timeout = 5
  http.read_timeout = 10
  http.get(uri.request_uri)

  elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
  { status: elapsed_ms > ep[:sla_ms] ? :slow : :up, ms: elapsed_ms }
rescue StandardError
  { status: :down, ms: nil }
end

def format_timing(result)
  result[:ms] ? "#{result[:ms]}ms" : "timeout"
end

App = app "Endpoint Health Checker", theme: :dark, layout: :wide do
  app_header "Endpoint Health Checker", variant: :primary do
    pulse_indicator color: :green, label: "Monitoring"
  end

  grid columns: ENDPOINTS.size, gap: :lg do
    ENDPOINTS.each do |ep|
      expandable_card key: ep[:key], title: ep[:name], subtitle: ep[:url],
                      status: :gray, badge_text: "\u2014", initially_expanded: true do
        div id: "health-#{ep[:key]}" do
          stat_display value: "\u2014", label: "RESPONSE TIME", color: :blue
          text "SLA: #{ep[:sla_ms]}ms"
        end
      end
    end
  end

  div id: "ring-css", style: "display:none"

  header2 "Status Log"
  div id: "status-log" do
    text "Waiting for first health check..."
  end

  prev_status = {}

  every(5) do |streamer|
    streamer.replace("#ring-css", RING_CSS)

    ENDPOINTS.each do |ep|
      key    = ep[:key]
      result = check_endpoint(ep)
      status = result[:status]

      streamer.replace("#health-#{key}") do
        div id: "health-#{key}" do
          stat_display value: format_timing(result), label: "RESPONSE TIME", color: STATUS_COLOR[status]
          status_dot status: STATUS_COLOR[status], pulse: status != :up
          text "SLA: #{ep[:sla_ms]}ms"
          badge STATUS_BADGE[status][:text], variant: STATUS_BADGE[status][:variant]
        end
      end

      card_id = "#card-#{key}"
      RING_CLASS.each_value { |cls| streamer.remove_class(card_id, cls) }
      streamer.add_class(card_id, RING_CLASS[status]) if RING_CLASS[status]

      old = prev_status[key]
      if old && old != status
        streamer.prepend("#status-log") do
          div style: "padding:4px 8px;border-bottom:1px solid rgba(255,255,255,0.1)" do
            text "#{STATUS_EMOJI[status]} #{ep[:name]} \u2192 #{status.to_s.upcase} (#{format_timing(result)}) at #{Time.now.strftime('%H:%M:%S')}"
          end
        end
      end
      prev_status[key] = status
    end
  end
end

App.run! if __FILE__ == $0
