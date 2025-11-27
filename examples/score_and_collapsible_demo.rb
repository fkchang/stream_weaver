# frozen_string_literal: true

# Demo of ScoreTable and Collapsible components
# Run: ruby examples/score_and_collapsible_demo.rb
# Open: http://localhost:4567

require_relative '../lib/stream_weaver'

app "Review Dashboard" do
  header "Teachable Moment Review"

  card do
    header3 "Item 1: Debugging Race Conditions"

    # Score table with color-coded metrics
    score_table scores: [
      { label: "Novelty", value: 8, max: 10 },
      { label: "Struggle→Solution", value: 7, max: 10 },
      { label: "Reusability", value: 9, max: 10 }
    ]

    text "Themes: debugging, concurrency, testing"

    # Collapsible context section
    collapsible "View Context (127 words)" do
      text "The developer was working on a payment processing system when they encountered intermittent test failures. After investigation, they discovered a race condition in the async checkout flow. The key insight was using condition-based waiting instead of arbitrary sleep timeouts. This pattern proved highly reusable across other async tests in the codebase."
    end

    checkbox :item_1, "Include in export"
  end

  card do
    header3 "Item 2: API Rate Limiting Strategy"

    score_table scores: [
      { label: "Novelty", value: 5, max: 10 },
      { label: "Struggle→Solution", value: 4, max: 10 },
      { label: "Reusability", value: 6, max: 10 }
    ]

    text "Themes: API design, performance"

    collapsible "View Context (89 words)" do
      text "Standard implementation of exponential backoff with jitter for API rate limiting. While not novel, the specific configuration values were tuned based on production metrics."
    end

    checkbox :item_2, "Include in export"
  end

  card do
    header3 "Item 3: Memory Leak Detection"

    score_table scores: [
      { label: "Novelty", value: 3, max: 10 },
      { label: "Struggle→Solution", value: 2, max: 10 },
      { label: "Reusability", value: 3, max: 10 }
    ]

    text "Themes: performance, debugging"

    collapsible "View Context (45 words)", expanded: true do
      text "Basic memory profiling using standard Ruby tools. No novel insights."
    end

    checkbox :item_3, "Include in export"
  end

  # Summary
  div class: "summary" do
    text "---"
    selected = [state[:item_1], state[:item_2], state[:item_3]].count { |v| v }
    text "Selected: #{selected} of 3 items"

    if selected > 0
      button "Export Selected" do |s|
        s[:exported] = true
      end
    end

    text "Exported successfully!" if state[:exported]
  end
end.run!
