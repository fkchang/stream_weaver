# Design Deck

`design_deck` navigation (moving between slides, `slide_container`/`slide`) is plain inlined JS (`sw-slide-nav.js`) — WORKS in every context, no server needed. Everything below is about the interactive part: option selection, notes, generate-more, model selection.

```ruby
design_deck "Design Options" do
  slide "arch", "Architecture" do
    option("Monolith") { text "Simple, one deploy unit" }
    option("Microservices") { text "Scales independently, more ops" }
  end
end
```

## What changed 2026-08-23 (disc-096)

**Before:** `swDeckSelect` applied the selected CSS class and `aria-checked` **before** calling `fetch('/deck/select')`, with no `.catch`. Every backend-less context — canvas, canvas-read, export — has no `/deck/*` route, so the fetch 404s (or fails outright) and the failure was swallowed. The user saw a confirmed selection that was never recorded and never reached anything. Not just dead — it actively lied about recorded state, `aria-checked` included.

**After:** confirmation is success-gated. Visual/aria state only changes after the POST resolves; a failed request surfaces a console error naming the route and reason, and applies no visual change. An `aria-busy` state covers the in-flight moment. Separately, the whole interactive surface (option cards, notes textarea, submit, generate-more, model selector) renders **read-only** wherever `/deck/*` genuinely doesn't exist — gated by a `deck_server:` construction flag the adapter carries, set correctly at every render site including canvas, canvas-read, export, and `streamweaver serve` (service mode never mounted `/deck/*` either — a second, previously-undocumented instance of the same bug, now covered too).

## Where it WORKS vs. where it's read-only

| Context | Deck interactivity |
|---|---|
| `streamweaver run` (real standalone server, `/deck/*` mounted) | WORKS — confirmation lands slightly after the click now (the fix), not before |
| Live canvas (A) | DEGRADES — honestly read-only, `/deck/*` doesn't exist here |
| canvas-read (B) | DEGRADES — same |
| Export (C) | DEGRADES — same |
| `streamweaver serve` (service mode) | DEGRADES — read-only, same previously-undocumented bug, now covered |

## The gotcha

If you're building a doc meant to demo option selection interactively, `design_deck` will render but every click will be inert (honestly, not silently) unless it's opened under a real `streamweaver run` server that mounts `/deck/*`. Don't put deck-selection interactivity in a doc you intend to Save-as-doc and reopen later, or export — it'll render fine and simply not accept input in either context. There's also a separate, still-open gap: the deck JS posts to `/deck/*` by absolute path, ignoring the adapter's `url_prefix` — so even a service-mode app that mounted deck routes under a prefix would post to the wrong place. That's why today's fix makes it read-only rather than pointing it at the prefixed route; url-prefixing the deck JS is a prerequisite for ever flipping `deck_server: true` under `streamweaver serve`.
