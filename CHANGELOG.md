# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
  - `Markdown` / `md` - Full GitHub Flavored Markdown via Kramdown
  - `Header` with `header1`-`header6` helpers for semantic headers
  - `TextArea` for multi-line text input
  - `RadioGroup` for single-choice radio buttons
  - `Card` for styled content containers
  - `Collapsible` for expandable/collapsible sections
  - `Columns` and `Column` for multi-column layouts with custom widths
  - `Form` with `submit`/`cancel` for deferred submission forms (client-side only until submit)
  - `ScoreTable` for color-coded metrics display
  - `LessonText`, `Term`, `Phrase` for educational content with glossary tooltips
  - `CheckboxGroup` with `item` for batch selection with select all/none
  - `StatusBadge` for visual match indicators (🟢 Strong / 🟡 Maybe / 🔴 Skip)
  - `TagButtons` for quick-select tag groups (single-select with destructive style option)
  - `ExternalLinkButton` for buttons that open URLs in new tabs (with optional form submit)
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
- Checkbox state properly handles unchecked values
- Agentic mode correctly outputs JSON to STDOUT after form submission
- Select `default:` now properly initializes Alpine.js state

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

[Unreleased]: https://github.com/fkchang/stream_weaver/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/fkchang/stream_weaver/releases/tag/v0.1.0
