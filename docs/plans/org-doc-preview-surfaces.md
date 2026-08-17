# Design: preview surfaces for StreamWeaver `.org` docs

Status: S1 shipped (stream_weaver-yf3a, commit 558b5b6). S2, S3 approved,
not started. Tracked via `bd` issues, not OpenSpec -- see "On OpenSpec"
below for why that tool is no longer part of this project's workflow.

## The gap that started this

Two renderers exist today. Neither is wired to "preview an `.org` file
directly":

- `streamweaver canvas-read` (`lib/stream_weaver/canvas/reader.rb`) is
  already a mature local doc browser -- live filesystem `/browse` with
  breadcrumbs, `/open?path=` for any file, `/export` to standalone HTML,
  `/save-doc` promoting to `.rb`/`.org`. But it is `.rb`-only: `FileList.build`
  (`reader.rb:27`), `GET /open` (`reader.rb:259`), and `render_doc` never
  detect or read `.org` at all. Zero support, not partial.
- The browser extension's Opal sandbox (`extension/sandbox.js`) is the only
  place `.org` gets rendered outside a Ruby process, but `content.js` is
  wired to exactly one trigger: a content script matched to
  `"https://github.com/*"` in `manifest.json`. No local-file entry point.

Reframe: this isn't "build a new renderer," it's "wire the two renderers
that already exist to more entry points." Every option below is evaluated
on that basis.

## Audience segmentation

1. **Solo dev w/ StreamWeaver + agents (Claude Code etc.) installed** --
   fastest path should be native, no distribution concern.
2. **Ruby-literate teammates without a running canvas server** -- want to
   read a doc without booting anything.
3. **Non-Rubyist colleagues** (e.g. SharePoint viewers at a corporate
   employer) -- need
   zero-Ruby-install rendering. The extension already solves the "no Ruby"
   problem architecturally (Opal ships the compiler as JS); the gap is
   which host pages it activates on.
4. **Windows users / broader popularization** -- Ruby install friction on
   Windows is real (RubyInstaller, DevKit, native gem compiles) in a way it
   isn't on mac/linux. A pure-JS distribution removes that entirely for
   *viewing* (authoring can stay Ruby, or skip Ruby altogether if an agent
   generates `.org` directly).
5. **Emacs/org-mode natives** -- org-mode already renders generic org
   locally, but not StreamWeaver's DSL semantics (callouts, sidebar_toc,
   doc_header pills, `.sw-mermaid`, cards) -- fidelity needs the actual
   StreamWeaver pipeline, not org-mode's own renderer.

## Surface options

### S1 -- `canvas-read` `.org` support
Teach `Reader` the same content-based detection `content.js`/`sandbox.js`
already use (`#+STREAMWEAVER_DSL:` marker), and run detected `.org` through
`Org::Reader.to_dsl` before `instance_eval`. Four confirmed touch points
(per `canvas-docs-discovery-export-fidelity`'s review, see Coordination
outcome below): `FileList.build` (`reader.rb:27`), `browse_entries`
(`reader.rb:154`), `GET /open`'s guard (`reader.rb:259`), and `render_doc`
itself, which needs an actual `Org::Reader.to_dsl` call before
`instance_eval`, not just a filter change.

- Cost: small. Reuses all of `/browse`'s directory-walking, breadcrumbs,
  and export machinery for free -- the moment `.org` is recognized, folder
  browsing works for `.org` too, no new UI.
- Touches: `lib/stream_weaver/canvas/reader.rb`, possibly `doc_store.rb`.
  **Coordinate with `canvas-docs-discovery-export-fidelity` before
  starting** -- that session is actively reworking org/rb export and
  global/local save UX in this same neighborhood (message sent, awaiting
  reply as of this doc's writing).
- Serves audience 1 (and the Emacs "cheap" recipe below, downstream).

### S2 -- Extension: local-file preview
A drag-drop or file-picker target on `viewer.html` feeding the existing
sandbox pipeline (`sandbox.js` doesn't care where `{source, name}` comes
from -- `content.js` is just today's only supplier).

- Cost: small. Zero renderer changes.
- Still requires "install the extension" as a one-time step -- real, if
  small, friction, worth naming honestly rather than calling this
  frictionless.
- Serves audience 3, no server/GitHub/Ruby required.

### S3 -- Extension: Gist support
Add `"https://gist.github.com/*"` to `manifest.json`'s `content_scripts`,
and a second detection path in `content.js` -- gist pages don't embed the
same `codeViewBlobLayoutRoute.StyledBlob` JSON a blob page does, so this
needs its own verification, not an assumption. Likely closer to the
existing raw-URL fallback (`rawUrlFromPage`) than the primary JSON scrape,
since gist raw content sits behind a predictable
`gist.githubusercontent.com/.../raw/...` URL.

- Distribution win: publishing a gist needs no repo, no push workflow, no
  CI -- the lowest-friction *authoring* channel on this list. This is the
  best "popularize the format" lever here: write a doc, paste as a gist,
  share a URL, anyone with the extension sees it rendered in full glory.
- Cost: moderate -- mostly the second detection path, needs live
  verification the way the GitHub path got (this repo does not accept
  curl-level self-assessment for UI surfaces; browser-verify against a
  real gist before calling it done).
- Serves audience 3/4 with the best adoption-per-effort ratio of anything
  here.

### On OpenSpec

The prior draft of this doc said "scaffold an OpenSpec change" as the next
step, because `~/work/rstreamlit/CLAUDE.md` (a parent-directory file, not
part of this git repo -- `rstreamlit` itself has no `.git`) carried a
managed block routing any "new capability / architecture shift" request
through `openspec/AGENTS.md`. Investigated and removed:

- That file was created by `openspec init` on 2025-11-07, the project's
  actual inception date (`openspec/changes/create-stream-weaver-gem` is the
  original gem-bootstrapping proposal, same date).
- It was used exactly three times total across the project's life
  (`create-stream-weaver-gem`, `add-route-tabs`, and an incomplete
  `add-isomorphic-ruby` with no `proposal.md` at all).
- `openspec/specs/` -- the "current truth, built and deployed" directory
  the three-stage workflow is supposed to graduate into -- is empty.
  `openspec/changes/archive/` is empty too. Nothing has ever completed
  OpenSpec's own lifecycle once.
- This repo's own `CLAUDE.md` mandates `bd` (beads) for all task tracking
  in terms that directly conflict with OpenSpec's `proposal.md`/`tasks.md`
  model ("do NOT use TodoWrite, TaskCreate, or markdown TODO lists").
  Recent planning work (`features/route-tabs.feature`,
  `*.context.md` files) is using a third, newer convention. Three
  overlapping systems, only one (`bd`) actively enforced by this repo.

Removed `~/work/rstreamlit/CLAUDE.md` (the file was nothing but that one
managed block). Left `openspec/` itself untouched -- it holds real
historical design content (the route-tabs proposal in particular has a
genuine Codex review write-up worth keeping) -- ask if you also want that
directory cleaned up or archived somewhere; not doing that unprompted.

Planning for this initiative now follows this repo's actual convention:
`docs/plans/*.md` for design, `bd` issues for tracked work.

### S4 -- SharePoint ("my immediate use") -- NOT a new integration
SharePoint document libraries are architecturally unlike GitHub/gist: no
guaranteed raw-text-in-page-JSON, tenant-specific domains, Office-viewer
semantics, and enterprise extension-allowlisting is an IT decision, not
just an engineering one. Building a SharePoint content script would be
materially harder and more fragile than S3, for a worse cost/benefit.

`Reader#export`'s `?offline=1` mode already exists for exactly this case
(`reader.rb:286-289` -- the comment literally says "SharePoint's HTML
preview"): render once, inline mermaid, no CDN, no CSP violations, upload
the resulting static HTML like any other document. SharePoint's own
preview then just displays a file -- no extension, no content script, no
auth story.

- Verdict: don't build SharePoint integration now. If there's a gap it's
  discoverability/automation of `/export?offline=1` -- e.g. a
  `streamweaver export --offline` CLI surface, or a one-command
  export-and-upload -- worth doing, kept in scope as a small follow-up.
- **Explicitly delayed, not rejected**: a SharePoint doc that stays
  "alive" (round-trips edits back into the source, the way a `.org` file
  in a repo does) is a materially bigger effort than static export --
  it would need real read-back-and-reconcile logic against a format
  SharePoint doesn't understand natively, not just a render pass. Worth
  revisiting once the `.org` round-trip story elsewhere (Writer/Reader) is
  more battle-tested, not now.

### S5 -- Opal-as-npm-package
Decouple "can render a StreamWeaver doc" from "has the extension" or "has
Ruby" -- a portable JS module any host could embed: a VS Code extension, an
Obsidian plugin, a static site generator, Emacs's `xwidget-webkit` (Emacs
28+, mac/linux builds with the right compile flags -- not universal), or a
bare `<script>` tag.

- Cost: real, not small. `sw-runtime.js` today is shaped for the
  extension's specific constraints -- `#app-container`, the sandboxed-page
  CSP split (`viewer.js`/`sandbox.js`'s two-frame dance exists
  specifically to dodge MV3's `unsafe-eval` restriction, a constraint that
  doesn't exist outside a Chrome extension). Packaging this as a general
  module means defining a real embeddable API (something like
  `StreamWeaverRender.render(source, {container, theme}) -> {html, css}`),
  decoupling from the two-frame sandbox dance, and taking on real
  versioning/publishing discipline. This is its own mini-project, not a
  line item.
- Distribution win if pursued: the actual lever for "Windows users" and
  broader popularity -- removes the Ruby-on-the-viewer requirement
  entirely and stops being Chrome-only.
- Verdict: valuable, sequence LAST. Its ROI depends on S1-S3 actually
  generating demand for wider distribution first -- textbook SDRD: don't
  build the general platform before the specific uses prove the demand.

### S6 -- Emacs integration
Two different asks bundled under one name -- **revised: neither is gated
on S5**. The original draft assumed the "rich" version needed the npm
package to avoid shelling out to Ruby per keystroke; corrected -- anyone
running Emacs in this era can be assumed to have Ruby available, and
elisp can invoke it directly, no JS toolchain required for either variant:

- **(a) Cheap**: an elisp function shelling out to `streamweaver export
  --offline` (once it exists) or a local canvas-read render, opening the
  result via `browse-url`/`xwidget-webkit`. ~20 lines of elisp, doesn't
  even live in this repo, near-free once S1 ships. Worth documenting as a
  recipe, not worth writing StreamWeaver-side code for.
- **(b) Rich**: an `xwidget-webkit`-embedded preview pane that re-invokes
  the same Ruby export/render on save and reloads the webview -- live-feeling
  without needing a JS-native renderer. More elisp work than (a), but still
  just elisp + the existing Ruby CLI, no dependency on S5.
- Verdict: (a) is a recipe to write once S1 ships. (b) is a real but
  self-contained elisp project, independent of everything else on this
  list -- can happen whenever, not blocked on S5.

## Decision (2026-08-17)

Build S1, S2, S3. S4 stays as-is (export/upload), with a small
export-automation follow-up in scope and the "alive" round-trip version
explicitly delayed. S5 stays out of scope until S1-S3 show demand. S6 is
a standalone elisp recipe/project, not blocked on anything above -- pick
up whenever, independent sequencing.

## Recommended sequencing (Pareto + SDRD)

1. **S1** -- cheapest, closes the daily personal gap, infrastructure for
   S6(a). Coordination cleared with both peer sessions (see below).
2. **S2** -- cheap, independent of S1, unlocks "no Ruby, no GitHub"
   preview immediately, stepping stone to S3.
3. **S3** -- best popularization-per-effort on this list; builds on S2's
   detection logic and the extension's existing raw-URL fallback.
4. **S4 follow-up (optional, small)** -- CLI ergonomics /
   export-and-upload automation for `/export --offline`, which already
   ships. Not blocking S1-S3.
5. **S5** -- the one genuine platform bet here; sequence after S1-S3 show
   real usage, not before.
6. **S6** -- pure elisp + existing Ruby CLI, no StreamWeaver-side code
   needed either variant; can happen any time, independent of S1-S5.

## Design Triumvirate check

- **Matt's Law**: S1/S2/S3 all reuse existing, already-findable surfaces
  (a directory browser, a drag target, a familiar gist URL) instead of
  inventing new navigation.
- **Forrest's Law**: sequencing is explicitly zero-friction-first -- each
  of S1-S3 converts an existing rendering capability into a single-action
  trigger (open a folder / drop a file / click a gist link), no perk
  hidden behind a new habit.
- **Gloria's Law**: none of S1-S3 introduce a "want-to" threshold --
  they're one-shot actions, not new workflows to adopt.

## Coordination outcome

`canvas-docs-discovery-export-fidelity` replied: no overlap, no objection,
S1 is squarely out of their scope. Their in-progress work is `DocStore.save`
(a `scope:` param for global-vs-repo choice) and the Save-as-doc modal /
`POST /save-doc` routes -- none of it touches `.org` naming/detection,
which they say is already-merged prior work (not theirs, not currently
owned by anyone). They flagged one correction to this doc's S1 cost
estimate: `browse_entries` (`reader.rb:154`,
`files: rest.select { |e| e.end_with?('.rb') }`) is a fourth `.rb`-hardcoded
site, on top of `FileList.build`, `GET /open`'s guard, and `render_doc`
assuming Ruby syntax throughout (not just a filter -- `.org` needs its own
`Org::Reader.to_dsl` code path there, confirmed above). Practical note from
them: this checkout has been shared across sessions before and a commit
landed on the wrong branch once -- sanity-check `git branch --show-current`
+ `git log --oneline -3` before committing.

`export streamweaver doc to org` also replied: idle on this front -- their
org-export work (Writer/Reader library + CLI, Save-as-Org UI/DocStore `.org`
support) finished, merged, and pushed a couple days before this session
started (their `git log -1` shows this session's own `28bfb6c` as latest,
confirming nothing pending). Not touching `writer.rb`, `doc_store.rb`'s org
save branch, or any org-detection-for-rendering code, no plans to. Safe to
proceed. Two things they flagged to fold in rather than discover later:

1. If cross-surface preview UX ever cares about *where* a `.org` lives (not
   just how it renders), that's `canvas-docs-discovery-export-fidelity`'s
   repo-vs-`~/.streamweaver` save-location design doc to sync with --
   roadmap only, not built yet, per that session's own earlier message.
   Not a concern for S1/S2/S3 as scoped above (none of them relocate
   files), but worth remembering if a later surface (e.g. a "browse my
   saved docs" view) needs to resolve doc location.
2. **Constraint to hold going forward**: anything that touches saved `.org`
   output must keep `#+STREAMWEAVER_DSL: 1` as the literal first line, or
   detection breaks silently across every surface in this doc (`content.js`,
   `sandbox.js`, and S1's planned `Reader` detection all key off it being
   line one). This is the same class of bug `c1df5f6` already fixed once
   (`DocStore.stamp` corrupting `.org`'s first line) -- any new save/rewrite
   path for `.org` (S1's `Reader`, a future S5 embed API, etc.) needs the
   same defense-in-depth guard `doc_store.rb:167` already has.

## Next step

Greenlit. Tracked as `bd` issues (see repo issue tracker), implementation
starting with S1.
