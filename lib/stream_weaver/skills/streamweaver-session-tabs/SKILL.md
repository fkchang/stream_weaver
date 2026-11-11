---
name: streamweaver-session-tabs
description: Use when a long or multi-agent session needs a live canvas a person can read instead of scrollback, and proactively once the session has spawned 3+ subagents, has 3+ decisions waiting on the person, or will run long enough that they leave and return cold. Triggers on "session tabs", "session canvas", "tab this session", "keep a living doc", "keep a running blog". Builds a tabbed StreamWeaver canvas (needs-me first, brief second) and optionally a second living-doc canvas.
---

# StreamWeaver Session Tabs

A tabbed canvas that is the session's working memory for the person: they open it cold and know in seconds what needs them, where things stand, and what changed. Read the StreamWeaver canvas guide (`docs/canvas-guide.md` in the gem) for the recipe, listener and skeletons; this skill adds when to activate and how to keep the canvas current.

Skip it for short single-thread sessions. For one long deliverable, use `streamweaver-doc-builder` instead.

## The invariants

1. **Tab 1 is "what needs you."** Open decisions, blocking first, the count in the tab label (`Decide (2 blocking)`, never a raw 23). When nothing is open it says "Nothing needs you" and shows a three-line summary.
2. **Tab 2 is the brief:** goal, what is happening now, what changed since the last push, the next step. One screen, always.
3. **Tabs never reorder.** Change a label or a card, not the order.
4. **Decisions live in tab 1 and nowhere else.** One inbox.

Everything after tab 2 is yours to shape. A good default set:

| Tab | Answers | Bound |
|---|---|---|
| Decide | Does this need me? | Blocking first, "Whenever" divider below |
| Brief | Where are we? | One screen |
| Findings | What would I care about? | Sorted by severity, source linked; acknowledged items collapse |
| Decided | What did we settle? | Append-only: choice, why, when |
| Artifacts | What do I read? | Read (1-2) and Reference (one line each), each status-labelled |
| Trail | How did we get here? | Collapsed to phases |

## The decision card

One card per decision, top to bottom: the question as the title (badge for the id, meta for "blocks X" or "whenever"); **the recommendation first, bold, with a one-line why**; the options as a two-column table with one line of tradeoff each; a badge naming where it came from; the answer control (`radio_group` or chips, plus a button). **A card is complete:** if answering needs another document, paste the excerpt in. Leaving the control alone means accepting the recommendation, and the card says so. Skeleton: guide section 6.

Every named thing (ticket, PR, file, session) is a link with a few words saying what it is.

## Keeping it current

Name the canvas `session-<project>` and open it once. Keep the DSL in a file and edit that file; regenerating from memory loses older tabs. Re-push the whole canvas on exactly these triggers, no more (each push resets the viewer to tab 1):

| Trigger | Update |
|---|---|
| A report or artifact landed | Artifacts, Findings, Trail |
| A decision opened | Decide, Trail |
| A decision resolved | Decide, Decided, Trail |
| A phase changed | Trail, and a fresh "now" in Brief |

Always refresh Brief and lead it with what changed. Answers only arrive while a listener runs (guide section 3); start it BEFORE you push the first decision, and end the page with `canvas_continue`.

## More than one canvas

Keep one canvas per purpose, side by side, each with its own name:

- **`session-<project>`**: the tabs above.
- **`doc-<topic>`** (a living doc): a spec, report or plan that changes as the work does. Build it with `streamweaver-doc-builder`.
- **`blog-<topic>`** (a running post): newest entry on top, each with a date, a one-line headline, what changed and what is next. For a long task this is the digestible update; edit the file and re-push, history keeps every version.

Link them to each other from the brief (name plus URL).

## If StreamWeaver is missing

Same tabs, lower fidelity: one self-contained HTML file with inline tab script, or one markdown file per tab under `notes/canvas/`. Never drop a tab, only the rendering.

## Check before each push

- Does tab 1 show only what needs the reader, with an accurate blocking count?
- Is the brief still one screen and does it lead with what changed?
- Can every open decision be answered without leaving its card?
- Does every named thing link?
- Is any tab an unbounded feed? Fold it, shelve it or collapse it.
- Did a resolved decision visibly move from Decide to Decided?
