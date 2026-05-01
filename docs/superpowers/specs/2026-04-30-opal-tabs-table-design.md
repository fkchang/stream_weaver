# Opal Tabs + Table Component Parity — Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `render_tabs` and `render_table` to `Adapter::Opal` so that the identical server-side DSL works in Opal builds — using a universal `register_callbacks` protocol that any interactive component can implement without touching the bridge.

**Architecture:** A `register_callbacks(registry)` method is added to `Components::Base` as a no-op default, then overridden in `Components::Button`, `Components::Tabs`, `Components::Table`, and `Components::Modal`. `OpalRuntime#register_component_callbacks` is updated to call this protocol exclusively — the hardcoded `is_a?(Button)` and `footer_component` branches are removed because the protocol handles them. `Adapter::Opal` gains `render_tabs` and `render_table`. The bridge gains zero new code.

**Tech Stack:** Ruby/Opal, existing `Components::Tabs`, `Components::Table`, `Components::Button`, `Components::Base`, `Components::Modal`, `OpalRuntime`, `Adapter::Opal`. No new data attributes, no new JS.

---

## Background

Phase 1 Opal apps can use buttons, text fields, checkboxes, and markdown. Two high-value server-side components — tabs and table — are missing. Adding them piecemeal with bespoke data attributes (`data-sw-set`, `data-sw-sort`) would fragment the bridge and create inconsistency. Instead, this design introduces a universal protocol that all interactive components follow.

### Current `OpalRuntime#register_component_callbacks`

```ruby
def register_component_callbacks(components)
  Array(components).each do |c|
    if c.is_a?(Components::Button)
      @callbacks[c.stable_id] = c.callback
    elsif c.respond_to?(:children)
      register_component_callbacks(c.children)
    elsif c.respond_to?(:footer_component)
      register_component_callbacks([c.footer_component])
    end
  end
end
```

This has hardcoded knowledge of `Button`, `footer_component`, and child traversal. Every new interactive component requires editing this method.

### How `Table#render` calls the adapter

```ruby
def render(view, state)
  resolved = resolve_data(state)
  view.adapter.render_table(view, resolved[:headers], resolved[:rows], table_options, state)
end
```

`Table` resolves its own data (handling state-bound, file-based, and explicit rows) and passes pre-resolved headers/rows to the adapter. `Adapter::Opal#render_table` must match this signature — it does not receive the component object.

### How `Modal#render` calls the adapter

```ruby
def render(view, state)
  view.adapter.render_modal(view, self, state)
end
```

Modal passes itself — the adapter receives the full component. The `footer_component` attribute is separate from `children`.

---

## Design

### 1. `register_callbacks` Protocol on `Components::Base`

```ruby
class Base
  def register_callbacks(registry)
    # Default: no interactive callbacks. Override in interactive components.
  end
end
```

Every component responds to `register_callbacks` — no `respond_to?` guards needed.

### 2. `Components::Button#register_callbacks`

`Button` stores its ID as `@button_id` (exposed via `id` reader) and its callback block as `@action` (no public reader):

```ruby
class Button < Base
  def register_callbacks(registry)
    registry[id] = @action if @action
  end
end
```

Replaces the `is_a?(Components::Button)` branch in the runtime.

### 3. `Components::Tabs#register_callbacks`

`Tabs` stores its key as `@key` (exposed via `attr_reader :key`):

```ruby
class Tabs < Base
  def register_callbacks(registry)
    children.each_with_index do |_tab, index|
      registry["#{@key}_tab_#{index}"] = ->(state) { state[@key] = index }
    end
  end
end
```

Callback keys: `"my_tabs_tab_0"`, `"my_tabs_tab_1"`, etc. The lambda writes `state[:my_tabs] = 2` using a symbol key (same key type as `@key`, written directly to state — not via `update_state`). Uses `data-sw-invoke` exactly as buttons do.

### 4. `Components::Table` — required additions

Two additions to `Table` in `components.rb`:

**a) Override `key`** — `Base#key` returns `nil`; `Table` stores its DSL key as `@data` (first positional arg):

```ruby
def key
  @data
end
```

**b) Add `:key` to `table_options`** — the existing `table_options` method does not include the key; `Adapter::Opal#render_table` needs it for sort state lookups:

```ruby
def table_options
  @options.merge(
    key: @data,        # add this line
    striped: @striped,
    bordered: @bordered,
    # ... rest unchanged
  )
end
```

No new `attr_reader` declarations are needed on `Table`. `register_callbacks` runs inside the class (accesses `@sortable`, `@headers`, `@data` directly). The adapter receives visual options via `table_options` hash.

### 5. `Components::Table#register_callbacks`

Sort is client-side only — operates on the rows passed to the adapter at render time. Callbacks are registered using headers available at component-build time. Requires explicit `headers:` in the DSL call (state-bound or file-derived headers at sort registration time are not supported in Phase 2b; a future phase can add lazy registration).

```ruby
class Table < Base
  def register_callbacks(registry)
    return unless @sortable && @data.is_a?(Symbol)
    Array(@headers).each_with_index do |_, col_index|
      registry["#{key}_sort_#{col_index}"] = ->(state) {
        if state["#{key}_sort_col"] == col_index
          state["#{key}_sort_dir"] = state["#{key}_sort_dir"] == :asc ? :desc : :asc
        else
          state["#{key}_sort_col"] = col_index
          state["#{key}_sort_dir"] = :asc
        end
      }
    end
  end
end
```

Sort state uses string keys (`"data_sort_col"`, `"data_sort_dir"`) — NOT symbols — because `update_state` converts keys to symbols, and sort state is written directly in lambdas. Tabs use symbol keys (e.g., `state[:my_tabs] = 2`) because tab state is also written directly in lambdas, and `@key` is already a symbol. The asymmetry is intentional.

**Client-side sort caveat (must be documented in code):** This sort operates on the `rows` array as passed. If the app is paginating (rows = page 1 of N), sort applies only to the visible page. Server-paginated sort requires the app to handle sort state and re-query — that is an application concern, not a framework concern.

### 6. `Components::Modal#register_callbacks`

Modal's `footer_component` (a `ModalFooter` container) is not in `children` — the runtime's `c.children` traversal does not reach footer buttons. `Modal#register_callbacks` traverses the footer subtree explicitly:

```ruby
class Modal < Base
  def register_callbacks(registry)
    return unless footer_component
    # ModalFooter has no callbacks itself — traverse its children (buttons)
    Array(footer_component.children).each { |c| c.register_callbacks(registry) }
  end
end
```

`ModalFooter` is a plain container (`attr_accessor :children`); its `register_callbacks` is the Base no-op. This approach migrates Modal fully to the protocol — the runtime needs no `footer_component` special case.

### 7. `OpalRuntime#register_component_callbacks` — protocol-based traversal

Replace with the protocol. No special cases needed:

```ruby
def register_component_callbacks(components)
  Array(components).each do |c|
    c.register_callbacks(@callbacks)
    register_component_callbacks(c.children)
  end
end
```

`Components::Base#children` returns `[]`, so recursion terminates naturally on leaf nodes. Each component declares its own callbacks — the runtime has zero hardcoded knowledge of component types.

### 8. `Adapter::Opal#render_tabs`

```ruby
def render_tabs(view, component, state)
  active_index = state[component.key] || 0
  view.div(class: "sw-tabs sw-tabs--#{component.variant || 'default'}") do
    view.div(class: "sw-tabs__nav") do
      component.children.each_with_index do |tab, index|
        active_class = index == active_index ? " sw-tabs__tab--active" : ""
        view.button(
          class: "sw-tabs__tab#{active_class}",
          data_sw_invoke: "#{component.key}_tab_#{index}"
        ) { view.plain(tab.label) }
      end
    end
    view.div(class: "sw-tabs__content") do
      active_tab = component.children[active_index]
      Array(active_tab&.children).each { |c| c.render(view, state) }
    end
  end
end
```

`data_sw_invoke` value `"#{component.key}_tab_#{index}"` matches the key registered in `Tabs#register_callbacks` exactly. `Tabs#render` passes the component object (consistent with Modal's convention since Tabs has no separate data-resolution step).

### 9. `Adapter::Opal#render_table`

Matches `Table#render`'s calling convention — receives pre-resolved headers/rows plus `table_options` hash:

```ruby
def render_table(view, headers, rows, options, state)
  key = options[:key]
  sort_col = state["#{key}_sort_col"]
  sort_dir = (state["#{key}_sort_dir"] || :asc).to_sym

  if options[:sortable] && sort_col
    rows = rows.sort_by { |row| row[sort_col].to_s }
    rows = rows.reverse if sort_dir == :desc
  end

  css_classes = ["sw-table"]
  css_classes << "sw-table--striped"    if options[:striped]
  css_classes << "sw-table--bordered"   if options[:bordered]
  css_classes << "sw-table--scrollable" if options[:scrollable]

  wrapper_style = options[:sticky_header] ? "max-height:400px;overflow-y:auto;" : nil

  view.div(class: css_classes.join(" "), style: wrapper_style) do
    view.table do
      view.thead do
        view.tr do
          headers.each_with_index do |header, index|
            if options[:sortable]
              indicator = if sort_col == index
                sort_dir == :asc ? " ↑" : " ↓"
              else
                ""
              end
              view.th do
                view.button(data_sw_invoke: "#{key}_sort_#{index}") do
                  view.plain("#{header}#{indicator}")
                end
              end
            else
              view.th { view.plain(header.to_s) }
            end
          end
        end
      end
      view.tbody do
        rows.each do |row|
          view.tr do
            Array(row).each { |cell| view.td { view.plain(cell.to_s) } }
          end
        end
      end
    end
  end
end
```

`data-sw-invoke` value `"#{key}_sort_#{index}"` matches the key registered in `Table#register_callbacks` exactly.

---

## What This Enables

After this change, the following DSL works identically in Opal and server-side:

```ruby
app "Dashboard" do
  tabs :view, variant: :pills do
    tab "Summary" do
      table :data,
        headers: ["Name", "Score", "Status"],
        rows: state[:data],
        sortable: true,
        striped: true
    end
    tab "Settings" do
      text_field :query, placeholder: "Search..."
    end
  end
end
```

`table :data` passes `:data` as the first positional arg — `@data` becomes `key`, used for sort state. Client-side sort works when all rows are passed inline. State-bound tables (`rows: state[:data]`) resolve to the current array at DSL evaluation time in Opal.

---

## What This Does Not Cover

- **Server-paginated sort** — client-side sort only; large dataset sort requires app-level state + re-query. Deferred.
- **`render_tabs` with lazy loading** — `lazy: true` tabs defer content rendering. Deferred to Phase 3.
- **File-based tables with sortable** — `@headers` comes from file resolution, not DSL time. Sort callback registration requires explicit headers. Deferred.
- **`render_mermaid`, `render_chartjs`** — separate Phase 2d spec.

---

## File Map

| File | Change |
|---|---|
| `lib/stream_weaver/components.rb` | `Base#register_callbacks` no-op; `Button#register_callbacks`; `Tabs#register_callbacks`; `Table`: add `def key`, add `:key =>` to `table_options`, add `Table#register_callbacks`; `Modal#register_callbacks` |
| `lib/stream_weaver/opal/runtime.rb` | Replace `register_component_callbacks` with protocol traversal (remove `is_a?` and `footer_component` branches) |
| `lib/stream_weaver/adapter/opal.rb` | Add `render_tabs(view, component, state)`, `render_table(view, headers, rows, options, state)` |

---

## Testing

**`spec/components_spec.rb`** — add:
- `Components::Base#register_callbacks` is a no-op (registry unchanged after call)
- `Components::Button#register_callbacks` registers `@action` under `id`
- `Components::Tabs#register_callbacks` registers N callbacks for N tabs under `"key_tab_N"` keys
- Tabs callback sets `state[@key]` (Symbol key) to tab index Integer
- `Components::Table#register_callbacks` registers N sort callbacks when `sortable: true`
- `Components::Table#register_callbacks` registers nothing when `sortable: false`
- Sort callback toggles direction (`:asc` → `:desc`) when same column clicked
- Sort callback resets to `:asc` when a new column clicked
- Two tables generate non-colliding callback keys (`"users_sort_0"` vs `"orders_sort_0"`)
- `Components::Table#key` returns `@data` (first positional arg)
- `Components::Modal#register_callbacks` registers footer children's callbacks

**`spec/opal/runtime_spec.rb`** — add:
- `register_component_callbacks` calls `register_callbacks` on every component
- Buttons self-register via protocol (no `is_a?` check)
- Tabs register their N tab callbacks
- Nested components inside tabs are traversed
- Modal footer buttons are registered via `Modal#register_callbacks`

**`spec/opal/adapter_opal_spec.rb`** — add:
- `render_tabs` emits `.sw-tabs` wrapper with variant class
- `render_tabs` emits `.sw-tabs__nav` buttons with correct `data-sw-invoke` keys
- `render_tabs` renders active tab content based on state
- `render_tabs` defaults to index 0 when state key absent
- `render_table` emits `.sw-table` with correct modifier classes (striped, bordered, scrollable)
- `render_table` emits `th` buttons with `data-sw-invoke` when `options[:sortable]` true
- `render_table` emits plain `th` (no button) when `options[:sortable]` false
- `render_table` sorts rows ascending when sort_col set in state
- `render_table` reverses rows when sort_dir `:desc` in state
- `render_table` emits sort indicator (↑/↓) on active sort column
