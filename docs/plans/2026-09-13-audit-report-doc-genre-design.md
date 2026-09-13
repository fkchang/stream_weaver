# Audit Report Doc Genre: design

Date: 2026-09-13
Status: design only, no code. Revised 2026-09-13 against the prior-org-decisions brief; Forrest ruled on section 8 the same day (all decided, see there).
Home repo: stream_weaver (see section 1 for why).

## 0. What this is

A reusable "audit report" document genre for StreamWeaver: one data contract, three small
components, one genre-level DSL macro, and one org-mode file schema. Any tool that
audits something (a guidance file, a skill library, a cabinet API surface) emits the
contract once and gets the same styled report: score hero, pass/warn/fail finding
cards, before/after stat panels, numbered owner to-do list.

The trigger was a competitor's LLM-generated "vault audit" page. The point here is not
to copy the page. It is that cultiv-ai already computes the audit data (wwfd-eval,
skill-ab, the drift detector, idea-ledger) and only the presentation is missing. This
genre is deterministic code from data to pixels. No LLM in the render path, which is the
whole cost argument versus routing through Artifact or a chrome mockup loop.

## 1. Where it lives and why

- **stream_weaver** owns the genre: components, the `audit_report` macro, the org
  reader/writer, the CLI dispatch. Rationale: all four render surfaces (standalone,
  canvas-push, canvas-read, export) are stream_weaver's, and the org round-trip code
  already lives here (`lib/stream_weaver/org/`). cultiv-ai depends on the gem by path
  (Gemfile, locked at 0.3.2), so it picks the genre up with no release step.
- **cultiv-ai / wwfd** own the producers: each tool grows a thin "emit the contract"
  adapter (a `--audit` flag or a `to_audit_report` method). No styling code lives there.

## 2. What already exists (verified, do not rebuild)

| Need | Existing primitive | Where | Verdict |
|---|---|---|---|
| Document shell | `doc_header`, `doc_section_header`, `sidebar_toc`, `:doc` theme | `lib/stream_weaver/components/doc_header.rb:24-53`, `sidebar_toc.rb`, `theme.rb:199-213` | Reuse as-is |
| Big number + label | `stat_display(value:, label:, color:, size:)` | `lib/stream_weaver/components.rb:2251-2272` | Reuse inside comparison panels; too small and too bare for the hero |
| Graded colouring convention | `score_table` thresholds (green >= 70, yellow 40-69, red < 40) | `components.rb:910-921` | Reuse the thresholds, not the component |
| Two-column before/after | `comparison(before_label:, after_label:) { before {}; after {} }` | `lib/stream_weaver/components/comparison.rb` | Reuse as the layout wrapper |
| Cards, N-up grid | `card`/`card_header`/`card_body`, `grid columns: [1,2,3]` | `components.rb`, `docs/components_reference.md:182-260` | Reuse |
| Coloured chip | `badge(text, variant: :success/:warning/:danger)` | `components.rb:2227` | Reuse for the status chip |
| Severity left-border | `priority_item` CSS pattern | `components.rb:2336` | Copy the CSS idea into `finding_card` |
| Pass/warn/fail badge | `status_badge(:strong/:maybe/:skip)` | `components.rb:1378` | Do not reuse: labels are domain-hardcoded |
| Checklist | `md` task lists: kramdown GFM renders `- [ ]`/`- [X]` as static checkboxes | `adapter/alpinejs.rb:2023-2029`, verified by running kramdown | Reuse; needs CSS only (no `.task-list` rules exist in `views.rb`) |
| Org round-trip | `Org::Reader` / `Org::Writer`, `streamweaver org-export` / `org-render` | `lib/stream_weaver/org/reader.rb`, `cli.rb:2006-2035` | Narrow dialect, see section 6 |

Prior-art report shells: `docs/streamweaver_canvas/mailroom-incident-20260813-1123.rb`
and `pm-discount-feasibility-20260819-1844.rb` (toc + header + numbered sections +
callouts). None combine the doc shell with the metric components; this genre is the
first to do so.

## 3. Data contract: AuditReport v1

Wire format is a plain Hash (YAML or JSON on disk). Every tool already emits JSON or
YAML, so this is the cheapest thing for a producer to hit. Org is the persisted,
human-editable form of the same data (section 6); the DSL is the render.

```yaml
audit_report: 1                     # schema version, required
title: "WWFD guidance eval"         # required
subject: "patterns/wwfd-claude-guidance.yaml"   # what was audited, optional
tool: "wwfd-eval"                   # producer id, optional, shown as a header pill
generated_at: "2026-09-13T08:40:00-04:00"

score:                              # required: the genre's identity is the hero number
  value: 87                         # numeric
  max: 100                          # optional; absent means "display value as-is" (a KPI, not a ratio)
  unit: "%"                         # optional display unit
  grade: "B"                        # optional; producer-supplied, never derived by the renderer
  label: "Guidance coverage"        # required; the small caption under the number
  headline: "7 of 8 patterns pass"  # optional; the one-line stat beside the number
  delta: -13                        # optional; signed change vs baseline, rendered as a chip
  baseline_label: "baseline 2026-09-01"

summary: |                          # optional markdown, rendered under the hero
  One paragraph of what this audit is and what changed.

findings:                           # optional list; section omitted when empty
  - id: f1                          # required, stable, referenced by todos
    status: fail                    # required: pass | warn | fail | skip
    category: "delegation"          # optional short chip (the "framework tag")
    title: "Delegation ladder is not a trigger"      # required
    body: |                         # optional markdown
      The guidance names the failure mode but never fires on it.
    owner: forrest                  # optional
    fix: "Add lean-coordinator as a pattern trigger"  # optional recommended action
    fixed: false                    # optional; true means "fix applied", rendered as a struck/green state

before_after:                       # optional; section omitted when absent
  before_label: "Baseline 2026-09-01"
  after_label: "This run"
  metrics:
    - label: "Score"
      before: 100
      after: 87
      unit: "%"
      good: up                      # up | down | none: which direction is an improvement

fixes_applied:                      # optional list of {title, body}; rendered as success callouts
  - title: "Renamed trigger X"
    body: "…"

todos:                              # optional; section omitted when empty
  - title: "Add delegation-ladder trigger"
    owner: forrest
    due: 2026-09-20
    done: false
    ref: f1                         # optional finding id; renders as a link to the card
```

Rules the renderer enforces:

- `skip` is a real fourth status ("could not evaluate"), not a warn. The drift detector's
  `:error` state and skill-ab's `not_yet_tested` both need it.
- Findings render fail, then warn, then pass, then skip. Counts per status go in the
  section header as chips, so the "what the audit found" summary is free.
- The hero colour follows `score_table`'s thresholds on `value / max` when `max` is
  present, and is neutral when it is absent. Grade is display-only.
- Everything except `audit_report`, `title`, and `score` is optional. A report with
  only a hero and a before/after block (delegation-roi) is valid.

### 3.1 How each cultiv-ai tool maps onto it

| Tool | score | findings.status | before/after | todos | Fit |
|---|---|---|---|---|---|
| wwfd-eval | percent, real `delta` vs `evals/baseline.json` | 1/0 per pattern -> pass/fail | baseline vs current score, natively | failed patterns | Strong |
| skill-ab report | share of skills with `earns_its_place` | earns_its_place->pass, inconclusive/not_yet_tested->warn/skip, deletion_candidate->fail | bare vs skill arm counts | deletion candidates, low-agreement skills | Good, lossy remap |
| Drift detector | `(total - failures) / total` | clean->pass, violations->fail, error->skip | none | `ScanProposal.proposed_action` | Good |
| idea-ledger report | derived from counts (shipped share) | shipped->pass, advancing->warn, declined->fail, filed->skip | none | its "Follow-ups" section | Usable, semantics stretched |
| delegation-roi | `minutes_saved`, no max | none (empty list) | window vs prior window, natively | none | Hero + before/after only |
| meeting-signals | none | none | none | owner + item rows | Poor; to-do only, do not force |

`ScanProposal` (`lib/cultiv_cabinet/secretary/scan_proposal.rb`) is already the shared
per-finding record across dozens of scans. A one-method mapping (`trigger_condition` ->
title, `proposed_action` -> fix, `urgency` P0/P1/P2 -> fail/warn/pass, `route_to` ->
owner, `proposal_type` -> category) turns every existing scanner into a producer without
touching the scanners.

## 4. Component set

Four additions to stream_weaver: three components and one macro. All static, canvas-safe by construction (no
`sendEvent`, no state), so they work in live canvas, canvas-read, and export. Each
needs the Alpine adapter render, the static adapter render, CSS in the `views.rb`
stylesheet heredoc (`sw-` BEM), and a `spec/components_spec.rb` block, following the
`stat_display` pattern (`components.rb:2251`, `display_dsl.rb:161`,
`adapter/alpinejs.rb:7129-7136`, `views.rb:2862+`).

1. **`score_hero(value:, label:, max: nil, unit: nil, grade: nil, headline: nil, delta: nil, baseline_label: nil)`**
   New. A hero band: the number at display-font scale with the grade beside it, the
   label under, the headline stat and delta chip to the right. Reuses the `.sw-stat`
   colour vocabulary. Why not `stat_display size: :xl`: the hero needs three extra
   slots (grade, headline, delta), not a bigger font.
2. **`finding_card(status:, title:, category: nil, owner: nil, fixed: false) { body }`**
   New, thin. `card` with a status-coloured left border (the `priority_item` idea), a
   `badge` chip for the status, a muted chip for the category, and an optional owner
   line in the footer. `fixed: true` swaps the chip to "fixed" and dims the card.
3. **`stat_comparison(before_label:, after_label:, metrics: [...])`**
   New, thin. `comparison` layout with one `stat_display` per metric in each panel, plus
   a delta chip coloured by `good:`. Why a component and not a macro: the org reader and
   writer need one construct to map a table onto, and export parity needs one render
   method.
4. **`audit_report(data)`** the genre macro, the single chokepoint.
   Takes the contract Hash and emits: `sidebar_toc` (only for sections present),
   `doc_header` (eyebrow = tool, title, pills = date, subject, grade), `score_hero`,
   summary `md`, section 1 "What the audit found" as `grid columns: [1,2,3]` of
   `finding_card`, section 2 `stat_comparison`, section 3 fixes as `callout(:success)`
   rows, section 4 the to-do list as one `md` block of GFM checkbox lines in the fixed
   convention `- [ ] title · owner · due · ref:f1`, preceded by an `[n/N]` cookie the
   macro computes from `done` at render time (Forrest's ruling, decision 5). No
   checklist component: kramdown already renders task lists as static checkboxes, so
   the only work is `.task-list` CSS in `views.rb`. Validates the contract and raises with a path on the
   first bad field, so a producer bug is a loud error and not a half-rendered page.
   Lives in a new `lib/stream_weaver/genres/audit_report.rb` and registers one DSL
   method; the doc-builder skill gains a short "audit report" reference section.

Standalone use is the doc-builder body pattern unchanged:

```ruby
# streamweaver-doc: v1
audit_report YAML.safe_load_file("wwfd-eval-2026-09-13.yaml", symbolize_names: true)
```

and `streamweaver canvas-push audit < body.rb` pushes it.

## 5. Render pipeline

```
producer (wwfd-eval, skill-ab, ...)  --emits-->  contract YAML/JSON  (wire format, not persisted)
                                                      |
                                        audit_report(hash) DSL body
                                                      |
                                       streamweaver org-export  (existing Org::Writer, extended)
                                                      v
                                             report.org   <-- greppable, diffable, versioned source of truth
                                                      |
                                       Org::Reader (existing, extended)   <-- canvas-read, org-render, extension preview
                                                      v
                                       DSL --> standalone | canvas-push | canvas-read | export
```

Nothing new at the CLI. The `.org` file is a plain instance of the shipped StreamWeaver
org dialect (`docs/superpowers/specs/2026-08-13-org-doc-format-design.md`), so every
surface that already understands that dialect delivers the genre for free: canvas-read
native `.org` (S1 in `docs/plans/org-doc-preview-surfaces.md`, shipped), the browser
extension's local-file drag-drop and Gist preview (S2, S3, shipped), and `org-render |
canvas-push`. Two surfaces do not take `.org` yet and are out of scope here:
`canvas-push` pipes stdin verbatim (hence the `org-render` step), and `streamweaver
export file.org` fails today (open mark disc-175); static HTML of an audit comes from
canvas-read's export or from `org-render file.org > body.rb` then `export body.rb`. The first line stays the literal `#+STREAMWEAVER_DSL: 1` so
every detection surface (content.js, sandbox.js, canvas-read, `doc_store.rb:167`) keeps
working.

There is no hand-rolled org emitter and no second parser. Producers never write org
directly; they hand a Hash to `audit_report`, and the existing writer serialises the
expanded component tree. orgkit is not a dependency of the genre. It becomes relevant
only if a tool later needs to mutate an existing report file in place (for example
ticking a to-do box), which is orgkit's byte-span mutation contract and
out of scope here.

No LLM is called anywhere in this pipeline. The token cost of showing an audit is the
cost of one `canvas-push` of a one-line body, or zero if the reader opens the `.org`
in canvas-read.

## 6. Org schema for the source file

The peer session's prior-decisions brief (2026-09-13) rules that the audit `.org` must
be an instance of the shipped dialect, not a parallel one: callouts and cards ride
inside `#+begin_quote` because org-ruby drops unknown block types entirely, the
round-trip bar is rendered-equivalent not byte-identical, and no hand-rolled org
emitters. This section is designed to that ruling. An earlier draft of this section
used tags, free property drawers and TODO headlines; it was dropped because the
dialect's reader has none of those (`reader.rb:29` numbered headlines only,
`reader.rb:215-223` two property keys and a mandatory `CUSTOM_ID`).

### 6.1 Principle: the components self-identify, the genre needs no reader

The four new components each get one org construct that (a) is a real org element
every generic renderer already shows, (b) is discriminated by the dialect's existing
mechanisms (quote-block marker line, `#+ATTR_STREAMWEAVER:` on a table), and (c)
degrades to the nearest plain construct in a viewer that does not know StreamWeaver.
Because the components self-identify, `#+STREAMWEAVER_GENRE: audit_report` is
advisory metadata only (tolerated by `PREAMBLE_RE`, `reader.rb:47`); the file is an
ordinary dialect doc that happens to use these constructs. No genre dispatch, no
reserved section names.

| Component | Org construct | Discriminator (Phase 3 addition to the dialect) | Degrades to |
|---|---|---|---|
| `score_hero` | quote block | marker line starts with `*🎯 ` (new reserved emoji, rule 3 table) | a blockquote showing the score |
| `finding_card` | quote block, card syntax | card whose `[badge]` is exactly `pass`, `warn`, `fail` or `skip` (rule 4 refinement); `/(meta)/` is the category | a plain card |
| `stat_comparison` | org table | `#+ATTR_STREAMWEAVER: :stat_comparison t :before "…" :after "…"` on the line before | a plain table |
| to-do list | plain org checkbox list inside prose | none needed; it is ordinary `md` text to the reader (`reader.rb:327-330`) and round-trips byte-identical | a native org checkbox list |
| fixes applied | existing ✅ callout | none needed | already in dialect |
| sections | existing numbered headlines with `:CUSTOM_ID:` | none needed | already in dialect |

Finding scalar fields that have no slot in the card syntax (`id`, `owner`, `fix`,
`fixed`) ride as git-style trailer lines at the end of the card body: `Id: f1`,
`Owner: forrest`, `Fix: …`, `Fixed: yes`. The reader strips recognised trailers into
the component; anything else stays body text.

### 6.2 The file

```org
#+STREAMWEAVER_DSL: 1
#+TITLE: WWFD guidance eval
#+STREAMWEAVER_GENRE: audit_report
#+DATE: 2026-09-13

#+begin_quote
wwfd-eval
WWFD guidance eval
2026-09-13 · patterns/wwfd-claude-guidance.yaml · [B](good)
#+end_quote

#+begin_quote
*🎯 87/100% B — Guidance coverage*
7 of 8 patterns pass
Δ -13 vs baseline 2026-09-01
#+end_quote

One paragraph of summary. Plain org prose, rendered as markdown.

* 1 What the audit found
:PROPERTIES:
:CUSTOM_ID: findings
:END:

#+begin_quote
*[fail] Delegation ladder is not a trigger* /(delegation)/
The guidance names the failure mode but never fires on it.

Id: f1
Owner: forrest
Fix: Add lean-coordinator as a pattern trigger
Fixed: no
#+end_quote

#+begin_quote
*[pass] Complexity skepticism* /(complexity_skepticism)/
The guidance explicitly names the failure mode and gives the concrete instruction.

Id: f2
#+end_quote

* 2 Before and after
:PROPERTIES:
:CUSTOM_ID: before-after
:END:

#+ATTR_STREAMWEAVER: :stat_comparison t :before "Baseline 2026-09-01" :after "This run"
| Metric           | Before | After | Unit | Good |
|---|---|---|---|---|
| Score            | 100    | 87    | %    | up   |
| Patterns passing | 8      | 7     |      | up   |

* 3 Fixes applied
:PROPERTIES:
:CUSTOM_ID: fixes
:END:

#+begin_quote
*✅ Renamed trigger X*
Body of what was changed.
#+end_quote

* 4 Owner to-do
:PROPERTIES:
:CUSTOM_ID: todo
:END:

Owner to-do [1/2]

- [ ] Add delegation-ladder trigger · forrest · 2026-09-20 · ref:f1
- [X] Re-run wwfd-eval after the rename · forrest
```

Greppability in practice: `grep -l '^\*\[fail\]' reports/*.org` lists every audit
with an open failure; `grep -h '^\*🎯' reports/*.org` is the score history; `git diff`
on a re-run shows exactly which cards flipped badge and which boxes got ticked;
`grep -h '^- \[ \]' reports/*.org` is every open to-do across all audits. Editing by
hand is changing `[fail]` to `[pass]` or `[ ]` to `[X]`. Owner, due and ref are
text-by-convention, so promotion to UTF reads them with one regex; the report keeps
the checked snapshot with the ref, which is the org-native shape for that.

### 6.3 What the Phase 3 dialect extension touches

Small, and all inside the existing reader and writer:

- `Org::Reader`: add 🎯 as a score marker (a separate table from `VARIANT_EMOJI` so
  callouts are untouched); in `emit_card` (`reader.rb:427`) route badge ∈
  {pass, warn, fail, skip} to `finding_card` and parse trailers; in `emit_table`
  (`reader.rb:332`) honour `:stat_comparison` in `pending_attr` alongside `:markdown`.
- `Org::Writer`: three new `when` branches in `render_component` (`writer.rb:137`) so
  the components stop falling into the `:streamweaver-raw` escape hatch, which is what
  would happen today and is neither greppable nor editable.
- The spec gets a dated Phase 3 section listing the two quote-block discriminators and the one
  table attribute, with the rule-3 emoji table extended and the rule-4 badge
  refinement stated as an accepted edge case (a plain card badged literally "pass" is
  a finding card; do not badge ordinary cards with those four words).
- Round-trip spec: `spec/org/round_trip_spec.rb` gains the file above and asserts
  rendered-equivalence.
- Body emission rule for the macro: `finding_card` and callout bodies must be emitted
  with `md`, never `text`, and must not nest other components. `Org::Writer` has no
  case arm for `text` or nested components inside a callout and drops them silently on
  export (open mark disc-170). The contract already makes `body` markdown, so this is a
  constraint on the macro, not on producers.

Accepted trade-off (decided): a checkbox list is invisible to org-agenda. `TODO`/`DONE`
headlines with `DEADLINE:` would need the dialect to learn TODO keywords and unnumbered
headlines, a bigger change than the genre justifies; revisit only if agenda visibility
turns out to matter.

## 7. First consumer and build sequence

### 7.1 First consumer: wwfd-eval

Chosen over the two flagged candidates:

- **skill-ab report** has zero recorded runs in this environment. There is no real data
  to prototype against, and a report designed against a synthetic fixture is the kind of
  demo-first work the AI Theater test exists to catch. It is the right second consumer:
  its verdict remap and deletion candidates exercise the warn/skip statuses and the
  to-do section that wwfd-eval does not.
- **coherence-check** is really two things. The CLI is unstructured RSpec prose and its
  own header documents why that was abandoned. The structured half, the drift detector,
  is quiet-on-success, has no before/after, and does not itemise findings past four fixed
  category labels.
- **wwfd-eval** has real data on disk today (`evals/baseline.json`, 8 per-pattern results
  with reasoning), the only genuine persisted baseline-versus-current score delta in the
  whole set, one finding per pattern with a category and a body, and a to-do list that
  falls out of the failures. It exercises the hero, the finding grid, and the before/after
  block with real values on day one. It is also run by protocol before every WWFD change
  (the global CLAUDE.md change protocol), so the report changes a real decision, commit or
  not, on a recurring basis rather than being looked at once.

Its one gap, binary pass/fail with no warn, is fine: warn is optional in the contract and
skill-ab covers it next.

### 7.2 Sequence (pareto rigor: lanes, rigor per story)

| Step | Lane | Rigor | What | Done when |
|---|---|---|---|---|
| 1 | components | strict | `score_hero`, `finding_card`, `stat_comparison`: class, DSL, Alpine + static adapters, CSS, specs; `.task-list` CSS for md checkbox lists | `bundle exec rspec` green; `examples/canvas-safe-showcase.rb` gains all three plus a checkbox list; export of the showcase renders them |
| 2 | components | strict | `audit_report(hash)` macro with contract validation, `examples/audit_report/` body + wrapper, doc-builder skill section | A hand-written YAML matching section 3 renders standalone and via canvas-push identically |
| 3 | consumer | loose | A 30-line script in wwfd turning `evals/baseline.json` plus a fresh run into contract YAML; push to canvas; Forrest reviews the real thing | Forrest has seen a real wwfd audit on canvas. This is the SDRD checkpoint: the visual reveals what v2 should be before the org work is built |
| 4 | org | strict | Phase 3 dialect extension: writer branches, reader discriminators and the table attribute, spec amendment, round-trip spec | `org-export` of the step-3 body produces the section 6.2 shape with no `:streamweaver-raw` blocks; `org-render` of it back renders equivalent; canvas-read opens the `.org` directly |
| 5 | consumer | loose | `bin/wwfd-eval --audit PATH.yaml` in wwfd; `bin/skill-ab report --audit` in cultiv-ai once it has runs; a `ScanProposal` -> finding mapper | Two producers, zero styling code in either repo |

Steps 1 and 2 are one warmed builder lane (same files). Step 3 comes before step 4 on
purpose: seeing the rendered report with real data is cheaper than guessing. Steps 4
and 5 can run in parallel once 3 is reviewed. Verification item for step 4: confirm
`Org::Writer.from_dsl` sees the components `audit_report` expands to, not the macro
call itself (it records the component tree via the recording context, so it should).

## 8. Decisions (ruled by Forrest, 2026-09-13)

1. **Home repo: stream_weaver** owns the genre; cultiv-ai and wwfd own producer
   adapters only. (Alternative rejected: cultiv-ai `lib/stream_weaver_ext/`.)
2. **Phase 3 dialect extension: yes.** Two quote-block discriminators (🎯 score marker,
   pass/warn/fail/skip card badge) and one table attribute (`:stat_comparison`) amend
   the shipped org-doc-format spec, so the three components never fall into the raw
   escape hatch on export.
3. **Static checklist: moot** under decision 5; a checkbox list is inherently static.
4. **First consumer: wwfd-eval**, skill-ab second once it has recorded runs.
5. **To-dos: option C, a plain org checkbox list** in the convention
   `- [ ] title · owner · due · ref:f1`, with the macro writing the `[n/N]` cookie.
   The `checklist` component and the `:checklist t` table attribute are removed from
   the plan (three new components, not four). Rationale: live items get promoted to
   UTF and the report keeps a checked snapshot with the ref; checkboxes are the
   org-native shape for that, and kramdown already renders them (section 2).
   (Alternatives rejected: a `:checklist` table; `TODO`/`DONE` headlines.)

## 9. Sources

Survey reports from this session (scratchpad, not in repo): stream_weaver primitives and
org reader scope; cultiv-ai and wwfd tool output shapes; orgkit and cultiv-ai org
conventions. Key repo references: `docs/superpowers/specs/2026-08-13-org-doc-format-design.md`
(existing org dialect), `lib/stream_weaver/skills/streamweaver-doc-builder/SKILL.md`,
`lib/stream_weaver/skills/streamweaver-canvas-safe/SKILL.md`, Tyrion marks disc-170,
disc-175, disc-182 (org gaps).
