# StreamWeaver → Opal → NPM: Direction Document

**Author:** Forrest Chang  
**Date:** May 2026  
**Status:** Vision / Future Work — Do Not Pursue Until Prerequisites Met  
**Purpose:** Preserve this architectural vision so it's not lost. This is a north star, not a sprint.

---

## The Vision

StreamWeaver is currently a Ruby gem with a Sinatra server backend. The vision: **package StreamWeaver as an NPM module via Opal's "Sole" engine**, making it installable as:

```bash
npm install stream-weaver
```

This would allow JavaScript developers to use a Ruby-authored reactive UI framework **without knowing Ruby**. They import it, write component trees in JS (which would be Opal-transpiled Ruby API), and get all the same reactive rendering, component library, and DSL expressiveness — in their existing JS stack.

This is a compelling story for reaching the much larger JavaScript ecosystem while keeping the canonical source of truth in Ruby.

---

## What Already Exists

### Opal Adapter
`lib/stream_weaver/adapter/opal.rb` — an Opal-compatible adapter layer already exists. This was written with browser execution in mind.

### Opal Runtime
`lib/stream_weaver/opal/runtime.rb` contains:
- `OpalRuntime` — Opal-clean entry point
- `OpalBridge` — browser ↔ Ruby communication bridge
- `ReactiveState` — client-side reactive state, already Opal-clean

These three modules are **already ready** for Opal compilation. They have no server-side dependencies.

### JS Stubs
`lib/stream_weaver/opal/stubs/` contains stubs for:
- `marked.umd.js` — markdown rendering (browser equivalent of kramdown)
- `morphdom.min.js` — DOM diffing

### Opal Compatibility Spike
`bin/opal_spike.rb` — an existing spike script that tests which modules compile cleanly through Opal. Run this to audit current compilation status.

---

## What "Sole" Does

Opal's **Sole** engine is the build tool that makes Ruby→NPM publishing practical:

1. Reads your `.gemspec`
2. Generates a `package.json` from gem metadata
3. Compiles all Ruby source files to JavaScript via Opal
4. Creates an `index.js` entry point that exports your Ruby classes/modules as JS
5. Enables `npm publish` — the package is now installable like any JS library

The result: `npm install stream-weaver` gives a JS developer access to `StreamWeaver.canvas()`, reactive state, and all components, backed by Opal's Ruby runtime in the browser.

---

## The Technical Gap

### What Can't Run in a Browser

The current server layer has components that fundamentally cannot run in a browser:

| Server Concern | Why It Can't Go to Browser |
|---------------|---------------------------|
| Sinatra HTTP server | No server socket in browser |
| Canvas Bridge WebSocket server | No TCP listener in browser |
| `kramdown` gem (Markdown) | Server-side Ruby gem, no browser equivalent |
| File I/O for table loading | No filesystem access in browser |
| Prism.js CDN loading via server | Needs to be bundled or loaded differently |

### The Replacement Model

Instead of a server → client push model, the Opal version needs a **pure client-side reactive model**:

```
Ruby DSL (compiled by Opal) → OpalRuntime → OpalBridge → DOM
                                    ↕
                              ReactiveState
                              (in-memory, browser)
```

The server is replaced by in-browser reactive state. Component updates are DOM mutations, not WebSocket pushes.

**The good news:** `OpalRuntime`, `OpalBridge`, and `ReactiveState` already implement this model. They were written with Opal in mind.

### Remaining Gaps to Close

Before a full Opal build would succeed:

#### 1. `components.rb` — Server-Side Concerns
- `kramdown` calls need to be replaced with `marked.umd.js` (stub already exists)
- File I/O for table data loading needs an Opal stub or in-memory equivalent
- Any `require 'json'` or `require 'tempfile'` needs Opal stubs

#### 2. `display_dsl.rb` — Server-Side Concerns
- Prism.js loading pattern needs to be browser-native (script tag or bundled)
- Any server-side rendering helpers need client-side equivalents

#### 3. WebSocket → In-Memory Events
`canvas_bridge.rb` uses WebSockets. The Opal version needs to replace this with an in-browser event bus (custom events or a simple pub/sub).

#### 4. Sole Configuration
A `stream-weaver.gemspec` needs Sole-compatible metadata and the Opal build needs to be configured to exclude the server layer files entirely.

---

## Minimal Viable NPM Path

Rather than porting the entire feature set at once, there's a pragmatic MVP:

**MVP Scope:** Just the reactive core

```
OpalRuntime          ← Opal-clean ✅
OpalBridge           ← Opal-clean ✅
Opal adapter         ← Opal-clean ✅
Basic components     ← ~20 most-used components, stubs for server deps
ReactiveState        ← Opal-clean ✅
```

**What's excluded from MVP:**
- Mermaid (external library dependency)
- Chart.js integration (manageable but deferred)
- Prism.js code blocks (deferred)
- Slide container (deferred)
- All navigation/server-rendered concerns

The MVP would demonstrate:
- `npm install stream-weaver` works
- `import StreamWeaver from 'stream-weaver'` gives you a working reactive component tree
- Basic layout, cards, text, stat displays, progress bars all render
- Reactive state updates propagate to DOM

This is enough to be interesting to JS developers and validate the concept.

---

## Strategic Framing

### Do This AFTER Traction

The NPM story is most compelling when there's proven Ruby-side value to port. The sequence should be:

1. ✅ **Build the Ruby gem to be feature-rich** — fill the audit gaps, get to parity with artifact aesthetic
2. ✅ **Publish the gem publicly** — RubyGems, documentation, README with demos
3. ✅ **See community adoption** — GitHub stars, issues filed by others, blog posts, use in production
4. 🔜 **Then pursue NPM** — "The Ruby reactive UI framework that JS developers can also use"

Pursuing NPM too early means spending engineering time on a complex cross-compilation build before there's proven demand. The JS community will be more receptive to "port this popular Ruby thing" than "try this new thing that happens to be Ruby inside."

### The Narrative When the Time Is Right

> "StreamWeaver is Streamlit for Ruby — and now you can use it from JavaScript too, without ever touching Ruby. All the expressiveness of a Ruby DSL, compiled to JavaScript by Opal, available on NPM."

This is a genuinely novel story. Opal's NPM publishing via Sole is underutilized. StreamWeaver would be a showcase of what's possible.

---

## Technical Checklist (When Ready to Execute)

- [ ] Run `bin/opal_spike.rb` — document which modules compile cleanly and which fail
- [ ] Create Opal stubs for `kramdown`, file I/O, and WebSocket dependencies
- [ ] Audit `components.rb` for every `require` and server assumption
- [ ] Audit `display_dsl.rb` same
- [ ] Implement in-browser event bus to replace WebSocket canvas bridge
- [ ] Configure Sole build with gemspec metadata
- [ ] Build and test MVP component set in a browser via Opal
- [ ] Publish `stream-weaver` to NPM (scoped or unscoped)
- [ ] Write JS-facing documentation (different audience from Ruby docs)

---

## References

- Opal documentation: https://opalrb.com
- Sole (Opal NPM bridge): https://github.com/opal/opal (see `sole` tooling)
- Existing Opal adapter: `lib/stream_weaver/adapter/opal.rb`
- Existing Opal runtime: `lib/stream_weaver/opal/runtime.rb`
- Opal spike: `bin/opal_spike.rb`
- JS stubs: `lib/stream_weaver/opal/stubs/`
