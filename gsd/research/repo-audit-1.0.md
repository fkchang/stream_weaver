# StreamWeaver Repo Audit — 1.0 Readiness

Audited 2026-07-02. Scope: factual inventory only, no design recommendations. This
report is input for a separate roadmap/strategy pass. Related existing research
already in this repo (not duplicated here): `gsd/research/market-positioning-research.md`
(HTML-vs-Markdown positioning) and `gsd/research/production-patterns-research.md`
(precedent survey for state/URLs/escape-hatch, written to inform exactly the gaps
this audit documents in sections 2-4).

---

## 1. Modes Inventory

StreamWeaver has evolved into **four distinct run modes**, documented in `README.md:67-72`:

| Mode | Invocation | Entry point | Maturity | Test coverage |
|---|---|---|---|---|
| Standalone script | `ruby app.rb` | `App#run!` in `lib/stream_weaver/app.rb`, own Sinatra server via `server.rb` | Mature — the original/primary mode | Broad, exercised by most of `spec/` |
| Agentic (popup input) | `app.run_once!` | Same `App` class, `run_once!` method | Mature, narrow use case | Covered by CLI eval/agentic specs |
| Service mode (multi-app-in-one-server) | `streamweaver app.rb` / `streamweaver serve` / `streamweaver run` | `lib/stream_weaver/service.rb`, dispatched via `lib/stream_weaver/cli.rb:15-107` (`case command`) | Functional but has the URL-slug gap (see section 3) | `spec/cli_spec.rb` and service-level specs |
| Canvas/panel push mode | `streamweaver live`, `streamweaver push`, `streamweaver panel`, `streamweaver canvas-*` (9 subcommands) | `lib/stream_weaver/canvas/{bridge.rb,bridge_server.rb,protocol.rb,session.rb,client.rb,doc_store.rb,history.rb,helpers.rb,reader.rb}` (2,231 lines total), CLI dispatch at `lib/stream_weaver/cli.rb:60-78` and `:1081-1467` | Actively developed, unevenly tested (see section 6) | `spec/canvas/` (9 files, ~1,196 lines, ~117 examples) + `spec/cli_canvas_push_spec.rb` + `spec/cli_canvas_read_default_spec.rb` — but **no direct spec file for `bridge_server.rb`** (1,111 lines, the largest and most load-bearing file in the subsystem) |

`lib/stream_weaver/cli.rb` is 1,897 lines and dispatches ~30 subcommands total
(`serve`, `run`, `list`, `remove`, `clear`, `admin`, `showcase`, `tutorial`, `stop`,
`status`, `llm`, `eval`, `prompt`, `live`, `push`, `live-list`, `live-close`, `wait`,
`template`, `canvas`, `canvas-push`, `canvas-wait`, `canvas-close`, `canvas-toast`,
`canvas-list`, `canvas-reset`, `canvas-stop`, `canvas-read`, `pick`, `confirm`,
`panel`, `opal-build`, `install-skill`, `setup`) — this is a large, sprawling CLI
surface for a single `exe/streamweaver` entry point.

A fifth mode exists at the deployment level rather than the DSL level: **Puma-dev
mode** (`README.md:156-188`, `examples/puma_dev/`), which runs a standard `config.ru`
under Puma-dev for memorable `http://myapp.test` URLs. This isn't a new run mode so
much as a deployment wrapper around standalone mode — but it's the one place in the
repo where a human-memorable URL story already works (see section 3 for why service
mode doesn't get the same treatment).

---

## 2. State Management

Two pluggable session stores exist, selected via `SW_SESSION_STORE` env var
(default `file`):

- **File store (current default)**: `StreamWeaver::FileSession < Rack::Session::Abstract::PersistedSecure`, `lib/stream_weaver/session_store.rb:66-165`. One `Marshal`-serialized file per session under `~/.config/stream_weaver/sessions/session_<id>`. No hard size limit. Sessions auto-expire after 24h (`expire_after: 86_400`); a startup cleanup in `lib/stream_weaver/server.rb:33-34` removes files older than 7 days.
- **Cookie store (legacy, opt-in)**: plain Sinatra `enable :sessions` (`server.rb:38-41`), hard-capped at 4096 bytes (`session_store.rb:34`). A `CookieStore#filter` (`session_store.rb:32-50`) strips blank values, known transient keys (`code_content`, `current_file_path`, `examples`, `_deck_state`, any `*_edited_code` key), and warns to stderr at 75% capacity (3,072B). No user-facing error on overflow — data is silently dropped past the filtered set.

**The "cookie too large" history is documented**: `CHANGELOG.md:205` records a
2026-01-02 incident — *"Tutorial session overflow - Session cookie was exceeding
4KB limit due to `*_edited_code` keys; now filtered from session storage."* The
`--reset` flag and `SW_DEBUG` env var (`CHANGELOG.md:36-37`) were added specifically
to troubleshoot this class of problem. A debug endpoint `GET /sw/session/size`
(`server.rb:862-878`) reports per-key byte sizes and an `over_limit` flag.

**Current state**: the file store is now default and effectively removes the 4KB
ceiling for standard installs. The cookie store remains available and still
silently truncates past 4KB with only a stderr warning — a data-loss risk if
`SW_SESSION_STORE=cookie` is set in production. Neither store is a shared/external
store (Redis, DB-backed) — file store is single-machine, filesystem-based, which is
adequate for local/dev use but not for multi-instance deployment.

---

## 3. Multi-App Server URL Generation (the hash-URL complaint)

**Exact generation point**: `lib/stream_weaver/service.rb:114-115`

```ruby
def load_app(file_path, name: nil, source: nil)
  app_id = SecureRandom.hex(4)
```

This produces an 8-hex-character id (e.g. `a3f9c2e1`), used directly as the URL
segment in the `/load-app` response (`service.rb:405-412`):

```ruby
url: "/apps/#{app_id}",
```

The route is defined at `service.rb:868` (`get '/apps/:app_id' do ... end`), and
the CLI prints the raw hash URL directly to the user at `cli.rb:158-159`.

**A partial fix already exists in the code but isn't wired to the default path**:
`aliased_path_for` (`service.rb:186-196`) builds a human-readable `/source/name`
route from an app's `name`/`source` fields, matched by a Sinatra route at
`service.rb:814-825` (`get '/:source/:name'` redirects to `/apps/:app_id`). This
only activates when `load_app` is called with an explicit `source:` — used by
`examples_browser` and `tutorial` internally — but the ordinary `streamweaver run
<file.rb>` CLI path (`cli.rb:123-166`) never passes `source:`, so everyday usage
always surfaces the raw hex `app_id` URL rather than a memorable slug.

---

## 4. "Escape to Sinatra" Gaps

No `TODO`/`FIXME`/"escape hatch" comments exist anywhere in `lib/` — the framework
doesn't self-document its own limits. Gaps identified by inspecting the DSL surface:

- **No custom HTTP route DSL for app authors.** `App#route` (`app.rb:134`) and
  `App#page` (`app.rb:119`) only register state-driven view matches, not arbitrary
  HTTP endpoints. There is no `get`/`post`/`put`/`patch`/`delete` method exposed on
  `App`. All real Sinatra routes (`/`, `/update`, `/action/:button_id`, `/submit`,
  `/event/:key`, `/form/:form_name`, `/theme/:theme_name`, `/deck/*` in `server.rb`;
  `/load-app`, `/live/*`, `/admin/*`, `/apps/:app_id/*` in `service.rb`) are
  framework-internal and not extensible from the DSL block.
- **No file upload support.** No multipart/`params[:file]` handling anywhere in
  `lib/` for app authors (only unrelated internal `Tempfile` usage and one unrelated
  `params[:file]` lookup in `canvas/reader.rb:107`).
- **No authentication/authorization layer.** No auth/authorize/CSRF concept in
  `lib/` beyond `set :protection, false if ENV['RACK_ENV'] == 'test'`
  (`server.rb:46`), which only disables Sinatra's built-in protection in tests.
- **No custom middleware DSL.** `use` appears only internally (session store
  wiring, `SW_DEBUG` logger) — never exposed to app authors.
- **Resource DSL is CRUD-only, single-table.** `docs/resource-dsl.md`'s store
  protocol (`all`/`find`/`create`/`update`/`destroy`) has no joins, relations, or
  nested resources — this is the newest subsystem (see gsd/plan.md /
  gsd/tasks.md / gsd/STATE.md below) and is intentionally scoped narrow.
- **Routing is explicitly documented as limited in one place.**
  `docs/routing.md:42`: *"One state key only. Doesn't handle parameterized paths
  like `/initiative/:id`"* for `route_by` — `route_with` is offered as the
  alternative but is still state-mapping, not general routing.

Net: any developer needing a webhook receiver, custom JSON API, non-GET/POST verb,
file upload, or auth has no documented in-framework path — they write raw Sinatra
alongside/instead of StreamWeaver. This is the gap `gsd/research/production-patterns-research.md`
was written to address (point "(c)" in that doc).

---

## 5. Gem Readiness

| Item | Status |
|---|---|
| Version | gemspec + `lib/stream_weaver/version.rb` both say **0.1.1**, but CHANGELOG.md has only ever cut `[0.1.0] - 2025-11-08` — everything since (including whatever justified the 0.1.1 bump) is still sitting in `[Unreleased]`. Version file and changelog are out of sync. |
| Dependencies | 10 runtime deps (sinatra, sinatra-contrib, phlex, puma, rackup, kramdown, kramdown-parser-gfm, ostruct, iterm2_ruby, diffy). **`iterm2_ruby ~> 0.1` is pointed at a local filesystem path in `Gemfile:9`** (`~/work/iterm2_ruby`), not published to rubygems.org — this is a hard blocker for `gem install stream_weaver` working for anyone but the author, since it's a runtime (not dev) dependency. |
| CI | **None.** No `.github/workflows/` directory exists. No automated tests, lint, or Ruby-version matrix on push/PR. |
| Test suite | Runs clean: **2,090 examples, 0 failures, 1 pending** (pending spec is an intentionally browser-only Opal test, not a real gap). ~5 second run time. Healthy suite size/health for a gem this size, but with zero CI it's only as good as manual discipline. |
| README | Hybrid — strong marketing/philosophy framing up top (mode comparison tables, "why StreamWeaver," collapsible longer story) with real Quick Start/install instructions further down. Reads more like a pitch/essay than a terse installation-first gem README; a first-time `gem install` user has to scroll past narrative to reach setup. |
| CHANGELOG | Real, substantial `[Unreleased]` section (~200 lines) with concrete entries, consistent Keep-a-Changelog formatting. Only one actual version cut (`0.1.0`) exists despite VERSION saying 0.1.1. |
| Docs tree | 73 files under `docs/`. Roughly 9 are genuine user-facing reference (`SERVICE_MODE.md`, `components_reference.md`, `crud-patterns.md`, `form-patterns.md`, `resource-dsl.md`, `routing.md`, `templates.md`, `testing.md`, `architecture/how_streamweaver_works.md`); the remainder is accumulated internal planning/scratch content — `docs/plans/*` (7 files), `docs/superpowers/plans/*` + `docs/superpowers/specs/*` (10 files, and per `.gitignore` these are supposed to be excluded from git but show up tracked in the working tree — worth reconciling), `docs/visual-skills/*` (25 files, session/build logs including `implementation/STATE.md`, `PROGRESS.md`, `SESSION-CONTEXT.md`), `docs/visual/*` (3 files), `docs/ideas/*` (3 files), `docs/blog/*`, stray `.rb` files inside `docs/streamweaver_canvas/`, and various spike/exploration docs (`opal-*`, `canvas-roadmap.md`, `canvas-ipc-session-summary.md`, `html-artifact-audit.md`, `ruby-ui-comparison.md`). This is not a coherent user-facing docs/ tree as-is. |
| exe/bin | `exe/streamweaver` is the actual packaged CLI entry point (wired via `spec.bindir = "exe"`). `bin/` (`build_scenarios`, `console`, `setup`, `opal_spike.rb`) is dev-only, correctly excluded from the gem by the gemspec's `spec.files` filter. |
| .gitignore | `*.gem` and `/pkg/` correctly ignored, none tracked. **`dist/` (2.7MB of built JS assets) is untracked but NOT in `.gitignore`** — currently shows as `?? dist/` in git status, one `git add -A` away from being accidentally committed. |
| Stray files at repo root | Two built `.gem` files sit at the repo root (`stream_weaver-0.1.0.gem`, `stream_weaver-0.1.1.gem`) — not tracked by git per the check above, but present on disk and should be confirmed as build artifacts, not something to ship. |

---

## 6. Canvas Mode Specifics

**Wire protocol** (`lib/stream_weaver/canvas/protocol.rb`, 74 lines): newline-delimited
JSON over a Unix domain socket (`~/.streamweaver/canvas.sock`) for Claude-to-Bridge
communication, plus WebSocket for Bridge-to-Browser. `Protocol.encode`/`.decode`/
`.parse_buffer` handle framing.

**Bridge architecture** (`bridge.rb`, 220 lines): `Bridge` holds an in-memory
`@sessions` hash (name to `Session`, no disk persistence — a crash loses all open
canvas sessions), dispatches messages by `type`. `handle_push` (line 112)
`instance_eval`s pushed DSL into a throwaway `App`, renders via the AlpineJS
adapter, and only persists the DSL on successful render — a bad push doesn't
clobber the last-good display state.

**Sessions**: `VALID_LAYOUTS = %i[default wide full fluid]` (`session.rb:9`);
theme is stored as a symbol with no validation against the actual theme registry.

**CLI surface**: 13 canvas-related subcommands in `cli.rb`, all functioning and
none stubbed.

**Documentation inconsistency found**: `docs/canvas-ipc-session-summary.md` is
headed "Status: OUTDATED — Canvas is now working and actively used" but its body
still documents a plan to delete `protocol.rb`, `session.rb`, `bridge.rb`,
`client.rb`, `bridge_server.rb`, `helpers.rb` in favor of an abandoned "templates"
approach — this actively contradicts the current (correct) architecture and should
be reconciled or removed before 1.0. `docs/canvas-roadmap.md` and
`docs/canvas-panel-workflow.md` are current and accurate.

**Relationship to the "visual companion" skill**: `lib/stream_weaver/skills/streamweaver-visual-companion/SKILL.md`
is a repo-shipped Claude Code skill built directly on canvas mode — it's an explicit
drop-in replacement for a Chrome-based visual companion, routing all interaction
through `panel`/`canvas-push`/`canvas-wait`. Canvas mode is therefore a dependency
of a shipped skill, not just an internal dev convenience, which raises the bar on
its required stability.

**Test coverage gap**: `spec/canvas/` covers session/doc_store/reader/history
behavior well, but **`bridge_server.rb` (1,111 lines, the largest and most
architecturally load-bearing file in the subsystem) has no dedicated spec file** —
only indirect coverage via CLI specs. Error handling across the small canvas files
is thin (13 `rescue` sites total across bridge/client/doc_store/helpers/history/reader).

**Overall**: an actively developed, real subsystem (not a throwaway experiment) —
but not fully mature for 1.0. In-memory-only session state (no crash recovery),
unvalidated theme/layout wire values, the largest file untested directly, and one
actively misleading doc file are the concrete gaps.

---

## 7. Tutorials

**CLI command**: `streamweaver tutorial` (`cli.rb:306`, `self.tutorial`) execs
`examples/advanced/tutorial.rb` as a standalone script.

**Content files**:
- `examples/advanced/tutorial.rb` (1,068 lines) — the live tutorial, 10 lessons
  (Philosophy, Hello World, Getting Input, Making Choices, Taking Action, Layout,
  Cards, Tables, Modals, Themes, Patterns). Last touched 2026-01-02 (the
  cookie-overflow fix commit).
- `examples_playground/advanced/tutorial.rb` — near-duplicate copy for the
  examples/showcase playground.
- `examples/claude_code/tutorial/README.md` — separate, small, Claude-Code-agent-oriented walkthrough.

**Staleness — confirmed stale.** The tutorial predates essentially all of the
`CHANGELOG.md` `[Unreleased]` section (there has been no version cut since 0.1.0
on 2025-11-08, so everything shipped since is "Unreleased"). Grep for
`canvas|navbar|doc theme|CardHeader|resource\b|route_by|route_with|opal` in
`tutorial.rb` returns zero real hits. The Themes lesson (`tutorial.rb:350-358`)
lists only `:default`, `:dashboard`, `:document` — missing the newer `:doc` theme
(added this cycle, commit `e98df87`) and the `:sketch` preset. No coverage of the
`resource` DSL/CRUD scaffolding, `navbar`/`nav_item`/`link_to`, `card_header`
badge/meta options, canvas/panel mode, or theme_switcher/theme_toggle — all
shipped after the tutorial's last edit. Roughly six months of feature growth is
undocumented in the one onboarding path that's wired into the CLI.

---

## 8. Theming/Styling

**`auto_mode.rb`** (`lib/stream_weaver/theme/auto_mode.rb`): generates inline JS
for OS-following dark/light mode, sets `data-sw-theme`/`dark` attributes on
`<html>` before `DOMContentLoaded` (avoiding flash-of-wrong-theme), persists
preference to `localStorage`, exposes `window.swToggleTheme`/`swGetTheme`. The
`mode:` parameter was a documented dead parameter until a fix landed this cycle
(`CHANGELOG.md:21`).

**Theme registry**: `lib/stream_weaver/theme.rb:151-206`, `BUILT_IN_THEMES` hash
with four entries — `:default` ("Warm Industrial"), `:dashboard` ("Data Dense"),
`:document` ("Reading Mode"), and `:doc` ("Compact Editorial" — added this cycle,
commit `e98df87`). No `register_theme` custom-theme API was found in the audited
region of `theme.rb`, despite CHANGELOG history referencing one previously —
worth confirming this API's current status before 1.0 messaging.

**Recent churn — actively in flux, not stable.** Three consecutive recent commits
(`e98df87`, `83be0bf`, `365e13a`) built the `:doc` theme and "doc-parity" polish
(a git-commit-message tag for matching an external artifact's editorial styling
pixel-for-pixel: ALL-CAPS table headers, `DocHeader` component, sticky-sidebar CSS
grid). The working tree at time of audit has uncommitted changes to
`auto_mode.rb`, `views.rb`, `components.rb`, and new/modified specs
(`theme_enhanced_spec.rb`, `theme_switcher_spec.rb`, `theme_toggle_spec.rb`,
`card_header_spec.rb`) — theming is mid-iteration right now, not settled.

**Test coverage**: `spec/theme_enhanced_spec.rb` (presets, AutoMode, ThemeToggle,
backward-compat), `spec/canvas/theme_support_spec.rb` (canvas session theme
carrying), `spec/components/theme_switcher_spec.rb` and `theme_toggle_spec.rb`
(narrow HTML-rendering checks).

---

## Existing Plans Found (so this audit doesn't duplicate them)

- **`docs/for_llms.md`** and **`llms.txt`** — both are LLM-oriented quick-reference
  docs (port auto-detection warning, "the DSL block re-executes on every
  interaction" mental model, minimal examples). Overlapping content between the
  two; not a planning doc.
- **`gsd/plan.md`, `gsd/tasks.md`, `gsd/STATE.md`** — a completed GSD Ralph-loop
  execution plan for the **Resource DSL** feature (routing chain, `page`/`route`
  DSL, `ResourceDefinition`, `DefaultViews`, override blocks, scaffolding
  examples). All 6 tasks (T1-T6) are marked **DONE** with commit hashes in
  `gsd/STATE.md` — this work is finished and merged, not in flight.
- **`gsd/research/production-patterns-research.md`** — a precedent survey
  (Streamlit, Rails "Solid" trio, etc.) written specifically to address the three
  pain points this audit independently confirmed: (a) cookie-session overflow
  history, (b) hash-based multi-app URLs, (c) users dropping to raw Sinatra. This
  is strategy input already sitting in the repo, not something to re-derive.
- **`gsd/research/market-positioning-research.md`** — positioning research
  (Anthropic's Markdown-to-HTML shift, docs-site template survey, demo-video
  stack) — orthogonal to the technical gaps in this audit, useful for the
  marketing/positioning side of a 1.0 roadmap.
