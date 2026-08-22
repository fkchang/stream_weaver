# Hotwire/Rails vs. StreamWeaver: Concept-by-Concept Gap Map

Grounds the "Hotwire-grade omakase layer" proposal. Honest accounting of what Rails/Hotwire
provides vs. what StreamWeaver ships today, by file and DSL method. Sources: `README.md`,
`docs/for_llms.md`, `docs/streamweaver-frontend-vision.md`, `docs/routing.md`,
`docs/resource-dsl.md`, `gsd/analysis/00-analysis-and-plan.md`, `features/route-tabs.feature`,
`features/now-view-support.feature`, `lib/stream_weaver/server.rb`,
`lib/stream_weaver/interaction_runner.rb`, `lib/stream_weaver/components.rb`,
`lib/stream_weaver/views.rb`, `lib/stream_weaver/streamer.rb`, and CHANGELOG.md.

StreamWeaver already has an explicit thesis document for this exact question
(`docs/streamweaver-frontend-vision.md`): a "Hotwire-equivalent stack" built on
`Ruby DSL + htmx + Alpine.js + Idiomorph` instead of `Turbo + Stimulus`. This map checks that
thesis against what's actually implemented, concept by concept.

---

## 1. Turbo Drive (full-page nav without reload; history)

**Hotwire/Rails**: Every `<a>` and form submission is intercepted, fetched via AJAX, and the
response body swaps into `<html>` — no full navigation, but the URL bar and browser history
update as if it were a real nav. Works automatically on all links with zero configuration.

**StreamWeaver today**: `hx-boost="true"` at the `<body>` level, documented as the
"Hotwire-Style Navigation Pattern" in `docs/for_llms.md` (§"Hotwire-Style Navigation Pattern"),
reference implementation `lib/stream_weaver/views/canvas/reader_layout.erb`. This is opt-in
per-layout, not automatic for every StreamWeaver app — only canvas-read's layout currently uses
it. `route_by`/`route_with` (`docs/routing.md`) separately drive `HX-Push-Url` for state-driven
URL changes on the main app container, which is a different mechanism (POST-then-push, not
GET-boosted anchor navigation).

**Gap assessment: PARTIAL** — the underlying primitive (htmx `hx-boost`) is proven in one
reference layout, but it is not a framework-level default; a new StreamWeaver app gets full
POST/morph interaction handling, not Turbo-Drive-style boosted navigation, unless the author
hand-wires the same `hx-boost`/`hx-select`/`hx-select-oob` pattern documented in the reader
layout.

---

## 2. Turbo Frames — named region replaced independently (scoped updates)

**Hotwire/Rails**: `<turbo-frame id="x">` is a custom element (`alex_turbo_frames_transcript.txt`
§6:27–7:47 traces this precisely: it's just `customElements.define`, no magic). A frame's
`connectedCallback` fires the initial fetch if `src` is present; any link/form inside it targets
it by default. The server returns a full page; Turbo discards everything except the matching
frame ID.

**StreamWeaver today**: `fragment :name do ... end` (`lib/stream_weaver/app.rb:419`,
`Components::Fragment` in `lib/stream_weaver/components.rb:107`). An action declares
`updates: :name` or `updates: %i[a b]`; on interaction, `InteractionRunner`
(`lib/stream_weaver/interaction_runner.rb:170`) renders `Views::FragmentContentView`
(`lib/stream_weaver/views.rb:3801`) — the primary fragment plus any declared `updates:` regions
as out-of-band swaps. As of the 2026-07-11 benchmark gate
(`gsd/analysis/00-analysis-and-plan.md` — "GATE PASSED... 14 PASS, 0 FAIL"), this also has a
row-granular counterpart (`RowSwapView`, `views.rb:3821`) so a table-row edit returns ~2KB
instead of the whole fragment.

**Mechanism difference worth naming**: a Turbo Frame request re-renders *only that one
controller action*. A StreamWeaver fragment update still re-runs the **entire DSL block**
server-side (README: "Fragments keep the normal single full DSL rerun while limiting the HTML
swapped into the page") — the scoping is in what's sent to the client, not in what executes on
the server. True fragment-local re-execution is explicitly deferred
(`gsd/analysis/00-analysis-and-plan.md`, "Deferred items... decision-gated at Phase 5.1").

**Gap assessment: PARTIAL** — the client-visible outcome (one region updates, benchmarked
close to hand-written htmx payload sizes) is achieved and shipped. The server-side execution
model is architecturally different (whole-rerun-then-slice vs. true per-frame dispatch), which
is a real cost for apps with expensive per-region computation, and multi-fragment composition
(nested/nameable nesting like Turbo's `src=`-chained frames) has no equivalent.

---

## 3. Frame ID matching convention (dom_id; "key frame by what's unique per position on page")

**Hotwire/Rails**: `dom_id(record, prefix)` generates `prefix_recordtype_id` deterministically.
The transcript's stated rule (10:56–12:15, reinforced at 39:18): **key the frame by what's
unique per position on the page, not by what the content is about** — e.g. key a hover-card
frame by the to-do, not the user, or two cards for the same user collide (this exact bug is
demonstrated live in the transcript, 38:52–40:24).

**StreamWeaver today**: `Fragment#id` (`components.rb:111`) — an author-supplied name, not a
derived-from-record convention. Loop-rendered interactive components (buttons, in particular)
historically collided when two loop iterations produced identical label+source-location IDs;
`CHANGELOG.md` records a shipped **button `id:` option** to disambiguate manually. The larger
fix — auto-disambiguation by render occurrence, a `key:` option accepting only stable scalars,
and a `strict_ids: true` mode that becomes the 1.0 default — is scoped as "Phase 0" in
`gsd/analysis/00-analysis-and-plan.md` and is not confirmed shipped (no `strict_ids` or
automatic-warn-and-disambiguate logic found in `lib/`).

**Gap assessment: MISSING** for the Rails convention itself (there is no `dom_id`-equivalent
helper deriving a guaranteed-unique ID from a record); **PARTIAL** for the underlying safety
property — manual `id:`/`key:` opt-out exists, but StreamWeaver's own gap catalog names silent
loop-ID collision as "the most dangerous bug in the catalog" (`00-analysis-and-plan.md`, Root
cause 2), i.e. the framework does not yet guarantee what Rails' `dom_id` guarantees by
construction.

---

## 4. "Content missing" failure semantics — loud, styleable, well-known failure when IDs don't match

**Hotwire/Rails**: When a frame's ID doesn't match anything in the response, Turbo renders the
literal text "Content missing" into the frame and adds a `.turbo-frame` error class — a visible,
CSS-styleable, well-documented failure (transcript 12:31–14:55: "It's not a crash... it's a
really quiet failure. There's no exception, no 500... but it's loud in the DOM"). This is a
deliberate design choice: fail visibly rather than guess.

**StreamWeaver today**: the opposite policy, by explicit design. README: "If a target
disappears or routing changes, StreamWeaver automatically falls back to a full swap." The
`InteractionRunner`/server.rb path validates a signed action token; on mismatch it raises
`StaleActionDefinition`, caught in `server.rb:299` to return `status 409` + `HX-Retarget:
#app-container` + a full re-render — i.e. it self-heals rather than surfacing a stuck "content
missing" box. `gsd/analysis/00-analysis-and-plan.md` names this explicitly:
"`HX-Retarget` full-container fallback (correct-by-fallback)."

**Gap assessment: N/A by design, not a gap** — this is a deliberate inversion of Hotwire's
philosophy (fail loud vs. self-heal), consistent with StreamWeaver's whole-rerun architecture
where a full fallback is always available. Worth flagging to the owner as a design decision to
make explicit in docs, not an accidental omission: StreamWeaver currently has no dev-mode
equivalent of "make broken wiring embarrassingly obvious," which the transcript's operator
(Forrest, 13:11) singles out as the single highest-leverage debugging aid in Turbo Frames.

---

## 5. Eager-loading frames (`src` attribute — render page now, slow panel lands later)

**Hotwire/Rails**: `<turbo-frame src="/slow_panel">` fires its own fetch the instant it's
parsed into the DOM, independent of the rest of the page. The transcript's framing (31:18–33:00):
"you have a page with three cheap panels and one really expensive query... with a frame you put
it behind a source, and the page renders it immediately." This is the textbook fix for
Streamlit-style whole-page-blocks-on-slow-query, which is exactly the failure mode StreamWeaver's
own gap catalog calls out (`00-analysis-and-plan.md`, Root cause 1: "This is exactly Streamlit's
scaling wall").

**StreamWeaver today**: no equivalent found. Every DSL block — including all fragments —
executes synchronously as part of one request/response cycle; there is no `src=`-style deferred
fetch that lets the shell render before a specific region's slow work completes. The closest
existing primitives are `every(seconds)` timers pushing SSE updates after initial render
(`docs/for_llms.md` §"Live Streaming with `every` Timers") and the manually-swapped
`streamer.replace` — both are *post-load* update mechanisms, not *initial-load* deferral. The
plan doc's own deferred-items list confirms this gap: `button async: true` background-work
primitive is explicitly "decision-gated at Phase 5.1," not built.

**Gap assessment: MISSING** — this is the single largest architectural gap for the "no custom
JavaScript" complex-app case: a StreamWeaver author with one slow panel today must hand-roll
`every` + `streamer.replace` (documented as a known workaround pattern, e.g.
"cultivation_dashboard's 15+ wrapped sections" per the plan doc) to approximate what Turbo gets
for free with one HTML attribute.

---

## 6. Lazy-loading frames (`loading=lazy`, fires on visibility — hover cards, infinite scroll via nested frames)

**Hotwire/Rails**: `loading="lazy"` defers the fetch until the frame becomes visible (not
scrolled-near, not hovered — actually visible per IntersectionObserver semantics under the
hood, transcript 33:07–35:02). Combined with pure CSS (`display:none` → `display:block` on
hover), this gives hover-cards and hover-triggered any-content with zero JS. Nested lazy frames
("Russian dolls," transcript 45:xx) give infinite scroll the same way: each page's response
contains the next page's placeholder frame, already marked lazy.

**StreamWeaver today**: `tabs :key, lazy: true` exists (`lib/stream_weaver/app.rb:859-866`,
renderer in `adapter/alpinejs.rb:2325-2383`) but is **click-triggered POST-then-morph**, not
visibility-triggered — inactive lazy tab panels render a `<!-- lazy: tab N not rendered -->`
comment and fetch only when the tab is clicked. This is closer to Rails' `remote: true`
click-to-load than to Turbo's IntersectionObserver-based `loading=lazy`. Notably,
`features/route-tabs.feature` (Scenario: `deprecate-lazy-post-morph`) shows this exact mode is
being **deprecated in favor of a future "lazy route tabs"** replacement — the team already knows
this primitive needs rework. No hover-card or infinite-scroll pattern (nested-lazy-frame
equivalent) exists anywhere in `lib/`.

**Gap assessment: PARTIAL, and self-acknowledged as needing rework** — the click-lazy primitive
exists for one component (tabs) and is already flagged for deprecation; visibility-based lazy
loading and nested-frame infinite scroll have no StreamWeaver equivalent at all.

---

## 7. Turbo Streams — multi-region updates from one response

**Hotwire/Rails**: A single response (from a controller action, a broadcast, or a form
submission) carries `<turbo-stream action="replace/append/prepend/remove" target="...">`
elements — arbitrary DOM operations to arbitrary named targets, all delivered together.

**StreamWeaver today**: two overlapping mechanisms, per `docs/streamweaver-frontend-vision.md`'s
own comparison table ("Turbo Streams | htmx out-of-band swaps + Alpine | OOB covers the
partial-update case; Alpine covers the live-update case"):
1. **Fragment `updates:` scopes** (see #2) — OOB swaps declared per-action, resolved through the
   same request/response cycle as the primary fragment.
2. **`Streamer`** (`lib/stream_weaver/streamer.rb`) — `replace`/`append`/`prepend`/`remove`/
   `add_class`/`remove_class` (`ACTIONS` constant, `streamer.rb:15`), pushed over SSE from
   `every(seconds)` timer blocks (`docs/for_llms.md` §"Live Streaming with `every` Timers").
   This is a near-exact operational match to Turbo Stream actions, just server-timer-driven
   rather than broadcast-from-anywhere.

**Gap assessment: HAVE** — the action vocabulary (replace/append/prepend/remove/class toggles)
and the "multiple regions from one push" capability both exist and are documented with real
worked examples. The gap is provenance, not capability: Turbo Streams can be emitted from any
controller action or model callback broadcast; StreamWeaver's `Streamer` is currently reachable
only from `every` timer blocks and (per `now-view-support.feature`, Scenario
`session-scoped-broadcast`) has a **known, tracked correctness bug** — pushes broadcast to every
open SSE connection unfiltered by session, so one browser tab's `every`-driven update can leak
into a different session's tab. That story is explicitly marked "not a small patch... treat it
as its own sub-investigation" — i.e. multi-region push works, but not yet safely multi-tenant.

---

## 8. Server-push (broadcasts over websocket/SSE)

**Hotwire/Rails**: `Turbo::StreamsChannel.broadcast_*` pushes over ActionCable (WebSocket) from
anywhere in the Rails stack — model callbacks, background jobs, controller actions — to any
number of subscribed browsers.

**StreamWeaver today**: SSE only (`Streamer`, `lib/stream_weaver/streamer.rb`; client listener
`adapter/alpinejs.rb:1140-1184`), explicitly a deliberate choice —
`gsd/analysis/00-analysis-and-plan.md`'s "Deferred items" list states "WebSocket support (SSE
already exists and covers the dashboard case)." Push is currently triggered only from `every`
timer blocks inside the app definition, not from arbitrary server-side code (no equivalent of
"broadcast from a background job" or "broadcast from another process"). The session-scoping bug
in #7 also applies here directly.

**Gap assessment: PARTIAL** — SSE-based push exists and is documented as the intentional,
lighter-weight substitute for ActionCable, which is reasonable for StreamWeaver's single-process
model. But it's narrower in origin (timer-triggered only, not broadcast-from-anywhere) and has
an open, tracked cross-session leak bug that would block relying on it for anything beyond a
single-user dashboard today.

---

## 9. Stimulus (small JS behaviors with lifecycle, targets, cleanup) vs. Alpine's role in StreamWeaver

**Hotwire/Rails**: Stimulus controllers are JS classes with `connect()`/`disconnect()`
lifecycle hooks, `data-target`/`data-controller` wiring, explicit cleanup on DOM removal (the
transcript's word-count example, 3:36–5:43, is a canonical minimal Stimulus controller built by
hand to show what Turbo Frame itself is made of).

**StreamWeaver today**: Alpine.js `x-data` declarations inline in server-rendered markup —
`docs/streamweaver-frontend-vision.md`'s comparison table names this explicitly as the chosen
substitute ("Stimulus controllers | Alpine `x-data` declarations | Closer to the markup, no
separate JS file per component"). For genuinely reusable custom behavior beyond what inline
Alpine expresses well, `StreamWeaver.register_component` / `component_registry.rb` lets an
author register a real Phlex-backed component as a DSL verb — confirmed shipped and spec'd per
`gsd/analysis/00-analysis-and-plan.md` ("Component registration — already shipped
(`StreamWeaver.register_component`, `component_registry.rb`, spec'd); document it prominently
instead").

**Gap assessment: PARTIAL, by design** — this is the one area where StreamWeaver has made an
explicit architectural bet to *not* replicate Hotwire 1:1 (Alpine's inline-declaration model
instead of Stimulus's class-based one), and the reasoning is documented (token efficiency for
LLM-generated views, no separate-file mental overhead). The real gap is that Stimulus's
lifecycle guarantees (connect/disconnect firing reliably across morphs, listener cleanup
enforced by the base class) have no equivalent enforcement mechanism in the Alpine convention —
that discipline is left to whoever writes the `x-data` block, with no framework-level guardrail
against the leaked-listener class of bug the transcript calls out (3:36) as Stimulus's main
value.

---

## 10. Form conventions (`form_with model:`, REST resource routing, strong params foot-guns)

**Hotwire/Rails**: `form_with model: @record` infers the URL/HTTP verb from the record's
persistence state; omitting an explicit `url:` on a nested/nonstandard case silently POSTs to
the generic endpoint and can overwrite unrelated attributes if strong params are too permissive
(the transcript's demonstrated failure, 17:28–22:00: editing just a title accidentally
flips `completed` too, because the generic endpoint permitted all three fields).

**StreamWeaver today**: two form mechanisms.
- **`form :name do ... submit "Save" do |values| ... end`** — deferred-submission block, POSTs
  to `/form/:form_name` with Rails-style nested params, documented in `docs/for_llms.md` and
  handled by `InteractionRunner` (`interaction: :form` branch, `server.rb:382-397`).
- **`resource :post, store: PostStore do field :title, :string; ... end`**
  (`docs/resource-dsl.md`) — the closer Rails analog: `field` declarations act as an explicit
  allowlist (StreamWeaver's version of strong params — only declared fields are read from
  submitted state), auto-generates `new`/`edit` forms bound to a duck-typed store protocol
  (`all`/`find`/`create`/`update`/`destroy`), validated at startup, plus named-route helpers
  (`posts_path`, `post_path(rec)`, etc.). This is explicitly called "shipped, tested (98
  examples green)" in `gsd/analysis/00-analysis-and-plan.md`, described as infrastructure to
  build on, not a gap.

`form_with`-style block-yielding record binding (`form_with(model: @record) { |f| f.text_field
:title }`) is explicitly **not yet implemented** — `docs/streamweaver-frontend-vision.md`
lists it under "Forms (open question)": "This is not yet implemented. It is on the roadmap."
The plan doc's Phase 3 names `form_for` model binding as a still-to-do decision doc + build item
("kills rivet's nine hand-managed `edit_*` keys").

**Gap assessment: PARTIAL** — `resource`/`field` already delivers the strong-params-equivalent
safety property Turbo's demo is warning about (a StreamWeaver `resource` form cannot
accidentally write undeclared fields, by construction), and CRUD scaffolding is genuinely
shipped. What's missing is the Rails-familiar block-yielding form-builder ergonomics
(`form_with(model:)`) for hand-written (non-`resource`) forms — today's `form` block is closer
to Rails' `form_tag` than `form_with(model:)`.

---

## 11. URL/history semantics (when does URL change; deep-linkable states)

**Hotwire/Rails**: Turbo Drive updates the URL/history on every boosted navigation
automatically; Turbo Frames deliberately do *not* touch the URL unless `data-turbo-action`
opts in (transcript 15:01, "Gotcha 3: the URL doesn't change... that's usually exactly what we
want").

**StreamWeaver today**: this is one of the most fleshed-out areas. `route_by`/`route_with`
(`docs/routing.md`) give a bidirectional URL↔state contract: GET seeds state from the path,
POST responses push `HX-Push-Url` derived from a `builder` lambda. `docs/routing.md`'s "Common
Pitfalls" section documents two real, previously-hit bug classes in detail (state-merge leakage
across narrow route branches; non-exhaustive `case`/`when` failing silently in both directions)
— evidence this has been exercised against real, sizeable apps (~20 branches, 15 tabs), not just
designed on paper. `features/route-tabs.feature` extends the same contract to `tabs :key,
url: true` with explicit server-authority rules ("On full GET the URL is authoritative... absent
param must not inherit session value" — Scenario `server-param-authority`) and documented
degradation in canvas/websocket mode. The `resource` DSL layers named-route helpers
(`posts_path`, `post_path(rec)`) on top.

**Gap assessment: HAVE** — deep-linkable, bookmarkable, back/forward-correct URL state is a
real, documented, pitfall-audited feature, arguably StreamWeaver's most Rails-native area today.
The gap vs. Hotwire is narrow: no automatic URL update on every navigation (StreamWeaver's is
opt-in per state key/tab, matching Turbo Frame's "don't touch the URL by default" philosophy
rather than Turbo Drive's "always update" one) — a reasonable design choice, not an oversight.

---

## 12. Scaffolding/generators (`rails g scaffold` → working CRUD)

**Hotwire/Rails**: `rails g scaffold Post title:string body:text` generates a model, migration,
controller with all seven REST actions, and views — a working CRUD app from one command.

**StreamWeaver today**: `resource :post, store: PostStore do field :title, :string; ... end`
(`docs/resource-dsl.md`) is the declarative equivalent — one block replaces "30–50 lines of
route/state/form boilerplate," generating index/show/new/edit/destroy with deep-linkable URLs,
route helpers, store validation at startup, and override blocks per action. Two working
reference apps exist: `examples/scaffolding/blog.rb` (~50 lines, zero-dependency smoke test) and
`examples/scaffolding/utf_lite.rb` (multi-resource, custom index override). This is a
**declarative-scaffold-as-code** pattern rather than a **generator-writes-files** pattern — there
is no `streamweaver new <name>` CLI command that scaffolds files onto disk.
`docs/streamweaver-frontend-vision.md` names this explicitly under "Scaffolding (long-term)":
"well downstream — the conventions need to stabilize first," not yet built.

**Gap assessment: PARTIAL** — the *outcome* Rails scaffolding produces (working CRUD from
minimal input) is achieved, arguably more concisely (one `resource` block vs. generated files
to maintain), and is genuinely shipped/tested. What's missing is the code-generation workflow
itself — no `streamweaver new` / `streamweaver generate` command exists, and there's no path yet
for an author who wants generated, then-hand-edited files rather than a live declarative block.

---

## 13. Progressive disclosure for AI agents (skills/guides that teach the framework)

**Hotwire/Rails**: no direct analog — Rails' equivalent of "teaching an AI agent the
framework" is its own extensive documentation, guides, and (increasingly) community-authored
AGENTS.md/CLAUDE.md files; there's no framework-shipped, tool-agnostic skill mechanism.

**StreamWeaver today**: this is a built, first-class part of the framework, and unusually
mature for a project this size.
- **`docs/for_llms.md`** (aliased as `llms.txt`) — an LLM-quick-reference doc, deliberately
  structured around common failure modes ("Common Mistakes," "Anti-Patterns That Cause Churn"),
  updated in lockstep with features (e.g. `route-tabs.feature`'s `docs-update` scenario requires
  `for_llms.md` + `llms.txt` updates as an acceptance criterion, not an afterthought).
- **Two shipped SKILL.md packages**: `streamweaver-visual-companion` (mockups/diagrams/
  brainstorming via canvas-push) and `streamweaver-doc-builder` (long-form `:doc`-theme
  documents), both installable to Claude Code's own path *and* the cross-tool
  `.agents/skills/` alias via `streamweaver setup` / `install-skill` — `docs/for_llms.md` names
  the exact install commands and directs agents to check for these before hand-rolling canvas
  DSL from raw examples.
- **`docs/reference/agent-skills-comparison.md`** — a researched comparison of how Claude Code,
  Codex, Gemini CLI, and GitHub Copilot each discover/trigger skills (SKILL.md spec via
  agentskills.io, `.agents/skills/` cross-tool alias), which is what informed the multi-tool
  install path above. This is meta-level: StreamWeaver has already researched and built for
  "teach every agent, not just Claude," which is exactly the concern a Hotwire-parity effort
  would need to replicate for its own new surface area.
- Repo-local skill: `.claude/skills/streamweaver-panel.md` documents the panel/canvas-push/
  canvas-wait workflow directly.

**Gap assessment: N/A — this is StreamWeaver's own concept, not a Hotwire one**, and it's a
genuine, shipped asset: the project already treats "does an AI agent build this correctly on
first try" as a first-class, tested acceptance criterion (see `docs/routing.md`'s Common
Pitfalls section, `for_llms.md`'s Common Mistakes, and every `.feature` file's `docs-update`
scenario). Any Hotwire-parity work should extend this existing discipline (update
`for_llms.md`/`llms.txt` + relevant skill as part of the feature, not as a follow-up) rather
than invent a new documentation mechanism.

---

## Summary Table

| # | Concept | Assessment |
|---|---|---|
| 1 | Turbo Drive | PARTIAL |
| 2 | Turbo Frames (scoped regions) | PARTIAL |
| 3 | dom_id / frame-keying convention | MISSING (helper) / PARTIAL (safety) |
| 4 | "Content missing" loud failure | N/A — deliberate inversion (self-heal instead) |
| 5 | Eager-loading frames (`src`) | MISSING |
| 6 | Lazy-loading frames (visibility) | PARTIAL, self-flagged for rework |
| 7 | Turbo Streams (multi-region push) | HAVE, with a tracked correctness bug |
| 8 | Server-push (websocket/SSE) | PARTIAL — SSE only, timer-triggered only |
| 9 | Stimulus vs. Alpine | PARTIAL, by design |
| 10 | Form conventions / strong params | PARTIAL |
| 11 | URL/history semantics | HAVE |
| 12 | Scaffolding/generators | PARTIAL |
| 13 | Agent progressive disclosure | N/A (StreamWeaver-only concept) — HAVE, mature |

