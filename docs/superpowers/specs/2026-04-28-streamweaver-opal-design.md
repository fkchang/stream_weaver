# StreamWeaver Opal — Design Spec

**Date:** 2026-04-28  
**Status:** Draft  
**Scope:** Phases 1–2 (Phase 3 / Supabase is a separate spec when Phase 2 ships)

---

## Problem

StreamWeaver's current execution model requires a server for every UI interaction — every keystroke triggers an HTMX round-trip that re-runs the Ruby block server-side and morphs the DOM. This works well for the pareto case but breaks down for:

- **Rich SPA-style apps** where high-frequency state (cursor position, selection, scroll) should never touch the server
- **Jamstack / $0 hosting** — no server means no StreamWeaver today
- **GitHub Pages deployments** — static files only

The goal is to let the same StreamWeaver DSL run entirely in the browser via Opal, covering:

1. Pure static apps (Jamstack, GitHub Pages)
2. SPA-style apps with optional server sync for durable state
3. Eventually: server-rendered components that Opal rehydrates (separate spec)

---

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Gem strategy | `Adapter::Opal` in existing gem | Adapter seam already exists; `adapter/base.rb` even mentions Opal as a future target |
| Separate gem | No | YAGNI; extract later if there's community demand |
| API compatibility | B — mostly same DSL | Simple files just work; browser-specific via `opal-browser` escape hatch |
| Build tooling | `opal` gem's own builder | Well-established, no webpack dependency, simplest path to `dist/` |
| Reactivity model | Phase 1: whole-block re-execution; Phase 2: ReactiveState proxy | Match SolidJS/Vue insights without their weight |
| Glimmer gem | No — inspired by, not dependent on | `facets` transitive dep balloons Opal bundle unacceptably |
| Binding syntax | None explicit for common case | `<=>` / `<=` operators are confusing; auto-tracking is invisible to app authors |
| Explicit watch | `watch(:key) { |val| }` | Readable, unambiguous, Ruby-idiomatic |

---

## Architecture

### Execution Model Comparison

**Current (server):**
```
DSL block → runs on server → Phlex → HTML string → HTMX morphdom → DOM patch
Every interaction = network round-trip. State in session cookie.
```

**Opal Phase 1 (whole-block re-execution):**
```
DSL block → runs in Opal (browser) → HTML builder → string → morphdom.js → DOM patch
No round-trips. State in Ruby hash inside Opal runtime.
```

**Opal Phase 2 (reactive proxy):**
```
DSL block → runs in Opal → ReactiveState tracks reads → DOM nodes register as observers
State write → only observers of that key re-render. Surgical DOM updates.
```

### Layer Map

| Layer | What it is | Phase |
|---|---|---|
| User DSL | Unchanged StreamWeaver DSL — same `app/card/text_field/button` | Now (exists) |
| `Adapter::Opal` | Renders DSL to HTML string, wires event listeners, holds state | 1 |
| `OpalHtmlBuilder` | Minimal tag helper (~100 lines) replacing Phlex in Opal context | 1 |
| `streamweaver opal-build` | CLI command: compiles app → `dist/index.html` + `dist/app.js` | 1 |
| `morphdom.js` | Client-side DOM patching after block re-execution | 1 |
| `ReactiveState` | ~70-line Observable hash: auto-tracks reads, notifies on write | 2 |
| History API wrapper | `route` DSL via `pushState`/`popstate` — same calls as Sinatra routes | 2 |
| Supabase client | Thin Ruby/Opal wrapper — sync state to Supabase on demand | 3 (separate spec) |

---

## Phase 1: Whole-Block Re-Execution

### Goal
Port as many existing StreamWeaver examples as possible. Prove the build pipeline. Validate DSL compatibility.

### How it works

1. `Adapter::Opal` implements the same interface as `Adapter::AlpineJS`
2. DSL methods call `OpalHtmlBuilder` (a minimal tag helper) instead of Phlex
3. State is a plain Ruby hash held in an `OpalRuntime` object
4. On any state change (input event, button click): re-run entire DSL block → produce HTML string → `morphdom.js` patches the DOM
5. Event listeners are re-attached after each morph

### OpalRenderer — replaces ComponentRenderer, not just the adapter

The existing architecture: `ComponentRenderer < Phlex::HTML` is the `view` object. Each component's `render(view, state)` calls `view.adapter.render_X(view, self, state)` — so `view` must respond to both `adapter` and Phlex tag methods (`input`, `div`, `span`, etc.).

`Adapter::Opal` therefore needs a parallel **`OpalRenderer`** — not a Phlex subclass, but a string-accumulating object that provides the same interface:

```ruby
module StreamWeaver
  module Opal
    class OpalRenderer
      attr_reader :adapter

      def initialize(adapter, state)
        @adapter = adapter
        @state = state
        @output = []
      end

      # Tag helpers — mirror Phlex's interface, produce strings
      def div(**attrs, &block)
        @output << "<div #{attrs_to_html(attrs)}>"
        block&.call
        @output << "</div>"
      end

      def input(**attrs)
        @output << "<input #{attrs_to_html(attrs)}>"
      end

      # ... ~20 more common tags

      def to_html
        @output.join
      end

      private

      def attrs_to_html(attrs)
        attrs.map { |k, v| "#{k}=\"#{v}\"" }.join(" ")
      end
    end
  end
end
```

`OpalRenderer` is the view object passed to every component's `render(view, state)`. The adapter methods receive it and call its tag helpers to accumulate HTML. `ComponentRenderer` (Phlex) is only used in server mode.

### Build pipeline

```bash
# New CLI command — added as a case in lib/stream_weaver/cli.rb
streamweaver opal-build my_app.rb

# Produces:
dist/
  index.html    # shell page that loads app.js + morphdom from CDN
  app.js        # Opal-compiled Ruby → JS bundle
```

The CLI `case command` block in `cli.rb` gains a `when 'opal-build'` branch that invokes `OpalBuilder.build(file, output_dir: 'dist')`. `OpalBuilder` wraps the `opal` gem's compiler API.

Deploy `dist/` to GitHub Pages or any static host.

### Phase 1 minimum adapter methods

`Adapter::Base` defines 42 `render_*` methods. Phase 1 only needs the subset used by the simple examples. Non-implemented methods raise `NotImplementedError` (already the `Base` default), which is acceptable for Phase 1.

**Must implement for Phase 1:**

| Method | Used by |
|---|---|
| `render_header` | hello_world, todo_list, most examples |
| `render_text_field` | hello_world, todo_list, form_demo |
| `render_checkbox` | hello_world |
| `render_button` | todo_list, form_demo |
| `render_div` | todo_list (container) |
| `render_markdown` | markdown_demo, md() calls |
| `render_card` | dashboard_components |
| `render_vstack` / `render_hstack` | layout examples |
| `render_select` | form_demo |
| `render_table` | data display examples |
| `render_cdn_scripts` | page bootstrap (morphdom.js inclusion) |
| `render_text` | plain text components |

**Deferred (raise NotImplementedError):** tabs, breadcrumbs, mermaid, chartjs, design_deck, slide_container, sidebar_toc, pipeline, kpi_dashboard, and all visual/presentation components.

Apps that use `feed`, `streamer`, `service_client` (server-push features) are out of scope for Opal — they require a server by definition.

---

## Phase 2: ReactiveState

### Goal
Enable rich SPA apps (in-browser IDE, MMA curriculum tracker) without wasted re-renders.

### Design

`ReactiveState` is a ~70-line pure Ruby class (no dependencies) that:

- Wraps a plain hash
- During block execution, tracks which block sections read which keys (via a thread-local "current observer" pattern)
- When a key is written, notifies only the lambdas that observed it
- Those lambdas re-render the affected DOM subtree and morph it in place

```ruby
module StreamWeaver
  module Opal
    class ReactiveState
      def initialize
        @data = {}
        @observers = Hash.new { |h, k| h[k] = [] }
        @current_observer = nil
      end

      def [](key)
        @observers[key] << @current_observer if @current_observer
        @data[key]
      end

      def []=(key, value)
        @data[key] = value
        @observers[key].each(&:call)
        @observers[key].clear  # re-register on next render
      end

      def watch(key, &block)
        @observers[key] << block
      end

      def track(observer_lambda, &block)
        # Opal is single-threaded — no thread locals. Plain instance var is correct.
        prev = @current_observer
        @current_observer = observer_lambda
        result = block.call
        @current_observer = prev
        result
      end
    end
  end
end
```

### Upgrade path

- Phase 1 apps use plain `{}` hash — whole-block re-runs
- Phase 2 drops in `ReactiveState` with no app code changes
- The runtime detects which is in use; `Adapter::Opal` is written to work with both

### Explicit watch (edge cases)

For side effects that don't map to DOM re-rendering:

```ruby
app "MMA Tracker" do
  watch(:current_student) do |student|
    # Only persists to Supabase when student changes, not on every render
    supabase.upsert("students", student)
  end
end
```

---

## URL Navigation (Cross-Cutting)

StreamWeaver already has partial route handling for Rails-like CRUD links. Opal extends this using the History API.

**Server mode:** `route "/students"` → Sinatra route match  
**Opal mode:** `route "/students"` → `pushState` + `popstate` listener

Same DSL call, two adapter implementations. Deep-linking to `/students` renders the students section without a server round-trip.

This ships in Phase 2. Phase 1 apps are single-page (no sub-routes needed for hello_world / todo_list).

---

## Out of Scope (This Spec)

- **Server-rendered + Opal rehydration** (bullet 3 from original brief) — separate spec
- **Rails/Sinatra plugin** (bullet 4) — depends on rehydration spec
- **Supabase sync layer** — Phase 3, separate spec after Phase 2 ships
- **`feed`, `streamer`, `service_client`** — inherently server-side, not portable to Opal
- **`form_block`** — deferred; form handling in Opal is complex
- **`opal-browser` DSL wrapping** — expose raw `opal-browser` as escape hatch; wrap common patterns later once we know which ones the pareto set needs

---

## Success Criteria

### Phase 1
- `streamweaver opal-build hello_world.rb` produces a working `dist/index.html`
- At least 5 existing examples port with zero DSL changes
- `dist/` deploys to GitHub Pages and works in Chrome/Safari/Firefox
- No server process needed at runtime

### Phase 2
- `ReactiveState` passes isolated unit tests (observable hash behavior)
- A filterable list (e.g., student search) updates surgically — only the list re-renders, not the search field
- Focus/scroll/selection preserved across state changes (morphdom handles this)
- `watch(:key) { }` fires only on key change, not on every render

---

## Required Spike (Before Phase 1 Begins)

**Opal compatibility check** — all StreamWeaver lib files use `# frozen_string_literal: true` and Ruby 3.x syntax (pattern matching, endless ranges, numbered block params). Opal's Ruby compatibility is not complete. Before writing `Adapter::Opal`, run a spike:

1. Add `opal` to the Gemfile
2. Attempt to compile `lib/stream_weaver/display_dsl.rb` and `lib/stream_weaver/components.rb` via `Opal::Builder`
3. Document which constructs fail (frozen strings, `pp`, `Kernel#caller`, etc.)
4. The spike output is the compatibility constraint list that Phase 1 must work within

This spike is the first task of Phase 1 — its output may narrow or expand the component compatibility list above.

## Open Questions

1. **Opal bundle size** — measure output JS for hello_world after the compatibility spike. Target: under 500KB gzipped.
2. **morphdom.js inclusion** — CDN link in `index.html` template for Phase 1; inline option in Phase 2 for offline/GitHub Pages reliability.
3. **OpalRuntime** — the object that owns the state hash and orchestrates re-execution. Responsibilities: holds state, holds the DSL block proc, calls `OpalRenderer`, calls morphdom JS bridge. One instance per app. Defined in `lib/stream_weaver/opal/runtime.rb`.
4. **Hot reload** — `opal-build --watch` mode exists and would improve dev UX; out of scope for Phase 1 but easy to add after.
