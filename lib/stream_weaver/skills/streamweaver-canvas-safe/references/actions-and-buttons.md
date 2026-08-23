# Actions and Buttons

Seven components dispatch through `window.sendEvent`, which only the live bridge's `cdn_scripts` defines (context A). All seven share the same three-context shape: **WORKS on the live canvas, DEGRADES-honest on canvas-read, SILENTLY-DEAD in an export.** There is no way to make click-driven interactivity survive an export — a static file has nothing to dispatch to. Design around that instead: use these for the live-canvas conversation loop, and lean on the plays-well-everywhere list (SKILL.md) for anything that has to survive being saved and reopened.

## button

```ruby
button "Submit" do |state|
  # runs when clicked, on the live canvas, with an agent listening on canvas-wait
end

button "Preview only", submit: false  # decorative — WORKS in all three contexts, never dispatches
```

Default `button` dispatches `sendEvent('action', {button: <token>, state: getFormState()})`. With no `canvas-wait` holder listening, the click still fires `showFeedback()` and replaces the container with "✓ Submitted" — the page is gone even though nothing consumed the event, so always have something waiting before you tell a user to click.

## clickable(action:)

```ruby
clickable(action: :open_row, key: "r1") { text "Row" }
```

Ported to `sendEvent('action')` (disc-097) — same payload shape as `button`. Can't be natively `disabled` (it's a `<div>`), so on canvas-read it drops `aria-disabled` + no `tabindex` instead of `disabled` — a focusable element that does nothing would be its own lie.

## menu_item (action block)

```ruby
dropdown do
  menu do
    menu_item("Archive") { |state| state[:archived] = true }
  end
end
```

Dispatches `sendEvent('action', {button: 'menu_item_N', ...})`; the menu still closes on dispatch, live canvas only.

## Waiting on the right event

`canvas-wait`'s default only catches `action` events (`button`, `clickable`, `menu_item`, `form` submit). `tag_buttons` and `chip_group` dispatch `change` instead — mirroring `radio_group` since they're a state change, not a submission. Pass `--event change` or `--any` if your doc's only dispatching control is one of those two, or the wait will hang forever on an event that's never coming.

## Quoting

Author-supplied strings reaching a JS handler (tag labels, menu item text) route through JSON quoting — an apostrophe in a label won't produce a JS syntax error. The one exception is `external_link_button`'s `window.open(url)` call, which is emitted identically in HTTP and canvas mode by design (quoting it would change HTTP-mode output); an unquoted URL there is a known, tracked edge case (disc-107), not something this skill's examples exercise.

## The gotcha

None of these components render any different markup between "will dispatch to an agent" and "will replace the page with a submitted-state placeholder because nobody's listening." Before telling a user to click a button, make sure a `canvas-wait` (with the right `--event`) is actually running — otherwise the click looks like it worked and just wasn't heard.
