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

If the first column's inline accent styling beats your own CSS on cells (not
the `<table>` element), that's a cell-level concern -- `class:`/`style:`
above only forwards to the `<table>` tag. Use per-column `style:` (String or
Proc) for arbitrary cell CSS, per-column `id_style:` to opt a column in or
out of the accent styling regardless of position, or table-level
`id_column:` to redirect (or disable) which column gets it on raw
`headers:`/`rows:` tables. See Table in `docs/components_reference.md` for
examples.

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

## IDE shell

The `:ide` theme and the `ide_*` components build a VS Code-style page: a
title bar, a left rail, an editor made of tabbed sections, a right rail with
a file tree and a terminal, and a status bar. Every component emits `sw-ide-*`
hooks, and all of them are styled by one stylesheet, `Components::Ide::CSS`,
which `IdeShell` declares with the `css` class macro (`layered: true`), so it
reaches every host once per page. Colours and fonts come from the
theme's `--ide-*` tokens (with `--sw-*` fallbacks), so another palette is a
token change, not a rewrite.

| Component | Element | Hook |
|---|---|---|
| `ide_shell` | Grid | `.sw-ide-shell`, `.sw-ide-shell--rail-open`, `.sw-ide-shell__nav-toggle`, `.sw-ide-shell__backdrop` |
| `ide_titlebar` | Bar | `.sw-ide-titlebar` |
| `ide_titlebar` | Parts | `__logo`, `__scope`, `__crumbs`, `__crumb`, `__crumb--current`, `__crumb-sep`, `__branch`, `__branch-icon`, `__actions`, `__link`, `__link-icon`, `__link-label`, `__theme-toggle`, `__theme-icon` |
| `ide_rail_left` | Rail | `.sw-ide-rail-left` |
| `ide_tree` | Tree | `.sw-ide-tree`, `__heading`, `__action`, `__rows`, `__row`, `__row--active`, `__row--selected`, `__row--disabled`, `__label`, `__tag` |
| `ide_note` | Card | `.sw-ide-note`, `__icon`, `__body`, `__dismiss` |
| `ide_editor` | Scroller | `.sw-ide-editor`, `.sw-ide-tabstrip`, `.sw-ide-tab` (`.sw-is-active` while its section is on screen) |
| `file_section` | Section | `.sw-ide-file-section`, `__comment` (the section is the tab's target) |
| `ide_rail_right` | Rail | `.sw-ide-rail-right` |
| `ide_rail_tabs` | Tabs | `.sw-ide-rail-tabs`, `.sw-ide-rail-tab`, `--active`, `--dim` |
| `ide_filetree` | Tree | `.sw-ide-filetree`, `__row` (`.sw-is-active`), `__icon` |
| `ide_terminal` | Panel | `.sw-ide-terminal`, `__head`, `__label`, `__screen`, `__line`, `__command`, `__prompt`, `__output` |
| `ide_statusbar` | Bar | `.sw-ide-statusbar`, `__item`, `__spacer` |

Page content has hooks too, for plain `div`s (there is no component behind
them): `.sw-ide-hero__title`, `__tagline`, `__lede`, `__meta`, `.sw-ide-pills` /
`.sw-ide-pill`, `.sw-ide-actions` / `.sw-ide-btn` (`--primary`), `.sw-ide-h2`,
`.sw-ide-h3`, `.sw-ide-lead`, `.sw-ide-beat`, `.sw-ide-cards` / `.sw-ide-card`
(`__head`, `__icon`), and `.sw-ide-transcript` (`__panel`, `__panel--page`,
`__label`, `__body`, `__line`, `__line--out`, `__choices`, `__choice`, `__cta`).
`.sw-ide-visually-hidden` hides text from sight but not from screen readers.
Text and phrase components render a `p`, so a wrapper hook needs
`p { margin: 0; color: inherit }`.

### Composing a shell

```ruby
App = StreamWeaver::App.new("My page", chrome: false, theme: :ide) do
  ide_shell do
    ide_titlebar(crumbs: %w[project page], branch: "main") { text "LOGO" }
    ide_rail_left { ide_tree(heading: "Pages", rows: [{ label: "Home", icon: :file, href: "/", selected: true }]) }
    ide_editor do
      file_section "intro", label: "README.md", icon: :file do
        header2 "Hello"
      end
    end
    ide_rail_right { ide_rail_tabs([{ label: "Files", active: true }]); ide_filetree }
    ide_statusbar(left: ["MIT"], right: ["Ruby"])
  end
end
```

- Use `chrome: false`; the shell owns the viewport. The theme toggle in the
  title bar flips light and dark.
- Each `file_section` is one tab and one `ide_filetree` row. The last section
  is sized automatically (`.sw-ide-editor > .sw-ide-file-section:last-child`
  fills the viewport), so its tab can reach the top of the editor.
- Below 1180px the right rail goes off-canvas behind a menu button, and below
  840px the left rail is hidden.
- The `:ide` palette lives in `--ide-*` tokens on `body.sw-theme-ide`; the dark
  palette is declared under `html.dark body.sw-theme-ide` (see
  [the flexibility note](ide-shell-css-flexibility.md) for why).

`examples/ide/streamweaver_landing.rb` is the full page; `examples/ide/shell_demo.rb`
is the smallest working one.

## Themes, tokens and page assets

A page is described once, by `PageShell.resolve`, and every host (the
standalone view, the canvas, the reader, the exporter, the Opal builder)
builds its `<head>` and body class from that one description. This section
is the map of where to extend what.

### Add a theme: `register_theme`

`register_theme` is the one way to add a theme, in your app or in a gem:

```ruby
StreamWeaver.register_theme :harbor,
  { color_primary: "#0e7490", color_bg: "#f7fafa", font_body: "'Inter', system-ui, sans-serif" },
  dark:  { color_primary: "#22d3ee", color_bg: "#0b1416", color_text: "#e6f4f7" },
  fonts: ["Inter:wght@400;600", { family: "Harbor Mono", src: "fonts/harbor.woff2" }],
  stylesheets: ["https://example.test/harbor-extra.css"],
  css:   "body.sw-theme-harbor h2 { letter-spacing: -0.01em; }",
  label: "Harbor", base: :document

StreamWeaver::App.new("Harbor", theme: :harbor) { header2 "Hello" }
```

| Argument | Meaning |
|---|---|
| `tokens` (2nd, a Hash) | Light-mode values; keys are `Theme::VARIABLE_SCHEMA` names (below) or raw `--custom-property` names |
| `dark:` | Dark-mode values (see the accent-versus-surface rule below) |
| `fonts:` | Google Fonts entries (`"Inter:wght@400;600"`) or self-hosted `{ family:, src: }`; a relative `src` resolves against the file that calls `register_theme` |
| `stylesheets:` | Stylesheet URLs the head loads |
| `css:` | Extra CSS emitted after the generated token CSS |
| `label:` | Name shown in the theme switcher |
| `description:` | Optional short text (default "Custom theme"). Stored metadata: `all_themes_for_switcher` returns it with `id`, `label` and `built_in`, and `to_ruby` / `to_json` save it; no page shows it |
| `base:` | Built-in theme whose look it inherits (default `:default`) |

The generated light and dark CSS lives under `body.sw-theme-harbor`, and
dark mode matches either signal, `html.dark` or `html[data-sw-theme="dark"]`.
A registered theme's page wears its base theme's class too
(`sw-layout-default sw-theme-document sw-theme-harbor`), because the base supplies type,
spacing and radius; the theme's own block, later at the same specificity,
overrides what it sets. The six built-ins (`:default`, `:dashboard`,
`:document`, `:dark`, `:doc`, `:ide`) register the same way, for their label
and fonts only: their hand-tuned CSS stays in `master_theme_css`.

A runtime switch to a registered theme reloads the page: its CSS, fonts and
stylesheets are emitted only for the theme a page is rendered with. The
`theme_switcher` swaps a built-in theme's classes in place, without a reload.

### Override tokens from the DSL: `theme_tokens`

```ruby
theme_tokens color_primary: "#a21caf", dark: { color_bg: "#120712" }
```

`theme_tokens` works inside any DSL body (a standalone app, a canvas push,
a `canvas-read` doc, an export). `App.new(..., theme_overrides: { ... })` is
the same call. It emits a layered `body[class*="sw-theme-"]` block, so it
applies over whatever theme the page wears. `dark:` values emit under the
same two dark selectors as a registered theme's (`html.dark` and
`html[data-sw-theme="dark"]`).

Token names (`Theme::VARIABLE_SCHEMA`; an unknown name warns):

| Group | Tokens |
|---|---|
| Typography | `font_display`, `font_body`, `font_family`, `font_mono`, `font_size_base`, `font_size_sm`, `font_size_lg`, `font_size_xl`, `line_height` |
| Primary | `color_primary`, `color_primary_hover`, `color_primary_light`, `color_primary_glow` |
| Neutrals | `color_text`, `color_text_muted`, `color_text_light`, `color_bg`, `color_bg_card`, `color_bg_elevated`, `color_border`, `color_border_strong`, `color_border_focus` |
| Secondary and accent | `color_secondary`, `color_secondary_hover`, `color_secondary_foreground`, `color_accent`, `color_accent_light` |
| Spacing and radius | `spacing_xs` to `spacing_2xl`, `radius_sm` to `radius_xl` |
| Shadows | `shadow_sm`, `shadow_md`, `shadow_lg`, `shadow_xl`, `shadow_inner`, `card_border_left` |
| Term highlighting | `term_color`, `term_bg_hover` |
| Visual skills | `vs_bg`, `vs_surface`, `vs_surface_elevated`, `vs_border`, `vs_text`, `vs_text_dim`, `vs_accent`, `vs_node_a` to `vs_node_c`, `vs_success`, `vs_warning`, `vs_error`, `vs_info` |

**Accent versus surface.** An accent or brand token (primary, accent,
type, spacing) applies in both modes. A surface token
(`Theme::SURFACE_TOKENS`: the neutral colors `color_text*`, `color_bg*`,
`color_border*`, and the `shadow_*` tokens) applies in light mode only,
because the framework's dark block owns those values; pass `dark:` to
give one a dark value.

Limits:

- **Opal builds do not render tokens.** The page keeps its theme's tokens
  and the build warns once.
- **Partial `dark:` with only `data-sw-theme="dark"`.** The built-in
  `:default` keys its dark text on `html.dark`, so a host that sets only the
  attribute gets your dark background with light-mode text unless `dark:`
  also gives `color_text`. Normal auto mode sets both signals.
- **A canvas push applies live, with no reload.** A pushed `use_theme`,
  `theme_tokens`, theme-declared fonts, theme and component CSS and
  stylesheets all take effect on the open canvas. The session's theme is
  only the fallback for a body with no `use_theme`.
  - Push CSS (`use_stylesheet`, `theme_tokens`) is *replaced* as a group on
    every push. Head asset tags (fonts, stylesheets, component CSS) are
    append-only, keyed by a hash of the tag: a font link from an earlier
    theme stays until a reload.
  - A push that fails to evaluate (including `SyntaxError` and
    `SystemStackError`) changes nothing; the CLI prints
    `Push rejected: <name> still shows its previous page`.
  - The live canvas and `canvas-read` agree for the same body.

### Component assets: the class macros

A component declares what it needs on its class, and every host delivers it:

```ruby
class Panel < StreamWeaver::Components::Base
  css ".harbor-panel { padding: 1rem }"                                   # unlayered: outranks the framework
  css ".harbor-panel b { color: var(--sw-color-primary) }", layered: true  # in @layer stream-weaver
  css_path "harbor.css"                                                    # a file, delivered per host
  js_path  "harbor.js"
  font family: "Harbor Mono", src: "fonts/harbor.woff2", weight: "400 700"

  def render(view, state)
    view.div(class: "harbor-panel") { view.plain "hi" }
  end
end
StreamWeaver.register_component(Panel, dsl: :harbor_panel)

StreamWeaver::App.new("Harbor") { harbor_panel }   # or `harbor_panel` in a canvas push
```

`register_component` defines the DSL method (`harbor_panel`), which a body
then calls like any component. A relative `css_path`, `js_path` or `font`
`src` resolves against the file that declares the class (here, the
directory of the file holding `Panel`); an absolute path works too. `css` and `font` accumulate when repeated, but `css_path` and `js_path`
hold one file each: a second `css_path` line replaces the first. Each
class contributes once per page, however many instances render. `layered:`
is optional: the default `false` is unlayered, so an app's component CSS
wins over the framework; `layered: true` is for framework components.

### The extension points: `Assets`, `PageShell`, `Delivery`

- **`StreamWeaver::Assets`**: one value,
  `Data.define(:fonts, :stylesheets, :framework_css, :user_css, :scripts, :body_classes)`.
  Two CSS buckets because layering depends on who owns the CSS: framework
  CSS is layered, user CSS is not. `+` concatenates bucket by bucket and
  drops repeats, so the framework, theme, layout, components and app each
  contribute one and are merged. `Assets.of(framework_css: [...])` builds one.
- **`PageShell.resolve(app, theme:, ...)`** returns a `PageShell::Page`:
  the `theme` and `layout` in effect, the merged `assets`, and
  `body_class` (the body's class string, computed in this one place). It
  must run *after* the body has rendered, because components register their
  CSS while they render and the app's `theme_tokens` run in the body. `app`
  is `nil` for a host with no App (a canvas page, an Opal build).
  `PageShell.fragment_page` is the same for a DSL fragment whose App is gone.
- **`PageShell.head(page, delivery)`** returns a `Head`, which renders a
  `Page`'s assets as tags through a `Delivery`. Which methods a host calls:
  - `Head#to_s` is the whole asset part of a head in one fixed order (layer
    pin, fonts, framework CSS, theme and component CSS, stylesheets, user
    CSS, scripts). Export and the reader call it (the reader passes
    `extra_layers:` for its chrome).
  - `Head#asset_tags` returns the page's own tags (font tags, the layered
    theme and component CSS block, stylesheet tags) as an array of strings,
    without scripts or user CSS. The live canvas keys each by a digest and
    appends the ones the open page lacks after a push; scripts are left out
    because one appended later would not run in page order, and user CSS is
    left out because the canvas replaces it as a group.
  - The per-bucket methods (`fonts`, `stylesheets`, `framework_css`,
    `user_css`, `scripts`) let a host place each piece itself. The standalone
    view and the Opal builder do.
- **`Delivery`** answers one question per host, `ref(path, kind)`, which
  returns the markup that loads a local file as `:stylesheet`, `:script` or
  `:font`. `Delivery::Served` gives a `/sw-asset` URL (standalone, canvas,
  reader), `Delivery::Inline` embeds the content (export), and
  `Delivery::Copied.new(root)` copies the file into `root/sw-assets/` and returns a
  relative href (Opal; `root` is the build's output directory, `dist` by default). A remote URL passes through unchanged.

```ruby
app = StreamWeaver::App.new("Harbor", theme: :harbor) do
  theme_tokens color_primary: "#a21caf"
  harbor_panel
end
app.generate    # renders the body: components and tokens register while it renders
page = StreamWeaver::PageShell.resolve(app, theme: :harbor)
puts page.body_class                                           # sw-layout-default sw-theme-document sw-theme-harbor
puts StreamWeaver::PageShell.head(page, StreamWeaver::Delivery::Served.new)
```

Resolve before `app.generate` and the page is missing the app's token CSS and
its components' assets: both are collected during the render.

### One place per axis

| To add | Touch exactly |
|---|---|
| A user or gem theme | One `register_theme` call, with `dark:`, `fonts:`, `css:` |
| A built-in theme | Two places: a `register_built_in_theme` line in `theme/built_ins.rb` (label, fonts) and its hand-tuned `body.sw-theme-<name>` block in `Views::AppView.master_theme_css`; the golden gate picks it up from `StreamWeaver.built_in_themes` |
| A DSL token override | `theme_tokens` (or `theme_overrides:`) |
| Component CSS, scripts or fonts | The `css`, `css_path`, `js_path`, `font` macros on the class; they reach every host |
| An output host | Not yet single-place. One `Delivery` class plus calls to `PageShell.resolve` and `PageShell.head`, and by hand: the framework's Google Fonts link (`Fonts::BASE_HREF`) and the two `preconnect` links (as `views.rb`, `css.rb` and `opal/builder.rb` do), and either `Head#to_s` or its own placement of `Head`'s buckets |
| A font source | Not yet single-place. Google fonts and self-hosted files are filtered separately (`Fonts.google_fonts_href`, `Fonts.font_face_css`) and `Head#font_tags` knows both kinds, so a third kind touches all three; the component `font` macro declares only self-hosted files |
| A gem layout | `register_layout` (unchanged); its `css_path` reaches every host |

### The golden gate

`spec/page_goldens_spec.rb` (helpers in `spec/support/page_goldens.rb`)
renders one fixed probe page for every built-in theme on every host (a probe you add may cover a subset of hosts, as the recipe below does)
(standalone, canvas, reader, export, Opal, the `/live` page) and compares
the ordered `<head>`, the body class and every CSS block with the files
under `spec/fixtures/page_goldens/`. Further probes cover a variant page
(app fonts, a stylesheet, a layout slot, `chrome: false`), `theme_overrides:`,
a registered theme (`:harbor`) and one `Theme::Presets` preset. Any change
to how a page is assembled must show up here, and only as a diff you meant.

```bash
bundle exec rspec spec/page_goldens_spec.rb                        # check
UPDATE_GOLDENS=1 bundle exec rspec spec/page_goldens_spec.rb       # rewrite, then review
git diff spec/fixtures/page_goldens                                # name each diff in the commit
```

- **A new host**: add its name to `PageGoldens::HOSTS` and a
  `render_<host>(theme)` method returning the page's HTML; if its body is
  filled in the browser, add it to `BROWSER_FILLED`.
- **Exclusions**: `PageGoldens::EXCLUSIONS` is a Hash of `'part of a host' =>
  'why it cannot be rendered without a browser or a full compile'` (the Opal
  `app.js`, runtime theme switching, the `/live` body, the extension head).
  A browser-filled host must name one, and the spec checks that the reason
  is a sentence.
- **The CSS store**: each CSS block is stored once, referenced by a
  12-character digest, in the shard named by the digest's first two hex
  digits (`css_blocks/<xx>.css`). A changed block is one in-place hunk in its
  shard. The git hygiene hook (`bin/check_git_hygiene`) blocks a staged file
  over 500,000 bytes; sharding keeps every file to about one block (the
  largest, a joined framework CSS block, is about 120 KB), so a new probe or
  host needs no store work. Keep new probes lean anyway, as `REGISTERED_DSL`
  does by leaving out the `ide_shell`: every distinct block is another copy
  of the framework CSS.

#### How the helper is built

- `PageGoldens.render_all` takes no arguments and returns a
  `Hash{String => String}`: a fixture path relative to
  `spec/fixtures/page_goldens/` (`"export/default.txt"`) to the text recorded
  for it. It always includes the store shards (`"css_blocks/<xx>.css"`). The spec renders it once in
  `before(:all)`, as `@fresh`.
- A probe constant holds a String (a DSL body, as `PROBE_DSL`, `VARIANT_DSL`,
  `REGISTERED_DSL`) or a Hash (App options or tokens, as `VARIANT_APP_OPTIONS`,
  `OVERRIDES`); hosts are Arrays of Symbols.
- `record(html)` reduces a page to its body class, head tags and body asset
  tags, and stores each CSS block once, by digest, in its `css_blocks/` shard.
- An example compares a render with its fixture like this (from the spec):
  `expect(@fresh.fetch("export/tokens.txt")).to eq(golden("export/tokens.txt"))`,
  where `golden(path)` reads the file and raises `missing golden ...` if there is none.
- Fixtures are named `<host>/<name>.txt` and are written only by
  `UPDATE_GOLDENS=1`, which deletes the directory and rewrites it from `render_all`.

#### Add a new probe in 5 steps

Followed end to end (and reverted) on a throwaway probe, this recipe turned a
missing fixture into a green spec:

1. Add the probe's inputs as constants in `spec/support/page_goldens.rb`, e.g.
   `TOKENS_HOSTS = %i[export].freeze` and
   `TOKENS_DSL = "theme_tokens color_primary: '#a21caf'\nheader1 'Tokens probe'\n"`.
2. Add one render method per host, returning `record(html)`:
   `def render_tokens_export; record(StreamWeaver::Export::HtmlExporter.from_dsl(TOKENS_DSL, theme: :default).to_html); end`.
3. In `render_all`, add, before the final `pages.merge(css_store_files)` line (anywhere after `pages = {}` works; the store shards are built last),
   `TOKENS_HOSTS.each { |host| pages["#{host}/tokens.txt"] = send("render_tokens_#{host}") }`.
4. In `spec/page_goldens_spec.rb`, add an `it` per host inside the
   `RSpec.describe` block, where `@fresh` and `golden` are already in scope,
   comparing `@fresh.fetch(path)` with `golden(path)`. The probe's name needs
   no registration anywhere else: the spec's "records every theme on every
   host, and nothing else" check compares the fixture directory with
   `@fresh.keys`.
5. Run `UPDATE_GOLDENS=1 bundle exec rspec spec/page_goldens_spec.rb`
   (it deletes the whole fixture directory and rewrites it from `render_all`, so
   a removed probe's fixtures vanish and the rest come back byte for byte), read
   `git diff spec/fixtures/page_goldens` (a new file, plus a new or grown
   `css_blocks/<xx>.css` shard for any new CSS block), run the spec again without the
   variable, and commit the constants, the method, the `it` and the fixtures together.

### Known follow-ups

- One Google Fonts URL builder is left, `Fonts.google_fonts_href`
  (`Presets.google_fonts_url` delegates to it). The component `font` macro
  cannot declare a Google font, so the sketch mode's Caveat link
  (`adapter/alpinejs.rb`, `inject_sketch_mode`) is still built by hand.
- `Head#to_s` is used by 2 of 5 hosts (export, reader). The canvas emits
  `framework_css_html` plus `Head#asset_tags`; the standalone view and the
  Opal builder place the buckets themselves. Moving `AppView` onto
  `Head#to_s` (the divergence comment in `views.rb`, `AppView#view_template`)
  is not done and is a stated golden diff when it is.
- Adding a host still needs `Fonts::BASE_HREF` and the `preconnect` links
  by hand: the design's single `Fonts.assets(entry)` branch was not built,
  so Google and self-hosted fonts are filtered separately
  (`Fonts.google_fonts_href`, `Fonts.font_face_css`) and `Head#font_tags`
  knows both.
- A `js_path` script is inert on a live canvas push: the poll replaces the
  page with `container.innerHTML` (`canvas/bridge_server.rb`, the poll
  script), which never runs scripts, so it runs only after a reload.
- `Canvas::Session#snapshot` re-creates the page recipe
  (`PageShell.fragment_page`) that `Canvas::Fragment#page` already holds,
  instead of keeping the pushed Fragment.
- `streamweaver export` rejects a DSL whose code sample mentions `run!`
  (disc-262).
- The reader takes theme fonts only from the first doc it opens.
- A live canvas keeps font links from an earlier theme until a reload
  (head asset tags are append-only).
- Code blocks are highlighted live but not after a reload (disc-263).
- Exclusive layouts are skipped on the canvas path (disc-259).

### Upgrade notes

- `App::BUILT_IN_THEMES`, `App::VALID_THEMES` and `Theme::BUILT_IN_THEMES`
  are gone, with no shim: ask `StreamWeaver.built_in_themes` or
  `StreamWeaver.get_theme(name)&.built_in?`. `Theme.google_fonts_url` and
  `Fonts.google_fonts?` are gone too: use `Fonts.google_fonts_href`.
- `Components::Ide::CSS` is now `IdeShell`'s `css` macro (layered) rather
  than injected by `render_ide_shell`, and no longer carries the landing-page
  rules (hero, pills, buttons, cards, transcript): they live in
  `examples/ide/streamweaver_landing_body.rb`.
- An already-registered custom theme's non-surface tokens (`color_primary`
  and the other accent, type and spacing tokens) now carry into dark mode;
  its surface tokens (`Theme::SURFACE_TOKENS`) still do not unless you pass
  `dark:`.
- `Theme::Presets` dark blocks now match both dark signals, `html.dark` and
  `html[data-sw-theme="dark"]`, not only one.
- `register_theme` with a built-in's name now warns (once per name): it
  replaces the hand-tuned built-in with a custom theme.
