# canvas-read: the document shelf

The most portable way to read a StreamWeaver doc. No iTerm2, no Chrome extension, no
`gh` — just a local web server and a URL.

## What it is

`streamweaver canvas-read` starts a small local web server that renders one or more
StreamWeaver DSL/Org files with full styling: sidebar navigation, a per-doc table of
contents, callouts, cards, tables, live Mermaid diagrams, images. Point it at a file,
a directory, or nothing (it finds your docs automatically) and it prints a URL.

```bash
streamweaver canvas-read notes.org
```

```text
canvas-read  1 file(s)  →  http://127.0.0.1:4800/?file=0
Ctrl-C to stop
```

**Never assume the port.** StreamWeaver auto-finds an available one starting near 4800
and prints the real URL every time — read it from the command's own output.

## The happy path (tested: macOS + iTerm2)

1. Save or author a StreamWeaver doc (`.rb` or `.org` — see below).
2. Run `streamweaver canvas-read <file>`.
3. A browser tab opens automatically at the printed URL (iTerm2 users can instead pop
   it into a split pane — see [canvas-panel-workflow.md](canvas-panel-workflow.md)).
4. Read, navigate the table of contents, click through Mermaid diagrams.
5. Ctrl-C the process when done.

## Authoring Org docs

Org is the portable, human-readable source format. Every StreamWeaver Org doc starts
with:

```org
#+STREAMWEAVER_DSL: 1
#+TITLE: Document Title
```

Numbered headings with `CUSTOM_ID` properties become sections and drive the sidebar
table of contents. Ordinary prose, lists, tables, quotes, and source blocks read as
plain Org. Components with no native Org form (anything outside the recognized set
below) use a passthrough block:

```org
#+begin_src ruby :streamweaver-raw t
image_block File.join(__dir__, "assets/example.png"), base64: true,
  alt: "Description"
#+end_src
```

`.rb` (the DSL source) is the other option — canonical, always lossless, and what
`org-export`/`org-render` convert to and from.

## Opening one document

```bash
streamweaver canvas-read path/to/doc.org
```

Works for both `.rb` and `.org` files.

## Opening a shelf

Pass multiple files, or a directory, and canvas-read turns them into a shelf: every
doc listed in a left rail, one click to switch between them.

```bash
streamweaver canvas-read docs/proposals/
```

With no arguments at all, canvas-read scans your usual docs roots (this repo, if
you're in one, plus `~/.streamweaver`) and builds the shelf from whatever it finds —
handy for a quick `streamweaver canvas-read` with nothing else typed.

## Comparing versions

The left rail lists every document in the shelf; click any entry to switch. Inside a
document, **Previous/Next** buttons step through the shelf in order, and each
document's own generated table of contents lets you jump to a section directly. This
is the pattern from the [DiDX case study](case-studies/2026-09-03-didx-canvas-read-shelf.md):
keep a neutral version, a personal-voice version, and a technical version side by
side, and compare them without leaving the shelf.

## Working with images

Ordinary relative image paths don't have a backing asset route in canvas-read.
Use `image_block` with `base64: true` so the image is embedded directly:

```org
#+begin_src ruby :streamweaver-raw t
image_block File.join(__dir__, "assets/diagram.png"), base64: true, alt: "Architecture"
#+end_src
```

Without `base64: true`, the image won't resolve — this is the one gotcha worth
knowing before you build a doc full of screenshots.

## Exporting or packaging

- `streamweaver export file.rb` writes a saved DSL doc out as standalone HTML
  (`--inline-images` to embed local images, `--offline` to inline the Mermaid
  library for viewers with a strict CSP).
- `.rb` and `.org` docs checked into a GitHub repo or Gist render with full
  StreamWeaver styling via the [browser extension](../extension/README.md) — no
  install, no Ruby, no server required for the reader.

See the known gap below for `streamweaver export` on `.org` files specifically.

## Platform support

canvas-read is the most portable piece of StreamWeaver — see the
[Platform support matrix](../README.md#platform-support) in the README. In short: it's
a plain local web server, so it's expected to work anywhere Ruby and a browser do,
independent of iTerm2, Chrome, or `gh`.

## No-iTerm degraded demo

```bash
SW_NO_OPEN=1 streamweaver canvas-read docs/
```

`SW_NO_OPEN=1` skips the auto-open — the command prints its URL and exits into the
running server; open that URL in any browser yourself. Expect the shelf to list every
Org and Ruby doc under `docs/`, with navigation, table of contents, images, diagrams,
and reading mode all working, no iTerm2 required.

## Known gaps

- **disc-175 — `streamweaver export` doesn't accept `.org` files first-class.**
  `canvas-read` handles Org source directly; `export` still tries to eval the raw Org
  text as Ruby and fails. The workaround (`Org::Reader.to_dsl` → `App` →
  `HtmlExporter`) is documented in the
  [case study](case-studies/2026-09-03-didx-canvas-read-shelf.md#important-export-gap).
- **disc-176 — canvas-read doesn't rewrite cross-document links.** Same-document Org
  anchors work; a relative link from one Org doc to another in the same shelf isn't
  rewritten into a canvas-read navigation URL. The shelf's left rail is the workaround
  today — MarkyMark has prior art for rewriting relative links into reader routes.

## Case study

This guide's structure follows the write-up from a real multi-document session:
[Case study: the Org + canvas-read document shelf (DiDX proposal session)](case-studies/2026-09-03-didx-canvas-read-shelf.md).
