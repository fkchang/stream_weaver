---
name: visual-recap
description: Use after finishing a task (or mid-task for incremental updates) — renders a live canvas showing what changed, why, and the key design choices made during implementation
---

# Visual Recap

Post-implementation canvas recap. Pushes a live visual summary of what actually changed: files touched, the most significant diffs, annotated complex code, and design choices flagged during the work — all in one persistent canvas that evolves with the task.

## When to Use

After any task where:
- Multiple files changed
- A design decision was made
- The user wants to see what happened, not just a text summary
- You're mid-task and want to show progress without finishing

Push at task start (showing intended changes), update mid-task, finalize when done. The canvas evolves — it is not a one-shot publish.

Skip for trivial one-liner edits where a text summary is faster than a canvas.

## Why StreamWeaver vs Static Recap

Builder.io's visual-recap and similar tools generate a static artifact at the end of a task — one snapshot, one publish, frozen. StreamWeaver's recap is **live and incremental**:

- Push at the start with the intended change map
- Update after each batch of files
- Add diff blocks as significant changes land
- Finalize with annotated code and design decisions

The user sees real progress. Mid-task pivots are visible. The canvas reflects the actual task state, not a post-hoc reconstruction.

## !! DO NOT LAUNCH STANDALONE SERVERS PER UPDATE !!

**NEVER** run `ruby app.rb` or `streamweaver <file.rb>` for each recap update. Use `canvas-push` to update a single persistent window throughout the session.

## Step 1 — Get the Changed Files

```bash
# After finishing: diff since the last commit
git diff HEAD~1 --name-only

# Mid-task or across a feature branch:
git diff main..HEAD --name-only

# For uncommitted changes:
git diff --name-only
git status --short
```

Parse the output to build a `{ path:, note: }` list. The `note:` should explain **why** the file changed, not what the file is. Write it now — don't defer to Step 3.

Example mapping:

```
lib/stream_weaver/components/callout.rb  → "Added :decision and :risk tone variants"
spec/components/callout_spec.rb          → "Cover new tone variants, edge cases for missing title"
lib/stream_weaver/display_dsl.rb         → "Expose callout shorthand with default variant: :info"
```

## Step 2 — Start the Canvas

```bash
streamweaver panel recap
```

This opens a persistent canvas named `recap` in an iTerm2 split pane (or browser tab elsewhere). The URL is printed to stdout — tell the user where to look.

## Step 3 — Push the Implementation Map

```bash
streamweaver canvas-push recap <<'RUBY'
  header1 "Recap: <task name>"

  implementation_map(files: [
    { path: "lib/stream_weaver/components/callout.rb",
      note: "Added :decision and :risk tone variants with icon and border color" },
    { path: "spec/components/callout_spec.rb",
      note: "Cover new tone variants and missing-title edge case" },
    { path: "lib/stream_weaver/display_dsl.rb",
      note: "Expose callout shorthand: default variant :info, no block required" }
  ])
RUBY
```

`note:` is the rationale — **why this file changed**, not just what it contains. One sentence.

## Step 4 — Push Diffs for the 2-3 Most Significant Changes

Pick the files where the change is non-obvious from the file name. Push a `diff` block per file:

```bash
streamweaver canvas-push recap <<'RUBY'
  header2 "Key Changes"

  diff(language: "ruby") do
    before do
      <<~CODE
        def callout(variant: :info, title: nil, &block)
          @components << Components::Callout.new(variant: variant, title: title, &block)
        end
      CODE
    end
    after do
      <<~CODE
        def callout(variant: :info, title: nil, **options, &block)
          with_container(Components::Callout.new(variant: variant, title: title, **options), &block)
        end
      CODE
    end
  end
RUBY
```

Limit to 2-3 diffs. If more files changed significantly, pick the ones that tell the story of the task. The `before`/`after` content should be the actual code — copy from the diff, don't paraphrase.

## Step 5 — Annotated Code for the Most Complex Change (Optional)

If one file has a non-obvious implementation worth explaining:

```bash
streamweaver canvas-push recap <<'RUBY'
  header2 "Implementation Detail"

  annotated_code(
    language: "ruby",
    annotations: [
      { line: 3,  label: "Delegates to with_container",
        note: "Allows callout to hold nested DSL components — text, md, badge, etc." },
      { line: 7,  label: "Variant maps to CSS class",
        note: "sw-callout-decision, sw-callout-risk, sw-callout-info — defined in callout.css" },
      { line: 12, label: "Title is optional",
        note: "Renders as a <strong> header when present; omitted entirely if nil" }
    ]
  ) do
    <<~CODE
      def callout(variant: :info, title: nil, **options, &block)
        with_container(
          Components::Callout.new(variant: variant, title: title, **options),
          &block
        )
      end

      class Callout
        VARIANT_CLASSES = { info: "sw-callout-info", decision: "sw-callout-decision",
                            risk: "sw-callout-risk", tip: "sw-callout-tip" }
        # ...
        def render_title
          strong { @title } if @title
        end
      end
    CODE
  end
RUBY
```

Skip this step if the implementation is straightforward.

## Step 6 — Flag Design Choices

Push a `callout(:decision)` for each meaningful design decision made during the task:

```bash
streamweaver canvas-push recap <<'RUBY'
  header2 "Design Choices"

  callout(variant: :decision, title: "with_container instead of direct push") do
    text "Callout now accepts nested DSL calls (text, md, badge). Using with_container lets the"
    text "component collect children from the block the same way card and columns do."
    text "Alternative: parse the block as a string. Rejected — loses type safety and child ordering."
  end

  callout(variant: :decision, title: ":info as the default variant") do
    text "Matches the most common use case (informational callouts). Callers who want :risk or"
    text ":decision must opt in — no accidental risk styling on plain callouts."
  end
RUBY
```

One `callout(:decision)` per meaningful choice. If you made a risky call, use `callout(:risk)` instead.

## Incremental Updates (Mid-Task)

You do not have to wait until a task is done. Update the recap as you go:

```bash
# After the first batch of files:
streamweaver canvas-push recap <<'RUBY'
  header1 "Recap: Add Callout Tones — In Progress"

  implementation_map(files: [
    { path: "lib/stream_weaver/components/callout.rb",  note: "[done] Tone variants added" },
    { path: "spec/components/callout_spec.rb",          note: "[wip]" },
    { path: "lib/stream_weaver/display_dsl.rb",         note: "[pending]" }
  ])
RUBY
```

Use `[done]`, `[wip]`, and `[pending]` prefixes in the `note:` field to show live status.

## Combining Steps in One Push

For small tasks, push everything in a single canvas update:

```bash
streamweaver canvas-push recap <<'RUBY'
  header1 "Recap: Add Callout Tones"

  implementation_map(files: [
    { path: "lib/stream_weaver/components/callout.rb",
      note: "Added :decision and :risk tone variants with icon and border color" },
    { path: "spec/components/callout_spec.rb",
      note: "Cover new tone variants and missing-title edge case" }
  ])

  diff(language: "ruby") do
    before { "def callout(variant: :info, &block)\n  ..." }
    after  { "def callout(variant: :info, **options, &block)\n  with_container(...)\nend" }
  end

  callout(variant: :decision, title: "with_container for nested DSL") do
    text "Allows callout to contain text, md, badge — matches card/columns pattern."
  end
RUBY
```

## DSL Reference

| Method | Purpose |
|---|---|
| `implementation_map(files: [...])` | File-to-rationale map; `note:` is the why |
| `diff(language:) { before { } after { } }` | Side-by-side code diff |
| `annotated_code(language:, annotations: [...]) { }` | Code with line-pinned notes |
| `callout(variant: :decision, title: "...") { }` | Design choice flag |
| `callout(variant: :risk, title: "...") { }` | Risk or caveat flag |

## Known Gotchas

- DSL method is `diff`, not `diff_block` — `diff_block` does not exist
- `annotated_code` line numbers are 1-indexed; they match the code block you supply, not the original file
- `callout` block must use `text` or `md` — nesting `diff` or `implementation_map` inside a callout throws
- `spacer` and `divider` don't exist — use `div(style: "height:Npx")` for spacing
- StreamWeaver auto-selects a port — capture the URL from stdout, don't hardcode 4567
- If `undefined method` errors appear, the bridge is stale: `streamweaver canvas-stop && streamweaver panel recap`
