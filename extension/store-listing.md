# Chrome Web Store listing draft — StreamWeaver Doc Viewer

Draft only. Review and edit before pasting into the dev console — nothing here has
been submitted. Sourced from `extension/manifest.json` and `extension/README.md`'s
"Known gaps" section as of this writing; re-check both if either changes before
submission.

## Short description (132 char limit)

```
Renders StreamWeaver docs on GitHub and Gist as formatted pages instead of raw Ruby/org source, rendered locally in your browser.
```

129 characters.

## Detailed description

```
StreamWeaver Doc Viewer renders StreamWeaver documents on GitHub and GitHub
Gist the way they look when actually run, instead of as raw Ruby or .org
source — for anyone reading a doc who doesn't have StreamWeaver or Ruby
installed.

A StreamWeaver doc is a small Ruby DSL (or its round-trippable .org export)
that compiles into a formatted page: headers, a sidebar table of contents,
callouts, tables, code blocks with syntax highlighting, comparison blocks,
cards, and Mermaid diagrams. Viewed on GitHub without this extension, that's
just source text. This extension detects a StreamWeaver doc automatically
(by a content stamp, not filename) and adds a "View rendered" button next to
the file — click it to see the formatted page in a new tab.

Works on:
- Any public or private GitHub repo blob page (.rb or .org)
- GitHub Gists, including multi-file gists
- Local files too — open the extension's viewer page directly and drop in
  a .org or .rb file from disk, no GitHub or server needed

How it works: everything renders entirely inside your browser. The
extension reads the file's source from the GitHub page itself (or fetches
the file's own Raw URL for Gists), compiles it locally using a bundled Ruby
compiler and rendering runtime, and displays the result in a sandboxed
extension page. No document content is ever sent anywhere — there is no
backend server for this extension, and it makes no network requests beyond
fetching the Raw source URL when required (see Privacy practices below for
exactly when that happens).

This is a personal utility made public, not a polished commercial product.
It works well on everything it's been tested against, but a few things are
worth knowing before you rely on it: the "View rendered" button's placement
is a best-effort guess at GitHub's current page markup and may need to adapt
if GitHub changes it, and a few edge cases (anonymous gists, private gists,
drag-and-drop file entry) are inferred from code review rather than
independently verified live. See the project README's "Known gaps" section
for the full list.

Source: [add repo URL before publishing, if the repo is public by then]
```

## Category

**Developer Tools.** Confirmed as the right fit — this is a tool for reading
developer-authored documentation on GitHub/Gist, not a general productivity or
"docs" viewer for end users; it only activates on `github.com` and
`gist.github.com` and only for a specific developer-facing content format.

## Privacy practices justification

Permissions actually declared in `manifest.json` (re-read fresh for this draft,
not from memory):

```json
"permissions": ["storage"],
"host_permissions": [
  "https://raw.githubusercontent.com/*",
  "https://gist.githubusercontent.com/*"
]
```

### `storage` (specifically `chrome.storage.session`)

**What it's for:** Passing a doc's source text from the GitHub/Gist content
script (`content.js`) to the extension's own viewer tab (`viewer.html`) and
sandboxed render frame (`sandbox.html`). When the "View rendered" button is
clicked, the file's source text is stashed under a one-time key in
`chrome.storage.session`; the viewer tab reads that key once and the entry is
meant to be single-use per render.

**Why session storage, not local/sync:** The content only needs to survive the
handoff between the GitHub tab and the new viewer tab — it does not need to
persist across browser restarts (`local`) or sync across devices (`sync`).
`chrome.storage.session` is the narrowest storage API that fits: in-memory
only, cleared when the browser session ends, never leaves the device.

**What is NOT stored:** No browsing history, no credentials, no analytics, no
user identifiers. The only data that ever touches `chrome.storage.session` is
the text content of the specific StreamWeaver doc file the user chose to
render — data already visible to the user on the GitHub/Gist page they were
looking at.

### `host_permissions`: `https://raw.githubusercontent.com/*`

**What it's for:** Fallback fetch path when a doc's full source isn't already
present in the current page's DOM. A GitHub blob page normally embeds the
whole file in an inline JSON payload the content script reads directly (no
network request at all in that case); this host permission exists for cases
where that embedded payload isn't available and the content script fetches
the file's own Raw URL instead.

**Scope:** Only ever fetches the specific file's own raw URL — the exact file
the user is already viewing or clicked to render. Never a directory listing,
never another file, never a request the user didn't implicitly trigger by
opening or clicking on that specific file.

### `host_permissions`: `https://gist.githubusercontent.com/*`

**What it's for:** GitHub Gist pages don't embed file content in the page DOM
at all (confirmed by inspecting real gist pages — see the "Gist support"
section of the project README) — a gist page's scripts carry only UI chrome,
never file content, and a rendered `.org` file's raw text isn't in the DOM
either. So gist support always fetches the file's Raw link
(`gist.github.com/.../raw/...`, which redirects to
`gist.githubusercontent.com/.../raw/...`) rather than scraping the page.

**Scope:** Same as the `raw.githubusercontent.com` case — only the specific
gist file whose "View rendered" button the user clicked, one fetch per file,
never a bulk or background fetch.

### What this extension does NOT do

- No remote script execution of any kind — Manifest V3 forbids it outright,
  and the extension bundles its Ruby compiler and rendering runtime (Opal +
  the StreamWeaver runtime + Mermaid + Prism + marked + morphdom) locally
  rather than loading any of it from a CDN.
- No analytics, telemetry, or tracking of any kind.
- No data leaves the browser except the two narrowly-scoped raw-content
  fetches described above, both triggered directly by a user action (opening
  a GitHub/gist page, clicking "View rendered").
- No access to any site other than `github.com`, `gist.github.com`, and the
  two raw-content hosts above — `content_scripts.matches` and
  `host_permissions` are both scoped exactly that tightly, nothing broader
  like `<all_urls>`.

## Screenshots (~1280x800)

Both captured live against the actual built 1.0.0 extension, genuinely loaded
in Chromium (`browse --headed` with `BROWSE_EXTENSIONS_DIR`), not staged —
see `extension/dist/screenshots/`:

1. **`screenshot-1-rendered-doc.png`** — a real rendered StreamWeaver doc (the
   `.rb` incident-report demo from `github.com/fkchang/streamweaver-doc-demo`):
   doc_header, sidebar table of contents, callouts, and body content, shown
   inside the extension's viewer page.
2. **`screenshot-2-button-in-context.png`** — the "View rendered" button
   mounted in a real GitHub file toolbar (the same repo's `demo.rb` blob
   page), next to GitHub's own Raw control. Replaced post-review: the
   original capture at this path was framed too wide to actually show the
   button (a real gap caught by re-checking live, not by re-reading the
   code — the button is small enough that a full-page shot at normal zoom
   makes it easy to miss even though it's genuinely there). This one is a
   tight crop (450x80) confirmed to show the button text clearly, at the
   cost of losing most of the surrounding page context.

Neither is at the store's ~1280x800 target: screenshot 1 was captured at
1200x948 (a headed-mode display cap in the verification environment, not a
deliberate choice), and screenshot 2 is a deliberately tight 450x80 crop
traded off against actually showing the button. Both need a proper
recapture at the exact console-preferred dimensions before upload — treat
this pair as "proves the feature and the copy are real," not "ready to
paste into the console."

## Known gaps worth flagging before submission

Pulled from `extension/README.md`'s "Known gaps" section — not exhaustive,
but the ones most relevant to what reviewers or early users might hit:

- No committed automated test for the extension itself; everything under
  "Verified" in the README was checked manually.
- Toolbar anchor is a best-effort guess at GitHub's current markup and may
  need updates if GitHub reshuffles it.
- Private repos work through the embedded-JSON path (page already
  authenticated); the `raw.githubusercontent.com` fallback would need a
  token and does not currently have one.
- Bundle is ~7MB unpacked (~1.6MB zipped), mostly Mermaid (3.5MB) and the
  compiler + runtime (3.7MB) — local-disk only, never downloaded per page
  view, but worth knowing if the console flags bundle size.
- Anonymous gists and private gists were not tested live (inferred from code
  review, not observed).
- Local-file drag-and-drop wasn't independently exercised (only the file
  picker was) — low risk, both call the same code path.
