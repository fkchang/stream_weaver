# StreamWeaver Capability Inventory

Read-only inventory of what StreamWeaver (the Ruby gem at the root of this repo) can do, compiled to design a "getting started" tutorial for a newcomer. Sourced from `README.md`, `docs/for_llms.md`, `exe/streamweaver`, `lib/stream_weaver/cli.rb`, `docs/*.md`, `lib/stream_weaver/skills/*/SKILL.md`, `.claude/skills/`, and `examples/`.

## 1. CLI Subcommands

All subcommands dispatch through `StreamWeaver::CLI.run` in `lib/stream_weaver/cli.rb`. `streamweaver <file.rb>` (bare path) is shorthand for `run`.

| Command | Purpose | Tutorial-worthy? |
|---|---|---|
| `streamweaver <file.rb>` / `run` | Run an app file (standalone, auto-port, auto-browser) | Y — the entry point everyone needs first |
| `ruby app.rb` | Same DSL, but you own the process (no service) | Y — the "vs `streamweaver app.rb`" distinction is a common first confusion |
| `eval` | Evaluate DSL from stdin, print result as JSON | N for a first pass — power-user/scripting path |
| `prompt` | One-shot flag-driven UI (`--radio`, `--select`, etc.), returns JSON | N — niche flag-based alternative to writing DSL |
| `list` | List all apps loaded into the background service | N — housekeeping |
| `remove <app_id>` | Remove one app from the service | N — housekeeping |
| `clear` | Remove all apps from the service | N — housekeeping |
| `admin` | Open the admin dashboard for the running service | N — operational, not a first-day need |
| `tutorial` | Launches the built-in interactive tutorial app (`examples/advanced/tutorial.rb`) | Y — literally the guided onboarding path, mention immediately |
| `showcase` | Browse all bundled examples in a live examples browser | Y — best "see what's possible" discovery step |
| `serve` | Start the background service in the foreground (dev mode) | N — internals |
| `stop` | Stop the background service | N — housekeeping, but worth one line |
| `status` | Show service status (port, pid) | N — troubleshooting reference |
| `llm` | Print `docs/for_llms.md` to stdout (LLM quick reference) | Y — the one-liner every AI-agent user needs on day one |
| `opal-build <app.rb>` | Compile an app to a static Opal (client-side Ruby→JS) bundle in `dist/` | N — advanced/deployment topic |
| `live <name>` | Open a persistent one-way live session (SSE push, no round-trip IPC) | N — superseded by `canvas` for most agent use, but worth a mention as the simpler ancestor |
| `push <name>` | Push content into a `live` session | N — pairs with `live` |
| `live-list` / `live-close <name>` | List / close live sessions | N — housekeeping |
| `template <name>` | Run one of the bundled templates | N — not explored in depth this pass; see Gaps |
| `canvas <name>` | Create/connect to a two-way canvas session (opens browser) | Y — the flagship "Claude Code talks to a UI" capability |
| `canvas-push <name>` | Push DSL content (from stdin) into a canvas session | Y — paired with `canvas`, this is the core loop |
| `canvas-wait <name>` | Block until the user interacts, return form state as JSON | Y — completes the two-way loop |
| `canvas-toast <name> <msg>` | Show a toast overlay without replacing page content | N — nice-to-know, not core |
| `canvas-close <name>` | Close a canvas session | N — one line in passing |
| `canvas-reset <name>` / `--all` | Reset session state, keep the connection/pane open | N — troubleshooting reference |
| `canvas-list` | List active canvas sessions | N — housekeeping |
| `canvas-stop` | Stop the canvas bridge server entirely | N — troubleshooting reference |
| `canvas-read <file\|dir>` | Browse canvas DSL docs (and history) in a read-only local viewer, no app session needed | Y — how you view a doc after the fact / share it |
| `export <file.rb>` | Write a canvas DSL doc out as standalone static HTML | Y — the "hand this to someone with no StreamWeaver installed" capability |
| `org-export <file.rb>` | Convert a saved DSL doc to a human-readable `.org` sibling file | N for first tutorial — but core to the org-mode story, see section 3 |
| `org-render <file.org>` | Convert an `.org` doc back into DSL body text (stdout) | N for first tutorial — round-trip companion to `org-export` |
| `pick` | High-level canvas helper wrapping a common choice pattern | N — not explored deeply this pass |
| `confirm` | High-level canvas helper wrapping a common confirm-dialog pattern | N — not explored deeply this pass |
| `panel [name]` | Split the current iTerm2 pane and open a canvas session in the new pane | Y — the single best "wow" demo for a terminal-based coworker |
| `install-skill [--global]` | Install StreamWeaver's Claude Code / cross-tool skills | Y — a one-time setup step worth doing in the first session |
| `setup` | One-command setup: bash permissions + globally install the panel skill for Claude Code | Y — alternative/superset of `install-skill`, good "step 0" |
| `--help` / `-h` / `help` | Show usage | N |
| `--version` / `-v` | Show gem version | N |

## 2. Canvas Capabilities

The canvas bridge is a persistent background server (separate from the app service) that gives Claude Code a two-way, addressable, named UI surface.

| Capability | Exact command |
|---|---|
| Create/open a session | `streamweaver canvas <name>` |
| Push DSL content into it | `streamweaver canvas-push <name> <<'RUBY' ... RUBY` (stdin) |
| Block for user interaction, get JSON back | `streamweaver canvas-wait <name>` |
| Multi-step flow without a final "close" message | end a pushed page with `canvas_continue message: "..."` DSL call instead of nothing |
| Show a non-destructive toast | `streamweaver canvas-toast <name> "message"` |
| Reset session state (keep the pane/connection) | `streamweaver canvas-reset <name>` (or `--all` for every session) |
| Close a session (and its iTerm pane, if any) | `streamweaver canvas-close <name>` |
| List all sessions | `streamweaver canvas-list` |
| Stop the whole bridge | `streamweaver canvas-stop` |
| Browse a saved/pushed DSL doc read-only (no live app) | `streamweaver canvas-read <file\|dir> [--theme=NAME] [--layout=NAME]` |
| Read history of everything pushed to a session | Tier-1 (off-repo) snapshots at `~/.streamweaver/history/<session>/<timestamp>.rb`, written automatically on every `canvas-push`, pruned after 7 days (`lib/stream_weaver/canvas/history.rb`). `canvas-read` with no args discovers these automatically. |
| Save the current canvas content as a permanent doc | In-browser: click the floating **💾 Save as doc** button rendered by `lib/stream_weaver/canvas/save_doc_widget.rb` (posts to the bridge; `scope: :repo` default writes near the project, `scope: :global` writes to `~/.streamweaver/canvas`) |
| Session naming | Free-form string arg to `canvas`/`canvas-push`/etc.; sanitized to `[A-Za-z0-9._-]` for on-disk paths; `panel` auto-generates `panel-<hex>` if omitted |
| Port / PID discovery | Canvas bridge finds its own free port (same auto-scan behavior as app service); the **app service** (separate from canvas) writes `~/.streamweaver/server.pid` (`port=`, `pid=`) via `lib/stream_weaver/service.rb`; individual apps write portfiles to `~/.streamweaver/apps/<sanitized_name>.port` (`url=`, `pid=`, `name=`) via `lib/stream_weaver/portfile.rb` |
| iTerm split-pane helper | `streamweaver panel [name]` — implemented in `lib/stream_weaver/iterm.rb` via the optional `iterm2_ruby` gem, **not** a standalone `bin/` script (see Gaps §7) |

## 3. Docs Capabilities

| Capability | Exact command |
|---|---|
| Render org-mode or DSL docs live in a viewer | `streamweaver canvas-read <path>` (accepts a file or directory; also auto-discovers Tier-1 history + registered doc roots when called with no args) |
| Force a fallback theme/layout for docs with no `use_theme`/`use_layout` declared | `streamweaver canvas-read <path> --theme=NAME --layout=NAME` |
| Apply the `:doc` theme in code (artifact-parity editorial styling, dark mode via `data-sw-theme="dark"`) | `theme: :doc` option to `app`, or `--theme=doc` flag to `streamweaver panel` |
| Export a live/saved DSL doc to standalone static HTML (no server, no Ruby needed to view) | `streamweaver export <file.rb> [-o out.html] [--inline-images] [--offline]` |
| Convert a saved DSL doc to human-readable `.org` | `streamweaver org-export <file.rb>` (writes `<name>.org` next to the source) |
| Convert an `.org` doc back into DSL body text | `streamweaver org-render <file.org>` (prints to stdout) |
| Render a StreamWeaver doc on GitHub/Gist as it would look running, client-side | Chrome extension at `extension/` (`StreamWeaver Doc Viewer`) — content script matches `github.com/*` and `gist.github.com/*`, adds a "View rendered" button. Build: `bin/vendor_browser_assets` then `bin/build_extension`, then load unpacked in `chrome://extensions`. **Shipped and verified** (status per `docs/plans/org-doc-preview-surfaces.md`: S1–S3 shipped, S4–S6 not started). |
| Save the currently-displayed canvas content permanently as a doc | Floating "Save as doc" button in the browser (see §2) |
| Doc history (append-only local snapshots) | `~/.streamweaver/history/<session>/` for canvas pushes; separate doc store at `~/.streamweaver/canvas` (`scope: :global`) or repo-local (`scope: :repo`, default) for explicit saves — `lib/stream_weaver/canvas/doc_store.rb` |

## 4. Interaction Modes Worth Demonstrating

| Mode | What it does | Example file |
|---|---|---|
| **Standalone / stateful app** | `app { ... }.run!` — persistent server, DSL block re-executes on every interaction, state persists across the session | `examples/basic/hello_world.rb`, `examples/basic/todo_list.rb` |
| **Agentic / blocking form** | `app { ... }.run_once!` — opens a popup UI, blocks the calling Ruby process until Submit, returns collected state as JSON, then exits | `examples/agentic/agentic_form.rb` |
| **Agentic with auto-close** | Same as above, plus the browser window auto-closes ~1s after submit | `examples/agentic/agentic_form_autoclose.rb` |
| **Canvas two-way IPC** | Claude Code pushes DSL, blocks on `canvas-wait`, reacts, pushes again — the terminal-agent-drives-a-UI loop | `docs/canvas-panel-workflow.md` walkthrough; `examples/claude_code/` |
| **Multi-step canvas flow** | `canvas_continue message: "..."` keeps a "processing" spinner between pushes instead of ending the session | documented in `docs/canvas-panel-workflow.md`; no single dedicated example file found (see Gaps) |
| **Traditional form block** | `form :name do ... submit "Save" { ... }; cancel "Cancel" end` — deferred submission, all fields collected together | `docs/form-patterns.md` (canonical pattern reference with all four form patterns side by side) |
| **Reactive auto-submit inputs** | Default behavior: every input triggers a server round-trip + re-render immediately (filters, toggles) | `docs/form-patterns.md`, `examples/basic/todo_list.rb` |
| **Editorial long-form doc (`:doc` theme)** | `doc_header`, `doc_section_header`, `sidebar_toc` — PRDs/reports delivered as standalone app or canvas from one shared DSL body | `examples/tutorials/streamweaver_way_tutorial.rb` (`SW_NO_OPEN=1 ruby examples/tutorials/streamweaver_way_tutorial.rb`); pattern documented in `lib/stream_weaver/skills/streamweaver-doc-builder/SKILL.md` |
| **Live one-way SSE session** | `streamweaver live <name>` + `streamweaver push <name>` — simpler ancestor of canvas, push-only, no wait/reply loop | referenced in CLI help; no dedicated `examples/` file found for `live`/`push` specifically (`examples/canvas/` only has a mermaid demo script) |

Note: the task brief's phrase "growing document" does not appear anywhere in the docs or code searched — likely means the multi-step canvas flow (`canvas_continue`) or the doc-builder pattern above; flagged rather than guessed at further.

## 5. Skills Shipped in This Repo

Two install paths exist, both driven by the CLI:

- **`streamweaver install-skill [--global]`** — installs the panel skill (inline, Claude-Code-only, not spec-compliant `SKILL.md`) plus four gem-sourced skills, symlinked (not copied) so gem updates propagate. Installs to `.claude/skills/` (Claude Code) **and** `.agents/skills/` (the cross-tool alias Codex CLI, Gemini CLI, and GitHub Copilot all discover natively) — `--global` targets `~/.claude/skills/` / `~/.agents/skills/` instead of the project-local paths.
- **`streamweaver setup`** — one-command setup: adds bash permissions for Claude Code and installs the panel skill globally.

| Skill | Source | Installed by `install-skill`? | Triggers on |
|---|---|---|---|
| `streamweaver-panel` | `.claude/skills/streamweaver-panel.md` (repo-committed, loose-file legacy format) | Y | Presenting results/status/rich choices visually via `streamweaver panel` |
| `streamweaver-visual-companion` | `lib/stream_weaver/skills/streamweaver-visual-companion/` | Y | Any "show me / mock it up / push to canvas" moment — replaces Artifact tool and Chrome-screenshot workflows |
| `streamweaver-doc-builder` | `lib/stream_weaver/skills/streamweaver-doc-builder/` | Y | Building editorial long-form docs with the `:doc` theme |
| `streamweaver-way` | `lib/stream_weaver/skills/streamweaver-way/` | Y | Building/changing interactive app features (fragments, defer/lazy, keying, dev-loud/prod-self-heal conventions) |
| `streamweaver-canvas-safe` | `lib/stream_weaver/skills/streamweaver-canvas-safe/` | Y | Before building a canvas doc / running `export` — which components need a live backend vs. render standalone |
| `visual-plan` | `lib/stream_weaver/skills/visual-plan/` | **N — not in the `gem_skills` install list** (see Gaps) | Pre-flight implementation planning via canvas, before code is written |
| `visual-recap` | `lib/stream_weaver/skills/visual-recap/` | **N — not in the `gem_skills` install list** (see Gaps) | Post-implementation visual summary of what changed |

## 6. The Representative 5 (first 20-minute tutorial)

1. **`streamweaver tutorial`** — the built-in guided app. Zero-setup, self-teaching first move; sets the "this is real code, not slides" tone immediately.
2. **`ruby app.rb` on the minimal example from `docs/for_llms.md`** (a 6-line `text_field` + reactive `text` app) — proves the "your DSL block re-executes on every interaction" mental model in under a minute, which is the single idea everything else builds on.
3. **`streamweaver panel demo`** + `canvas-push` from another terminal — the "wow" moment: an agent (or the coworker's own hand-typed command) drives a live split-pane UI with no HTML/JS. This is StreamWeaver's actual differentiator versus every other quick-UI tool, and it's the one capability a coworker cannot get anywhere else.
4. **`streamweaver showcase`** — self-serve exploration of the example library once the core loop clicks, so the tutorial doesn't have to enumerate every component; Matt's Law (find it, digest it) via a browsable index instead of a wall of text.
5. **`streamweaver export`** on a pushed canvas doc — closes the loop by showing the output is a real, shareable artifact (static HTML, no server needed), which matters for a coworker evaluating whether this is a toy or something they can actually hand to someone else.

Rationale: this set covers all four modes (standalone, agentic-adjacent via canvas-wait, canvas two-way, static export) with the minimum number of new concepts, and front-loads the one feature (`panel`) that no generic "Streamlit for Ruby" pitch conveys in words alone — it has to be seen running.

## 7. Gaps (things a newcomer would trip on)

1. **`visual-plan` and `visual-recap` skills exist in `lib/stream_weaver/skills/` but are absent from the `gem_skills` hash in `CLI.install_skill`** (`lib/stream_weaver/cli.rb:2056-2061`) — running `streamweaver install-skill` does not install them, and the command's own printed summary doesn't mention them either. A newcomer who reads the skill source directly and expects `install-skill` to wire it up will be quietly wrong.
2. **No `bin/iterm_split_browser.py` in this repo.** The iTerm split-pane behavior referenced by that name (from prior session memory) doesn't exist here — the actual mechanism is `lib/stream_weaver/iterm.rb`, a Ruby wrapper around the optional `iterm2_ruby` gem, invoked via `streamweaver panel`. Worth correcting in any tutorial material that inherited the old filename.
3. **`streamweaver template <name>`** is a documented top-level command (`lib/stream_weaver/cli.rb:916`) but this pass didn't find example template names or a `docs/` page describing what templates ship or how to list them — a newcomer typing `streamweaver template` with no args has no discoverable next step from the CLI help text alone (the main `help` output doesn't mention `template` at all, only `live`/`push`/canvas commands are documented there).
4. **`streamweaver pick` and `streamweaver confirm`** are listed in the dispatch table and called "high-level canvas helpers" in the main help text's Panel section, but neither appears in the `help` command's own examples, and this pass didn't trace their DSL surface — a newcomer has no worked example to copy.
5. **`examples/canvas/`** contains only `mermaid_canvas_demo.sh` — there's no example file demonstrating the basic `live`/`push` one-way session commands that the CLI help documents at length, so a newcomer following the help text's "Live Session Examples" has to hand-type them from scratch rather than running something first.

These are reported, not fixed — this was a read-only inventory pass.
