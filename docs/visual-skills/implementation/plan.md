# Visual Skills Implementation Plan

*GSD Ralph-Loop Orchestration*
*Created: 2026-03-12*

---

## Overview

This plan describes how to execute the 15 tasks in `tasks.md` using the GSD ralph-loop pattern: each task gets a fresh subagent with its own 200K context window, reads specs from files, produces independently committable output, and tracks progress via file-based state.

---

## 1. State Tracking Files

### PLAN.md (this file)
- Describes the orchestration process
- Does not change during execution

### STATE.md
Create at: `docs/visual-skills/implementation/STATE.md`

Tracks live execution state. Format:

```markdown
# Implementation State

## Current Task: T2
## Last Completed: T1
## Status: IN_PROGRESS

| Task | Status | Commit | Notes |
|------|--------|--------|-------|
| T1 | DONE | abc1234 | Spike complete. See spike-findings.md |
| T2 | IN_PROGRESS | -- | Started theme enhancement |
| T3 | BLOCKED | -- | Waiting on T2 |
| T4 | NOT_STARTED | -- | |
| ... | | | |
```

Status values: `NOT_STARTED`, `IN_PROGRESS`, `DONE`, `FAILED`, `BLOCKED`

### spike-findings.md
Created by T1 at: `docs/visual-skills/implementation/spike-findings.md`
Consumed by T10. Contains the discovered state machine, edge cases, and architectural decisions from the generate-more spike.

---

## 2. Execution Order

### Wave 1: Spike + Foundation (parallel)

**T1 (Generate-More Spike)** and **T2 (Theme + CSS Foundation)** run first, in parallel. T1 has no dependencies. T2 is the foundation for everything else.

```
Subagent A: T1 (spike)         -- standalone, ~40% context
Subagent B: T2 (theme)         -- standalone, ~35% context
```

### Wave 2: Shared Components (parallel after T2)

Once T2 is done, T3, T4, T5, T6 can all run in parallel.

```
Subagent C: T3 (mermaid)       -- needs T2
Subagent D: T4 (codeblock)     -- needs T2
Subagent E: T5 (keyboard+slides) -- needs T2
Subagent F: T6 (card+table)   -- needs T2
```

### Wave 3: Deck Core (sequential)

T7, T8, T9 are sequential (each builds on the previous).

```
Subagent G: T7 (deck shell)    -- needs T5, T6
Subagent G: T8 (selection)     -- needs T7
Subagent G: T9 (summary)      -- needs T8
```

### Wave 4: Generate-More + Explainer (parallel)

T10 needs both T1 and T8. T11, T12 need T2 and T6.

```
Subagent H: T10 (generate-more) -- needs T1, T8
Subagent I: T11 (explainer 1)   -- needs T2, T6
Subagent J: T12 (explainer 2)   -- needs T2, T6
```

### Wave 5: Polish (parallel)

T13, T14, T15 are independent of each other.

```
Subagent K: T13 (css helpers)    -- needs T2
Subagent L: T14 (deck polish)    -- needs T10
Subagent M: T15 (presets)        -- needs T2
```

### Optimal Timeline (with parallelization)

```
Wave 1:  T1 ─────────  T2 ────────
Wave 2:                  T3  T4  T5  T6
Wave 3:                              T7 ── T8 ── T9
Wave 4:                                          T10  T11  T12
Wave 5:                                                T13  T14  T15
```

With maximum parallelization, critical path is: **T2 -> T5 -> T7 -> T8 -> T10 -> T14** (6 sequential steps).

---

## 3. Subagent Invocation Protocol

### Starting a Task

Each subagent receives a prompt like this:

```
You are implementing task T{N} of the StreamWeaver visual skills project.

Read these files first:
1. docs/visual-skills/implementation/tasks.md -- find task T{N}, read its full specification
2. docs/visual-skills/implementation/STATE.md -- verify dependencies are DONE
3. {each file listed in the task's "Input Files" section}

Your job:
- Create/modify ONLY the files listed in "Output Files"
- Meet ALL acceptance criteria
- Run tests: `bundle exec rspec {spec files}`
- Commit with message: "feat(visual-skills): T{N} - {task title}"

When done:
- Update STATE.md: set T{N} to DONE, record commit hash
- Unblock any tasks that depend on T{N}
```

### Context Budget

Each task is designed to fit within ~50% of the 200K context window:
- Task spec reading: ~5%
- Input file reading: ~15-25%
- Implementation: ~15-20%
- Test output / iteration: ~5-10%
- Total: ~40-55%

This leaves ~50% headroom for debugging, retries, and exploratory reading.

### Commit Convention

Each task produces exactly one commit:

```
feat(visual-skills): T{N} - {task title}

- {bullet 1: what was created}
- {bullet 2: what was modified}
- {bullet 3: key decisions made}
```

Example:
```
feat(visual-skills): T3 - Mermaid component

- Add Components::Mermaid with zoom/pan support
- Add mermaid() DSL method to DisplayDSL
- CDN loads Mermaid.js lazily via ESM import
- Theme-aware: reads data-theme for Mermaid themeVariables
```

---

## 4. Failure Recovery

### Task Fails Tests

1. Subagent fixes and retries within same context window
2. If context is exhausted, mark task as `FAILED` in STATE.md with notes
3. Next subagent reads STATE.md, sees failure notes, picks up where previous left off

### Task Produces Wrong Output

1. `git revert {commit}` the bad commit
2. Update STATE.md to `NOT_STARTED` with notes on what went wrong
3. Re-run with additional guidance in the prompt

### Dependency Not Ready

1. Subagent reads STATE.md, sees dependency is not `DONE`
2. Subagent reports `BLOCKED` and exits
3. Orchestrator retries after dependency completes

### Context Exhaustion

If a task is too large for one context window:
1. Split into T{N}a and T{N}b
2. First subagent commits partial work, updates STATE.md
3. Second subagent continues from committed state

---

## 5. Integration Checkpoints

After each wave, run full test suite and verify integration:

### After Wave 2 (shared components)
```bash
bundle exec rspec spec/components/mermaid_spec.rb \
                   spec/components/code_block_spec.rb \
                   spec/components/image_block_spec.rb \
                   spec/components/keyboard_shortcuts_spec.rb \
                   spec/components/slide_container_spec.rb \
                   spec/components/card_depth_spec.rb \
                   spec/components/table_enhanced_spec.rb
```
Verify: existing tests still pass (`bundle exec rspec` -- full suite).

### After Wave 3 (deck core)
```bash
bundle exec rspec spec/components/deck/
```
Manual verification: run example deck app, navigate slides, select options, verify state persistence.

### After Wave 4 (generate-more + explainer)
```bash
bundle exec rspec spec/components/deck/generate_more_spec.rb \
                   spec/components/sidebar_toc_spec.rb \
                   spec/components/callout_spec.rb \
                   spec/components/comparison_spec.rb \
                   spec/components/pipeline_spec.rb \
                   spec/components/kpi_dashboard_spec.rb \
                   spec/components/chart_spec.rb
```
Manual verification: generate-more flow end-to-end with simulated agent.

### After Wave 5 (polish)
Full suite: `bundle exec rspec`
Manual verification: theme presets, HTML export, all deck workflows.

---

## 6. Running the Orchestrator

### Manual Orchestration (recommended to start)

The orchestrator is you (the human or the main Claude Code session). Steps:

1. **Initialize STATE.md:**
   ```bash
   cat > docs/visual-skills/implementation/STATE.md << 'EOF'
   # Implementation State

   ## Current Task: T1, T2
   ## Last Completed: --
   ## Status: IN_PROGRESS

   | Task | Status | Commit | Notes |
   |------|--------|--------|-------|
   | T1 | NOT_STARTED | -- | |
   | T2 | NOT_STARTED | -- | |
   | T3 | BLOCKED | -- | Needs T2 |
   | T4 | BLOCKED | -- | Needs T2 |
   | T5 | BLOCKED | -- | Needs T2 |
   | T6 | BLOCKED | -- | Needs T2 |
   | T7 | BLOCKED | -- | Needs T5, T6 |
   | T8 | BLOCKED | -- | Needs T7 |
   | T9 | BLOCKED | -- | Needs T8 |
   | T10 | BLOCKED | -- | Needs T1, T8 |
   | T11 | BLOCKED | -- | Needs T2, T6 |
   | T12 | BLOCKED | -- | Needs T2, T6 |
   | T13 | BLOCKED | -- | Needs T2 |
   | T14 | BLOCKED | -- | Needs T10 |
   | T15 | BLOCKED | -- | Needs T2 |
   EOF
   ```

2. **Launch Wave 1:** Start two subagent sessions (or one at a time):
   - Session 1: "Implement task T1 per docs/visual-skills/implementation/tasks.md"
   - Session 2: "Implement task T2 per docs/visual-skills/implementation/tasks.md"

3. **After each task completes:** Verify the commit, check STATE.md was updated, unblock dependent tasks.

4. **Launch next wave** when all dependencies are met.

### Automated Orchestration (future)

A script could automate the loop:

```ruby
#!/usr/bin/env ruby
# bin/ralph-loop.rb -- automated task orchestration
#
# Reads STATE.md, finds next runnable task (NOT_STARTED with all deps DONE),
# launches subagent, waits for completion, updates state.
#
# Not implemented yet -- manual orchestration is fine for 15 tasks.
```

---

## 7. Verification Checklist (End-to-End)

When all 15 tasks are complete:

- [ ] `bundle exec rspec` -- all tests pass (existing + new)
- [ ] Example design deck app renders and navigates
- [ ] Option selection persists across page reloads
- [ ] Generate-more flow works with simulated agent
- [ ] Summary slide shows all selections
- [ ] Theme toggle works (dark/light/auto)
- [ ] Theme presets apply correctly
- [ ] Explainer components render in isolation
- [ ] SidebarToc scroll spy works
- [ ] HTML export produces valid self-contained file
- [ ] CSS uses `sw-` prefix consistently
- [ ] No regressions in existing StreamWeaver functionality
- [ ] All components have ARIA attributes where applicable

---

## 8. Key Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Generate-more state machine more complex than expected | High | T1 spike discovers reality before T10 commits to design |
| Pushable SSE insufficient for generate-more | Medium | Spike (T1) validates this early; fallback is WebSocket |
| Card/Table backward compat broken by enhancements | Low | T6 tests verify existing usage unchanged |
| Context window too small for T7 (deck shell) | Medium | Deck shell is the largest task at ~45%; can split into T7a/T7b if needed |
| AlpineJS adapter doesn't support new component patterns | Low | New components follow existing adapter pattern; adapter is well-understood |
| CDN loading conflicts (Mermaid + Prism + Chart.js) | Low | Each loads lazily only when component is used; no global conflicts expected |

---

## 9. File Summary

| File | Purpose |
|------|---------|
| `docs/visual-skills/implementation/plan.md` | This file -- how to run the ralph-loop |
| `docs/visual-skills/implementation/tasks.md` | All 15 tasks with specs |
| `docs/visual-skills/implementation/STATE.md` | Live execution state (create at start) |
| `docs/visual-skills/implementation/spike-findings.md` | T1 output, consumed by T10 |
| `docs/visual-skills/SESSION-CONTEXT.md` | Overall project context |
| `docs/visual-skills/design/architecture.md` | Architecture reference |
| `docs/visual-skills/design/review-synthesis.md` | Post-review decisions |
| `docs/visual-skills/analysis/components.md` | Component inventory |
