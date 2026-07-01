# Doc Parity — Epic Context

## Original Goal

Replicate Anthropic's "Calendar-Driven Travel State" HTML PRD artifact (~780 lines HTML) in StreamWeaver's Ruby DSL (~160 lines), then make it a true apples-to-apples match — same content, same compact editorial look — and ultimately better: dark mode, visible theme control, canvas interactivity, "Save as doc" local persistence. Then package the technique as a reusable agent skill and seed a blog post.

The strategic point: a Ruby DSL produces these docs at a fraction of the token cost of hand-written React/HTML. That's a Ruby-thinking advantage worth writing about.

## What Exists (Built Before This Epic Started)

- `lib/stream_weaver/components/doc_header.rb` — DocHeader (eyebrow/title/pills) + DocSectionHeader (number/title/id)
- `lib/stream_weaver/adapter/alpinejs.rb` — render_doc_header, render_doc_section_header, DOC_HEADER_CSS, sidebar_toc CSS, render_table, render_mermaid
- `lib/stream_weaver/display_dsl.rb` — doc_header / doc_section_header DSL methods
- `spec/components/doc_header_spec.rb` — 29 examples, passing
- `examples/components/prd_demo.rb` — standalone app (theme: :document), runnable
- `examples/components/prd_dsl.rb` — inner DSL body for canvas-push (no app wrapper)
- Design+content reference: `docs/reference/travel-state-prd.artifact.html` (780 lines, Anthropic artifact)

Note: prd_demo.rb and prd_dsl.rb contain personal travel/location details and are gitignored until sanitized (see story `sanitize-prd-content`).

## Locked Decisions

1. **New dedicated `:doc` theme** ported 1:1 from the artifact CSS — do NOT rework existing `:document` theme.
2. **Everything in one epic** — theme + component fixes + content parity + canvas + skill + blog seed + sanitize.
3. **Light default + visible toggle** — fix mermaid in dark, ship a designed dark variant.

## Root Causes of Current Visual Gaps

- **Too large/inconsistent fonts**: `:document` theme uses 19px base, 1.85 line-height, Crimson Pro serif body, `xl` padding stacked. Artifact: 15px sans, 1.65, serif only for titles.
- **No TOC numbers**: sidebar_toc stores only {id, label}, no CSS counter.
- **Sidebar scrolls away**: `float:left; margin-left:-224px` hack — `position:sticky` doesn't hold in a float layout.
- **Dark default**: app shell always injects AutoMode.inline_script (follows OS prefers-color-scheme). No visible control.
- **Mermaid blank in dark**: two competing dark mechanisms — ThemeSwitcher sets only `.dark` class; mermaid reads `data-sw-theme` exclusively.
- **Table/card styling**: table th/td styles are inline in render_table (CSS overrides lose to specificity). card_header is a plain block div with no badge/meta layout.

## Key Technical Notes

- Table inline styles: must edit render_table directly in alpinejs.rb (~line 1143) — CSS overrides won't work.
- Sticky sidebar load-bearing fix: `align-self: start` on the sidebar in a CSS grid context. Without it, sticky collapses.
- Mermaid dark fix: make ThemeSwitcher also set `document.documentElement.dataset.swTheme` (currently only sets `.dark` class).
- Canvas body: hardcodes `sw-theme-default` at bridge_server.rb:236 — needs parameterization for :doc support.
- prd_demo.rb should load prd_dsl.rb as its body (single content source) once shared-dsl-dedup story is done.

## Story Sequence / Dependencies

Phase 1 (theme foundation — do first, others depend on tokens):
  doc-theme-light → doc-theme-dark → register-doc-theme

Phase 2 (component polish — fan out in parallel after Phase 1):
  toc-numbers, sticky-sidebar, table-caps-blue, card-header-badge-meta, mermaid-dark-fix, theme-toggle-light-default

Phase 3 (content — after Phase 2 visual fixes confirmed):
  prd-content-1to1 → shared-dsl-dedup

Phase 4 (canvas — needs Phase 1 theme):
  canvas-theme-support → save-as-doc-verify

Phase 5+6 (independent — can run any time after Phase 1):
  streamweaver-doc-builder-skill, ruby-vs-react-doc-seed

Phase 7 (last — needs everything confirmed working):
  sanitize-prd-content

## Verification Approach

- Standalone: `ruby examples/components/prd_demo.rb` — read the banner for actual port (NOT 4567 — auto-detects)
- Canvas: `streamweaver panel prd-test` then `streamweaver canvas-push prd-test < examples/components/prd_dsl.rb`
- Visual: side-by-side vs `docs/reference/travel-state-prd.artifact.html` (open locally)
- Scroll test: playwright-cli to verify sidebar stays fixed while scrolling
- Dark mode: toggle + confirm mermaid renders in both modes
