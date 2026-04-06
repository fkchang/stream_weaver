# Gemini Review Assessment

*Date: 2026-03-12*
*Gemini CLI run from stream_weaver root with full file access*

## Gemini's Points and Our Assessment

### Point 1: Three-Party "Hanging" Problem — RIGHT
Tab-close leaves `run_once!` hanging. "Shimmering death" (skeletons that never resolve) is real.
Stale request scoping to session ID is a good catch neither prior reviewer raised.
**Action:** Design cancellation path. `run_once!` needs timeout/heartbeat abort. Session-scope requests.

### Point 2: DSL Rigidity "Visual Wall" — HALF-RIGHT
Agents will occasionally need precise layout control. But escape hatch already exists:
`div(style: "position: relative; top: 20px") { mermaid "..." }`.
**Action:** Document `div(style:)` as the explicit escape hatch. No new component needed.

### Point 3: Token Efficiency "Context Bloat" — WRONG
Gemini's math is off. Current: agent reads ~30K tokens of reference material. With DSL: ~2-3K tokens of
DSL reference. Net savings of 25K+ input tokens. Retry costs (~500 tokens) are dwarfed by savings.
Structured DSL is MORE debuggable than raw HTML, not less.
**No action needed.** 80-85% claim holds.

### Point 4: "Phantom Option" Race Condition — GOOD CATCH
User requests options for Slide A, navigates to Slide B, options arrive for Slide A.
Neither prior reviewer caught this specific race condition.
**Action:** Address in generate-more spike. Push to state, re-render on navigate-back.

### Point 5: Push-to-State Not Push-to-DOM — BEST INSIGHT
Instead of SSE pushing HTML snippets to DOM targets, push new options to server-side state
and let StreamWeaver's reactive re-render handle display. This:
- Eliminates phantom option problem
- Keeps summary slide in sync automatically
- Aligns with StreamWeaver's existing reactive model
- Is simpler than SSE-to-DOM approach
**Action:** Revise generate-more architecture to push-to-state. Significant improvement.

Disagree with "JSON-over-HTTP as primary protocol" — DSL is right for Ruby-capable agents.
JSON API is the secondary protocol (already planned for Phase 5 per Codex review).

### Point 6: Component Rot — MOSTLY WRONG
StreamWeaver is a bounded DSL for agent-to-browser communication, not a general-purpose UI framework.
"Interactive maps" and "multi-step forms" are out of scope. CSS changes don't require DSL changes.
Theme presets can be added without touching components.
**No action needed** beyond keeping component set focused.

## Changes to Incorporate

| Point | Action | Priority |
|---|---|---|
| Tab-close cancellation | Design heartbeat + abort for `run_once!` | High (spike) |
| Session-scoped requests | Scope generate queue to session ID | High (spike) |
| Escape hatch docs | Document `div(style:)` pattern | Medium (Phase 1) |
| Phantom option race | Address in spike | High (spike) |
| Push-to-state | Revise generate-more to push state not DOM | High (architecture change) |
