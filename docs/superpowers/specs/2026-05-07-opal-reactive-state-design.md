# Opal Phase 2c — ReactiveState Design Spec

**Date:** 2026-05-07
**Status:** Draft
**Parent spec:** `2026-04-28-streamweaver-opal-design.md`
**Scope:** Phase 2c — Observable state hash + `watch` + `on_start` + granular DOM updates

---

## Problem

Phase 2a/2b shipped working Opal builds with full re-render on every interaction (whole-block re-execution → morphdom the entire `sw-app` div). This is correct but inefficient: a keypress in a search field re-renders a shopping cart that has nothing to do with the search.

Two gaps remain before Opal can handle the full React problem space:

1. **Side effects tied to state changes** — "when `:search` changes, fetch new results" cannot be expressed by re-running the block (that runs on *every* change). React's `useEffect` with deps solves this. StreamWeaver needs `watch`.

2. **Initialization** — "run this once on startup" is the same problem. React's `useEffect(fn, [])`. StreamWeaver needs `on_start`.

3. **Efficiency** — re-rendering the entire app on every keystroke is wasteful. Only the DOM regions that read a changed state key should be patched.

### What is NOT a gap

Five of the seven React patterns that cause friction dissolve automatically in StreamWeaver's shared-hash + re-run model:

| React concept | StreamWeaver | Gap? |
|---|---|---|
| `useState` | `state[:key]` | No |
| Props / lifting state | `state[:key]` shared | No |
| Context API | `state[:key]` (already global) | No |
| `useMemo` (derived state) | Inline computation — it's Ruby | No |
| `useReducer` | `case state[:step]` | No |
| `useEffect` w/ deps | `watch(:key) { }` | **Yes — new** |
| `useEffect(fn, [])` | `on_start { }` | **Yes — new** |

---

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| ReactiveState as drop-in | Yes — replaces `@state = {}` in OpalRuntime | Zero API change for app authors; same DSL works in both phases |
| Binding syntax | None — auto-tracking via `[]` read override | Following the Glimmer/SolidJS insight: if the framework tracks reads, app authors write nothing special |
| `watch` placement | Inside `app do` block, before the UI | Consistent with React hook placement convention; evaluated during block setup |
| `on_start` semantics | Runs exactly once, **after** first render | Deferred to next tick via JS `setTimeout(fn, 0)` to avoid render-during-render; matches React's `useEffect(fn, [])` semantics (effects run after mount) |
| Granularity unit | Per top-level component (Phase 2c step 2) | Coarser than per-block but architecturally sound; sufficient for 95% of cases |
| Granular DOM wrapper | `<div id="sw-region-N">` wrapping each top-level component | Gives morphdom a stable target without restructuring the component model |
| Step 1 vs Step 2 | Step 1 (ReactiveState + watch + on_start) first; Step 2 (granular patches) separate task | Step 1 delivers real value and unblocks blog post / spec validation |

---

## Validation Scenarios

These scenarios define what Phase 2c must handle. S1–S7 are regression tests (must work unchanged from Phase 2b). S8–S9 validate the new primitives.

### S1 — Counter with derived display (regression)
```ruby
app do
  button("Increment") { state[:count] = state[:count].to_i + 1 }
  text "Count: #{state[:count]}"
  text "Is even: #{state[:count].to_i.even?}"
end
```
**Validates:** Derived state via inline computation. No `useMemo` needed.

### S2 — Search-filtered list (regression)
```ruby
app do
  text_field :search, placeholder: "Filter..."
  items = %w[Apple Banana Cherry].select { |i| i.downcase.include?(state[:search].to_s.downcase) }
  items.each { |item| text item }
end
```
**Validates:** One field affecting a rendered list. React requires `useMemo`. StreamWeaver: just Ruby.

### S3 — Sibling coordination via shared state (regression)
```ruby
app do
  tabs :active_tab do
    tab "Config" do
      select :theme, ["light", "dark"]
      text_field :app_name, label: "App Name"
    end
    tab "Preview" do
      div(class: "preview-#{state[:theme]}") { header1 state[:app_name] || "Preview" }
    end
  end
end
```
**Validates:** Sibling components coordinating via shared state — React's "lift state up" problem doesn't exist here.

### S4 — Shopping cart with derived total (regression)
```ruby
app do
  products = [{ name: "Widget", price: 9.99 }, { name: "Gadget", price: 24.99 }]
  products.each do |p|
    card do
      text p[:name]; text "$#{p[:price]}"
      button("Add") { state[:cart] = (state[:cart] || []) + [p] }
    end
  end
  card do
    header3 "Cart (#{(state[:cart] || []).size} items)"
    text "Total: $#{(state[:cart] || []).sum { |i| i[:price] }.round(2)}"
  end
end
```
**Validates:** Multiple components sharing state; derived total recomputes inline. React needs Context + `useMemo`.

### S5 — Watch: search triggers side effect (new — `watch`)
```ruby
app do
  watch(:search) { |query| state[:results] = perform_search(query) }
  text_field :search, placeholder: "Search..."
  (state[:results] || []).each { |r| text r }
end
```
**Validates:** `watch` fires when `:search` changes, not on every block re-run. Equivalent to React's `useEffect` with `[search]` dependency.

### S6 — on_start: async fetch on mount (new — `on_start`)
```ruby
app do
  on_start do
    state[:loading] = true
    fetch_json("/api/items") { |data|
      state[:items] = data
      state[:loading] = false
    }
  end

  if state[:loading]
    text "Loading..."
  else
    (state[:items] || []).each { |item| text item[:name] }
  end
end
```
**Validates:** `on_start` fires exactly once. `state[:loading]` toggle causes re-render. Equivalent to React's `useEffect(() => { fetchData() }, [])`.

### S7 — Multi-step wizard / state machine (regression)
```ruby
app do
  case (state[:step] || :info)
  when :info
    text_field :name; text_field :email
    button("Next") { state[:step] = :payment }
  when :payment
    text_field :card
    button("Back") { state[:step] = :info }
    button("Next") { state[:step] = :confirm }
  when :confirm
    text "Name: #{state[:name]}"; text "Card: #{state[:card]}"
    button("Submit") { state[:confirmed] = true }
  end
end
```
**Validates:** `case/when` is `useReducer`. No new primitives needed — Ruby already has this.

### S8 — Loan calculator: interdependent derived fields (new — granular update validation)
```ruby
app do
  text_field :principal, label: "Loan Amount ($)", type: :number
  text_field :rate,      label: "Annual Rate (%)", type: :number
  text_field :term,      label: "Term (months)",   type: :number

  p = state[:principal].to_f
  r = state[:rate].to_f / 100 / 12
  n = state[:term].to_f
  payment = r > 0 && n > 0 ? (p * r * (1+r)**n) / ((1+r)**n - 1) : 0

  card do
    header3 "Monthly Payment"
    text "$#{payment.round(2)}"
  end
end
```
**Validates:** Three inputs affect one derived display. React needs `useMemo` with 3-item dependency array. StreamWeaver: inline computation, zero annotation. With granular updates (step 2), only the `card` re-renders when any input changes.

### S9 — Dashboard: multiple widgets, shared symbol (new — granular update validation)
```ruby
app do
  select :symbol, %w[AAPL MSFT GOOG], label: "Symbol"

  columns widths: ["33%", "33%", "33%"] do
    column { card { header3 "Price";  text price_for(state[:symbol]) } }
    column { card { header3 "Volume"; text volume_for(state[:symbol]) } }
    column { card { header3 "P/E";    text pe_for(state[:symbol]) } }
  end
end
```
**Validates:** Multiple independent display components reading the same key. React requires Context or props drilling through a shared parent. With granular updates, only the three cards re-render when `:symbol` changes — not the `select` widget.

---

## Architecture: Step 1 — ReactiveState + watch + on_start

### ReactiveState class (`lib/stream_weaver/opal/reactive_state.rb`)

~70 lines. Zero dependencies. Replaces the plain `{}` hash in `OpalRuntime`.

```ruby
class ReactiveState
  def initialize(hash = {})
    @data     = hash
    @watchers = Hash.new { |h, k| h[k] = [] }  # key => [procs]
    @tracking = nil
    @track_map = Hash.new { |h, k| h[k] = [] } # key => [region_ids]
  end

  def [](key)
    key = key.to_sym
    (@track_map[key] << @tracking if @tracking && !@track_map[key].include?(@tracking))
    @data[key]
  end

  def []=(key, value)
    key = key.to_sym
    old = @data[key]
    @data[key] = value
    notify(key) unless old == value
  end

  def watch(key, &block)
    @watchers[key.to_sym] << block
  end

  def track(region_id)
    prev, @tracking = @tracking, region_id
    result = yield
    @tracking = prev
    result
  end

  def dependencies_for(region_id)
    @track_map.each_with_object([]) { |(key, ids), arr| arr << key if ids.include?(region_id) }
  end

  def to_h = @data.dup

  private

  def notify(key)
    @watchers[key].each { |w| w.call(@data[key]) }
  end
end
```

### OpalRuntime changes

1. Replace `@state = {}` with `@state = ReactiveState.new`
2. Add `watch` delegation: DSL method `watch(key, &block)` calls `@state.watch(key, &block)` — but ALSO registers `invoke_and_patch` so the watcher triggers a re-render after the side-effect block runs
3. Add `on_start(&block)` — stores block, fires it once via `setTimeout(0)` after first render
4. Step 1 still does full re-render (same as today); `track_map` is populated but not yet used for granular patches

### DSL surface in `app.rb` / `display_dsl.rb`

`watch` and `on_start` will be defined as no-ops in `display_dsl.rb` for MRI (server-side rendering). In Opal, `OpalRuntime` overrides them by wiring into its own instance via a thread-local-style class accessor.

**Note on `watch` block argument:** The parent spec (`2026-04-28`) showed zero-arg watch blocks. This spec intentionally passes the new value as an argument (`|val|`) — this avoids a redundant state read inside the watcher and matches the `notify` call signature. Deliberate divergence.

**MRI no-op stubs** (in `display_dsl.rb`):
```ruby
def watch(key, &block); end  # no-op server-side
def on_start(&block); end    # no-op server-side
```

**Wiring mechanism:** `App#watch` and `App#on_start` are called inside `instance_eval(&@block)` — in the context of `App`, which has no knowledge of `OpalRuntime`. The bridge uses a class-level current-runtime accessor:

```ruby
# In OpalRuntime:
class << self
  attr_accessor :current
end

def render_html
  OpalRuntime.current = self
  # ... existing render logic ...
ensure
  OpalRuntime.current = nil
end
```

`App` methods delegate to it:
```ruby
# In app.rb (RUBY_ENGINE guard so MRI never sees OpalRuntime):
if RUBY_ENGINE == "opal"
  def watch(key, &block)
    rt = StreamWeaver::Opal::OpalRuntime.current
    return unless rt && !rt.watchers_initialized?
    rt.state.watch(key) do |val|
      block.call(val)
      rt.render_and_patch
    end
  end

  def on_start(&block)
    StreamWeaver::Opal::OpalRuntime.current&.register_start_hook(block)
  end
end
```

**Watcher accumulation prevention:** `OpalRuntime` tracks whether watchers have been registered with an `@watchers_initialized` flag. `rebuild_with_state` sets this flag to `true` after the first call. On subsequent re-renders, `watch()` inside the block is a no-op — watchers are registered once and persist for the lifetime of the runtime instance.

```ruby
def watchers_initialized? = @watchers_initialized

def rebuild_with_state_with_watcher_guard(state)
  was_initialized = @watchers_initialized
  @watchers_initialized = true
  # App block runs — watch() calls are no-ops if was_initialized
  rebuild_with_state(state)
end
```

---

## Architecture: Step 2 — Granular DOM Updates

*This is a follow-on task after Step 1 ships. Specified here for continuity.*

### Tracking regions

Each top-level component in `app.components` becomes a `sw-region-N` div during render:

```html
<div id="sw-region-0"><!-- counter card --></div>
<div id="sw-region-1"><!-- search results --></div>
<div id="sw-region-2"><!-- cart summary --></div>
```

### OpalRuntime changes for granular patching

1. `render_html` wraps each component's output in `state.track("sw-region-#{i}") { c.render(...) }`
2. After render, `@track_map` contains `{ :cart => ["sw-region-2"], :search => ["sw-region-1"] }`
3. `update_and_patch(key, value)` queries `@track_map[key]` and patches only those regions via `morphdom(document.getElementById(region_id), ...)`
4. `invoke_and_patch` after a watcher fires similarly targets only affected regions

### Fallback

If a component's dependencies can't be determined (e.g., first render), fall back to full `sw-app` patch. After first render, `track_map` is populated and granular patching takes over.

---

## File Map

| File | Action | Notes |
|---|---|---|
| `lib/stream_weaver/opal/reactive_state.rb` | Create | ~70-line Observable hash |
| `lib/stream_weaver/opal/runtime.rb` | Modify | Use ReactiveState; add `on_start`; wire `watch`; step 2: granular patch |
| `lib/stream_weaver/opal/bridge.rb` | Modify | Step 2: targeted morphdom calls by region ID |
| `lib/stream_weaver/display_dsl.rb` | Modify | Add MRI no-op stubs for `watch` and `on_start` |
| `lib/stream_weaver/adapter/opal.rb` | Modify | Wire `watch`/`on_start` to runtime |
| `spec/opal/reactive_state_spec.rb` | Create | Unit tests for ReactiveState dependency tracking + notify |
| `spec/opal/runtime_spec.rb` | Modify | Add S5/S6/S8/S9 scenario specs |
| `examples/opal/reactive_demo.rb` | Create | Demo covering S5 (watch) and S8 (loan calculator) |

---

## Out of Scope (Future Phases)

- **S10 — WebSocket / live data feed** — requires async primitives beyond `on_start`
- **S11 — URL params as reactive state** — History API wrapper (Phase 3 in original design)
- **S12 — Settings with granular subscription** — covered by step 2 granular updates; no new DSL needed
- **Supabase client** — Phase 3 per original spec

---

## Testing Strategy

**Step 1 (ReactiveState class):** Pure Ruby unit tests on MRI. `ReactiveState` has no Opal dependency — test `[]` tracking, `[]=` notification, `watch` callback invocation.

**`watch` / `on_start` wiring:** Test via `adapter/opal` spec with a fake runtime. Verify `watch` callback fires after state write, and `on_start` fires once.

**Scenario regression (S1–S4, S7):** Existing Opal adapter specs cover these. Run full suite after each step.

**S5/S6/S8/S9:** New specs in `runtime_spec.rb` verifying rendered HTML reflects post-watch state and `on_start` side effects.

**Step 2 (granular):** Add region wrapper assertions — verify `sw-region-N` divs are emitted and that a state write to `:search` only triggers a patch on the region that read `:search`.
