# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Automatic "Submit to Agent" button appears in agentic mode (`run_once!`)
- Submit button uses HTMX to include all form inputs via `hx-include="[x-model]"`
- `/submit` endpoint now syncs all form state (including checkboxes) before returning to agent

### Fixed
- Checkbox state now properly handles unchecked values (sets to false instead of keeping previous state)
- Agentic mode (`run_once!`) now correctly outputs JSON to STDOUT after form submission
- Fixed stdout suppression issue that prevented JSON output in agentic mode
- Added helper methods `collect_input_keys` and `find_component_by_key` for proper state synchronization
- `/submit` endpoint now properly captures all input values including unchecked checkboxes
- `/submit` endpoint now only returns input component data (not all session state)
- Agentic mode now uses Rackup with WEBrick for reliable server startup

## [0.1.0] - 2025-01-07

### Added
- Initial release of StreamWeaver gem
- Core DSL for building interactive UIs with `app` helper method
- 6 MVP components: TextField, Button, Text, Div, Checkbox, Select
- Sinatra-based web server with automatic port detection
- Phlex-based HTML rendering with inline CSS
- HTMX + Alpine.js frontend reactivity
- Session-based state management
- Single-file execution with `run!` method
- Browser auto-opening (cross-platform: macOS/Linux/Windows)
- **Agentic mode** with `run_once!` method for AI agent workflows
- STDOUT and file output modes for data return
- Documentation and examples
- RSpec test suite

### Fixed
- Checkbox component now uses `view.plain` instead of `view.text` for Phlex compatibility
- Select component option elements now use block syntax for content rendering (Phlex compatibility)
- Text component now automatically detects markdown-style headers (`##`, `###`, etc.) and renders them as proper HTML heading elements

[Unreleased]: https://github.com/fkchang/stream_weaver/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/fkchang/stream_weaver/releases/tag/v0.1.0
