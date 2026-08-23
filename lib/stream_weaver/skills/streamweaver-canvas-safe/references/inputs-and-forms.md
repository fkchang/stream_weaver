# Inputs and Forms

Every plain input (`text_field`, `text_area`, `date_field`, `checkbox`, `select`) auto-submits via a debounced `hx-post /update` on every keystroke or change. That request 404s on every backend-less context (A, B, C) — it needs `streamweaver run`/`serve` with the update route mounted. This is disc-106, tracked and deliberately out of scope; know it going in rather than chase a phantom 404 in the console.

The good news: on the live canvas (A), the value still reaches an agent — just not through the field's own auto-submit. `getFormState()` walks the DOM for every `[x-model]` element at the moment some *other* `sendEvent`-carrying control fires (a `button`, `clickable`, a form submit). So a `text_field` sitting next to a `button` works as a value carrier even though its own round-trip never completes.

```ruby
text_field :city, placeholder: "City"
button "Submit" do |state|
  # state[:city] is populated from getFormState() on the live canvas
end
```

If you don't want the debounced 404 noise on canvas, pass `submit: false` — the field becomes an inert value carrier with no auto-submit at all (DEGRADES honestly instead of failing silently):

```ruby
text_field :city, submit: false
```

## checkbox_group — array harvest, not auto-submit

```ruby
checkbox_group :selected_items, select_all: "Select All", select_none: "Clear" do
  items.each { |item| item(item.id) { text item.name } }
end
# button click elsewhere harvests state[:selected_items] = ["id1", "id3"]
```

**Fixed 2026-08-23 (disc-098):** the harvest used to collapse every group to the *last* checked item's boolean — confidently wrong data, worse than dead. It's fixed now: items inside a `.checkbox-group` accumulate into an array; a lone `checkbox` outside a group still returns a boolean. `checkbox_group` itself was never ported to `sendEvent` — its auto-submit still 404s everywhere backend-less, same as the plain inputs above. The array only leaves the page when another control's click harvests it.

## chip_group — multi-select, sendEvent-ported

```ruby
chip_group :langs, %w[ruby js python]              # multi: true by default
chip_group :lang, %w[ruby js python], multi: false  # single-select
```

Ported to `sendEvent('change')` on the live canvas (disc-097) — dispatches `{field: :langs, value: [...], state: getFormState()}` on every click, array-harvest-correct. See `references/actions-and-buttons.md` for the sendEvent-only-on-live-canvas rundown; canvas-read renders it honestly `aria-disabled`, export falls back to a dead `hx-post`.

## tag_buttons — sendEvent-ported

```ruby
tag_buttons :category, ["Fiction", "Non-fiction", "Mystery"]
```

Same disposition as `chip_group`: `sendEvent('change')` on the live canvas, honest `aria-disabled` on canvas-read, dead `hx-post` in export.

## form blocks

```ruby
form :edit_person do
  text_field :name, placeholder: "Name"
  select :status, %w[active paused archived]
  submit "Save" do |form_values|
    # form_values = { name: "...", status: "..." }
  end
  cancel "Cancel"
end
```

`submit` dispatches through `sendEvent('action')` on the live canvas (disc-097 — `form` was the one auto-submit-based component that got fully ported, not just harvest-fixed). `cancel` is Alpine-only client-side reset, so it works in all three contexts.

## The gotcha

Checking a box or typing into a field, by itself, sends **nothing** anywhere. Only a `sendEvent`-carrying control's click harvests the current DOM state. If your doc's only interactive elements are plain inputs with no `button`/`clickable`/`form submit` alongside them, nothing an agent waits on will ever fire — the fields will look interactive (you can type, you can check boxes) and simply never report anywhere. Always pair inputs with at least one dispatching control.
