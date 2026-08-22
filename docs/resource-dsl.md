# StreamWeaver Resource DSL

Convention-over-configuration CRUD scaffolding. One `resource` block replaces 30–50 lines of route/state/form boilerplate.

---

## Quick Start

```ruby
require 'stream_weaver'

module PostStore
  @posts = [{ id: '1', title: 'Hello', body: 'First post', status: 'published' }]
  def self.all;        @posts; end
  def self.find(id);   @posts.find { |p| p[:id] == id }; end
  def self.create(attrs)
    id = ((@posts.map { |p| p[:id].to_i }.max || 0) + 1).to_s
    @posts << { id: id, **attrs }; id
  end
  def self.update(id, attrs); post = find(id) or return false; post.merge!(attrs); true; end
  def self.destroy(id);       @posts.reject! { |p| p[:id] == id }; true; end
end

app 'Blog' do
  page :home, '/' do
    header1 'My Blog'
  end

  resource :post, store: PostStore do
    field :title,  :string
    field :body,   :text
    field :status, :enum, values: %w[draft published]
  end
end.run!
```

That single `resource` block gives you:

| URL | Action |
|---|---|
| `GET /posts` | Index — table with View / Edit / Delete per row |
| `GET /posts/new` | New — form with field inputs, Create button |
| `GET /post/:id` | Show — card with field values, Edit / Delete buttons |
| `GET /post/:id/edit` | Edit — form seeded from record, Save button |
| Delete button | Inline confirmation alert, then destroys record |

All URLs are deep-linkable and browser back/forward works.

---

## DSL Reference

### `resource`

```ruby
resource :name, store: MyStore, plural: 'custom_plural' do
  # field, edit_view, new_view, only, except, override blocks
end
```

| Option | Default | Description |
|---|---|---|
| `store:` | required | Object responding to store protocol (see below) |
| `plural:` | `"#{name}s"` | Override pluralization for irregular nouns |

**Declare `page` / `route` calls before `resource` blocks.** The routing chain is first-registered-wins; static page routes must appear before resource collection/member routes.

---

### `field`

```ruby
field :name, :type
field :name, :type, values: [...]   # for :enum
```

| Type | Input component rendered |
|---|---|
| `:string` | `text_field` |
| `:text` | `text_area` (4 rows) |
| `:enum` | `select` with `values:` list |
| `:boolean` | `checkbox` |
| `:integer` / `:number` | `text_field` |
| `:date` | `text_field` |

---

### `edit_view` / `new_view`

```ruby
edit_view :page    # URL-addressable /resource/:id/edit (default: :modal)
new_view  :page    # URL-addressable /resource/new    (default: :modal)
```

---

### `only` / `except`

```ruby
only   %i[index show]        # whitelist actions
except %i[destroy]           # blacklist actions
```

Default set: `[:index, :show, :new, :edit, :destroy]`

---

### Override Blocks

Fully replace any default view. Block runs in App context (`instance_exec`).

```ruby
resource :goal, store: GoalStore do
  field :title,   :string
  field :horizon, :enum, values: %w[month quarter year]

  index do |goals|
    header1 'Goals'
    goals.group_by { |g| g[:horizon] }.each do |horizon, gs|
      header3 horizon.capitalize
      table gs do
        column :title
      end
    end
  end

  show do |goal|
    card { header3 goal[:title]; text goal[:horizon] }
  end
end
```

| Block | Receives | Replaces |
|---|---|---|
| `index do \|items\|` | Array of all records | Default index table |
| `show do \|item\|` | Single record hash | Default show card |
| `new do \|_\|` | nil | Default new form |
| `edit do \|item\|` | Single record hash | Default edit form |

App ivars (`@current_form`, `@form_context`) are saved before the block runs and restored after, preventing bleed-through.

---

### `page` and `route`

```ruby
page :home, '/' do
  header1 'Welcome'
end

route :about, '/about'   # same as page with empty block
```

Declares a static named route. Renders the block when the current URL matches. Use before `resource` blocks.

---

### `form_for`

A resource-bound form primitive: seeds fields from a record, infers create vs. update
from record identity, renders inputs via the shared field-type table, and wires submit
to coerce → validate → `store.create`/`update` → flash + PRG. It's what `resource`'s own
default `new`/`edit` views call under the hood — `form_for` exposes the same machinery
for use inside your own override blocks.

```ruby
resource :person, store: PersonStore do
  field :name, :string
  field :role, :enum, values: %w[lead champion decision_maker]

  edit do |person|
    header1 "Edit #{person[:name]}"
    form_for :person, record: person do
      submit_label "Save"
      cancel_label "Cancel"
    end
  end

  new do
    header1 "New Person"
    form_for :person do
      submit_label "Create"
    end
  end
end
```

| Argument | Default | Description |
|---|---|---|
| `resource_name` | `nil` | A registered `resource` name — reuses its `store:`/`fields:` |
| `record:` | `nil` | The record being edited. `nil`, or an id-less hash, means create mode |
| `store:` | resource's store | Required if `resource_name` is omitted |
| `fields:` | resource's fields | Required if `resource_name` is omitted |
| `name:` | `"#{singular}_form"` | Scope/form name override |
| `on_success:` | resource's default transition | `Proc`, `instance_exec`'d with the new/updated id |
| `validate:` | `nil` | `Proc`, called with coerced values, returns `Hash[field, Array[String]]` of extra errors |

Can also be used standalone, without a `resource` block, by passing `store:`/`fields:`
directly:

```ruby
form_for store: PersonStore, fields: [
  StreamWeaver::Field.new(:name, :string, {}),
  StreamWeaver::Field.new(:age, :integer, {})
], name: :person_form
```

**Create vs. update inference** — a `nil` `record:`, or a `record:` whose `:id` is nil,
means create; a present record with an id means update. This also sets the default
submit label (`"Create"` / `"Save"`).

**Seeding and dirty-draft safety** — the form's scope is seeded from `record:` only on
the first render for that record id, and never re-seeded on subsequent re-renders for
the same id — an unrelated re-render (a sidebar filter, a toast dismiss) never clobbers
an in-progress edit. Switching to a different record id (e.g. navigating from editing
person `1` to editing person `2`) re-seeds fresh, so there's no cross-record leakage.

**Validation** — coercion failures (`:integer`/`:number` fields that don't parse) and any
`validate { }` block errors both populate `state[:"#{name}_form_errors"]`, rendered as a
single `Alert(variant: :error)` summary above the fields. A validation failure is a
same-request re-render, not a redirect — the user's just-typed values stay in the scope
and the store is never called.

**Success** — on a valid submit, `form_for` calls `store.create`/`store.update`, sets
`flash[:notice]`, and transitions to the resource's `show` action (or `index` if the
resource doesn't declare `show`) with the URL pushed via the existing PRG mechanism.
Pass `on_success:` to override the transition — required for standalone (non-`resource`)
usage, which has no resource action to fall back to.

**In-block DSL** — inside the `form_for do ... end` block:

| Call | Effect |
|---|---|
| `submit_label "text"` | Overrides the default submit button label |
| `cancel_label "text"` | Adds a Cancel button (omitted by default) |
| `validate { \|values\| ... }` | Registers the extra validation hook described above |
| any other field/component call | Renders alongside the auto-generated fields, inside the same form |

All three (`submit_label`/`cancel_label`/`validate`) raise if called outside a `form_for`
block.

**Inline-edit example** — the course's [Turbo Frame inline-editing pattern](for_llms.md#turbo-frame-style-inline-editing-with-form_for)
(click a title to edit it in place, submit swaps back to the display view) is a direct
`form_for` use case; see `docs/for_llms.md` for the worked example.

---

## Named-Route Helpers

Defined automatically on the App instance when `resource :post` is declared:

| Helper | Returns |
|---|---|
| `posts_path` | `"/posts"` |
| `new_post_path` | `"/posts/new"` |
| `post_path(rec)` | `"/post/#{rec[:id]}"` |
| `edit_post_path(rec)` | `"/post/#{rec[:id]}/edit"` |

For irregular plurals (`plural: 'people'` on `:person`), helpers use the overridden plural: `people_path`, `new_person_path`, etc.

---

## Store Protocol

Stores are duck-typed. Any object (module, class, instance) that responds to these five methods works:

| Method | Signature | Return |
|---|---|---|
| `all` | `()` | Array of record hashes |
| `find` | `(id)` | Record hash or nil |
| `create` | `(attrs_hash)` | New record id (String) |
| `update` | `(id, attrs_hash)` | true / false |
| `destroy` | `(id)` | true / false |

Records are plain hashes with a symbol `:id` key. StreamWeaver validates the store at app startup (not at request time) and raises `ArgumentError` with a clear message listing missing methods.

---

## State Schema (`_sw_` Namespace)

The `_sw_` prefix is reserved. Do not use `state[:_sw_*]` keys in your own code.

| Key | Values | Meaning |
|---|---|---|
| `state[:_sw_action]` | `:index`, `:show`, `:new`, `:edit`, page name sym | Current action |
| `state[:_sw_resource]` | `:post`, `:goal`, etc. / `nil` | Active resource (nil for pages) |
| `state[:_sw_id]` | String id / nil | Selected record |
| `state[:_sw_action]` `:destroy_confirm` | — | Delete confirmation (routed via `GET /singular/:id/delete`) |
| `state[:"#{singular}_form"]` | Hash | Form state (managed by `form` DSL) |

Use `state[:_sw_resource]` and `state[:_sw_action]` in navbar `active:` checks:

```ruby
navbar do
  nav_item 'Posts', href: posts_path, active: state[:_sw_resource] == :post
  nav_item 'Home',  href: '/',        active: state[:_sw_action]   == :home
end
```

---

## Route Precedence

Routes are first-registered-wins. Recommended declaration order:

1. `page` / `route` (static exact-match routes)
2. `resource` blocks (collection then member patterns)
3. Manual `route_with` rules

```ruby
app 'Example' do
  page :home, '/'         # declared first — matched first

  resource :post, store: PostStore do  # declared after page
    field :title, :string
  end
end.run!
```

---

## Default View Behavior

When no override block is provided:

**Index** — renders a `header1` with the plural name, a "New" button, and a `table` with one column per field plus an actions column with View / Edit / Delete links per row. Delete links navigate to `/singular/:id/delete`.

**Show** — renders a `card` with `header3` (value of first field), one `text` line per field, and an hstack with Edit and Delete buttons. Delete navigates to `/singular/:id/delete`.

**Destroy confirm** — renders a warning `alert` prompting confirmation. "Confirm Delete" calls `store.destroy` and transitions to `:index`; "Cancel" returns to `:index`.

**New** — renders `header1 "New ..."` and a `form` block with inputs auto-generated from field types. Submit calls `store.create`, then transitions to `:show` for the new record.

**Edit** — renders `header1 "Edit ..."`, seeds form state from the record on first load (guarded by a seeded-for key to prevent reset on every re-render), same form inputs as new. Submit calls `store.update`, transitions to `:show`.

---

## Complete Example with Override

See `examples/scaffolding/blog.rb` for a zero-dependency smoke test (~50 lines).

See `examples/scaffolding/utf_lite.rb` for a multi-resource app with a custom index override and `edit_view :page`.
