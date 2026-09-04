# Send this to a coworker

The pitch, verbatim:

```bash
gem install stream_weaver
streamweaver install
streamweaver get-started
```

3 steps to awesome. Full experience is macOS + iTerm2; anywhere else, `get-started`
falls back to a browser tab automatically -- same course, no surprises.

Two versions below, depending on who's getting it. Pick one and paste it as-is.

## Developer version

> StreamWeaver is a Ruby DSL for building interactive UIs with almost no code, and it comes with a
> five-step "Getting Started" course that teaches it by actually running it next to your terminal.
> The full experience puts the course in an iTerm2 window of its own and your agent in a fresh tab
> beside your work -- set iTerm2 up first, then install the gem and run the door command.

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
premier experience ===` followed by two things: a new iTerm2 tab in your current window running
your agent CLI, and the StreamWeaver University canvas in a window of its own. The canvas is the
control panel -- you drive the course from there; the agent tab stays clear for the agent (and for
the demo canvas panes it opens as you work through the steps). If iTerm2 isn't set up, the canvas
falls back to a plain browser tab instead (same course) -- pass `--degraded` to skip straight to
that.

**You're done when** the Getting Started panel shows "Start with step 1." -- click "Run step 1" and
watch it type the first prompt into the agent tab for you.

Your progress persists to disk as you go, so you can close everything and come back later -- even
after a reboot -- and `get-started` picks up exactly where you left off. Want to start over? Click
the quiet "Reset course" link at the bottom of the list (or run `streamweaver university-reset`).

If your agent CLI has browser control -- claude-in-chrome, playwright-cli, or gstack's `/browse`
skill -- the worker session moves faster, but it's optional: every course step verifies what it did
with `curl` first, so none of this blocks you from finishing the course without it.

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
