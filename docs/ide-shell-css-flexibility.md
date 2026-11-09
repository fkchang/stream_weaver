# Is the CSS and theming mechanism flexible enough?

Short answer: yes for a look, partly for a whole page. Building the `:ide`
theme and the `ide_*` components (a VS Code-style landing page) needed no
change to the framework's CSS model, but it found gaps worth knowing about.

## What worked

- **`chrome: false`** removes the framework page chrome, so the shell could own
  the whole viewport.
- **The cascade layer.** Framework CSS sits in `@layer stream-weaver`, so
  unlayered component CSS wins without specificity fights.
- **`register_theme` and `BUILT_IN_THEMES`.** `:ide` is an ordinary theme with a
  light and a dark palette; nothing special-cased.
- **Theme-declared fonts.** The theme names Geist and JetBrains Mono and the
  page loads them on every host.
- **A component stylesheet declared with the `css` macro.** `IdeShell`
  declares `css Ide::CSS, layered: true`, so the stylesheet sits in the
  framework layer and reaches every host (standalone, canvas, reader, export,
  Opal) once per page.

## Gaps found

| Gap | Effect | Tracked |
|---|---|---|
| `theme_overrides:` colours lose in dark mode, because `html.dark body` is more specific than `body.sw-theme-X` (`views.rb`) | Fixed: accent tokens apply in both modes and a surface token takes a `dark:` value (`theme_tokens color_bg: "#fff", dark: { color_bg: "#111" }`); see `docs/theming-hooks.md` | disc-253 |
| Self-hosted fonts were not emitted (`fonts:` took Google Fonts only) | Fixed: a theme or a component's `font` macro declares `{ family:, src: }` and every host emits the `@font-face`, the file served, inlined or copied by its Delivery | disc-254 |
| `css_path` links reached neither the canvas nor Opal builds | Fixed: each host's Delivery serves (standalone, canvas, reader), inlines (export) or copies (Opal) `css_path` and `js_path` files, so a component stylesheet no longer has to be a string constant | disc-255 |
| No DSL token API | Fixed: `theme_tokens color_primary: "#a21caf"` in any DSL body (or `theme_overrides:`), on every host except Opal; `register_theme` takes `dark:`, `fonts:` and `css:` | disc-258 |
| Exclusive `register_layout` is skipped on the canvas path (`app.rb`) | `ide_shell` had to be a container component, not a layout; related to disc-127 | not filed (mark limit), see disc-127 |
| Exports and Opal builds did not load theme-declared fonts | Fixed: every host's head comes from `PageShell.resolve`, so an exported or Opal `:ide` page loads Geist and JetBrains Mono | disc-250 |
| The `:doc` dark selector keys only on `data-sw-theme`, not `html.dark` | Fixed: `:doc` dark mode follows either signal | disc-251 |
| The file tree is flat for screen readers (no nested structure) | The right-rail tree does not announce depth | disc-252 |
| The `:ide` theme did not declare `--sw-spacing-*` | Tab triggers computed to zero padding; fixed in the theme | fixed |

## Verdict

A bespoke, theme-quality page is a theme (tokens), one component stylesheet,
and `sw-` hooks, which matches `docs/theming-hooks.md`. The weak spots are the
edges that remain: the exclusive layout skipped on the canvas, and the Opal
build, which does not render DSL tokens. Dark-mode overrides, fonts and
component assets now reach every host through one page description
(`PageShell.resolve`); see `docs/theming-hooks.md`.
