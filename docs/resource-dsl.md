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
  def self.update(id, attrs); (find(id) || return false).merge!(attrs); true; end
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
| `state[:_sw_confirm_delete]` | String id / nil | Record pending delete confirmation |
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

**Index** — renders a `header1` with the plural name, a "New" button, a `table` with one column per field plus an actions column (View / Edit / Delete buttons per row). If `state[:_sw_confirm_delete]` is set, a warning `alert` with Confirm / Cancel appears inline.

**Show** — renders a `card` with `header3` (value of first field), one `text` line per field, and an hstack with Edit and Delete buttons. Same inline confirm alert when pending delete.

**New** — renders `header1 "New ..."` and a `form` block with inputs auto-generated from field types. Submit calls `store.create`, then transitions to `:show` for the new record.

**Edit** — renders `header1 "Edit ..."`, seeds form state from the record on first load (guarded by a seeded-for key to prevent reset on every re-render), same form inputs as new. Submit calls `store.update`, transitions to `:show`.

---

## Complete Example with Override

See `examples/scaffolding/blog.rb` for a zero-dependency smoke test (~50 lines).

See `examples/scaffolding/utf_lite.rb` for a multi-resource app with a custom index override and `edit_view :page`.
