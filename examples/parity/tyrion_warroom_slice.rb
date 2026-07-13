#!/usr/bin/env ruby
# frozen_string_literal: true

# FAC-8mj design-parity rebuild: chases the REAL tyrion War Room (crest
# topbar + horizontal nav, story sidebar, war-table hero background with
# translucent parchment cards, per-lane color identity, Cinzel display type,
# "Here Be Dragons" empty-state) using every existing DSL affordance first.
# Every place that needed raw CSS/style: passthrough/the endpoint escape
# hatch instead of a one-line DSL call is catalogued in
# gsd/analysis/08-design-parity-fights.md.
#
# Fixture data only -- invented story titles, no real Tyrion project data.
# Reference read (READ-ONLY, never copied): ~/work/tyrion web/app.rb,
# views/layout.rb, views/war_room.rb, public/shared.css.
#
# Optional real art: export SW_PARITY_ASSETS=/path/to/tyrion/web/public/assets
# to see the actual crest/dragon/war-table art via a local-file endpoint.
# Unset (the committed default), everything falls back to a CSS gradient +
# unicode glyph -- no tyrion asset is ever vendored into this repo.
#
# Run: ruby examples/parity/tyrion_warroom_slice.rb

require_relative "../../lib/stream_weaver"
require "time"

# ---------------------------------------------------------------------------
# Optional local art (never committed) -- see class comment above.
# ---------------------------------------------------------------------------
PARITY_ASSETS_DIR = ENV["SW_PARITY_ASSETS"]
SLICE_CSS_PATH = File.expand_path("assets/tyrion_slice.css", __dir__)
ASSET_MIME = {
  ".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg",
  ".svg" => "image/svg+xml", ".webp" => "image/webp"
}.freeze

def parity_asset_url(basename)
  return nil unless PARITY_ASSETS_DIR
  path = File.join(PARITY_ASSETS_DIR, basename)
  File.exist?(path) ? "/parity/asset?name=#{basename}" : nil
end

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
      notes: state == :active ? ["Kickoff logged.", "First checkpoint hit."] : ["Kickoff logged."],
      completed_at: state == :done ? (Time.now - ((i + 1) * 3600 * 5)) : nil
    }
  end

  # Demo-only lane emptying (stream_weaver-8mj empty-state proof): set
  # SW_PARITY_EMPTY_LANE=blocked (or queue/active/done) to see the "Here Be
  # Dragons" empty-state render for that lane. Unset by default -- the normal
  # demo shows all four lanes populated.
  EMPTY_LANE = ENV["SW_PARITY_EMPTY_LANE"]&.to_sym

  class << self
    def all = @stories
    def find(id) = @stories.find { |s| s[:id] == id.to_i }
    def by_state(state) = state == EMPTY_LANE ? [] : @stories.select { |s| s[:state] == state }

    def add_note!(id, body)
      find(id)&.[](:notes)&.push(body)
    end
  end
end

# state -> [label, tone, subtitle] -- tone reuses the framework's semantic
# success/warning/error tokens (gold=:warning, red=:error, green=:success);
# see gsd/analysis/08-design-parity-fights.md for why an exact-hex match
# would still need a style: override.
LANES = [
  [:queue, "Queue", :neutral, "Pending"],
  [:active, "Active Campaign", :warning, "In Progress"],
  [:blocked, "Blocked Frontier", :error, "Blocked"],
  [:done, "Shipped Keep", :success, "Done"]
].freeze

DOT_STATUS = { queue: :gray, active: :yellow, blocked: :red, done: :green }.freeze

def relative_time(t)
  return "" unless t
  mins = ((Time.now - t) / 60).round
  return "#{mins}m ago" if mins < 60
  hours = mins / 60
  return "#{hours}h ago" if hours < 24
  "#{hours / 24}d ago"
end

App = StreamWeaver::App.new(
  "Tyrion War Room (parity slice)",
  chrome: false,
  layout: :fluid,
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
  },
  fonts: ["Cinzel:wght@400;600;700", "IBM+Plex+Mono:wght@300;400", "Lora:ital,wght@0,400;1,400;1,600"],
  stylesheets: ["/parity/tyrion_slice.css"]
) do
  # ---- local-file escape hatch (never serves outside SW_PARITY_ASSETS) ----
  endpoint :get, "/parity/tyrion_slice.css" do |_req|
    [200, { "Content-Type" => "text/css" }, [File.read(SLICE_CSS_PATH)]]
  end

  endpoint :get, "/parity/asset" do |req|
    name = File.basename(req.params["name"].to_s)
    path = PARITY_ASSETS_DIR && File.join(PARITY_ASSETS_DIR, name)
    if path && File.exist?(path)
      [200, { "Content-Type" => ASSET_MIME[File.extname(path).downcase] || "application/octet-stream" }, [File.binread(path)]]
    else
      [404, { "Content-Type" => "text/plain" }, ["not found"]]
    end
  end

  crest_url = parity_asset_url("LionCrest.png")
  dragon_url = parity_asset_url("dragon.png")
  map_url = parity_asset_url("strategy_map.png")

  # `--tyrion-board-bg` must be set on the board's own element (below), not
  # here on the topbar -- a CSS custom property only cascades to *this*
  # element's descendants, and the board lives outside the topbar's subtree
  # (sibling under app_shell), so setting it here left `.tyrion-board` always
  # falling back to its plain gradient default -- the hero image never made
  # it past the topbar strip.
  topbar_bg = map_url ? "--tyrion-topbar-bg: linear-gradient(to bottom, rgba(0,0,0,.48), rgba(13,10,7,.88)), url('#{map_url}');" : ""
  board_bg = map_url ? "--tyrion-board-bg: linear-gradient(180deg, rgba(8,10,11,.2), rgba(8,10,11,.3)), url('#{map_url}');" : ""
  crest_bg = crest_url ? "--tyrion-crest-bg: url('#{crest_url}');" : ""
  dragon_bg = dragon_url ? "--tyrion-dragon-bg: url('#{dragon_url}');" : ""

  fullbleed do
    div(class: "tyrion-topbar", style: topbar_bg) do
      div(class: "tyrion-topbar-main") do
        div(class: "tyrion-crest", style: crest_bg) { phrase(crest_url ? "" : "🦁") }
        div(class: "tyrion-wordmark") { phrase "TYRION" }
        div(class: "tyrion-sep") { phrase "·" }
        div(class: "tyrion-crumb") { phrase "field-ops › warroom-parity" }
      end
      navbar(class: "tyrion-topbar-nav") do
        nav_item("⚔ War Room", href: "#", active: true)
        nav_item("🗺 Roadmap", href: "#")
        nav_item("📖 Active Story", href: "#")
        nav_item("🌍 Global View", href: "#")
        nav_item("💡 Discoveries", href: "#")
      end
    end
  end

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

  app_shell(sidebar_width: "230px", sidebar_position: :left, gap: "0") do
    sidebar(header: nil, sticky: false) do
      div(class: "tyrion-sidebar-label") { phrase "Stories · field-ops" }

      StoryStore.all.each do |story|
        div(class: "tyrion-story-row tyrion-story-row--#{story[:state]}") do
          hstack(spacing: :sm) do
            status_dot(status: DOT_STATUS.fetch(story[:state]), pulse: story[:state] == :active, size: :sm)
            text story[:slug]
          end
        end
      end

      div(class: "tyrion-discoveries") do
        div(class: "tyrion-sidebar-label") { phrase "Discoveries" }
        badge "spike", variant: :info, size: :sm
        badge "2 ready", variant: :success, size: :sm
        badge "3 marks", variant: :default, size: :sm
      end
    end

    main do
      columns(widths: ["76%", "24%"]) do
        column do
          fragment(:board) do
            # Empty-state renders only over the one lane that's actually
            # empty (index into LANES' left-to-right order), and only when
            # such a lane exists -- it used to render unconditionally,
            # bleeding through card gaps in every populated lane. It's kept
            # as a board-level sibling rather than a Lane child: Lane#count
            # is auto-derived from children.size (any component is a valid
            # child per the framework's own doc comment), so nesting it
            # inside the empty lane would count the empty-state itself as a
            # "card" and show e.g. "1" instead of "0" in that lane's header.
            empty_lane_index = LANES.find_index { |state_key, *| StoryStore.by_state(state_key).empty? }

            board(class: "tyrion-board", style: "position: relative; #{board_bg}") do
              if empty_lane_index
                dragon_style = "left: calc(#{empty_lane_index} * (100% / #{LANES.size})); " \
                               "width: calc(100% / #{LANES.size});"
                overlay(z: 1, class: "tyrion-dragon-zone", style: dragon_style) do
                  div(class: "tyrion-dragon-glyph", style: dragon_bg) { phrase(dragon_url ? "" : "🐉") }
                  header3 "Here Be Dragons"
                  text "Uncertain requirements"
                  text "External dependency"
                  text "Needs human decision"
                end
              end

              LANES.each do |state_key, label, tone, subtitle|
                stories = StoryStore.by_state(state_key)
                title = state_key == :blocked ? "🐉 #{label}" : label

                lane(title, tone: tone, subtitle: subtitle) do
                  stories.each do |story|
                    if state_key == :done
                      board_card(tone: :success, class: "tyrion-card tyrion-card--done") do
                        header4 story[:slug]
                        text "✓ done · #{relative_time(story[:completed_at])}", tone: :success
                        button "View", key: story[:id], primary: :detail, style: :none, class: "tyrion-view-link" do |s|
                          s[:selected_story] = story[:id]
                        end
                      end
                    else
                      board_card(tone: (state_key == :blocked ? :error : nil), class: "tyrion-card") do
                        header4 story[:slug]
                        text story[:context], tone: :muted
                        badge story[:state].to_s, variant: :default, size: :sm
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
  end
end

App.generate.run! if __FILE__ == $0
