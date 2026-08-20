# route-tabs — Epic Context

## Origin

Grew out of the audit0802 canvas port (2026-08-03): a dashboard was rebuilt with tabs, which exposed that StreamWeaver tabs are invisible to the URL — no bookmarks, no shared links, no history. A draft "hx-get + hx-push-url" design was adversarially vetted by Codex (session continuation available via .context/codex-session-id) and produced 8 P1 findings; the redesign below dissolves four of them by architecture rather than mitigation.

Full design docs (authoritative, Codex-vetted): `../openspec/changes/add-route-tabs/` (relative to this repo root) — proposal.md, design.md (decisions D1-D8), specs/tab-navigation/spec.md (the scenarios this .feature is derived from), tasks.md. Read design.md before implementing any story.

## Vet status

Codex Sol vet 2026-08-20 (10 findings, all applied): confirmed NO semantic code drift since e414edc — D1-D8 remain valid against current main; line refs below are corrected to current positions. Key clarifications baked in: client init never falls back to the server-rendered index (D2), authority applies at tabs evaluation with no key registry (D8, new), duplicate-key validation scoped to other url: true tabs groups (D5), canvas warning fires once per render pass (D6).

## The Eight Decisions (D1-D8, from design.md)

- D1: Client-side History API, not HTMX GET. Eager panels; click = Alpine switch + pushState (merge into live location.search); popstate re-derives. Zero requests per switch.
- D2: On the client the URL is the single source of truth — x-data derives activeTab from location.search (absent/invalid → 0; the server-rendered index is NEVER a client fallback), so any server-driven container morph self-corrects. Route tabs emit NO hidden sync input.
- D3: On full GET the URL is authoritative for route-tab keys: present+valid → that index; absent/invalid → 0. Never session-sticky.
- D4: Two-stage validation: scalar+integer coercion at param import; range clamp at tabs evaluation. The clamp applies to ALL tabs (strict improvement).
- D5: Reserved/duplicate key validation at build time (app_id, splat, captures, duplicate url: true tabs keys — NOT a general stateful-component check; no registry exists). Broader collisions are a docs caution.
- D6: Canvas/websocket mode: url: ignored → plain client tabs + one warning per render pass. Never break a pushed page.
- D7: url: true + lazy: true raises. Loud, not coerced.
- D8: Authority/coercion applied at tabs evaluation from the request-params snapshot (values + presence) — the component handles its own key; no route-key registry, no prepass. Standalone imports params before rebuild (server.rb:251); service rebuilds after acquiring state (service.rb:975) — evaluation-time application works identically in both.

## Cross-cutting constraints

- Existing tabs without url: must render byte-for-byte unchanged (regression spec exists in spec/canvas/adapter_websocket_spec.rb — keep it green). Precedent commit: e414edc.
- Do NOT touch the per-index callback registrations in Components::Tabs (components.rb ~1489) — consumed by the Opal runtime adapter (adapter/opal.rb), not the HTMX path.
- The canvas-mode signal is the existing `websocket_mode?` predicate (alpinejs.rb:41 as of 2026-08-20); do not invent a new flag.
- The emitted JS helper should follow the file's existing emitted-script pattern (cf. cdn_scripts / websocket init in alpinejs.rb).
- Known pre-existing bug, NOT this epic's job: htmx back-button handler drops the query string (alpinejs.rb:1243 as of 2026-08-20) — tracked as beads stream_weaver-5hd. Route tabs sidestep it via their own popstate handling.
- Related beads: stream_weaver-z02 (tabs ARIA, separate), stream_weaver-pkh (lazy tabs broken on canvas — the deprecate-lazy-post-morph story should reference it).

## File map

- lib/stream_weaver/app.rb ~838-874 — tabs DSL (option, validation, clamp)
- lib/stream_weaver/adapter/alpinejs.rb ~2321 — render_tabs (url branch goes here; eager-branch trigger_attrs shape from e414edc confirmed present); websocket_mode? at :41
- lib/stream_weaver/service.rb ~975-999 — GET /apps/:app_id (rebuilds after acquiring state; needs param seeding per D8)
- lib/stream_weaver/server.rb ~227-251 — standalone GET / (imports params before rebuild at :251; verify composes with coercion)
- spec/canvas/adapter_websocket_spec.rb — existing tabs regression lock lives here
- docs/components_reference.md ~292-313 — Tabs section

## Deferred (do not build)

Lazy server-fetched route tabs (v2, gated on fragments/scoped-swap epic), slug-valued params (?view=findings), ARIA (z02), portfolio/UTF concerns.

## Verification rules (repo-standing)

- Browser verification is MAIN THREAD ONLY with playwright-cli + screenshots (subagent playwright fails; UI parity claims require browser evidence, never curl-only).
- Every test boot: SW_NO_OPEN=1 / PORT env to suppress auto-open, and kill the boot when done.
- Pre-push gate: full rspec, DHH review, docs freshness, AI-slop check (any finding blocks).
