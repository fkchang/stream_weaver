# Generate-More Spike Findings (T1)

*Date: 2026-03-12*
*Status: Complete*
*Consumed by: T10 (Generate-More Full Implementation)*

---

## 1. State Machine (Discovered)

The architecture doc predicted three states (IDLE, GENERATING, TIMED_OUT). Implementation revealed **four** are needed:

| State | Description | Entry Condition |
|-------|-------------|-----------------|
| `:idle` | No generation in progress. Generate button enabled. | Initial, or all options received, or timeout dismissed, or cancel complete |
| `:generating` | Request queued, skeletons visible, cancel button shown. | User clicks Generate |
| `:timed_out` | 15s elapsed. Warning shown, Generate re-enabled. | Server-side timer detects elapsed > 15s |
| `:cancelled` | User requested cancellation. Transient state. | User clicks Cancel during `:generating` |

### Transitions

```
idle -> generating       (user clicks Generate)
generating -> idle       (all options received: received_count >= requested_count)
generating -> timed_out  (server-side timer: elapsed > 15s)
generating -> cancelled  (user clicks Cancel)
cancelled -> idle        (agent thread acknowledges, cleanup completes)
timed_out -> idle        (user clicks Generate again, or page refresh)
```

### Why `:cancelled` is needed

Originally tried cancelling by flipping directly to `:idle`, but the agent thread had a race window: it could push an option between the cancel request and the next cancellation check. The `:cancelled` state acts as a "stop flag" that the agent thread checks before each push. Once acknowledged, it transitions to `:idle`.

### Alternative: Signal-based cancellation

Instead of a state, cancellation could be a flag in a separate channel (as implemented in the spike via `SpikeState.cancel(session_id)`). This separates "agent should stop" from "UI state." T10 should evaluate whether the cancelled state should be part of the state machine or a side-channel flag. The spike used both: a side-channel flag for the agent thread, and a transient `:cancelled` state that resolves to `:idle`.

---

## 2. Push-to-State: Validated

### What works

The core pattern works as designed:
1. Agent pushes option data into a shared server-side state store
2. After each push, `streamer.replace("#target", html)` sends re-rendered content
3. Browser receives complete HTML and morphs the DOM (via htmx + Alpine morph)
4. No phantom option race -- content is always rendered from current state
5. No partial/stale state -- each push renders the entire content area

### What the architecture doc got right

- Eliminating push-to-DOM avoids phantom options entirely
- Summary slide stays in sync because it reads the same state
- Simpler than SSE-to-DOM with multiple targets

### Key constraint discovered: Full re-render vs. incremental

The spike re-renders the ENTIRE content div on each option push. This works fine for 2-10 options. For 50+ options, T10 should consider:
- Append mode: SSE appends just the new option card, only if on the correct slide
- Or: continue full re-render but optimize the HTML size (skip unchanged options)

For the expected use case (2-5 generated options at a time), full re-render is fine.

---

## 3. Session State Architecture: Critical Finding

### The problem

StreamWeaver's existing state lives in `session[:streamlit_state]` -- a Sinatra cookie session. The agent thread (which pushes state) has **no access** to this session:

- Cookie sessions are per-HTTP-request, scoped to the Rack middleware
- Background threads (agent simulator, timer threads) cannot read or write cookie sessions
- Even if they could, cookie size limit (4KB) would be exceeded by option data

### The solution: External state store

The spike uses an in-memory hash (`SpikeState`) keyed by session ID:
- Session ID is stored in the cookie session (`state[:spike_session]`)
- The App DSL block reads from `SpikeState.get(session_id)` during render
- The agent thread writes to `SpikeState.update(session_id)` when pushing options
- Thread-safe via Mutex

### T10 recommendation

Implement `DeckState` as a file-backed JSON store (as planned in architecture doc):
- Session ID assigned on first visit, stored in cookie
- Full state persisted to `tmp/streamweaver/sessions/{session_id}.json`
- The `App` DSL block reads from `DeckState` during render
- Agent pushes to `DeckState` via HTTP endpoint or direct file write
- Mutex or file locking for thread safety

This aligns with the Q1 resolution (file-backed state, option B) from the architecture doc.

---

## 4. SSE Integration: Works As-Is

StreamWeaver's existing `Streamer` infrastructure works for push-to-state with no modifications:

- `streamer.replace("#target", html)` broadcasts to all SSE connections
- The browser's SSE handler (already built into StreamWeaver's JS) receives the event and morphs the target element
- No new SSE event types needed -- `replace` is sufficient
- No modifications to `Pushable`, `Streamer`, or `Feed` required

### Minor concern: `stream` block pattern

The spike uses the `stream` block to capture the streamer reference and run a timeout checker:

```ruby
stream do |streamer|
  $streamer_ref = streamer
  loop do
    sleep 1
    # check timeouts
  end
end
```

This works but feels like an abuse of the stream block (which is designed for app-defined push logic, not infrastructure). T10 should consider whether timeout checking should be a timer (`every(1)`) or a separate mechanism.

---

## 5. Timeout Handling

### What works

Server-side timeout checking (in the stream/timer block) detects `:generating` states that have exceeded 15 seconds and transitions them to `:timed_out`. This is reliable because:
- It doesn't depend on the browser being connected
- It doesn't depend on the agent being responsive
- It runs independently of any request

### Edge case: Partial receipt

If 2 of 3 options arrive before timeout, the user sees 2 real options + 1 skeleton, then a timeout message. The received options are preserved in state. This is the correct behavior -- partial results are better than no results.

### T10 consideration: Configurable timeout

15 seconds is hardcoded in the spike. T10 should make this configurable:
```ruby
generate_more timeout: 30  # or whatever
```

---

## 6. Cancellation

### What works

Two-phase cancellation:
1. User clicks Cancel -> sets a cancellation flag
2. Agent thread checks flag before each option push
3. If cancelled, agent stops generating and transitions to `:idle`
4. SSE pushes re-rendered content (options received so far are preserved)

### Edge case: Race between cancel and push

If the agent pushes an option at the exact moment the user cancels, the option is still added to state. This is acceptable -- the user gets one extra option, which is harmless.

### Edge case: Cancel arrives after all options received

If the user clicks cancel but all options have already been received (`:generating` already transitioned to `:idle`), the cancel is a no-op. This is correct.

---

## 7. Edge Cases Found

| Edge Case | What Happens | Severity |
|-----------|-------------|----------|
| Double-click Generate | Second click is a no-op (button hidden during `:generating`) | Low -- handled |
| Cancel after timeout | No-op (already `:timed_out`) | Low -- handled |
| Page refresh during generation | New render reads current state, shows received options + skeletons | Medium -- works correctly |
| Agent dies mid-generation | Timeout fires after 15s, preserves partial options | Medium -- handled by timeout |
| Multiple browser tabs | All tabs share same session state (via session ID in cookie) | Low -- acceptable for spike |
| Very long prompt text | No issue (prompt stored in state, displayed in descriptions) | Low |
| Rapid generate-cancel-generate | Works but agent thread may have stale request in queue | Medium -- T10 should add request versioning |

### T10 should address: Request versioning

If a user clicks Generate, then Cancel, then Generate again quickly, the agent thread may still be processing the first request while the second is queued. T10 should add a `request_id` or version number to distinguish stale requests from current ones.

---

## 8. Decisions for T10

| Decision | Spike Choice | T10 Recommendation |
|----------|-------------|-------------------|
| State store | In-memory hash | File-backed JSON (DeckState) |
| Re-render scope | Full content div | Full content div (adequate for <= 10 options) |
| Cancellation | Side-channel flag + transient state | Keep side-channel flag pattern |
| Timeout detection | Stream block loop | Timer (`every(1)`) or dedicated infrastructure |
| Agent communication | Direct shared memory | HTTP endpoints (`POST /deck/add_option`, `GET /deck/pending`) |
| Skeleton rendering | Inline HTML | Component class (`SkeletonPlaceholder`) |
| Status display | Inline HTML banner | Component class (`GenerateMoreControls`) |

---

## 9. What StreamWeaver Needs (Gem Changes for T10)

### No changes needed to existing infrastructure

- `Pushable` module: works as-is
- `Streamer` class: works as-is
- `Feed` class: works as-is (for external agent pushing)
- SSE endpoint (`GET /stream`): works as-is
- Push endpoint (`POST /stream/push`): works as-is

### New additions needed

1. **`DeckState` class** -- File-backed state store keyed by session ID
2. **Custom routes** -- `POST /deck/generate`, `GET /deck/pending`, `POST /deck/add_option`
3. **`GenerateMoreControls` component** -- DSL method for generate UI
4. **`SkeletonPlaceholder` component** -- Shimmer loading cards
5. **State-change SSE notification** -- `streamer.notify_state_change` (or reuse `replace`)
6. **Timeout timer** -- Server-side timer checking generate timeouts

### Nice-to-have

- `notify_state_change` method on Streamer that triggers a full page re-render (instead of replacing a specific target). Currently the spike uses `replace("#spike-content", html)` which requires rendering HTML outside the DSL block. A `notify_state_change` that tells the browser to re-fetch `/update` would be cleaner and more aligned with StreamWeaver's reactive model.

---

## 10. Summary

**Push-to-state works.** The spike validates the core architectural decision. The pattern is:
1. User action sets generate state to `:generating`
2. Skeletons appear (rendered from state by the component tree)
3. Agent pushes options to a shared state store
4. SSE notifies browser to re-render
5. Component tree reads updated state, renders new options + remaining skeletons
6. When all options received, state returns to `:idle`

**Key constraint:** Session state MUST be in a server-side store accessible to background threads. Cookie sessions are insufficient. File-backed JSON (DeckState) is the right approach.

**The existing StreamWeaver Pushable/Streamer/Feed infrastructure works without modification** for the push-to-state pattern. The only new infrastructure needed is the state store and the HTTP endpoints for agent communication.
