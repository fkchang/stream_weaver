# StreamWeaver University — Roadmap of Epics

Draft 2026-08-28. Input for `/tyrion-shape`. Companion: `capability-inventory.md`.

## Why

A coworker saw the docs + canvas demo and wants to try it. Two audiences from day one:

- **Developer** — installs the gem, runs the tutorial in their own Claude Code session.
- **Non-developer** — never installs StreamWeaver; reads org docs on gists via the Chrome extension.

Real-life forcing function: this week's discussions will run on gists + org mode with both kinds of coworker.

## Architecture (what changes vs what stays)

| Layer | Stays the same | Varies over time |
|---|---|---|
| Curriculum | Courses, steps, scripts, expected canvas state, progress ledger | Number of courses |
| Driver | "Teacher session steps the user; worker session demonstrates" | Claude Code first; Codex (needs herdr) later |
| Surface | "Canvas beside the terminal" | iTerm split pane (`streamweaver panel`) first; herdr chromium panel; cmux tab; plain browser fallback |

Rule: the University app only knows the curriculum layer. Driver and surface are two shell-outs kept in one file, swapped later without touching courses.

## Trilaws constraints (hard)

- **Forrest's Law** — one door: `streamweaver get-started`. It installs skills, starts the bridge, opens the surface, lands on the course list. No second command to learn.
- **Matt's Law** — course list is the table of contents. Only Getting Started enabled; future courses listed, disabled, one line each.
- **Gloria's Law** — progress persists (`~/.streamweaver/university/progress.yml`); resume lands on the next unfinished step; every step is re-runnable and ends in a visible canvas payoff.

## Epic 1 — `university-getting-started` (this week)

Stories (draft, rigor in brackets):

1. **readme-extension-webstore** [trivial] — README Browser Extension section links the Chrome Web Store listing (`https://chromewebstore.google.com/detail/streamweaver-doc-viewer/odjjednfpfiagefgpcfdlelldphmpcgj`) as the primary path (extension ID is stable across updates); "load unpacked" becomes the dev path. Add a "Share a doc" recipe with the two-level framing: gist = quick collab on one doc with anyone (send gist link + extension link, no install); the level-up is committing the same `.org` to the team repo, where it renders identically in the repo browser — docs graduate from shared-once to living with the code, no format change.
2. **install-skill-covers-all-skills** [trivial] — `gem_skills` hash in `CLI.install_skill` (cli.rb ~2056) includes `visual-plan` and `visual-recap`; printed summary matches.
3. **get-started-door-command** [loose] — `streamweaver get-started` extends existing `setup` (cli.rb ~2095, already installs skills to the Claude and `.agents` skill roots). Premier experience is opt-OUT: checks iTerm2 + `iterm2_ruby` + Python API and, if any is missing, prints exact install steps and a loud "full experience needs iTerm2" warning; only an explicit `--degraded` / "continue anyway" proceeds without it. Also checks core (Ruby, gem, canvas bridge) and agent skills (Claude and Codex roots, warn if no agent). Premier path: opens canvas split pane, opens a worker tab running `claude` (or `codex`), pushes the course-list canvas. Degraded path (Windows/Linux/no-iTerm): browser tab + instructions to arrange a second terminal beside it.
4. **course-list-canvas** [loose] — course listing with Getting Started enabled, others disabled with one-line blurbs; points to existing `streamweaver tutorial` as "the classic component tour (older, being refreshed)".
5. **progress-ledger** [loose] — per-step done state in `~/.streamweaver/university/progress.yml`, resume-to-next-unfinished, "repeat step" always available.
5b. **driver-worker-runner** [strict] — the course canvas is the driver: each step has a Run button; clicking sends the step's prompt to the worker tab via `iterm2ctl send-text` (driver adapter lives in `iterm.rb` next to the surface adapter). Deterministic, no teacher LLM (IoC phase 3). Degraded mode: canvas shows the prompt with a copy button and "paste into your second terminal". Strict because tab targeting can silently hit the wrong tab.
6. **step-1-canvas-push** [loose] — `panel` + `canvas-push` hello card. Payoff: appears in the pane, no HTML.
7. **step-2-dsl-reexec** [loose] — 6-line `ruby app.rb`; mental model: block re-executes per interaction.
8. **step-3-form-modes** [loose] — same form as stateful vs blocking (`canvas-wait`/`pick`/`confirm`). Payoff: "a TUI can't do this."
9. **step-4-growing-doc** [loose] — worker runs a script that appends sections; save-as-doc; review versions in `canvas-read`.
10. **step-5-org-portability** [loose] — `export`/`org-export` the doc, push to a gist, open with the extension; contrast native GitHub org rendering vs extension rendering.
11. **coworker-install-blurb** [trivial] — one paragraph + 3 commands to send to a developer coworker; one link pair (gist + extension) to send to a non-developer.
12. **clean-room-walkthrough** [strict, gate] — fresh machine/user runs the blurb end-to-end; every step reaches its payoff; evidence in ledger.

Out of scope for Epic 1: LLM teacher session (`/worker-session`), Codex as worker beyond a pickup check, cmux, herdr, `template`/`pick`/`confirm` docs beyond what step 3 needs.

## Earmarked epics (titles only, flesh out when reached)

- **university-teacher-worker** — orchestrator session drives a `/worker-session`; course canvas becomes the teacher's control panel (jump to step N, repeat).
- **tutorial-refresh** — bring `streamweaver tutorial` (Glimmer-derived code/edit/render format, keep it) up to current components and capabilities; register it as a University course.
- **university-codex-driver** — Codex as the worker; depends on a herdr chromium-panel spike (personal payoff too).
- **university-surfaces** — cmux tab and herdr panel adapters.
- **course-docs-deep-dive**, **course-canvas-modes**, **course-skills-and-panels** — one epic each.
- **cli-discoverability** — `template`, `pick`, `confirm` documented or hidden from help.

## Open items

- Meeting transcript → `demo-ask.md`; cross-check the five steps against what actually landed with the coworker.
- Confirm the Web Store listing is current with `extension/` on main before pointing coworkers at it.

## Additions after dependency survey (2026-08-28)

Source: `dependency-survey.md`.

- `iterm2_ruby` already degrades gracefully (`iterm.rb:85` LoadError → `open`), so the surface tier is a report, not a gate. Only real setup step is iTerm2 → Preferences → General → Magic → Enable Python API; get-started must say so.
- Codex skill install already exists via `~/.agents/skills` (spec-tested). Follow-up story: also mirror `~/.codex/skills/` (legacy path) or verify Codex picks up `.agents/skills` on Brett's version — **verify-codex-skill-pickup** [strict].
- `/worker-session` chain (skill → `~/work/claude_code_history/bin/worker-session` → herdr or `iterm2ctl` → `claude`) is personal tooling, not the gem. Stays out of Epic 1; in `university-teacher-worker` it is published as a world-tier skill and get-started installs it like any other skill. Gem owns canvas/docs; skill package owns session orchestration; get-started is the installer that knows both.
- Browser-open logic duplicated 3× (service_client.rb, cli.rb, server.rb) — earmark **dedupe-browser-open** under `cli-discoverability`.
- No private/team/world skill packaging scheme exists yet — earmark epic **skill-packaging-tiers**.
