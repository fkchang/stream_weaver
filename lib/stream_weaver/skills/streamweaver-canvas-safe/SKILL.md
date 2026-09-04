---
name: streamweaver-canvas-safe
description: Use before building a canvas doc, pushing a Save-as-doc that will be reopened later, or running `streamweaver export` — tells you which components stay honest with no backend behind them (canvas-read, an exported file) versus which ones need the live bridge or a real server, so the doc you hand someone doesn't quietly stop working the moment it leaves the live canvas
---

# StreamWeaver Canvas-Safe

A canvas doc gets rendered in more places than the live canvas it was written for: `canvas-read` opens it with no app session, `streamweaver export` writes it out as a static file with no server at all. Same `.rb`, three runtimes. This skill is the compact version of that story — read it before you reach for a component you haven't checked, and drop into a reference file only when you're actually about to use one of the components it covers.

**Full source of truth:** `docs/frontend-only.md` (compatibility table + mechanisms) and `docs/research/frontend-only-matrix.md` (the ~95-row long tail with source lines and repro commands). This skill is a shorter, action-oriented cut of both — when in doubt, they win.

## The three contexts

| Ctx | Name | Behind it | htmx? | Alpine? |
|---|---|---|---|---|
| A | Live canvas | `Canvas::BridgeServer` + WebSocket, an agent may be listening on `canvas-wait` | yes | yes |
| B | canvas-read | `Canvas::Reader`, render-only, no app session | yes | yes |
| C | Exported HTML | nothing — a static file | no | only if `x-data` is present |

## Verdict vocabulary

- **WORKS** — full intended function.
- **DEGRADES** — reduced but honest (disabled control, visible title, read-only state) — the user can see less is on offer.
- **SILENTLY-DEAD** — renders, looks interactive, does nothing. No error, no visual sign. The one to design out of a doc before it ships.
- **BREAKS** — errors, blanks, or visibly wrong output.

## Plays well everywhere (WORKS in A, B, and C)

Anything that owns its own state — Alpine `x-data` it never asks an enclosing scope for — or is flat markup with no server dependency. This is the safe backbone for any doc that needs to survive `canvas-read` or an export: `text`, `md`, `header1`–`header6`, `card`/`card_header`/`card_body`, `callout`, `table` (incl. `sortable: true`), `collapsible`/`expandable_card`/`dropdown`, `tabs` (eager, default — **not** `url: true`, see `references/tabs-and-navigation.md`), `sidebar_toc`, `mermaid`, the whole chart family (`chart`, `bar_chart`, `line_chart`, `pie_chart`, `sparkline`, `stacked_bar_chart`, `area_chart`, `hbar_chart`, `doughnut_chart` — fixed 2026-08-23, see `references/charts-and-diagrams.md`), `theme_toggle`/`theme_switcher`/`theme_preset`, `copy_button`, `code_block`, `keyboard_shortcuts` (as a legend), `use_stylesheet`, `doc_header`/`doc_section_header`, `badge`/`status_dot`, and every layout primitive (`columns`, `div`, `section`, `grid`, `vstack`/`hstack`, ...).

**If a doc is built only from this list, it renders identically in a live canvas, `canvas-read`, and an export.** `examples/canvas-safe-showcase.rb` proves it — see below.

## sendEvent-only-on-live-canvas (WORKS in A only)

These dispatch through `window.sendEvent`, which only `Canvas::BridgeServer`'s `cdn_scripts` defines: `button`, `radio_group`, `clickable(action:)`, `menu_item` (action block), `form` submit, `tag_buttons`, `chip_group`. In B (canvas-read) they render honestly `disabled`/`aria-disabled` with an explanatory title — no `ReferenceError`, no self-mutating click. In C (export) htmx never loads, so their `hx-post` fallback never fires either — SILENTLY-DEAD, quiet and invisible. **Use these to build the live-canvas interaction; don't expect them to do anything once the doc is reopened as a saved doc or exported.** Detail + minimal examples: `references/actions-and-buttons.md` and `references/inputs-and-forms.md`. Saving the session **as `.org`** doesn't render them dead — it leaves them out entirely (one `#+STREAMWEAVER_OMITTED: <call>` keyword line each, counted as `omitted` in the save dialog's coverage notice), because a static org document cannot hold a live control. Save as `.rb` when the controls have to come back.

## Needs a real server (`streamweaver run`/`serve` with the routes mounted — not canvas, not canvas-read, not export)

- Per-keystroke sync on `text_field`/`text_area`/`date_field`/`checkbox`/`select`/`checkbox_group` (auto-submit `hx-post /update` — 404s everywhere backend-less; the *value itself* still reaches an agent because `button`'s `getFormState()` harvests the DOM on click, but the field's own auto-submit never fires cleanly). See `references/inputs-and-forms.md`.
- `design_deck` option selection, notes, generate-more — DEGRADES to honestly read-only wherever `deck_server:` isn't set (canvas, canvas-read, export, and `streamweaver serve` alike). See `references/deck.md`.
- `modal` opening (server-state driven — can close client-side, can't open without a live push), `route_by`/`route`/`page`, `every`/`stream` (SSE — `AppView`-only, no client at all backend-less), `resource`/`form_for` (routed CRUD), `endpoint(...)`, `tabs lazy: true` (deprecated — blank panels, not this skill's concern to fix).
- `local_asset` / relative `image_block` src / any `/sw-asset/...` reference — BREAKS everywhere except `--inline-images` on export or a colocated file.

## When to load a reference file

| Building with... | Read |
|---|---|
| `text_field`, `checkbox_group`, `chip_group`, `tag_buttons`, `form` blocks | `references/inputs-and-forms.md` |
| `button`, `clickable`, `menu_item`, submit buttons | `references/actions-and-buttons.md` |
| `mermaid`, `chart`/`bar_chart`/etc. | `references/charts-and-diagrams.md` |
| `tabs`, `collapsible`, `dropdown`, `modal`, `route_by` | `references/tabs-and-navigation.md` |
| `design_deck` | `references/deck.md` |

Each reference file is advice plus a minimal working DSL snippet plus the one gotcha that actually bites — load it only when you're about to use that component, not up front.

## The comprehensive example

`examples/canvas-safe-showcase.rb` is a bare DSL body (`streamweaver-doc: v1`, no `app` wrapper — see `streamweaver-doc-builder` for the shared-body pattern) built entirely from the plays-well-everywhere list above. It was verified to render correctly — no silently-dead component, no missing script pairing — in all three contexts: pushed through the real bridge (websocket adapter, context A), served by `Canvas::Reader` (context B, `SW_NO_OPEN=1`, ephemeral port, killed and `lsof`-verified after), and run through `streamweaver export` (context C). Use it as the starting skeleton for a doc that must survive being saved and reopened later, or exported and handed to someone with no server at all.

It deliberately does **not** include any sendEvent-only component (button, radio_group, ...) — adding one is a live-canvas-only enhancement to layer on top, not part of the guaranteed-everywhere core. See `references/actions-and-buttons.md` for how to add interactivity honestly.

## Known gotchas (cross-cutting, see `docs/frontend-only.md` for the full list)

- **Bare `x-model` with no owning `x-data` is silently-dead everywhere backend-less** — console-clean, no error. Every component above either owns its own `x-data` or uses server-round-trip inputs (which are covered under "needs a real server").
- **`canvas-wait`'s default only catches `action` events** (`button`, `clickable`, `menu_item`, `form` submit). `tag_buttons` and `chip_group` dispatch `change` — pass `--event change` or `--any`.
- **A CSP-locked viewer breaks every Alpine-dependent component in an export**, even ones marked WORKS above (tabs, collapsible, dropdown, theme_toggle) — `x-cloak` content never un-hides. `--offline` on export only inlines mermaid, not Alpine.
