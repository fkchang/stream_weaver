# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Human-readable service-mode URLs** - `streamweaver run <file.rb>` now serves apps at slug URLs like `/apps/sales-dashboard` (derived from the app's declared name, falling back to the filename) instead of opaque hashes. The hex `/apps/:app_id` URL still resolves as a canonical fallback. Slugs that collide across different files get a numeric suffix (`-2`, `-3`, ...); re-loading the same file reuses its existing slug.
- **`endpoint` DSL — the "never rewrite in Sinatra" escape hatch** - Register a real HTTP route (webhook receiver, JSON API, file download) directly from the app DSL: `endpoint(:get, "/api/status") { |req| { ok: true } }`. Supports `:get`/`:post`/`:put`/`:patch`/`:delete`; the block receives the raw `Rack::Request` and its return value maps to a response (`Hash` -> JSON 200, `String` -> HTML 200, `[status, headers, body]` -> passed through verbatim). Endpoints bypass StreamWeaver's state/session/CSRF machinery entirely and always lose to a colliding internal route (`/update`, `/action/*`, `/submit`, `/event/*`, `/form/*`, `/theme/*`, `/sw/*`), with a warning at registration time if that happens. Works in both standalone (`run!`) and multi-app service mode (scoped under `/apps/:app_id/...`). See `docs/endpoints.md`.
- **iTerm split-pane install hint** - When `streamweaver panel` falls back to the system browser because the optional `iterm2_ruby` gem isn't installed (but you ARE in iTerm2 on macOS), the CLI now prints a one-line `gem install iterm2_ruby` tip so the split-pane perk is discoverable.
- **`bin/smoke` — executable UAT smoke test** - Freezes a manual UAT battery into a repeatable script: boots a fixture app in both standalone (`run!`) and multi-app service (`streamweaver serve`) mode on ephemeral ports and drives it over real HTTP, checking the `endpoint` DSL, the reserved-path boot warning, slug/hex `/apps/:id` resolution, endpoint dispatch scoping, and slug collision/reuse. Prints one check/x check line per assertion plus a final summary; exits nonzero on any failure. Wired into CI as the `smoke` job. See `docs/testing.md`.

### Changed
- **Built-in tutorial (`streamweaver tutorial`) revamped for the last ~6 months of features** - Refreshed the Themes and Layout/Cards lessons (`:doc` theme, `:sketch` preset, `theme_switcher`/`theme_toggle` auto dark mode, `card_header` `badge:`/`meta:`) and added six new lessons: The Four Modes (standalone/agentic/service/canvas-panel orientation), Navigation (`navbar`/`nav_item`/`link_to` + `route_by`/`route_with`), Resource DSL, Endpoints (the tutorial now registers and self-demonstrates a real `GET /tutorial/api/hello` endpoint), Service Mode, and Canvas/Panel. Also fixed an invalid-Ruby one-liner in the Resource DSL quick-start example (`docs/resource-dsl.md`).

### Fixed
- **Loading a `.run!` app file no longer kills service mode** - `Service.load_app` evaluates app files with a `service_loading` flag set, and `run!` is now a warn-and-no-op while it's active. Previously a file ending in `end.run!` (the documented standalone pattern) started a second server inside the service process and took the whole service down on exit. Standalone `ruby app.rb` behavior is unchanged.

## [0.2.0] - 2026-07-05

### Changed
- **`iterm2_ruby` is now an optional enhancement, not a runtime dependency** - `gem install stream_weaver` no longer requires it; iTerm2 split-pane browser panes activate when the (now published) `iterm2_ruby` gem is installed (`gem install iterm2_ruby`), otherwise panel/canvas commands fall back to opening the system browser

### Added
- **Canvas theme support** - Canvas/panel sessions can now use the `:doc` theme (and any registered theme): `streamweaver panel my-session --theme=doc`. Canvas sessions default to `:default` as before; the canvas page now reuses the same theme CSS (including dark-mode variants) as full-page rendering, so the mermaid dark-mode fix also applies in canvas mode.
- **`CardHeader` `badge:` / `meta:` options** - `card_header "Title", badge: "C1", meta: "right-aligned text"` renders a mono badge before the title and right-aligned meta text after it, for compact labeled card headers.
- **Puma-dev support** - Run StreamWeaver apps with memorable URLs like `http://myapp.test`:
  - Detects `PORT` environment variable (set by Puma-dev and PaaS platforms)
  - Skips auto-browser opening when `PORT` is set for on-demand access
  - Provides `config.ru` example in `examples/puma_dev/`
  - See [examples/puma_dev/README.md](examples/puma_dev/README.md) for setup guide

### Fixed
- **Mermaid diagrams stayed light in dark mode** - Diagrams didn't re-render when the page switched to dark mode, and modern CSS color functions (`oklch()`, `color-mix()`) in theme tokens crashed Mermaid's color parser. Diagrams now re-render on theme change, and colors are resolved through a canvas probe so Mermaid always receives plain `rgb()`.
- **`theme_toggle` `mode:` was a dead parameter** - `theme_toggle mode: :light` (or `:dark`) had no effect on first-page-load behavior; the page always defaulted to following OS `prefers-color-scheme` regardless of `mode:`. `AutoMode.inline_script`/`.alpine_data` now accept the component's `mode:` as the localStorage-fallback default, so `mode: :light`/`:dark` actually forces that theme until the user toggles.
- **Puma thread pool exhaustion** - SSE streaming apps could hang when opening multiple browser tabs; increased default Puma thread pool from 5 to 16 to accommodate long-lived SSE connections
- **Canvas-push error feedback** - DSL errors now reported to stderr with exit code 1, enabling Claude to see and fix syntax errors
- **Tutorial checkbox syntax** - Fixed incorrect `checkbox :key, label: "text"` to correct `checkbox :key, "text"` in learn.md examples
- **iTerm panel stability** - AppleScript keystrokes could hang or type into wrong window; now opens URL in external browser instead

### Added
- **`navbar` / `nav_item` / `link_to` components** - Cross-app navigation bar DSL. `navbar` renders a horizontal nav bar; `nav_item` renders as a bold non-clickable span when `active: true` or a link otherwise; `link_to` renders an inline anchor element.
  ```ruby
  navbar do
    nav_item "Dashboard", active: true
    nav_item "Settings", href: "/settings"
  end
  link_to "Docs", href: "https://example.com"
  ```
- **`--reset` flag** - Clear corrupted session state on any app: `ruby my_app.rb --reset`. One-shot clear on first page load, then normal operation resumes
- **`SW_DEBUG` env var** - Request-level debug logging for troubleshooting: `SW_DEBUG=1 ruby my_app.rb`. Logs request method, path, cookie/state sizes, and SSE connection counts
- **StatusDot `label:` option** - Display text labels below status dots:
  ```ruby
  status_dot status: :green, pulse: true, label: "billing.rb"
  ```
- **Canvas Mode CSS** - Full component styling in canvas/panel mode:
  - Progress bars with animated stripes
  - Spinners with rotation animation
  - Status dots with pulse animation and labels
  - Badges, alerts, activity items
  - Tables with striped rows and sortable headers
  - Collapsible sections, hstack/vstack spacing
- **Canvas Syntax Highlighting** - Code blocks in canvas mode now have syntax highlighting via highlight.js (github theme)
- **Canvas Charts** - Chart.js support in canvas mode for bar_chart, line_chart, etc.
- **`git_health.sh` example** - Dynamic git repository analyzer:
  - Scans real git history, generates custom health dashboard
  - Charts showing commit patterns by day of week
  - Author contribution tables with sorting
  - Contextual recommendations based on findings
  - Different results each run based on actual repo state
- **Enhanced `panel_demo.sh`** - 4-step workflow showcasing canvas capabilities:
  - Step 1: Issue selection (cards, badges, checkboxes, radio groups)
  - Step 2: Diff preview (side-by-side columns, alerts)
  - Step 3: Progress animation (spinner, progress bar, status dots, activity log)
  - Step 4: Results summary (badges, alerts, sortable table, collapsibles)
- **Canvas Mode** - IPC system for external apps to push rich UI:
  - Persistent browser canvas for agentic CLIs to display interactive UI
  - WebSocket + HTTP bridge for bidirectional communication
  - `streamweaver panel SESSION` - Open canvas in iTerm2 split pane (side-by-side with terminal)
  - `streamweaver canvas-push SESSION` - Push DSL content to canvas
  - `streamweaver canvas-wait SESSION` - Wait for button click, return JSON (ignores radio/checkbox)
  - `streamweaver setup` - Configure Claude Code with bash permissions and panel skill
  - High-level Ruby helpers: `Canvas.pick(session, options)`, `Canvas.confirm(session, message)`
  - See [docs/canvas-roadmap.md](docs/canvas-roadmap.md) for full documentation
- **Button `id:` option** - Disambiguate buttons in loops to prevent callback collisions:
  ```ruby
  items.each { |i| button "Select", id: i[:name] do |s| ... end }
  ```
- **Templates** - Pre-built UI patterns for common interactions:
  - `wizard` - Multi-step forms with branching (`next: {branch_on: "field_name"}`)
  - `choices` - Quick selection from options, returns `{choice: "Selected"}`
  - `confirm` - Yes/No decisions, returns `{confirmed: true/false}`
  - `info` - Display messages with action buttons, returns `{action: "Clicked"}`
  - `table` - Data display with optional row selection
  - `code` - Code display with syntax highlighting and line numbers
  - `diff` - Unified diff display with add/remove highlighting
  - Usage: `streamweaver template <name> <session> '<json-config>'`
  - See [docs/templates.md](docs/templates.md) for full documentation
- **Dashboard Components** - Operations dashboard UI elements (best with `theme: :dark`):
  - `status_dot` - Colored status indicators with optional pulse animation
  - `badge` - Pill-shaped badges with variant colors (`:default`, `:danger`, `:warning`, `:success`)
  - `stat_display` - Large value + label statistics (e.g., "42 TASKS")
  - `type_tag` - Activity type badges (`:research`, `:task`, `:decision`, `:planning`)
  - `pulse_indicator` - Animated system status indicators
  - `priority_item` - Priority-colored items (`:critical`, `:high`, `:medium`, `:low`)
  - `activity_item` - Time-stamped activity feed entries
  - `app_shell` - Dashboard layout with main area and collapsible sidebar
  - `expandable_card` - Cards that expand/collapse to show details
- **Table Component Enhancements**:
  - `markdown: true` option for clickable links in table cells
  - Smart header inference from array of hashes (no need to specify headers)
  - Column DSL with formatters: `column :balance, format: :currency, align: :right`
  - Built-in formatters: `:currency`, `:date`, `:number`, `:percent`, `:boolean`
  - Interactive features: `sortable: true`, `sticky_header: true`
  - Styling options: `striped: true`, `bordered: true`, `hoverable: true`, `compact: true`
- **Dark Theme** - Full dark mode with deep backgrounds, glow effects, and dashboard styling
- **`default:` option** for `text_field`, `text_area`, and `code_editor` to set initial values
- **Service Mode** - Single server renders multiple apps without per-app process management:
  - `streamweaver <file.rb>` - Run app (auto-starts service if needed)
  - `streamweaver list` - List all loaded apps with timing info
  - `streamweaver remove <id>` - Remove a specific app
  - `streamweaver clear` - Remove all apps
  - `streamweaver admin` - Open admin dashboard
  - `streamweaver status` - Show service status
  - `streamweaver stop` - Stop background service
  - Named sessions via `--name` flag for easier identification
- **Admin Dashboard** - StreamWeaver app managing other StreamWeaver apps (meta!)
  - Shows service stats (apps loaded, PID, port)
  - Lists all apps with timing (loaded/idle duration)
  - Open/Remove buttons for each app
  - Clear All Apps action
- **Multi-app routing** - Each app gets unique URL (`/apps/:app_id`)
- **URL prefix support** in adapter for service mode routing
- **Multi-theme system** with three built-in themes:
  - `:default` - Warm Industrial (Source Sans 3, 17px, generous spacing)
  - `:dashboard` - Data Dense (15px, tighter spacing, minimal accents)
  - `:document` - Reading Mode (Crimson Pro serif, 19px, paper background)
- **Custom theme registration** via `StreamWeaver.register_theme`
- **Runtime theme switching** via `theme_switcher` component
- **Theme Tweaker app** (`examples/theme_tweaker.rb`) - Visual theme editor with live preview and export
- **`submit: false` option** for form components to disable HTMX auto-submit:
  - `text_field :key, submit: false`
  - `checkbox :key, "Label", submit: false`
  - `select :key, choices, submit: false`
  - `button "Label", submit: false` (display-only button)
- **Adapter pattern** for rendering - `StreamWeaver::Adapter::AlpineJS` handles all framework-specific rendering
- **New components**:
  - **Charts** via Chart.js (CDN-loaded only when charts present):
    - `BarChart` / `bar_chart` / `hbar_chart` - Bar charts (vertical/horizontal)
    - `LineChart` / `line_chart` - Line charts with fill, smooth, points options
    - `PieChart` / `pie_chart` / `doughnut_chart` - Pie and doughnut charts
    - `StackedBarChart` / `stacked_bar_chart` - Multi-series stacked/grouped bars
    - `sparkline` - Compact inline trends (no axes/labels)
    - `area_chart` - Line chart with fill (shorthand)
    - Multiple data input modes: inline hash, file+path, explicit labels/values, state-bound
    - File loading with dot-path extraction (e.g., `"entries.-1.phases"`)
  - `Markdown` / `md` - Full GitHub Flavored Markdown via Kramdown
  - `Header` with `header1`-`header6` helpers for semantic headers
  - `TextArea` for multi-line text input
  - `RadioGroup` for single-choice radio buttons
  - `Card` for styled content containers with `card_header`, `card_body`, `card_footer`
  - `Collapsible` for expandable/collapsible sections
  - `Columns` and `Column` for multi-column layouts with custom widths
  - `Form` with `submit`/`cancel` for deferred submission forms (client-side only until submit)
  - `ScoreTable` for color-coded metrics display
  - `LessonText`, `Term`, `Phrase` for educational content with glossary tooltips
  - `CheckboxGroup` with `item` for batch selection with select all/none
  - `StatusBadge` for visual match indicators (🟢 Strong / 🟡 Maybe / 🔴 Skip)
  - `TagButtons` for quick-select tag groups (single-select with destructive style option)
  - `ExternalLinkButton` for buttons that open URLs in new tabs (with optional form submit)
- **Layout components**:
  - `VStack` for vertical stacking with spacing and dividers
  - `HStack` for horizontal stacking with alignment and justify options
  - `Grid` for responsive grid layouts with breakpoint columns (`[1, 2, 3]`)
- **Navigation components**:
  - `Tabs` with `tab` for tabbed navigation (variants: `:line`, `:enclosed`, `:soft-rounded`)
  - `Breadcrumbs` with `crumb` for hierarchical navigation trails
  - `Dropdown` with `trigger`, `menu`, `menu_item`, `menu_divider` for action menus
- **Modal dialogs**:
  - `Modal` with `modal_footer` for overlay dialogs (sizes: `:sm`, `:md`, `:lg`, `:xl`)
  - State-driven open/close via `state[:modal_key_open]`
- **Feedback components**:
  - `Alert` for static feedback messages (variants: `:info`, `:success`, `:warning`, `:error`)
  - `ToastContainer` with `show_toast`/`clear_toasts` for stacked notifications
  - `ProgressBar` for visual progress indicators with variants and animation
  - `Spinner` for loading indicators with sizes and labels
- **Event callbacks**:
  - `on_change` callback for text_field, checkbox, select
  - `on_blur` callback for text_field, text_area
  - `debounce:` option for text input callbacks
- **Custom component modules** via `components:` option on `app`
- **Layout modes** via `layout:` parameter: `:default` (900px), `:wide` (1100px), `:full` (1400px), `:fluid` (100%)
- `default:` option for `select` component to set initial value
- `auto_close_window:` option for `run_once!` to close browser after submit
- Automatic "Submit to Agent" button in agentic mode
- CSS custom properties (CSS variables) for theme customization
- Comprehensive inline CSS with modern styling

### Changed
- `Text` component now renders literal text only (no markdown parsing)
- Refactored component rendering to use adapter pattern for future extensibility
- **New "Warm Industrial" theme**: Source Sans 3 font, terracotta primary color (#c2410c), 17px base font with 1.7 line-height

### Fixed
- **Canvas panel iTerm2 integration** - Panel now opens in split pane beside terminal
- **Canvas bridge port conflicts** - Auto-finds available port instead of hardcoded 4568
- **Canvas bridge race condition** - Waits for HTTP server health before returning URL
- **Canvas bridge reuse** - Verifies HTTP health on existing bridge before reusing
- **iTerm2 URL navigation** - Adds Escape keys to dismiss autocomplete before typing URL
- **Canvas-wait event filtering** - Now filters for 'action' events by default (button clicks only), ignoring checkbox/radio changes
- **Canvas 'Submitted' feedback** - Only shows for button clicks, not radio/checkbox changes
- **Canvas card styling** - Cards now render with proper borders, backgrounds, and the terracotta left accent
- **Canvas checkbox rendering** - Checkboxes wrapped in proper div with aligned label, inline markdown parsed
- Checkbox state properly handles unchecked values
- Agentic mode correctly outputs JSON to STDOUT after form submission
- Select `default:` now properly initializes Alpine.js state
- **Table markdown cells** - Use correct Phlex raw/safe pattern for markdown rendering in table cells
- **Table data: keyword** - Support `data:` keyword argument in table DSL method for explicit data passing
- **Tutorial session overflow** (2026-01-02) - Session cookie was exceeding 4KB limit due to `*_edited_code` keys; now filtered from session storage
- **Tutorial button ID mismatch** (2026-01-02) - Button IDs now use stable hash from `block.source_location` instead of render-order counter, preventing action failures when conditional content changes component tree
- **Tutorial Reset button** (2026-01-02) - Reset always renders with block for stable ID; uses flag pattern to survive session filtering

## [0.1.0] - 2025-11-08

### Added
- Initial release of StreamWeaver gem
- Core DSL for building interactive UIs with `app` helper method
- MVP components: TextField, Button, Text, Div, Checkbox, Select
- Sinatra-based web server with automatic port detection
- Phlex-based HTML rendering with inline CSS
- HTMX + Alpine.js frontend reactivity
- Session-based state management
- Single-file execution with `run!` method
- Browser auto-opening (cross-platform: macOS/Linux/Windows)
- **Agentic mode** with `run_once!` method for AI agent workflows
- Documentation and examples
- RSpec test suite

[Unreleased]: https://github.com/fkchang/stream_weaver/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/fkchang/stream_weaver/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/fkchang/stream_weaver/releases/tag/v0.1.0
