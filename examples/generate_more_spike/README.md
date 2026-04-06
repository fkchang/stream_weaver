# Generate-More Spike (T1)

Standalone spike demonstrating the generate-more loop using **push-to-state** architecture.

## How to Run

```bash
cd examples/generate_more_spike
ruby app.rb
```

The app opens at `http://127.0.0.1:4567` (or next available port).

## What It Demonstrates

1. **Generate More button** -- Enter an optional prompt and select how many options to generate (1-5).
2. **Skeleton placeholders** -- While generating, skeleton shimmer cards appear for pending options.
3. **Simulated agent** -- A background thread simulates an agent (polls for requests, sleeps 1-3s per option, pushes results to state).
4. **Push-to-state** -- New options are written to server-side shared state. SSE sends the re-rendered HTML to the browser. The browser never receives raw data -- it gets a fully rendered content div.
5. **Timeout** -- If generation takes longer than 15s, a timeout warning appears.
6. **Cancel** -- A cancel button aborts in-progress generation.
7. **Session isolation** -- Each browser session gets its own state keyed by session ID.

## Architecture Validated

### Push-to-State Pattern

The agent pushes options into a shared server-side state store, NOT directly into the DOM via SSE. StreamWeaver's existing `Streamer.replace()` sends the complete re-rendered HTML for the content div. This:

- Eliminates the phantom option race condition (user on different slide when options arrive)
- Keeps everything in sync automatically (no stale partial state)
- Aligns with StreamWeaver's reactive model (re-render from state)
- Is simpler than SSE-to-DOM with targeted element updates

### Key Finding: Session Cookie Limitation

The agent thread has NO access to Sinatra's cookie-based session. Push-to-state requires a server-side state store (in-memory hash, file-backed JSON, or similar) keyed by session ID. T10 must implement `DeckState` as a file-backed store, not rely on `session[:streamlit_state]`.

## State Machine

```
                        IDLE
                          |
                [user clicks Generate]
                          |
                          v
                    GENERATING
                   /     |      \
        [all received]   |   [user cancels]
               |    [timeout 15s]    |
               v         |          v
             IDLE    TIMED_OUT   CANCELLED
                         |          |
                    [retry/dismiss] [cleanup]
                         |          |
                         v          v
                        IDLE      IDLE
```

## Files

- `app.rb` -- The spike app (standalone, does not modify the gem)
- `README.md` -- This file
