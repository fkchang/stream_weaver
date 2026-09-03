# University Getting Started — epic context

Sources: docs/university/roadmap.md (design + earmarked epics), docs/university/capability-inventory.md (30 subcommands, representative 5, newcomer gaps), docs/university/dependency-survey.md (deps with file:line refs).

## Architecture rule

Three layers; the University app only knows the first.

| Layer | Stays the same | Varies |
|---|---|---|
| Curriculum | courses, steps, prompts, progress.yml | number of courses |
| Driver | "canvas sends the step prompt to a worker session" | iterm2ctl send-text now; herdr/cmux later; LLM teacher (`/worker-session`) in a later epic |
| Surface | "a canvas the user drives, beside the work" | iTerm controller window of its own + agent-only worker tab (`ITerm.open_browser_window` / `open_worker_tab`, lib/stream_weaver/iterm.rb) now; browser tab degraded; herdr/cmux later |

Driver and surface adapters both live in `iterm.rb`. Keep them as two small methods, not a framework.

## Surface layout (decision 2026-08-31, supersedes the split-pane arrangement)

Three surfaces, one job each. The terminal `get-started` was invoked from is left untouched. The **controller** is the University canvas in a window of its own — it is what the user drives, not a sidecar. The **worker tab** opens in the caller's own window (so it inherits a usable size) and holds only the agent, leaving it free to acquire its own demo canvas pane per step, which is exactly what the course prompts have it do from step 1. `get-started` therefore no longer splits the worker tab with the University canvas.

## Premier vs degraded (decision 2026-08-28)

iTerm2 is opt-OUT, not optional. Brett explicitly wants the split-pane experience. get-started nags hard with exact install steps (gem install iterm2_ruby; iTerm2 → Preferences → General → Magic → Enable Python API) and only degrades on `--degraded` or explicit "continue anyway". Degraded users arrange browser + second terminal themselves and paste prompts from copy buttons.

## Existing facts (don't re-derive)

- `ITerm.check_availability` (iterm.rb) requires "iterm2" only on darwin inside an iTerm2 session; LoadError → `system("open", url)`. `ITerm.gem_missing?` already prints the gem tip. (Named, not line-numbered, so an insert above them does not date this note.)
- `streamweaver setup` (cli.rb:2095-2133) adds `Bash(streamweaver *)` to Claude settings and calls `install_skill(['--global'])`. get-started wraps this.
- `install_skill` (cli.rb:2039-2091) symlinks skill dirs into the Claude root and `~/.agents/skills` (spec/cli_install_skill_spec.rb). `gem_skills` hash at cli.rb:2056-2061 omits visual-plan and visual-recap.
- Browser-open duplicated in service_client.rb:35-39, cli.rb:1060-1064, server.rb:1064-1068 — do not add a fourth; earmarked for dedupe.
- Chrome Web Store: https://chromewebstore.google.com/detail/streamweaver-doc-viewer/odjjednfpfiagefgpcfdlelldphmpcgj — extension IDs are stable across updates.
- `/worker-session` chain (skill → ~/work/claude_code_history/bin/worker-session → herdr or iterm2ctl → claude) is personal tooling. Out of scope; do not vendor it.

## Discovery traps for course content

- disc-098 / disc-105: checkbox_group and multi chip_group harvest wrong values through canvas-wait — step 3 must use radio_group/select/text_field.
- disc-094: `streamweaver export` drops Chart.js for chart shorthands — step 4/5 doc must not use bar_chart etc.
- disc-095: canvas-read buttons grey out and do nothing — the step-4 doc reviewed in canvas-read should be content-only.
- disc-093 (findings_ready): backend-less component matrix — consult before choosing step-4/5 components.
- disc-170: `text` inside a `callout` is silently dropped by `org-export` — `Org::Writer` doesn't recognize `Components::Text`, and a *nested* passthrough has no verbatim source, so the body becomes an "unrecognized component" placeholder with no warning. Use `md` inside callouts. Same shape: `columns`/`column` falls to raw passthrough, so step 4's two-column section uses `comparison` (native in both writer and reader). Verified 2026-09-03: the step-4 doc org-exports at 10/10 recognized, 0 passthrough, and round-trips back to an identical component sequence.

## Course session names (content-v2, 2026-09-03)

`dashboard` (step 1), `decision` (step 3), `doc-demo` (step 4) are the demo sessions; `university` is the controller canvas the user drives from and is **never** closed. Every step prompt opens by closing the previous step's demo session or background server, and step 5 closes them all. Asserted in spec/university/course_spec.rb.

## Deferred / out of scope

LLM teacher session, Codex as full worker (pickup check only), cmux/herdr adapters, `template`/`pick`/`confirm` docs, tutorial refresh, skill packaging tiers. See roadmap "Earmarked epics".

## Course content law (Forrest, 2026-09-03)

Never present anything a TUI already does (and does faster). Every step must show a capability delta: live arbitrary UI, diagrams, charts, blocking visual decision forms, growing styled docs, portability. "Claude could just open an HTML page of that" = the step has failed. Applies to all future courses.
