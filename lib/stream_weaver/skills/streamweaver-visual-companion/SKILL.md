---
name: streamweaver-visual-companion
description: Use when showing mockups, diagrams, layout comparisons, or visual A/B options during brainstorming — a token-efficient alternative to the chrome-based visual companion that uses StreamWeaver canvas-push mode
---

# StreamWeaver Visual Companion

Drop-in replacement for the chrome visual companion skill. Uses StreamWeaver canvas-push instead of Chrome tabs — 5-7x fewer tokens, no GEA session conflicts.

## When to Use

Same decision rule as the chrome companion: **would the user understand this better by seeing it than reading it?**

Use for: UI mockups, architecture diagrams, layout comparisons, side-by-side design options, state machine flows.

Use terminal for: requirements questions, conceptual A/B text choices, tradeoff lists, anything answered in words.

## !! DO NOT LAUNCH STANDALONE SERVERS PER QUESTION !!

**This is the most common failure mode. Read carefully.**

**NEVER** run `ruby app.rb` or `streamweaver <file.rb>` for each visual question in a conversation. This creates orphaned processes, port conflicts, and multiple browser windows. The correct approach is **canvas-push** — it updates a single persistent window throughout the conversation.

The only exception: launching **one** standalone app file for full-width layout needs (see Layout section). One launch, then update-in-place. Not one per question.

If you find yourself launching a new server for each update, stop. Use `canvas-push` instead.

## Mode: Canvas-Push

Use **canvas-push mode**: push DSL updates to a persistent canvas that stays open throughout the conversation.

## Starting a Session

```bash
# Start a named canvas session (opens browser tab automatically)
streamweaver panel brainstorm

# Push first content
streamweaver canvas-push brainstorm <<'RUBY'
  header1 "Which layout works better?"
  columns widths: ['50%', '50%'] do
    column do
      header3 "Option A — Current"
      md "- 6 tabs"
      md "- Scanner Tasks separate"
    end
    column do
      header3 "Option B — Proposed"
      md "- 5 tabs"
      md "- Scanner Tasks merged into Home"
    end
  end
RUBY
```

Tell the user: "Take a look at [url printed by StreamWeaver] and let me know what you think in the terminal."

## Layout

**Canvas sessions default to the centered 900px card container** — there is no `--layout` flag for `canvas` or `panel` commands.

For most brainstorming comparisons (A/B options, side-by-side mockups), 900px is sufficient. Use `columns widths: ['50%', '50%']` to fill the available width.

**For truly full-width layout** (dashboards, wide tables, broad mockups): launch a standalone app file — the one case where a standalone is correct:

```ruby
# brainstorm_wide.rb — launch once, update via live session or reload
app "Brainstorm", layout: :fluid do
  # :default (900px) | :wide (1100px) | :full (1400px) | :fluid (100%)
  columns widths: ['33%', '33%', '34%'] do
    # ...
  end
end
```

```bash
streamweaver brainstorm_wide.rb
```

## The Loop

1. Push DSL content via `canvas-push`
2. Tell user what to expect, give the URL, end your turn
3. User responds in terminal — use their text as feedback
4. Push updated content or next question
5. Repeat until done

For explicit option selection (optional): add a `radio_group` + `button`, then use `canvas-wait brainstorm` to block until they click. Returns JSON with selection.

## Returning to Terminal

When the next step is text-only, push a placeholder so the user isn't staring at a resolved mockup:

```bash
streamweaver canvas-push brainstorm <<'RUBY'
  div(style: "display:flex;align-items:center;justify-content:center;min-height:60vh") do
    text "Continuing in terminal..."
  end
RUBY
```

## Cleanup: Kill Orphaned Servers

If a previous session launched orphaned processes (canvas or standalone), clean them up:

```bash
# List active canvas sessions
streamweaver canvas-list

# Close a specific canvas session
streamweaver canvas-close brainstorm

# Stop the entire canvas bridge
streamweaver canvas-stop

# List all loaded StreamWeaver apps
streamweaver list

# Remove all apps from the service
streamweaver clear

# Find orphaned StreamWeaver processes by port range
lsof -i :4567-4600 -sTCP:LISTEN

# Kill a specific port (e.g., 4570)
lsof -ti :4570 | xargs kill -9
```

## DSL Quick Reference

```ruby
header1 "Title"               # h1–h6 available
text "Plain text"             # NEVER put markdown in text — use md instead
md "**Bold** and *italic*"    # markdown renderer
div(style: "height:16px")     # spacing (spacer/divider not available)

columns widths: ['50%','50%'] do  # side-by-side comparison
  column { header3 "Left" }
  column { header3 "Right" }
end

card do                        # boxed section
  header3 "Section"
  text "Content"
end

table headers: ["Col","Col2"], rows: [["a","b"],["c","d"]]
radio_group :choice, ["Option A", "Option B", "Option C"]
button "Select"
badge "New", color: :green
status_dot :green, "Active"
```

## Known Gotchas

- `spacer` and `divider` don't exist — use `div(style: "height:Npx")`
- `theme: :light` unrecognized — omit, defaults to `:default`
- StreamWeaver auto-selects an available port (not always 4567) — capture the URL from stdout
- The browser tab opens automatically on `streamweaver panel` — no need to navigate manually
- Canvas sessions default to 900px centered card — not `layout: :fluid`; no `--layout` CLI flag exists
