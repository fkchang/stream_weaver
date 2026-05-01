# Opal Phase 2b: Tabs + Table Component Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `render_tabs` and `render_table` to `Adapter::Opal` using a universal `register_callbacks` protocol so the identical server-side DSL works in Opal builds.

**Architecture:** A `register_callbacks(registry)` method added to `Components::Base` as a no-op, overridden in `Button`, `Tabs`, `Table`, and `Modal`. `OpalRuntime#register_component_callbacks` replaced with protocol-only traversal (no more `is_a?` or `footer_component` branches). `Adapter::Opal` gains `render_tabs` and `render_table`. Zero bridge changes.

**Tech Stack:** Ruby/RSpec, `lib/stream_weaver/components.rb`, `lib/stream_weaver/opal/runtime.rb`, `lib/stream_weaver/adapter/opal.rb`.

---

## File Map

| File | Change |
|---|---|
| `lib/stream_weaver/components.rb` | Add `Base#register_callbacks` no-op; add `Button#register_callbacks`; add `Tabs#register_callbacks`; add `Table#key`, `table_options :key`, `Table#register_callbacks`; add `Modal#register_callbacks` |
| `lib/stream_weaver/opal/runtime.rb` | Replace `register_component_callbacks` with protocol traversal |
| `lib/stream_weaver/adapter/opal.rb` | Add `render_tabs`, `render_table` |
| `spec/components_spec.rb` | Add `register_callbacks` tests for all five component types |
| `spec/opal/runtime_spec.rb` | Add protocol traversal tests |
| `spec/opal/adapter_opal_spec.rb` | Add `render_tabs` and `render_table` tests |

---

## Task 1: `register_callbacks` Protocol Foundation

Establish the protocol on `Base`, make `Button` self-register, and update the runtime. These three changes must land in one atomic commit — updating the runtime without `Button#register_callbacks` in place would silently stop all button callbacks.

**Files:**
- Modify: `lib/stream_weaver/components.rb` (~line 45, inside `Components::Base`; ~line 140, inside `Components::Button`)
- Modify: `lib/stream_weaver/opal/runtime.rb` (`register_component_callbacks` method)
- Test: `spec/components_spec.rb`, `spec/opal/runtime_spec.rb`

- [ ] **Step 1: Write failing tests for Base no-op and Button self-registration**

Add to `spec/components_spec.rb` inside the existing `describe StreamWeaver::Components::Base` block:

```ruby
describe "#register_callbacks" do
  it "is a no-op — leaves registry unchanged" do
    registry = {}
    described_class.new.register_callbacks(registry)
    expect(registry).to be_empty
  end
end
```

Add a new `describe StreamWeaver::Components::Button` block (or inside an existing one if present):

```ruby
describe StreamWeaver::Components::Button do
  describe "#register_callbacks" do
    it "registers @action under id" do
      action = ->(state) { state[:clicked] = true }
      btn = described_class.new("Click me", "btn_1", &action)
      registry = {}
      btn.register_callbacks(registry)
      expect(registry).to have_key(btn.id)
      state = {}
      registry[btn.id].call(state)
      expect(state[:clicked]).to be true
    end

    it "skips registration when no block given" do
      btn = described_class.new("Label", "btn_2")
      registry = {}
      btn.register_callbacks(registry)
      expect(registry).to be_empty
    end
  end
end
```

Add to `spec/opal/runtime_spec.rb`:

```ruby
describe "#register_component_callbacks" do
  it "uses the register_callbacks protocol, not is_a? checks" do
    action = ->(state) { state[:hit] = true }
    btn = StreamWeaver::Components::Button.new("Go", "test_btn", &action)
    runtime.register_component_callbacks([btn])
    runtime.invoke_callback(btn.id)
    expect(runtime.state[:hit]).to be true
  end

  it "traverses children recursively via Base#children" do
    inner_action = ->(state) { state[:inner] = true }
    inner_btn = StreamWeaver::Components::Button.new("Inner", "inner_btn", &inner_action)
    # Wrap in a component whose children include the button
    wrapper = StreamWeaver::Components::Div.new
    allow(wrapper).to receive(:children).and_return([inner_btn])
    runtime.register_component_callbacks([wrapper])
    runtime.invoke_callback(inner_btn.id)
    expect(runtime.state[:inner]).to be true
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/components_spec.rb spec/opal/runtime_spec.rb --format documentation 2>&1 | grep -E "FAILED|register_callbacks"
```

Expected: failures about `register_callbacks` not defined.

- [ ] **Step 3: Add `Base#register_callbacks` no-op**

In `lib/stream_weaver/components.rb`, inside `class Base` (around line 45, after the existing `key` method):

```ruby
def register_callbacks(registry)
  # Default: no interactive callbacks. Override in interactive components.
end
```

- [ ] **Step 4: Add `Button#register_callbacks`**

In `lib/stream_weaver/components.rb`, inside `class Button` (after the existing `id` method, around line 141):

```ruby
def register_callbacks(registry)
  registry[id] = @action if @action
end
```

- [ ] **Step 5: Update `OpalRuntime#register_component_callbacks`**

In `lib/stream_weaver/opal/runtime.rb`, find the `register_component_callbacks` method by searching for `def register_component_callbacks` — do not match by the body text (the current body differs slightly from any description). Replace the entire method with:

```ruby
def register_component_callbacks(components)
  Array(components).each do |c|
    c.register_callbacks(@callbacks)
    register_component_callbacks(c.children)
  end
end
```

`Base#children` returns `[]`, so recursion terminates naturally on leaf nodes. `Button`, `Tabs`, `Table`, and `Modal` all self-declare their callbacks via `register_callbacks`. No component type is hardcoded here.

- [ ] **Step 6: Run tests to verify they pass**

```bash
bundle exec rspec spec/components_spec.rb spec/opal/runtime_spec.rb --format documentation 2>&1 | tail -10
```

Expected: all new tests green. Full suite should still pass:

```bash
bundle exec rspec spec/ 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add lib/stream_weaver/components.rb lib/stream_weaver/opal/runtime.rb spec/components_spec.rb spec/opal/runtime_spec.rb
git commit -m "feat(opal): register_callbacks protocol on Base+Button, update runtime traversal"
```

---

## Task 2: `Tabs#register_callbacks`

**Files:**
- Modify: `lib/stream_weaver/components.rb` (inside `class Tabs`, after `attr_reader :key, :variant, :lazy, :options`)
- Test: `spec/components_spec.rb`

- [ ] **Step 1: Write failing tests**

Add a `describe StreamWeaver::Components::Tabs` block in `spec/components_spec.rb`:

```ruby
describe StreamWeaver::Components::Tabs do
  def make_tabs(key, n_tabs)
    tabs = described_class.new(key)
    n_tabs.times do |i|
      tab = StreamWeaver::Components::Tab.new("Tab #{i}")
      tabs.instance_variable_get(:@children) << tab
    end
    tabs
  end

  describe "#register_callbacks" do
    it "registers one callback per tab under key_tab_N keys" do
      tabs = make_tabs(:view, 3)
      registry = {}
      tabs.register_callbacks(registry)
      expect(registry.keys).to eq(["view_tab_0", "view_tab_1", "view_tab_2"])
    end

    it "callback sets state[key] to tab index" do
      tabs = make_tabs(:view, 2)
      registry = {}
      tabs.register_callbacks(registry)
      state = {}
      registry["view_tab_1"].call(state)
      expect(state[:view]).to eq(1)
    end

    it "uses symbol key in state (not string)" do
      tabs = make_tabs(:panel, 2)
      registry = {}
      tabs.register_callbacks(registry)
      state = {}
      registry["panel_tab_0"].call(state)
      expect(state).to have_key(:panel)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/components_spec.rb -e "Tabs" --format documentation 2>&1 | tail -10
```

Expected: failures — `register_callbacks` not defined or returns nothing.

- [ ] **Step 3: Add `Tabs#register_callbacks`**

In `lib/stream_weaver/components.rb`, inside `class Tabs` (after line `attr_reader :key, :variant, :lazy, :options`):

```ruby
def register_callbacks(registry)
  children.each_with_index do |_tab, index|
    registry["#{@key}_tab_#{index}"] = ->(state) { state[@key] = index }
  end
end
```

Note: state key is `@key` (a Symbol like `:view`), written directly — not via `update_state`. This is intentional; symbol-key tab state is consistent because `@key` is always a Symbol from the DSL.

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/components_spec.rb -e "Tabs" --format documentation 2>&1 | tail -10
```

- [ ] **Step 5: Commit**

```bash
git add lib/stream_weaver/components.rb spec/components_spec.rb
git commit -m "feat(opal): Tabs#register_callbacks — one lambda per tab via protocol"
```

---

## Task 3: `Table` Key + `table_options` + `Table#register_callbacks`

**Files:**
- Modify: `lib/stream_weaver/components.rb` (inside `class Table`: add `key` method, update `table_options`, add `register_callbacks`)
- Test: `spec/components_spec.rb`

- [ ] **Step 1: Write failing tests**

Add a `describe StreamWeaver::Components::Table` block in `spec/components_spec.rb`:

```ruby
describe StreamWeaver::Components::Table do
  describe "#key" do
    it "returns the first positional arg (the state key)" do
      table = described_class.new(:users)
      expect(table.key).to eq(:users)
    end

    it "returns nil when no positional arg given" do
      table = described_class.new(headers: ["A"], rows: [["a"]])
      expect(table.key).to be_nil
    end
  end

  describe "#register_callbacks" do
    it "registers N sort callbacks when sortable: true and @data is Symbol" do
      table = described_class.new(:scores, headers: ["Name", "Score"], rows: [], sortable: true)
      registry = {}
      table.register_callbacks(registry)
      expect(registry.keys).to eq(["scores_sort_0", "scores_sort_1"])
    end

    it "skips registration when sortable: false" do
      table = described_class.new(:scores, headers: ["Name"], rows: [], sortable: false)
      registry = {}
      table.register_callbacks(registry)
      expect(registry).to be_empty
    end

    it "skips registration when @data is not a Symbol (direct-data table)" do
      table = described_class.new(headers: ["Name"], rows: [["Alice"]], sortable: true)
      registry = {}
      table.register_callbacks(registry)
      expect(registry).to be_empty
    end

    it "sort callback sets sort_col to column index and sort_dir to :asc" do
      table = described_class.new(:scores, headers: ["Name", "Score"], rows: [], sortable: true)
      registry = {}
      table.register_callbacks(registry)
      state = {}
      registry["scores_sort_1"].call(state)
      expect(state["scores_sort_col"]).to eq(1)
      expect(state["scores_sort_dir"]).to eq(:asc)
    end

    it "sort callback toggles direction when same column clicked again" do
      table = described_class.new(:scores, headers: ["Name"], rows: [], sortable: true)
      registry = {}
      table.register_callbacks(registry)
      state = { "scores_sort_col" => 0, "scores_sort_dir" => :asc }
      registry["scores_sort_0"].call(state)
      expect(state["scores_sort_dir"]).to eq(:desc)
    end

    it "two tables generate non-colliding callback keys" do
      t1 = described_class.new(:users, headers: ["Name"], rows: [], sortable: true)
      t2 = described_class.new(:orders, headers: ["Item"], rows: [], sortable: true)
      r1, r2 = {}, {}
      t1.register_callbacks(r1)
      t2.register_callbacks(r2)
      expect(r1.keys).to eq(["users_sort_0"])
      expect(r2.keys).to eq(["orders_sort_0"])
    end
  end

  describe "table_options includes :key" do
    it "includes the state key for adapter sort state lookups" do
      table = described_class.new(:users, headers: ["Name"], rows: [])
      expect(table.send(:table_options)[:key]).to eq(:users)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/components_spec.rb -e "Table" --format documentation 2>&1 | tail -15
```

- [ ] **Step 3: Add `Table#key` override**

In `lib/stream_weaver/components.rb`, inside `class Table` (add after `attr_reader :columns`):

```ruby
def key
  @data
end
```

- [ ] **Step 4: Add `:key` to `table_options`**

In `lib/stream_weaver/components.rb`, find the `table_options` private method (~line 713). Add `key: @data` as the first entry:

```ruby
def table_options
  @options.merge(
    key: @data,
    striped: @striped,
    bordered: @bordered,
    hoverable: @hoverable,
    compact: @compact,
    sortable: @sortable,
    sticky_header: @sticky_header,
    markdown: @markdown,
    caption: @caption,
    columns: @columns,
    alternating: @alternating,
    scrollable: @scrollable,
    hover: @hover
  )
end
```

- [ ] **Step 5: Add `Table#register_callbacks`**

In `lib/stream_weaver/components.rb`, inside `class Table`, add `register_callbacks` **before the `private` keyword** — it must be public because the runtime calls it externally via `c.register_callbacks(@callbacks)`:

```ruby
def register_callbacks(registry)
  # Sort is client-side only. Only supported when @data is a Symbol (state-bound key).
  # Direct-data tables (headers:/rows: without state key) cannot sort — @data would be nil.
  # Server-paginated sort requires app-level state + re-query; this only sorts in-memory rows.
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
```

Sort state uses string keys (`"scores_sort_col"`) to avoid collision with `update_state`, which converts all keys to symbols.

- [ ] **Step 6: Run tests to verify they pass**

```bash
bundle exec rspec spec/components_spec.rb -e "Table" --format documentation 2>&1 | tail -15
```

Full suite:

```bash
bundle exec rspec spec/ 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add lib/stream_weaver/components.rb spec/components_spec.rb
git commit -m "feat(opal): Table#key, table_options :key, Table#register_callbacks with client-sort"
```

---

## Task 4: `Modal#register_callbacks`

**Files:**
- Modify: `lib/stream_weaver/components.rb` (inside `class Modal`)
- Test: `spec/components_spec.rb`

- [ ] **Step 1: Write failing tests**

Add a `describe StreamWeaver::Components::Modal` block in `spec/components_spec.rb`:

```ruby
describe StreamWeaver::Components::Modal do
  describe "#register_callbacks" do
    it "registers footer children's callbacks" do
      modal = described_class.new(:confirm, title: "Confirm")
      footer = StreamWeaver::Components::ModalFooter.new
      action = ->(state) { state[:confirmed] = true }
      btn = StreamWeaver::Components::Button.new("OK", "modal_ok", &action)
      footer.children << btn
      modal.footer_component = footer

      registry = {}
      modal.register_callbacks(registry)
      expect(registry).to have_key(btn.id)
    end

    it "is a no-op when footer_component is nil" do
      modal = described_class.new(:info, title: "Info")
      registry = {}
      expect { modal.register_callbacks(registry) }.not_to raise_error
      expect(registry).to be_empty
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/components_spec.rb -e "Modal" --format documentation 2>&1 | tail -10
```

- [ ] **Step 3: Add `Modal#register_callbacks`**

In `lib/stream_weaver/components.rb`, inside `class Modal` (after `attr_accessor :children, :footer_component`):

```ruby
def register_callbacks(registry)
  return unless footer_component
  # footer_component (ModalFooter) is not in children — traverse its children explicitly.
  # ModalFooter is a plain container; its children are the interactive components (buttons).
  Array(footer_component.children).each { |c| c.register_callbacks(registry) }
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/components_spec.rb -e "Modal" --format documentation 2>&1 | tail -10
```

Also verify that the full runtime test suite still passes (the old `footer_component` branch is already gone from Task 1):

```bash
bundle exec rspec spec/opal/runtime_spec.rb --format documentation 2>&1 | tail -10
```

- [ ] **Step 5: Commit**

```bash
git add lib/stream_weaver/components.rb spec/components_spec.rb
git commit -m "feat(opal): Modal#register_callbacks — footer traversal via protocol"
```

---

## Task 5: `Adapter::Opal#render_tabs`

**Files:**
- Modify: `lib/stream_weaver/adapter/opal.rb`
- Test: `spec/opal/adapter_opal_spec.rb`

`Tabs#render` calls `view.adapter.render_tabs(view, self, state)` — the full component object is passed (confirmed in `components.rb`).

- [ ] **Step 1: Write failing tests**

Add to `spec/opal/adapter_opal_spec.rb`:

```ruby
describe "#render_tabs" do
  def make_tabs(key, labels)
    tabs = StreamWeaver::Components::Tabs.new(key)
    labels.each do |label|
      tab = StreamWeaver::Components::Tab.new(label)
      tabs.instance_variable_get(:@children) << tab
    end
    tabs
  end

  it "emits .sw-tabs wrapper" do
    tabs = make_tabs(:view, ["A", "B"])
    adapter.render_tabs(view, tabs, {})
    expect(view.to_html).to include('class="sw-tabs')
  end

  it "includes variant class" do
    tabs = StreamWeaver::Components::Tabs.new(:view, variant: :pills)
    adapter.render_tabs(view, tabs, {})
    expect(view.to_html).to include("sw-tabs--pills")
  end

  it "defaults to sw-tabs--line when no variant given (Tabs constructor default)" do
    tabs = StreamWeaver::Components::Tabs.new(:view)
    adapter.render_tabs(view, tabs, {})
    expect(view.to_html).to include("sw-tabs--line")
  end

  it "emits .sw-tabs__nav with a button per tab" do
    tabs = make_tabs(:view, ["Alpha", "Beta"])
    adapter.render_tabs(view, tabs, {})
    html = view.to_html
    expect(html).to include('data-sw-invoke="view_tab_0"')
    expect(html).to include('data-sw-invoke="view_tab_1"')
    expect(html).to include("Alpha")
    expect(html).to include("Beta")
  end

  it "marks tab 0 active by default when state key absent" do
    tabs = make_tabs(:view, ["X", "Y"])
    adapter.render_tabs(view, tabs, {})
    expect(view.to_html).to include("sw-tabs__tab--active")
  end

  it "marks the correct tab active based on state" do
    tabs = make_tabs(:view, ["X", "Y", "Z"])
    adapter.render_tabs(view, tabs, { view: 2 })
    html = view.to_html
    # Count active markers — exactly one
    expect(html.scan("sw-tabs__tab--active").length).to eq(1)
    # The third button gets the active class
    buttons = html.scan(/class="sw-tabs__tab[^"]*"/)
    expect(buttons[2]).to include("sw-tabs__tab--active")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/opal/adapter_opal_spec.rb -e "render_tabs" --format documentation 2>&1 | tail -10
```

- [ ] **Step 3: Add `render_tabs` to `Adapter::Opal`**

In `lib/stream_weaver/adapter/opal.rb`, add after `render_cdn_scripts`:

```ruby
def render_tabs(view, component, state)
  active_index = state[component.key] || 0
  view.div(class: "sw-tabs sw-tabs--#{component.variant || 'line'}") do
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

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/opal/adapter_opal_spec.rb -e "render_tabs" --format documentation 2>&1 | tail -10
```

- [ ] **Step 5: Full suite**

```bash
bundle exec rspec spec/ 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add lib/stream_weaver/adapter/opal.rb spec/opal/adapter_opal_spec.rb
git commit -m "feat(opal): render_tabs — tab navigation via register_callbacks protocol"
```

---

## Task 6: `Adapter::Opal#render_table`

**Files:**
- Modify: `lib/stream_weaver/adapter/opal.rb`
- Test: `spec/opal/adapter_opal_spec.rb`

`Table#render` calls `view.adapter.render_table(view, resolved[:headers], resolved[:rows], table_options, state)` — pre-resolved headers/rows plus the `table_options` hash (which now includes `:key`).

- [ ] **Step 1: Write failing tests**

Add to `spec/opal/adapter_opal_spec.rb`:

```ruby
describe "#render_table" do
  let(:headers) { ["Name", "Score"] }
  let(:rows)    { [["Alice", 90], ["Bob", 75], ["Carol", 85]] }
  let(:options) { { key: :scores, sortable: false, striped: false, bordered: false,
                    scrollable: false, sticky_header: false } }

  def render_table(opts_override = {}, state_override = {})
    adapter.render_table(view, headers, rows, options.merge(opts_override), state.merge(state_override))
  end

  it "emits a .sw-table wrapper div" do
    render_table
    expect(view.to_html).to include('class="sw-table"')
  end

  it "emits header cells as plain th when not sortable" do
    render_table
    html = view.to_html
    expect(html).to include("<th>Name</th>")
    expect(html).to include("<th>Score</th>")
    expect(html).not_to include("data-sw-invoke")
  end

  it "emits th buttons with data-sw-invoke when sortable: true" do
    render_table(sortable: true)
    html = view.to_html
    expect(html).to include('data-sw-invoke="scores_sort_0"')
    expect(html).to include('data-sw-invoke="scores_sort_1"')
  end

  it "adds sw-table--striped class when striped: true" do
    render_table(striped: true)
    expect(view.to_html).to include("sw-table--striped")
  end

  it "adds sw-table--bordered class when bordered: true" do
    render_table(bordered: true)
    expect(view.to_html).to include("sw-table--bordered")
  end

  it "adds sw-table--scrollable class when scrollable: true" do
    render_table(scrollable: true)
    expect(view.to_html).to include("sw-table--scrollable")
  end

  it "sorts rows ascending by sort_col when sort state present" do
    render_table(
      { sortable: true },
      { "scores_sort_col" => 0, "scores_sort_dir" => :asc }
    )
    html = view.to_html
    alice_pos = html.index("Alice")
    bob_pos   = html.index("Bob")
    carol_pos = html.index("Carol")
    expect(alice_pos).to be < bob_pos
    expect(bob_pos).to be < carol_pos
  end

  it "reverses sort when sort_dir is :desc" do
    render_table(
      { sortable: true },
      { "scores_sort_col" => 0, "scores_sort_dir" => :desc }
    )
    html = view.to_html
    alice_pos = html.index("Alice")
    carol_pos = html.index("Carol")
    expect(carol_pos).to be < alice_pos
  end

  it "emits sort indicator on active column" do
    render_table(
      { sortable: true },
      { "scores_sort_col" => 0, "scores_sort_dir" => :asc }
    )
    expect(view.to_html).to include("↑")
  end

  it "emits ↓ when sort_dir is :desc" do
    render_table(
      { sortable: true },
      { "scores_sort_col" => 0, "scores_sort_dir" => :desc }
    )
    expect(view.to_html).to include("↓")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/opal/adapter_opal_spec.rb -e "render_table" --format documentation 2>&1 | tail -10
```

- [ ] **Step 3: Add `render_table` to `Adapter::Opal`**

In `lib/stream_weaver/adapter/opal.rb`, add after `render_tabs`:

```ruby
def render_table(view, headers, rows, options, state)
  key       = options[:key]
  sort_col  = state["#{key}_sort_col"]
  sort_dir  = (state["#{key}_sort_dir"] || :asc).to_sym

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

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/opal/adapter_opal_spec.rb -e "render_table" --format documentation 2>&1 | tail -10
```

- [ ] **Step 5: Full suite**

```bash
bundle exec rspec spec/ 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add lib/stream_weaver/adapter/opal.rb spec/opal/adapter_opal_spec.rb
git commit -m "feat(opal): render_table — sortable client-side, visual modifiers, via existing adapter convention"
```

---

## Done

After all 6 tasks, run the full suite one final time:

```bash
bundle exec rspec spec/ 2>&1 | tail -5
```

Then create beads issues for the 6 tasks (if not already tracked) and push:

```bash
git push
```
