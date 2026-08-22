---
name: streamweaver-way
description: Use when building or changing an interactive StreamWeaver app or feature — inline editing, live search/filtering, per-row buttons, hover cards, infinite scroll, tabs, or any region slow enough to hold up the page. Encodes "The StreamWeaver Way": the conventions (fragments, defer:/lazy:, form_for, interactive-id keying, dev-loud/prod-self-heal) that make app code zero-JavaScript by default. For one-off mockups, diagrams, or dashboards to look at, use streamweaver-visual-companion instead; for long-form editorial documents, use streamweaver-doc-builder.
---

# The StreamWeaver Way

StreamWeaver is an *omakase* layer, not a widget kit: the backend and the frontend were
designed as one system, so the conventions below are the framework, not style advice.
Follow them and you write no JavaScript. Fight them and you write a lot.

**Read the laws. Drill into a recipe only when you're building that thing.**

---

## The Laws

**1. Key by what is unique per position on the page, not by what the content is about.**
Every interactive element needs a server-dispatchable id, and StreamWeaver derives one
for you (label + block source location, with `-dup-N` auto-disambiguation on repeats), so
you rarely pass anything. Auto-derived ids are *position*-stable, not *content*-stable:
insert or delete an earlier row and every later suffix shifts. Reach for `key:` only when
identity must outlive reordering, filtering, or deletion — per-row Edit/Delete buttons,
per-row fragments. Then key it by the thing that is unique *per row on this page* (the
todo), never by what the row happens to display (its assignee) — two rows sharing an
assignee is the classic collision, and it fails silently: hovering the second card shows
the first one's data. Precedence is `id:` > `key:` > auto. `key:` takes stable scalars
only (String/Symbol/Integer; anything else raises). Never key by positional index.

**2. Deferred over hand-rolled timers.** A slow region gets `fragment(..., defer: true)`
so the shell ships now and the region lands later. Never an `every(...)` poll, never a
"loading" flag toggled by a second request you wrote yourself. Measured on one 1.5s
region: initial GET 0.018s instead of 1.5s.

**3. Lazy means visible.** `lazy: true` holds the fetch until the fragment is actually
*visible* — scrolled into view, or CSS flipping an ancestor out of `display: none`.
Hidden content costs exactly nothing, and it fetches exactly once. That interlock is what
buys you hover cards and infinite scroll with no scroll handler and no state counter.

**4. Dev loud, prod self-heals.** A stale action token gets a 409 + full-container
re-render that is byte-for-byte identical in production — the user never sees an error.
In development only, the same response prepends a dismissible `.sw-dev-fallback` overlay
naming the stale target and the likely cause. This is a deliberate inversion of Hotwire's
"Content missing": keep the debugging signal, don't charge the user for it. If you see
that overlay, your wiring is wrong — don't style it away.

**5. State your intent in DSL verbs. Zero custom JavaScript is the default, not an
aspiration.** All four benchmark features below run with no script tag, no inline JS, no
hand-written Alpine — only DSL verbs and CSS. If you're reaching for JavaScript, you have
almost certainly missed a verb. Do not touch adapter internals (`lib/stream_weaver/
adapter/*`) or emit raw `hx-*` attributes from app code; the verbs own those.

**6. Trilaws as design filters.** Run every feature through all three:
*Matt* — is it findable and digestible (progressive disclosure for the long tail)?
*Forrest* — zero friction plus a real perk (if it can be automatic, it must be)?
*Gloria* — is the default path the correct path (design for the brain you have, not the
one that remembers to pass the right option)? Law 1's auto-keying is Gloria's Law in
code: the default already disambiguates, so the silent-wrong-callback bug can't happen.

---

## Core mechanics (everything below builds on these)

```ruby
app 'My App' do
  state[:count] ||= 0            # the whole block RE-RUNS on every interaction
  text "Count: #{state[:count]}"
  button('+') { |s| s[:count] += 1 }
end.run!
```

**`fragment(name) { ... }`** marks a region that interactions *inside it* swap on their
own, instead of swapping the whole app container. Everything interactive rendered inside
a fragment is auto-scoped to it — that scoping is the whole mechanism the recipes use.

| Form | Fetch timing | Use for |
|---|---|---|
| `fragment(:n) { }` | inline, with the page | scoping a swap to one region |
| `fragment(:n, defer: true) { }` | right after page load | slow regions off the critical path |
| `fragment(:n, lazy: true) { }` | first time it is visible | hover cards, infinite scroll, tab panels |

`lazy: true` implies `defer: true`. `placeholder:` accepts nothing (small spinner), a
String (rendered as text), or a Proc (run as DSL). **Give the placeholder height** — the
observer watches the wrapper, and a zero-area target never intersects.

**Three rules that apply to every deferred/lazy fragment:**

- The block is skipped on the shell render, so anything it *registers* (actions, timers)
  isn't registered until the fetch. Keep registration outside deferred blocks.
- A **named**-action button (`button 'X', action: :foo`) inside one does not fire — its
  token is minted outside the session's action manifest. Use a block button
  (`button('X') { |s| ... }`), which dispatches by id and is unaffected.
- Each fetch re-runs its **ancestors'** blocks. Nest for staging, not to split one
  expensive block into cheaper pieces.

**`form_for`** is the record-bound form primitive: seeds fields from a record, infers
create vs. update from record identity, coerces + validates on submit, calls
`store.create`/`store.update`, flashes, and PRGs. **Only the fields you declare are read
from the submitted state** — that allowlist is edit-safety by construction, not by
remembering to pass the right URL.

A **store** is any object answering `all`, `find(id)`, `create(attrs)`, `update(id, attrs)`,
`destroy(id)`. A plain module over an Array is enough to build all four recipes.

---

## The four benchmark recipes

These are the four Turbo Frames features from the learnhotwire.com course, in
StreamWeaver, with zero custom JavaScript. Recipe 1 defines the store; recipes 2-4 add
one method each to it, shown inline. Each is complete and runnable.

### 1. Inline editing (a row becomes a form in place)

One `fragment` per row, keyed by record id, branching on an `editing_id` in state. The
Edit button and the form submit both swap **just this row**, because both are rendered
inside that row's fragment.

```ruby
require 'stream_weaver'

module TodoStore
  @todos = [{ id: '1', title: 'Buy milk', completed: false },
            { id: '2', title: 'Ship it',  completed: true }]
  class << self
    def all = @todos
    def find(id) = @todos.find { |t| t[:id] == id.to_s }
    def create(attrs) = (id = (@todos.size + 1).to_s; @todos << { id: id, **attrs }; id)
    def update(id, attrs) = (t = find(id)) ? (t.merge!(attrs); true) : false
    def destroy(id) = (@todos.reject! { |t| t[:id] == id.to_s }; true)
  end
end

# Declare ONLY the editable field. A submit through this form cannot reach
# :completed -- the allowlist is enforced by construction.
TITLE_ONLY = [StreamWeaver::Field.new(:title, :string, {})].freeze

app 'My Todos' do
  TodoStore.all.each do |todo|
    fragment("todo-#{todo[:id]}") do
      if state[:editing_id].to_s == todo[:id]
        form_for(
          store: TodoStore,
          fields: TITLE_ONLY,
          name: :"todo_#{todo[:id]}_form",
          record: todo,
          on_success: ->(_id) { state[:editing_id] = nil }
        ) { submit_label 'Save' }
        button('Cancel', style: :secondary, key: "cancel-#{todo[:id]}") { |s| s[:editing_id] = nil }
      else
        hstack spacing: :sm do
          text "#{todo[:completed] ? '☑' : '☐'}  #{todo[:title]}"
          button('Edit', style: :secondary, key: "edit-#{todo[:id]}") { |s| s[:editing_id] = todo[:id] }
        end
      end
    end
  end
end.run!
```

**Gotchas**

- Per-row buttons **must** carry `key:` (Law 1). Without it the derived ids are
  position-stable only, and a delete or a filter shifts them under you.
- `on_success:` is **required** for standalone `form_for` (no `resource` block to fall
  back to for the post-submit transition).
- Standalone `form_for` derives its flash noun by stripping `_form` from `name:`, so
  `:todo_1_form` flashes `"Todo_1 updated."` — cosmetic, known, unfixed.
- Inside a `resource` block the shorter form works and the transition is free:
  `form_for :todo, record: todo do submit_label 'Save' end`.

### 2. Scoped live search (submit-as-you-type)

`text_field` auto-submits on input — no Stimulus controller, no debounce code. The only
decision is **where the field lives**, and it is a real trade-off:

```ruby
# Add to TodoStore. The blank guard is load-bearing -- see gotchas.
def TodoStore.search(query)
  return all if query.to_s.strip.empty?
  needle = query.to_s.downcase
  all.select { |t| t[:title].downcase.include?(needle) }
end

app 'Search' do
  # B -- field INSIDE the fragment: scoped morph, fewer bytes, focus and caret
  # survive. Cost: the field re-renders itself on every keystroke.
  fragment(:results) do
    text_field :query, placeholder: 'Filter todos…'
    results = TodoStore.search(state[:query])
    text "#{results.length} of #{TodoStore.all.length} todos"
    results.first(8).each { |t| text "• #{t[:title]}" }
  end
end.run!
```

**Gotchas**

- **`text_field :query, updates: :results` is silently accepted and silently ignored.**
  This is the natural transliteration of Rails' `data: {turbo_frame: :todos}` and it looks
  right; `updates:` is read only by `button` and `clickable`. There is no
  `data-turbo-frame` equivalent for inputs yet.
- Consequently an input can target only its own enclosing fragment or `#app-container`.
  **A field placed outside the results fragment swaps the whole container** — it works and
  filters correctly, it just costs the whole body every keystroke. Prefer arrangement B
  above unless you specifically need the field to never re-render itself.
- Guard the blank query in your store (`return all if query.to_s.strip.empty?`) or
  clearing the box makes the whole list vanish.
- Search is a GET filter, so put the query in the URL via `route_with` if you want it
  shareable.

### 3. Lazy hover cards (CSS reveals it; revealing it is what fetches it)

Nothing on the page fetches anything until the pointer arrives. Three lines of CSS plus
`lazy: true` — the two halves interlock.

```ruby
# Each todo carries a :user_id; UserStore is any lookup, deliberately slow here
# so "eager or lazy?" is observable.
module UserStore
  USERS = { 'u1' => { id: 'u1', name: 'Ada Lovelace', role: 'Engineering' },
            'u2' => { id: 'u2', name: 'Alan Turing',  role: 'Research' } }.freeze
  def self.find(id) = USERS[id]
end

app 'Directory' do
  use_stylesheet <<~CSS
    .hovercard { position: relative; display: inline-block; cursor: help; }
    .hovercard .hovercard-panel { display: none; position: absolute; top: 1.6em; left: 0; z-index: 50; min-width: 15rem; }
    .hovercard:hover .hovercard-panel { display: block; }
  CSS

  TodoStore.all.each do |todo|
    user = UserStore.find(todo[:user_id])
    div class: 'hovercard' do
      text user[:name]
      div class: 'hovercard-panel' do
        # Keyed by the TODO, not the user -- see the gotcha below.
        fragment(:"hovercard_#{todo[:id]}", lazy: true, placeholder: 'Loading…') do
          card do
            header3 user[:name]
            text user[:role]
          end
        end
      end
    end
  end
end.run!
```

**Gotchas**

- **Key by the todo, not the user.** Two todos sharing an assignee would emit the same
  fragment name twice; hovering the second shows the first one's card, silently. This is
  Law 1 in its purest form.
- `display: none` means no fetch, for as long as it lasts — that is the guarantee that
  makes six cards cost zero on page load. Don't hide the panel with `visibility: hidden`
  or `opacity: 0`; those stay visible to the observer and every card fetches eagerly.
- It fetches **once**. Hover away and back and the landed content stays put.
- To verify laziness: `document.querySelectorAll('.sw-fragment-lazy').length` counts
  fragments that have *not* fetched yet.

### 4. Russian-doll infinite scroll (nested lazy fragments)

Page N's block ends by declaring page N+1 as its own lazy fragment, nested inside it.
Page N+1 does not exist in the DOM — and never fetches — until page N has landed and been
scrolled past. That recursion is the entire pagination logic: no scroll handler, no page
counter in state, no "Load more" button.

```ruby
# One page's slice -- never everything-so-far. Empty return terminates the chain.
TodoStore::PER_PAGE = 10
def TodoStore.page(number) = all.drop(([number.to_i, 1].max - 1) * PER_PAGE).first(PER_PAGE)

def scroll_page(number)
  fragment(:"page_#{number}", lazy: true, placeholder: 'Loading…') do
    TodoStore.page(number).each { |t| card { text t[:title] } }
    # The guard is load-bearing: without it the chain dead-ends in a blank fragment.
    scroll_page(number + 1) unless TodoStore.page(number + 1).empty?
  end
end

app('Feed') { scroll_page(1) }.run!
```

**Gotchas**

- Have the store return **one page's slice** (`all.drop((n - 1) * PER_PAGE).first(PER_PAGE)`),
  never everything-so-far. Each response should be a constant size; if payloads grow
  per page, you're re-sending rows.
- Each fetch re-runs its ancestors' blocks, so keep per-page work cheap. Nested ids are
  `parent--child`, so page 3 is `sw-frag-page-1--page-2--page-3`.
- **Inside a tab, the lazy fragment goes INSIDE a `tab` block, never beside one** at the
  top level of a `tabs` block — a non-tab child there shifts every panel index. Route tabs
  (`tabs :view, url: true`) render inactive panels as `display: none`, so a lazy fragment
  in one waits until that tab is opened:

  ```ruby
  tabs :view, url: true do
    tab('Summary') { text summary_line }
    tab('Revenue') { fragment(:revenue, lazy: true) { revenue_table } }
  end
  ```

---

## Anti-patterns (each one has bitten someone)

- **`defer { ... }`** — the bare verb is not the deferred primitive. It now raises and
  names the real one: `fragment(:name, defer: true)`.
- **`every(...)` to refresh a slow region** — that's Law 2. Use `defer:`.
- **Named-action buttons inside a deferred/lazy fragment** — they don't fire. Block
  buttons.
- **Keying by positional index** — `key: i` is exactly the identity that reordering
  destroys. Key by record id.
- **`text "**bold**"`** — `text` does not render markdown. Use `md`.
- **`spacer` / `divider`** — don't exist. `div(style: 'height:24px')`.
- **`<button onclick="location.href=...">`** — bypasses htmx, full reload, loses state.
  Use `link_to` / `nav_item` with a real `href`.
- **Assuming port 4567** — StreamWeaver finds a free port and prints the real URL. Read
  stdout.

**Catch keying bugs before they ship:** `strict_ids` turns a derived-id collision from a
warning into a hard failure. It raises in development and test, and degrades to a warning
in production (a live page shouldn't 500 over an id the framework already disambiguated).

```ruby
StreamWeaver::App.new('My App', strict_ids: true) { ... }   # per app
StreamWeaver.strict_ids = true                              # global
SW_STRICT_IDS=1 ruby my_app.rb                              # env, e.g. in CI
```

---

## Going deeper (pointers only — these are not summarized here)

**The worked example set.** `examples/my_todos/` is all four recipes above in one running
app, annotated with the Rails mechanism each one mirrors. Boot it with
`SW_NO_OPEN=1 ruby examples/my_todos/my_todos.rb`, and `SW_HOVERCARD_DELAY=1.5` to feel
the difference lazy makes.

**`llms.txt` (aliased as `docs/for_llms.md`)** — the full DSL reference. Sections that
extend this skill, by name:

| Section | What it adds |
|---|---|
| Interactive IDs and keying | Full precedence rules, `strict_ids`, `clickable` |
| Record-Bound Forms (`form_for`) | Every option, in-block DSL, validation semantics |
| Turbo Frame-Style Inline Editing with `form_for` | The `resource`-based variant of recipe 1 |
| Deferred Fragments (`fragment ..., defer: true`) | Placeholders, nesting, export behavior |
| Lazy Fragments (`fragment ..., lazy: true`) | Both guarantees, and all three recipes |
| Dev Loud, Prod Self-Heal | What the overlay names, and what it can't detect |
| Resource Scaffolding | `resource` CRUD, named-route helpers |
| Route Tabs (`tabs url: true`) | Deep-linkable tabs, URL authority ordering |
| Repo Conventions | The full anti-pattern list |

**Reference docs.** `docs/resource-dsl.md` (`resource` + `form_for` full reference),
`docs/routing.md` (**read Common Pitfalls before any app with more than a couple of
routes**), `docs/crud-patterns.md`, `docs/components_reference.md`.

**Decision docs — read when you want the *why*, or are extending the primitive.**
`docs/research/streamweaver-way-spike-findings.md` (what broke and how each break was
closed — the source of every gotcha above),
`docs/research/2026-08-22-lazy-fragments-trigger-decision.md` (why `intersect once` and
not `revealed`),
`docs/research/2026-08-22-learnhotwire-syllabus-coverage.md` (Hotwire feature-by-feature
coverage: what exists, what's next),
`docs/streamweaver-frontend-vision.md` (the strategic thesis).

**Sibling skills.** `streamweaver-visual-companion` for mockups, diagrams, and dashboards
you just want to look at; `streamweaver-doc-builder` for long-form editorial documents.
This skill is for apps people interact with.
