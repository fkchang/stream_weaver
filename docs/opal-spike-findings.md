# Opal Compatibility Spike Findings

**Spike date:** 2026-04-29
**Opal version:** 1.8.2
**Ruby version:** 3.3.5

## Summary

All 7 candidate files compile cleanly under Opal when missing-require errors are suppressed (syntax-only pass). Two files have `require` statements for standard library modules unavailable in Opal. These are fixable by conditionally guarding the requires or replacing the calls. There are no fundamental syntax incompatibilities in the target files.

---

## Files and Results

### Files that compiled cleanly (no issues at all)

| File | Result |
|---|---|
| `lib/stream_weaver/version.rb` | OK |
| `lib/stream_weaver/utils.rb` | OK |
| `lib/stream_weaver/theme.rb` | OK |
| `lib/stream_weaver/components.rb` | OK |
| `lib/stream_weaver/adapter/base.rb` | OK |

### Files with missing-require issues (fixable)

| File | Missing require | Impact |
|---|---|---|
| `lib/stream_weaver/display_dsl.rb` | `require 'digest/md5'` | Inside `DisplayDSL#button` at runtime — for generating stable button IDs |
| `lib/stream_weaver/app.rb` | `require 'digest'`, `require 'set'` | `digest` for `Digest::MD5` in `App#button`; `set` for `@transient_keys = Set.new` |

**Note:** `set`, `json`, `cgi`, `base64`, and `ostruct` ARE available in Opal's stdlib. Only `digest` and `digest/md5` are missing from Opal.

**All 7 files pass Opal syntax compilation when `missing_require_severity: :ignore` is used.**

---

## Missing Requires Analysis

### `digest` / `digest/md5`

Used for: generating stable 8-character hex IDs for buttons from source location or label+id pair.

**Where:** `display_dsl.rb:580` (in `DisplayDSL#button`) and `app.rb:3` (top-level require) + `app.rb:326` (in `App#button`).

**Workarounds:**
1. **Best for Opal:** Replace `Digest::MD5.hexdigest(id_input)[0..7]` with a pure-Ruby FNV or djb2 hash (no stdlib needed). This is the recommended approach for the Opal adapter.
2. **Conditional guard:** `require 'digest/md5' unless RUBY_PLATFORM == 'opal'` — but this leaks server/client coupling into shared files.
3. **OpalRenderer handles button IDs independently** — the Opal runtime can use JS `Date.now()` or a counter; the Ruby-side `stable_id` is server-only.

**Recommended resolution:** The Opal runtime/renderer does not need stable IDs from Ruby — buttons in the browser are handled via JS event listeners, not HTMX post-backs. The `DisplayDSL#button` and `App#button` methods can be overridden in `adapter/opal.rb` without the `digest` dependency.

### `require 'set'` in `app.rb`

`Set` IS available in Opal's stdlib (`stdlib/set.rb`). However, the `require 'set'` at the top of `app.rb` will trigger a missing-require warning in strict mode — but since Opal includes `set.rb` in its stdlib, this resolves correctly at runtime. **No action needed.**

Wait — re-checking: Opal's stdlib has `set.rb` but it needs to be added to the Opal path. In practice, when using `missing_require_severity: :ignore`, `Set` will be undefined at runtime unless explicitly included. The `opal_entry.rb` build step should add `require 'set'` before bundling, or stub it.

**Resolution:** Add `require 'set'` to the Opal bundle entrypoint build configuration.

---

## Opal Standard Library Availability

| Library | In Opal | Notes |
|---|---|---|
| `set` | YES (`stdlib/set.rb`) | Must be explicitly included in bundle |
| `json` | YES (`stdlib/json.rb`) | Must be explicitly included in bundle |
| `cgi` | YES (`stdlib/cgi.rb`) | Must be explicitly included in bundle |
| `base64` | YES (`stdlib/base64.rb`) | Must be explicitly included in bundle |
| `ostruct` | YES (`stdlib/ostruct.rb`) | Must be explicitly included in bundle |
| `digest` | NO | Not in Opal core or stdlib — replace with pure-Ruby hash |
| `digest/md5` | NO | Same as above |

---

## kramdown Opal Compatibility

**Result: NOT Opal-safe for production use.**

When kramdown's gem `lib/` is added to Opal's load path:
- Compiles with `missing_require_severity: :ignore` but produces warnings:
  - "Cannot handle dynamic require" — `kramdown/document.rb:130`, `kramdown/converter.rb:39`, `kramdown/converter.rb:55`
  - "Skipping the 'o' Regexp flag as it's not widely supported by JavaScript vendors" — multiple occurrences in `kramdown/parser/html.rb`
- Fails strict compilation with `MissingRequire` on `kramdown/converter/math_engine/`
- kramdown uses `require` with dynamic strings (string interpolation), which Opal cannot resolve

**Conclusion:** `render_markdown` in the Opal renderer MUST use `marked.js` via JS interop (or another browser-native Markdown library) rather than kramdown. This is a firm constraint.

**Implementation note:** `marked.js` is already a common CDN dependency for Markdown rendering in browser contexts. The Opal adapter can call `JS.global[:marked].call(content)` after loading marked.js.

---

## Server-Only Constructs in Candidate Files

### `app.rb`

| Construct | Impact |
|---|---|
| `SinatraApp.create(self)` in `App#generate` | Only called from server entrypoint — not in browser path |
| `File.exist?` / `File.binread` in `build_favicon_href` | File I/O — not callable in browser. `build_favicon_href` only reached if `favicon` DSL is used. Override in Opal adapter. |
| `CGI.escape` in `define_path_helpers` | CGI is available in Opal stdlib — works in browser |
| `Time.now.to_f` in `show_toast` | `Time` is available in Opal core — works in browser |
| `require 'resource'` at top of `app.rb` | `resource.rb` requires `cgi` (available) but also integrates with Sinatra routing. Must stub or exclude. |

### `display_dsl.rb`

| Construct | Impact |
|---|---|
| `require 'digest/md5'` in `#button` | See above — override button in Opal adapter |
| `block.source_location` | Available in Opal — OK |

### `components.rb`

| Construct | Impact |
|---|---|
| `require "yaml"` / `require "json"` (inside Table/ScoreTable) | `json` available in Opal stdlib; `yaml` not needed for browser rendering |
| Direct `view.div`, `view.span`, `view.h4`, `view.p`, `view.hr` calls | These 5 HTML methods must exist on the OpalRenderer's view object |
| `view.adapter.*` delegation | All rendering goes through adapter — clean separation |

---

## OpalRenderer Must-Implement Method List

The `OpalRenderer` (the `view` object passed to `component.render(view, state)`) must support:

### Direct HTML element methods (called directly on view in components.rb)

- `div(**attrs, &block)` — Card, CardHeader, CardBody, CardFooter, Div
- `span(&block)` — Phrase, Card label
- `h4(&block)` — CardHeader
- `p(&block)` — Text component
- `hr(**attrs)` — MenuDivider

### Adapter methods (via `view.adapter.*`)

From `components.rb` (64 adapter calls):
- `render_text_field`, `render_text_area`, `render_checkbox`, `render_select`, `render_radio_group`
- `render_button`, `render_app_header`, `render_div`, `render_term`, `render_lesson_text`
- `render_vstack`, `render_hstack`, `render_grid`, `render_scroll_box`
- `render_collapsible`, `render_alert`, `render_tabs`, `render_breadcrumbs`, `render_dropdown`
- `render_modal`, `render_toast_container`, `render_theme_toggle`, `render_theme_preset`, `render_theme_switcher`
- `render_header`, `render_markdown`, `render_stat_display`, `render_badge`, `render_status_dot`
- `render_type_tag`, `render_pulse_indicator`, `render_activity_item`, `render_timeline_event`
- `render_priority_item`, `render_progress_bar`, `render_spinner`, `render_score_table`, `render_table`
- `render_status_badge`, `render_external_link_button`, `render_link`, `render_navbar`, `render_nav_item`
- `render_checkbox_group`, `render_code_editor`, `render_tag_buttons`, `render_form`
- `render_expandable_card`, `render_canvas_continue`, `render_bar_chart`, `render_line_chart`
- `render_pie_chart`, `render_stacked_bar_chart`, `render_column`, `render_columns`
- `render_app_shell`, `render_main_content`, `render_sidebar`

From visual skills component sub-files:
- `render_code_block`, `render_image_block`, `render_mermaid`, `render_keyboard_shortcuts`
- `render_slide_container`, `render_slide`, `render_sidebar_toc`, `render_callout`, `render_comparison`
- `render_pipeline`, `render_kpi_dashboard`, `render_chartjs`, `render_timeline_event`
- `render_design_deck`, `render_deck_slide`, `render_deck_option`, `render_deck_summary`
- `render_generate_more_controls`, `render_skeleton_placeholder`, `render_model_selector`
- `render_close_overlay`, `render_confirmation_bar`
- `render_hero`, `render_prose`, `render_pullquote`, `render_dir_tree`, `render_legend`
- `render_flow_arrow`, `render_layout_toggle`

**Phase 1 OpalRenderer priority (minimal viable set for basic text/container rendering):**
- `div`, `span`, `h4`, `p`, `hr`
- `render_text`, `render_markdown` (via marked.js), `render_header`, `render_button`
- `render_div`, `render_vstack`, `render_hstack`, `render_card`

---

## Adjustments to Phase 1 Plan

1. **Opal version locked:** Use `opal ~> 1.8` (installed 1.8.2). API confirmed working.

2. **Builder pattern:** Use `Opal::Builder.new(missing_require_severity: :ignore)` for the entrypoint build. The 7 candidate files all compile under this mode.

3. **digest replacement:** The `App#button` and `DisplayDSL#button` use `Digest::MD5` for stable IDs. In the Opal adapter, override the button logic to use a pure counter or JS `Math.random()`. No digest dependency needed in the browser.

4. **stdlib requires in Opal bundle:** The opal build step must explicitly `require` stdlib modules: `set`, `json`, `cgi` before bundling `stream_weaver/app`.

5. **kramdown is out:** `render_markdown` in `OpalAdapter` must use `marked.js` via `JS.global[:marked].call(content)`. Add marked.js to the CDN list alongside the Opal runtime bundle.

6. **`require 'resource'` in app.rb:** `resource.rb` is a server-only routing concern. The `opal_entry.rb` entrypoint does NOT require `app.rb` directly — it requires only the safe subset. Phase 1 OpalRenderer can stub or skip resource/routing machinery.

7. **Direct view HTML calls are minimal:** Only `div`, `span`, `h4`, `p`, `hr` — the OpalRenderer's view interface is very simple.

8. **Adapter delegation is the primary pattern:** 64 of 73 `view.` calls go through `view.adapter.*` — the clean separation makes OpalAdapter straightforward to implement incrementally.

---

## Files Created/Modified This Spike

- `Gemfile` — added `group :development { gem "opal", "~> 1.8" }`
- `lib/stream_weaver/opal_entry.rb` — browser-only require tree (created, placeholder for non-existent files)
- `bin/opal_spike.rb` — Opal compatibility test script
- `docs/opal-spike-findings.md` — this document
