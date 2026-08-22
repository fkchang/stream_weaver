# streamweaver-way — epic context

## Why this epic exists

Study-group session on Turbo Frames (2026-08-17, `alex_turbo_frames_transcript.txt`,
from the learnhotwire.com course — course repo github.com/learnhotwire/rails)
crystallized the thesis: Hotwire's power is not Turbo's mechanics — htmx/Alpine already
have those — it's the omakase layer: conventions (`dom_id`, resources, partials),
failure semantics ("content missing"), and a backend/frontend designed as one system.
Three research docs ground this epic:

- `docs/research/2026-08-17-hotwire-alike-landscape.md` — **the niche is empty.**
  Nobody has built a Hotwire-grade omakase layer over htmx/alpine. Frontend libraries
  (Unpoly, Alpine AJAX, Datastar) add convention but ask nothing of the backend, by
  design; backend attempts (Loco.rs, FastHTML) never define the shared middle
  (fragment ID convention + patch semantics + wire format). The one real transplant
  (turbo-laravel) ported Hotwire itself rather than rebuilding it on htmx.
- `docs/research/2026-08-17-hotwire-concept-map.md` — 13-concept gap map.
  **Known erratum**: §10 claims record-bound forms are unimplemented; `form_for`
  shipped 2026-07-10 (`lib/stream_weaver/app.rb:598`) — it was just undocumented.
  Story `document-form-for` fixes both the docs and the map.
- `docs/research/2026-08-22-learnhotwire-syllabus-coverage.md` — full 65-row matrix
  against the entire learnhotwire syllabus (HAVE 12 / PARTIAL 21 / MISSING 11 /
  N-A-by-design 21). This is the **living verification doc**: parity claims land here
  in the format "Rails uses <mechanism> for <feature>, key elements <X>; StreamWeaver
  equivalent is <Y>."

**Strategic ruling**: do NOT build a generic "Hotwire for htmx" library. Hotwire works
because one team owns both sides; StreamWeaver already owns both sides. Finish the
omakase layer inside StreamWeaver, codify it as The StreamWeaver Way, and only later
consider extracting a portable convention (Datastar's cross-language SDK pattern is
the model). OSS extraction deferred until conventions stabilize on real apps.

## Scope ruling: this epic = Turbo Frames chapters

The study group moves through the course a section at a time; epics track it. This
epic covers the **Turbo Frames chapters** (Alex's 2026-08-17 preso: inline editing,
search, hovercards, infinite scroll) plus the cross-cutting primitives they expose.

The rest of the arc exists NOW as pending Tyrion epics, each with a blocked
`shape-epic` first story naming its unlock condition — an orchestrating thread reads
`tyrion status` / `tyrion epic show` to know where to go next. Chain:
streamweaver-way → turbo-streams-parity (also gated on now-view
session-scoped-broadcast fix) → modal-dialogs-parity → stimulus-role-parity.
Feature files: features/turbo-streams-parity.feature,
features/modal-dialogs-parity.feature, features/stimulus-role-parity.feature.
Epic ownership of every syllabus row: "Epic ownership roadmap" section in
docs/research/2026-08-22-learnhotwire-syllabus-coverage.md. Shaped-when-reached
(Turbo Streams is next, ~2 weeks):

- **Turbo Streams parity epic**: broadcast-from-anywhere Streamer (currently `every`
  timer-only), `refresh_fragment` bare-refresh action (broadcasts_refreshes
  equivalent), extensible `Streamer::ACTIONS` registration (custom stream actions).
  HARD PREREQ: the session-scoped-broadcast leak fix (now-view-support epic) —
  broadcast-from-anywhere widens that bug's blast radius, so it lands first.
- **Modal dialogs epic**: native `<dialog>`/`showModal()` for the `modal` component
  (the pattern already exists internally in the mermaid fullscreen viewer — free
  focus-trap and `::backdrop`).
- **Stimulus-role epic** (if warranted): drag-and-drop/`sortable:` primitive (core to
  the course's My Todos reordering), autogrow textarea, `submits_with:`-style button
  label swap. Some may fold into other epics as cheap additions.

## The verification vehicle: My Todos companion app

`examples/my_todos/` — a StreamWeaver/Sinatra mirror of the course's Rails My Todos
app. Forrest's verification format, per feature: *"Rails example uses <Turbo
mechanism> to do <xyz>, key elements <BLAH>; StreamWeaver does equivalent via <Y>."*
Story `my-todos-parity-spike` builds it against today's primitives to discover exact
break points (SDRD: build to discover). Story `my-todos-zero-js` completes it on the
shipped primitives and back-fills verified parity entries into the syllabus matrix —
the epic's definition of done. The app doubles as study-group demo material.

## Story order and dependencies

`my-todos-parity-spike` and `document-form-for` first (spike needs form_for docs
awareness; both independent). Then the primitive stories (`strict-ids-auto-keying`,
`deferred-fragments-src`, `visibility-lazy-fragments` — visibility-lazy builds on
deferred-fragments' fetch path) plus `dev-loud-failure-overlay` (independent).
`my-todos-zero-js` after the primitives. `streamweaver-way-skill` last.

## Adjacent epic state (as of 2026-08-22)

- **route-tabs: SHIPPED 2026-08-21 (8/8)** — URL-driven tabs landed; the click-lazy
  post-morph tabs mode is deprecated with a named-but-undesigned "lazy route tabs"
  successor. `visibility-lazy-fragments` IS the design for that successor's
  underlying primitive; its design note must cover tab-panel adoption.
- **now-view-support** (drafted, un-imported): owns `session-scoped-broadcast` (SSE
  cross-session leak). NOT this epic's problem — deferred/lazy fragments use
  request/response fetch, not SSE — but it gates the future Turbo Streams epic.

## Design rulings baked into this epic

1. **Dev loud, prod self-heal**: keep prod's `HX-Retarget` full-swap self-heal
   (`server.rb` 409 path); add a dev-mode loud overlay. Deliberate inversion of
   Hotwire's "content missing", now made explicit.
2. **Key by position, not content**: the transcript's frame-keying rule (hover-card
   collision demo, 38:52–40:24) becomes a documented law, enforced by `strict_ids`.
3. **Trilaws as design filters**: Matt's Law (find/digest), Forrest's Law (zero
   friction + substantial perks — deferred loading must be one option on an existing
   verb, not a new subsystem), Gloria's Law (the default path must be the correct
   path).
4. **Scoping is what's sent, not what runs**: fragments re-run the whole DSL and
   slice the response. `deferred-fragments-src` must not silently change that model
   for non-deferred fragments; true fragment-local re-execution stays deferred per
   `gsd/analysis/00-analysis-and-plan.md`.

## Prior art inside the repo

- Phase 0 strict-ids scoping: `gsd/analysis/00-analysis-and-plan.md` (auto-disambiguate
  by render occurrence, `key:` stable scalars, `strict_ids: true` as eventual default).
  CHANGELOG records the manual button `id:` stopgap already shipped.
- Record-bound forms: `form_for` (`lib/stream_weaver/app.rb:598`) — shipped, spec'd,
  undocumented.
- Fragment/OOB pipeline: `lib/stream_weaver/interaction_runner.rb:170`,
  `Views::FragmentContentView` (`views.rb:3801`), row-granular `RowSwapView`
  (`views.rb:3821`).
- Fallback/self-heal path: `server.rb:299` (StaleActionDefinition → 409 +
  `HX-Retarget: #app-container`).
- Native `<dialog>` precedent: mermaid fullscreen viewer (for the future modal epic).
- Docs discipline: docs updates (`for_llms.md`, `llms.txt`) are acceptance criteria,
  not follow-ups.

## Standing test rules (from ledger memories)

- Any UI claim gated by MAIN-THREAD browser verification (playwright-cli) with
  screenshots — never curl-level self-assessment.
- Every test boot: `SW_NO_OPEN=1` / `PORT=<port>` and kill the boot when done.

## UTF mirror

This epic is mirrored as UTF campaign `streamweaver-way` (cultiv-cabinet utf plan) so
it appears in the resumability ledger alongside other campaigns.
