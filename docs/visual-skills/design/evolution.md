# Design Evolution Log

## Purpose
Track every design decision, iteration, and review so future LLMs (and humans)
can understand WHY the architecture looks the way it does.

---

## Entry 1: Analysis Phase Complete (2026-03-12)

### What we learned
- **37% overlap confirmed** — user predicted ~1/3, analysis yielded 37%
- **Token savings are asymmetric:** deck saves 30-45%, explainer saves 80-85%
- **The explainer's savings are architectural:** 30K tokens of design system in the prompt → 0 in framework code
- **50 components identified:** 9 shared, 10 deck, 19 explainer, 12 existing enhancements

### Decisions made
1. Analysis-first approach validated — parallel subagents with shared template produced consistent, comparable output
2. Gherkin as bridge format — 1003 lines of scenarios, detailed enough for implementation
3. 5-phase implementation sequence confirmed (shared → deck → explainer → polish → integration)

### Key risks identified
1. **Generate-more loop** is the hardest architectural challenge — Promise-based blocking in Pi doesn't map to StreamWeaver's reactive model
2. **Agent communication protocol** is bidirectional — agent needs to both send data (create deck) and receive results (user selections)
3. **CSS complexity** — visual-explainer has 40+ CSS components, 13 font pairings, 5 color palettes. Quality bar is high.

---

## Entry 2: OO Design Phase (2026-03-12, in progress)

### Design agent launched with:
- All 6 analysis artifacts as input
- 16 existing StreamWeaver source files for pattern matching
- Explicit instruction to be opinionated and flag genuine trade-offs
- Required outputs: module structure, class hierarchies, data flow diagrams, DSL examples

### Reviews completed:
- [x] DHH reviewer — "fundamentally sound, needs ruthless editing pass"
- [x] Codex second opinion — "solid, spike generate-more, file-backed state"
- [ ] User review of progression before implementation

---

## Entry 4: Review Synthesis (2026-03-12)

### Key outcomes from dual review
1. **Component count reduced 50 → ~32** by merging CSS-only wrappers into existing primitives
2. **State management changed** from cookie session to file-backed state (Codex convinced us)
3. **Generate-more: spike first** — both reviewers had different concerns; a spike will reveal which matter
4. **Skill entry points killed** — "the DSL IS the API" (DHH). Agent glue lives outside the gem as custom commands (Codex)
5. **5 new doc sections needed**: state ownership table, CSS convention, accessibility, scalability limits, agent lifecycle

### Where reviewers disagreed (and how we resolved)
- **State storage:** DHH said cookies, Codex said files → files (Codex is right about note overflow)
- **Generate-more complexity:** DHH said simpler, Codex said more states needed → spike it (both right from different angles)
- **Component count:** DHH said cut 40%, Codex said defensible → cut ~36% (DHH's instinct is right)

### Revised component count: ~32 classes + ~7 CSS helpers = ~39 DSL methods

---

## Entry 5: Gemini Adversarial Review (2026-03-12)

### Best insight: Push-to-state, not push-to-DOM
Gemini proposed that generate-more should push new options to server-side state and let
StreamWeaver's reactive re-render handle display, instead of pushing HTML snippets via SSE.
This aligns with StreamWeaver's existing model and solves the "phantom option" race condition
(user navigates away during generation). **Adopted as architecture change.**

### Good catch: Session-scoped request queue
Generate requests queued on the server must be scoped to session ID, otherwise stale
requests from killed agent processes persist. Neither prior reviewer caught this.

### Overruled: Token efficiency concern
Gemini argued DSL reference docs in agent context erode savings. Math doesn't support this:
~3K DSL reference vs ~30K CSS patterns = still 80%+ net savings. Overruled.

### Overruled: Component rot / plugin system
StreamWeaver is a bounded DSL, not a general-purpose UI framework. Component set is
intentionally focused. No plugin system needed.

### Running tally of reviews: 3 reviewers, all approve core architecture
- DHH: "fundamentally sound" — cut components, simplify generate-more
- Codex: "solid" — spike generate-more, file-backed state, accessibility
- Gemini: "push-to-state is better" — best architectural improvement so far

---

## Entry 3: Blog Series Recognized (2026-03-12)

### Insight
The process itself is generating multiple blog-worthy artifacts:
1. **Token efficiency** — the flagship technical argument
2. **Claude Code capabilities** — parallel analysis, quality of autonomous work
3. **Engineering process + GenAI** — specification depth as the new 10x multiplier
4. **Repeatable process** — skill extraction from a successful workflow

### Decision
Track blog material as we go rather than reconstructing after the fact.
The process IS the content.
