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
  standalone page loads them with one link.
- **A component stylesheet as a Ruby constant.** `Components::Ide::CSS` is
  added once by `render_ide_shell`. A constant, not a `css_path` file, because
  it must reach both the standalone page and the canvas.

## Gaps found

| Gap | Effect | Tracked |
|---|---|---|
| `theme_overrides:` colours lose in dark mode, because `html.dark body` is more specific than `body.sw-theme-X` (`views.rb`) | A theme must declare its dark tokens under `html.dark body.sw-theme-X` itself, as `:doc` and `:ide` do | disc-253 |
| Self-hosted fonts are not emitted (`fonts:` takes Google Fonts only) | A theme cannot ship its own font files | disc-254 |
| `css_path` links reach neither the canvas nor Opal builds | Only a CSS string constant works everywhere, which is why `Components::Ide::CSS` is one | disc-255 |
| No DSL token API | A page cannot set `--ide-*` or `--sw-*` tokens from Ruby; it needs CSS | not filed (mark limit) |
| Exclusive `register_layout` is skipped on the canvas path (`app.rb`) | `ide_shell` had to be a container component, not a layout; related to disc-127 | not filed (mark limit), see disc-127 |
| Exports and Opal builds do not load theme-declared fonts | Exported `:ide` pages fall back to system fonts | disc-250 |
| The `:doc` dark selector keys only on `data-sw-theme`, not `html.dark` | `:doc` dark mode can lose to generic dark rules | disc-251 |
| The file tree is flat for screen readers (no nested structure) | The right-rail tree does not announce depth | disc-252 |
| The `:ide` theme did not declare `--sw-spacing-*` | Tab triggers computed to zero padding; fixed in the theme | fixed |

## Verdict

A bespoke, theme-quality page is a theme (tokens), one component stylesheet,
and `sw-` hooks, which matches `docs/theming-hooks.md`. The weak spots are the
edges: dark-mode specificity, fonts, and anything that bypasses the standalone
page (canvas, exports, Opal).
