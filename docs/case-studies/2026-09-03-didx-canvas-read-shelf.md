# Case study: the Org + canvas-read document shelf (DiDX proposal session)

Date: 2026-09-03. Environment: **Codex (ChatGPT desktop app) on macOS** — notably *not* the
designed-for environment (Claude Code + iTerm2). The workflow held up anyway, which is the
headline: the Org-source + canvas-read loop is agent-agnostic.

**The winning loop:**

```text
Discuss → save a small Org document → reload canvas-read → compare versions → revise → export when ready
```

> Agent-friendly source, human-friendly reading, version-friendly files, and very low
> friction between writing and reviewing.

Three proposal documents (a neutral showcase, a personal version with several rounds of copy
revision, and a technical starter) lived as 12-16KB Org files sharing one image directory,
read side-by-side in canvas-read's shelf (left rail, per-doc TOC, Previous/Next). Preserving
alternative versions felt cheap rather than burdensome — that is the feature.

What follows is the session's own context write-up, verbatim.

---

## What happened

In one Codex session, we developed a visual DiDX proposal through several rounds of discussion.

Codex created and saved three StreamWeaver Org documents:

1. `didx_whats_possible.org` — a neutral visual showcase.
2. `didx_let_me_expand_the_picture.org` — a more personal version written from me to the recipient, with several rounds of copy revision.
3. `didx_blueprint_theme_model_starter.org` — a local implementation starter for the component, blueprint, theme, color scheme, page, and preset hierarchy.

The Org files remained small, around 12 to 16 KB each. The visual weight lived in shared image assets rather than bloated document source.

## Why canvas-read felt so good

`canvas-read` turned the files into a small local document shelf. The left rail showed all three documents. I could:

- Move between versions immediately.
- Compare the neutral and personal versions without opening separate tools.
- Keep the technical starter beside the presentation documents.
- Use the generated table of contents inside each document.
- See images, callouts, tables, diagrams, and polished formatting.
- Reload after an edit and immediately review the result.
- Keep the canonical source as Org while getting a much better reading experience.

The important experience was that these stopped feeling like loose files. They felt like a small, navigable local knowledge collection.

This was especially useful while revising the message. We could preserve the previous version, create another version with a different voice, and compare them from the same shelf.

## Actual command used

The executable was not on `PATH`, so the working command was run from the repository:

```bash
SW_NO_OPEN=1 bundle exec ruby -Ilib exe/streamweaver canvas-read \
  /path/to/didx_whats_possible.org \
  /path/to/didx_let_me_expand_the_picture.org \
  /path/to/didx_blueprint_theme_model_starter.org \
  --theme=doc
```

`canvas-read` selected an available port and printed the URL:

```text
canvas-read 3 file(s) → http://127.0.0.1:4800/?file=0
```

Earlier runs used port 4801. Documentation should explicitly say not to assume a fixed port.

Passing the files explicitly produced the controlled comparison shelf we wanted.

## Org format used

Each source begins with:

```org
#+STREAMWEAVER_DSL: 1
#+TITLE: Document Title
```

Numbered headings with `CUSTOM_ID` properties become document sections and generate the sidebar table of contents. Normal prose, lists, tables, quotes, and source blocks remain readable as Org.

Components not represented natively in the Org dialect can use the existing passthrough:

```org
#+begin_src ruby :streamweaver-raw t
image_block File.join(__dir__, "assets/example.png"), base64: true,
  alt: "Description"
#+end_src
```

This let the document remain primarily Org while still using StreamWeaver image components and limited custom styling.

## Images and shared assets

The documents referenced one shared image directory; generated images were not duplicated per document. `image_block` with `base64: true` made the images work in `canvas-read`, where ordinary relative image paths do not have a backing asset route.

```text
Small Org source + shared high-quality images = rich canvas-read document
```

## Standalone delivery

We also produced standalone HTML and an email-ready ZIP (~11 MB):

```text
Proposal/
├── Proposal.html
└── images/ (11 PNG files)
```

Recipient instructions: unzip, keep the HTML and `images` together, double-click the HTML.

## Important export gap

`canvas-read` handled the StreamWeaver Org files correctly. The normal `streamweaver export file.org` command did not — it attempted to evaluate the raw Org text as Ruby and failed. The session worked around it by reading the Org, converting through `StreamWeaver::Org::Reader.to_dsl`, evaluating in a `StreamWeaver::App`, and passing that to `StreamWeaver::Export::HtmlExporter`. This is a current gap; a first-class Org export path would remove the custom step.

## Another known gap: links between documents

Same-document Org anchors work. Native relative links from one Org document to another are not rewritten into `canvas-read` navigation URLs. The shelf made cross-document links unnecessary here, but a connected corpus will eventually want that. MarkyMark has prior art: it rewrites relative Markdown/Org links into internal reader routes preserving fragments and searches.

## What was actually tested

Directly tested: macOS; Codex Desktop and its in-app browser; local StreamWeaver source; Ruby and Bundler already installed; canvas-read with explicit Org file arguments; the `:doc` theme; multiple documents in one shelf; desktop and phone-width rendering; Org-to-DSL conversion; shared image assets; standalone HTML generation; ZIP packaging with relative images.

Not tested: Linux; WSL; native Windows Ruby; browsers outside the Codex in-app browser for canvas-read; a packaged StreamWeaver executable; a clean machine without the development repository; `streamweaver panel` without iTerm.

## Platform boundaries to document clearly

`streamweaver panel` is the iTerm-specific convenience path — macOS + iTerm functionality. `canvas-read` is a local web server and far less platform-specific; the degraded path is: start without auto-open, print the URL, open it in any browser. That should be viable on macOS without iTerm, Linux, WSL, and possibly Windows, subject to Ruby/browser-launch testing. The Chrome plugin and `gh` CLI are workflow enhancers, not requirements for reading a local shelf.

Documentation should distinguish: tested and supported / expected to work but not tested / known degraded path / future platform support.

## Suggested degraded demo

```bash
SW_NO_OPEN=1 streamweaver canvas-read docs/
```

Expected: URL printed; user opens it; shelf lists Org and Ruby documents; navigation, TOC, images, diagrams, reading mode all work; no iTerm required. Test independently on macOS-plain-terminal, Linux, WSL, Windows.

## Suggested documentation structure

1. What canvas-read is. 2. The tested macOS happy path. 3. Saving or authoring StreamWeaver Org documents. 4. Opening one document. 5. Opening a shelf. 6. Comparing versions with the left rail and Previous/Next. 7. Working with images. 8. Exporting or packaging. 9. Platform support matrix. 10. No-iTerm degraded path. 11. Known gaps. 12. This case study.
