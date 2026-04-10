# StreamWeaver CRUD Patterns

StreamWeaver handles CRUD differently from Rails. Because button callbacks are plain Ruby, data mutation happens directly — no controller layer, no POST-redirect-GET cycle. The URL routing layer handles deep-linking to edit views.

## The Core Insight

A StreamWeaver button callback IS a POST handler:

```ruby
button "Save" do |s|
  initiative = load_initiative(s[:editing_id])
  initiative[:title] = s[:edit_title]
  initiative[:status] = s[:edit_status]
  save_initiative(initiative)
  s[:editing_initiative] = false   # exit edit mode
  s[:flash] = "Saved!"
end
```

No controller. No form action. No redirect. Just Ruby.

---

## Read (Index + Show)

Standard StreamWeaver patterns — load from YAML/store, render in app block:

```ruby
# Index: list all initiatives
initiatives = load_initiatives
table initiatives do
  column :title
  column :status
  column(:id) { |i| button("View") { |s| s[:initiative_id] = i[:id] } }
end

# Show: render detail when initiative_id is set
if state[:initiative_id]
  init = load_initiative(state[:initiative_id])
  card do
    header3 init[:title]
    text "Status: #{init[:status]}"
    button "Edit" do |s|
      s[:editing_initiative] = true
    end
  end
end
```

---

## Create

Use a modal or inline form. State holds the draft fields; the save button commits to the store.

```ruby
button "New Initiative", style: :primary do |s|
  s[:creating_initiative] = true
  s[:new_init_title] = ""
  s[:new_init_status] = "active"
end

modal :new_initiative, title: "New Initiative" do
  text_field :new_init_title, placeholder: "Title", submit: false
  select :new_init_status, %w[active paused completed], submit: false

  modal_footer do
    button "Create", style: :primary do |s|
      id = create_initiative(title: s[:new_init_title], status: s[:new_init_status])
      s[:creating_initiative] = false
      s[:initiative_id] = id   # navigate to new record
      s[:flash] = "Initiative created"
    end
    button "Cancel" do |s|
      s[:creating_initiative] = false
    end
  end
end
```

The `modal :new_initiative` opens when `state[:new_initiative_open]` is true (StreamWeaver convention: `modal :key` → controlled by `state[:key_open]`).

---

## Update (Edit Form)

### Option A: Modal Edit (no URL change)

Good for quick edits on a list view. State holds the record being edited.

```ruby
initiatives.each do |init|
  hstack do
    text init[:title]
    button "Edit" do |s|
      s[:editing_id] = init[:id]
      # load current values into edit fields
      s[:edit_title]  = init[:title]
      s[:edit_status] = init[:status]
    end
  end
end

if state[:editing_id]
  modal :edit_initiative, title: "Edit Initiative" do
    text_field :edit_title, placeholder: "Title", submit: false
    select :edit_status, %w[active paused completed], submit: false

    modal_footer do
      button "Save", style: :primary do |s|
        update_initiative(s[:editing_id], title: s[:edit_title], status: s[:edit_status])
        s[:editing_id] = nil
        s[:flash] = "Saved"
      end
      button "Cancel" do |s|
        s[:editing_id] = nil
      end
    end
  end
end
```

### Option B: URL-Addressable Edit Page

Pairs with `route_with` routing (see `routing.md`). Visiting `/initiative/init-001/edit` seeds `state[:editing_initiative] = true`.

```ruby
# route_with parser handles: /initiative/:id/edit → { initiative_id: id, editing_initiative: true }
# route_with builder handles: editing_initiative? → /initiative/:id/edit

if state[:editing_initiative] && state[:initiative_id]
  init = load_initiative(state[:initiative_id])

  # Seed edit fields on first load
  if state[:edit_seeded_for] != state[:initiative_id]
    state[:edit_title]     = init[:title]
    state[:edit_status]    = init[:status]
    state[:edit_seeded_for] = state[:initiative_id]
  end

  card do
    header3 "Edit: #{init[:title]}"

    text_field :edit_title, label: "Title", submit: false
    select :edit_status, %w[active paused completed], submit: false

    hstack do
      button "Save", style: :primary do |s|
        update_initiative(s[:initiative_id], title: s[:edit_title], status: s[:edit_status])
        s[:editing_initiative] = false   # URL drops back to /initiative/:id
        s[:flash] = "Saved"
      end
      button "Cancel", style: :secondary do |s|
        s[:editing_initiative] = false
      end
    end
  end
end
```

**Field seeding pattern**: The `edit_seeded_for` guard ensures edit fields are seeded from the record once per initiative, not overwritten on every re-render. Without it, every button click would reset the form to the stored value.

---

## Delete

```ruby
button "Delete", style: :danger do |s|
  s[:confirm_delete_id] = init[:id]
end

if state[:confirm_delete_id]
  alert(variant: :warning) do
    text "Delete this initiative? This cannot be undone."
    hstack do
      button "Confirm Delete", style: :danger do |s|
        delete_initiative(s[:confirm_delete_id])
        s[:confirm_delete_id] = nil
        s[:initiative_id] = nil   # navigate away
        s[:flash] = "Deleted"
      end
      button "Cancel" do |s|
        s[:confirm_delete_id] = nil
      end
    end
  end
end
```

---

## Flash Messages

StreamWeaver has no built-in flash. Use `state[:flash]` with a conditional render:

```ruby
if state[:flash]
  alert(variant: :success) { text state[:flash] }
  # Auto-clear: set flash to nil after it's rendered once
  # Use a counter trick or a dedicated clear button
end
```

For auto-dismiss, use a toast:

```ruby
# In button callback:
s[:toasts] ||= []
s[:toasts] << { id: SecureRandom.hex(4), message: "Saved!", type: :success, duration: 3000 }

# In render:
toast_container  # renders toasts from state[:toasts]
```

---

## Store Adapter Pattern

Keep data access decoupled from the UI. Centralizing it makes the CRUD callbacks readable:

```ruby
module InitiativeStore
  YAML_PATH = File.expand_path("~/cultiv-os/cabinet/initiatives/master-initiatives.yaml")

  def self.all
    YAML.safe_load_file(YAML_PATH, symbolize_names: true)[:initiatives] || []
  end

  def self.find(id)
    all.find { |i| i[:id] == id }
  end

  def self.update(id, attrs)
    data = YAML.safe_load_file(YAML_PATH)
    idx  = data["initiatives"].index { |i| i["id"] == id }
    return false unless idx
    data["initiatives"][idx].merge!(attrs.transform_keys(&:to_s))
    File.write(YAML_PATH, data.to_yaml)
    true
  end
end

# In app:
button "Save" do |s|
  InitiativeStore.update(s[:initiative_id], title: s[:edit_title], status: s[:edit_status])
  s[:editing_initiative] = false
end
```

---

See [docs/resource-dsl.md](resource-dsl.md) for the implemented `resource` DSL.

---

## Decision Guide

| Interaction | Pattern |
|---|---|
| Read-only list | `table` + state filter |
| Quick edit (no URL change) | Modal edit + `state[:editing_id]` |
| Deep-linkable edit form | `route_with` + URL-addressable edit page |
| Inline edit (click cell) | Not yet supported — use modal |
| Bulk update | `checkbox_group` + bulk action button |
| Delete with confirmation | Confirm state flag + conditional alert |
