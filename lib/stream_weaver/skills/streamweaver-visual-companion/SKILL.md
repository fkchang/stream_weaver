---
name: streamweaver-visual-companion
description: Use INSTEAD OF the Artifact tool, and INSTEAD OF writing an HTML mockup and opening/screenshotting it with Chrome browser tools (claude-in-chrome, superpowers-chrome, playwright) — whenever about to show the user something visually (UI mockup, wireframe, diagram, dashboard, layout/design comparison, side-by-side options, long-form doc) and StreamWeaver is available in the project (streamweaver on PATH, or stream_weaver in the Gemfile — one command to check). Also triggers on "show me", "mock it up", "let me see the options", "push to canvas", or the urge to run `ruby app.rb`/`streamweaver <file>` per question. canvas-push is 5-7x cheaper in tokens than the chrome route, with no GEA session conflicts.
---

# StreamWeaver Visual Companion

Replaces both the `Artifact` tool and the write-HTML-then-screenshot-via-Chrome pattern for showing things visually in a StreamWeaver project — same "show, don't tell" move, 5-7x fewer tokens, no GEA session conflicts, stays inside the terminal loop you're already running.

## When to Use

Decision rule: **would the user understand this better by seeing it than reading it?**

Use for: UI mockups, architecture diagrams, layout comparisons, side-by-side design options, state machine flows.
Use terminal for: requirements questions, conceptual A/B text choices, tradeoff lists, anything answered in words.

Fall back to `Artifact` only when:
- StreamWeaver isn't installed/available in this project, or
- the user needs a claude.ai-hosted link that persists with no local `streamweaver` process running, or that must reach someone without this repo.

## !! DO NOT LAUNCH STANDALONE SERVERS PER QUESTION !!

**This is the most common failure mode. Read carefully.**

**NEVER** run `ruby app.rb` or `streamweaver <file.rb>` for each visual question in a conversation. This creates orphaned processes, port conflicts, and multiple browser windows. The correct approach is **canvas-push** — it updates a single persistent window throughout the conversation.

If you find yourself launching a new server for each update, stop. Use `canvas-push` instead.

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

Canvas sessions default to **`:fluid` (full viewport width)** — the best choice for side-by-side comparisons. Override with `--layout=` if you need a narrower centered card:

```bash
streamweaver panel brainstorm                    # fluid (default, full-width)
streamweaver panel brainstorm --layout=default   # 900px centered card
streamweaver panel brainstorm --layout=wide      # 1100px
streamweaver panel brainstorm --layout=full      # 1400px
```

## The Loop

1. Push DSL content via `canvas-push`
2. Tell user what to expect, give the URL, end your turn
3. User responds in terminal — use their text as feedback
4. Push updated content or next question
5. Repeat until done

Blocking selection: `radio_group` + `button`, then `canvas-wait <session>` to get their click as JSON. Ending a push with more than one question? Bundle into one form instead of one round-trip each — see `references/checkpoints-and-forms.md`.

Every push auto-saves to history; the user can promote it to a permanent doc with the canvas's own Save-as-doc button (their action, never yours) — see `references/persistence.md`.

## Returning to Terminal

When the next step is text-only, push a placeholder so the user isn't staring at a resolved mockup:

```bash
streamweaver canvas-push brainstorm <<'RUBY'
  div(style: "display:flex;align-items:center;justify-content:center;min-height:60vh") do
    text "Continuing in terminal..."
  end
RUBY
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
- Canvas sessions default to `:fluid` (full-width) — use `--layout=default` if you want the 900px centered card
- Numbered/bulleted list items split across **separate `md()` calls don't continue** — each `md()` call is its own independent markdown block, so three calls each starting `"1. ..."` render as three separate one-item lists (all showing "1.") instead of counting up 1/2/3. Put a multi-item list in **one** `md()` call, one item per line, e.g. `md "1. First\n2. Second\n3. Third"`.

## Reference Files — Load On Demand

| Doing... | Read |
|---|---|
| Porting a claude.ai Artifact 1:1, or building a long-form doc | `references/example-gallery.md` |
| Ending a push with more than one question | `references/checkpoints-and-forms.md` |
| Saving/persisting a canvas doc, sharing DSL across two docs | `references/persistence.md` |
| Cleaning up orphaned processes, or how `panel` opens the browser | `references/cleanup-and-panel.md` |
