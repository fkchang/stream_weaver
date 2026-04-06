# Review Synthesis: DHH + Codex Second Opinion

## Verdict
Both reviewers approve the architecture. "Fundamentally sound" (DHH). "Solid" (Codex).
The DSL design is the strongest element — both reviewers independently praised it.

---

## Where Both Reviewers Agree

### 1. Merge redundant components
- **VeCard → Card** with `depth:` option
- **DataTable → Table** with `sticky_header:`, `alternating:`, `scrollable:` options
- **ProgressIndicator → progress_bar** with `position: :fixed` variant
**Action:** Reduce component count from ~50 to ~35. Collapse CSS-only wrappers.

### 2. DSL reads beautifully
Both independently called out Section 10 examples as excellent. "Reads like prose" (DHH).
"DSL-first approach is well-reasoned" (Codex). No changes needed here.

### 3. Flat namespace is correct
Both approve. Shared components alongside existing ones. Deck subsystem namespaced.

### 4. Design deck as DSL methods, not subclass
Both approve. `design_deck` is like `tabs` or `modal`.

### 5. All 9 open questions mostly well-answered
DHH: "All nine recommendations are sound."
Codex: "Agree on 7 of 9" (disagrees on Q1 and partially on Q9).

### 6. Phase 1 (shared foundation) is correctly prioritized
Both agree: Mermaid, CodeBlock, theme enhancements first.

### 7. Polling for generate-more is acceptable
Both agree polling is fine for an operation that takes 5-15 seconds.
Codex suggests long-polling as documented future optimization.

---

## Where They Differ

### State Management (Q1)
- **DHH:** "Start with server session (A). Do not prematurely optimize."
- **Codex:** "Start with file-backed state (B) from day one. Cookie overflow is when-not-if."
- **Resolution:** Codex is right here. User-generated notes make cookie overflow likely with 5+ slides. File-backed state is trivially harder to implement but avoids a painful mid-stream migration. **Go with (B).**

### Generate-More Complexity
- **DHH:** "Kill the state machine. Queue, poll, push. Three steps."
- **Codex:** "The state machine is too simple — missing CANCELLED, ERROR, PARTIAL states."
- **Resolution:** Both are right from different angles. DHH says don't over-plan it; Codex says don't under-plan it. **Compromise: spike it first** (Codex's recommendation). The spike will reveal which edge cases matter. Don't design the state machine on paper — discover it through implementation.

### Component Count
- **DHH:** "Cut by 40%. A div with a CSS class is still a div."
- **Codex:** "Slightly high but defensible. 50 is manageable."
- **Resolution:** **DHH is right.** Merge the CSS-only wrappers. The bar for a new component class should be "does it have behavior or state?" not "does it have styling?" Target ~30-35 components.

### Skill Entry Points (Section 6.5)
- **DHH:** "Kill them. The DSL is the API."
- **Codex:** "Start with Claude Code custom commands (option C)."
- **Resolution:** **DHH is right for the gem itself** — no Skill classes in StreamWeaver. **Codex is right for the agent integration** — custom commands are the right glue layer, living outside the gem.

---

## New Issues Raised (Codex Only)

### Must Address Before Implementation
1. **`beforeunload` / tab-close cancellation** — if user closes tab, `run_once!` hangs forever. Need a cancellation path. Critical.
2. **State ownership table** — document what state lives where (server/client/localStorage) and how it syncs. Essential for implementation clarity.
3. **Agent process lifecycle** — heartbeat, crash recovery, clean shutdown of polling thread when `run_once!` resolves.
4. **CSS naming convention** — enforce `sw-` prefix, define specificity rules before 35 components ship.

### Should Address (Medium Priority)
5. **Accessibility requirements** — `aria-live`, `aria-current`, `aria-busy` for key components.
6. **Scalability section** — soft limits (10 slides, 50 files) and hard limits (20 slides, 200 files).
7. **Phase 2 splitting** — 2a (slide nav), 2b (deck+selection), 2c (summary). Incremental validation.
8. **Integration test checkpoints** between phases.
9. **Double-submit prevention.**

### Can Defer (Low Priority)
10. **JSON-over-HTTP API** — secondary protocol for non-Ruby agents. Phase 5.
11. **Long-polling optimization** — document as future path.
12. **CDN fallback / offline degradation.**
13. **Touch/swipe navigation.**

---

## Revised Architecture Changes

Based on both reviews, the architecture should be updated:

### Component Changes
| Original | Revised | Rationale |
|----------|---------|-----------|
| VeCard | Card with `depth:` option | DHH + Codex agree |
| DataTable | Table with `sticky_header:` etc. | DHH + Codex agree |
| ProgressIndicator | progress_bar with `position: :fixed` | DHH |
| HeroSection | div with CSS class via `hero` DSL helper | DHH |
| Prose | div with CSS class | DHH |
| Pullquote | div with CSS class | DHH |
| FlowArrow | CSS-only, no component class | DHH |
| Legend | CSS-only, no component class | DHH |
| DesignDeckSkill | Removed (DSL is API) | DHH |
| VisualExplainerSkill | Removed (DSL is API) | DHH |

### State Management Change
- Cookie session → File-backed state (write JSON to temp file per session)
- Implement `DeckState` object abstracting storage backend (Codex)

### Generate-More Change
- Spike before designing state machine
- Phase 3 becomes "spike + implement based on findings"

### New Documentation Sections
- State ownership table
- CSS naming convention (`sw-` prefix)
- Accessibility requirements
- Scalability limits
- Agent lifecycle (heartbeat, crash, shutdown)

### Phase Refinement
- Phase 2 → 2a/2b/2c (incremental validation)
- Phase 5 → 5a/5b (utility components vs workflow features)
- Add integration test checkpoints

---

## Revised Component Count: ~32

### Shared (8, down from 9)
Mermaid, CodeBlock, ImageBlock, SlideContainer, KeyboardShortcuts,
Toast, HtmlExporter, Chart

### Deck (9, down from 10)
DesignDeck, DeckSlide, DeckOption, DeckSummary,
GenerateMoreControls, SkeletonPlaceholder, ModelSelector,
ConfirmationBar, CloseOverlay

### Explainer-specific (5, down from 19)
SidebarToc, Comparison, Pipeline, Callout, KpiDashboard

### Enhanced existing (10, down from 12)
Card (+depth), Table (+sticky/alternating/scrollable),
Grid, Alert, StatDisplay, Collapsible, ProgressBar (+fixed),
RadioGroup, Theme (+presets/auto), AlpineJS adapter

### CSS-only helpers (no component class, just DSL methods wrapping div)
hero, prose, pullquote, dir_tree, legend, flow_arrow, layout_toggle

**Total: ~32 component classes + ~7 CSS helpers = ~39 DSL methods**
