# Architecture Review: StreamWeaver Visual Skills

*Reviewer: Claude Opus (second-opinion review)*
*Date: 2026-03-12*
*Document under review: `architecture.md` (1618 lines)*

---

## Overall Assessment

This is a well-structured architecture document. The design philosophy is sound -- "The DSL IS the API" is the right bet, and the decision to follow existing StreamWeaver patterns rather than introduce parallel systems will pay dividends. The overlap analysis is thorough and the 37% shared figure is credible.

That said, there are several areas where I see risk, over-engineering, or missing considerations. This review is organized around the nine focus areas requested.

---

## 1. Agent Communication Protocol (Section 6)

### The Good

"Agent writes Ruby script, runs it, reads stdout" is the correct primary protocol for the StreamWeaver ecosystem. It leverages the existing `run_once!` pattern and keeps the DSL as the single source of truth. For agents that already run in a Ruby-capable environment (Claude Code, Pi), this is zero friction.

### The Concern: Agents That Cannot Run Ruby

The design acknowledges only one protocol. What about:
- **Web-based agents** that can make HTTP calls but cannot execute arbitrary Ruby
- **Codex** running in a sandboxed environment where `ruby` may not be available or the gem may not be installed
- **Multi-agent orchestration** where a coordinator dispatches to StreamWeaver without running Ruby locally

**Recommendation:** Add a thin JSON-over-HTTP API as a secondary protocol. Not as the primary path, but as a fallback. The `Skills` classes in Section 6.5 already accept structured data (`slides:` as an array of hashes). Expose that same interface as a POST endpoint:

```
POST /api/deck { title: "...", slides: [...] }
POST /api/explainer { title: "...", sections: [...] }
```

The server translates JSON to DSL calls internally. This is a small surface area (two endpoints) and dramatically widens the agent compatibility story. It can be Phase 5 work -- it does not block the core implementation -- but it should be in the design document as a planned extension rather than absent entirely.

### The Concern: `run_once!` Lifecycle and Generate-More Tension

The `run_once!` pattern assumes a single request-response cycle: start, collect input, return result, shut down. But the generate-more loop requires the agent script to remain active and responsive *during* user interaction. The document shows this with a `Thread.new` polling loop, but the implications are under-explored:

- The agent script must now be a long-running process, not a fire-and-forget script
- If the agent's Ruby process crashes mid-session, the user is stuck with a dead Generate button
- The `run_once!` shutdown trigger (submit) must cleanly terminate the polling thread

This is workable but the document should explicitly address the lifecycle: how does the polling thread know to stop? What happens if the agent process is killed? The heartbeat/watchdog from pi-design-deck seems relevant here and is mentioned in the overlap analysis but absent from the architecture.

---

## 2. Generate-More Loop (Section 7)

### Polling is the Right Call -- With Caveats

I agree with the recommendation of polling over callbacks or stdout. The reasoning is correct: simplicity wins when the operation being waited on (LLM generation) takes 5-15 seconds anyway. A 1-2 second poll interval is noise.

### What is Missing

**Concurrency prevention is unaddressed.** The original pi-design-deck has explicit concurrent-generation prevention. What happens if the user clicks "Generate" twice quickly? The document shows `settings.generate_requests << request` using a simple append -- there is no deduplication or "already generating for this slide" guard. This needs to be in the state machine diagram.

**The state machine is too simple.** It covers the happy path and the timeout path. Missing states:
- **CANCELLED** -- user navigates away from the slide while generation is in progress
- **ERROR** -- the agent's LLM call fails (rate limit, network error, context too long)
- **PARTIAL** -- some options arrive but the agent fails mid-batch

The state machine should also address: what happens to pending skeletons when the user navigates to a different slide and back? Are they preserved? Cleared?

**WebSockets vs. SSE vs. polling:** The document does not mention WebSockets at all. For this specific use case, SSE (which StreamWeaver already has) is the right answer for server-to-browser push, and HTTP polling is fine for browser-to-agent communication. WebSockets would add complexity without benefit since the communication is asymmetric: the browser rarely sends to the server outside of form actions. This is the correct architecture, but the document should explicitly note *why* WebSockets were not chosen, since a reviewer will ask.

**Long-polling as an alternative to polling:** Instead of the agent polling `/deck/pending` every 1-2 seconds, the server could hold the connection open until a request arrives (long-polling). This eliminates latency entirely and reduces unnecessary HTTP requests. The implementation is slightly more complex but well-understood. Worth mentioning as a future optimization even if not implemented in Phase 3.

---

## 3. State Machine Complexity

### The Concern: State Sprawl

The deck accumulates state from multiple sources:
- `state[:deck_selections]` -- slide_id -> option_label (core)
- `state[:deck_notes]` -- option-level notes (many keys)
- `state[:deck_generate]` -- generation status, timestamps
- `state[:_result]` -- submission payload
- Implicit state: current slide index (Alpine.js client-side), dirty tracking, layout override

This is spread across server session (cookie), client-side Alpine.js `x-data`, and localStorage. The document does not have a single "state map" showing where each piece of state lives and how they synchronize.

**What could go wrong:**
1. **Cookie size limit.** The recommendation says "start with server session, upgrade if needed." But `deck_notes` is variable-length user input. If each of 10 slides has a 200-character note, plus option notes, you can easily hit 4KB. I would recommend starting with (B) file-backed state from day one -- it is not significantly harder and avoids a mid-stream migration.

2. **Stale state after SSE push.** When a new option arrives via SSE, the client DOM updates but does the Alpine.js reactive state update? The option count changes, the selection set might need resetting, the summary slide's "Still need" list changes. The document says "needs validation" for Alpine + SSE integration (Section 4.12 in components.md) but the architecture should not leave this as a "maybe it works" -- it is load-bearing.

3. **Dirty tracking across server and client.** The original pi-design-deck tracks dirty state entirely client-side (localStorage). The architecture routes through server sessions. If the user modifies a note, that is a POST to the server, a session update, and then the client needs to know "saved at HH:MM." This round-trip for every keystroke is either chatty or requires debouncing, which the document does not specify.

**Recommendation:** Create a state ownership table in the document:

| State | Owner | Sync Mechanism |
|-------|-------|---------------|
| Current slide index | Client (Alpine) | None needed |
| Selections | Client (Alpine) + Server (session) | POST on change |
| Notes | Client (Alpine) | POST on blur/debounce |
| Generate status | Server | SSE push to client |
| Dirty flag | Client | Computed from last-save timestamp |
| Layout override | Client (localStorage) | None needed |

---

## 4. Component Count: 50 Components

### Assessment: Slightly High But Defensible

The inventory lists approximately 50 components (9 shared, 10 deck, 19 explainer, 12 enhanced existing). This is a lot, but the breakdown reveals that many are small:

- **Genuinely complex:** Mermaid (zoom engine), SlideContainer (two modes), DesignDeck (orchestrator), SidebarToc (scroll spy), GenerateMoreControls (state machine)
- **Medium:** CodeBlock, Chart, DataTable, DeckSummary, HtmlExporter
- **Simple (CSS wrapper + div):** VeCard, Callout, Prose, Pullquote, HeroSection, Legend, FlowArrow, DirTree, SkeletonPlaceholder, ConfirmationBar, CloseOverlay, LayoutToggle, Pipeline, Comparison

### Components That Should Be Merged

1. **`VeCard` and `Card`**: The document argues against merging because "Card has header/body/footer sub-components." But `VeCard` is just Card with a `depth:` option and no sub-components. Consider adding `depth:` to the existing Card and using it without sub-components. Two card types will confuse agent prompt engineering ("when do I use `card` vs `ve_card`?").

2. **`DataTable` and `Table`**: Same argument. The document says they "serve different use cases" but the DSL distinction (`table` vs `data_table`) will confuse agents. Better: enhance `Table` with the sticky/hover/scrollable options and keep one component name. The different input formats (positional, file, headers+rows) can coexist.

3. **`code_file` (from components.md 3.9) and `code_block`**: The document already implicitly merged these (code_block has a `file:` option). Good. Just make sure components.md is updated to reflect this.

4. **`ProgressIndicator` and `progress_bar`**: The existing `progress_bar` with a `position: :fixed` variant seems sufficient. Adding a new name for what is visually the same element creates confusion.

### Components That Might Be Missing

1. **`Tabs` for explainer pages** -- multi-section pages where the user switches between views (e.g., "By File" vs "By Severity" in a diff review). StreamWeaver has tabs, but are they compatible with the explainer's use patterns?

2. **`Badge` variants for status in data tables** -- the document mentions "status badges rendered as styled spans" but does not define how the agent specifies them within row data. The `{ status: :match, label: "Match" }` hash syntax in the DataTable example needs a rendering rule.

3. **`Tooltip`** -- the deck has `description:` on options that is described as "hover text." How is this rendered? A native `title` attribute, or a styled tooltip component?

---

## 5. Five-Phase Implementation Sequencing

### Phase 1 (Shared Foundation) -- Correct

Building shared components first is the right call. No notes.

### Phase 2 (Design Deck Core) -- Correct but Large

Phase 2 is 6 items but includes the `DesignDeck` orchestrator, which is the single most complex piece. The risk is that it takes longer than estimated and delays everything after it. Consider splitting Phase 2 into:
- **2a:** SlideContainer (:swap mode) + ProgressIndicator + keyboard nav -- these are useful independently
- **2b:** DesignDeck + DeckSlide + DeckOption + selection state
- **2c:** DeckSummary

This lets you validate slide navigation before coupling it to the deck's selection logic.

### Phase 3 (Generate-More Loop) -- Correct Placement

Separating generate-more from deck core is wise. The deck is useful without generate-more. Ship Phase 2 and get user feedback before investing in the polling infrastructure.

### Phase 4 (Visual Explainer Core) -- Hidden Dependency

Phase 4 depends on the `HtmlExporter` from Phase 1. But the explainer also needs the *static export* path to be working end-to-end (write file, open in browser). This is a thin integration test but it should be called out: Phase 4 cannot be validated without a working export pipeline.

### Phase 5 (Polish) -- Too Much in One Phase

Phase 5 is a grab bag of 9 items with wildly different effort levels (ModelSelector: medium, FlowArrow: small, Animation choreography: medium, Skill entry points: medium). Consider splitting:
- **5a:** Typography and utility components (Prose, Pullquote, DirTree, etc.) -- small, can be done in parallel
- **5b:** ModelSelector + Save/Load + Animation -- medium, interdependent with deck workflow
- **5c:** Skill entry points -- this is really Phase 6, since it depends on everything else being stable

### Missing Phase: Integration Testing

There is no phase for end-to-end validation. After Phase 2, someone should write a real design deck script and test the full flow: write script, run it, make selections, submit, read result. After Phase 4, someone should generate a real diff review page. These integration checkpoints should be explicit.

---

## 6. Open Questions Evaluation

### Q1 (Deck State: Server vs. Client) -- Disagree with Recommendation

The recommendation is "start with server session (A), upgrade if needed." As noted in Section 3 above, I think file-backed state (B) should be the starting point. The cost is minimal (write JSON to a temp file, read it back) and avoids the cookie-size cliff. Cookie-based session is fine for StreamWeaver's typical use (small form state), but the deck's state profile is different: variable-length user-generated notes make cookie overflow a when-not-if issue.

### Q2 (Adapter Extension) -- Agree

The hybrid approach (adapter for interactive, self-render for display) is pragmatic and matches the existing codebase. Good call.

### Q3 (Polling vs. Callback) -- Agree with Caveat

Polling is fine. Add long-polling as a documented future optimization path. Also document the poll interval as configurable (default 1s, adjustable for low-latency use cases).

### Q4 (Deck as App Subclass) -- Agree

DSL methods on App is correct. The deck is a component composition, not a new application type. The conditional route registration is a minor wart but far less painful than a class hierarchy.

### Q5 (DisplayDSL vs. App) -- Agree

Display components in DisplayDSL enables Feed-based push of rich content. This is exactly right for generate-more.

### Q6 (Mermaid Re-rendering) -- Agree

Calling `mermaid.run()` after SSE insertion is the simplest approach. MutationObserver adds complexity and is harder to debug. One note: ensure that `mermaid.run({ nodes: [newElement] })` scopes the re-render to the new element only, not the entire page. Full-page re-render on every SSE push would cause visible flicker on existing diagrams.

### Q7 (Anti-Slop) -- Agree

Documentation-only is correct for now. Theme presets are the enforcement mechanism. If slop becomes a problem, the fix is better prompts, not runtime CSS policing.

### Q8 (Comparison Block Syntax) -- Agree

Named blocks (`before`/`after`) are the most readable. This matches existing StreamWeaver patterns.

### Q9 (Explainer Slash Commands) -- Partially Disagree

The recommendation is (B) initially, (A) eventually. I agree with starting outside StreamWeaver, but I think (C) Claude Code custom commands is the better initial home, not standalone scripts. Custom commands are already the agent integration point -- they live in the project, they are discoverable, and they naturally separate data-gathering (agent-side) from rendering (StreamWeaver-side). Standalone scripts have no discoverability and will drift.

---

## 7. Scalability Concerns

### 20-Slide Deck

The design is implicitly optimized for 3-8 slides (the typical design-decision deck). At 20 slides:
- **Cookie overflow:** Near-certain with server session state. File-backed state is essential.
- **Summary slide:** 20 summary cards in a grid will be visually overwhelming. Consider pagination or grouping.
- **Navigation:** Linear Back/Next through 20 slides is tedious. Consider adding a slide picker (dropdown or thumbnail strip) as a navigation shortcut.
- **Memory:** 20 slides with Mermaid diagrams each means 20 Mermaid render calls. Mermaid.js is not lightweight -- each render involves SVG generation. Lazy rendering (only render the active slide's diagrams) would help.

### 500-File Diff Review

This is the real scalability stress test. A diff review with 500 changed files means:
- **SidebarToc:** 500 entries in the sidebar TOC is unusable. Need grouping by directory or category, with collapsible sections.
- **IntersectionObserver:** 500 observed elements could cause performance issues on scroll. Batch observation, use a single observer with root margin, or virtualize.
- **Page weight:** 500 code blocks with Prism.js highlighting is a lot of DOM. Consider pagination (show 20 files at a time with "load more") or virtual scrolling.
- **HTML export:** A self-contained HTML file with 500 highlighted code blocks could be 5-10MB. This may be fine for local viewing but brutal for Vercel deployment.
- **Generation time:** The agent generating 500 file reviews is already slow. But the *rendering* should not add to the pain. Ensure the DSL-to-HTML path is O(n) and does not have quadratic behaviors (e.g., repeated CSS generation per component).

**Recommendation:** Add a "Scale Considerations" section to the architecture document. Define soft limits (recommended: up to 10 slides, up to 50 files) and hard limits (tested: up to 20 slides, up to 200 files). For beyond-limits use cases, document the degradation strategy (pagination, grouping, lazy loading).

### CDN Latency

The document notes "CDN latency is acceptable" for a local dev tool. True for first load, but Mermaid.js alone is ~2MB. If the user has a cold cache or is offline (airplane, VPN tunnel), the page will be broken. Consider:
- A local fallback for the most critical CDN assets (Mermaid, Prism)
- A "pre-warm" step that downloads CDN assets on gem install
- Graceful degradation: show raw code/text if Prism/Mermaid fail to load

---

## 8. Missing Features

Comparing the overlap analysis against the architecture:

### Covered Well
- Mermaid rendering (both modes)
- Code highlighting
- Theme system
- Keyboard shortcuts
- HTML export
- Slide navigation (both modes)
- Selection and generate-more
- All major explainer components

### Missing or Under-Specified

1. **Heartbeat/Watchdog (from pi-design-deck Section 2.10):** The original deck has a 5-second heartbeat with 60-second grace period and idle timer. The architecture mentions none of this. If the browser tab is closed or the network drops, the agent script should know. StreamWeaver's existing SSE could serve as the heartbeat (connection drop = client gone), but this needs to be explicit.

2. **Touch/Swipe Navigation (from visual-explainer):** The overlap analysis lists touch swipe support. The architecture mentions `keyboard_nav` but not touch. For scroll-snap mode, CSS handles the basic case, but the 50px swipe threshold and explicit touch handling from the explainer are not covered.

3. **Accessibility (ARIA):** The DeckOption section mentions `role="radio"` and `aria-checked`, which is good. But the rest of the architecture is silent on accessibility. The slide container needs `aria-live` for slide transitions. The sidebar TOC needs `aria-current`. The generate-more skeleton needs `aria-busy`. Add an "Accessibility Requirements" subsection.

4. **Auto-Trigger on Complex Tables (from visual-explainer Section 3.1):** This agent-side behavior (automatically rendering tables with 4+ rows as HTML) is not addressed. It is agent logic, not StreamWeaver logic, but the skill entry point should at least accept a flag like `auto_visual: true` that tells the rendering to upgrade tables.

5. **Vercel Deployment / Share (from visual-explainer Section 3.6):** Mentioned in the overlap analysis but absent from the architecture. Even if it is out of scope for initial phases, it should be listed as a future extension.

6. **`beforeunload` Handler:** The original deck sends a beacon on tab close. This is important for clean shutdown of `run_once!`. The architecture relies on `run_once!` blocking until submit, but what if the user closes the tab without submitting? The agent script would hang indefinitely. Need a cancellation path.

7. **Double-Submit Prevention:** The original deck prevents double-submit on the summary slide. Not mentioned in the architecture.

8. **surf-cli Image Generation:** The optional Gemini-powered image generation from visual-explainer. This is clearly out of scope for initial implementation, but worth listing as a future integration point.

---

## 9. Risk Assessment

### Biggest Risk: Generate-More Loop Complexity

The generate-more loop is the riskiest feature. It introduces:
- Bidirectional communication between three parties (browser, server, agent)
- A long-running agent process with a polling thread
- Race conditions between user navigation and async option delivery
- Timeout handling across two processes
- DOM manipulation of content that contains embedded JavaScript (Mermaid init)

This feature alone accounts for ~20% of the estimated effort and contains the highest density of edge cases. If any single feature needs a spike/prototype before committing to the design, it is this one.

**Mitigation:** Phase 3 is correctly separated from Phase 2. Ship the deck without generate-more first. Validate the core selection/submission flow. Then tackle generate-more as a separate effort with its own spike.

### Most Likely to Need Rework: State Management

The hybrid state approach (server session + client Alpine + localStorage) will accumulate inconsistencies. The most likely rework scenario: discovering mid-implementation that cookie-based sessions cannot hold deck state, requiring a migration to file-backed state that touches every route handler.

**Mitigation:** Start with file-backed state (recommendation above). Also, centralize state access behind a `DeckState` object that abstracts the storage backend.

### Second Most Likely Rework: CSS Architecture

50 components means a large CSS surface area. The document plans to add visual skills CSS as additional sections in `StreamWeaver::CSS`. But there is no mention of:
- CSS naming convention (BEM? `sw-` prefix?)
- Specificity management (what happens when depth-tier styles conflict with card styles?)
- CSS custom property namespacing (the example uses `--sw-vs-*` which is good, but is this enforced?)

Without a CSS architecture, the 50 components will accumulate specificity conflicts and !important overrides.

**Mitigation:** Define a CSS convention in the architecture document. The `sw-` prefix is already used in examples (`sw-mermaid-wrap`, `sw-code-block`). Make this explicit and enforce it.

### Lower but Non-Zero Risk: CDN Dependency

The architecture depends on four CDN-hosted libraries (Mermaid, Prism, Chart.js, Google Fonts). Any of these being down, rate-limited, or serving a breaking update will break the user experience. Mermaid.js in particular has had breaking changes between minor versions.

**Mitigation:** Pin CDN versions (already done: `mermaid@11`). Consider adding integrity hashes (`integrity="sha384-..."`) to CDN script tags. Document the offline degradation story.

---

## Summary of Recommendations

| # | Recommendation | Priority | Effort |
|---|---------------|----------|--------|
| 1 | Add JSON-over-HTTP API as secondary agent protocol | Low (Phase 5) | Small |
| 2 | Document agent process lifecycle (heartbeat, crash recovery, clean shutdown) | High | Doc only |
| 3 | Add CANCELLED, ERROR, PARTIAL states to generate-more state machine | High | Doc + Small code |
| 4 | Start with file-backed state instead of cookie session | High | Small |
| 5 | Create state ownership table (what lives where, how it syncs) | High | Doc only |
| 6 | Merge VeCard into Card (add `depth:` option) | Medium | Small |
| 7 | Merge DataTable into Table (add sticky/hover options) | Medium | Small |
| 8 | Split Phase 2 into 2a/2b/2c for incremental validation | Medium | Planning only |
| 9 | Add explicit integration test checkpoints between phases | Medium | Planning only |
| 10 | Add scalability section with soft/hard limits | Medium | Doc only |
| 11 | Address `beforeunload` / tab-close cancellation for `run_once!` | High | Small |
| 12 | Define CSS naming convention and specificity rules | Medium | Doc only |
| 13 | Add accessibility requirements subsection | Medium | Doc only |
| 14 | Spike the generate-more loop before committing to full implementation | High | Medium |

### Bottom Line

The architecture is solid. The DSL-first approach, the reuse of existing StreamWeaver patterns, the phased implementation, and the component decomposition are all well-reasoned. The main risks are in the generate-more loop (complex distributed state) and state management (hybrid storage). Both can be mitigated by spiking early and centralizing state behind an abstraction. The component count is manageable if you merge the redundant pairs (VeCard/Card, DataTable/Table).

Ship Phase 1, spike generate-more in parallel, and validate the full deck flow end-to-end before investing in polish.
