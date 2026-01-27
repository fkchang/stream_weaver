# StreamWeaver Gem Release & Panel Feature Plan

## Context

Preparing StreamWeaver for initial gem release to RubyGems, and implementing iTerm2 panel feature for Claude Code integration.

## What's Done

### 1. Documentation Updates ✅
- **CHANGELOG.md** - Updated with all features since 0.1.0:
  - Canvas Mode (IPC for external apps)
  - Templates (wizard, choices, confirm, info, table, code, diff)
  - Dashboard Components
  - Table enhancements
  - Dark theme
  - default: option for text inputs

- **README.md** - Completely rewritten:
  - "Express intention, get interface" tagline
  - Joy of Ruby philosophy section
  - Four modes table (Standalone, Agentic, Canvas, Service)
  - `ruby app.rb` vs `streamweaver app.rb` distinction
  - Token efficiency emphasis (5-10x fewer tokens)
  - iTerm2 built-in browser tip
  - Condensed components reference

### 2. Panel Feature (Partially Done)
**Commits pushed:**
- `062a295` - feat: Add panel command for iTerm2 split + canvas workflow

**Files created/modified:**
- `lib/stream_weaver/iterm.rb` - NEW - iTerm2 AppleScript integration
- `lib/stream_weaver/cli.rb` - Added `panel` and `install-skill` commands
- `lib/stream_weaver/canvas/bridge_server.rb` - Enhanced waiting screen
- `lib/stream_weaver.rb` - Added require for iterm.rb

**What works:**
- `streamweaver panel [name]` - Creates canvas, splits iTerm2 pane
- `streamweaver install-skill [--global]` - Installs Claude Code skill
- AppleScript escaping fixed (using Open3.capture2 with stdin)
- Split returns `:external` (uses system browser since iTerm2 browser profile not set up)

**Known issues to investigate:**
- "✓ Submitted - You can close this window" message appears on canvas submit
- User reported this is wrong for live canvas mode
- Need to verify if this was existing behavior or regression

## What's Left

### 1. Test Panel Feature
```bash
# Test the panel command
./exe/streamweaver panel test-session

# Should:
# - Split iTerm2 vertically
# - Create canvas session
# - Open browser (external or in iTerm2 if browser profile exists)

# Push content
./exe/streamweaver canvas-push test-session <<'RUBY'
header1 "Test"
button "Click me"
RUBY

# Clean up
./exe/streamweaver canvas-close test-session
```

### 2. Investigate Submit Message
- Check if "close this window" message on submit was existing behavior
- Canvas/live mode may need different submit handling than agentic mode
- Don't change without understanding full context

### 3. Gem Release Prep
- Version bump: 0.1.0 → 0.2.0 (in `lib/stream_weaver/version.rb`)
- Clean up old files:
  - `IMPLEMENTATION_SUMMARY_v0.1.0.md` - move to docs/archive?
  - `blog_post_streamweaver_vs_react.md` - remove from gem?
- Build and test gem locally: `gem build stream_weaver.gemspec`
- Push to RubyGems: `gem push stream_weaver-0.2.0.gem`

### 4. iTerm2 Browser Profile (Optional Enhancement)
For true embedded browser in iTerm2 split pane:
1. User needs to set up browser profile in iTerm2 Preferences
2. Could add `streamweaver setup-iterm` command to guide this
3. See: https://iterm2.com/documentation-web.html

## Key Files

```
lib/stream_weaver/
├── iterm.rb              # iTerm2 AppleScript (NEW)
├── cli.rb                # panel, install-skill commands
├── canvas/
│   └── bridge_server.rb  # Enhanced waiting screen
└── version.rb            # Bump to 0.2.0

docs/
├── canvas-roadmap.md     # Canvas documentation
├── templates.md          # Templates documentation
└── SERVICE_MODE.md       # Service mode docs
```

## Commands Reference

```bash
# Panel workflow
streamweaver panel [name]           # Split iTerm2, open canvas
streamweaver canvas-push <name>     # Push DSL content
streamweaver canvas-wait <name>     # Wait for user interaction
streamweaver canvas-close <name>    # Close session

# Skill installation
streamweaver install-skill          # Project scope (.claude/skills/)
streamweaver install-skill --global # Global scope (~/.claude/skills/)

# Gem build
gem build stream_weaver.gemspec
gem push stream_weaver-0.2.0.gem
```

## Resume Prompt

To continue this work, use this prompt:

---

Continue StreamWeaver gem release preparation.

Current state:
- README and CHANGELOG updated and committed
- Panel feature implemented but needs testing
- Need to: test panel, investigate submit message behavior, bump version, release gem

Read the plan at `docs/plans/2026-01-26-gem-release-and-panel.md` for full context.

Start by testing the panel command to verify the iTerm2 split works correctly.

---
