---
name: streamweaver-doc-builder
description: Use when building editorial "doc"-style StreamWeaver apps — PRDs, reports, explainers, long-form write-ups — with the :doc theme, doc_header/doc_section_header/sidebar_toc, and the shared-DSL pattern for standalone + canvas delivery
---

# StreamWeaver Doc Builder

Build long-form, editorial-style documents (PRDs, reports, explainers) as StreamWeaver apps using the `:doc` theme and the document component family. Documents can be authored once as a shared DSL body and delivered two ways — standalone Ruby app or live canvas — without duplicating content.

## When to Use

Use when the deliverable is a **document**, not a dashboard or a brainstorming canvas:

- A PRD, spec, or proposal that needs sections, a table of contents, callouts, and tables
- A report or explainer meant to be read top-to-bottom
- Anything you'd otherwise write as a long markdown file, but want scroll-spy navigation, styled callouts, and diagrams rendered live

Skip for: dashboards (use standard components), quick visual A/B comparisons or brainstorming (use `streamweaver-visual-companion`), pre-flight implementation plans (use `visual-plan`).

## !! DO NOT LAUNCH STANDALONE SERVERS PER QUESTION !!

Same rule as the other canvas-based skills: **never** run `ruby app.rb` or `streamweaver <file.rb>` for each content update while iterating on a doc with the user. Use `canvas-push` to update a single persistent session. Only reach for a standalone `ruby` run when you want a permanent, git-tracked app file from the start (see "Two Delivery Modes" below).

## The `:doc` Theme

`:doc` — "Compact Editorial" — is the theme for document-style apps: Charter/system-ui fonts, 15px base size, `#1E4ED8` primary blue, `#F5F4EF` background. Defined in `lib/stream_weaver/theme.rb`.

```ruby
app "My Document Title", theme: :doc do
  # ... doc components here
end
```

**Do not confuse this with the older `:document` theme** (serif Crimson Pro, 19px, "Reading Mode"). `:document` predates `:doc` and some older example files in this repo still reference it — for new doc-style apps, always use `theme: :doc`.

Dark mode works automatically — the `:doc` theme has a dark variant, and `theme_toggle` / auto-mode JS sets `data-sw-theme="dark"` on `<html>` for you. Don't hand-roll dark-mode styling; just use `theme: :doc` (standalone) or `--theme=doc` (canvas panel) and it's wired through, including Mermaid diagram dark-sync.

## Two Delivery Modes, One DSL Body

The core pattern: write your document content **once**, as a bare DSL body file — no `app` wrapper, just a sequence of top-level component calls. Then consume that same file two ways:

1. **Standalone app** — `instance_eval` the body inside an `app "...", theme: :doc do ... end` wrapper
2. **Canvas push** — pipe the body file directly to `streamweaver canvas-push <session>`

Because both modes read the exact same file, content never drifts between "the app I can `ruby run.rb`" and "the live canvas I've been iterating on with the user."

Reference implementation in this repo: `examples/components/prd_dsl.rb` (body only) + `examples/components/prd_demo.rb` (standalone wrapper). Copy the shared-body/`instance_eval` structure — but note `prd_demo.rb` still says `theme: :document`, since it predates the `:doc` theme; use `theme: :doc` in new work.

```ruby
# doc_body.rb — no `app` block, just component calls
sidebar_toc sections: [
  { id: "problem", label: "Problem Statement" },
  { id: "architecture", label: "Architecture" }
]

doc_header(title: "My PRD", pills: [{ text: "Draft" }])

doc_section_header "01", "Problem Statement", id: "problem"
md "Prose goes here."
```

```ruby
# doc_app.rb — standalone wrapper
require_relative "../../lib/stream_weaver"

DOC_BODY_PATH = File.join(__dir__, "doc_body.rb")

DocApp = app "My PRD", theme: :doc do
  instance_eval(File.read(DOC_BODY_PATH), DOC_BODY_PATH)
end

DocApp.run! if __FILE__ == $0
```

```bash
# Same doc_body.rb, pushed to a live canvas instead
streamweaver canvas-push my-doc < doc_body.rb
```

## Component Reference

### `doc_header` — title block

```ruby
doc_header(
  eyebrow: "Acme Corp · Internal Wiki",  # optional small label above the title
  title: "Calendar-Driven Travel State", # required
  pills: [                               # optional meta row
    { text: "Draft" },                   # Hash -> colored pill (variant: :default/:warn/:good)
    "June 25, 2026",                     # String -> plain meta text
    "Author: Jane Doe"
  ]
)
```

### `doc_section_header` — numbered section heading

```ruby
doc_section_header "01", "Problem Statement", id: "problem"
# number, title positional; id: becomes the DOM anchor id
```

### `sidebar_toc` — sticky scroll-spy table of contents

Call once, near the top of the doc:

```ruby
sidebar_toc sections: [
  { id: "problem", label: "Problem Statement" },
  { id: "architecture", label: "Architecture" }
]
```

Desktop (>=1000px): sticky 170px sidebar, active section highlighted via `IntersectionObserver`. Mobile (<1000px): horizontal scrollable sticky bar at top. Each `id:` here must exactly match the `id:` on a `doc_section_header` (see Known Gotchas).

### `callout` — non-dismissible tip/warning box

```ruby
callout(variant: :warning, title: "Root cause:") do
  text "Explanation text here."
end
# variants: :info, :warning, :success, :error, :tip, :decision, :risk
```

### `table` — data table

```ruby
table(
  headers: ["Component", "Responsibility", "Owner"],
  rows: [
    ["Enforcement", "Require calendar entry", "scheduler secretary"],
    ["Sync script", "Read calendars, write state", "launchd"]
  ]
)
```

### `card` / `card_header` / `card_body` — boxed section

```ruby
card do
  card_header "Component Title", badge: "C1", meta: "owner · trigger"
  # badge: optional small tag before title; meta: optional right-aligned text
  card_body do
    md "Body content, supports **markdown**."
    code_block(<<~TXT, lang: "text")
      inline code sample
    TXT
  end
end
```

### `comparison` — side-by-side before/after panels

Useful for "In Scope" / "Out of Scope" grids:

```ruby
comparison(before_label: "In Scope", after_label: "Out of Scope") do
  before { md "- Item 1\n- Item 2" }
  after  { md "- Excluded item" }
end
# Stacks vertically on viewports <768px.
```

### `code_block` — syntax-highlighted code

```ruby
code_block(<<~RUBY, lang: "ruby")
  def hello
    puts "hi"
  end
RUBY
# Options: file: "path/to/file.rb" (shows file header bar),
#          truncate: N (thumbnail line limit), scroll: true/false
```

### `mermaid` — diagrams (dark-mode aware)

```ruby
mermaid <<~MERMAID
  graph LR
    A["Calendar"] --> B["Sync script"] --> C["state.yaml"]
    style A fill:#EEF2FF,stroke:#1E4ED8,color:#1E4ED8
MERMAID
# Options: zoom: true (pan/zoom controls), compact: true (reduced padding
#          for card embedding), layout: :elk
```

### `md` — prose

Use `md` for all body copy that needs bold/italic/links/lists. **`text` does not render markdown** — see Known Gotchas.

## Minimal Copy-Paste Template

A complete, runnable doc in under 30 lines. Adapt the titles/sections/content and go.

```ruby
require_relative "../../lib/stream_weaver"

MyDoc = app "My Report Title", theme: :doc do
  sidebar_toc sections: [
    { id: "overview", label: "Overview" },
    { id: "findings", label: "Findings" }
  ]

  doc_header(
    eyebrow: "Team · Project",
    title: "My Report Title",
    pills: [{ text: "Draft" }, "July 2, 2026"]
  )

  doc_section_header "01", "Overview", id: "overview"
  md "This report covers **what changed** and *why it matters*."

  callout(variant: :info, title: "Key takeaway") do
    text "The short version, up front."
  end

  doc_section_header "02", "Findings", id: "findings"
  table(
    headers: ["Metric", "Before", "After"],
    rows: [["Latency", "220ms", "80ms"]]
  )
end

MyDoc.run! if __FILE__ == $0
```

To push the same content live instead of running it standalone: strip the `require_relative`/`app ... do`/`.run!` wrapper down to just the component calls (the body), and pipe it: `streamweaver canvas-push my-doc < doc_body.rb`.

## Canvas Workflow

```bash
# 1. Open a themed canvas panel (iTerm2 split pane, or browser tab elsewhere)
streamweaver panel my-doc --theme=doc --fresh

# 2. Push the DSL body (same file used standalone — see shared-DSL pattern above)
streamweaver canvas-push my-doc < path/to/doc_body.rb

# 3. Interact — user can click, scroll, use theme_toggle if included; you can push
#    updates to the SAME session as content evolves (re-run canvas-push with the
#    updated body — never spin up a second session)

# 4. Save as doc — a floating 💾 "Save as doc" button sits bottom-right on the canvas.
#    User clicks it, names the doc, and it's written to docs/streamweaver_canvas/<name>.rb
#    — git-tracked, permanent. Don't reinvent this flow for the user; point them at the
#    button. Fallback (only if the button isn't reachable, e.g. non-canvas context) —
#    get <bridge-port> from `streamweaver canvas-list` output:
curl -sX POST "http://localhost:<bridge-port>/canvas/my-doc/save-doc" \
  -H 'Content-Type: application/json' \
  -d '{"name":"<doc-name>"}'
```

`--theme=doc` on `panel` renders the canvas in the `:doc` theme, dark-mode variant included — the canvas body gets class `sw-theme-doc`, and Mermaid dark-attribute sync wires through automatically.

`streamweaver canvas-read` (no args) opens a browsable viewer over `docs/streamweaver_canvas/` — saved Docs and auto-saved History, both promotable/viewable from the same UI.

Every `canvas-push` is auto-saved to history (`~/.streamweaver/history/<session>/`, 7-day cleanup, not git-tracked) regardless of whether the user ever clicks Save as doc — this is tier 1 of a two-tier persistence system. Nothing is silently lost even before an explicit save; tier 2 (Save as doc) is what makes it permanent and shared.

## Known Gotchas

- **`text` does not render markdown** — bold, italic, links, and lists all need `md` instead.
- **`spacer`/`divider` don't exist** — use `div(style: "height:Npx")` for spacing.
- **Don't launch a new server per update** — use `canvas-push` to update a single persistent session, not `ruby app.rb` repeatedly.
- **Don't assume port 4567** — StreamWeaver auto-picks a free port; read the actual URL from stdout.
- **Don't pass `theme: :light`** — it's unrecognized and silently falls back to `:default`. Omit `theme:` entirely, or use `theme_toggle mode: :light` if you want to force light appearance within `:doc`.
- **`sidebar_toc` section `id:` values must exactly match** the `id:` passed to each `doc_section_header`. A mismatch silently breaks scroll-spy highlighting — no error, it just won't highlight.
- **Don't hand-roll dark mode** — the `:doc` theme's dark variant and Mermaid dark-sync already work automatically in both standalone and canvas contexts. Just use `theme: :doc` / `--theme=doc`.
- **Don't confuse `:doc` with `:document`** — `:document` is the older serif "Reading Mode" theme; `:doc` ("Compact Editorial") is the current one to use for new document-style apps.
