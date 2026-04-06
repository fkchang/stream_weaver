#!/usr/bin/env ruby
# frozen_string_literal: true

# ============================================================================
# Generate-More Spike (T1)
# ============================================================================
#
# Standalone spike demonstrating the generate-more loop using push-to-state.
# This is throwaway code -- T10 will do the real implementation.
#
# Key architectural decision being validated:
#   Push-to-state, NOT push-to-DOM.
#   The "agent" pushes new options into server-side state, and StreamWeaver's
#   reactive re-render handles display. No direct DOM manipulation via SSE.
#
# Run with:
#   cd examples/generate_more_spike && ruby app.rb
#
# What it demonstrates:
#   1. "Generate More" button with prompt input
#   2. Skeleton placeholders appear while generating
#   3. Simulated agent (Thread.new) detects request, sleeps, pushes state
#   4. Page re-renders reactively with new options replacing skeletons
#   5. Timeout after 15s shows error message
#   6. Cancel button aborts pending generation
#   7. Session-scoped request queue
# ============================================================================

require_relative '../../lib/stream_weaver'
require 'json'
require 'securerandom'

# ============================================================================
# Generate-More State Machine (Discovered through implementation)
# ============================================================================
# States:
#   :idle       - No generation in progress. Generate button enabled.
#   :generating - Request queued, skeletons visible, cancel button shown.
#   :timed_out  - 15s elapsed without all options arriving.
#   :cancelled  - User cancelled, agent acknowledged. Transient -> idle.
#
# Transitions:
#   idle -> generating       (user clicks Generate)
#   generating -> idle       (all options received)
#   generating -> timed_out  (15s timeout, checked in timer)
#   generating -> cancelled  (user clicks Cancel)
#   cancelled -> idle        (immediate, after cleanup)
#   timed_out -> idle        (user clicks Generate again)
# ============================================================================

# ============================================================================
# Shared state store (simulates file-backed DeckState for the spike)
# ============================================================================
# In T10 this becomes DeckState with file-backed JSON per session.
# Key finding: session cookies can't hold this state (agent thread has no
# access to Sinatra sessions). A shared server-side store keyed by session
# ID is required.

module SpikeState
  @mutex = Mutex.new
  @sessions = {}
  @pending_requests = []
  @cancelled_sessions = {}

  class << self
    attr_reader :mutex

    def get(session_id)
      @mutex.synchronize do
        @sessions[session_id] ||= default_state
        @sessions[session_id].dup
      end
    end

    def update(session_id)
      @mutex.synchronize do
        @sessions[session_id] ||= default_state
        yield @sessions[session_id]
      end
    end

    def queue_request(request)
      @mutex.synchronize { @pending_requests << request }
    end

    def take_requests
      @mutex.synchronize do
        taken = @pending_requests.dup
        @pending_requests.clear
        taken
      end
    end

    def cancel(session_id)
      @mutex.synchronize { @cancelled_sessions[session_id] = true }
    end

    def cancelled?(session_id)
      @mutex.synchronize { @cancelled_sessions.delete(session_id) || false }
    end

    private

    def default_state
      {
        options: [
          { id: "opt_1", label: "Monolith", description: "Single deployable unit, simpler operations", generated: false },
          { id: "opt_2", label: "Microservices", description: "Independent services, complex but scalable", generated: false },
        ],
        generate_status: :idle,
        requested_count: 0,
        received_count: 0,
        prompt: nil,
        started_at: nil,
      }
    end
  end
end

# ============================================================================
# Simulated agent options
# ============================================================================

SIMULATED_OPTIONS = [
  { label: "Event-Driven", description: "Loosely coupled via message bus, great for async workflows" },
  { label: "Serverless", description: "Functions-as-a-service, pay per invocation, auto-scaling" },
  { label: "Modular Monolith", description: "Best of both: monolith deployment, modular internals" },
  { label: "Hexagonal", description: "Ports and adapters pattern, testable and flexible" },
  { label: "CQRS", description: "Separate read/write models for optimized query performance" },
  { label: "Service Mesh", description: "Sidecar proxies handle networking, observability built-in" },
]

# ============================================================================
# Simulated Agent Thread
# ============================================================================
# In the real system, an external agent polls GET /deck/pending.
# Here we simulate with a thread watching the shared state.

$streamer_ref = nil
$sim_option_index = 0

def start_agent_simulator
  Thread.new do
    loop do
      requests = SpikeState.take_requests

      requests.each do |request|
        session_id = request[:session_id]
        count = request[:count]
        prompt = request[:prompt]

        $stderr.puts "[Agent] Processing generate request: count=#{count}, prompt=#{prompt.inspect}"

        count.times do |i|
          # Check cancellation
          if SpikeState.cancelled?(session_id)
            $stderr.puts "[Agent] Generation cancelled for session #{session_id}"
            SpikeState.update(session_id) { |s| s[:generate_status] = :idle }
            push_rerender(session_id)
            break
          end

          # Simulate LLM generation delay (1-3 seconds per option)
          sleep(1.0 + rand * 2.0)

          # Check cancellation again after sleep
          if SpikeState.cancelled?(session_id)
            $stderr.puts "[Agent] Generation cancelled (post-sleep) for session #{session_id}"
            SpikeState.update(session_id) { |s| s[:generate_status] = :idle }
            push_rerender(session_id)
            break
          end

          # Check if already timed out
          state = SpikeState.get(session_id)
          if state[:generate_status] != :generating
            $stderr.puts "[Agent] State is #{state[:generate_status]}, stopping generation"
            break
          end

          # Pick a simulated option
          opt = SIMULATED_OPTIONS[$sim_option_index % SIMULATED_OPTIONS.length]
          $sim_option_index += 1

          desc = prompt && !prompt.strip.empty? ?
            "#{opt[:description]} (prompted: #{prompt})" :
            opt[:description]

          opt_id = "gen_#{SecureRandom.hex(4)}"

          # PUSH TO STATE -- the key architectural decision
          SpikeState.update(session_id) do |s|
            s[:options] << {
              id: opt_id,
              label: opt[:label],
              description: desc,
              generated: true,
            }
            s[:received_count] += 1
            $stderr.puts "[Agent] Pushed option #{i + 1}/#{count}: #{opt[:label]} (#{s[:received_count]}/#{s[:requested_count]})"

            # If all received, transition to idle
            if s[:received_count] >= s[:requested_count]
              s[:generate_status] = :idle
              $stderr.puts "[Agent] All options received -> idle"
            end
          end

          # Notify browser to re-render via SSE
          push_rerender(session_id)
        end
      end

      sleep 0.5 unless requests.any?
    end
  end
end

def push_rerender(session_id)
  return unless $streamer_ref
  html = build_options_html(session_id)
  $streamer_ref.replace("#spike-content", html)
end

# ============================================================================
# HTML builder for option cards + skeletons + status
# ============================================================================
# This is what StreamWeaver's reactive re-render would produce.
# The component tree reads state and renders the current view.

def build_options_html(session_id)
  state = SpikeState.get(session_id)
  status = state[:generate_status]
  options = state[:options]
  requested = state[:requested_count]
  received = state[:received_count]
  remaining = status == :generating ? [requested - received, 0].max : 0

  html = +""

  # Status banner
  case status
  when :generating
    elapsed = state[:started_at] ? (Time.now.to_f - state[:started_at]).round(1) : 0
    html << %(<div style="background:#1e3a5f;border:1px solid #3b82f6;border-radius:8px;padding:12px 16px;margin-bottom:16px;display:flex;align-items:center;justify-content:space-between">)
    html << %(<div style="display:flex;align-items:center;gap:8px">)
    html << %(<div style="width:12px;height:12px;border-radius:50%;background:#3b82f6;animation:pulse 1s ease-in-out infinite"></div>)
    html << %(<span style="color:#93c5fd">Generating #{requested} option(s)... #{received}/#{requested} received (#{elapsed}s)</span>)
    html << %(</div>)
    html << %(<form method="post" action="/spike/cancel" style="margin:0">)
    html << %(<input type="hidden" name="session_id" value="#{session_id}">)
    html << %(<button type="submit" style="background:#dc2626;color:white;border:none;border-radius:6px;padding:6px 16px;cursor:pointer;font-size:0.875rem">Cancel</button>)
    html << %(</form></div>)
  when :timed_out
    html << %(<div style="background:#451a03;border:1px solid #f59e0b;border-radius:8px;padding:12px 16px;margin-bottom:16px">)
    html << %(<span style="color:#fbbf24">Generation timed out after 15s. #{received}/#{requested} options received. Click Generate to try again.</span>)
    html << %(</div>)
  end

  # Options grid
  html << %(<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px">)

  options.each do |opt|
    border = opt[:generated] ? "#22c55e" : "#374151"
    badge = opt[:generated] ?
      %(<span style="background:#166534;color:#86efac;font-size:0.7rem;padding:2px 8px;border-radius:9999px;margin-left:8px">generated</span>) : ""

    html << %(<div style="background:#1f2937;border:1px solid #{border};border-radius:12px;padding:16px">)
    html << %(<h3 style="margin:0 0 8px;color:#f3f4f6;font-size:1rem">#{opt[:label]}#{badge}</h3>)
    html << %(<p style="margin:0;color:#9ca3af;font-size:0.875rem">#{opt[:description]}</p>)
    html << %(</div>)
  end

  # Skeleton placeholders
  remaining.times do
    html << %(<div style="background:#1f2937;border:1px solid #374151;border-radius:12px;padding:16px">)
    html << %(<div style="background:#374151;height:20px;width:60%;border-radius:4px;margin-bottom:12px;animation:shimmer 1.5s ease-in-out infinite alternate"></div>)
    html << %(<div style="background:#374151;height:14px;width:90%;border-radius:4px;margin-bottom:8px;animation:shimmer 1.5s ease-in-out infinite alternate 0.2s"></div>)
    html << %(<div style="background:#374151;height:14px;width:75%;border-radius:4px;animation:shimmer 1.5s ease-in-out infinite alternate 0.4s"></div>)
    html << %(</div>)
  end

  html << %(</div>)

  # CSS for animations (included each push since SSE replaces content)
  html << %(<style>)
  html << %(@keyframes shimmer{from{opacity:0.5}to{opacity:1}})
  html << %(@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.4}})
  html << %(</style>)

  html
end

# ============================================================================
# StreamWeaver App
# ============================================================================

SpikeApp = app "Generate-More Spike", theme: :dark, stylesheets: [
  "data:text/css,@keyframes shimmer{from{opacity:0.5}to{opacity:1}}@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.4}}"
] do
  # Assign a session ID on first visit
  state[:spike_session] ||= SecureRandom.hex(8)
  session_id = state[:spike_session]

  # Initialize session state if needed
  SpikeState.get(session_id)
  spike_state = SpikeState.get(session_id)

  header1 "Generate-More Spike"
  text "Demonstrates the push-to-state architecture for the generate-more loop."
  text "Options below are pre-seeded. Click 'Generate More' to simulate an agent generating additional options."

  div style: "border-top:1px solid #374151;margin:16px 0"

  # Generate controls
  card do
    header3 "Generate More Options"

    text_field :gen_prompt, placeholder: "e.g., Focus on event-driven patterns", label: "Prompt (optional)"

    select :gen_count, ["1", "2", "3", "4", "5"], default: "2", label: "Number of options"

    is_generating = spike_state[:generate_status] == :generating

    unless is_generating
      button "Generate More", variant: :primary do |s|
        sid = s[:spike_session]
        count = (s[:gen_count] || "2").to_i
        prompt = s[:gen_prompt]

        # Transition to :generating
        SpikeState.update(sid) do |ss|
          ss[:generate_status] = :generating
          ss[:requested_count] = count
          ss[:received_count] = 0
          ss[:prompt] = prompt
          ss[:started_at] = Time.now.to_f
        end

        # Queue request for the agent simulator
        SpikeState.queue_request(
          session_id: sid,
          count: count,
          prompt: prompt,
          timestamp: Time.now,
        )

        $stderr.puts "[Server] Generate request queued: session=#{sid} count=#{count} prompt=#{prompt.inspect}"
      end
    end
  end

  # Content area -- this div is replaced by SSE pushes
  div id: "spike-content" do
    # Initial render: show current options from spike state
    spike_state[:options].each do |opt|
      card do
        badge_label = opt[:generated] ? " [generated]" : ""
        header3 "#{opt[:label]}#{badge_label}"
        text opt[:description]
      end
    end

    # Show skeletons if currently generating
    if spike_state[:generate_status] == :generating
      remaining = [spike_state[:requested_count] - spike_state[:received_count], 0].max
      remaining.times do
        div style: "background:#1f2937;border:1px solid #374151;border-radius:12px;padding:16px;margin-top:8px" do
          div style: "background:#374151;height:20px;width:60%;border-radius:4px;margin-bottom:12px;animation:shimmer 1.5s ease-in-out infinite alternate"
          div style: "background:#374151;height:14px;width:90%;border-radius:4px;margin-bottom:8px;animation:shimmer 1.5s ease-in-out infinite alternate 0.2s"
          div style: "background:#374151;height:14px;width:75%;border-radius:4px;animation:shimmer 1.5s ease-in-out infinite alternate 0.4s"
        end
      end
    end

    if spike_state[:generate_status] == :timed_out
      alert variant: :warning, title: "Timeout" do
        text "Generation timed out after 15s. #{spike_state[:received_count]}/#{spike_state[:requested_count]} options received."
      end
    end
  end

  # State debug panel
  div style: "margin-top:24px;padding:16px;background:#111827;border:1px solid #1f2937;border-radius:8px" do
    header4 "State Debug"
    text "Session: #{session_id}"
    text "Status: #{spike_state[:generate_status]}"
    text "Options: #{spike_state[:options].length} (#{spike_state[:options].count { |o| o[:generated] }} generated)"
    text "Requested: #{spike_state[:requested_count]}, Received: #{spike_state[:received_count]}"
    if spike_state[:started_at] && spike_state[:generate_status] == :generating
      text "Elapsed: #{(Time.now.to_f - spike_state[:started_at]).round(1)}s"
    end
  end

  # SSE stream: agent pushes re-rendered content here
  stream do |streamer|
    $streamer_ref = streamer
    # Timeout checker loop
    loop do
      sleep 1
      SpikeState.mutex.synchronize do
        SpikeState.instance_variable_get(:@sessions).each do |sid, s|
          next unless s[:generate_status] == :generating && s[:started_at]
          elapsed = Time.now.to_f - s[:started_at]
          if elapsed > 15
            s[:generate_status] = :timed_out
            $stderr.puts "[Server] Session #{sid} timed out (#{elapsed.round(1)}s)"
            Thread.new { push_rerender(sid) }
          end
        end
      end
    end
  end
end

# ============================================================================
# Custom routes (cancel endpoint)
# ============================================================================

SpikeApp.post '/spike/cancel' do
  state = session[:streamlit_state] ||= {}
  session_id = state[:spike_session]

  if session_id
    SpikeState.cancel(session_id)
    SpikeState.update(session_id) { |s| s[:generate_status] = :idle }
    $stderr.puts "[Server] Cancel for session #{session_id}"
    Thread.new { push_rerender(session_id) }
  end

  redirect '/'
end

# ============================================================================
# Start
# ============================================================================

agent_thread = start_agent_simulator
$stderr.puts "[Spike] Agent simulator started"

SpikeApp.run!
