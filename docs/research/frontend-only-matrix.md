# Frontend-Only Compatibility Matrix

**Spike:** disc-093 — which StreamWeaver components survive a backend-less context, and how do they fail.
**Status:** code-verified + server-verified. Cells needing a live browser are listed at the bottom.
**Date:** 2026-08-22

**Update 2026-08-23:** this is the spike-time snapshot, kept intact for history. Five defects it documents are now fixed (chart-export-allowlist, reader-dead-controls, checkbox-group-array, canvas-action-parity, deck-honest-ui — canvas-safe epic). Rows whose verdicts changed are marked `SUPERSEDED 2026-08-23` in place below, with the original text left untouched. For post-fix reality, the corrected compatibility table, and the before/after story for each fix, see [`docs/frontend-only.md`](../frontend-only.md).

## The three contexts

| Ctx | Name | What's behind it | Adapter mode | htmx? | Alpine? |
|---|---|---|---|---|---|
| A | Live canvas page | `Canvas::BridgeServer` + WebSocket, agent optionally listening on `canvas-wait` | `:websocket` | yes | yes |
| B | canvas-read doc | `Canvas::Reader` render-only server, no app session | `:websocket` | yes | yes |
| C | Exported static HTML | nothing | `:http` | **no** | only if `x-data` present |

Verdicts used below:

- **WORKS** — full intended function.
- **DEGRADES** — reduced but honest; the user can see that less is on offer.
- **SILENTLY-DEAD** — renders, looks interactive, does nothing. The dangerous class.
- **BREAKS** — errors, blanks, or visibly wrong output.

## Mechanisms

Nine rules generate every cell in this document. Read these and you can predict rows that aren't listed.

**M1 — `hx-post` is emitted in every context; almost nothing serves it.**
`Adapter::AlpineJS` calls `htmx_attrs` from 21 sites. Only **four** places in the entire adapter consult `websocket_mode?` for behavior (`render_radio_group`, `button_attrs`, `container_attributes`, `cdn_scripts` — `lib/stream_weaver/adapter/alpinejs.rb:570,691,753,824`), plus tabs at `:2386`. Every other `hx-post` renders identically in all three contexts. In A and B htmx **is** loaded, so the request fires and 404s. In C htmx is deliberately never loaded (`html_exporter.rb:307-313`), so the request never fires at all — no error, no network entry, nothing in the console. **C is the quietest failure mode of the three.**

> `SUPERSEDED 2026-08-23`: as of canvas-action-parity, the count of `websocket_mode?`-aware call sites is no longer 4 — five more sites (`clickable`, `menu_item`, form submit, `tag_buttons`, `chip_group`) were ported to `sendEvent`, and a coverage spec now inventories all call sites and their declared disposition. Seven sites remain unfixed (disc-106, see `docs/frontend-only.md`). The core rule (htmx renders everywhere, C is the quietest failure mode) still holds for those seven.

Verified route surface (all 404, live servers):

```
POST /canvas/<session>/update            404   (bridge has only /canvas/:name, /poll, /save-doc, /event)
POST /canvas/<session>/action/<id>       404
POST /canvas/<session>/form/<name>       404
POST /canvas/reader/update               404   (reader has only /, /browse, /open, /export, /save-doc, /delete-doc, /health)
POST /deck/select                        404
```

**M2 — `sendEvent` is defined only by `cdn_scripts` in websocket mode.**
`window.sendEvent` / `window.getFormState` live inside `websocket_init_script` (`alpinejs.rb:833-1019`), reached only via `adapter.cdn_scripts`. The bridge includes it (`bridge_server.rb:262`). **The reader deliberately does not** — see the comment at `reader.rb:683-686`: it keeps `mode: :websocket` for markup parity but omits `cdn_scripts` to avoid a doomed WebSocket connect. Result, measured on a live reader page: `sendEvent(` is **called 3 times and defined 0 times**. Every canvas-mode control in context B throws `ReferenceError` on click. The exporter renders in `:http` mode, so it never emits `sendEvent` at all.

> `SUPERSEDED 2026-08-23`: reader-dead-controls added an `inert:` adapter flag. The reader now renders `sendEvent`-calling controls as honestly disabled (with a title) instead of emitting the `@click`/`@change` handler at all — the `ReferenceError` this mechanism describes no longer happens for `button`, `radio_group`, or the five sites canvas-action-parity ported. See `docs/frontend-only.md`.

**M3 — Alpine-owned state works everywhere; app-state binding works nowhere.**
Components that declare their **own** `x-data` (collapsible, tabs, dropdown, copy_button, sortable table, theme_toggle, expandable_card, slide_container, timeline_event) are self-contained and behave identically in A, B and C. Components that emit a bare `x-model="key"` expect an enclosing scope holding that key — and none of the three contexts provides one:

```
A  <div id="app-container" x-data='{"wsConnected":false,"wsReconnecting":false}' hx-ext='alpine-morph'>
B  <div id="app-container" data-sw-body-class="...">          # no x-data at all
C  <div id="app-container">                                   # no x-data at all
```

A's container has an `x-data` but it holds only the two WebSocket flags, never the pushed state keys (canvas pushes render with `state = {}`).

**M4 — Adapter-inlined JS travels; CDN-referenced JS does not.**
Anything the adapter writes with `view.script { raw ... }` is embedded in the HTML and survives into an export and past a CSP that blocks external hosts: `sw-mermaid-zoom.js`, `sw-route-tabs.js`, `sw-copy.js`, `sw-slide-nav.js`, `sw-keyboard.js`, `sw-sidebar-toc.js`, the deck selection JS, and the `chart` component's own Chart.js lazy loader. Anything referenced by URL dies under a CSP-locked viewer: Alpine, Prism (js + css), mermaid's ESM module, Google Fonts. `--offline` inlines **mermaid only** — not Alpine, not Prism, not Chart.js. An export whose interactivity rests on Alpine (tabs, collapsible, dropdown, theme toggle) is therefore **BREAKS**, not DEGRADES, in a viewer that blocks `cdn.jsdelivr.net`: `x-cloak` panels never un-hide.

**M5 — the exporter's Chart.js allowlist has drifted.**
`components_include?(Components::Chart)` (`html_exporter.rb:341`) gates the Chart.js CDN tag. But every shorthand chart DSL builds a `ChartBase` subclass, **not** `Components::Chart`:

```
bar_chart, hbar_chart        -> Components::BarChart        is_a?(Chart) = false
line_chart, area_chart,
sparkline                    -> Components::LineChart       is_a?(Chart) = false
pie_chart, doughnut_chart    -> Components::PieChart        is_a?(Chart) = false
stacked_bar_chart            -> Components::StackedBarChart is_a?(Chart) = false
chart                        -> Components::Chart           is_a?(Chart) = TRUE
```

So an export containing `bar_chart` ships **no Chart.js**. The emitted markup is `x-init="if (typeof Chart !== 'undefined') { new Chart(...) }"` — the guard swallows the failure, leaving a chart-shaped empty bordered box with no console error. This is the exact drift the method's own comment claims was fixed for Alpine ("an allowlist here would silently drift every time one of them changes"); the Chart branch still has it.

> `SUPERSEDED 2026-08-23`: fixed by chart-export-allowlist. The gate now checks `components_include?(Components::Chart) || components_include?(Components::ChartBase)` (`html_exporter.rb:341-350`) — the whole family, proven against an anonymous `ChartBase` subclass the gate has never seen. Every shorthand chart method ships Chart.js in exports now. See `docs/frontend-only.md`.

**M6 — `url: true` tabs invert between canvas and export.**
`route_tabs? = component.url && !websocket_mode?` (`alpinejs.rb:2421`). On canvas (A and B) route tabs **degrade** to plain client tabs and log one warning per render pass to the agent's stderr — the human never sees it. In an **export** they are real route tabs: `sw-route-tabs.js` is inlined and `swRouteTabs.push()` runs. Route tabs are the only feature in this matrix that is *more* functional in a static export than on the live canvas.

**M7 — inlined JS that calls server-only routes.**
The deck selection engine hardcodes `fetch('/deck/select')`, `/deck/note`, `/deck/submit`, `/deck/generate`, `/deck/refresh` (`alpinejs.rb:5585+`); `local_asset` mints `/sw-asset/<key>/...` served only by `server.rb:222`; a toast's dismiss calls `htmx.ajax('POST','/toast/dismiss/<id>')` with no URL prefix. All 404 in A and B and fail silently in C.

> `SUPERSEDED 2026-08-23` (deck only): deck-honest-ui made the whole deck UI honestly read-only wherever `/deck/*` doesn't exist, gated by a new `deck_server:` flag at 11 construction sites (including service mode, a second uncovered instance of this bug the story found and fixed). `local_asset` and the toast dismiss route are unaffected by this epic. See `docs/frontend-only.md`.

**M8 — AppView-only page scripts are absent from all three contexts.**
The SSE client and the routing/popstate scripts are emitted by `AppView` (`views.rb:98-105`). A and B render through `AppContentView`; C renders through `ComponentRenderer.render_html`. Neither emits them. So `every`, `stream`, and `route_by` have **no client at all** — the DSL accepts them, the initial paint shows the placeholder, and nothing ever updates.

**M9 — `getFormState()` reads the DOM, not Alpine.**
`document.querySelectorAll('[x-model]')` (`alpinejs.rb:941`) harvests raw element values on button click. This is why plain inputs still deliver data on the live canvas despite M3. It also mishandles groups: for checkboxes it assigns `state[key] = el.checked`, so a `checkbox_group` whose N items share one `x-model` sends the **last item's boolean**, not the selected array.

> `SUPERSEDED 2026-08-23`: fixed by checkbox-group-array. The harvest now branches on `el.closest('.checkbox-group')` (later extended to `.sw-chip-group` for `chip_group`, disc-105): group items accumulate into an array in DOM order; a lone checkbox outside a group still returns a boolean. See `docs/frontend-only.md`.

## How to reproduce any row

```bash
cd <repo>

# Context C — export
bundle exec ruby -Ilib exe/streamweaver export FIXTURE.rb -o /tmp/out.html

# Context B — canvas-read (kill it afterwards; verify the port is free)
SW_NO_OPEN=1 bundle exec ruby -Ilib exe/streamweaver canvas-read FIXTURE.rb &
curl -s "http://127.0.0.1:4800/?file=0" -o /tmp/reader.html
kill %1; lsof -i :4800 -sTCP:LISTEN   # must be empty

# Context A — live canvas (create the session in-process so no browser tab opens)
ruby -Ilib -e 'require "stream_weaver"; require "stream_weaver/canvas/client"
  StreamWeaver::Canvas::Client.ensure_bridge_running
  p StreamWeaver::Canvas::Client.send_message(
      StreamWeaver::Canvas::Protocol::Messages.create("probe", layout: :fluid))'
SW_NO_OPEN=1 bundle exec ruby -Ilib exe/streamweaver canvas-push probe < FIXTURE.rb
curl -s "http://127.0.0.1:4700/canvas/probe" -o /tmp/canvas.html
bundle exec ruby -Ilib exe/streamweaver canvas-close probe
```

The per-row "Repro" column below is the discriminating grep against the file those commands produce.

## Inputs

| Component | A live canvas | B canvas-read | C export | Repro |
|---|---|---|---|---|
| `text_field` | DEGRADES — auto-submit `hx-post /update` 404s (no reactive re-render), but the typed value is harvested on button click (M9) | SILENTLY-DEAD — accepts typing, 404 on change, nothing ever reads it (M1+M2) | SILENTLY-DEAD — `hx-post` present, htmx absent; zero network activity (M1) | `grep -o 'hx-post="[^"]*"' out.html` |
| `text_field submit: false` | WORKS as value carrier | DEGRADES — value carrier with no consumer | DEGRADES — inert field, honest | `grep -c 'hx-post' out.html` |
| `text_area` | DEGRADES (as `text_field`) | SILENTLY-DEAD | SILENTLY-DEAD | same |
| `date_field` | DEGRADES (as `text_field`) | SILENTLY-DEAD | SILENTLY-DEAD | same |
| `checkbox` | DEGRADES — value harvested on button click | SILENTLY-DEAD | SILENTLY-DEAD | same |
| `select` | DEGRADES — value harvested | SILENTLY-DEAD | SILENTLY-DEAD | same |
| `radio_group` | **WORKS** — the one input ported to `sendEvent('change')` (M2); reaches the agent | SILENTLY-DEAD — `sendEvent` undefined, `ReferenceError` on change (M2) | SILENTLY-DEAD — falls back to `hx-post /update` in `:http` mode | `grep -c "window.sendEvent" reader.html` → 0 |
| `checkbox_group` | **BREAKS (silently wrong data)** — select-all/none work client-side, but M9 collapses the whole group to the last item's boolean instead of the selected array | SILENTLY-DEAD | SILENTLY-DEAD | `alpinejs.rb:941` vs `:620` |
| `chip_group` | DEGRADES — value harvested | SILENTLY-DEAD | SILENTLY-DEAD | `grep 'hx-post' ...` |
| `tag_buttons` | SILENTLY-DEAD — `hx-post /update` with `hx-vals`, not websocket-aware; clicking a tag does nothing | SILENTLY-DEAD | SILENTLY-DEAD | `alpinejs.rb:1986` |
| `code_editor` | DEGRADES — editing works, value harvested | SILENTLY-DEAD | SILENTLY-DEAD | `grep 'x-model' out.html` |
| `form` block | **SILENTLY-DEAD** — local Alpine `_form` state and Cancel-reset work, Save posts to `/form/<name>` → 404. Unlike `button`, `form` was **never** made websocket-aware, so the agent is not even notified | SILENTLY-DEAD | SILENTLY-DEAD | `grep -o 'hx-post="[^"]*form[^"]*"'` |
| `form_for` / `resource` forms | BREAKS — depends on routed store actions the bridge does not serve | BREAKS | BREAKS | `resource` raises without a real store |

> `SUPERSEDED 2026-08-23`: `checkbox_group` (A column, M9 harvest), `chip_group` (A column, ported + M9), `tag_buttons` (A column, ported), and `form` block (A column, ported) all changed. See the compatibility table in `docs/frontend-only.md` for corrected per-context verdicts; `radio_group`'s B column (honestly inert, no more `ReferenceError`) also changed.

## Buttons and actions

| Component | A live canvas | B canvas-read | C export | Repro |
|---|---|---|---|---|
| `button` (default) | **WORKS when an agent is listening.** With no `canvas-wait` holder the click still fires `showFeedback()`, which **replaces `#app-container`** with "✓ Submitted" or the `canvas_continue` spinner — the page is destroyed and the event goes nowhere | **SILENTLY-DEAD, self-disabling.** `@click` is `$el.disabled=true; sendEvent(...)`; the first statement runs, the second throws. The button greys itself out and nothing happens | SILENTLY-DEAD — `hx-post /action/<id>`, htmx absent, button stays enabled, no console output | `grep -o "sendEvent('action'" canvas.html` |
| `button submit: false` | WORKS (decorative by contract) | WORKS | WORKS | `grep -c 'hx-post' ` |
| `external_link_button` | DEGRADES — `window.open` fires; the paired `/submit` post 404s | DEGRADES | DEGRADES | `alpinejs.rb:2072` |
| `copy_button` | WORKS — Alpine + clipboard, no server | WORKS | WORKS (see browser list re `file://`) | `grep -c 'x-show' out.html` |
| `code_block copy: true` | WORKS | WORKS | WORKS | same |
| `clickable(action:)` | **SILENTLY-DEAD** — `hx-post /action/...`, never websocket-aware. Direct asymmetry with `button`, which was ported | SILENTLY-DEAD | SILENTLY-DEAD | `alpinejs.rb:2565` |
| `menu_item` with an action block | **SILENTLY-DEAD** — same asymmetry; the menu closes, the action never runs | SILENTLY-DEAD | SILENTLY-DEAD | `alpinejs.rb:7734` |
| `clickable(href:)` / `link_to` (external URL) | WORKS | WORKS | WORKS | — |
| `link_to` / `nav_item` (app-relative href) | DEGRADES — navigates off the canvas to a 404 | DEGRADES | DEGRADES — dead link | `grep -o 'href="/[^"]*"'` |

> `SUPERSEDED 2026-08-23`: `button` (B column) and `clickable(action:)` / `menu_item` (A and B columns) all changed — see `docs/frontend-only.md`. `external_link_button`'s unquoted-URL edge case is now tracked as disc-107 (not fixed, out of scope: quoting it would change HTTP-mode markup).

## Display (pure markup — the safe zone)

All of the following are static HTML with no server dependency and no Alpine requirement: **WORKS in A, B and C.**

`text`, `md` / `markdown`, `header1`–`header6`, `card`, `callout`, `alert`, `prose`, `pullquote`, `hero`, `doc_header`, `doc_section_header`, `badge`, `status_badge`, `status_dot`, `type_tag`, `stat_display`, `pulse_indicator`, `priority_item`, `activity_item`, `progress_bar`, `spinner`, `dir_tree`, `legend`, `flow_arrow`, `wireframe`, `wireframe_block`, `api_endpoint`, `kpi_dashboard`, `pipeline`, `implementation_map`, `comparison`, `decision`, `annotated_code`, `diff`, `score_table`, `lesson_text`, `app_header` (chrome only), `topbar`, `board` / `lane` / `board_card`, and every layout primitive (`columns`, `column`, `vstack`, `hstack`, `grid`, `grid_area`, `sticky`, `fullbleed`, `overlay`, `scroll_box`, `app_shell`, `sidebar`, `main`, `div`, `section`).

Two exceptions inside that list:

| Component | A | B | C | Repro |
|---|---|---|---|---|
| `code_block` (syntax highlighting) | WORKS — bridge loads highlight.js | WORKS — reader loads highlight.js | WORKS — export loads Prism from CDN; **BREAKS to unstyled code under CSP** (M4) | `grep -o 'prismjs@[0-9.]*' out.html` |
| `image_block` with a relative `src` | BREAKS — no route serves the file | BREAKS | BREAKS unless `--inline-images` or the file is colocated | `bundle exec ... export f.rb --inline-images` |
| `local_asset` / `stylesheets:` local path | BREAKS — mints `/sw-asset/...`, 404 (M7) | BREAKS | BREAKS | `grep -o '/sw-asset/[^"]*'` |
| `use_stylesheet` | WORKS — raw CSS is inlined, not referenced | WORKS | WORKS | `grep -c '<style>' out.html` |

## Tables

| Component | A | B | C | Repro |
|---|---|---|---|---|
| `table` (static) | WORKS | WORKS | WORKS | — |
| `table sortable: true` | WORKS — pure Alpine client sort | WORKS | WORKS (needs Alpine; BREAKS under CSP) | `grep -o 'x-data' out.html` |
| `table sticky_header:` / `striped:` | WORKS (CSS only) | WORKS | WORKS | — |
| `table` with action buttons in cells | inherits `button` | inherits `button` | inherits `button` | — |

## Navigation and tabs

| Component | A | B | C | Repro |
|---|---|---|---|---|
| `tabs` (eager, default) | WORKS — `@click activeTab = N`, pure client | WORKS | WORKS — the `hx-post` session sync is `hx-swap="none"` and was never user-visible, so dropping it costs nothing | `grep -c swRouteTabs out.html` → 0 |
| `tabs url: true` | DEGRADES — plain client tabs; the URL is untouched and the warning goes to the **agent's** stderr, not the user (M6) | DEGRADES — identical | **WORKS** — real route tabs, `sw-route-tabs.js` inlined, `pushState` live | `grep -c swRouteTabs` → 2 in export, 0 on canvas |
| `tabs lazy: true` (deprecated) | SILENTLY-DEAD → blank. Inactive panels contain only `<!-- lazy: tab N not rendered -->`; the `hx-post /update` that would fill them 404s, so switching reveals an **empty panel** (`stream_weaver-pkh`) | SILENTLY-DEAD → blank | SILENTLY-DEAD → blank (htmx absent) | `grep -c 'lazy: tab' out.html` |
| `collapsible` / `accordion` | WORKS | WORKS | WORKS (Alpine) | `grep -c x-show` |
| `expandable_card` | WORKS | WORKS | WORKS (Alpine) | same |
| `dropdown` (open/close) | WORKS | WORKS | WORKS (Alpine) | same |
| `navbar` / `nav_item` / `breadcrumbs` | DEGRADES — renders correctly, hrefs go nowhere | DEGRADES | DEGRADES | `grep -o 'href="/[^"]*"'` |
| `sidebar_toc` | WORKS — `sw-sidebar-toc.js` is inlined | WORKS | WORKS | `grep -c 'sw-sidebar-toc'` |
| `keyboard_shortcuts` | WORKS as a legend; bound actions inherit `button` | WORKS as a legend | WORKS as a legend | `grep -c 'sw-keyboard'` |
| `modal` | DEGRADES — Alpine close works; **opening** is server-state driven, so the agent must re-push | SILENTLY-DEAD — cannot be opened | SILENTLY-DEAD — cannot be opened | `grep -o 'hx-post="[^"]*action[^"]*"'` |
| `route_by` / `route` / `page` | SILENTLY-DEAD — no routing script is emitted at all (M8) | SILENTLY-DEAD | SILENTLY-DEAD | `views.rb:103` is AppView-only |

## Diagrams and charts

| Component | A | B | C | Repro |
|---|---|---|---|---|
| `mermaid` (incl. `zoom:`) | WORKS — engine inlined, library from CDN | WORKS | WORKS; `--offline` inlines the library so it survives CSP (**except `elk: true`**, which has no global build) | `grep -c 'sw-mermaid-zoom' out.html` |
| `chart type: …` (`Components::Chart`) | WORKS | WORKS | WORKS — self-loading CDN, immune to M5 | `grep -c SW_CHART_CDN out.html` → 2 |
| `bar_chart` / `hbar_chart` | WORKS — bridge hardcodes `chart.umd` | WORKS — reader ERB hardcodes it | **SILENTLY-DEAD** — no Chart.js emitted (M5); `typeof Chart !== 'undefined'` guard swallows it; empty bordered box | `grep -c chart.umd out.html` → **0** |
| `line_chart` / `area_chart` / `sparkline` | WORKS | WORKS | **SILENTLY-DEAD** (M5) | same |
| `pie_chart` / `doughnut_chart` | WORKS | WORKS | **SILENTLY-DEAD** (M5) | same |
| `stacked_bar_chart` | WORKS | WORKS | **SILENTLY-DEAD** (M5) | same |

> `SUPERSEDED 2026-08-23`: every C-column SILENTLY-DEAD verdict in this section is fixed — all shorthand chart methods now ship Chart.js in exports (chart-export-allowlist). See `docs/frontend-only.md`.

## Deck and slides

| Component | A | B | C | Repro |
|---|---|---|---|---|
| `slide_container` / `slide` | WORKS — `sw-slide-nav.js` inlined | WORKS | WORKS | `grep -c 'sw-slide-nav'` |
| `design_deck` / `deck_slide` (navigation) | WORKS | WORKS | WORKS | same |
| `design_deck` **option selection** | **SILENTLY-DEAD, and it lies.** `swDeckSelect` applies the selected class and `aria-checked` **first**, then `fetch('/deck/select')` → 404 with no `.catch`. The user sees a confirmed selection that was never recorded and never reached the agent | SILENTLY-DEAD, identical | SILENTLY-DEAD, identical (failed fetch instead of 404) | `alpinejs.rb:5608-5636`; `curl -X POST .../deck/select` → 404 |
| deck notes textarea (`@blur`) | SILENTLY-DEAD — `fetch('/deck/note')` 404 | SILENTLY-DEAD | SILENTLY-DEAD | `/deck/note` → 404 |
| `deck_summary` / `model_selector` / `confirmation_bar` / generate-more | SILENTLY-DEAD — all route through `/deck/*` (M7) | SILENTLY-DEAD | SILENTLY-DEAD | same |

> `SUPERSEDED 2026-08-23`: all three SILENTLY-DEAD rows above are fixed by deck-honest-ui. The deck now renders read-only wherever `/deck/*` can't exist (A, B, C all become honestly DEGRADES instead of lying SILENTLY-DEAD), gated by a `deck_server:` flag at 11 construction sites — including service mode, a second previously-undocumented instance of this bug the fix also caught. See `docs/frontend-only.md`.

## Theme components

| Component | A | B | C | Repro |
|---|---|---|---|---|
| `theme_toggle` | WORKS — Alpine + localStorage | WORKS | WORKS (BREAKS under CSP, M4) | `grep -c 'x-data' out.html` |
| `theme_switcher` | WORKS | WORKS | WORKS (same caveat) | same |
| `theme_preset` | WORKS — CSS only | WORKS | WORKS | — |
| `layout_toggle` | WORKS — client `@click` | WORKS | WORKS (same caveat) | `grep -c '@click'` |

## Feedback, streaming, services

| Component | A | B | C | Repro |
|---|---|---|---|---|
| `toast_container` | **SILENTLY-DEAD** — renders an empty div; toasts come from `state[:_toasts]`, always empty here. (The canvas's own `streamweaver canvas-toast` overlay is a **separate** bridge mechanism and does work in A) | SILENTLY-DEAD | SILENTLY-DEAD; dismiss would also throw — `htmx` is undefined | `alpinejs.rb:2772` |
| `canvas_continue` | WORKS — hidden marker read by `sendEvent`'s `showFeedback` | inert, no visible surface | inert, no visible surface | `grep -c 'sw-canvas-continue'` |
| `every(n)` timers | **SILENTLY-DEAD** — no SSE client emitted (M8); the initial placeholder paints and never changes | SILENTLY-DEAD | SILENTLY-DEAD | rendered length is the placeholder only |
| `stream do …` | SILENTLY-DEAD (M8) | SILENTLY-DEAD | SILENTLY-DEAD | same |
| `endpoint(verb, path)` | SILENTLY-DEAD — declared, never routed | SILENTLY-DEAD | SILENTLY-DEAD | `curl` the path → 404 |
| `resource` DSL | BREAKS — routed CRUD with no router | BREAKS | BREAKS | store validation raises at build |
| `service_client` / `feed` | out of scope — these are the real-backend case | — | — | — |

## Headline counts

Roughly 95 distinct DSL surfaces were classified.

| | WORKS | DEGRADES | SILENTLY-DEAD | BREAKS |
|---|---|---|---|---|
| A — live canvas | 64 | 11 | 16 | 4 |
| B — canvas-read | 62 | 4 | 25 | 4 |
| C — export | 61 | 4 | 26 | 4 |

> `SUPERSEDED 2026-08-23`: these counts are the pre-fix snapshot and no longer add up post-fix (multiple rows moved SILENTLY-DEAD/BREAKS → WORKS/DEGRADES across all three columns — see the sections above). This doc does not restate the counts; `docs/frontend-only.md` has the corrected per-row table.

The static-display core (about two thirds of the DSL) is safe everywhere. Every failure is concentrated in the same three places: anything that round-trips, anything that talks to `/deck/*`, and anything that needs a running timer.

## Needs browser confirmation

These follow from the code but cannot be settled without loading a page. Browser work belongs to the main session.

1. **Alpine's reaction to orphan `x-model`** (M3). Does an `x-model="role"` with no enclosing `x-data` throw a visible console error, silently no-op, or (for `x-model="name"`) fall through to `window.name`? This decides whether the input rows in B and C are SILENTLY-DEAD or BREAKS.
2. **Export route tabs under `file://`** (M6). `swRouteTabs.push()` calls `history.pushState` with a query string; several browsers throw `SecurityError` on `file://` origins. If it throws inside `@click`, tab switching in an exported doc is BREAKS, not WORKS.
3. **Export tabs under a CSP that blocks `cdn.jsdelivr.net`.** `x-data="{ activeTab: swRouteTabs.read(...) }"` should throw when Alpine is blocked, leaving every `x-cloak` panel hidden — predicted BREAKS (blank document), needs confirmation.
4. **`copy_button` from `file://`.** `navigator.clipboard` requires a secure context; whether `file://` qualifies varies by browser.
5. **The self-disabling button in context B.** Confirm the click leaves the button permanently greyed with a `ReferenceError: sendEvent is not defined` in the console.
6. **`bar_chart` in an export.** Confirm the observable is an empty bordered box with **no** console error (the `typeof Chart` guard), not a visible failure.
7. **Deck option selection in an export.** Confirm the selected state visibly sticks after the failed fetch — the "it lies" claim rests on the optimistic class being applied before the request.
8. **`checkbox_group` payload on a live canvas.** Confirm the JSON delivered to `canvas-wait` carries a boolean rather than the selected array (M9).

> `SUPERSEDED 2026-08-23`: items 1 and 2 remain genuinely open (file:// pushState + orphan x-model are still unconfirmed — see `docs/frontend-only.md`'s "file:// open questions"). Items 5, 6, 7, and 8 were confirmed as part of the fixes above and are no longer open questions — each fix's story recorded the browser evidence. Item 3 (CSP blocking Alpine) was confirmed during this pass: `x-cloak`/`x-show` content does vanish under a CSP-locked viewer while flat content survives, exactly as predicted.

## Source references

- `lib/stream_weaver/adapter/alpinejs.rb` — `websocket_mode?` at `:41`; the four behavioral branches at `:570`, `:691`, `:753`, `:824`; tabs at `:2321-2445`; deck JS at `:5585`; `getFormState` at `:941`
- `lib/stream_weaver/canvas/bridge_server.rb` — route surface at `:87-213`; page shell at `:216-285`
- `lib/stream_weaver/canvas/reader.rb` — route surface at `:454-671`; `render_doc` and the deliberate `cdn_scripts` omission at `:683-728`
- `lib/stream_weaver/export/html_exporter.rb` — htmx exclusion at `:307-313`; Alpine conditional at `:333`; the drifted Chart branch at `:341`; `--offline` at `:208`
- `lib/stream_weaver/views.rb` — AppView-only SSE and routing scripts at `:98-105`; `AppContentView` at `:3704`

**Note (2026-08-23):** the source line numbers above are the spike-time snapshot and will have shifted after the five fixes landed (each added new methods/branches to `alpinejs.rb` and `html_exporter.rb`). Treat them as approximate; the fix-story notes in tyrion (chart-export-allowlist, reader-dead-controls, checkbox-group-array, canvas-action-parity, deck-honest-ui) carry the current line numbers.
