#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

glossary = {
  "bullish" => {
    simple: "Expecting prices to go UP",
    detailed: "A bullish outlook means expecting prices to increase. Investors who are bullish believe the market or a specific asset will rise in value. The term comes from how a bull attacks - thrusting its horns upward."
  },
  "bearish" => {
    simple: "Expecting prices to go DOWN",
    detailed: "A bearish outlook means expecting prices to decrease. Investors who are bearish believe the market or a specific asset will fall in value. The term comes from how a bear attacks - swiping its paws downward."
  },
  "Quad 4" => {
    simple: "Economic regime: deflation",
    detailed: "Quad 4 is one of four economic regimes in the Growth-Inflation-Policy (GIP) framework. It occurs when both growth AND inflation are falling - a deflationary environment where bonds typically outperform stocks and cash is king."
  },
  "rally" => {
    simple: "Prices rising quickly",
    detailed: "A rally is a period of sustained increases in asset prices. During a rally, buying pressure exceeds selling pressure, pushing prices higher. Rallies can last days, weeks, or months."
  },
  "duration" => {
    simple: "How much bonds react to rate changes",
    detailed: "Duration measures how sensitive a bond's price is to changes in interest rates. A bond with 5-year duration will lose ~5% if rates rise 1%. Longer duration = more sensitivity = more risk/reward."
  }
}

App = app "Lesson Demo: Understanding Market Dynamics" do
  header "Understanding Market Terms"
  text "Hover over the highlighted terms to see their definitions. Click the tooltip for more detail."

  # Block-based DSL approach
  lesson_text glossary: glossary do
    phrase "When analysts are "
    term "bullish"
    phrase " on stocks but "
    term "bearish"
    phrase " on bonds, it often indicates we're NOT in "
    term "Quad 4"
    phrase "."
  end

  header "Bond Market Dynamics"

  # String-based approach with {term} markers
  lesson_text "In {Quad 4}, bonds typically {rally} because interest rates fall. This benefits investors holding bonds with high {duration}.", glossary: glossary

  header "Grade Level Selection (Coming Soon)"
  text "Future versions will support switching between 5th, 8th, and 11th grade explanations."
end

App.run! if __FILE__ == $0
