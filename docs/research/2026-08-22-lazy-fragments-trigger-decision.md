# Lazy fragments: which htmx trigger, and what `lazy:` means on its own

Decision note for the `visibility-lazy-fragments` story (epic `streamweaver-way`).
Companion to `2026-08-17-hotwire-concept-map.md`, which named deferred/lazy
fragments as the open gap against Turbo Frames.

`fragment(:name, defer: true, lazy: true)` is StreamWeaver's `loading="lazy"`.
Turbo's rule for that attribute is precise and worth restating, because two of
the three obvious implementations get it wrong: the frame loads **when it becomes
visible** — not when it is scrolled near, not when it is hovered, but when it is
actually visible. A frame inside a `display: none` container never loads. Flip
that container to `display: block` with no scrolling at all and it loads.

## Decision 1 — `hx-trigger="intersect once"`, not `revealed`

htmx offers two candidate triggers. They are not variations on a theme; they are
built on different primitives and only one of them matches Turbo.

Read from htmx 2.0.4 (`https://unpkg.com/htmx.org@2.0.4/dist/htmx.js`), which is
the exact build `Adapter::AlpineJS#render_cdn_scripts` loads:

**`revealed` is scroll-polled geometry.** `addTriggerHandler` (js:2662) calls
`initScrollHandler()`, which installs `scroll`/`resize` listeners that set a flag,
plus a 200ms `setInterval` that re-checks every `[hx-trigger*='revealed']`
element via `maybeReveal` → `isScrolledIntoView` (js:750):

```js
function isScrolledIntoView(el) {
  const rect = el.getBoundingClientRect()
  return rect.top < window.innerHeight && rect.bottom >= 0
}
```

A `display: none` element has no layout box, so `getBoundingClientRect()` returns
an all-zero rect — and `0 < window.innerHeight && 0 >= 0` is **true**. `revealed`
therefore considers every hidden element revealed and fetches it immediately, on
the first `maybeReveal` call at process time. That is a direct contradiction of
criterion 4 ("a fragment hidden via CSS never triggers a fetch"), and it takes
the zero-JS hover-card pattern with it: the card would load on page render for
every host on the page, which is the whole cost the pattern exists to avoid.
The 200ms polling is a second, smaller mismatch — a hover that flips `display`
without scrolling never sets the `windowIsScrolling` flag, so nothing re-checks.

**`intersect` is an IntersectionObserver.** Same function, js:2666:

```js
const observer = new IntersectionObserver(function(entries) {
  for (let i = 0; i < entries.length; i++) {
    if (entries[i].isIntersecting) { triggerEvent(elt, 'intersect'); break }
  }
}, observerOptions)
observer.observe(asElement(elt))
```

IntersectionObserver reports no intersection for a target with no layout box, and
delivers a callback on *any* transition into intersection regardless of cause —
scrolling, an ancestor's `display` flip, a CSS `:hover` rule, an Alpine `x-show`.
That is Turbo's rule, expressed in the same browser API Turbo itself uses.

**Chosen: `hx-trigger="intersect once"`.** Locked by
`spec/lazy_fragments_spec.rb` ("waits for intersection instead of firing on
load"), which also asserts the page contains no `hx-trigger="load"` — the shell
must ship with no way to fetch a lazy fragment except a visibility event.

### Why `once` is load-bearing

The observer keeps observing after it fires. Without `once`, scrolling a
materialized fragment out of the viewport and back would fire `intersect` again
and refetch — exactly what criterion 3 forbids. htmx's `once` latch (js:2506) is
stored per element:

```js
if (triggerSpec.once) {
  if (elementData.triggeredOnce) { return } else { elementData.triggeredOnce = true }
}
```

`elementData` comes from `getInternalData(elt)`, i.e. it is keyed to the DOM node,
not to the id or the URL. That per-element scope is what makes the next decision
work.

## Decision 2 — composition with the full-container re-arm

`deferred-fragments-src` established that an interaction swapping the whole app
container re-renders a deferred fragment back to its placeholder and re-fetches.
The mechanism is the wrapper element: the fetch attributes ride an inner
`<div id="<frag-id>--deferred">` rather than the fragment container, so the morph
sees materialized content where the new markup has a wrapper, matches neither by
id nor positionally, and builds a **fresh element**.

A lazy fragment composes with that for free, and correctly:

- Fresh element ⇒ fresh `getInternalData` ⇒ `triggeredOnce` is unset ⇒ the
  fragment re-arms rather than staying stuck on its placeholder.
- Re-armed on `intersect`, not `load` ⇒ it re-arms **lazily**. If the fragment is
  off-screen or CSS-hidden when the re-render lands, it waits, exactly as it did
  on first paint. A plain deferred fragment would have refetched immediately.

Locked by "re-arms as a lazy wrapper after a full-container update" and "gives
the lazy wrapper its own id so the morph replaces rather than reuses it".

## Decision 3 — `lazy: true` implies `defer: true`

`fragment(:card, lazy: true)` is legal and means `defer: true, lazy: true`.
Ruling: **imply, do not raise.**

The case for raising was consistency with the adjacent guard — `placeholder:`
without `defer:` raises `ArgumentError`. But those two options are not alike.
A placeholder with nothing to place-hold has *no* meaning; the author who wrote it
has a mistaken model of the API and needs to hear about it. `lazy:` has exactly
one possible meaning, and it is unambiguous: hold the fetch until visible. There
is no second reading for an error message to disambiguate, so raising would spend
an author's round-trip to make them type a word the DSL could have supplied.
That is friction with nothing on the other side of it (Forrest's Law).

It also matches Turbo, where `loading="lazy"` is only meaningful on a frame that
loads from `src` — the attribute presupposes the deferred load rather than
combining with it. And the DSL already implies options elsewhere: `area_chart` is
`line_chart` with `fill: true`, `doughnut_chart` is `pie_chart` with
`doughnut: true`.

Implementation is one line at the top of `App#fragment` (`defer ||= lazy`), placed
*before* the placeholder guard so `fragment(:card, lazy: true, placeholder: '…')`
is accepted while `fragment(:card, placeholder: '…')` still raises. All three
behaviours are specced.

## Design note — lazy route tabs

Required by criterion 5. **Design only; no tabs code was changed by this story.**

`tabs key, lazy: true` (the POST-morph mode) is deprecated. `App#warn_lazy_tabs_deprecated`
already names its successor in the warning text: "lazy route tabs will replace
this mode". This is the primitive that lets that happen.

### The shape

Route tabs (`tabs :view, url: true`) render every panel into the DOM as a
`<div class="sw-tab-panel" x-show="activeTab === N" x-cloak>`. Two independent
mechanisms make an inactive panel `display: none`: `[x-cloak] { display: none !important; }`
(adapter/alpinejs.rb:6738) before Alpine boots, and `x-show`'s own inline
`display: none` afterwards. So an inactive route-tab panel is already, today,
precisely the CSS-hidden container that a lazy fragment refuses to fetch inside.

Adoption is therefore a **DSL pattern, not a renderer feature**:

```ruby
tabs :view, url: true do
  tab 'Summary' do
    text summary_line          # cheap, always rendered
  end

  tab 'Revenue' do
    fragment :revenue, lazy: true, placeholder: -> { skeleton_rows(8) } do
      revenue_table            # 1.5s of work; runs the first time this tab is shown
    end
  end
end
```

What happens: the shell ships with all three panels present and the Revenue panel
hidden, so its block never runs. Clicking the Revenue trigger runs Alpine's
`activeTab = 1` and `swRouteTabs.push(:view, 1)` — client-side only, no server
round-trip, the URL updates. `x-show` flips the panel to visible; the
IntersectionObserver on the lazy wrapper fires; one scoped fetch materializes just
that fragment. Switching back and forward again refetches nothing (`once`, plus
the wrapper is gone). Back/forward across the tab is client-side too: `@popstate`
re-reads the index and re-shows an already-materialized panel.

### Why this beats the deprecated mode

- **The deprecated mode fetches the whole app container.** Its trigger button
  carries `hx-target="#app-container"` with `hx-vals` writing the new index into
  session state. Lazy route tabs fetch one fragment at its own signed endpoint,
  send no state patch, and leave the tab index where route tabs put it (the URL).
- **The deprecated mode is dead on a canvas page** because a canvas has no route
  for its POST-morph (`stream_weaver-pkh`, quoted at app.rb:1014). Lazy route tabs
  inherit the deferred-fragment fetch path, so they degrade the same way every
  other deferred fragment does — see the caveat below. That is not yet *working*
  on canvas, but it is one shared gap instead of a second bespoke one.
- **Panel cost becomes per-panel and opt-in.** `lazy: true` on the tabs group was
  all-or-nothing and skipped evaluation for every inactive tab, which forced the
  two-pass re-render at app.rb:926 when a clamped index changed after the block
  had run. A lazy fragment inside one tab costs nothing to the tabs machinery: the
  panel still renders, its cheap content still evaluates, and only the fragment's
  block is held back.

### Constraint: keep the fragment inside `tab`, never beside it

`disc-085`: the index-clamp range bound, `tab`'s positional index, and
`render_tabs`' `children.each_with_index` all count **all** children of the tabs
block, not just `Tab` components. A non-tab child at the top level of a `tabs`
block shifts every panel index after it and lets an in-range-but-wrong index dodge
the clamp.

This design does not touch that, and must not start:

```ruby
tabs :view, url: true do
  fragment(:sidebar, lazy: true) { … }   # WRONG — becomes child 0, shifts every panel
  tab('Summary') { … }
end
```

The pattern above puts the fragment **inside** a `tab` block, where it is a child
of the `Tab` component and invisible to all three counting sites. Whoever
implements lazy route tabs should carry this as an explicit non-goal: adopting the
primitive requires no change to `render_tabs`, so it must not become the occasion
to open the mixed-children counting question. Fixing `disc-085` remains its own
story, and doing it first would not block this one.

### Open question for the implementer

Whether `lazy route tabs` should also become sugar — e.g. `tab 'Revenue', lazy: true`
wrapping the block in a lazy fragment automatically — or stay the explicit
two-verb composition above. The explicit form is what this story enables and is
already zero-JS; sugar would need to answer where the fragment name comes from
(the label? the index? — an index-derived name reintroduces exactly the
positional coupling `disc-085` is about) and whether a placeholder can be
declared per tab. Recommend shipping the composition, using it in `my-todos`, and
only then deciding whether the sugar earns a name.

## Caveats and known limitations

- **Canvas.** `Fragment#render_deferred` posts to `url('/update')` with no
  `websocket_mode?` guard, so a deferred *or* lazy fragment on a live canvas page
  posts to a route the bridge does not serve. Inherited from
  `deferred-fragments-src`, unchanged here; it is an instance of `disc-097` (only
  4 of 21 `htmx_attrs` call sites consult `websocket_mode?`) and belongs to
  `disc-093`'s backend-less-context matrix.
- **Named actions inside the fragment.** `disc-100` applies unchanged: a
  `button 'X', action: :foo` minted during a fragment fetch is dead on arrival.
  Use a block button.
- **Static export.** A lazy fragment's block runs inline in an export, like a
  deferred one — nothing will ever scroll an exported file. Specced.
- **Placeholder height.** The wrapper is what the observer watches, so a
  placeholder should occupy space. The default spinner does; a placeholder that
  renders nothing gives the observer a zero-area target.

## What the browser pass must still settle

Everything above about the *server* is specced (`spec/lazy_fragments_spec.rb`, 20
examples). Everything about *visibility* is a browser claim and is deliberately
not asserted in MRI: that IntersectionObserver stays silent for a `display: none`
target, that a CSS `:hover` reveal fires it, that exactly one network request
results, and that re-hiding and re-showing produces none. The runbook for those
checks is in the story's handoff note.
