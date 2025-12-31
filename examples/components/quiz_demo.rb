#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

# Demonstrates the new radio_group and card components for quiz-style UIs
QuizApp = app "Quiz Demo" do
  header2 "Test your knowledge"
  text "Answer the questions below using the radio buttons."

  card do
    header3 "1. What does GIP stand for?"
    radio_group :q1, [
      "Growth, Income, Profit",
      "Growth, Inflation, Policy",
      "Gains, Interest, Prices",
      "GDP, Interest rates, Profits"
    ]
  end

  card do
    header3 "2. Which programming language is this app built with?"
    radio_group :q2, [
      "Python",
      "Ruby",
      "JavaScript",
      "Go"
    ]
  end

  card do
    header3 "3. True or False: StreamWeaver uses Alpine.js"
    radio_group :q3, ["True", "False"]
  end

  # Show answers when all questions are answered
  if state[:q1] && state[:q2] && state[:q3]
    card class: "results-card" do
      header2 "Your Answers"
      text "Q1: #{state[:q1]}"
      text "Q2: #{state[:q2]}"
      text "Q3: #{state[:q3]}"
    end
  end
end

QuizApp.run! if __FILE__ == $0
