# The co-edit loop: a document that grows from a form

A person fills in a small form under a document. The agent does the work the answer asks for, adds the result to the document, and the page re-renders. Repeat until the person says done. This is how StreamWeaver University's step 4 demonstrates "co-editing a document with an agent, in a pane, with no file open on either side", and it is the closest thing in the codebase to point-and-comment feedback on a document.

It is also easy to build wrong. Every rule below came from a failure in a real run of the course.

## What it looks like

```bash
streamweaver panel doc-demo --theme=doc                       # open the pane
ruby "$(streamweaver university-demo doc)" doc-demo --picker  # doc + the picker form, not saved
streamweaver canvas-wait doc-demo                             # agent blocks (in the BACKGROUND)
```

The picker is a radio group of canned section keys (`timeline`, `tradeoffs`, `cheatsheet`, `architecture`, `done`), a free-text box ("describe a section in your own words") and an "Add it" button. When the person submits:

| They chose | The agent does |
|---|---|
| A canned key | Re-runs the script with `--extend=<key>` |
| Free text | Writes the new section as DSL to a file, then runs `--add-custom <key> <file>` |
| `done` | Runs `--finish` (re-push the finished doc without the form, and save) |

A survey fits the same shape. As the maintainer recalls it, the demo that made the pattern concrete was a survey ("what is the best order to watch the Star Wars films") whose submit made the agent do the work and add the result to the document. A code comment in `growing_doc.rb` confirms a Star Wars chart section was a custom section in a live run. The survey is just a section; the loop is the product.

## The moving parts

Source: `lib/stream_weaver/university/scripts/growing_doc.rb` and `growing_doc_state.rb`.

1. **The document is a list of DSL sections**, concatenated: a base (six staged sections), then every persisted `--extend` key, then every persisted custom section. A `sidebar_toc` is rebuilt from the sections present, so the outline never links to an anchor that has not been pushed.
2. **State is per canvas session.** `GrowingDocState` persists the extend keys and custom sections, so any later invocation rebuilds everything applied so far.
3. **Every push carries the whole document**, not a patch. The page grows because each push is a superset of the last, and the final push is a complete, saveable file.
4. **The form is appended below the document and never saved.** `--picker` and saving are mutually exclusive, so no control lands in the file that gets exported.
5. **The agent waits in `canvas-wait`.** That is channel 1 in `docs/canvas-agent-channels.md`. The loop is a series of single questions, so it fits; a form the person answers over hours would want a standing channel instead.

## Rules that cost a UAT round each

| Rule | The failure behind it |
|---|---|
| The radio value is the `--extend` key, verbatim | Choices used to be human labels. The agent had to parse a key out of a label, got it wrong, and the script printed "Saved" for a pick that never landed. |
| Unknown keys fail loudly, exit non-zero, and the save line says so | The old path warned on stderr and then printed an unqualified "Saved: path". |
| Persist state per session, and make `--extend` only ever add | A re-run without `--extend` rebuilt the base and clobbered earlier picks. |
| A bare re-run means "start over"; `--finish` never does | Without the carve-out, a plain Repeat inherited the previous round's picks and skipped the growing animation. |
| Persist custom (free-text) sections the same way as canned ones | A person's own Star Wars chart section had nowhere to live and was wiped by the next picker round. |
| Validate a custom snippet as Ruby before persisting it (`Ripper.sexp`) | Persisted state is replayed on every rebuild. One syntax error would break every later round with no undo short of `--reset`, which throws away the good picks too. |
| `--finish` re-pushes the finished document | After "done", nothing re-pushed, so the pane kept showing the canvas-wait adapter's own "Submitted" screen instead of the document. |
| Every canned section's header begins with its key | The person picked "cheatsheet" and could not find a matching header, because the rendered title never named the key. |
| Print one OK line naming the exact rendered header | Makes "which section did my pick add" a grep, not a guess. |

## Keep the document portable

The document is meant to leave the live canvas as a saved `.rb`, an exported `.org`, or a gist. Outside the live canvas, controls grey out and do nothing, and some components are dropped. So:

- No buttons in the document body. The picker is the one exception and is never saved.
- Only components `streamweaver org-export` recognizes: `doc_section_header`, `md`, `comparison`, `code_block`, `callout`, `mermaid`, and `table` in the `headers:`/`rows:` form (an array of hashes renders identically and then exports as an unrecognized block).
- No chart shorthands; `streamweaver export` drops Chart.js for those.
- Flat, one statement per component. The org writer recovers verbatim source by that 1:1 correspondence.

## Why this matters beyond the course

The loop already has the shape of annotation feedback: a person indicates something about a document, an agent changes the document's source, and the page regenerates. What it lacks is the front end. Today the person chooses from a form below the document; they cannot point at a paragraph and say "this part". The anchors would come from the components themselves, since StreamWeaver renders every component and could stamp each with an identity.

See `docs/canvas-agent-channels.md` for how such a click would travel to an agent.

## What was lost, and where to look

The Star Wars section from the original live run was not saved: it is not in the saved `university-doc.rb`, and no persisted picker state remains for the course. The transcripts of the sessions that built and ran the course (early September 2026) are in the Claude Code conversation archive and show the full exchange. If you need the exact survey wording, search that archive for "star wars" with the stream_weaver project filter.

## To try it

```bash
streamweaver get-started        # sets up and opens the course; step 4 runs this loop
```

Or run the three commands at the top of this page directly. `STREAMWEAVER_GROWING_DOC_PAUSE=0` removes the pause between the six staged pushes. `--reset` clears the persisted picks for a session.
