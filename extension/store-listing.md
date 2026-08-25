# Chrome Web Store listing draft — StreamWeaver Doc Viewer

Draft only. Review and edit before pasting into the dev console — nothing here has
been submitted. Sourced from `extension/manifest.json` and `extension/README.md`'s
"Known gaps" section as of this writing; re-check both if either changes before
submission.

## Short description (132 char limit)

The dev console's "Store listing" tab only has a Description field, not a
separate short-description/summary field (confirmed against the live form,
2026-08-25) — this may live elsewhere (a "Distribution"/search-visibility
tab) or not be a thing in this console version. Kept here anyway in case it
turns up.

```
StreamWeaver docs, rendered for real on GitHub & Gist. Sidebar nav, diagrams, zero install, zero lock-in.
```

105 characters.

Chrome Web Store's Description field is plain text — no inline images.
"(see screenshot)" below points at the gallery instead: both callouts are
covered by screenshot 1, the org-vs-extension comparison — see
"Screenshots" further down for the full set.

```
Love those beautiful Claude artifacts, but want them more portable and
less token-hungry? This might be your fix.

StreamWeaver (github.com/fkchang/stream_weaver) is one of the ways to
build docs interactively with an agent like Claude Code or Codex — saved
as either a token-cheap Ruby DSL or a plain .org file, both of which
GitHub already knows how to render. Beyond text and headers, StreamWeaver
docs support callouts, cards, tables, syntax-highlighted code, and Mermaid
diagrams — real structure, not just prose.

Org mode already renders on par with markdown on GitHub (see screenshot).
With this extension, the same file gets the real thing: a floating,
scroll-updating sidebar nav, and interactive Mermaid diagrams you can
zoom, pan, and pop out full-screen (see screenshot).

Works on:
• Any GitHub repo blob page, public or private (.rb or .org)
• GitHub Gists, including multi-file gists
• Local files too — drop one into the viewer straight off disk, no GitHub
  needed

Everything compiles and renders client-side: a bundled Ruby compiler and
runtime, zero backend, zero telemetry. The only network activity is a
narrowly-scoped fetch of the file's own Raw URL when the page doesn't
already embed it — see Privacy practices below for exactly when.

Built vendor-neutral on purpose: StreamWeaver docs are meant to travel —
across repos, across teams, to whoever you're collaborating with, on your
team or off it. All they need is a Chrome-compatible browser and this
extension.
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

## Screenshots (1280x800, required — the console rejects anything else)

Not plain screenshots — composed, captioned graphics built from real capture
material (no staged/mocked UI, every pixel inside each frame is an actual
render) plus text overlays explaining what's shown, since the console gives
no per-image caption field and the Description text can't embed images.
Built via local HTML/CSS + `browse`'s offline render mode (`goto file://`,
`screenshot --selector`), not Codex/generative image tools — this keeps the
StreamWeaver violet (`#4c1d95`, from `extension/icons/icon.svg`) and the
serif headline face consistent with the icon and hero image rather than
introducing a second, AI-imagined visual language. See
`extension/dist/screenshots/`:

1. **`screenshot-1-comparison.png`** — side-by-side: `demo.org` rendering
   natively on GitHub (left) vs. the same doc through the extension (right,
   sidebar nav + full layout visible). Backs both "(see screenshot)" callouts
   in the description in one image. Exactly 1280x800.
2. **`screenshot-2-button.png`** — the "View rendered" button in a real
   GitHub file toolbar, captioned. Exactly 1280x800.
3. **`screenshot-3-mermaid.png`** — the fullscreen Mermaid expand overlay,
   captioned. Exactly 1280x800. This is what today's mermaid-controls fix
   restored.

All three are exact 1280x800, 24-bit PNG, no alpha — verified with
`sips -g pixelWidth -g pixelHeight -g hasAlpha`, not assumed.

## Store icon (128x128, required)

Already built, no need to generate anything new: `extension/icons/icon128.png`
— the same document + woven-thread mark used in `manifest.json`, already
verified to survive 16px shrinking legibly (the whole reason that icon
design won out over other concept drafts). 128x128, no alpha.

## Small promo tile (440x280, optional)

`extension/dist/promo/small-tile-440x280.png` — same violet, same icon, same
serif, name + a short tagline. Appears in Chrome Web Store search/category
browsing, so worth having even though it's optional. Built the same way as
the screenshots (HTML/CSS render, not Codex).

## Marquee promo tile (1400x560, optional)

Not built. Only used if Google editorially features the extension — low
value for a first submission with zero installs and zero reviews. Worth
revisiting once the extension has some real usage; same technique would
extend to it cheaply if wanted later.

## Additional fields

- **Homepage URL:** `https://github.com/fkchang/stream_weaver`
- **Support URL:** `https://github.com/fkchang/stream_weaver/issues`
  (reasonable default; swap for something else if a dedicated support
  channel exists by submission time)
- **Official URL:** leave as "None" unless the repo/site is verified via
  Google Search Console — that verification is a separate, real step, not
  a rubber stamp; don't set this without actually doing it.

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
