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

## Submitting a prompt into an agent TUI (four UAT rounds, don't re-derive)

`ITerm.send_to_session` is the only place that turns prompt text into keystrokes. Getting `claude`'s TUI to actually *submit* took four live rounds; each earlier shape looked right and failed in a different way:

| Round | Shape sent | Live result |
|---|---|---|
| 1 | `text + "\n"` in one write | multi-line prompt submitted one broken fragment per line |
| 2 | collapsed one line + CR in the same write | text appears, sits unsubmitted (the CR is read as pasted content) |
| 3 | one line, then a lone `"\r"` as a second write | text appears, still sits unsubmitted |
| 4 | `\e[200~<text>\e[201~` as write 1, lone `"\r"` as write 2 | current |

Round 4 is bracketed paste (DEC 2004): the markers tell the TUI where the pasted block ends, so the Return that follows is a keypress rather than more paste content. Rules that fall out of this and must survive any refactor:

- The bracketing lives in the **adapter** (`ITerm.send_to_session`, `bracketed_paste`), never in a caller — `Runner.run_step!` hands over plain prose and nothing terminal-shaped. Nested paste blocks would put the markers in the composer.
- The CR is bracketed **never**, and always ships as its own write, last.
- Prompts are still collapsed to one line first (`Runner.one_line`) — bracketed paste makes embedded newlines survivable but not meaningful.
- No sleeps anywhere in this path. Timing has never been the failure.

**Runbook — if round 4 also fails live:** the next lever is *investigation, not another build*. Look at `iterm2_ruby`'s raw `Session.async_send_text` path (does the gem's `send_text` reach it directly, and does it pass `suppress_broadcast`?) — a broadcast-suppressed or re-encoded write could be mangling the escapes before iTerm2 ever sees them. Confirm what bytes land in the pane (e.g. `cat -v` in a scratch pane as the target) before changing `send_to_session` again.

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

## Controller: single-mode + warm-up push (Forrest, live UAT round 5, 2026-09-03)

Three controller-level fixes, all in `lib/stream_weaver/university/{canvas,listener,progress}.rb` (not course.rb/scripts):

1. **Warm-up push on Run.** The worker's own first push took ~5 minutes live. `Listener.warm_up!` now pushes a deterministic, no-LLM placeholder card to that step's demo canvas (`Listener::STEP_DEMO_SESSIONS`, creating the session if absent) BEFORE `Runner.run_step!` sends the prompt — first paint in well under a second. Gated on `Listener.send_would_reach_worker?` (a recorded worker + `ITerm.session_alive?`) so it's never pushed on a refused/degraded send. `Listener::DEMO_SESSION_NAMES` (used by Reset) is now derived from `STEP_DEMO_SESSIONS` — it had drifted to the pre-content-v2 names (`hello`, `form-demo`) and never actually closed `dashboard`/`decision`.
2. **Single-mode: the step screen is gone.** "Details" now expands a step's full content (why it matters, prompt + Run/Copy, payoffs, Mark done + next hint) inline on its course-list row — no second screen, no `back-to-list`/`next-N` navigation. `Progress#viewing_step`/`#view_step!`/`#clear_view!` renamed to `#expanded_step`/`#expand_step!`/`#collapse!` (same ledger field, `viewing`, so old deep-link/persistence behavior — the ledger state auto-expands a row on load — is unchanged). See design-spec.md's "Revision note (single-mode, 2026-09-03)".
3. **Doc-theme code-block contrast.** `.sw-code-block` fell back to `var(--sw-surface, #ffffff)` (a visual-skills token the `:doc` theme never sets), so Prism's tomorrow-theme token colors read pastel-on-white instead of on the dark background that theme assumes. Fixed with a `body.sw-theme-doc .sw-code-block` override in `views.rb` forcing the dark reverse-video scheme in both light and dark mode — scoped to `:doc` only.

## Deferred / out of scope

LLM teacher session, Codex as full worker (pickup check only), cmux/herdr adapters, `template`/`pick`/`confirm` docs, tutorial refresh, skill packaging tiers. See roadmap "Earmarked epics".

## Course content law (Forrest, 2026-09-03)

Never present anything a TUI already does (and does faster). Every step must show a capability delta: live arbitrary UI, diagrams, charts, blocking visual decision forms, growing styled docs, portability. "Claude could just open an HTML page of that" = the step has failed. Applies to all future courses.

## Canned artifacts, narrating agent (round 5, 2026-09-03)

The worker never concocts demo DSL live and never reads a source checkout. Every demo ships finished inside the gem under `lib/stream_weaver/university/demos/` (plus `scripts/growing_doc.rb`, registered as `doc`), and prompts reach them only through `streamweaver university-demo <name>`, which prints the absolute path from the installed gem. Round 5 measured ~5 minutes to first paint with the agent composing; the rule is **run first, narrate after**.

Facts that fall out and must survive any refactor:

- The DSL is rendered **inside the bridge process**, so a pushed DSL file cannot read the caller's ENV. That is why `dashboard.rb` is a parameterized push script rather than three DSL files, and why `decision_form.rb` pushes itself rather than being piped through `canvas-push`.
- `decision_form.rb` is ONE artifact with two surfaces: `run_once!` (finds a port, opens the browser, blocks, prints JSON) and `canvas <session>` (pushes the same context and inputs). Agentic mode renders its own submit button, so only the canvas surface carries an explicit one.
- `growing_doc.rb` saves itself through the bridge's own `POST /canvas/:name/save-doc` under the deterministic name `university-doc` — the same endpoint the floating button calls, so script and button cannot diverge. Step 5 uses that name; the user's manual save is a bonus lap.
- Six outline sections is the **floor**, not a target: below it the doc theme's sidebar has nothing worth showing, and round 5 ended step 5 pointing at a nav that wasn't there.

## Verify vs present (round 5, 2026-09-03)

Two rules, both on every prompt (`Course::VERIFY_RULE`, `Course::PRESENT_RULE`). Round 5 curl-verified step 2 and then never showed it to the user at all.

- **Verify** is silent and for the agent: curl plus the app's own action log. Browser automation only if the session already has it; never fetched mid-course.
- **Present** is for the user: `open <url>` / `xdg-open <url>`, or let `streamweaver panel` open the pane. Never browser automation (it renders into the agent's session, not the user's), never `SW_NO_OPEN` on a run the user is meant to interact with, and never a command with a discovered port baked into it — a real session shelled a personal `gstack/browse` path and hardcoded port 4700, neither of which survives a coworker's machine.

## Waiting on a human is a background job (2026-09-03)

Mined from `f53afb90`: a foreground `streamweaver canvas-wait` blew past the harness's 120s foreground-block ceiling, was silently demoted to a background task, and cost ~3.5 minutes in notification/poll lag — the single largest agent-side sink in the round-5 pass. Steps 3 and 4 now instruct the worker to background the blocking wait **from the start** and react on the completion notification. Taught as a pattern, not a workaround.

## Org-export-safe component set (2026-09-03)

`Org::Writer` recognizes exactly: `DocHeader`, `DocSectionHeader`, `SidebarToc`, `Markdown`, `Table`, `Comparison`, `Callout`, `CodeBlock`, `Mermaid`, `Card`/`CardHeader`/`CardBody`. Anything else raw-passes-through. Two traps already paid for:

- `table` is only recognized in the `headers:`/`rows:` form. The array-of-hashes and `data:` forms render identically in the pane and then leave as an unrecognized block, silently (`Writer#render_table` returns `raw_passthrough` when `headers` is nil).
- Timeline and KPI-dashboard shapes are NOT in the set — which is why step 4's co-edit menu offers a table, a comparison, a callout and a mermaid instead.

## Pane-width rule (2026-09-03)

Course demo visuals render in a SPLIT pane (~750-800px when the worker window is at the 1600px minimum; critique baseline 620px). Design every step's canvas for that width: KPI tiles wrap to 2x2, charts full-width, no layout that needs >800px to read. Content and window sizing are one decision, not two.

## Round-6 fixes (Forrest, live UAT, 2026-09-03)

Seven fixes, all in `lib/stream_weaver/university/{course,canvas,demos/counter,scripts/growing_doc}.rb` (not progress.rb/listener.rb/runner.rb):

1. **Closing ritual.** `Course.closing_ritual(number)` (plus a `TOTAL_STEPS = 5` constant, needed because the method is called from inside the `GETTING_STARTED_STEPS` array literal that's still being built — the constant doesn't exist yet at that point, same reason `VERIFY_RULE`/`PRESENT_RULE`/`cleanup_line` are also plain methods/constants rather than reaching into the array) appends a fixed two-line sign-off to every prompt, after `PRESENT_RULE`: "✅ Step N demo complete" + "click Mark done — that advances you to step N+1 (then click Run on it)." Step 5's variant points at the recap instead of a nonexistent step 6. Without a fixed sign-off, a worker either kept narrating past a finished demo or went quiet with the user unsure the step was actually done.
2. **Step 1's last push.** The third `dashboard N` push is now explicitly announced as the last one ("That was the final push — the dashboard is done"), with an invitation to actually read the mermaid diagram — it's a picture of the mechanism (agent, CLI, bridge, pane), not decoration.
3. **`demos/counter.rb` is self-describing.** A `callout` is now the file's first statement inside the block — its own line, deliberately outside the six-line mechanism (state/header1/text/button + `app`/`end.run!`), so the "six-line block, eight-line file" claim stays true of the ORIGINAL eight; the file is now nine lines total. The callout's own text names no line count (a stale "eight lines of Ruby" claim sitting next to a nine-line file, contradicting the header two lines below it, repeated the exact "hidden line" trap this step exists to warn about — caught in review, not by the first pass). The prompt (course.rb step 2) now says "nine lines" and calls out the callout as the ninth, not-part-of-the-mechanism line.
4. **`growing_doc.rb` narrates its own pushes.** `announce_stage(index, verb)` prints `stage N/7 <verb>: <label>` (verb is `"pushing"`/`"pushed"`, label comes from the stage's own `toc[:label]` — no second parallel name to keep in sync) to stdout right before and right after each of the six growing-doc pushes. The step 4 prompt points the worker at that stream and forbids summarizing after the whole ~20s run finishes.
5. **Picker bug, root cause and fix.** The radio choices used to be human labels (`"tradeoffs -- A before/after comparison ..."`), and `--extend` expected the bare EXTENSIONS key — a worker had to parse one out of the other, got it wrong, and the unknown-key branch warned to stderr (easy to miss) while `run!` still printed `Saved: <path>` on stdout as if the pick had landed. The doc was unchanged; the live UAT run reported success. Fix: single source of truth — `picker_dsl`'s `radio_group` choices are now `EXTENSIONS.keys + ['done']` verbatim (a legend `md` block above the radio group explains what each bare key means, since the key alone isn't self-explanatory). `apply_extensions!(keys, toc, body)` (extracted so it's testable with no canvas bridge) prints an OK line per recognized key and a FAILED line per unknown one, and returns true only if every key was recognized; `run!` exits non-zero if not. `save_message(path, doc_name, extend_ok)` appends `" -- WITH FAILED EXTENSIONS, see above"` to the save line itself when any key failed, so "Saved: ..." can never again read as unqualified success on stdout alone. The step 4 prompt now tells the worker to curl the `doc-demo` session and grep for the new section's heading before claiming a `--extend` landed.
6. **`.rb` vs `.org`, named as a tradeoff.** Both course.rb's step 4 prompt (the "Save as doc" / "Save as Org" explanation) and `growing_doc.rb`'s own `READBACK` doc section now say what each format is FOR, not just what it's named: `.rb` is full fidelity — StreamWeaver can re-render and extend it again later, exactly as it looked here; `.org` is the portable half — plain text, human-readable anywhere with nothing to install, and the extension (step 5) makes that same file beautiful again without needing StreamWeaver at all.
7. **Run → Re-run.** `Canvas.run_label(progress, last_run, number)` (in `module Canvas` alongside `step_states`/`mark_done_message`, per round-6 code review's suggestion) reads "Re-run" once `progress.requested_at(number)` is set (permanent, stamped only on a `:sent` status) OR the step's own `last_run` is the most recent click (covers a degraded/failed send, which never earns a `requested_at` stamp). Shared by BOTH the hero "Run step N" button and each row's own primary button (`:current`/`:todo` branches — `:done`'s "Repeat" never calls it) — the first round-6 pass shipped these as two separate inline copies and only relabeled the row, leaving the hero (the most visible button on the page) permanently reading "Run step N" even after that step had actually been sent. Forrest caught it as a follow-up; fixed by extracting the one shared method rather than patching the hero's own copy.

Known follow-up from round-6 code review, not done (small, non-blocking): `Progress` could expose a `last_run_on?(step_number)` predicate instead of two call sites (`Canvas.run_label` plus the `uni-step__expect` inline-expansion check) cracking open the raw `last_run` hash directly.
