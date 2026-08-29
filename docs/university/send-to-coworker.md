# Send this to a coworker

Two versions, depending on who's getting it. Pick one and paste it as-is.

## Developer version

> StreamWeaver is a Ruby DSL for building interactive UIs with almost no code, and it comes with a
> five-step "Getting Started" course that teaches it by actually running it next to your terminal.
> The full experience is a split iTerm2 tab (agent on one side, the course on the other) -- set that
> up first, then install the gem and run the door command.

**1. Prerequisites** (macOS + iTerm2 only -- skip if you're on another OS or terminal, you'll just
get a browser tab instead):

```bash
gem install iterm2_ruby
```

Then in iTerm2: **Settings → General → Magic → Enable Python API**.

**2. Install the gem:**

```bash
gem install stream_weaver
```

**3. Run the door command:**

```bash
streamweaver get-started
```

You'll see a dependency checklist (✅/❌ per item), then, if everything's green, `=== Opening
premier experience ===` followed by a brand new iTerm2 tab: your agent CLI on the left, the
StreamWeaver University canvas on the right. If iTerm2 isn't set up, it falls back to a plain
browser tab instead (same course, just not split-pane) -- pass `--degraded` to skip straight to
that.

**You're done when** the Getting Started panel shows "Start with step 1." -- click "Run step 1" and
watch it type the first prompt into the agent pane for you.

## Non-developer version

> The gist link below is a placeholder -- replace it with the real one before sending.

> Here's a doc StreamWeaver generated, viewable two ways:

| Version | Link |
|---|---|
| Plain (works everywhere, no install) | `<GIST LINK — replace before sending>` |
| Rendered (sidebar nav, callouts, tables, live diagrams) | Same gist link, after installing the [StreamWeaver Doc Viewer extension](https://chromewebstore.google.com/detail/streamweaver-doc-viewer/odjjednfpfiagefgpcfdlelldphmpcgj) |

The gist link already renders as readable text without the extension -- the extension just makes it
look exactly like it did in the original canvas: sidebar navigation, callouts, cards, tables, and
live Mermaid diagrams, all in the browser, no install beyond the one-click extension. The extension
is Chrome/Chromium only -- other browsers just see the plain org text, which is still readable.
