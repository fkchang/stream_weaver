# My Todos — Turbo Frames parity spike

A StreamWeaver mirror of the learnhotwire.com course's Rails "My Todos" app
(`github.com/learnhotwire/rails`), attempting the four Turbo Frames chapter features under one
rule: **zero custom JavaScript in app code**. No script tags, no inline JS, no hand-written
Alpine — DSL verbs and CSS only.

This is a discovery spike, not a demo. Two of the four features deliberately do not work; the app
says so on screen where they stop.

```bash
SW_NO_OPEN=1 STREAMWEAVER_PORT=4599 ruby examples/my_todos/my_todos.rb
```

| Route | Feature | Verdict |
|---|---|---|
| `/` | Inline editing | Works — per-row fragment + title-only `form_for` |
| `/search` | Search | Partial — auto-submit is free, but an input can't target a sibling fragment |
| `/hover-cards` | Hover cards | Partial — CSS reveal works, lazy fetch has no primitive |
| `/infinite-scroll` | Infinite scroll | Degraded — click-to-load-more, and each click re-sends everything |

Boot with `SW_HOVERCARD_DELAY=1.5` to feel what eager card rendering costs (the equivalent of the
chapter's `sleep 1.5`).

**Full write-up**: [`docs/research/streamweaver-way-spike-findings.md`](../../docs/research/streamweaver-way-spike-findings.md)
— per feature, the Rails mechanism with its key elements, the StreamWeaver equivalent used or the
exact missing primitive and where it breaks.
