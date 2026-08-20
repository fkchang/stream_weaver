# StreamWeaver Form Patterns

Canonical patterns for form/input/selection UIs. Use this to pick the right component for your use case.

## Pattern Reference

| Pattern | Use Case | Component | Example |
|---|---|---|---|
| Instant feedback | Filters, toggles | Default inputs (auto-submit) | `select :filter, options` |
| Multi-select then act | Batch operations | `checkbox_group` or `submit: false` + button | Check items then "Delete Selected" |
| Traditional form | Edit/create with Save/Cancel | `form` block | `form :edit_person do...end` |
| Single selection for later action | Pick category then add item | `select` with `submit: false` | `select :cat, names, submit: false` |
| Scrollable list | Long item lists | `scroll_box` | `scroll_box(max_height: "400px") do...end` |

## Examples

### Instant Feedback (default)
```ruby
# Every change triggers a server round-trip and re-render
select :filter, ["All", "Active", "Done"]
text_field :search, placeholder: "Search..."
```

### Single Selection for Later Action
```ruby
# User picks a category, then clicks Add — no round-trip on select change
cat_names = categories.map { |c| c["name"] }
select :category, cat_names, default: cat_names.first, submit: false

button "Add Item", style: :primary do |s|
  chosen = s[:category]  # string name, not an index
  # ... use chosen
end
```

### Multi-Select Then Act
```ruby
checkbox_group :selected_items do
  items.each { |item| item item.id do text item.name end }
end

button "Delete Selected" do |s|
  ids = s[:selected_items]  # array of checked values
  # ... delete them
end
```

### Traditional Form
```ruby
form :edit_person do
  text_field :name, placeholder: "Name"
  text_field :email, placeholder: "Email"
  submit "Save" do |s|
    data = s[:edit_person]  # { name: "...", email: "..." }
    # ... save
  end
  cancel "Cancel"
end
```

### Scrollable List
```ruby
scroll_box(max_height: "400px") do
  items.each do |item|
    hstack spacing: :xs, align: :center do
      text item.name
      button "Edit", id: "edit_#{item.id}" do |s|
        # ...
      end
    end
  end
end
```

## Anti-Patterns

### 1. Button-as-Radio
**Wrong** — Using buttons + state to simulate selection:
```ruby
# DON'T DO THIS
hstack do
  categories.each_with_index do |cat, i|
    button cat, style: state[:cat] == i ? :primary : :secondary do |s|
      s[:cat] = i
    end
  end
end
```

**Right** — Use `select` or `radio_group`:
```ruby
select :cat, category_names, submit: false
```

### 2. Integer State Keys
**Wrong** — Storing array indices in session state:
```ruby
s[:cat] = i  # breaks if list order changes
```

**Right** — Store the string name, resolve to index at action time:
```ruby
s[:cat_name] = cat["name"]
# later:
idx = categories.index { |c| c["name"] == s[:cat_name] } || 0
```

### 3. Forgetting `submit: false`
**Wrong** — Inputs inside button-action workflows auto-submit by default:
```ruby
text_field :label  # triggers round-trip on every keystroke!
button "Add" do |s| ... end
```

**Right**:
```ruby
text_field :label, submit: false
button "Add" do |s| ... end
```

### 4. Session Cookie Overflow
Large text values in state overflow the 4KB cookie limit.
**Fix**: Use `transient: true` to exclude from the session cookie:
```ruby
text_area :paste_area, transient: true
```

### 5. Stale Session After Restart
Static dev secret preserves cookies across restarts. If your state schema changed, old cookies cause errors.
**Fix**: Store state as recoverable strings (not fragile indices). Use `--reset` flag or clear cookies after schema changes.

### 6. Transient Fields Never Resync From the Server
`transient: true` is documented above (#4) as "exclude from the session cookie" — but the
Alpine adapter's morph-merge goes further than that: it also skips writing the server's value
back into the browser's reactive store on *every* subsequent update, not just full-cookie
snapshots (`adapter/alpinejs.rb`, the `htmx:beforeSwap` handler — `if (transientKeys.has(k))
return;`). In practice this means once a transient field's DOM node exists, only the user's own
typing ever changes what it shows — a server-side `s[:x] = ""` after a button handler, or a
fresh prefill for a *different* record reusing the same state key, is silently dropped.

**Wrong** — clearing a transient field after its own submit handler:
```ruby
text_field :custom_item, submit: false, transient: true
button "Add" do |s|
  add_item(s[:custom_item])
  s[:custom_item] = ""   # never reaches the browser — field still shows the old value
end
```

**Wrong** — reusing one transient key across multiple records' edit forms (e.g. a schema-driven
edit UI where every row's Time/Date field binds to the same `:edit_time`/`:edit_date` key
instead of a per-row key): opening row B's edit form after row A's still shows row A's value,
because the fresh prefill for row B never overwrites what's already sitting in the browser.

**Fix**: if a field's value must ever be authoritatively reset by the server (a post-submit
clear, a fresh prefill on reopen), don't mark it `transient: true` unless it's genuinely a
one-shot, never-cleared, never-reused input (the large-paste-area case #4 was written for).
Short single-value fields rarely have a real cookie-size reason to be transient — dropping the
flag is usually simpler than working around the resync gap. If cookie size is the actual
concern *and* the field needs server-driven resets, the two needs are currently in tension —
there's no flag that gives "excluded from cookie" without also losing resync.

Found via `~/work/cultiv-ai/apps/health_dashboard/app.rb`, 2026-08-20 — a custom-item field
that never visually cleared after Add, and an entry-edit form's Time/Date fields that leaked
one edit's value into the next.
