# My Todos — Turbo Frames parity proof

A StreamWeaver mirror of the learnhotwire.com course's Rails "My Todos" app
(`github.com/learnhotwire/rails`), building all four Turbo Frames chapter features under one
rule: **zero custom JavaScript in app code**. No script tags, no inline JS, no hand-written
Alpine — DSL verbs and CSS only.

This started as a discovery spike (two of the four features didn't work yet); it's now the
parity proof — all four work end to end on the primitives the spike's findings motivated
(deferred/lazy fragments, strict-ids keying).

```bash
SW_NO_OPEN=1 STREAMWEAVER_PORT=4599 ruby examples/my_todos/my_todos.rb
```

| Route | Feature | How |
|---|---|---|
| `/` | Inline editing | Per-row `fragment` + title-only `form_for`, keyed by record id |
| `/search` | Search | `text_field` auto-submit, in two arrangements (field outside vs. inside the results fragment) — both filter correctly; see the app for the remaining cost trade-off |
| `/hover-cards` | Hover cards | `fragment(..., lazy: true)` keyed by todo, inside the CSS `:hover` reveal — fetches once, only when hovered |
| `/infinite-scroll` | Infinite scroll | Russian-doll nested `fragment(..., lazy: true)` — each page declares the next as its own lazy fragment; scrolling triggers the fetch |

Boot with `SW_HOVERCARD_DELAY=1.5` to feel the difference: the shell renders in well under a
second, and each card pays its 1.5s only once, only if hovered (the equivalent of the chapter's
`sleep 1.5`).

**Full write-up**: [`docs/research/streamweaver-way-spike-findings.md`](../../docs/research/streamweaver-way-spike-findings.md)
— per feature, the Rails mechanism with its key elements, the StreamWeaver equivalent, and the
resolution history (what was missing, what shipped to close it).
