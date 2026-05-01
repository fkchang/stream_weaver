# Opal CSS/Theme Wiring — Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `streamweaver opal-build` produce fully styled apps — the same StreamWeaver theme system that server-rendered apps enjoy, delivered as a static `dist/sw-theme.css` file with no build tools required.

**Architecture:** The builder writes `dist/sw-theme.css` from Ruby CSS strings already in the gem (`CSS.full_stylesheet` + `Theme.visual_skills_css`). `OpalShell` gains three `<head>` additions: Google Fonts CDN links, a `<link>` to the local `sw-theme.css`, and the dark mode inline script. `Adapter::Opal` adds `render_theme_preset` (no-op — preset baked at build time) and `render_theme_toggle` (data-attribute button). `OpalBridge` adds a fourth delegated listener for `data-sw-action="toggle-theme"`.

**Tech Stack:** Ruby (build-time CSS extraction from existing gem methods), existing `Theme` and `CSS` modules, no new dependencies.

---

## Background

Phase 1 Opal apps render correctly but ship unstyled — the browser sees raw HTML with no stylesheet. The StreamWeaver CSS lives entirely in Ruby as heredoc strings and is normally injected inline by `views.rb` during server-side rendering. For Opal builds, we extract it at build time (MRI) and write it as a separate cacheable file.

### How CSS works today (server-side)

`views.rb` injects into `<head>` at render time:
- Google Fonts CDN `<link>` tags (preconnect + stylesheet)
- A large inline `<style>` block via `CSS.full_stylesheet` (extracted from `views.rb` heredoc)
- `Theme.visual_skills_css` — semantic `--sw-*` CSS custom property tokens
- `Theme::AutoMode.inline_script` — dark mode JS that reads localStorage/system preference
- Per-component `render_theme_preset` calls inject CSS var overrides for the active preset

For Opal, all of this must be handled at build time since there is no server render.

---

## Design

### 1. OpalBuilder — new `write_theme_css` step

`OpalBuilder#call` gains a new step between `copy_morphdom` and `write_index_html`:

```ruby
def call
  FileUtils.mkdir_p(@output_dir)
  write_app_js
  copy_morphdom
  write_theme_css   # new
  write_index_html
end
```

`write_theme_css` assembles the CSS from existing gem methods:

```ruby
def write_theme_css
  css = StreamWeaver::CSS.full_stylesheet
  css += "\n" + StreamWeaver::Theme.visual_skills_css
  css += "\n" + StreamWeaver::CSS.animation_css
  if @theme
    preset = StreamWeaver::Theme::Presets.find(@theme)
    css += "\n" + preset.to_css if preset
  end
  File.write(output_path("sw-theme.css"), css)
end
```

`OpalBuilder.new` and `.build` gain a `theme:` keyword (default `nil`):

```ruby
def self.build(app_file, output_dir: "dist", title: nil, theme: nil)
  new(app_file, output_dir: output_dir, title: title, theme: theme).call
end

def initialize(app_file, output_dir: "dist", title: nil, theme: nil)
  # ... existing setup ...
  @theme = theme
end
```

The `--theme` CLI flag maps to this keyword. Invalid preset names are warned and ignored (same pattern as `build_stdlib`).

**`dist/` output after build:**

| File | Contents |
|---|---|
| `app.js` | Compiled Ruby DSL (unchanged) |
| `morphdom.min.js` | DOM patching (unchanged) |
| `sw-theme.css` | Full StreamWeaver CSS + optional preset vars |
| `index.html` | Shell with all `<head>` links wired |

### 2. OpalShell — enriched `<head>`

`OpalShell.render` gains three new optional params:

```ruby
def self.render(
  title: "StreamWeaver App",
  app_js: "app.js",
  morphdom_js: nil,
  theme_css: nil,         # new: local CSS filename or nil
  google_fonts_url: nil,  # new: Google Fonts URL or nil
  dark_mode_script: nil   # new: JS string or nil
)
```

The generated `<head>` becomes:

```html
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>#{title}</title>
  <!-- Google Fonts (if google_fonts_url provided) -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="#{google_fonts_url}">
  <!-- Theme CSS -->
  <link rel="stylesheet" href="#{theme_css}">
  <!-- morphdom -->
  <script src="#{morphdom_src}"></script>
  <!-- Dark mode script -->
  <script>#{dark_mode_script}</script>
</head>
```

Each addition is conditional on its param being non-nil, so existing tests need no changes and builds without `--theme` still work (though they won't look styled).

`OpalBuilder#write_index_html` passes the new params:

```ruby
def write_index_html
  File.write(output_path("index.html"),
    OpalShell.render(
      title: @title,
      app_js: "app.js",
      morphdom_js: File.exist?(output_path("morphdom.min.js")) ? "morphdom.min.js" : nil,
      theme_css: File.exist?(output_path("sw-theme.css")) ? "sw-theme.css" : nil,
      google_fonts_url: google_fonts_url_for_build,
      dark_mode_script: StreamWeaver::Theme::AutoMode.inline_script
    ))
end
```

`google_fonts_url_for_build` returns the URL for the default preset (Source Sans 3 + Crimson Pro), or the preset-specific URL if `@theme` is set.

### 3. Adapter::Opal — theme methods

**`render_theme_preset`** — no-op. The preset CSS vars were baked into `sw-theme.css` by the builder. Nothing to emit at render time.

```ruby
def render_theme_preset(view, component, state)
  # CSS vars for this preset are in dist/sw-theme.css, written at build time.
end
```

**`render_theme_toggle`** — emits a button with a `data-sw-action` attribute. No Ruby callback; the bridge handles it as a pure browser action.

```ruby
def render_theme_toggle(view, component, state)
  view.button(data_sw_action: "toggle-theme") { view.plain("🌓") }
end
```

### 4. OpalBridge — `data-sw-action` listener

`OpalBridge#install` gains a fourth delegated listener alongside the existing three:

```ruby
# Inside the %x{} block, within window.SWRuntime.start:
document.addEventListener('click', function(e) {
  var el = e.target.closest('[data-sw-action]');
  if (el && el.dataset.swAction === 'toggle-theme') {
    if (typeof swToggleTheme === 'function') swToggleTheme();
  }
});
```

`data-sw-action` is for browser-only static actions (no Ruby callback). This is distinct from `data-sw-invoke` (Ruby callbacks). Using a named attribute keeps the "no inline onclick" principle consistent.

### 5. CLI — `--theme PRESET` flag

`opal_build` in `cli.rb` gains a `--theme` option via `OptionParser` (the existing hand-rolled arg parsing stays for now; the DHH-style OptionParser refactor is a separate cleanup):

```ruby
theme = nil
# ... after file extraction:
if args.include?('--theme')
  theme = args[args.index('--theme') + 1]
end
StreamWeaver::Opal::Builder.build(file, output_dir: output_dir, theme: theme)
```

---

## What This Enables

After this change:

```bash
streamweaver opal-build hello_world.rb
# dist/ now has sw-theme.css — styled with default theme

streamweaver opal-build dashboard.rb --theme editorial
# dist/sw-theme.css includes editorial preset CSS vars
```

A Phase 1 `hello_world` app built with this change will look identical to its server-rendered counterpart: correct fonts, colors, spacing, dark mode toggle, component styles.

---

## What This Does Not Cover

- **`render_theme_switcher`** (runtime preset switching) — requires runtime CSS injection, deferred to Phase 3.
- **Offline fonts** — Google Fonts is still CDN-loaded. Embedding fonts as base64 is deferred.
- **Custom registered themes** (`StreamWeaver.register_theme`) — require the user's theme registration code to run at build time. Deferred.
- **Other adapter methods** (`render_tabs`, `render_table`, `mermaid`, `chartjs`) — separate Phase 2b spec.

---

## Testing

- `spec/opal/builder_spec.rb` — add: writes `sw-theme.css`, `--theme` appends preset CSS
- `spec/opal/shell_spec.rb` — add: includes Google Fonts link, theme CSS link, dark mode script when params provided; omits when nil
- `spec/opal/adapter_opal_spec.rb` — add: `render_theme_preset` is a no-op, `render_theme_toggle` emits `data-sw-action="toggle-theme"` button
- `spec/opal/bridge_spec.rb` — add: `data-sw-action` listener section (`:nocov:` for browser-only code, document the expected behavior)
