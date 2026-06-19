---
name: visual-plan
description: Use before starting any non-trivial implementation task — renders a live canvas showing the implementation map, open decisions, and wireframes so the user can sign off before code is written
---

# Visual Plan

Pre-flight planning via StreamWeaver canvas. Push a live plan showing what will change and why, flag open decisions, and block for sign-off on anything that needs user input — all before touching any code.

## When to Use

Before any task where:
- Multiple files will change
- An architecture decision is open (database choice, API shape, component structure)
- A UI surface is being added or significantly reworked
- The user said "show me the plan first"

Skip for trivial edits (one-line fix, rename, config change) — overhead exceeds value.

## !! DO NOT LAUNCH STANDALONE SERVERS PER QUESTION !!

Same rule as the visual companion: **never** run `ruby app.rb` or `streamweaver <file.rb>` for each planning update. Use `canvas-push` to update a single persistent window throughout the session.

## Starting a Plan Session

```bash
# Open a named canvas panel — opens in iTerm2 split pane, or browser tab elsewhere
streamweaver panel plan

# Push the initial plan content
streamweaver canvas-push plan <<'RUBY'
  header1 "Implementation Plan"

  implementation_map(files: [
    { path: "lib/foo/bar.rb",      note: "Add #process method for new pipeline step" },
    { path: "lib/foo/pipeline.rb", note: "Wire bar into pipeline chain" },
    { path: "spec/foo/bar_spec.rb", note: "Cover happy path and nil input edge case" }
  ])

  decision(question: "Should bar be stateless or hold config?") do
    option(id: :stateless, label: "Stateless",
           detail: "Simple — take config as args each call. Easy to test.",
           recommended: true)
    option(id: :stateful,  label: "Stateful",
           detail: "Holds config in instance. Needed if config is expensive to build.")
  end
RUBY
```

Tell the user: "Check the plan canvas at [url]. Let me know in the terminal if you want to adjust anything."

## The Planning Loop

1. Push the full plan canvas (files + decisions + wireframes)
2. Tell the user the canvas URL, end your turn
3. User reviews and responds in the terminal
4. If a decision needs sign-off: use `canvas-wait` (see below) to block until they click
5. Once approved: start implementation; push progress updates to the same canvas

**The canvas stays open while you implement.** Push updates as files change.

## DSL Reference

### `implementation_map` — what files change and why

```ruby
implementation_map(files: [
  { path: "lib/payments/processor.rb", note: "Add retry logic for network errors" },
  { path: "lib/payments/errors.rb",    note: "New RetryableError class" },
  { path: "spec/payments/processor_spec.rb", note: "Cover retry behavior" }
])
```

`note:` should explain the why, not the what ("Add retry logic" not "modify method").

### `decision` — open architecture choices

```ruby
decision(question: "Which caching layer?") do
  option(id: :redis,   label: "Redis",    detail: "Shared, fast, extra infra dep", recommended: true)
  option(id: :memory,  label: "In-memory", detail: "Zero dep, lost on restart")
  option(id: :none,    label: "No cache",  detail: "Simplest — acceptable if <50ms")
end
```

Mark the option you'd choose `recommended: true`.

### `callout(:decision)` — tradeoff flags inline

```ruby
callout(variant: :decision, title: "Auth approach affects test setup") do
  text "If we use JWT here, the test helpers need to generate tokens — adds ~30 lines to spec/support."
  text "If we use session cookies, existing test helpers work as-is."
end
```

Use for tradeoffs that don't need a full option matrix — a constraint, an implicit choice, a flag for the user.

### `callout(:risk)` — things that could go wrong

```ruby
callout(variant: :risk, title: "Migration is irreversible") do
  text "DROP COLUMN is non-reversible in production without a new migration."
  text "Confirm data is not needed before proceeding."
end
```

Use for anything that could bite silently: data loss, breaking changes, non-idempotent operations, external API calls with side effects.

### `wireframe` — UI mockups for new surfaces

```ruby
wireframe(surface: :browser) do
  <<~HTML
    <div class="wf-card">
      <h2>Invoice #1042</h2>
      <p class="wf-muted">Due 2026-07-01</p>
      <button class="primary">Pay now</button>
    </div>
  HTML
end
```

Surfaces: `:browser`, `:desktop`, `:mobile`, `:phone`, `:tablet`, `:popover`, `:card`, `:widget`, `:panel`.

Use for UI stories where the layout matters. Skip if the change is purely logic or data.

### Combining components

```ruby
streamweaver canvas-push plan <<'RUBY'
  header1 "Plan: Add Invoice Detail Page"

  implementation_map(files: [
    { path: "app/controllers/invoices_controller.rb", note: "Add #show action" },
    { path: "app/views/invoices/show.html.erb",       note: "New view" },
    { path: "spec/controllers/invoices_controller_spec.rb", note: "Cover show + 404" }
  ])

  decision(question: "Render total in controller or view?") do
    option(id: :controller, label: "Controller",   detail: "Testable, consistent", recommended: true)
    option(id: :view,       label: "View helper",  detail: "Less boilerplate if reused")
  end

  callout(variant: :risk, title: "Invoice data includes PII") do
    text "Confirm auth check on #show — anonymous access must 403, not 404."
  end

  wireframe(surface: :browser) do
    '<h1>Invoice #1042</h1><p class="wf-muted">$240.00 due</p><button class="primary">Pay</button>'
  end
RUBY
```

## Blocking for Sign-Off with `canvas-wait`

When a decision needs explicit user approval before you proceed, add interactive controls and wait:

```bash
streamweaver canvas-push plan <<'RUBY'
  header2 "Approve to continue"
  radio_group :db_choice, ["PostgreSQL (recommended)", "SQLite", "Needs more discussion"]
  button "Approve and proceed"
RUBY

# Blocks until user clicks the button — prints JSON with their selection
result=$(streamweaver canvas-wait plan)
echo "User chose: $result"
```

`canvas-wait` returns JSON: `{"type":"action","element":"button","value":"Approve and proceed","state":{"db_choice":"PostgreSQL (recommended)"}}`.

Use when the decision changes the implementation path, is hard to reverse, or the user should weigh in before code is written. Skip for low-stakes choices — don't block when the user can redirect in the next turn.

## Updating the Canvas During Implementation

Once approved, keep the canvas live as work progresses:

```bash
# After each file is written
streamweaver canvas-push plan <<'RUBY'
  header1 "Implementation Plan — In Progress"

  implementation_map(files: [
    { path: "lib/foo/bar.rb",       note: "[done]" },
    { path: "lib/foo/pipeline.rb",  note: "[wip]" },
    { path: "spec/foo/bar_spec.rb", note: "[pending]" }
  ])
RUBY
```

The user sees live status without having to ask. The plan evolves from "what will change" to "what has changed."

## Known Gotchas

- `spacer` and `divider` don't exist — use `div(style: "height:Npx")`
- `text` does not render markdown — use `md` for bold/italic/links
- `decision` block scope: only `option(...)` calls are valid inside it — other DSL methods throw
- StreamWeaver auto-selects an available port — capture the URL from stdout, don't hardcode 4567
- Canvas sessions default to `:fluid` (full-width) — good for wide implementation maps; use `--layout=default` for a narrower card
