#!/usr/bin/env ruby
# frozen_string_literal: true

# stream_weaver-oeo proof: Forrest's direction was "duplicate the sinatra
# apps' theming niceness (semantic classes + ONE user stylesheet owning
# the look, zero framework fights) instead of the intrusive escape-hatch
# path the pixel slice used." examples/parity/tyrion_warroom_slice.rb
# proved pixel-identical parity is achievable, but only by inventing
# tyrion's own class names from scratch with primitive div/phrase/header
# calls and never touching a real StreamWeaver component (Board, Lane,
# Sidebar, Navbar, ... were all deliberately unused there, see that
# file's own header comment).
#
# This slice is the other half of the bet: same fixture data, same two
# routes (/ and /stories/:id), but built with the PRETTY DSL --
# app_shell/sidebar/navbar/nav_item/board/lane/board_card/clickable/card
# -- styled by exactly ONE stylesheet (tyrion_components.css) that
# targets ONLY the sw- hook classes documented in docs/theming-hooks.md
# (plus its own tc- prefixed classes for the handful of elements with no
# dedicated component -- topbar branding, war-table hero background,
# story-detail page chrome; see design-parity-fights.md findings #2 and
# #6, both still-open gaps this slice routes around the same way the
# pixel slice did).
#
# Because every framework style now lives in @layer stream-weaver
# (stream_weaver-oeo commit 1), tyrion_components.css needs zero
# specificity workarounds anywhere -- no `body` prefix, no !important,
# nothing the pixel slice's CSS had to resort to.
#
# Palette/type values below were re-derived by reading (READ-ONLY, never
# copied) ~/work/tyrion/web/public/shared.css's :root custom properties --
# every rule in tyrion_components.css is hand-written against those
# values, not copy-pasted, and never references SW_PARITY_CSS (this slice
# doesn't load the real stylesheet at all -- that's the whole point).
#
# Fixture data only -- invented story titles, no real Tyrion project data.
#
# Env vars (optional; the slice degrades gracefully without it):
#   SW_PARITY_ASSETS=/path/to/tyrion/web/public/assets
#     Real crest/dragon/lantern art via a local-file endpoint. Unset:
#     unicode glyph fallbacks (🦁/🐉/🏮).
#
# Run: SW_PARITY_ASSETS=... ruby examples/parity/tyrion_warroom_components.rb

require_relative "../../lib/stream_weaver"
require "time"

PARITY_ASSETS_DIR = ENV["SW_PARITY_ASSETS"]
COMPONENTS_CSS_PATH = File.expand_path("tyrion_components.css", __dir__)

def parity_art_url(basename)
  return nil unless PARITY_ASSETS_DIR

  path = File.join(PARITY_ASSETS_DIR, basename)
  return nil unless File.exist?(path)

  "/sw-asset/#{StreamWeaver::ComponentAssets.register_file(File.expand_path(path))}/#{basename}"
end

CREST_URL   = parity_art_url("LionCrest.png")
DRAGON_URL  = parity_art_url("dragon.png")
LANTERN_URL = parity_art_url("lantern.png")

# ---------------------------------------------------------------------------
# Store: identical fixture data to tyrion_warroom_slice.rb (same shape,
# same mirrored lane counts curled from the real war room -- see that
# file's StoryStore comment for the full provenance note).
# ---------------------------------------------------------------------------
module StoryStore
  DEFS = [
    { slug: "forge-the-beacon-relay", epic_slug: "field-ops", status: :done,
      context: "Beacon-relay handshake wired between both outposts.",
      intent: "Two outposts need a shared signal before the muster begins.",
      next_action: nil,
      criteria: [["Relay reaches both towers", :met], ["Signal survives storm interference", :met], ["Watch rotation briefed", :met]],
      notes: [[:progress, "First handshake test succeeded at half range."], [:progress, "Full 4-league range held through the night watch."]],
      stale: false },
    { slug: "mend-the-gate-hinge", epic_slug: "field-ops", status: :done,
      context: "Gate hinge replaced and load-tested.",
      intent: "Keep the east gate from seizing before winter.",
      next_action: nil,
      criteria: [["Hinge replaced", :met], ["Load test passed", :met]],
      notes: [[:progress, "New hinge forged and fitted."], [:progress, "Load-tested to double the rated weight."]],
      stale: false },
    { slug: "seal-the-old-cistern", epic_slug: "river-trade", status: :done,
      context: "Cistern sealed; pressure test passed.",
      intent: "Stop the slow leak before the dry season.",
      next_action: nil,
      criteria: [["Cistern sealed", :met], ["Pressure test passed", :met]],
      notes: [[:progress, "Seal held at full pressure for a full day."]], stale: false },
    { slug: "clear-the-ashwood-pass", epic_slug: "field-ops", status: :done,
      context: "Riders confirmed the pass safe for the muster.",
      intent: "Confirm the ashwood pass is clear before the muster marches through.",
      next_action: nil,
      criteria: [["Riders dispatched", :met], ["Pass condition confirmed", :met]],
      notes: [[:progress, "Riders returned at dusk -- pass reported clear."]], stale: false },
    { slug: "repair-the-north-bridge", epic_slug: "field-ops", status: :done,
      context: "Crossbeams placed; load-bearing test passed.",
      intent: "The north bridge must hold before the autumn floods.",
      next_action: nil,
      criteria: [["Timber delivered", :met], ["Crossbeams placed", :met], ["Load-bearing test", :met]],
      notes: [[:progress, "Timber arrived a day ahead of schedule."], [:progress, "Load test held at double the rated weight."]],
      stale: false },
    { slug: "translate-the-sunken-tablet", epic_slug: "river-trade", status: :done,
      context: "Scriptorium translator resolved the old script.",
      intent: "The tablet may name the vault's true owner.",
      next_action: nil,
      criteria: [["Tablet recovered", :met], ["Translator found", :met]],
      notes: [[:progress, "Scriptorium translator confirmed the vault's owner."]], stale: false },
    { slug: "negotiate-toll-rights", epic_slug: "river-trade", status: :done,
      context: "Guild council approved the toll rights.",
      intent: "Toll rights unlock the southern supply route.",
      next_action: nil,
      criteria: [["Guild proposal submitted", :met], ["Council vote scheduled", :met]],
      notes: [[:progress, "Council vote passed on the second reading."]], stale: false },
    { slug: "draft-the-harvest-ledger", epic_slug: "field-ops", status: :done,
      context: "Ledger reconciled against the quartermaster's count.",
      intent: "The harvest ledger must balance before winter stores are sealed.",
      next_action: nil,
      criteria: [["Ledger drafted", :met], ["Counts reconciled", :met]],
      notes: [[:progress, "Ledger balanced on the first reconciliation pass."]], stale: false },
    { slug: "chart-the-southern-vault", epic_slug: "field-ops", status: :pending,
      context: "Survey pass before the vault dig begins.",
      intent: nil, next_action: nil, criteria: [], notes: [], stale: false },
    { slug: "restock-the-armory", epic_slug: "field-ops", status: :pending,
      context: "Quartermaster count due before the next campaign.",
      intent: nil, next_action: nil, criteria: [], notes: [], stale: false },
    { slug: "draft-the-spring-muster", epic_slug: "field-ops", status: :pending,
      context: "First pass on troop assignments.",
      intent: nil, next_action: nil, criteria: [], notes: [], stale: false },
    { slug: "ready-the-siege-engines", epic_slug: "field-ops", status: :pending,
      context: "Inventory pass before the engines are wheeled out.",
      intent: nil, next_action: nil, criteria: [], notes: [], stale: false },
    { slug: "survey-the-flooded-cellar", epic_slug: "river-trade", status: :pending,
      context: "Waiting on a dry spell before the survey crew goes down.",
      intent: nil, next_action: nil, criteria: [], notes: [], stale: false },
    { slug: "catalog-the-relic-hoard", epic_slug: "river-trade", status: :pending,
      context: "First pass on the recovered hoard, pending an appraiser.",
      intent: nil, next_action: nil, criteria: [], notes: [], stale: false }
  ].freeze

  EMPTY_LANE = ENV["SW_PARITY_EMPTY_LANE"]&.to_sym

  @stories = DEFS.each_with_index.map do |d, i|
    d.merge(
      id: i + 1,
      last_note_at: d[:status] == :in_progress ? (d[:stale] ? Time.now - (9 * 3600) : Time.now - (i + 1) * 240) : nil,
      completed_at: d[:status] == :done ? Time.now - ((i + 1) * 3600 * 9) : nil
    )
  end

  class << self
    def all = @stories
    def find(id) = @stories.find { |s| s[:id] == id.to_i }
    def by_status(status) = status == EMPTY_LANE ? [] : @stories.select { |s| s[:status] == status }
  end
end

def relative_time(t)
  return "" unless t
  mins = ((Time.now - t) / 60).round
  return "#{mins}m ago" if mins < 60
  hours = mins / 60
  return "#{hours}h ago" if hours < 24
  "#{hours / 24}d ago"
end

STATUS_LABEL = { pending: "pending", in_progress: "in progress", done: "done", blocked: "blocked" }.freeze
# Lane tone: -> board's own semantic tokens (--sw-success/warning/error/info),
# not tyrion's literal hex values -- the right abstraction level for a
# reusable option (design-parity-fights.md's own "not attempted" note #2).
LANE_TONE = { pending: :neutral, in_progress: :warning, blocked: :error, done: :success }.freeze

App = StreamWeaver::App.new(
  "Tyrion War Room (components slice)",
  chrome: false,
  theme: :dashboard,
  theme_overrides: { color_bg: "#0D0A07", color_text: "#F5E6C8" },
  fonts: ["Cinzel:wght@400;600;700", "IBM+Plex+Mono:wght@300;400", "Lora:ital,wght@0,400;1,400;1,600"],
  # Local-path auto-detection (App#resolve_stylesheet_href) serves this
  # file via /sw-asset/... -- no hand-rolled endpoint needed, unlike the
  # pixel slice's SW_PARITY_CSS proxy for the (much larger, real) shared.css.
  stylesheets: [COMPONENTS_CSS_PATH],
  assets_dirs: [PARITY_ASSETS_DIR].compact
) do
  def art_glyph(url, glyph, css_class:)
    if url
      div(class: "#{css_class} tc-art-img", style: "background-image:url('#{url}');")
    else
      phrase(glyph, class: "#{css_class} tc-art-glyph")
    end
  end

  current_action = state[StreamWeaver::Resource::StateKeys::ACTION]
  current_story  = current_action.is_a?(Symbol) && current_action.to_s.start_with?("story_") ? StoryStore.find(current_action.to_s.delete_prefix("story_")) : nil

  # =========================================================================
  # Topbar chrome: no dedicated `topbar`/`hero` component exists
  # (design-parity-fights.md finding #6, still open) -- hand-assembled with
  # div/phrase/navbar, same as the pixel slice, using tc- prefixed classes
  # (never a generic name that could collide with an app's own CSS).
  # =========================================================================
  div(class: "tc-topbar") do
    div(class: "tc-topbar-brand") do
      art_glyph(CREST_URL, "🦁", css_class: "tc-crest")
      header1("TYRION", class: "tc-wordmark")
    end
    phrase("·", class: "tc-topbar-sep")
    phrase("field-ops", class: "tc-topbar-crumb")
    phrase("·", class: "tc-topbar-sep")
    phrase(current_story ? current_story[:slug] : "warroom-components", class: "tc-topbar-crumb tc-topbar-crumb--active")
    div(class: "tc-topbar-git") do
      phrase("⎇ parity/warroom-components", class: "tc-pill")
      phrase("✗ 2", class: "tc-pill tc-pill--amber")
    end
  end
  navbar(class: "tc-navbar") do
    nav_item("⚔ War Room", href: "/", active: current_story.nil?)
    nav_item("🗺 Roadmap", href: "#")
    nav_item("📖 Active Story", href: "#")
    nav_item("🌍 Global View", href: "#")
    nav_item("💡 Discoveries", href: "#")
    nav_item("❓ About Tyrion", href: "#")
  end

  # =========================================================================
  # app_shell owns the sidebar + main-content split -- the one real
  # StreamWeaver layout primitive that maps directly onto tyrion's chrome.
  # =========================================================================
  app_shell(sidebar_position: :left, sidebar_width: "240px", gap: "0", class: "tc-shell") do
    sidebar(sticky: true, class: "tc-sidebar") do
      div(class: "tc-sidebar-path") { phrase("field-ops › warroom-components") }
      div(class: "sw-sidebar-section") { phrase("Stories · warroom-components") }

      StoryStore.all.each do |story|
        icon_glyph = story[:status] == :pending ? "○" : "●"
        clickable(href: "/stories/#{story[:id]}", class: "tc-story-row tc-story-row--#{story[:status]}") do
          phrase(icon_glyph, class: "tc-story-icon")
          phrase(story[:slug], class: "tc-story-name")
        end
      end

      div(class: "tc-discoveries") do
        div(class: "sw-sidebar-section") { phrase("Discoveries") }
        clickable(href: "#", class: "tc-disc-row") do
          phrase("spike", class: "tc-disc-pill tc-disc-pill--spike")
          phrase("the flooded cellar timing", class: "tc-disc-label")
        end
        clickable(href: "#", class: "tc-disc-row") do
          phrase("5 marks", class: "tc-disc-pill tc-disc-pill--mark")
          phrase("unformalized", class: "tc-disc-label")
        end
      end
    end

    main do
      # ======================================================================
      # War Room board -- the actual Board/Lane/BoardCard proof.
      # ======================================================================
      page(:warroom, "/") do
        div(class: "tc-board-hero") do
          div(class: "tc-dragon-zone") do
            art_glyph(DRAGON_URL, "🐉", css_class: "tc-dragon-glyph")
            header3("Here Be Dragons")
            text("Uncertain requirements")
            text("External dependency")
            text("Needs human decision")
          end

          board do
            [[:pending, "Queue", "Pending"], [:in_progress, "Active Campaign", "In Progress"],
             [:blocked, "Blocked Frontier", "Blocked"], [:done, "Shipped Keep", "Done"]].each do |status, title, sub|
              stories = StoryStore.by_status(status)
              # Lane has no icon slot (design-parity-fights.md's title_prefix
              # workaround, still the only option) -- prefixing the glyph
              # into title: is the same approach the pixel slice used.
              lane_title = status == :blocked ? "🐉 #{title}" : title
              lane(lane_title, tone: LANE_TONE.fetch(status), subtitle: sub) do
                stories.each { |story| render_wr_card(story) }
              end
            end
          end
        end
      end

      # ======================================================================
      # Story detail -- no dedicated "story detail" component exists
      # (same gap as the pixel slice); built from card/card_header/card_body,
      # which do have sw- hooks, plus tc- classes for the parts that don't
      # map onto any existing primitive (hero status line, resume strip).
      # ======================================================================
      StoryStore.all.each do |story|
        page(:"story_#{story[:id]}", "/stories/#{story[:id]}") do
          div(class: "tc-story-page") do
            clickable(href: "/", class: "tc-back-link") { phrase("← War Room") }

            card(class: "tc-story-hero") do
              card_body do
                div(class: "tc-hero-status") do
                  phrase(STATUS_LABEL.fetch(story[:status]), class: "sw-status-badge sw-status-badge--#{story[:status] == :in_progress ? 'maybe' : (story[:status] == :done ? 'strong' : 'skip')}")
                  if story[:last_note_at]
                    phrase("last note #{relative_time(story[:last_note_at])}", class: "tc-hero-meta")
                  end
                end
                header1(story[:slug], class: "tc-hero-title")

                if story[:intent]
                  div(class: "tc-brief") do
                    phrase("MISSION BRIEF", class: "tc-brief-label")
                    text(story[:intent], class: "tc-brief-text")
                  end
                end
              end
            end

            card do
              card_header("Current Context")
              card_body { text(story[:context]) }
            end

            card do
              card_header("Next Action")
              card_body { text(story[:next_action] || "(not set)") }
            end

            div(class: "tc-story-split") do
              card do
                card_header("Criteria")
                card_body do
                  if story[:criteria].any?
                    story[:criteria].each do |crit_text, status|
                      div(class: "tc-crit-row tc-crit-row--#{status}") do
                        phrase(status == :met ? "✓" : "○", class: "tc-crit-check")
                        phrase(crit_text, class: "tc-crit-text")
                      end
                    end
                  else
                    text("No criteria yet")
                  end
                end
              end

              card do
                card_header("Notes")
                card_body do
                  note_anchor = story[:last_note_at] || story[:completed_at] || Time.now
                  story[:notes].each_with_index do |(kind, body), idx|
                    div(class: "tc-note-entry") do
                      phrase("#{kind} · #{relative_time(note_anchor - (idx * 3600))}", class: "tc-note-meta")
                      text(body, class: "tc-note-body")
                    end
                  end
                end
              end
            end

            if story[:status] == :in_progress || story[:next_action] || story[:last_note_at]
              div(class: "tc-resume-strip") do
                div(class: "tc-rs-panel") do
                  phrase("LAST NOTE", class: "tc-rs-label")
                  text(story[:notes].first ? "#{relative_time(story[:last_note_at])} — \"#{story[:notes].first[1].to_s[0, 60]}\"" : "no notes yet", class: "tc-rs-text")
                end
                div(class: "tc-rs-panel tc-rs-panel--beacon") do
                  art_glyph(LANTERN_URL, "🏮", css_class: "tc-lantern-glyph")
                  div do
                    phrase("RESUME POINT", class: "tc-rs-label")
                    met = story[:criteria].count { |_, s| s == :met }
                    text(story[:criteria].any? ? "#{story[:slug]} · #{met}/#{story[:criteria].size} criteria met" : story[:slug], class: "tc-rs-text")
                  end
                end
                div(class: "tc-rs-panel") do
                  phrase("NEXT ACTION", class: "tc-rs-label")
                  text(story[:next_action] || "(not set)", class: "tc-rs-text")
                end
              end
            end
          end
        end
      end
    end
  end
end

def render_wr_card(story)
  clickable(href: "/stories/#{story[:id]}") do
    board_card(tone: story[:status] == :blocked ? :error : nil, class: story[:stale] ? "tc-card--stale" : nil) do
      phrase("⚠ STALE #{relative_time(story[:last_note_at])}", class: "tc-stale-badge") if story[:stale]
      phrase(story[:epic_slug], class: "tc-card-epic")
      header4(story[:slug])
      text(story[:context].to_s[0, 60], class: "tc-card-ctx") if story[:context] && story[:status] != :done
      if story[:status] == :done
        phrase("✓ done · #{relative_time(story[:completed_at])}", class: "tc-card-done-meta")
      else
        badge(STATUS_LABEL.fetch(story[:status]), variant: :default, size: :sm)
      end
    end
  end
end

App.generate.run! if __FILE__ == $0
