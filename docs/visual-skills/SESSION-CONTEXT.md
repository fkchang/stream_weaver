# Session Context -- Visual Skills Development

## Purpose
This file captures everything needed to resume work after context compaction.
Read this first when continuing this work.

---

## Current Status: Phase 5 COMPLETE, Demo Testing & Fixes DONE, Phase 6 PENDING

### All 15 implementation tasks done -- 1427 tests, 0 failures
### Demo apps tested and fixed -- both rendering correctly

---

## Critical Bug Found & Fixed: CSS/JS Injection Memoization

### The Bug
All visual skills components used `@_var ||=` or `@var = true` memoization on the **adapter instance** to inject CSS/JS once per page. But the adapter is a singleton (`set :adapter, Adapter::AlpineJS.new` in server.rb), so after the first render, all subsequent HTMX morph re-renders skipped CSS/JS injection. This caused:
- No slide navigation (swSlideNav undefined)
- No component styling (no grids, no borders, no colors)
- No Prism.js syntax highlighting
- No Mermaid.js diagram rendering
- No Chart.js charts

### The Fix
Changed **19 injection methods** in `lib/stream_weaver/adapter/alpinejs.rb` from adapter-level memoization to per-view dedup:

**Before** (broken -- adapter instance persists):
```ruby
def inject_slide_nav_js(view)
  @_slide_nav_js_injected ||= begin
    view.script { view.raw(view.safe(File.read(js_path))) }
    true
  end
end
```

**After** (fixed -- view is fresh per render):
```ruby
def inject_slide_nav_js(view)
  return if view.instance_variable_get(:@_slide_nav_js_injected)
  view.instance_variable_set(:@_slide_nav_js_injected, true)
  view.script { view.raw(view.safe(File.read(js_path))) } if File.exist?(js_path)
end
```

### All 19 methods fixed:
1. `inject_keyboard_js` (line ~2661)
2. `inject_deck_css` (line ~3705)
3. `inject_deck_selection_js` (line ~3712)
4. `inject_deck_summary_js` (line ~3795)
5. `inject_generate_more_css` (line ~3827)
6. `inject_generate_more_js` (line ~3834)
7. `inject_deck_polish_css` (line ~4059)
8. `inject_slide_nav_js` (line ~4666)
9. `inject_slide_container_css` (line ~4674)
10. Animation CSS in `render_theme_preset` (line ~2035)
11. Mermaid assets in `render_mermaid` (line ~2111)
12. Pipeline CSS in `render_pipeline` (line ~2274)
13. KPI CSS in `render_kpi_dashboard` (line ~2386)
14. Chart assets in `render_chartjs` (line ~2482)
15. `inject_sidebar_toc_assets` (line ~2859)
16. `inject_callout_css` (line ~2870)
17. `inject_comparison_css` (line ~2877)
18. `inject_prism_cdn` (line ~5509)
19. `inject_helpers_css` (line ~5696)

---

## Other Fixes Applied

### Score Table Key Mismatch
- `render_score_table` expected `score[:value]` but demo used `score[:score]`
- Fix: `value = score[:value] || score[:score] || 0`
- File: `lib/stream_weaver/adapter/alpinejs.rb:1204`

### Duplicate Deck Title
- Page H1 from views.rb AND deck's own H1 both showed the same title
- Fix: Removed `view.h1(class: "sw-deck__title")` from `render_design_deck`
- Updated test in `spec/components/deck/design_deck_spec.rb:286`

### Scroll-to-Top on Slide Change
- Swap mode navigation didn't scroll back to top, leaving user staring at empty space
- Fix: Added `container.scrollIntoView()` for swap mode in `_onNavigate()`
- File: `lib/stream_weaver/assets/js/sw-slide-nav.js:93`

### Stale DeckState Cleanup
- Hundreds of test-generated JSON files in `tmp/deck_state/` causing pre-selected options
- Cleaned up; consider adding to `.gitignore`

---

## What Was Built (Phase 5)

### Wave 1: Foundation
- **T1**: Generate-more spike -- push-to-state validated, 4-state machine discovered
- **T2**: Theme + CSS foundation -- `sw-` prefix convention, auto-mode, CSS custom properties

### Wave 2: Shared Components
- **T3**: Mermaid (zoom/pan, CDN, theme-aware, ELK layout) -- 50 tests
- **T4**: CodeBlock (Prism.js, file header, truncation) + ImageBlock (caption, base64) -- 61 tests
- **T5**: KeyboardShortcuts + SlideContainer (swap + scroll-snap modes) -- 87 tests
- **T6**: Card depth tiers + Table enhancements (backward compat) -- 45 tests

### Wave 3: Deck Core
- **T7**: DesignDeck + DeckSlide + DeckOption (DSL nesting, option grids, ARIA) -- 78 tests
- **T8**: DeckState file-backed store, selection + notes persistence -- 60 tests
- **T9**: DeckSummary, submit gating, run_once! integration -- 35 tests

### Wave 4: Generate-More + Explainer
- **T10**: Generate-more full (4-state machine, request versioning, push-to-state) -- 56 tests
- **T11**: SidebarToc + Callout + Comparison -- 68 tests
- **T12**: Pipeline + KpiDashboard + Chart (Chart.js) -- 91 tests

### Wave 5: Polish
- **T13**: 7 CSS-only helpers + HtmlExporter -- 80 tests
- **T14**: ModelSelector + ConfirmationBar + CloseOverlay -- 46 tests
- **T15**: 5 theme presets + 6 CSS animations -- 104 tests

---

## Demo Apps (TESTED & WORKING)

### Design Deck Demo
- **File**: `examples/visual_skills/design_deck_demo.rb`
- **Scenario**: "API Gateway Architecture Review" -- 4 slides with mermaid + code_block options
- **Run**: `bash -lc 'ruby examples/visual_skills/design_deck_demo.rb'`
- **Status**: Working -- slides render, mermaid diagrams in cards, navigation, option selection, generate-more controls
- **Remaining polish**: Notes textarea contrast on dark theme could be better

### Visual Explainer Demo
- **File**: `examples/visual_skills/explainer_demo.rb`
- **Scenario**: "Diff Review: feature/auth-migration" -- JWT migration code review
- **Run**: `bash -lc 'ruby examples/visual_skills/explainer_demo.rb'`
- **Status**: Working -- all 13 component types rendering correctly
- **Verified components**: hero, prose, pullquote, kpi_dashboard (grid), chart (line + bar), mermaid (full diagram), dir_tree, comparison (side-by-side), code_block (syntax highlighted), pipeline (horizontal flow), callout (all 5 variants with colored backgrounds), score_table, sidebar_toc, flow_arrow, badges

---

## What Needs to Happen Next

### Git Commit
All work is uncommitted. When ready:
- Stage all new/modified files
- Single commit or per-wave commits per user preference

### Phase 6: Documentation & Blog
- Blog post drafts in `docs/visual-skills/blog/`
- Lessons learned update in `docs/visual-skills/lessons-learned/process.md`

### Remaining Polish (Optional)
- Notes textarea contrast on dark theme in deck demo
- Pullquote text is very low contrast on dark theme (barely visible)
- `tmp/deck_state/` should be added to `.gitignore`

---

## Key Files Reference

### Implementation State
| File | Purpose |
|------|---------|
| `docs/visual-skills/implementation/STATE.md` | All 15 tasks DONE |
| `docs/visual-skills/implementation/tasks.md` | Task specifications |
| `docs/visual-skills/implementation/plan.md` | Ralph-loop orchestration plan |
| `docs/visual-skills/implementation/spike-findings.md` | T1 generate-more spike discoveries |
| `docs/visual-skills/PROGRESS.md` | Phase checklist |
| `docs/visual-skills/SESSION-CONTEXT.md` | This file |

### Design Documents
| File | Purpose |
|------|---------|
| `docs/visual-skills/design/architecture.md` | Full architecture (updated with post-review changes) |
| `docs/visual-skills/design/review-synthesis.md` | 3-reviewer reconciliation |
| `docs/visual-skills/design/gemini-review.md` | Push-to-state insight |
| `docs/visual-skills/design/evolution.md` | 5 decision log entries |

### Source Code (New)
| Directory | Contents |
|-----------|----------|
| `lib/stream_weaver/components/mermaid.rb` | Mermaid component |
| `lib/stream_weaver/components/code_block.rb` | CodeBlock component |
| `lib/stream_weaver/components/image_block.rb` | ImageBlock component |
| `lib/stream_weaver/components/keyboard_shortcuts.rb` | KeyboardShortcuts |
| `lib/stream_weaver/components/slide_container.rb` | SlideContainer + Slide |
| `lib/stream_weaver/components/sidebar_toc.rb` | SidebarToc |
| `lib/stream_weaver/components/callout.rb` | Callout (5 variants) |
| `lib/stream_weaver/components/comparison.rb` | Comparison (before/after) |
| `lib/stream_weaver/components/pipeline.rb` | Pipeline step flow |
| `lib/stream_weaver/components/kpi_dashboard.rb` | KPI metrics grid |
| `lib/stream_weaver/components/chart.rb` | Chart.js wrapper |
| `lib/stream_weaver/components/deck/` | All deck components (7 files) |
| `lib/stream_weaver/theme/presets.rb` | 5 theme presets |
| `lib/stream_weaver/theme/auto_mode.rb` | Auto-mode JS |
| `lib/stream_weaver/export/html_exporter.rb` | Self-contained HTML export |
| `lib/stream_weaver/assets/js/` | Custom JS (mermaid zoom, keyboard, slides, sidebar TOC) |

### Test Files
All specs in `spec/` -- run `bash -lc 'bundle exec rspec'` for full suite (1427 tests).

---

## Memory References
- Project memory: `~/.claude/projects/-Users-fkchang-work-rstreamlit-stream-weaver/memory/project_visual_skills.md`
- Port detection memory: StreamWeaver uses `find_available_port` starting at 4567
- Feedback memory: playwright-cli testing approach (subagents failed)
