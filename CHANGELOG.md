# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Adapter pattern** for rendering - `StreamWeaver::Adapter::AlpineJS` handles all framework-specific rendering
- **New components**:
  - `Markdown` / `md` - Full GitHub Flavored Markdown via Kramdown
  - `Header` with `header1`-`header6` helpers for semantic headers
  - `TextArea` for multi-line text input
  - `RadioGroup` for single-choice radio buttons
  - `Card` for styled content containers
  - `Collapsible` for expandable/collapsible sections
  - `ScoreTable` for color-coded metrics display
  - `LessonText`, `Term`, `Phrase` for educational content with glossary tooltips
  - `CheckboxGroup` with `item` for batch selection with select all/none
  - `StatusBadge` for visual match indicators (🟢 Strong / 🟡 Maybe / 🔴 Skip)
  - `TagButtons` for quick-select tag groups (single-select with destructive style option)
  - `ExternalLinkButton` for buttons that open URLs in new tabs (with optional form submit)
- `default:` option for `select` component to set initial value
- `auto_close_window:` option for `run_once!` to close browser after submit
- Automatic "Submit to Agent" button in agentic mode
- CSS custom properties (CSS variables) for theme customization
- Comprehensive inline CSS with modern styling

### Changed
- `Text` component now renders literal text only (no markdown parsing)
- Refactored component rendering to use adapter pattern for future extensibility

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
