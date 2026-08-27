# Persisting Visual Docs

Every canvas session has two tiers of persistence — both work without any action from you.

## Tier 1: Auto-saved history (always-on)

Every `streamweaver canvas-push` call automatically writes the DSL to `~/.streamweaver/history/<session>/<YYYYMMDD_HHMMSS>.rb`. The CLI prints the saved path on stderr:

```
$ streamweaver canvas-push brainstorm <<'RUBY' ... RUBY
  saved: /Users/.../streamweaver/history/brainstorm/20260428_153012.rb
Pushed to brainstorm
```

You don't have to ask the user, configure anything, or run a separate save command. The history is the project's safety net — entries older than 7 days are auto-cleaned. **Never in git, never noisy.** It's the user's "I forgot to save that good diagram from yesterday" insurance.

## Tier 2: Persistent project docs (user-driven)

Each canvas page has a floating **💾 Save as doc** button in the bottom-right. The user clicks it, names the doc (pre-filled with `<session>-YYYYMMDD-HHMM`), and the DSL is written to:

- `<git_root>/docs/streamweaver_canvas/<name>.rb` if invoked inside a git repo
- `~/.streamweaver/canvas/<name>.rb` otherwise

These are the *intentional* keep-forever artifacts that get committed to the repo and shared with teammates. `examples/doc-parity-example.rb` in this skill folder shows what this tier can grow into — a fully polished document, not just a saved sketch.

A doc saved this way gets reopened later with no live bridge behind it — the same file also gets browsed via `canvas-read` and can be run through `streamweaver export`. Not every component behaves the same way once the bridge is gone; see the `streamweaver-canvas-safe` skill before building interactivity into anything you expect to Save-as-doc.

When the same material ships to two audiences (a decision memo plus its engineering companion), don't keep two docs that each restate the same tables. Put the shared tables in one `shared/*.rb` fragment and `instance_eval` it from both bodies, so they cannot drift. Push with `cat shared/frag.rb my-doc.rb | streamweaver canvas-push my-doc` — the bridge evaluates pushed text with no filename, so `__dir__` is `nil` there and the doc cannot find the fragment on its own. Pattern, per-mode resolution rules, and org-mode caveats: `docs/shared-dsl-fragments.md` in the stream_weaver repo.

**Important:** Saving is a user action, not yours. Don't try to "save the canvas" yourself unless the user explicitly asks. If the user says "save this as X" and the button isn't easy to reach, you can fall back to:

```bash
curl -sX POST "http://localhost:<bridge-port>/canvas/<session>/save-doc" \
  -H 'Content-Type: application/json' \
  -d '{"name":"<doc-name>"}'
```

The bridge port is shown in `streamweaver canvas-list` output.

## Browsing saved docs

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
