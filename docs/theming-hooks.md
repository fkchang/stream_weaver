# Theming hooks

StreamWeaver's structural components emit a stable, `sw-` prefixed class on
every element you'd want to skin. The contract:

- **`sw-` prefixed classes are a stable public API.** They will not be
  renamed or removed without a deprecation cycle. Write your CSS against
  them.
- **Any other class (internal names, Alpine `x-` attributes, `data-sw-*`
  attributes) is an implementation detail.** It can change between
  releases without notice. Don't select on it in production CSS.
- **`class:`/`style:` on any structural component appends to the element,
  it never replaces the framework's own classes.** Your class always
  lands after the framework's, so at equal specificity your rule wins on
  document order too -- and since stream_weaver-oeo, every framework rule
  also lives in `@layer stream-weaver`, so your unlayered CSS wins
  regardless of specificity or order. One stylesheet targeting these
  hooks is enough to fully re-skin an app; you never need to fight the
  framework's own styles.
- **A few components still emit a second, unprefixed legacy class**
  (`card`, `card-header`, `card-body`, `card-footer`, `status-badge` and
  its `status-badge-*` siblings, and the `.sidebar-section` utility class)
  **alongside** the `sw-` hook, for backward compatibility. These generic
  names are exactly what stream_weaver-lyb was filed over -- they can
  collide with an app's own class names by coincidence (a real app's
  `.card` or `.status-badge` is a completely reasonable thing to
  independently invent). They're deprecated and will be removed at 1.0;
  new code should target the `sw-` hook only.

## Component -> hooks -> minimal CSS

### Board / Lane / BoardCard

| Element | Hook |
|---|---|
| Board container | `.sw-board` |
| Board with pinned lane headers | `.sw-board--pinned-headers` |
| Lane container | `.sw-board__lane` |
| Lane header band | `.sw-board__lane-header`, `.sw-board__lane-header--{tone}` |
| Lane heading wrapper | `.sw-board__lane-heading` |
| Lane title | `.sw-board__lane-title` |
| Lane subtitle | `.sw-board__lane-subtitle` |
| Lane card count | `.sw-board__lane-count` |
| Lane body (card stack) | `.sw-board__lane-body` |
| Lane icon (before the title) | `.sw-board__lane-icon` |
| Board card | `.sw-board__card`, `.sw-board__card--{tone}` |

```css
.sw-board { gap: 1.5rem; }
.sw-board__lane-header--success { background: #16a34a; }
.sw-board__card { border-radius: 12px; backdrop-filter: blur(4px); }
```

`tone:` on `lane`/`board_card` is one of `%i[neutral success warning error info]`.
`board`, `lane`, and `board_card` all accept `class:`/`style:`.
`board(pinned_headers: true)` adds `.sw-board--pinned-headers` and
`data-sw-pinned-headers="true"`; its lane header bands remain sticky while the
board scrolls vertically.

`lane` accepts `icon:` (stream_weaver-oeo) -- an emoji/glyph string, or a
URL/path (an `App#local_asset` result, `/sw-asset/...`, or any http(s)/data
URI), rendered before the title. A value is treated as an image when it
starts with `http://`, `https://`, `/`, or `data:`; anything else renders
as plain text/emoji. Replaces the `title_prefix` string-concatenation
workaround (design-parity-fights.md) that both tyrion parity slices used.

### Sidebar

| Element | Hook |
|---|---|
| Sidebar container | `.sw-sidebar`, `.sw-sidebar-sticky` (when `sticky: true`) |
| Header wrapper | `.sw-sidebar-header` |
| Header title | `.sw-sidebar-title` |
| Content wrapper | `.sw-sidebar-content` |

```css
.sw-sidebar { width: 260px; background: #1a1714; }
.sw-sidebar-title { font-family: 'Cinzel', serif; }
```

`sidebar` accepts `class:`/`style:`.

### Navbar / NavItem

| Element | Hook |
|---|---|
| Navbar container | `.sw-navbar` |
| Nav item | `.sw-navbar-item` |
| Active nav item | `.sw-navbar-item-active` |
| Nav item label (when close chrome is present) | `.sw-navbar-item__label` |
| Decorative close chrome | `.sw-navbar-item__close` |

```css
.sw-navbar { border-bottom: 2px solid gold; }
.sw-navbar-item-active { text-decoration: underline; }
```

Both `navbar` and `nav_item` accept `class:`/`style:` (nav_item forwarding
added in stream_weaver-oeo).
`nav_item(..., close: true)` adds a decorative `×`; pass a string to `close:`
for a different glyph. This option is visual tab chrome, not an interactive
close action. Apps that close tabs should wire that behavior through their own
action component.

### Topbar

App-chrome header bar: brand (icon/glyph + wordmark), a breadcrumb trail,
and trailing block content (badges/pills/whatever you render in the
block). Added in stream_weaver-oeo to replace the hand-rolled
div/phrase topbar both tyrion parity slices needed (design-parity-
fights.md finding #6).

| Element | Hook |
|---|---|
| Container | `.sw-topbar` |
| Brand wrapper | `.sw-topbar-brand` |
| Brand icon | `.sw-topbar-icon` |
| Wordmark | `.sw-topbar-wordmark` |
| Breadcrumb trail | `.sw-topbar-breadcrumbs` |
| Breadcrumb item | `.sw-topbar-crumb`, `.sw-topbar-crumb--active` (last item) |
| Breadcrumb separator | `.sw-topbar-separator` |
| Trailing content | `.sw-topbar-trailing` |

```css
.sw-topbar { background: #1a1208; border-bottom: 1px solid #4a3520; }
.sw-topbar-wordmark { font-family: 'Cinzel', serif; letter-spacing: 0.1em; }
```

```ruby
topbar(icon: "🦁", wordmark: "TYRION", breadcrumbs: ["field-ops", "warroom"]) do
  badge("main")
end
```

`icon:` follows the same URL-vs-glyph detection as `lane`'s `icon:`.
`breadcrumbs:` is a plain array of strings; the last one gets
`.sw-topbar-crumb--active`. The brand wrapper, breadcrumb trail, and
trailing wrapper are each omitted from the DOM when they have nothing to
render (no icon/wordmark, empty breadcrumbs, or an empty block).
`topbar` accepts `class:`/`style:`.

### AppShell

| Element | Hook |
|---|---|
| Shell container | `.sw-app-shell`, `.sw-app-shell-sidebar-{position}` |
| Main region | `.sw-app-shell-main` |
| Sidebar region | `.sw-app-shell-sidebar` |

```css
.sw-app-shell { --sw-shell-sidebar-width: 280px; }
```

`app_shell` accepts `class:`/`style:` (merged with the framework's own
`--sw-shell-sidebar-width`/`--sw-shell-gap` custom properties).

### Card

| Element | Hook | Legacy (deprecated) |
|---|---|---|
| Card container | `.sw-card`, `.sw-card--{depth}`, `.sw-card--accent-{a\|b\|c}` | `.card` |
| Corner label | `.sw-card__label` | -- |
| Header | `.sw-card-header` | `.card-header`, `.card-header--badged` |
| Header badge | `.card-header__badge` | -- |
| Header title | `.card-header__title` | -- |
| Header meta | `.card-header__meta` | -- |
| Body | `.sw-card-body` | `.card-body` |
| Footer | `.sw-card-footer` | `.card-footer` |

```css
.sw-card { border-radius: 16px; }
.sw-card--hero { box-shadow: 0 20px 40px rgba(0,0,0,0.3); }
```

`card`, `card_header`, `card_body`, and `card_footer` all accept
`class:`/`style:` (`card_header`/`card_body`/`card_footer` forwarding
added in stream_weaver-oeo).

### Table

| Element | Hook |
|---|---|
| Table element | `.sw-table` |
| Variants | `.sw-table-striped`, `.sw-table-bordered`, `.sw-table-hoverable`, `.sw-table-compact`, `.sw-table-sortable`, `.sw-table--alternating`, `.sw-table--hover`, `.sw-table--sticky-header` |
| Row action cell | `.sw-table__actions` |

```css
.sw-table { font-family: 'IBM Plex Mono', monospace; }
.sw-table-striped tr:nth-child(even) { background: #f5f5f0; }
```

`table` accepts `class:`/`style:` on the `<table>` element itself
(forwarding added in stream_weaver-oeo; `style:` is appended after the
framework's own required `width`/`border-collapse` base style).

### Button

| Element | Hook | Legacy (deprecated) |
|---|---|---|
| Button | `.sw-button` | `.btn`, `.btn-primary`/`.btn-secondary`, `.btn-quiet`, `.btn-outline`, `.btn-sm` |

```css
.sw-button { text-transform: uppercase; letter-spacing: 0.05em; }
```

`.sw-button` is an identifying hook only -- no framework CSS rule targets
it directly (styling stays keyed off `.btn`/`.btn-primary`/etc. so
`style: :none`'s "no framework look" contract is unaffected by its
presence). It's always emitted, including under `style: :none`.

### Modal

| Element | Hook |
|---|---|
| Outer wrapper | `.sw-modal-wrapper` |
| Backdrop | `.sw-modal-backdrop` |
| Dialog | `.sw-modal`, `.sw-modal-{sm\|md\|lg\|xl}` |
| Header | `.sw-modal-header` |
| Title | `.sw-modal-title` |
| Body | `.sw-modal-body` |

```css
.sw-modal { border-radius: 8px; border: 2px solid gold; }
```

`modal` accepts `class:`/`style:` on the dialog element (forwarding added
in stream_weaver-oeo).

### Badge / Status

| Component | Element | Hook | Legacy (deprecated) |
|---|---|---|---|
| `badge` | Pill | `.sw-badge`, `.sw-badge-{variant}`, `.sw-badge-{size}` | -- |
| `status_dot` | Dot | `.sw-status-dot`, `.sw-status-dot-{status}`, `.sw-status-dot-{size}`, `.sw-status-dot-pulse` | -- |
| `status_dot` | Label | `.sw-status-dot-label` | -- |
| `status_badge` | Badge | `.sw-status-badge`, `.sw-status-badge--{strong\|maybe\|skip\|unknown}` | `.status-badge`, `.status-badge-{strong\|maybe\|skip\|unknown}` |
| `status_badge` | Icon/label/reasoning | `.sw-status-badge__icon`, `.sw-status-badge__label`, `.sw-status-badge__reasoning` | `.status-badge-icon`, `.status-badge-label`, `.status-badge-reasoning` |

```css
.sw-badge-success { background: #16a34a; }
.sw-status-badge--strong { background: rgba(16,185,129,0.15); }
```

### Sidebar-section utility class

`.sidebar-section` is a plain CSS utility (no dedicated component --
apply it with `class: "sw-sidebar-section"` on any `div`/container). The
`sw-sidebar-section` hook styles identically; the unprefixed name is kept
for back-compat only.

```css
.sw-sidebar-section { background: transparent; }
```

## Why this exists

Before stream_weaver-oeo, a bespoke skin had two options: fight the
framework's CSS with specificity bumps (see
`gsd/analysis/08-design-parity-fights.md` finding #1, and
`examples/parity/tyrion_warroom_slice.rb`'s header comment for the
pixel-parity slice that had to invent its own class names entirely to
avoid the fight), or reverse-engineer whichever internal class happened
to be attached to the element you wanted to style. Neither scales past a
one-off demo.

Now: every framework style lives in `@layer stream-weaver`, so any
unlayered app stylesheet always wins regardless of specificity or
document order, and every structural component emits one of the `sw-`
hooks documented above. A bespoke look is "pretty DSL calls + one CSS
file targeting these hooks" -- see
`examples/parity/tyrion_warroom_components.rb` +
`examples/parity/tyrion_components.css` for the proof.
