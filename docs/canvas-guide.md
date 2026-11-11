# StreamWeaver canvas guide for agents

**What this is:** the one page to read before you show the user anything long, or ask them anything. **What you do with it:** pick the right surface (section 1), then follow the recipe (section 2). Open the rest only when you need it.

Why: a growing terminal scrollback buries questions, decisions and context, so the user loses their place. A canvas is a page that stays put, can be answered by click, and costs far fewer tokens than writing HTML and screenshotting it.

**Design rules for every page:** (1) make it easy to find what matters and easy to digest; (2) remove every manual step, show the value by default, do automatically what can be automatic; (3) design for a tired, distracted reader: clarity before speed, no new inbox of guilt.

## 1. Which surface

Default thresholds (the local additions, see the last line, may change them):

| Put it... | When |
|---|---|
| **On a canvas** | More than 3 paragraphs, OR a table of more than 5 rows, OR any decision, question or choice for the user |
| **In the terminal** | A short answer, a status line, or one line saying "N decisions are on the canvas" (first line, never buried) |
| **In an Artifact** | Only if StreamWeaver is unavailable (`streamweaver` not on PATH), or someone who cannot reach this machine must open a hosted link |
| **In a gist / exported file** | Only when it must leave the machine and outlive the bridge; Save-as-doc on the canvas is the user's action, never yours |

## 2. The six-line recipe

```bash
streamweaver panel NAME                  # 1. once per session; opens the pane (SW_NO_OPEN=1 to suppress the browser on test boots)
# 2. write the page's DSL to FILE.rb and edit that file; never retype the page inline
streamweaver canvas-push NAME < FILE.rb  # 3. push from the file
```

4. **Tabs by action, numbered when order matters:** `1. Read what we found`, `2. Look at the sketches`, `3. Choose and send`. Not genre names.
5. **Cold open:** the first lines say what this page is and the single ask ("Choose Now, Next or Later for 9 items"). Never a sentence about the page ("Written for someone arriving cold..."). Put "leave it alone to accept my recommendation" at the control.
6. **Verdict:** for a page that tracks a goal (a plan, a runway, a tracker) lead with a judgment (behind, on track, ahead, unknown) and offer options, not orders. Never claim more certainty than the data has.

Then give the URL, say "N decisions are on the canvas", and end your turn. One canvas per session, re-pushed as things change. A push resets the viewer to tab 1, so push on real changes only.

## 3. Buttons and clicks

| Situation | Use |
|---|---|
| One question, one click, you will wait for it | `streamweaver canvas-wait NAME` (returns JSON; first `action` only; times out at 300 s, `-t SECONDS`) |
| A page answered over time, several cards, a queue | A **long-lived listener**, started BEFORE you push |
| The click must wake an agent session | A relay or `reply_to` sink; see `docs/canvas-agent-channels.md` |

A click with no listener is lost, and the page still says "Submitted". End the page with `canvas_continue message: "Received. I will act and refresh this page."` at the top level, after the closing `end` of `tabs` (inside `tabs` it raises `undefined method label`).

Listener skeleton (run in the background with `SW_NO_AUTO_RESTART=1`). The button pressed is the answer; every other field is just a selection:

```ruby
require 'stream_weaver/canvas/client'
loop do
  begin
    StreamWeaver::Canvas::Client.each_event('NAME') do |event|
      d = event[:data]                         # {type:, button:, state: {...}}
      next if d[:button].to_s.empty?           # a field edit or tab switch
      File.open('answers.jsonl', 'a') { |f| f.puts(d.to_json) }   # 1. record FIRST
      system('streamweaver', 'canvas-push', 'NAME', in: File.open('FILE.rb'))  # 2. re-push, even if nothing changed
    end                                        # 3. then act on the answer
  rescue StandardError => e
    warn e.message                             # bridge restarted
  end
  sleep 2
end
```

Re-push after every click: the spinner page swallows later clicks until the next push. `tag_buttons` and `chip_group` send `change` events, not `action` (`canvas-wait --any`, or filter on `d[:type]`). Full rules: `lib/stream_weaver/skills/streamweaver-visual-companion/references/many-clicks.md`.

## 4. Raising another session or pane from a canvas

A plain link cannot raise a terminal tab; only a click your listener hears can. Give the row a button whose id carries the target (`button "Raise NAME", id: "raise-<session-id>"`), and have the listener dispatch on the id prefix to whatever focuses that tab in your terminal. Show `claude --resume <session-id>` beside the name as a fallback. To bring a **canvas's own** pane forward after a push, run `streamweaver canvas-raise NAME`.

## 5. Gotchas (verified unless marked)

- `text "..."` is plain text. Markdown goes in `md`.
- A list split across several `md` calls restarts at 1. Put the whole list in ONE `md` with `\n` between items.
- `spacer` and `divider` do not exist: use `div(style: "height:8px")`. `theme: :light` is unrecognised: omit it.
- `text_field`, `text_area`, `select` that feed a button need `submit: false`, or every keystroke re-renders (`docs/for_llms.md`). Phone behaviour of this: NOT VERIFIED. `text_area` takes `placeholder:` and `rows:`, not `label:`.
- `checkbox_group` takes a block of `item` rows, not an array.
- **Never run `streamweaver canvas list`.** `canvas` takes a session name, so `list` is read as a session called "list" (usage line verified; running it was NOT tried). The command is `streamweaver canvas-list`.
- **`canvas-restart` closes every open tab and drops every listener.** The bridge heals itself only when idle; otherwise it warns once and keeps the old code. After a restart, re-push and restart your listener. Do not restart without a reason.
- Do not launch `ruby app.rb` or `streamweaver FILE.rb` per question. Use `canvas-push`.
- Buttons, radios and forms work only on the live canvas, not in `canvas-read` or an export (see the `streamweaver-canvas-safe` skill).
- Every push is saved in `~/.streamweaver/history/NAME/`; restore a blank session with `canvas-push NAME < latest-snapshot`.
- `canvas-notes NAME` reads comments the user left on the page (nothing wakes you).

## 6. Copy-paste skeletons

Both pushed to a throwaway canvas and rendered with no errors; button ids, `canvas_continue` and card text all appeared in the page.

**Decision tab** (question in words, recommendation, evidence, draft text, buttons):

```ruby
tabs :main do
  tab "1. Decide (1 blocking)" do
    card do
      card_header "Ship the announcement as written?", badge: "D1", meta: "blocks rollout"
      card_body do
        md "**Recommendation: yes.** One-line why."
        md "**Evidence**\n- First fact, with a link\n- Second fact"
        md "**Draft text**\n\n> Exact text that will go out"
        radio_group :d1, ["Ship as written", "Shorten", "Not yet"]
        text_area :d1_note, placeholder: "Anything to change? (leave alone = accept)", rows: 2, submit: false
        button "Send", id: "d1-send"
      end
    end
    header3 "Whenever"
    md "- **D2** small choice, recommend X, not blocking."
  end
end
canvas_continue message: "Received. I will act and refresh this page."
```

Every card is complete: if answering needs a second document, paste the excerpt in. Link every named thing (ticket, PR, file).

**Command-center tab** (rows the user acts on, each with its own button):

```ruby
tab "2. Command center" do
  card do
    card_header "Session NAME", badge: "running", meta: "4 min ago"
    card_body do
      md "[Open the repo](https://example.com)  `claude --resume UUID`"
      button "Raise NAME", id: "raise-UUID"
      button "Done", id: "done-UUID", style: :secondary
    end
  end
end
```

Pair with the listener in section 3 and dispatch on `d[:button]` by id prefix. For a long multi-agent session, the `session-tabs` skill's fixed six tabs (Decide, Brief, Findings, Decided, Artifacts, Trail) work well.

## 7. Patterns that always hold

- **Needs-me first.** Tab 1 is "what needs you" (open decisions, blocking first, count in the tab label: `Decide (2 blocking)`), and when nothing does it says "Nothing needs you" plus a three-line summary. Tabs never reorder; spatial memory is a feature.
- **Brief second:** where we are, what changed since the last push, the next step. One screen, always.
- **One canvas per purpose, several at once is fine.** A session canvas (needs-me, brief, findings, decided) and a **living doc** canvas (a report, a spec, a running blog) side by side, each with its own name. Do not stack purposes into one page.
- **Living blog:** for a long task, keep one canvas as a running post, newest entry on top (date, one-line headline, what changed, what is next). The reader gets a digestible update instead of scrollback. Edit the file and re-push; every push is saved to history.
- **Long docs you write for people** (PRDs, reports, explainers): build them as a StreamWeaver doc (`:doc` theme, `doc_header`, `sidebar_toc`), not markdown, and use the `streamweaver-doc-builder` skill. Shareable as an exported file.

## 8. Examples in this repo

- `lib/stream_weaver/university/listener.rb`: a click becomes a ledger write plus a re-push.
- `examples/canvas/` and `examples/claude_code/verification_flow/`: pages and multi-step flows.
- `docs/canvas-panel-workflow.md`, `docs/canvas-agent-channels.md`, `docs/components_reference.md`.

**Last step: if `~/.streamweaver/canvas-guide.local.md` exists, read it.** It holds the user's own rules (thresholds, named design principles, listener and example locations) and wins where it disagrees with this page.
