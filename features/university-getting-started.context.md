# University Getting Started — epic context

Sources: docs/university/roadmap.md (design + earmarked epics), docs/university/capability-inventory.md (30 subcommands, representative 5, newcomer gaps), docs/university/dependency-survey.md (deps with file:line refs).

## Architecture rule

Three layers; the University app only knows the first.

| Layer | Stays the same | Varies |
|---|---|---|
| Curriculum | courses, steps, prompts, progress.yml | number of courses |
| Driver | "canvas sends the step prompt to a worker session" | iterm2ctl send-text now; herdr/cmux later; LLM teacher (`/worker-session`) in a later epic |
| Surface | "canvas beside the terminal" | iTerm split pane (`streamweaver panel`, lib/stream_weaver/iterm.rb) now; browser tab degraded; herdr/cmux later |

Driver and surface adapters both live in `iterm.rb`. Keep them as two small methods, not a framework.

## Premier vs degraded (decision 2026-08-28)

iTerm2 is opt-OUT, not optional. Brett explicitly wants the split-pane experience. get-started nags hard with exact install steps (gem install iterm2_ruby; iTerm2 → Preferences → General → Magic → Enable Python API) and only degrades on `--degraded` or explicit "continue anyway". Degraded users arrange browser + second terminal themselves and paste prompts from copy buttons.

## Existing facts (don't re-derive)

- `iterm.rb:85` requires "iterm2" only on darwin inside an iTerm2 session; LoadError → `system("open", url)`. `ITerm.gem_missing?` (cli.rb:1921) already prints the gem tip.
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

## Deferred / out of scope

LLM teacher session, Codex as full worker (pickup check only), cmux/herdr adapters, `template`/`pick`/`confirm` docs, tutorial refresh, skill packaging tiers. See roadmap "Earmarked epics".
