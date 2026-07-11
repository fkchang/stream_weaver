#!/usr/bin/env ruby
# frozen_string_literal: true

# Demonstrates the six FAC-P2.2 pareto components together: date_field,
# accordion/section, chip_group, board/lane/board_card, text tones +
# callout banners, and columns equal-split/auto-distribution.
# Run: ruby examples/components/pareto_set.rb

require_relative '../../lib/stream_weaver'

TASKS = {
  todo: ["Write proposal", "Review PR #42"],
  doing: ["Ship pareto components"],
  done: ["Set up CI", "Draft gap catalog"]
}.freeze

ROLES = %w[Engineer Designer PM Writer Analyst].freeze

App = app "Pareto Components" do
  header1 "Pareto Component Set (FAC-P2.2)"

  header "1. date_field"
  date_field :deadline, label: "Deadline", min: "2026-01-01", max: "2027-12-31"
  if (parsed = StreamWeaver::Components::DateField.to_date(state[:deadline]))
    text "Parsed as a Date: #{parsed.iso8601}", tone: :muted
  end

  header "2. accordion / section"
  accordion do
    section("What is this?", open: true) do
      text "Native <details>/<summary> disclosure -- zero JS."
    end
    section("Why not expandable_card?") do
      text "expandable_card needs a state key; this doesn't."
    end
  end

  header "3. chip_group"
  chip_group :tags, %w[Ruby Rails Sinatra Hanami], multi: true
  text "Selected: #{Array(state[:tags]).join(', ')}", tone: :caption

  header "4. board / lane / board_card"
  board do
    TASKS.each do |lane_key, items|
      lane(lane_key.to_s.capitalize) do
        items.each { |item| board_card { text item } }
      end
    end
  end

  header "5. text tones + callout"
  text "Muted helper text.", tone: :muted
  text "Something went wrong.", tone: :error
  text "Operation succeeded.", tone: :success
  callout("Saved successfully.", tone: :success)
  callout(variant: :warning, title: "Heads up") do
    text "The block form still works exactly as before."
  end

  header "6. columns equal-split"
  columns(3, items: ROLES) { |role| card { text role } }
end

App.run! if __FILE__ == $0
