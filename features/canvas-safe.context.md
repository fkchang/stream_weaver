# canvas-safe — Epic Context

## Origin / lineage

Promoted from spike **disc-093** (2026-08-22): "Which StreamWeaver components work in each backend-less context and how does each degrade?" Findings: docs/research/frontend-only-matrix.md (~95 DSL surfaces, mechanisms M1-M9, per-cell repro commands). Defect marks: disc-094 (chart export allowlist), disc-095 (reader dead controls), disc-096 (deck optimistic UI), disc-097 (htmx-site asymmetry), disc-098 (checkbox_group wrong payload), disc-099 (route-tabs canvas/export inversion — informational, no fix story; the warning-visibility question folds into frontend-only-doc).

Driving need (Forrest, 2026-08-22): docs made via canvas + Save-as-doc must have honest frontend-only behavior; then a concerns doc + progressive-disclosure skill so agents/humans know what plays well.

## The three contexts (fixed vocabulary — use everywhere)

- **A: live canvas** — bridge behind the page; sendEvent → agent via canvas-wait works WHEN cdn_scripts are emitted and an agent listens.
- **B: canvas-read** — render-only reader server; no app session; currently renders :websocket markup WITHOUT bridge cdn_scripts (that mismatch is disc-095).
- **C: exported HTML** — static; htmx never shipped; Alpine CDN-loaded only when x-data present; CSP-locked viewers kill CDN assets and all x-show/x-cloak content vanishes (browser-confirmed) while flat content survives.

## Mechanisms (from the matrix, M1-M9 abridged)

M1: hx-post emitted in all contexts; only 4 of 21 htmx_attrs call sites consult websocket_mode?. M2: sendEvent is defined only by bridge cdn_scripts. M3: Alpine-owned x-data works everywhere; bare x-model has no scope anywhere backend-less (silently-dead, console-clean — browser-confirmed). M4: adapter-inlined JS travels; CDN JS dies under CSP (--offline covers mermaid only). M5: chart CDN gate misses ChartBase subclasses. M6: route_tabs? = url && !websocket_mode? (export more functional than canvas). M7: inlined JS calling server-only /deck/* and /sw-asset/*. M8: SSE + routing scripts are AppView-only. M9: getFormState reads DOM, not Alpine state.

## Cross-cutting constraints

- FIXES BEFORE ADVICE: frontend-only-doc, canvas-safe-skill, compat-matrix-spec depend on the five fix stories landing first.
- http-mode (standalone/service) rendering must be byte-for-byte unchanged in every fix story — the route-tabs epic set the precedent (explicit output-comparison specs, not just existing-specs-green).
- alpinejs.rb is the collision surface: checkbox-group-array, canvas-action-parity, deck-honest-ui all touch it → SERIAL on the main checkout. chart-export-allowlist (html_exporter.rb) and reader-dead-controls (canvas/reader.rb) are disjoint → worktree-parallel.
- Browser/UAT split per /tyrion-conduct: builders check server-provable criteria only; browser criteria stay UNCHECKED with a handoff runbook; the coordinator seals.
- Doc/skill stories get CLEAN-ROOM acceptance (fresh agent, deliverable file only, tasked to BUILD from it).
- Repo hygiene: no /Users paths in committed content; SW_NO_OPEN=1 + kill + lsof-verify every test boot; cli open_browser ignores SW_NO_OPEN (bd stream_weaver-gxfa) — avoid `streamweaver run`/canvas-create paths in tests.
- Comprehensive lifted-from-real-canvas examples need Forrest's picks + a sanitization pass (lesson-017); NOT in this epic's stories — tracked as a followup, the skill ships with purpose-built examples.

## File map (verified current by the spike)

- lib/stream_weaver/html_exporter.rb:341 — components_include?(Components::Chart) gate (disc-094)
- lib/stream_weaver/canvas/reader.rb:683-686 — renders :websocket, omits cdn_scripts (disc-095)
- lib/stream_weaver/adapter/alpinejs.rb:941 getFormState (disc-098); :570/:691/:753/:824 the four websocket_mode? sites; :2565 clickable, :7734 menu_item, :2179 form submit, :1986 tag_buttons, :2055 chip_group (disc-097); :5608-5636 swDeckSelect + deck JS (disc-096)
- Matrix: docs/research/frontend-only-matrix.md — per-cell repro commands; "needs browser confirmation" list at bottom (file:// pushState + clipboard remain open, harness-blocked)
- Skills to link from: the two in-repo skills (streamweaver-visual-companion, streamweaver-doc-builder)

## Deferred / not in scope

Lazy route tabs (stream_weaver-pkh), tabs ARIA (z02), route-tabs naming sweep, lifted-canvas showcase examples (needs human picks + sanitization), file:// manual checks (30-second human task, noted in doc).
