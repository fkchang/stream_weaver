# Shared DSL Fragments

How two or more StreamWeaver docs share ONE canonical copy of a table, a rule
list, or a set of numbers, so the documents cannot drift apart.

This is a pattern doc, not a feature doc -- nothing in `lib/` implements it
today. It is built entirely out of `instance_eval`, which is already how every
doc body is evaluated. See the "Proposal" section at the end for what a
first-class helper would look like.

## The problem

Multi-audience documents are the normal case, not the exception. The same
decision gets written up twice: once for the people who have to approve it and
once for the people who have to build it. Both write-ups quote the same rules
table and the same options table. The moment one of them is edited, the two
documents disagree, and nobody finds out until a meeting where two people are
reading different numbers off two different pages.

Forrest's 10th Rule applies to documents as much as to code. Two hand-maintained
copies of one table are a slow, buggy, half-assed version of one table.

## When to use it

- Two or more docs for **different audiences** that must agree on the same
  tables, rules, prices, or estimates. A decision memo and its engineering
  companion is the canonical shape.
- A doc plus a longer implementer reference where a summary table is the
  contract between them.
- Any number that gets restated. If a figure appears in two files and a human
  has to keep them equal, it belongs in a fragment.

Do NOT use it for prose. Prose written for engineers should not be the prose
shown to the product owner -- that difference is the whole point of having two
documents. Share the **facts** (tables, rule lists, numbers) and let each doc
write its own framing around them.

## The pattern

Three parts.

**1. The fragment** -- a plain `.rb` file, conventionally under a `shared/`
directory next to the docs. It defines methods that EMIT DSL and nothing else.
It is never rendered on its own.

**2. The consumer** -- each doc body loads the fragment with `instance_eval` at
the top, then calls the fragment's methods wherever the shared content belongs.
Because `instance_eval` on a string with a `def` in it defines a **singleton
method on the receiver**, and the receiver here is the `App` the doc body is
itself being evaluated against, those methods can call `table`, `md`, `callout`
and every other DSL verb exactly as if they had been written inline.

**3. Delivery** -- `streamweaver export` and `canvas-read` resolve the fragment
themselves; `canvas-push` and `org-export` need a hand. See "Delivery" below.

## The consumer snippet

Copy this into the top of each doc body. Replace the fragment path and the
guard method name.

```ruby
# streamweaver-doc: v1
#
# The shared tables come from ONE canonical file so this doc and its companion
# cannot drift. `streamweaver export` and `canvas-read` pass this file's path
# to instance_eval, so __dir__ is this file's own directory there. `org-export`
# and the canvas-push bridge eval the text with NO filename, so __dir__ is nil:
# org-export runs in your shell (cwd or SW_DOC_DIR resolves it), and canvas-push
# needs the fragment concatenated ahead of the body -- see the push command in
# docs/shared-dsl-fragments.md.
unless respond_to?(:pm_base_rules_table)
  _root = __dir__ || ENV["SW_DOC_DIR"] || Dir.pwd
  _frag = File.expand_path("shared/pm_discount_shared.rb", _root)
  raise "shared DSL fragment not found: #{_frag}" unless File.file?(_frag)
  instance_eval(File.read(_frag), _frag)
end
```

Three things earn their place here and nothing else does:

- `__dir__` covers export and canvas-read, which is most of the time.
- `ENV["SW_DOC_DIR"] || Dir.pwd` covers `org-export`, which runs in the same
  process as your shell.
- `unless respond_to?(...)` makes the concatenated canvas-push form a no-op
  rather than a second load. It is also what lets the resolver fail loudly
  instead of silently: if nothing defined the methods and nothing on disk
  matches, you get a path in the error message.

`DisplayDSL` and `App` define no `method_missing` (grep confirms), so
`respond_to?` is an honest test.

**Do not hardcode an absolute home-directory path as a fallback.** It works on
one machine and silently breaks the doc for anyone else, including a CI export.
Use the concatenation form for canvas-push instead.

## Why the snippet looks like that: how StreamWeaver evaluates a doc

Every mode is `instance_eval` of the doc text against a fresh `App` (or, for
org, against `Org::RecordingContext`, which includes the same `DisplayDSL`).
They differ only in whether a **filename** is passed to `instance_eval`, and
that is what decides whether `__dir__` works.

| Mode | Eval site | Filename passed | `__dir__` inside the doc | Same process as your shell |
|---|---|---|---|---|
| `streamweaver export` | `lib/stream_weaver/export/html_exporter.rb:104` | yes | the doc's directory | yes |
| `canvas-read` | `lib/stream_weaver/canvas/reader.rb:732` | yes | the doc's directory | yes |
| `streamweaver org-export` | `lib/stream_weaver/org/writer.rb:35` | no | `nil` | yes |
| `canvas-push` (bridge) | `lib/stream_weaver/canvas/bridge.rb:205` | no | `nil` | **no** |
| standalone `app ... do instance_eval(File.read(p), p) end` | your own wrapper | yes (you pass it) | the doc's directory | yes |

Verified empirically on Ruby 3.3.5: with a filename, `__dir__` is that file's
directory (and stays **relative** if you passed a relative path, which is fine
-- `File.expand_path` resolves it against the unchanged cwd). With no filename,
`__FILE__` is `"(eval at .../writer.rb:35)"` and `__dir__` returns `nil` rather
than raising. Guard with `||`, not with `rescue`.

The canvas-push row is the one that constrains everything. `canvas-push` reads
the DSL from **stdin** (`lib/stream_weaver/cli.rb:1177`) and ships it as plain
text over a socket to a long-lived bridge process. The bridge's cwd, its
environment, and its idea of "the current project" are not yours. It does
receive a `source_dir` -- the pushing side's git root
(`lib/stream_weaver/cli.rb:1185`, `lib/stream_weaver/canvas/protocol.rb:51`) --
but nothing plumbs that into the eval, and it is the repo root anyway, not the
doc's directory.

The gem already conceded this point once: `CLI.prepend_stylesheets`
(`lib/stream_weaver/cli.rb:1215-1228`) reads `--stylesheet` files on the
**pushing** side and inlines their content into the pushed text, with a comment
saying it does so "precisely because canvas-push has no reliable notion of 'the
DSL's own directory' once it's plain text." Fragments have the same problem and
take the same answer.

## Delivery

```bash
cd <repo>/docs/streamweaver_canvas

# Export to standalone HTML -- __dir__ resolves the fragment
streamweaver export pm-discount-decision-memo.rb -o /tmp/memo.html

# Browse -- canvas-read passes the path, __dir__ resolves the fragment
streamweaver canvas-read

# Org sibling -- __dir__ is nil, so run it from the doc's directory,
# or set SW_DOC_DIR to that directory from anywhere
streamweaver org-export pm-discount-decision-memo.rb
SW_DOC_DIR=$PWD streamweaver org-export /abs/path/pm-discount-decision-memo.rb

# Push to a canvas -- concatenate the fragment ahead of the body.
# The `unless respond_to?` guard makes the doc's own loader a no-op.
cat shared/pm_discount_shared.rb pm-discount-decision-memo.rb \
  | streamweaver canvas-push pm-memo
```

All five forms were run end to end against a throwaway doc before this was
written; the fragment's table renders in each.

## Fragment authoring conventions

- **One method per shared artifact**, named with a doc-family prefix:
  `pm_base_rules_table`, `pm_policy_table`. The prefix is not decoration --
  these become singleton methods on the `App`, sharing a namespace with every
  DSL verb, so a fragment method called `summary` or `rules` is a collision
  waiting to happen.
- **Emit DSL only.** The method body is `table(...)`, `md(...)`, `callout(...)
  do ... end`. Nothing else.
- **No side effects, no output, no `require`.** The file is read and eval'd,
  possibly several times per process, in contexts that are not a normal Ruby
  load path.
- **No headers.** No `doc_header`, no `doc_section_header`, no `sidebar_toc`.
  Section structure belongs to each doc, because each audience gets a different
  outline. The fragment supplies content that slots into whatever section the
  consumer chose.
- **No `# streamweaver-doc: v1` marker.** That marker means "this is a
  renderable doc body." A fragment is not one, and marking it invites tooling
  to try to render it.
- **A header comment naming the consumers.** The next person to edit a number
  in the fragment needs to know, in the file itself, which documents that
  number is about to change.

## Org mode

**Are fragment-sourced tables inlined in an org export?** Yes. `Org::Writer`
does not read your `.rb` source and translate it statement by statement -- it
`instance_eval`s the DSL text against `Org::RecordingContext`
(`lib/stream_weaver/org/writer.rb:35`) and then walks the resulting component
tree. By the time the writer sees anything, the fragment has already run and
its `Components::Table` objects are indistinguishable from tables written
inline. The generated `.org` is a fully expanded **snapshot**: drift-free at the
moment of export, and NOT re-linked to the fragment afterwards. Re-run
`org-export` after editing the fragment.

**Does the org round-trip path support `#+INCLUDE:`?** No, and nothing else
either. `Org::Reader.to_dsl` takes a **String**, never a path
(`lib/stream_weaver/org/reader.rb:41`), and all three of its callers hand it
text they have already read: `CLI.org_render`
(`lib/stream_weaver/cli.rb:1500`), `Canvas::Reader.render_doc`
(`lib/stream_weaver/canvas/reader.rb:731`), and the browser extension's
`sandbox.js`. There is no filesystem access anywhere in the parse. An
`#+INCLUDE:` line is not recognized as a keyword either -- `PREAMBLE_RE`
(`lib/stream_weaver/org/reader.rb:38`) matches only `#+STREAMWEAVER_DSL:` and
`#+TITLE:` -- so it falls through into the surrounding prose and round-trips
into an `md` block as visible literal text. Confirmed by running `org-render`
over an org doc containing one.

What it would take (proposal only, not implemented):

1. Thread a base directory through `Org::Reader.to_dsl(text, base_dir:)` and
   `Reader#initialize`, and pass it from `CLI.org_render` (which knows
   `org_path`) and `Canvas::Reader.render_doc` (which already has `path:`).
2. Add an expansion pre-pass before `#chunks` that splices the referenced
   file's lines in place of each `#+INCLUDE:` line, with a depth or cycle
   guard.
3. Accept that the **extension** path cannot do it. `sandbox.js` parses org in
   the browser with no filesystem, so an org doc using `#+INCLUDE:` would
   render one way through the CLI and another way in the extension. That
   divergence, not the parsing work, is the real cost.

Given that org files are generated snapshots today, the honest recommendation
is: author in Ruby, share fragments in Ruby, and let org be an export format.

**Why does a hand-typed `#+begin_quote` card/callout marker raise "malformed
card header"?** The marker line must contain ONLY the bolded title (`*title*`,
or `*[badge] title*`, plus an optional trailing `/(meta)/`) -- nothing else on
that line. Both `callout_marker_match` (`lib/stream_weaver/org/reader.rb:504-509`)
and `emit_card`'s own regex (`lib/stream_weaver/org/reader.rb:417-423`) are
fully line-anchored (`\A...\z`), so a natural "bolded lead-in phrase, then
continue the sentence" instinct --

```org
#+begin_quote
*ℹ️ Append-only.* This doc isn't version-tracked, so this is the history
mechanism...
#+end_quote
```

-- fails BOTH the callout match and the card fallback (even for a marker that
starts with a reserved callout emoji), so you get the generic "malformed card
header" error rather than anything pointing at the real cause. Body prose has
to start on the next line instead:

```org
#+begin_quote
*ℹ️ Append-only*
This doc isn't version-tracked, so this is the history mechanism...
#+end_quote
```

Same class of bug as the numbered-list-across-separate-`md()`-calls gotcha in
the visual-companion skill: looks fine to a human, breaks a strict line-based
parser. Confirmed live 2026-08-27 against a hand-typed org doc outside this
repo -- hand-typing `.org` at all runs against the "author in Ruby" advice
just above, but the parser should fail with a clearer message regardless.

## Caveat: the org writer's verbatim passthrough degrades

`Org::Writer` has an escape hatch for components it does not know how to
represent: it emits the component's **original source text** inside a
`#+begin_src ruby :streamweaver-raw t` block. That hatch depends on a 1:1
correspondence between top-level statements in the DSL text and components in
the tree, and it is switched off wholesale when the counts disagree --
`return {} unless statements.length == components.length`
(`lib/stream_weaver/org/writer.rb:206`).

A fragment loader is three top-level statements that produce zero components,
so the counts always disagree. Measured on a doc containing one unrecognized
component (`header1`):

| Doc | Coverage |
|---|---|
| without a fragment loader | `passthrough_verbatim: 1, passthrough_lossy: 0`, org contains `header1 "Unrecognized Thing"` |
| with a fragment loader | `passthrough_verbatim: 0, passthrough_lossy: 1`, org contains `# unrecognized component: StreamWeaver::Components::Header` |

Recognized components (`md`, `table`, `callout`, `card`, `comparison`,
`mermaid`, `code_block`, plus `doc_header`/`doc_section_header`/`sidebar_toc`)
are entirely unaffected -- which is most doc-theme docs, including both worked
examples below. The rule of thumb: a fragment-loading doc should stick to the
recognized vocabulary if its org sibling matters.

`NO_OP_STATEMENT_RE` (`lib/stream_weaver/org/writer.rb:30`) already exists to
excuse exactly this kind of component-less statement, but it only matches
`use_theme` / `use_layout`. It is not extensible from a doc.

## Proposal: a first-class `dsl_fragment` helper

Not implemented. This is a sketch for Forrest to accept or reject.

```ruby
doc_section_header "01", "Agreed Base", id: "agreed-base"
dsl_fragment "shared/pm_discount_shared.rb"
pm_base_rules_table
```

**Where it lives:** `StreamWeaver::DisplayDSL`
(`lib/stream_weaver/display_dsl.rb`). That is the one module included by all
three evaluation contexts -- `App` (`lib/stream_weaver/app.rb:10`),
`Org::RecordingContext` (`lib/stream_weaver/org/recording_context.rb:28`), and
therefore the canvas/bridge mini-`App` too. Anywhere else and it exists in some
modes and not others.

**Why it cannot just call `__dir__`:** inside a method defined in the gem,
`__dir__` is the gem's own directory. The helper must resolve against a base
directory supplied by whoever did the eval. So the proposal is really two
things: a `doc_base_dir` accessor on the DSL, and a `dsl_fragment` method that
resolves against it (falling back to `Dir.pwd`, and raising with the attempted
path when the file is missing).

Cases it must cover, one per row of the evaluation table above:

| Mode | What sets `doc_base_dir` | Change needed |
|---|---|---|
| `streamweaver export` | `HtmlExporter.from_dsl` already computes `File.dirname(File.expand_path(path))` for its own `base_dir:` | pass the same value to the app before `instance_eval` (`html_exporter.rb:104-106`) |
| `canvas-read` | `render_doc` already takes `path:` | set it on `mini_app` before eval (`canvas/reader.rb:732`) |
| `org-export` | `CLI.org_export` knows `rb_path` but throws it away | thread it into `Org::Writer.from_dsl(text, base_dir:)` and on to `RecordingContext` (`cli.rb:1479`, `org/writer.rb:35`) |
| standalone wrapper | the author knows the path | the existing `instance_eval(File.read(p), p)` idiom, plus an explicit setter |
| `canvas-push` | **nothing can** -- stdin has no path, and the bridge is a different process | see below |

**canvas-push is the load-bearing case.** Two candidate answers:

- *Textual pre-resolution on the pushing side*, following the exact precedent
  of `CLI.prepend_stylesheets` (`cli.rb:1215-1228`): give `canvas-push` an
  optional `--file PATH` (or a path argument in place of stdin), and have the
  CLI expand each `dsl_fragment "..."` line into the fragment's literal text
  before the push. The bridge then never needs a base dir, and the pushed text
  is self-contained -- which also fixes the history snapshot
  (`CLI.record_push_history`), currently saving a doc that cannot re-render
  because its fragment reference is unresolvable.
- *Plumb `session.source_dir` through.* The bridge already has it
  (`canvas/session.rb:11`, `canvas/bridge.rb:136`). But it is the git root, not
  the doc's directory, so fragment paths would have to be repo-root-relative --
  a second, inconsistent resolution rule. Not recommended.

The first option is the better one and it subsumes the concatenation workaround
this doc currently recommends.

**One more change comes with it:** add `dsl_fragment` to
`Org::Writer::NO_OP_STATEMENT_RE` (`org/writer.rb:30`), so a fragment-loading
doc keeps verbatim raw passthrough instead of degrading to lossy. That fix is
only available to a first-class helper -- a hand-rolled loader cannot buy it --
and on its own it is a decent argument for building the helper.

## Worked example

Live in the `billing_engine` repo, two audiences, one canonical pair of tables.
Paths are relative to that repo's root:

- Fragment: `docs/streamweaver_canvas/shared/pm_discount_shared.rb` -- defines
  `pm_base_rules_table` and `pm_policy_table`.
- Product/decision audience:
  `docs/streamweaver_canvas/pm-discount-decision-memo.rb`
- Engineering audience:
  `docs/streamweaver_canvas/pm-discount-engineering-brief.rb`

The seven base rules and the three renewal policies appear in both documents,
framed completely differently around them, and exist in exactly one place on
disk.
