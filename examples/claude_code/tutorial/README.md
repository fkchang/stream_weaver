# StreamWeaver Canvas Tutorial

A conversational, freeform tutorial for learning StreamWeaver through Claude Code.

## What This Is

Unlike the standalone `tutorial.rb` (which teaches StreamWeaver components in a fixed order), this is a **conversational** tutorial where:

- You ask questions naturally in the terminal
- Claude explains briefly and renders examples to the canvas
- You iterate: "make it blue", "add more fields", "try something else"
- No fixed order—explore what interests you

## Usage

```bash
cd examples/claude_code/tutorial
claude
# /learn
```

## How It Works

1. **Welcome** - Canvas shows topics you can explore
2. **You ask** - Type questions/requests in terminal
3. **Claude renders** - Canvas shows both DSL code AND rendered output
4. **You iterate** - Modify, explore more, or finish

## Example Questions

- "Show me how text_field works"
- "What chart options are there?"
- "Make a dashboard with 3 stats"
- "Show me a login form"
- "Add validation styling to that"
- "Now try it with a dark theme"

## Canvas Layout

Each response shows:

```
┌─────────────────────────────┐
│ Component: text_field       │
├─────────────────────────────┤
│ DSL Code                    │
│ ```ruby                     │
│ text_field :email, ...      │
│ ```                         │
├─────────────────────────────┤
│ Rendered Output             │
│ ┌─────────────────────────┐ │
│ │ Email: [____________]   │ │
│ └─────────────────────────┘ │
├─────────────────────────────┤
│ Ask follow-up or try next   │
└─────────────────────────────┘
```

## Comparison with tutorial.rb

| Feature | tutorial.rb | /learn |
|---------|-------------|--------|
| Mode | Standalone app | Claude Code canvas |
| Flow | Fixed sections | Freeform conversation |
| Learning | Self-guided | Claude-guided |
| Generation | Pre-built | Dynamic per question |
| Iteration | Playgrounds | "Make it X" requests |

Both are useful—`tutorial.rb` for comprehensive self-study, `/learn` for quick exploration with Claude.

## Topics Covered

**Components:**
- Forms: text_field, radio_group, checkbox, select, button
- Data: table, bar_chart, pie_chart, stat_display
- Status: status_dot, progress_bar, spinner, badge, alert
- Layout: card, hstack, vstack, columns, collapsible

**Patterns:**
- Login/signup forms
- Dashboards with stats
- Status pages
- Multi-step progress
- Data tables with charts

## Files

```
tutorial/
├── .claude/
│   ├── commands/
│   │   └── learn.md           # Slash command instructions
│   └── settings.local.json    # Pre-allowed permissions
└── README.md                  # This file
```
