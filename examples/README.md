# StreamWeaver Examples

## Directory Structure

### [basic/](basic/)
Simple getting-started examples. Hello world, forms, basic layouts.

### [components/](components/)
Individual component showcases. Each file demonstrates a specific component's options and styling.

### [layout/](layout/)
Layout patterns: columns, grids, cards, collapsibles.

### [styling/](styling/)
Theme and styling examples: dark mode, custom CSS, color schemes.

### [charts/](charts/)
Chart components: bar charts, pie charts, stat displays.

### [advanced/](advanced/)
Complex patterns: multi-step wizards, dashboards, tables with sorting.

### [agentic/](agentic/)
Interactive workflows with user input and state management.

### [claude_code/](claude_code/)
**Claude Code slash command integrations**. Interactive canvas workflows powered by Claude Code. See [claude_code/README.md](claude_code/README.md).

## Live Streaming Examples

### timer_showcase.rb
Dev Machine Monitor — live CPU, Memory, and Disk metrics updated every few seconds. Demonstrates `every` timers, `add_class`/`remove_class` for spotlight effects, and `prepend` for an alert feed.

```bash
bundle exec ruby examples/timer_showcase.rb
```

### timer_health_checker.rb
Endpoint Health Checker — pings GitHub, RubyGems, and Httpbin every 5 seconds, showing response times, SLA badges, and ring effects on degraded endpoints.

```bash
bundle exec ruby examples/timer_health_checker.rb
```

## Standalone Scripts

### panel_demo.sh
Multi-step workflow demonstrating StreamWeaver's visual capabilities:
- Syntax-highlighted code diffs
- Animated progress indicators
- Interactive charts and tables

```bash
./examples/panel_demo.sh
```

### git_health.sh
Git repository health analyzer with dynamic canvas dashboard:
- Real git data analysis
- File structure visualization
- Contributor stats

```bash
./examples/git_health.sh [path-to-repo]
```

### dashboard_components.rb
Component showcase for operations dashboards.

### operations_dashboard_demo.rb
Full operations dashboard example with dark theme.

## Running Examples

### Ruby Files
```bash
streamweaver examples/basic/hello_world.rb
```

### Shell Scripts
```bash
./examples/panel_demo.sh
```

### Claude Code Slash Commands
```bash
cd examples/claude_code/codebreaker
claude
# /infiltrate
```

## Documentation

- [Canvas Panel Workflow](../docs/canvas-panel-workflow.md) - Two-way IPC for Claude Code
- [Components Reference](../docs/components_reference.md) - All DSL components
- [How StreamWeaver Works](../docs/architecture/how_streamweaver_works.md) - Architecture overview
