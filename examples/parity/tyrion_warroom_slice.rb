#!/usr/bin/env ruby
# frozen_string_literal: true

# FAC-P5.1 early-gate rebuild: Tyrion's War Room slice (see
# gsd/analysis/07-parity-early-gate.md for the parity assessment).
# Fixture data only -- invented story titles, no real Tyrion project data.
# Styled toward tyrion's gold/parchment palette via theme_overrides (tokens
# only, translating the FEEL of public/shared.css, not vendoring its CSS).
# Run: ruby examples/parity/tyrion_warroom_slice.rb

require_relative "../../lib/stream_weaver"

# ---------------------------------------------------------------------------
# Store: in-memory, DB-shaped -- records live here, never in the state hash
# (mirrors tyrion's Store; see rivet_people_slice.rb header comment for the
# same convention on the rivet side).
# ---------------------------------------------------------------------------
module StoryStore
  SLUGS = [
    ["forge-the-beacon-relay", :active, "Wiring the beacon-relay handshake between outposts."],
    ["chart-the-southern-vault", :queue, "Survey pass before the vault dig begins."],
    ["mend-the-gate-hinge", :done, "Gate hinge replaced and load-tested."],
    ["negotiate-toll-rights", :blocked, "Waiting on the river guild's council decision."],
    ["restock-the-armory", :queue, "Quartermaster count due before the next campaign."],
    ["scout-the-ashwood-pass", :active, "Two riders sent, awaiting the return signal."],
    ["seal-the-old-cistern", :done, "Cistern sealed; pressure test passed."],
    ["translate-the-sunken-tablet", :blocked, "Needs a scholar fluent in the old script."],
    ["draft-the-spring-muster", :queue, "First pass on troop assignments."],
    ["repair-the-north-bridge", :active, "Timber delivered, carpentry crew starting."]
  ].freeze

  @stories = SLUGS.each_with_index.map do |(slug, state, context), i|
    {
      id: i + 1,
      slug: slug,
      state: state,
      context: context,
      notes: state == :active ? ["Kickoff logged.", "First checkpoint hit."] : ["Kickoff logged."]
    }
  end

  class << self
    def all = @stories
    def find(id) = @stories.find { |s| s[:id] == id.to_i }
    def by_state(state) = @stories.select { |s| s[:state] == state }

    def add_note!(id, body)
      find(id)&.[](:notes)&.push(body)
    end
  end
end

LANES = [[:queue, "Queue"], [:active, "Active Campaign"], [:blocked, "Blocked Frontier"], [:done, "Shipped Keep"]].freeze

App = StreamWeaver::App.new(
  "Tyrion War Room (parity slice)",
  chrome: false,
  theme: :dashboard,
  theme_overrides: {
    font_display: "'Cinzel', 'Lora', Georgia, serif",
    font_body: "'Lora', Georgia, serif",
    color_primary: "#D97706",
    color_primary_hover: "#F59E0B",
    color_bg: "#0D0A07",
    color_bg_card: "#1A1208",
    color_bg_elevated: "#241A0E",
    color_text: "#F5E6C8",
    color_text_muted: "#D4B896",
    color_border: "#4A3520",
    color_border_strong: "#6B4E2A",
    color_accent: "#F59E0B",
    card_border_left: "3px solid var(--sw-color-primary)"
  }
) do
  header1 "War Room"
  text "Field Ops Ledger -- parity slice", tone: :muted

  fragment(:flash) { flash_messages }

  # `updates: :flash` only -- the button already lives inside fragment(:detail),
  # so that fragment is the primary (auto-scoped) target; re-listing it in
  # `updates:` would double-render the same fragment id as an OOB extra too.
  action(:add_note, updates: :flash) do |state, key|
    body = state[:note_body].to_s.strip
    if body.empty?
      flash[:error] = "Note can't be blank."
    else
      StoryStore.add_note!(key, body)
      state[:note_body] = ""
      flash[:notice] = "Note added."
    end
  end

  columns(widths: ["65%", "35%"]) do
    column do
      fragment(:board) do
        board do
          LANES.each do |state_key, label|
            stories = StoryStore.by_state(state_key)
            lane("#{label} (#{stories.size})") do
              stories.each do |story|
                board_card do
                  text story[:slug]
                  text story[:context], tone: :muted
                  # primary: (stream_weaver-78a) makes :detail the response's
                  # actual swap target instead of resending the whole board
                  # fragment just to trigger this sibling pane's refresh.
                  button "View", key: story[:id], primary: :detail do |s|
                    s[:selected_story] = story[:id]
                  end
                end
              end
            end
          end
        end
      end
    end

    column do
      fragment(:detail) do
        story = state[:selected_story] && StoryStore.find(state[:selected_story])

        if story.nil?
          card { text "Select a story to see its detail.", tone: :muted }
        else
          card do
            header3 story[:slug]
            text story[:state].to_s.capitalize, tone: :caption
            text story[:context]

            header3 "Notes"
            story[:notes].each { |note| text "- #{note}" }

            text_area :note_body, placeholder: "Add a note...", rows: 3, submit: false
            button "Add Note", action: :add_note, key: story[:id], style: :primary
          end
        end
      end
    end
  end
end

App.generate.run! if __FILE__ == $0
