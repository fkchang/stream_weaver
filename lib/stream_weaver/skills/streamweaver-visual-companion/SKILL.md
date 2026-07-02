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

Every push is auto-saved to ephemeral history (see "Persisting Visual Docs" below). The user can promote any state to a permanent doc with the in-canvas Save-as-doc button — that's their action, not yours.

For explicit option selection (optional): add a `radio_group` + `button`, then use `canvas-wait brainstorm` to block until they click. Returns JSON with selection.

## Persisting Visual Docs

Every canvas session has two tiers of persistence — both work without any action from you.

### Tier 1: Auto-saved history (always-on)

Every `streamweaver canvas-push` call automatically writes the DSL to `~/.streamweaver/history/<session>/<YYYYMMDD_HHMMSS>.rb`. The CLI prints the saved path on stderr:

```
$ streamweaver canvas-push brainstorm <<'RUBY' ... RUBY
  saved: /Users/.../streamweaver/history/brainstorm/20260428_153012.rb
Pushed to brainstorm
```

You don't have to ask the user, configure anything, or run a separate save command. The history is the project's safety net — entries older than 7 days are auto-cleaned. **Never in git, never noisy.** It's the user's "I forgot to save that good diagram from yesterday" insurance.

### Tier 2: Persistent project docs (user-driven)

Each canvas page has a floating **💾 Save as doc** button in the bottom-right. The user clicks it, names the doc (pre-filled with `<session>-YYYYMMDD-HHMM`), and the DSL is written to:

- `<git_root>/docs/streamweaver_canvas/<name>.rb` if invoked inside a git repo
- `~/.streamweaver/canvas/<name>.rb` otherwise

These are the *intentional* keep-forever artifacts that get committed to the repo and shared with teammates.

**Important:** Saving is a user action, not yours. Don't try to "save the canvas" yourself unless the user explicitly asks. If the user says "save this as X" and the button isn't easy to reach, you can fall back to:

```bash
curl -sX POST "http://localhost:<bridge-port>/canvas/<session>/save-doc" \
  -H 'Content-Type: application/json' \
  -d '{"name":"<doc-name>"}'
```

The bridge port is shown in `streamweaver canvas-list` output.

### Browsing saved docs

`streamweaver canvas-read` with no arguments opens the project's `docs/streamweaver_canvas/` directory in a local viewer. The user just runs:

```bash
streamweaver canvas-read
# canvas-read  using default: <git_root>/docs/streamweaver_canvas
# → opens browser with sidebar listing every saved doc
```

If the user asks "show me what we saved," that's the command. No paths needed.

To browse the *history* tier (auto-saved snapshots), pass it explicitly:

```bash
streamweaver canvas-read ~/.streamweaver/history/brainstorm/
```

A combined view (history + docs visible together in one viewer) is on the roadmap (`6m8`, `q4y` in beads).

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

## How `streamweaver panel` Opens the Browser

**You don't need to detect the terminal or call any helper scripts.** `streamweaver panel <session>` figures out the best experience automatically:

- **In iTerm2:** opens as a vertical split pane next to the terminal so the canvas lives alongside the conversation. This is the ideal UX — the user sees diagrams without leaving the terminal context.
- **Anywhere else (Terminal.app, VSCode terminal, kitty, alacritty, tmux, SSH, Linux):** opens in the default system browser (a new tab/window) and prints the URL.

Either way the URL is printed in stdout so the user has a fallback.

**Anti-patterns to avoid:**
- Don't run `python` scripts to drive iTerm — the `iterm2_ruby` gem (on RubyGems) drives iTerm natively and the CLI handles invocation.
- Don't try to `osascript`/AppleScript the iTerm split yourself — `streamweaver panel` already does this through the iTerm2 Ruby API.
- Don't open the browser with a shell `open` / `xdg-open` after `streamweaver panel` — it already opened one (or split into one). Doing so creates duplicates.

If you specifically need the browser opened externally even when iTerm is available (e.g., for screen sharing on a separate display), that's a feature request — file a bd issue rather than working around it in the skill.

## Known Gotchas

- `spacer` and `divider` don't exist — use `div(style: "height:Npx")`
- `theme: :light` unrecognized — omit, defaults to `:default`
- StreamWeaver auto-selects an available port (not always 4567) — capture the URL from stdout
- Canvas sessions default to `:fluid` (full-width) — use `--layout=default` if you want the 900px centered card
