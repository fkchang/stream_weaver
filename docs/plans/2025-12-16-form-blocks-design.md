# Form Blocks with Deferred Submission

## Overview

Add a `form` block to StreamWeaver that groups multiple form elements together, uses client-side only state until submission, and sends all values in a single HTMX POST on submit.

## Problem

Currently, all form widgets trigger immediate HTMX requests on change, syncing state with the server on every keystroke/selection. This causes issues when:
1. Multiple fields need to be edited before saving
2. Navigation state gets reset during re-renders
3. Unnecessary server round-trips for uncommitted changes

## API

```ruby
form :edit_person do
  text_field :name, placeholder: 'Name'
  select :status, %w[active paused archived]
  text_area :notes, placeholder: 'Notes...', rows: 3

  submit 'Save' do |form_values|
    # form_values = { name: "...", status: "...", notes: "..." }
    # state[:edit_person] already updated at this point
    api.save_person(form_values)  # optional side effects
  end

  cancel 'Cancel'  # resets to original values, no server request
end
```

## Design Decisions

### State Namespace: Nested Hash
Form values stored as `state[:edit_person][:name]` - nested hash structure matching Rails conventions (strong params, form_for).

### Initial Values: From State
Form reads initial values from `state[:form_name]`. App code is responsible for populating state before rendering (like Rails controller setting `@person = Person.find(id)`).

### Submit Behavior: Auto-Update State
On submit, state is automatically updated with form values, then the submit block runs. This keeps UI consistent - other components using `state[:edit_person][:name]` show current values.

### Context Flag for Widgets
Same DSL methods (`text_field`, `select`, etc.) work inside and outside forms. A context flag tells the adapter to render differently (no HTMX, form-scoped x-model).

## Client-Side Behavior

Form block wraps contents in Alpine.js scope with local state:

```html
<div x-data="{
  _form: { name: 'Alice', status: 'active', notes: '' },
  _original: { name: 'Alice', status: 'active', notes: '' }
}">
  <input type="text" x-model="_form.name" name="edit_person[name]">
  <select x-model="_form.status" name="edit_person[status]">...</select>

  <button hx-post="/form/edit_person" hx-include="[name^='edit_person']">Save</button>
  <button type="button" @click="_form = JSON.parse(JSON.stringify(_original))">Cancel</button>
</div>
```

### Widget Rendering Differences

| Aspect | Standalone widget | Widget inside form |
|--------|-------------------|-------------------|
| `x-model` | `x-model="name"` (root scope) | `x-model="_form.name"` (form-local) |
| `hx-post` | On every change (`/update`) | None |
| `hx-trigger` | `keyup changed delay:500ms` | None |
| `name` attr | `name="name"` | `name="form_name[field]"` (Rails nested) |

### Cancel Button
Pure Alpine - resets `_form` to `_original` snapshot, no server request.

### Submit Button
Single HTMX POST to `/form/:form_name` with all form values.

## Server-Side Handling

New endpoint `POST /form/:form_name`:

1. Parse Rails-style nested params: `edit_person[name]` -> `{ name: "..." }`
2. Auto-update state: `state[:edit_person] = form_values`
3. Execute submit block if defined
4. Re-render page with updated state

## Implementation Files

| File | Changes |
|------|---------|
| `lib/stream_weaver/components.rb` | Add `Form` component class |
| `lib/stream_weaver/app.rb` | Add `form`, `submit`, `cancel` DSL methods; add `@form_context` flag |
| `lib/stream_weaver/adapter/alpinejs.rb` | Add `render_form`, modify widget renderers to check form context |
| `lib/stream_weaver/server.rb` | Add `POST /form/:form_name` endpoint |
| `docs/for_llms.md` | Document form block usage and auto-update behavior |

## Form Component Structure

```ruby
class Form < Base
  attr_reader :name, :submit_label, :cancel_label, :submit_action
  attr_accessor :children

  def initialize(name, **options)
    @name = name
    @children = []
    @submit_label = nil
    @cancel_label = nil
    @submit_action = nil
  end

  def execute_submit(state, form_values)
    @submit_action&.call(form_values)
  end
end
```

## Documentation Notes

For `docs/for_llms.md`, emphasize:
- Form values auto-update to state on submit (state[:form_name] = form_values)
- Submit block is for side effects (API calls), not state management
- Cancel resets to original values without server request
- Same DSL methods work inside/outside forms - context determines behavior
