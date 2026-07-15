#!/usr/bin/env ruby
# frozen_string_literal: true

# stream_weaver-8mj pixel-parity rebuild: Forrest's bar is IDENTICAL --
# "if we cannot make it look identical, then we have not succeeded." The
# prior slice (gsd/analysis/08-design-parity-fights.md, superseded by this
# rewrite) invented its own class names (tyrion-card, tyrion-board, ...)
# and fought StreamWeaver's own component CSS to skin them. This version
# instead emits tyrion's OWN class names (wr-board, wr-card, topbar,
# sidebar, story-row, as-parchment, ...) using only primitive
# div/phrase/header/clickable calls -- no Board/Lane/BoardCard/Sidebar/
# Navbar -- so the REAL public/shared.css (consumed at runtime, never
# copied into this repo) governs every element directly, with nothing of
# StreamWeaver's own competing for the same classes.
#
# Reference read (READ-ONLY, never copied): ~/work/tyrion web/app.rb,
# web/views/layout.rb, web/views/war_room.rb, web/views/active_story.rb,
# web/public/shared.css. Every class name/structure below was re-derived
# by reading those files, not copy-pasted.
#
# Fixture data only -- invented story titles, no real Tyrion project data.
#
# Env vars (both optional; the slice degrades gracefully without either):
#   SW_PARITY_CSS=/path/to/tyrion/web/public/shared.css
#     Serves the REAL CSS at runtime via `stylesheets:` local-path
#     auto-detection. Unset: only this slice's own minimal seam CSS loads,
#     and every wr-*/topbar/sidebar/as-* class renders unstyled (bare
#     browser defaults) -- a stark but honest way to see exactly how much
#     of the look comes from the real stylesheet.
#   SW_PARITY_ASSETS=/path/to/tyrion/web/public/assets
#     Real crest/dragon/lantern/map art via a local-file endpoint. Unset:
#     unicode glyph fallbacks (🦁/🐉) and the plain CSS gradient tyrion's
#     own shared.css already falls back to when its background-image url
#     404s (see tyrion_slice.css).
#
# Run: SW_PARITY_CSS=... SW_PARITY_ASSETS=... ruby examples/parity/tyrion_warroom_slice.rb

require_relative "../../lib/stream_weaver"
require "base64"
require "time"

PARITY_ASSETS_DIR = ENV["SW_PARITY_ASSETS"]
PARITY_CSS_PATH   = ENV["SW_PARITY_CSS"]&.then { |p| File.expand_path(p) }
SLICE_CSS_PATH    = File.expand_path("assets/tyrion_slice.css", __dir__)

# ---------------------------------------------------------------------------
# Real art, resolved to /sw-asset/ URLs *before* App.new -- ComponentAssets
# is a module-level registry (no App instance required), which sidesteps a
# real ordering gap: `stylesheets:` is resolved eagerly when App.new runs,
# but App#local_asset needs `self` to be the App instance, which only
# exists *inside* the DSL block that App.new's `stylesheets:` keyword
# argument is evaluated before. There is no way to build a `local_asset`
# URL early enough to hand to `stylesheets:` through the public API alone
# -- calling the registry directly is the only route. See catalog finding
# below for the fuller writeup (this is a second surfacing of the same
# gap, not a new one).
# ---------------------------------------------------------------------------
def parity_art_url(basename)
  return nil unless PARITY_ASSETS_DIR
  path = File.join(PARITY_ASSETS_DIR, basename)
  return nil unless File.exist?(path)

  "/sw-asset/#{StreamWeaver::ComponentAssets.register_file(File.expand_path(path))}/#{basename}"
end

CREST_URL  = parity_art_url("LionCrest.png")
DRAGON_URL = parity_art_url("dragon.png")
LANTERN_URL = parity_art_url("lantern.png")
MAP_URL    = parity_art_url("strategy_map.png")

stylesheet_list = [PARITY_CSS_PATH, SLICE_CSS_PATH].compact
extra_asset_dirs = [PARITY_ASSETS_DIR].compact
extra_asset_dirs << File.dirname(PARITY_CSS_PATH) if PARITY_CSS_PATH

# Real shared.css hardcodes `.topbar`/`.wr-board` background-image as a
# *relative* url("assets/strategy_map.png") -- there's no way to point
# that at our resolved MAP_URL without either rewriting the real CSS
# (never copied/edited, per the ticket's own constraint) or shipping an
# override rule of our own. `stylesheets:` entries that aren't a real
# local file pass through unchanged (see App#resolve_stylesheet_href) --
# including a `data:` URI, which isn't caught by the URL-scheme guard
# there (no `//` after the colon) -- so a small inline override, appended
# last, gets the real photo in without a temp file or an extra
# assets_dirs: entry.
if MAP_URL
  bg_css = <<~CSS
    body .topbar { background-image: linear-gradient(to bottom, rgba(0,0,0,.48), rgba(13,10,7,.88)), url('#{MAP_URL}'); }
    body .wr-board { background: linear-gradient(180deg, rgba(8,10,11,.18), rgba(8,10,11,.28)), url('#{MAP_URL}') center/cover no-repeat; }
  CSS
  stylesheet_list << "data:text/css;base64,#{Base64.strict_encode64(bg_css)}"
end

# ---------------------------------------------------------------------------
# Store: in-memory, DB-shaped -- records live here, never in the state hash.
# ---------------------------------------------------------------------------
module StoryStore
  # Mirrors the real tyrion server's *current* lane shape (stream_weaver-8mj
  # A/B fidelity pass): Queue 6 / Active 0 / Blocked 0 / Done 8, curled from
  # http://127.0.0.1:4579/warroom -- fixture slugs below are invented
  # (slug-style, matching this file's existing medieval theme), never the
  # real project's story names. With Active and Blocked both empty, the
  # "Here Be Dragons" watermark (unconditionally rendered in both this
  # slice and the real war_room.rb -- see the render_wr_col call below) has
  # nothing to be covered by in those two lanes and reads exactly as it
  # does live: centered, undimmed, not fighting card backgrounds for the
  # gaps it shows through.
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

  # Demo-only lane emptying (stream_weaver-8mj empty-state proof): set
  # SW_PARITY_EMPTY_LANE=pending (or done/active/blocked) to force that
  # lane empty regardless of the fixture above. Unset by default -- the
  # mirrored shape above (Active/Blocked already empty) is the normal demo.
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
STATUS_CSS   = { pending: "pending", in_progress: "in-progress", done: "done", blocked: "blocked" }.freeze

App = StreamWeaver::App.new(
  "Tyrion War Room (parity slice)",
  chrome: false,
  theme: :dashboard,
  theme_overrides: { color_bg: "#0D0A07", color_text: "#F5E6C8" },
  fonts: ["Cinzel:wght@400;600;700", "IBM+Plex+Mono:wght@300;400", "Lora:ital,wght@0,400;1,400;1,600"],
  stylesheets: stylesheet_list,
  assets_dirs: extra_asset_dirs
) do
  # =========================================================================
  # Shared chrome: topbar + sidebar, rendered on every page. Real DOM:
  # web/views/layout.rb -- .topbar > .topbar-main + .topbar-nav, .sidebar.
  # =========================================================================

  def art_glyph(url, glyph, style:)
    if url
      div(style: "#{style}background-image:url('#{url}');background-size:contain;background-repeat:no-repeat;background-position:center;display:inline-block;")
    else
      phrase(glyph, style: "#{style}display:inline-block;text-align:center;")
    end
  end

  current_action = state[StreamWeaver::Resource::StateKeys::ACTION]
  current_story  = current_action.is_a?(Symbol) && current_action.to_s.start_with?("story_") ? StoryStore.find(current_action.to_s.delete_prefix("story_")) : nil
  active_tab = if current_story
    current_story[:status] == :in_progress ? :active : :warroom
  else
    :warroom
  end

  div(class: "shell") do
    div(class: "topbar") do
      div(class: "topbar-main") do
        div(class: "topbar-brand") do
          art_glyph(CREST_URL, "🦁", style: "height:44px;width:44px;margin-right:10px;vertical-align:middle;")
          phrase("TYRION", style: "font-family:'Cinzel',serif;font-size:24px;font-weight:700;color:var(--gold-bright);letter-spacing:0.12em;")
        end
        phrase("·", class: "topbar-sep")
        phrase("field-ops", class: "topbar-crumb")
        phrase("·", class: "topbar-sep")
        phrase(current_story ? current_story[:slug] : "warroom-parity", class: "topbar-crumb active")
        div(class: "topbar-git") do
          phrase("⎇ parity/warroom-slice", class: "pill pill-neutral")
          phrase("✗ 2", class: "pill pill-amber")
        end
      end
      div(class: "topbar-nav") do
        [
          [:warroom, "⚔ War Room", "/"],
          [:roadmap, "🗺 Roadmap", "#"],
          [:active, "📖 Active Story", "#"],
          [:global, "🌍 Global View", "#"],
          [:discoveries, "💡 Discoveries", "#"],
          [:about, "❓ About Tyrion", "#"]
        ].each do |id, label, href|
          clickable(href: href, class: active_tab == id ? "demo-tab active" : "demo-tab") { phrase(label) }
        end
      end
    end

    div(class: "sidebar") do
      div(style: "padding:10px 14px 0;font-size:12px;color:var(--text-dim);font-family:var(--font-mono);") { phrase("field-ops › warroom-parity") }
      div(class: "sidebar-section") { phrase("Stories · warroom-parity") }

      StoryStore.all.each do |story|
        row_class = case story[:status]
                    when :done then "story-row done"
                    when :in_progress then "story-row active"
                    else "story-row"
                    end
        icon_glyph = story[:status] == :pending ? "○" : "●"
        icon_color = case story[:status]
                     when :done then "var(--emerald)"
                     when :in_progress then "var(--amber)"
                     else "var(--ink-faint)"
                     end
        clickable(href: "/stories/#{story[:id]}", class: row_class) do
          phrase(icon_glyph, class: story[:status] == :in_progress ? "s-icon s-icon-pulse" : "s-icon", style: "color:#{icon_color}")
          phrase(story[:slug], class: "s-name")
        end
      end

      # Mirrors the reference's current discoveries shape: an active spike,
      # zero promotable ("ready") discoveries -- so no ready row, matching
      # Layout's `if disc[:ready_count] > 0` gate in the real app -- and 5
      # unformalized marks.
      div(class: "disc-strip") do
        div(class: "sidebar-section") { phrase("Discoveries") }
        clickable(href: "#", class: "disc-row") do
          phrase("spike", class: "d-pill spike")
          phrase("the flooded cellar timing", class: "d-label")
        end
        clickable(href: "#", class: "disc-row") do
          phrase("5 marks", class: "d-pill mark")
          phrase("unformalized", class: "d-label")
        end
      end
    end

    # =======================================================================
    # War Room board -- real DOM: web/views/war_room.rb.
    # =======================================================================
    page(:warroom, "/") do
      div(class: "main-content visible") do
        div(class: "wr-board") do
          # Always rendered, centered, behind the columns (z-index:1 vs
          # .wr-columns' z-index:2) -- not an empty-lane conditional. The
          # original slice's report mischaracterized this as an empty-state
          # overlay; the real war_room.rb renders it unconditionally as a
          # background watermark, only visible through the gaps between
          # cards.
          div(class: "wr-dragon-zone") do
            div do
              art_glyph(DRAGON_URL, "🐉", style: "width:70px;height:70px;opacity:.82;filter:drop-shadow(0 6px 12px rgba(0,0,0,.5));margin-bottom:10px;")
              div(class: "wr-dragon-zone-copy") do
                header3("Here Be Dragons")
                # `.wr-dragon-zone-copy p` (real CSS) targets a bare <p> tag,
                # not a class -- text() with no tone: renders exactly that
                # (Components::Text's untoned branch emits `view.p { content
                # }` with zero attrs), so three stacked <p>s (margin:0 in the
                # real CSS) read the same as the original's one <p> + <br>s.
                text("Uncertain requirements")
                text("External dependency")
                text("Needs human decision")
              end
            end
          end

          div(class: "wr-columns") do
            render_wr_col("Queue", "Pending", StoryStore.by_status(:pending), "wr-col")
            render_wr_col("Active Campaign", "In Progress", StoryStore.by_status(:in_progress), "wr-col", header_class: "active-hdr")
            render_wr_col("Blocked Frontier", "Blocked", StoryStore.by_status(:blocked), "wr-col", header_class: "dragons-hdr", show_dragon: true, title_prefix: "🐉 ")
            render_wr_col("Shipped Keep", "Done", StoryStore.by_status(:done), "wr-col", header_class: "done-hdr")
          end

          active_stories = StoryStore.by_status(:in_progress)
          if active_stories.size == 1
            render_single_resume_strip(active_stories.first)
          elsif active_stories.size > 1
            render_multi_lane_strip(active_stories)
          end
        end
      end
    end

    # =======================================================================
    # Story detail pages -- one real deep-linkable URL per fixture story
    # (page() matches on a literal path, not a param placeholder -- with
    # only 10 fixture stories, registering one page per id is the correct
    # DSL-native way to get real /stories/:id URLs; `resource()` exists for
    # this but pulls in its own DefaultViews scaffolding (edit/new/destroy
    # markup this slice doesn't want fighting the real as-* CSS for
    # control it doesn't need). Real DOM: web/views/active_story.rb.
    # =======================================================================
    StoryStore.all.each do |story|
      page(:"story_#{story[:id]}", "/stories/#{story[:id]}") do
        div(class: "main-content visible") do
          div(class: "as-outer") do
            div(class: "as-scroll") do
              div(class: "as-parchment") do
                clickable(href: "/", style: "display:inline-block;font-size:12px;font-family:'IBM Plex Mono',monospace;color:var(--ink-faint);text-decoration:none;margin-bottom:12px;opacity:.7;") { phrase("← War Room") }

                div(class: "as-hero-status") do
                  div(class: "status-badge #{STATUS_CSS.fetch(story[:status])}") do
                    div(class: "dot")
                    phrase(STATUS_LABEL.fetch(story[:status]))
                  end
                  if story[:last_note_at]
                    phrase("last note #{relative_time(story[:last_note_at])}", style: "font-size:13px;color:var(--ink-muted)")
                  end
                end
                div(class: "as-hero-title") { phrase(story[:slug]) }

                if story[:intent]
                  div(style: "background:rgba(180,140,80,.08);border-left:3px solid rgba(180,140,80,.35);border-radius:0 6px 6px 0;padding:10px 14px;margin-bottom:14px;") do
                    div(style: "font-size:10px;font-family:'IBM Plex Mono',monospace;color:var(--ink-faint);letter-spacing:.1em;margin-bottom:6px;") { phrase("MISSION BRIEF") }
                    div(style: "font-family:'Lora',serif;font-size:14px;color:var(--ink-dim);font-style:italic;line-height:1.6;") { phrase(story[:intent]) }
                  end
                end

                div(class: "as-block") do
                  div(class: "as-block-label") { phrase("Current Context") }
                  div(style: "font-size:11px;font-family:'IBM Plex Mono',monospace;color:var(--ink-faint);margin-top:-3px;margin-bottom:5px;") { phrase("set by implementing agent") }
                  div(class: "as-block-text") { phrase(story[:context]) }
                end

                div(class: "as-block") do
                  div(class: "as-block-label") { phrase("Next Action") }
                  div(style: "font-size:11px;font-family:'IBM Plex Mono',monospace;color:var(--ink-faint);margin-top:-3px;margin-bottom:5px;") { phrase("agent sets this before handing off") }
                  div(class: "as-block-text") { phrase(story[:next_action] || "(not set)") }
                end

                div(class: "as-split") do
                  div do
                    div(class: "as-block-label", style: "margin-bottom:8px") { phrase("Criteria") }
                    if story[:criteria].any?
                      story[:criteria].each do |text, status|
                        div(class: status == :met ? "as-crit-row done" : "as-crit-row") do
                          div(class: status == :met ? "crit-check checked" : "crit-check")
                          div(class: "crit-text") { phrase(text) }
                        end
                      end
                    else
                      div(style: "font-size:13px;color:var(--ink-faint);font-style:italic;") { phrase("No criteria yet") }
                    end
                  end

                  div(style: "display:flex;flex-direction:column;") do
                    div(class: "as-block-label", style: "margin-bottom:8px") { phrase("Notes") }
                    note_anchor = story[:last_note_at] || story[:completed_at] || Time.now
                    story[:notes].each_with_index do |(kind, body), idx|
                      div(class: "as-note-entry #{kind}") do
                        div(class: "note-meta") { phrase("#{kind} · #{relative_time(note_anchor - (idx * 3600))}") }
                        div(class: "note-body") { phrase(body) }
                      end
                    end
                    # Static/decorative -- functional note-adding is out of
                    # scope for this pixel-parity pass (see catalog "not
                    # attempted").
                    div(class: "as-quick-note", style: "margin-top:auto;") do
                      div(style: "flex:1;font-family:var(--font-mono);font-size:14px;color:var(--ink-faint);font-style:italic;") { phrase("progress note + Enter…") }
                    end
                  end
                end
              end

              if story[:status] == :in_progress || story[:next_action] || story[:last_note_at]
                div(class: "as-resume-strip") do
                  div(class: "as-rs-panel") do
                    div(class: "as-rs-label") { phrase("LAST NOTE") }
                    div(class: "as-rs-text") { phrase(story[:notes].first ? "#{relative_time(story[:last_note_at])} — \"#{story[:notes].first[1].to_s[0, 60]}\"" : "no notes yet") }
                  end
                  div(class: "as-rs-panel as-rs-beacon") do
                    art_glyph(LANTERN_URL, "🏮", style: "height:44px;width:44px;filter:drop-shadow(0 0 10px rgba(245,158,11,0.75));")
                    div do
                      div(class: "as-rs-label") { phrase("RESUME POINT") }
                      div(class: "as-rs-text") do
                        met = story[:criteria].count { |_, s| s == :met }
                        phrase(story[:criteria].any? ? "#{story[:slug]} · #{met}/#{story[:criteria].size} criteria met" : story[:slug])
                      end
                    end
                  end
                  div(class: "as-rs-panel") do
                    div(class: "as-rs-label") { phrase("NEXT ACTION") }
                    div(class: "as-rs-text") { phrase(story[:next_action] || "(not set)") }
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

def render_wr_col(title, sub, stories, col_class, header_class: nil, show_dragon: false, title_prefix: "")
  div(class: col_class) do
    div(class: ["wr-col-header", header_class].compact.join(" ")) do
      art_glyph(DRAGON_URL, "🐉", style: "height:22px;width:22px;opacity:.85;filter:drop-shadow(0 2px 4px rgba(0,0,0,.4));") if show_dragon
      div do
        div(class: "wr-col-title") { phrase("#{title_prefix}#{title}") }
        div(class: "wr-col-sub") { phrase(sub) }
      end
      phrase(stories.size.to_s, class: stories.size.positive? && show_dragon ? "wr-col-count danger" : "wr-col-count")
    end

    stories.each do |story|
      if story[:status] == :done
        render_wr_done_card(story)
      else
        render_wr_card(story)
      end
    end
  end
end

def render_wr_card(story)
  card_style = story[:status] == :blocked ? "border-left:3px solid #b91c1c;background:linear-gradient(180deg,rgba(220,180,160,.97),rgba(190,150,120,.94));" : ""
  clickable(href: "/stories/#{story[:id]}") do
    div(class: story[:stale] ? "wr-card stale" : "wr-card", style: card_style) do
      div(class: "wr-stale-badge") { phrase("⚠ STALE #{relative_time(story[:last_note_at])}") } if story[:stale]
      phrase(story[:epic_slug], class: "wr-card-id")
      header4(story[:slug], class: "wr-card-title")
      div(class: "wr-card-ctx") { phrase(story[:context].to_s[0, 60]) } if story[:context]
      div(class: "wr-card-tags") { phrase(STATUS_LABEL.fetch(story[:status]), class: "wr-tag") }
    end
  end
end

def render_wr_done_card(story)
  clickable(href: "/stories/#{story[:id]}") do
    div(class: "wr-card done-card") do
      phrase(story[:epic_slug], class: "wr-card-id")
      header4(story[:slug], class: "wr-card-title")
      div(class: "wr-card-tags") { phrase("✓ done · #{relative_time(story[:completed_at])}", style: "font-size:11px;color:#166534;") }
    end
  end
end

def render_single_resume_strip(story)
  div(class: "wr-resume-strip") do
    div(class: "wr-thread-card") do
      div(class: "wr-tc-label") { phrase("⚡ Active") }
      div(class: "wr-tc-text") { phrase(story[:slug]) }
    end
    div(class: "wr-thread-card beacon-card") do
      div(class: "wr-tc-label") do
        art_glyph(LANTERN_URL, "🏮", style: "height:20px;width:20px;filter:drop-shadow(0 0 8px rgba(245,158,11,.8));")
        phrase(" Resume Point")
      end
      div(class: "wr-tc-title") { phrase(story[:slug]) }
      div(class: "wr-tc-meta") { phrase("🕐 #{relative_time(story[:last_note_at])}") }
    end
    div(class: "wr-thread-card") do
      div(class: "wr-tc-label") { phrase("→ Next Action") }
      div(class: "wr-tc-text") { phrase(story[:next_action] || "(not set)") }
    end
  end
end

def render_multi_lane_strip(active_stories)
  div(class: "wr-resume-strip wr-resume-strip--multi") do
    div(class: "wr-thread-card") do
      div(class: "wr-tc-label") { phrase("⚡ #{active_stories.size} active lanes") }
      div(class: "wr-tc-text") { phrase("No single resume point — each lane owns its own story.") }
    end
    active_stories.each do |s|
      div(class: "wr-thread-card") do
        div(class: "wr-tc-label") { phrase("🛤 field-ops") }
        div(class: "wr-tc-title") { phrase(s[:slug]) }
        div(class: "wr-tc-meta") { phrase("🕐 #{relative_time(s[:last_note_at])}") }
      end
    end
  end
end

App.generate.run! if __FILE__ == $0
