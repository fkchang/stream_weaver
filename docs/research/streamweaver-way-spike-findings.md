# My Todos Parity Spike — Where StreamWeaver Breaks

Empirical companion to `docs/research/2026-08-17-hotwire-concept-map.md`. That map assessed the
gaps by reading the code; this one assessed them by building the app and watching what came back
over the wire.

**The app**: `examples/my_todos/` — a StreamWeaver mirror of the learnhotwire.com course's Rails
"My Todos" app (`github.com/learnhotwire/rails`), attempting the four Turbo Frames chapter
features under one rule: **zero custom JavaScript in app code**. No script tags, no inline JS, no
hand-written Alpine. DSL verbs and CSS only.

**Framework changes made: none.** Everything below is recorded, not patched.

**Evidence status**: every measurement here is server-side (curl against a live boot on port
4599). Response shapes, byte counts, emitted htmx attributes, and timings are facts. Claims about
what a *user* sees — focus retention while typing, whether the CSS hover reveal actually reveals,
whether morph swaps look smooth — are pending a main-thread browser pass and are marked as such.

---

## Scorecard

| # | Feature | Verdict | Breaks at |
|---|---|---|---|
| 1 | Inline editing | **WORKS** | — (deep-linkable edit state is the only Rails behavior not matched) |
| 2 | Search | **PARTIAL** | An input cannot target a sibling fragment; no `data-turbo-frame` equivalent |
| 3 | Hover cards | **PARTIAL** | CSS reveal works; no visibility-triggered fetch exists, so every card renders eagerly |
| 4 | Infinite scroll | **DEGRADED** | No visibility trigger *and* no nested/appending fragments; degrades to O(n)-per-click "Load more" |

Two surprise stumbles beyond the two expected gaps, both in the silent-failure class — see
[Surprise stumbles](#surprise-stumbles).

---

## How fragment scoping actually works (the fact everything else follows from)

Worth stating up front, because three of the four findings are consequences of it.

StreamWeaver's fragment scoping is **lexical, not declarative**. `Adapter::AlpineJS#htmx_attrs`
(`lib/stream_weaver/adapter/alpinejs.rb:1277-1295`) asks the view for `current_fragment_id` — the
fragment the element is *being rendered inside* — and, if there is one, rewrites the element's
`hx-target` to `#<that fragment id>` and appends a signed `_sw_fragment` token to its POST URL.

Turbo is the opposite: a link or form *names* the frame it drives, from anywhere on the page
(`data: {turbo_frame: :todos}`). Position on the page is irrelevant.

So in StreamWeaver, **where you write a component determines what it can update**. The one escape
hatch is `updates:` (and `primary:`), which lets an element name additional fragments — but it is
read only by `button` and `clickable` (`lib/stream_weaver/app.rb:742`, `:799`). No input component
passes it through.

---

## 1. Inline editing — WORKS

### The Rails mechanism

Two frames with the same `dom_id`, in two different templates:

- `app/views/projects/show.html.erb` — `turbo_frame_tag @project, :edit_name` wrapping
  `<h1><%= link_to @project.name, edit_project_name_path(@project) %></h1>`
- `app/views/projects/names/edit.html.erb` — `turbo_frame_tag @project, :edit_name` wrapping
  `form_with model: @project, url: project_name_path(@project)`

The link lives *inside* the frame it replaces. Clicking it fetches the edit page; Turbo discards
everything except the matching frame and swaps it in. Key elements: the `turbo_frame_tag` pair,
`dom_id` deriving the shared id from the record, and the frame not touching the URL.

**The "edit safe" half** is a separate lesson and the more interesting one. The chapter
(transcript 17:28–22:00) demos `form_with model: @todo` with no `url:`, which defaults to the
generic `project_todo_path` whose strong params are
`params.expect(todo: [:name, :description, :due_date, :completed, :user_id])`. Editing just the
title silently flips `completed` too, because the form carries a hidden `completed` field and the
generic endpoint permits it. Neither version errors. The fix is a **narrow nested resource** —
`resource :name` → `Projects::NamesController` → `params.expect(project: [:name])` — reached by
passing an explicit `url:`.

### The StreamWeaver equivalent

One `fragment` per row, keyed by record id, branching on `state[:editing_id]`:

```ruby
fragment("todo-#{todo[:id]}") do
  if state[:editing_id].to_s == todo[:id]
    form_for(store: TodoStore, fields: TITLE_ONLY, name: :"todo_#{todo[:id]}_form",
             record: todo, on_success: ->(_id) { state[:editing_id] = nil }) { submit_label 'Save' }
  else
    text "#{todo[:completed] ? '☑' : '☐'}  #{todo[:title]}"
    button('Edit', key: todo[:id]) { |s| s[:editing_id] = todo[:id] }
  end
end
```

Because the Edit button and the form's submit are both rendered inside the fragment, both are
auto-scoped to it. Server-verified:

```
Edit button emitted:  hx-target="#sw-frag-todo-1"  hx-swap="morph:innerHTML"
                      hx-post="/action/btn_edit_70c8d6e8?_sw_fragment=eyJmIjoic3ctZnJhZy10b2RvLTEifQ...."
POST that action   →  1,327 bytes   (full page load of the same view: 108,792 bytes)
POST the form      →    806 bytes   ("Buy milk #1" → "Buy oat milk (renamed)", ☑ unchanged)
```

The flash arrives free as an out-of-band swap into `#sw-frag-flash` — `InteractionRunner` adds a
fragment named `flash` to the OOB extras automatically whenever a scoped response set a flash
message (`lib/stream_weaver/interaction_runner.rb:139-142`).

**Edit-safety is structural here, not a thing you remember to do.** `form_for_coerce`
(`lib/stream_weaver/app.rb:1650-1663`) iterates the *declared* `fields:` and builds the update
hash from those alone. A form declared with `fields: [Field.new(:title, :string, {})]` cannot
write `:completed` — there is no `url:` to forget, and no generic endpoint to fall back to. This
is a genuine improvement on the Rails ergonomics the chapter warns about: Rails makes the safe
path opt-in, StreamWeaver makes the unsafe path unexpressible.

### What is not matched

Rails' edit state is a real URL (`/projects/1/name/edit`) you can visit, link, or reload.
StreamWeaver's `state[:editing_id]` is session state; the scoped response sends `hx-push-url: /`
and the URL never reflects which row is open. Both frameworks agree the URL *shouldn't change on
a frame swap*, so this matches Turbo's default behavior — but Rails still has a canonical URL for
the edit view, and StreamWeaver has none unless you route it yourself (which `resource`'s
`edit_view :page` would give you, at the cost of it being a page navigation rather than a scoped
swap — the tradeoff `llms.txt` already names).

**Browser pass owed**: confirm the row visibly turns into a form and back, that only that row
changes, and that the other rows' completed marks are untouched.

---

## 2. Search — PARTIAL

### The Rails mechanism

The form sits **outside** the results frame and names it:

```erb
<%= form_with url: project_path(@project), method: :get, data: {turbo_frame: :todos} do |form| %>
  <%= form.search_field :query, value: params[:query],
        data: {controller: :autosubmit, action: "input->autosubmit#submit"} %>
<% end %>

<%= turbo_frame_tag "todos", target: :_top, data: {turbo_action: :advance} do %>
  <%= render @todos %>
<% end %>
```

Key elements: `data-turbo-frame` pointing the response at a frame elsewhere on the page;
`method: :get` so the query lands in the URL and stays cacheable; `data: {turbo_action: :advance}`
so the frame swap *does* push history here (opt-in, unlike feature 1); `target: :_top` so links in
the results escape the frame instead of dying in "Content missing"; and a Stimulus `autosubmit`
controller for submit-as-you-type — which must call `requestSubmit()`, not `submit()`, or Turbo
never sees the event (transcript 24:xx–25:26).

### What StreamWeaver does better

`text_field` auto-submits on input with **no controller at all**, debounced:

```
hx-trigger="keyup changed delay:500ms"
```

That is the whole of the chapter's Stimulus `autosubmit` controller plus its `requestSubmit()`
gotcha, gone. Deep-linking works in both directions:

- **In**: `GET /search?query=oat` on a fresh session renders `1 of 60 todos` — query params sync
  to state before render.
- **Out**: typing pushes `hx-push-url: /search?query=milk`, via a `route_with` builder that
  appends the query when the search view is active.

### Where it breaks

**An input cannot target a sibling fragment.** `render_text_field`
(`lib/stream_weaver/adapter/alpinejs.rb:81-145`) calls `htmx_attrs(...)` without ever passing
`sw_updates:`, so a text field gets exactly one target: its own enclosing fragment, or
`#app-container` if it isn't inside one. There is no `data-turbo-frame` equivalent.

The app renders both arrangements side by side. Measured, same server, same query:

| Arrangement | Emitted `hx-target` | Response |
|---|---|---|
| A — field outside the results fragment (the Rails shape) | `#app-container` | 2,123 bytes — whole app body: navbar, both sections |
| B — field moved inside the results fragment | `#sw-frag-search-results-inside` | 800 bytes |

So search-as-you-type is *achievable* with zero JS, but only by inverting the Rails layout: the
field has to live inside the region it filters. That has a cost the Rails version doesn't pay —
the input re-renders itself on every keystroke (the `<input>` tag is visible in B's 800-byte
response body), so caret and focus survive only if idiomorph's `morph:innerHTML` preserves them.

**Browser pass owed — this is the load-bearing unknown for this feature.** Type continuously into
arrangement B's field and confirm focus, caret position, and in-flight characters survive the
morph. If they don't, StreamWeaver has no zero-JS search-as-you-type at all, and this drops from
PARTIAL to BREAKS. Also worth checking arrangement A for a visible full-body flash on each
keystroke.

### The primitive that would close it

`updates:` on input components — i.e. `text_field :query, updates: :search_results` resolving the
same way a button's does. Today that exact line is silently ignored (see stumble (b) below), which
makes this gap worse than a plain absence.

---

## 3. Hover cards — PARTIAL (expected gap, confirmed)

### The Rails mechanism

From `app/views/todos/_todo.html.erb`:

```erb
<div class="hovercard">
  <%= image_tag todo.user.gravatar_url, class: "avatar" %>
  <%= turbo_frame_tag todo.user, :hovercard,
        src: project_user_path(todo.project, todo.user), loading: :lazy do %>
  <% end %>
</div>
```

plus three lines of CSS: `.hovercard-panel { display: none }`, `position: absolute` in a
`position: relative` parent, and `.hovercard:hover turbo-frame { display: block }`.

The mechanism is a two-part interlock, and both parts matter:

1. **CSS does the revealing.** No hover handler, no fetch call, no state.
2. **`loading="lazy"` does the fetching.** Turbo's IntersectionObserver fires when the frame
   becomes *visible* — and it does not know or care why. `display: none` means not visible, so no
   request goes out; the CSS `:hover` rule flips it to visible, and that alone triggers the fetch.
   It loads exactly once — frames don't refetch on becoming visible again.

Also worth carrying forward: the shipped course code keys the frame by `todo.user`, which the
chapter itself demos as a bug (transcript 38:52–40:24). Two todos assigned to the same person emit
the same frame id twice — duplicate ids, invalid HTML, two frames answering to one name. The rule
is **key the frame by whatever is unique per position on the page, not by what the content is
about** — here, the todo, even though the card displays a user.

### What StreamWeaver gets

Part 1, in full. `use_stylesheet` (`lib/stream_weaver/app.rb:1416`) injects the CSS, and the
rendered page carries `.hovercard:hover .hovercard-panel { display: block; }`. Zero JavaScript,
zero DSL gymnastics.

### Where it breaks

Part 2 does not exist. There is no visibility-triggered anything:

- `Components::Fragment#initialize` (`lib/stream_weaver/components.rb:107-115`) takes `(name, id)`
  and **nothing else** — no `src:`, no `loading:`. A fragment renders inline, in the same request,
  always.
- `tabs lazy: true` is click-triggered POST-then-morph, not visibility-triggered — and
  `features/route-tabs.feature` already deprecates it.
- `every(n)` is a post-load SSE timer, not an initial-load deferral.
- `div hover_class:` toggles a CSS class client-side but fetches nothing.

So every card body is rendered eagerly, in the same request as the list. Server-verified: the
initial `/hover-cards` HTML contains all 6 fully-populated panels and zero `loading="lazy"` /
`IntersectionObserver` markers.

**The cost, measured.** The store has an opt-in `UserStore.delay`, the equivalent of the chapter's
`sleep 1.5`. Booting with `SW_HOVERCARD_DELAY=1.5`:

```
GET /hover-cards   9.151s   (6 cards × 1.5s, all paid up front, whether or not anyone hovers)
GET /search        0.003s   (same server, same session, no cards)
```

In Rails that page renders instantly, each card costs 1.5s only if hovered, and only the first
time. StreamWeaver pays for all of them, always. On a list of 60 rows it is 90 seconds of work to
render a page nobody may hover at all.

**The workaround and what it costs.** There isn't a good one. Rendering eagerly (what the spike
does) is correct but pays the full cost up front and scales with list length. Converting the
reveal to a click — a `button` with `updates:` on a shared detail fragment — does fetch lazily,
but it is no longer a hover card: it needs a click, it holds one card at a time, and it burns the
page's one detail region. Neither approximates "hover, and only then, and only once."

**Browser pass owed**: hover an assignee name and confirm the card actually appears and is
positioned sanely; confirm (via devtools Network) that **no request is made on hover** — that's
the observable signature of the missing primitive.

### The primitive that would close it

`visibility-lazy-fragments` (already a story in this epic). Concretely: `fragment(:name, loading: :lazy)`
rendering a placeholder plus an IntersectionObserver-triggered fetch, with fetch-once semantics.
The story should adopt Turbo's keying rule as a documented convention — key by position, not by
content — because StreamWeaver has no `dom_id` helper and today the author hand-applies it (see
`strict-ids-auto-keying`).

---

## 4. Infinite scroll — DEGRADED (expected gap, confirmed, plus a second one)

### The Rails mechanism

From `app/views/todos/index.html.erb` — "Russian dolls":

```erb
<%= turbo_frame_tag :todos_page, @pagy.page, target: :_top do %>
  <%= render partial: "todos/todo", collection: @todos, locals: {inline: true} %>
  <% if @pagy.next %>
    <%= turbo_frame_tag :todos_page, @pagy.next, src: todos_path(page: @pagy.next),
          loading: :lazy, target: :_top do %>
      <%= tag.div "Loading..." %>
    <% end %>
  <% end %>
<% end %>
```

Key elements: the outer frame's id is built from the *current* page number; a second frame nested
inside it is keyed to the *next* page, points at that page's URL, and is `loading: :lazy`. Scroll
it into view and it fetches; the response is the same template rendered for page N+1, whose outer
frame id matches the placeholder that asked for it, and which carries the *next* placeholder
inside itself. The chain propagates until pages run out.

Two details that matter:

- **Nesting, not replacing.** If page N+1 replaced page N's frame instead of landing inside it,
  you'd have built pagination with a scroll trigger — the user scrolls down and watches what they
  were reading vanish. Nesting means nothing is ever removed; the DOM gets deeper, not wider.
- **The `@pagy.next` guard.** Without it, the last page renders a frame with a blank id and the
  chain dead-ends in "Content missing".

The controller is one line of Pagy, every page is a real linkable URL (`?page=7` works, and you
can start infinite-scrolling from there), and there are no scroll listeners and no
IntersectionObserver in app code.

### What StreamWeaver gets

A click-driven "Load more" inside a fragment. It works, and the scoping works — the button emits
`hx-target="#sw-frag-todo-pages"`. The `if page < TodoStore.page_count` guard is the direct
analogue of `@pagy.next`.

### Where it breaks — twice

**(a) No visibility trigger.** Same missing primitive as feature 3. A button substitutes for the
scroll, which changes the interaction from "infinite scroll" to "paginate by clicking".

**(b) No nested or appending fragments.** This one is separate and, for this feature, worse. A
fragment swap is always `morph:innerHTML` — `HTMX_SWAP` is a hardcoded constant
(`lib/stream_weaver/adapter/alpinejs.rb:29`) and `Fragment` accepts no options to override it. So
each "Load more" must re-render and re-send **every row loaded so far**:

```
click 1:  1,248 bytes   20 rows in payload
click 2:  1,603 bytes   30 rows in payload
click 3:  1,957 bytes   40 rows in payload
```

O(n) per click, O(n²) over a session. Turbo's nested frames send exactly one page per fetch,
forever — O(1) per click, no matter how deep you are.

The row-granular narrowing that exists (`RowSwapView`,
`InteractionRunner#row_swap_for`, `lib/stream_weaver/interaction_runner.rb:190-214`) does not
rescue this: it requires the fragment to contain exactly one column-DSL `table` with row identity,
and its `:create` branch narrows only when **exactly one** row was added
(`new_ids.length == old_ids.length + 1`). A page-at-a-time append of 10 rows falls through to full
fragment content even if the list were rendered as a table.

**Browser pass owed**: click Load more a few times and confirm rows accumulate rather than
replace, and that scroll position is not lost on the morph.

### The primitives that would close it

Two, composed — which is why this feature is the epic's best integration test:

1. `visibility-lazy-fragments` (feature 3's primitive), and
2. `deferred-fragments-src` extended with a nesting/append semantic, so a fragment's response can
   land *inside* the previous one instead of replacing it. `Streamer#append` already has the right
   verb vocabulary but is reachable only from `every` timer blocks.

---

## Surprise stumbles

Both are silent failures, and both are the kind an author hits precisely *because* they went
looking for the missing primitive above.

### (a) `defer` is an unimplemented no-op that silently drops its block

`lib/stream_weaver/display_dsl.rb:916`:

```ruby
def defer(&block); end
```

It sits in the display DSL alongside `every`, `after`, `watch`, and `on_start` — which are real
verbs implemented elsewhere — so it reads exactly like the deferred-rendering primitive an author
hunting for feature 3 or 4 would reach for. It is not. Probed:

```ruby
StreamWeaver::App.new('probe') do
  text 'BEFORE'
  defer { text 'INSIDE-DEFER' }
  text 'AFTER'
end
# components => [Text("BEFORE"), Text("AFTER")]
```

No raise, no warning, no comment in the source saying it's a stub. Content written inside a
`defer` block simply never appears, and nothing tells the author why.

### (b) `updates:` on an input is silently accepted and silently ignored

```ruby
text_field :q, updates: :results   # renders: hx-target="#app-container"
```

No raise, no warning. `updates:` is consumed only by `button` and `clickable`
(`lib/stream_weaver/app.rb:742`, `:799`); on any other component it lands in the options hash and
is never read. This is the single most likely wrong turn for someone porting the Rails search
feature — it is the natural transliteration of `data: {turbo_frame: :todos}`, it looks right, and
it produces a full-page swap with zero feedback.

Both stumbles are the concept map's §4 finding hitting real code: StreamWeaver chose self-healing
fallback over Hotwire's loud "Content missing", and that policy has quietly generalized from
*routing* fallbacks into *authoring* mistakes, where it is no longer a virtue. This is direct
evidence for `dev-loud-failure-overlay`, and suggests its scope should include build-time
validation of ignored options, not just runtime swap failures.

### (c) Minor: per-row `form_for` names leak into flash text

Standalone `form_for` derives its flash noun by stripping `_form` from `name:`
(`lib/stream_weaver/app.rb:608`), so a per-row form named `:todo_1_form` flashes
`"Todo_1 updated."` rather than `"Todo updated."`. Cosmetic, but per-row form names are exactly
what inline editing requires, so anyone following the documented inline-edit pattern will hit it.

---

## What this means for the epic

The two expected gaps were confirmed, and the confirmation was more specific than the concept map
predicted in two ways:

- **The lazy-fragment gap is really two gaps.** Visibility-triggering and nesting/appending are
  independent, and infinite scroll needs both. A `visibility-lazy-fragments` story that ships
  IntersectionObserver semantics alone gets hover cards and leaves infinite scroll still O(n) per
  click.
- **The input-can't-name-a-fragment gap wasn't on the map at all.** The concept map assessed
  fragments as PARTIAL on execution-model grounds (whole-rerun vs. per-frame dispatch). The
  practical blocker found here is narrower and more fixable: scoping is lexical, and `updates:`
  — the one declarative escape hatch — isn't wired to inputs. That looks like a small,
  high-leverage story, and it's what stands between StreamWeaver and a search feature that beats
  Rails' outright (the auto-submit half already does).

Order suggested by this spike: input `updates:` (small, unblocks feature 2 cleanly) →
`dev-loud-failure-overlay` scoped to include ignored-option validation (cheap, and both surprise
stumbles above disappear) → `visibility-lazy-fragments` → nesting/append on
`deferred-fragments-src`.

---

## Reproducing

```bash
SW_NO_OPEN=1 STREAMWEAVER_PORT=4599 ruby examples/my_todos/my_todos.rb
```

Then `/` (inline editing), `/search`, `/hover-cards`, `/infinite-scroll`. Boot with
`SW_HOVERCARD_DELAY=1.5` to reproduce the eager-render timing above. Kill the process when done.
