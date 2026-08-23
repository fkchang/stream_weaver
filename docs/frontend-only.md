# Frontend-Only Compatibility

A canvas DSL file gets rendered by StreamWeaver in more places than the live canvas it was written for: `canvas-read` browses it with no app session behind it, and `streamweaver export` writes it out as a static HTML file with no server at all. Same `.rb`, three different runtimes. This doc tells you what survives each one, why, and what changed in the 2026-08-23 fix pass (canvas-safe epic).

Companion reading: `docs/research/frontend-only-matrix.md` is the full ~95-row spike (per-cell repro commands, source line numbers) that this doc summarizes and corrects. Read this doc first; drop into the matrix when you need the exact grep for a specific component.

## The three contexts

| Ctx | Name | What's behind it | Adapter mode | htmx? | Alpine? |
|---|---|---|---|---|---|
| A | Live canvas | `Canvas::BridgeServer` + WebSocket; an agent may be listening on `canvas-wait` | `:websocket` | yes | yes |
| B | canvas-read | `Canvas::Reader`, a render-only viewer with no app session | `:websocket` | yes | yes |
| C | Exported HTML | nothing — a static file | `:http` | no | only if `x-data` is present |

Verdicts used below:

- **WORKS** — full intended function.
- **DEGRADES** — reduced but honest. The user can see that less is on offer (disabled control, visible title, read-only state).
- **SILENTLY-DEAD** — renders, looks interactive, does nothing. The dangerous class: no error, no visual sign, just a click that goes nowhere.
- **BREAKS** — errors, blanks, or visibly wrong output.

Contexts A and B both run the same `:websocket` adapter code, so they usually share a verdict — the difference is that B additionally renders with an `inert:` flag that turns "throws a ReferenceError" into "renders honestly disabled." Where A and B diverge, it's because of that flag, not because of different markup logic.

## Nine mechanisms, in plain language

Everything in the compatibility table below falls out of these nine rules. Learn these and you can predict any row that isn't listed explicitly.

**State lives in Alpine, and only Alpine's own state is portable.** A component that owns its `x-data` (collapsible, tabs, dropdown, copy button, theme toggle, sortable table) behaves identically in all three contexts — it never asked anything outside itself for state. A component that emits a bare `x-model="key"` is betting on an enclosing scope that holds `key`. Context A's container carries only two WebSocket flags, never the pushed app state. Contexts B and C don't even give it an `x-data` wrapper. Bare `x-model` bindings are silently-dead everywhere backend-less — confirmed in-browser, console-clean, no error at all.

**`sendEvent` only exists where `cdn_scripts` defines it.** `window.sendEvent` / `window.getFormState` live inside the websocket init script, which only ships via `adapter.cdn_scripts`. The bridge (A) includes it. The reader (B) deliberately omits it — connecting a WebSocket that will never resolve is worse than not trying — so before the 2026-08-23 fixes, any control calling `sendEvent` directly on B threw `ReferenceError: sendEvent is not defined`. The export (C) never emits it at all; C's `:http` mode doesn't even try.

**`hx-post` renders everywhere; almost nothing serves it.** Most form-ish components (`text_field`, `checkbox`, `select`, `date_field`, and friends) still auto-submit via `hx-post` regardless of context. In A and B, htmx is loaded, so the request fires and 404s (the bridge only routes `/canvas/:name`, `/poll`, `/save-doc`, `/event`; the reader only routes its own browse/export endpoints — neither has `/update`, `/action/*`, or `/form/*`). In C, htmx is never loaded, so the request never fires — no network entry, no console line, nothing. **C is the quietest failure mode of the three**, which is exactly why it's easy to ship an export that looks fine and does nothing.

**Some JS is inlined; some is CDN-referenced — only the inlined kind survives export/CSP.** Anything the adapter writes directly into the page (`sw-mermaid-zoom.js`, `sw-route-tabs.js`, `sw-copy.js`, `sw-slide-nav.js`, `sw-keyboard.js`, `sw-sidebar-toc.js`, the deck JS, Chart.js's own lazy-load wrapper) travels into an export and survives a CSP that blocks external hosts. Anything referenced by `<script src="https://...">` — Alpine itself, Prism, mermaid's ESM module, Google Fonts — dies under a CSP-locked viewer. `--offline` on `export` inlines mermaid's library only, not Alpine or Prism. **This is the CSP finding that matters most:** any component whose interactivity depends on Alpine (tabs, collapsible, dropdown, theme toggle, `x-show`/`x-cloak` panels) goes from DEGRADES to full **BREAKS** in a CSP-locked viewer — `x-cloak` content never un-hides, so it stays invisible forever. Flat, non-Alpine content (headers, cards, tables, static markdown) is untouched; it was never waiting on a CDN script to begin with.

**The Chart.js gate used to key on one class, not the family.** `html_exporter.rb`'s CDN-inclusion check originally tested `is_a?(Components::Chart)` — but every shorthand chart DSL method (`bar_chart`, `line_chart`, `pie_chart`, `sparkline`, `stacked_bar_chart`, `area_chart`, `hbar_chart`, `doughnut_chart`) builds a `ChartBase` subclass, not `Components::Chart` itself. Fixed 2026-08-23 (below).

**`tabs url: true` is more functional in an export than on canvas.** `route_tabs? = component.url && !websocket_mode?`. On canvas (A, B) route tabs degrade to plain client-side tabs and log a warning once per render — to the *agent's* stderr, never shown to the human viewing the page. In an export, `sw-route-tabs.js` is inlined and runs real `pushState` routing. This is intentional, informational (disc-099), and not a bug — but it means the one component that gets *more* capable off the live canvas is worth knowing about if you're diagnosing "why does this behave differently exported."

**Inlined JS still calls server-only routes.** The deck selection engine hardcodes `fetch('/deck/select')`, `/deck/note`, `/deck/submit`, `/deck/generate`, `/deck/refresh`; `local_asset` mints `/sw-asset/<key>/...`; a toast dismiss calls `/toast/dismiss/<id>`. None of these routes exist outside the one server that mounts them. All 404 (A, B) or fail silently (C).

**`AppView`-only scripts never reach canvas or export.** The SSE client and the routing/`popstate` scripts are emitted only by `AppView`. A and B render through `AppContentView`; C renders through `ComponentRenderer.render_html`. Neither ever gets those scripts, so `every`, `stream`, and `route_by` have no client at all in any backend-less context — the initial paint shows and nothing ever updates. Out of scope for this epic; know it going in.

**`getFormState()` reads the DOM, not Alpine.** It walks `document.querySelectorAll('[x-model]')` at button-click time and harvests raw element values. This is *why* plain inputs still deliver data on the live canvas despite the state-binding rule above — it's a DOM read, not a scope read. Before 2026-08-23 it also mishandled grouped checkboxes: assigning `state[key] = el.checked` for every item in a group meant the *last* item in the group silently overwrote the rest, so a `checkbox_group` sent a boolean instead of the selected array. Fixed 2026-08-23 (below).

## What changed 2026-08-23 (canvas-safe epic)

Five defects the spike (disc-093) found are now fixed. Each entry is the honest before/after — what was silently wrong, and exactly what changed.

### 1. Chart export family gate (disc-094)

**Before:** `streamweaver export` shipped Chart.js only when the app used `chart type: ...` directly. Every shorthand — `bar_chart`, `hbar_chart`, `line_chart`, `area_chart`, `sparkline`, `pie_chart`, `doughnut_chart`, `stacked_bar_chart` — built a `ChartBase` subclass that failed the `is_a?(Components::Chart)` check. The exported markup still carried the guarded `x-init="if (typeof Chart !== 'undefined') { new Chart(...) }"`, so nothing threw — you got an empty bordered box, console-silent, that looked like a rendering glitch rather than a missing library.

**After:** `html_exporter.rb:341-350` gates on `components_include?(Components::Chart) || components_include?(Components::ChartBase)` — the whole family, not a name allowlist. A spec builds an anonymous `Class.new(Components::BarChart)` the gate has never seen and proves it still gets Chart.js, so a future chart subclass can't silently join the dead list. Browser-verified: all 9 chart DSL methods render real ink in an exported file served over HTTP.

**Verdict change:** every shorthand chart, export context (C): SILENTLY-DEAD → **WORKS**.

### 2. Reader inert controls (disc-095)

**Before:** `canvas-read` rendered `button` and `radio_group` in `:websocket` mode (for markup parity) but deliberately never shipped `cdn_scripts` — so `sendEvent` was undefined. `button`'s handler is `$el.disabled=true; sendEvent(...)` — the first statement runs, the second throws. The user watched the button visibly grey itself out, as if the click had been accepted, then nothing happened. That's the dangerous shape: a real disabled-state mutation on a call that did nothing.

**After:** the adapter gained an `inert:` construction flag. When set, `button` and `radio_group` render `disabled` (or `aria-disabled` for non-native elements) plus `title="Interactive on live canvas only"`, with no `@click`/`@change` handler emitting `sendEvent` at all — no ReferenceError is possible because nothing calls it. Confirmed live: zero console errors on click, no self-mutation (the control's disabled state is identical before and after the click, because it was set at render time, not click time). Live-canvas markup (real bridge, `inert:` unset) is pinned byte-for-byte unchanged by golden-string specs.

**Verdict change:** `button`, `radio_group`, canvas-read (B): SILENTLY-DEAD (self-disabling, `ReferenceError`) → **DEGRADES** (honestly disabled, zero errors).

### 3. Checkbox array harvest (disc-098, disc-105)

**Before:** `getFormState()`'s checkbox branch did `state[key] = el.checked` for every matching element. A `checkbox_group` renders N checkboxes sharing one `x-model` key — so the harvest silently collapsed the whole group to the *last* item's boolean. Select "apple" and "cherry," harvest `{fruits: true}` (or `false`, depending on which checkbox happened to render last) — never `{fruits: ["apple", "cherry"]}`. No error, no warning; `canvas-wait` received confidently wrong data.

**After:** the harvest branches on `el.closest('.checkbox-group')`: items inside a group accumulate into an array of checked values (in DOM order, not insertion order); a lone checkbox outside a group keeps returning a boolean, untouched. Verified in a real browser: click apple + cherry + a standalone "subscribe" checkbox → `getFormState()` returns `{fruits: ["apple", "cherry"], subscribe: true}`. The same bug existed in `chip_group`'s multi-select mode (disc-105, same DOM-collapse mechanism) and was folded into the canvas-action-parity fix below with the matching selector: `el.closest('.checkbox-group, .sw-chip-group')`.

**Verdict change:** `checkbox_group`, live canvas (A): BREAKS (silently wrong data) → **DEGRADES** (auto-submit `hx-post` still 404s and is still ignored, same as before — but the value now harvests correctly as an array on button click). Contexts B and C are unaffected: `checkbox_group` was never ported to `sendEvent`, so it's still governed by the "hx-post nobody serves" mechanism, not this fix.

### 4. Five sites ported to `sendEvent`, plus a sweep spec (disc-097)

**Before:** only `button` and `radio_group` had ever been made websocket-aware. Five other interactive components still emitted plain `hx-post` with no `websocket_mode?` branch at all: `clickable(action:)`, `menu_item` with an action block, `form` submit buttons, `tag_buttons`, and `chip_group`. Every one of them was silently-dead on the live canvas — a direct asymmetry with `button`, which worked.

**After:** all five now dispatch through `sendEvent`, each shaped to match what the control actually does:

| Component | Event | Payload |
|---|---|---|
| `clickable(action:)` | `action` | `{button: <token>, state: getFormState()}` — same signed token as `button` |
| `menu_item` (block) | `action` | `{button: 'menu_item_N', state: getFormState()}`; menu still closes on dispatch |
| `form` submit | `action` | `{button: 'form-<name>-submit', form: '<name>', values: _form, state: getFormState()}` |
| `tag_buttons` | `change` | `{field: <key>, value: <selected>, state: getFormState()}` — a state change, not a submission, so it mirrors `radio_group` rather than `button` |
| `chip_group` | `change` | `{field: <key>, value: <chip>, state: getFormState()}`, with the disc-105 array fix so `state` carries the full multi-select array |

Each of the five also gained the same inert treatment as #2 above: on canvas-read (B), they render honestly disabled/`aria-disabled` with the same "interactive on live canvas only" title, instead of throwing. `clickable` can't be natively `disabled` (it's a `<div>`), so it uses `aria-disabled` and drops its `tabindex` instead — a focusable element that does nothing would be its own lie.

A coverage spec (`htmx_call_site_sweep_spec.rb`) now inventories *every* `htmx_attrs` call site in the adapter and asserts each one's declared disposition (`:sendEvent` or `:htmx`) matches its actual behavior — so a future component can't silently join the dead list the way these five did. It already caught a real regression once, mid-implementation, when a refactor moved call sites into new helper methods without updating the inventory.

Two things fell out of this work and are tracked, not fixed here:

- **A quoting rule, and one exception.** Author-supplied strings (tag labels, menu item text) now always route through JSON quoting before reaching a JS handler — an apostrophe in a tag label used to produce a JS syntax error, silently killing that specific button. `external_link_button`'s `window.open(url)` call is the one place this rule *isn't* applied, because that line is emitted identically in HTTP mode and canvas mode, and quoting it would change HTTP output — out of scope for an epic that guarantees HTTP-mode bytes don't move (disc-107).
- **`canvas-wait` no longer returns on button clicks only.** Since `tag_buttons` and `chip_group` now dispatch `change` events, `canvas-wait` needs `--event change` or `--any` to catch them — `action`-only waiting (the default) still only catches `button`, `clickable`, `menu_item`, and `form` submit.

**Verdict change:** `clickable(action:)`, `menu_item` (block), `form` submit, `tag_buttons`, live canvas (A): SILENTLY-DEAD → **WORKS**. `chip_group`, live canvas (A): DEGRADES → **WORKS**. All five, canvas-read (B): SILENTLY-DEAD → **DEGRADES**. Export (C) is unaffected — HTTP-mode markup is byte-for-byte unchanged by construction.

### 5. Deck: success-gated confirmation, read-only via `deck_server:` (disc-096)

**Before:** `swDeckSelect` was the most dangerous shape in the whole matrix. It applied the selected class and `aria-checked` **before** calling `fetch('/deck/select')`, with no `.catch`. Wherever `/deck/*` doesn't exist — canvas, canvas-read, export — the fetch 404s (or fails outright) and the failure is swallowed. The user sees a confirmed selection that was never recorded and never reached anything. It's not just dead, it actively lies.

**After:** confirmation is success-gated. Visual/aria state changes only after the POST resolves; a failed request surfaces a console error naming the route and reason, and applies no visual change at all — a card that was already selected stays selected, a click that failed shows nothing. An `aria-busy` state covers the in-flight moment (gating alone would have just replaced a lie with silence). Separately, the whole deck UI (option cards, notes textarea, submit, generate-more, model selector) now renders read-only wherever `/deck/*` genuinely can't exist, gated by a new `deck_server:` construction flag threaded through the adapter and set at 11 call sites: the bridge's live-push, the reader, the exporter, and — this was a second, previously undocumented bug the review caught — all nine `service.rb` mount points. Service mode (`streamweaver serve`) has real HTTP routes but never mounted `/deck/*` either, so it had the identical uncovered lie; it's now honestly read-only too.

One thing this fix does *not* address, filed as its own followup: the deck JS posts to `/deck/*` by absolute path, ignoring the adapter's `url_prefix`. So even a service-mode app that mounted deck routes under `/apps/<id>/deck/*` would still post to the wrong place. Today's fix makes that render read-only, which is honest for current behavior; if decks are ever wanted under `streamweaver serve`, url-prefixing the deck JS is a prerequisite, and only then would service adapters flip `deck_server: true`.

**Verdict change:** `design_deck` option selection, notes, and generate-more, all three backend-less contexts (A, B, C): SILENTLY-DEAD ("and it lies") → **DEGRADES** (honestly read-only). The one context where deck selection still fully works — the real standalone `streamweaver run` server — is unchanged behaviorally except that confirmation now lands slightly after the click (the fix, not a regression).

## Compatibility table

Everything not listed here behaves as in the full matrix (`docs/research/frontend-only-matrix.md`) — unaffected by this fix pass. This table covers the rows that changed, plus the ones people ask about most.

### Inputs

| Component | A live canvas | B canvas-read | C export |
|---|---|---|---|
| `text_field` / `text_area` / `date_field` / `checkbox` / `select` | DEGRADES — value harvested on button click (M9), but the auto-submit `hx-post` still 404s per keystroke/change, unfixed (disc-106) | SILENTLY-DEAD — same 404, no visible sign | SILENTLY-DEAD — `hx-post` present, htmx never loaded, no network activity at all |
| `radio_group` | WORKS — ported to `sendEvent('change')` before this epic | **DEGRADES** — honestly disabled, zero console errors (was SILENTLY-DEAD) | SILENTLY-DEAD — falls back to `hx-post /update` in `:http` mode |
| `checkbox_group` | **DEGRADES** — array harvested correctly on button click (was BREAKS: silently wrong boolean) | SILENTLY-DEAD — not ported to `sendEvent`; unaffected by the harvest fix | SILENTLY-DEAD |
| `chip_group` | **WORKS** — ported to `sendEvent('change')`, array harvest fixed (was DEGRADES) | **DEGRADES** — honestly disabled (was SILENTLY-DEAD) | SILENTLY-DEAD |
| `tag_buttons` | **WORKS** — ported to `sendEvent('change')` (was SILENTLY-DEAD) | **DEGRADES** (was SILENTLY-DEAD) | SILENTLY-DEAD |
| `form` block | **WORKS** — submit ported to `sendEvent('action')` (was SILENTLY-DEAD) | **DEGRADES** (was SILENTLY-DEAD) | SILENTLY-DEAD |

### Buttons and actions

| Component | A live canvas | B canvas-read | C export |
|---|---|---|---|
| `button` (default) | WORKS when an agent is listening on `canvas-wait`; with no listener, click still fires the "✓ Submitted" replacement | **DEGRADES** — honestly disabled, zero errors (was SILENTLY-DEAD, self-disabling) | SILENTLY-DEAD |
| `clickable(action:)` | **WORKS** — ported (was SILENTLY-DEAD) | **DEGRADES**, `aria-disabled` + no `tabindex` (was SILENTLY-DEAD) | SILENTLY-DEAD |
| `menu_item` (action block) | **WORKS** — ported, menu still closes (was SILENTLY-DEAD) | **DEGRADES** (was SILENTLY-DEAD) | SILENTLY-DEAD |
| `external_link_button` | DEGRADES — `window.open` fires; paired submit 404s. Unquoted-URL edge case tracked, not fixed (disc-107) | DEGRADES | DEGRADES |

### Diagrams and charts

| Component | A | B | C |
|---|---|---|---|
| `chart type: ...` (`Components::Chart` directly) | WORKS | WORKS | WORKS (was already immune to the drift) |
| `bar_chart` / `hbar_chart` / `line_chart` / `area_chart` / `sparkline` / `pie_chart` / `doughnut_chart` / `stacked_bar_chart` | WORKS | WORKS | **WORKS** — Chart.js now ships for the whole `ChartBase` family (was SILENTLY-DEAD: empty bordered box, no console error) |
| `mermaid` | WORKS | WORKS | WORKS; `--offline` inlines the library so it survives CSP (except `elk: true`, no global build) |

### Deck and slides

| Component | A | B | C |
|---|---|---|---|
| `slide_container` / `slide` navigation | WORKS (unrelated to the deck fix) | WORKS | WORKS |
| `design_deck` option selection, notes, generate-more | **DEGRADES** — honestly read-only, `/deck/*` doesn't exist here (was SILENTLY-DEAD and lying: optimistic confirmation before an unhandled 404) | **DEGRADES** (same) | **DEGRADES** (same) |
| `design_deck` under a real `streamweaver run` deck server | WORKS unchanged, except confirmation now lands after the POST resolves instead of before it (the fix) | n/a | n/a |
| `design_deck` under `streamweaver serve` (service mode) | **DEGRADES** — read-only, previously-undocumented identical bug, now covered (was SILENTLY-DEAD and lying, same as above) | n/a | n/a |

## The remaining edge: disc-106

Seven `htmx_attrs` call sites still post into routes nothing serves, on canvas: `text_field`, `text_area`, `date_field`, `checkbox`, `select`, `checkbox_group`'s auto-submit, and `external_link_button`. They're less visible than the five fixed in disc-097 because they're state *syncs*, not submissions — the value gets re-harvested correctly by `getFormState()` the next time an action fires, so the user doesn't see missing behavior. But every keystroke or change still fires a debounced `POST /canvas/<session>/update` that 404s, so a live canvas with a text field generates a steady trickle of 404s and htmx console noise that a careful user would notice. Fixing this is a canvas-protocol question (does per-keystroke state sync over the bridge even make sense?), not a rendering one, and is deliberately out of this epic's scope.

## file:// open questions (untested)

These follow from the code but haven't been confirmed in a browser — they're the two remaining unknowns from the original spike, unaffected by the fixes above:

- **Route tabs under `file://`.** Exported `tabs url: true` calls `history.pushState` with a query string. Several browsers throw `SecurityError` for `pushState` on `file://` origins. If it throws, tab switching in a locally-opened export is BREAKS, not the WORKS this doc otherwise reports for exports — nobody has opened one from disk and clicked a tab to confirm either way.
- **`copy_button` clipboard access under `file://`.** `navigator.clipboard` requires a secure context, and whether a `file://` origin counts varies by browser. Untested.

Both are cheap to check by hand (open an export from disk, click a route tab, click a copy button) — nobody has done it yet.

## See also

- `docs/research/frontend-only-matrix.md` — the full row-by-row spike this doc summarizes: per-cell repro commands, exact source lines, and everything not called out as changed above.
- `docs/components_reference.md` — component-level API reference; cross-references this doc where a component's backend-less behavior is non-obvious.
- `llms.txt` — the agent-facing quick reference; see its Detailed Documentation table.
