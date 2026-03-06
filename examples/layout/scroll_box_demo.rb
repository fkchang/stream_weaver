#!/usr/bin/env ruby
# frozen_string_literal: true

# Demonstrates the scroll_box component for constraining vertical space.
#
# Use cases shown:
# 1. Static long content  - Terms & conditions, documentation
# 2. Live log output      - Auto-scrolling log tail via SSE timers
# 3. Chat/message history - Scrollable message list
# 4. Data list            - Long lists constrained to a fixed height
#
# Run with: bundle exec ruby examples/layout/scroll_box_demo.rb

require_relative "../../lib/stream_weaver"

# Simulated log messages for the live demo
LOG_MESSAGES = [
  "INFO  -- : Request GET /api/v2/users completed in 42ms",
  "INFO  -- : Cache HIT for key session:abc123",
  "DEBUG -- : SQL (1.2ms) SELECT * FROM users WHERE active = true",
  "INFO  -- : Request POST /api/v2/orders completed in 118ms",
  "WARN  -- : Slow query detected (>100ms) on orders#index",
  "INFO  -- : Background job ProcessEmailJob enqueued",
  "INFO  -- : WebSocket connection opened for channel:dashboard",
  "ERROR -- : Redis connection timeout after 5000ms, retrying...",
  "INFO  -- : Redis reconnected successfully",
  "DEBUG -- : Cache MISS for key metrics:daily, computing...",
  "INFO  -- : Request GET /health returned 200 in 2ms",
  "WARN  -- : Rate limit approaching for IP 192.168.1.42 (85/100)",
  "INFO  -- : Deploy webhook received, version v2.14.3",
  "INFO  -- : Asset compilation completed in 3.2s",
  "ERROR -- : Failed to send notification email: SMTP timeout",
].freeze

CHAT_MESSAGES = [
  { user: "Alice", text: "Has anyone seen the latency spike on the API gateway?" },
  { user: "Bob", text: "Yeah, I'm looking into it now. Seems like a connection pool issue." },
  { user: "Carol", text: "We saw something similar last week. Check the pgbouncer config." },
  { user: "Alice", text: "Good call. The max_client_conn was set too low." },
  { user: "Bob", text: "Bumped it to 200, deploying now." },
  { user: "Carol", text: "Keep an eye on memory usage after that change." },
  { user: "Bob", text: "Will do. Monitoring dashboard is up." },
  { user: "Alice", text: "Latency is back to normal. Nice work!" },
].freeze

TERMS = <<~TERMS
  1. ACCEPTANCE OF TERMS. By accessing and using this service, you accept and agree to be bound by the terms and provision of this agreement.

  2. PROVISION OF SERVICE. The service is provided "as is" and on an "as available" basis. We make no warranties, expressed or implied, and hereby disclaim all warranties including without limitation, implied warranties of merchantability and fitness for a particular purpose.

  3. USER CONDUCT. You agree not to use the service for any unlawful purpose or in any way that could damage, disable, or impair the service. You agree not to attempt to gain unauthorized access to any part of the service.

  4. INTELLECTUAL PROPERTY. All content included in the service, such as text, graphics, logos, and software, is the property of the service provider and is protected by copyright and other intellectual property laws.

  5. PRIVACY POLICY. Your use of the service is also governed by our Privacy Policy, which is incorporated into these terms by reference. Please review our Privacy Policy to understand our practices.

  6. LIMITATION OF LIABILITY. In no event shall the service provider be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the service.

  7. MODIFICATIONS TO TERMS. We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of the new terms.

  8. GOVERNING LAW. These terms shall be governed by and construed in accordance with the laws of the applicable jurisdiction, without regard to conflict of law provisions.

  9. TERMINATION. We may terminate or suspend your access to the service at any time, without prior notice, for conduct that we believe violates these terms or is harmful to other users.

  10. CONTACT. If you have questions about these terms, please contact us through the appropriate channels provided on our website.
TERMS

App = app "ScrollBox Demo", layout: :wide do
  hstack(justify: :between, align: :center) do
    header1 "ScrollBox Component Demo"
    theme_switcher
  end
  md "The `scroll_box` constrains content to a fixed height with vertical scrolling."

  columns widths: ["50%", "50%"] do
    # ---- Left column ----
    column do
      # Use case 1: Static long content
      header2 "Terms & Conditions"
      text "A classic scroll_box use case - long legal text in a constrained area:"

      scroll_box max_height: "200px" do
        md TERMS
      end

      # Use case 2: Data list
      header2 "File Browser"
      text "Long lists constrained to avoid page bloat:"

      scroll_box max_height: "250px" do
        vstack spacing: :xs, divider: true do
          50.times do |i|
            ext = %w[.rb .js .yml .md .json].sample
            size = rand(1..500)
            hstack spacing: :sm, justify: :between, align: :center do
              phrase "app/models/file_#{i + 1}#{ext}"
              badge "#{size} KB", size: :sm
            end
          end
        end
      end
    end

    # ---- Right column ----
    column do
      # Use case 3: Chat messages
      header2 "Team Chat"
      text "Message history in a scrollable container:"

      scroll_box max_height: "200px" do
        vstack spacing: :sm do
          CHAT_MESSAGES.each do |msg|
            div do
              md "**#{msg[:user]}**: #{msg[:text]}"
            end
          end
        end
      end

      # Use case 4: Live log output (SSE-updated)
      header2 "Live Application Log"
      text "Log entries arrive via SSE and accumulate in the scroll_box:"

      scroll_box max_height: "250px" do
        div id: "log-output" do
          text "[#{Time.now.strftime('%H:%M:%S')}] Log stream started..."
        end
      end
    end
  end

  # --- Live log timer ---
  every(2) do |streamer|
    msg = LOG_MESSAGES.sample
    timestamp = Time.now.strftime("%H:%M:%S.%L")
    level_color = if msg.start_with?("ERROR")
      "color: #ef4444"
    elsif msg.start_with?("WARN")
      "color: #eab308"
    elsif msg.start_with?("DEBUG")
      "color: #6b7280"
    else
      "color: #a3a3a3"
    end

    streamer.append("#log-output") do
      div style: "font-family: monospace; font-size: 0.85rem; padding: 2px 0; #{level_color}" do
        text "[#{timestamp}] #{msg}"
      end
    end
  end
end

App.run! if __FILE__ == $0
