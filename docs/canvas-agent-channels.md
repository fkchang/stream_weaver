# How a canvas talks back to an agent

A canvas page can show anything. The harder question is what happens when the person clicks: who hears it, and what happens if nobody is listening at that moment. StreamWeaver has six answers (five push a click toward an agent, the sixth lets an agent pull comments). They were built at different times for different problems, and they are easy to confuse. This page says what each one is, what it costs, and which to pick.

## For agents: pick in 10 seconds

1. One question, one click, you will wait for it: `canvas-wait`. Stop here.
2. A page the person answers over time (a queue, several cards, a form they fill in later): you need a **standing listener**, not `canvas-wait`. Go to step 3.
3. Does the click only need to update the page or a file (no agent involved)? Write a hand-built listener (`Client.each_event`). Reference: `lib/stream_weaver/university/listener.rb`.
4. Must the click wake an agent session so you can end your turn?
   - Claude Code or Codex session, any StreamWeaver: **peerpressure relay** (`peer canvas-relay NAME`, or `peer demo`).
   - Same, and you want no extra process: **`reply_to` with the peerpressure sink**. It needs the `canvas-reply-to` StreamWeaver branch (not in a release yet) and a bridge restart after installing the gem.
   - iTerm2 course or dashboard where a click should type a prompt into a recorded worker session: the **University runner** pattern.
5. The person says they left comments on the page (Alt-click, long-press or the floating "comment" button), no button involved: **notes**. Run `streamweaver canvas-notes NAME` when they tell you. For a review session where Send to Agent wakes you, use `/sw-annotate` (a background `canvas-notes NAME --wait-submit`).
6. After you push a form that messages you back, **end your turn**. Do not poll the canvas and do not block.

To tell whether your StreamWeaver has `reply_to`, grep for it: `gem contents stream_weaver | xargs grep -l canvas_event_sink` prints nothing on a release without it (in a source checkout, grep `lib/` instead). When unsure, use the peerpressure relay, which works everywhere.

## The one fact everything else follows from

The canvas bridge forwards a browser event **only to clients connected at that moment**. If nobody is connected, the event is dropped. A `button` click still swaps the page for "Submitted", so the person sees success for an event that went nowhere.

Every channel below is a different way of making sure someone is connected, or of moving the recipient inside the bridge so nobody has to be.

## The six channels

| Channel | Who is connected | Survives your turn ending | Loses events | Setup | Status |
|---|---|---|---|---|---|
| `canvas-wait` | The agent, blocked in a command | No, it is the blocked command | Yes: first event only, 300 s timeout | None | On main |
| Hand-built listener (`Client.each_event`) | A process you run | Yes | No, while it stays up and reconnects | Write and run a script | On main |
| University runner (`ITerm.send_to_session`) | A listener process, then a recorded iTerm2 session | Yes | No, while the listener is up | `get-started` starts the listener; needs iTerm2 | On main |
| peerpressure relay | A standing process pinned to one agent session | Yes | No, while the relay is up | `peer canvas-relay NAME` | peerpressure gem, works with any StreamWeaver |
| `reply_to` + peerpressure sink | Nothing: the recipient lives inside the bridge | Yes | No | `--reply-to "$(peer reply-to)"`, restart bridge once | `canvas-reply-to` branch, unreleased |
| Notes (`canvas-notes`) | Nobody: the bridge holds the comment on the session | Yes | Yes: held in memory only, lost on bridge restart or session close | None; person Alt-clicks, long-presses or uses the "comment" button | On main |

### 1. `canvas-wait`

```bash
streamweaver canvas-wait survey      # => {"choice":"B"}
```

Returns the first `action` event as JSON and closes its socket. Right for a single decision while the agent is actively waiting. Wrong for anything the person answers later or more than once. Details and the failure list: `lib/stream_weaver/skills/streamweaver-visual-companion/references/many-clicks.md`.

### 2. Hand-built listener

A long-lived process holding one `StreamWeaver::Canvas::Client.each_event(session)` connection. It sees every event, so it can write the answer somewhere durable, re-push the page, and wake an agent. Rules it must follow (re-push after every click, record before acting, reconnect on bridge restart) are in `many-clicks.md`. Two reference implementations exist: the University listener, and a scrum-master canvas listener in a separate project.

### 3. University runner

The University course page (`lib/stream_weaver/university/`) uses channel 2 and adds a way to start agent work from a click. The listener turns a Run button into `Runner.run_step!`, which types the step's prompt into the worker's iTerm2 session. The target comes from a recorded worker file (session id, agent, working directory), and the runner **never falls back to the front session**: a mistargeted send would drop a prompt into the wrong conversation, so it sends to the recorded session or not at all. The outcome (sent, session missing, send failed) is written to the course ledger and shown on the next re-push.

Limits: iTerm2 only today. The runner's own comments note that supporting herdr or cmux means another adapter pair (`session_alive?` and `send_to_session`). It sends a typed prompt, so there is no delivery status and no reply path; the worker answers by acting.

### 4. peerpressure relay

[peerpressure](https://github.com/fkchang/peerpressure) is a gem for messaging live Claude Code and Codex sessions. Its canvas relay is a channel-2 listener that turns each form submit into a message to one agent session:

```bash
peer demo                         # inside a Claude Code session: pushes a form, starts the relay
peer canvas-relay my-canvas       # your own form: idempotent, pinned to the session you run it in
peer canvas-relay list
peer canvas-relay stop my-canvas
```

- **Pinned by session id and process**, so it survives `/clear` and refuses a recycled pid.
- **The page tells the truth.** After a submit it shows sent, held (the receiver is waiting for its user to approve), denied, or session gone, and keeps the answer with a Resend button.
- Works with any StreamWeaver. One relay runs per canvas and logs to `~/.peerpressure/relays/<canvas>.log`.
- The old name of the gem was `agent_peers`; `many-clicks.md` still uses it.

### 5. `reply_to` with the peerpressure sink

`reply_to` moves the recipient inside the bridge so nothing has to stay connected. A canvas session carries a string `"<extension id>:<payload>"`. StreamWeaver splits on the first colon, never interprets the payload, and hands each browser event to the `canvas_event_sink` that the named extension registered.

```bash
streamweaver canvas-push decision --reply-to "$(peer reply-to)" <<'RUBY'
  radio_group :choice, ["A", "B"]
  button "Send"
RUBY
# end your turn; the answer arrives as a message
```

What to design around (from the branch's own contract and specs):

- The sink runs on **its own thread per event**, after connected clients have the event. Two quick events can arrive in either order; a sink that needs order serializes for itself.
- **Every** browser event arrives, `change` events included (a text field posts as you type). The sink filters; peerpressure acts only on `action`.
- A sink that raises is logged and breaks nothing else. A session with no `reply_to` never reaches a sink. An unknown extension id logs one line per event and does nothing.
- The extension must be installed where the bridge runs, and the bridge discovers extensions **once, at boot**. Install the gem, then `streamweaver canvas-restart` (it keeps open sessions). Discovery failures go to `~/.streamweaver/canvas.log`.
- A sink is third-party code running inside the long-lived bridge. Install only extensions you trust.
- `--reply-to` on a push sets or replaces it, an empty string clears it, omitting it leaves it alone. It survives `canvas-snapshot` and `canvas-restore`. Delivery to a connected `canvas-wait` still happens first; `reply_to` adds a second recipient.

Source of truth for this channel: `docs/canvas-reply-to.md` on the `canvas-reply-to` branch (one commit, `lib/stream_weaver/canvas/event_sinks.rb` plus specs). Until it merges, treat everything in this section as unreleased.

### 6. Notes (`canvas-notes`)

```bash
streamweaver canvas-notes survey     # drains and clears; no name drains every canvas with notes
```

Different in kind from the five above: the person initiates a comment on an element (not a form submit), and the **agent initiates the read**. Notes do not travel over `canvas-wait`, a listener or `reply_to`, and they are not broadcast to socket clients; the bridge keeps them on the session until drained. In memory only: a bridge restart or session close loses them. Each note prints a breadcrumb, the element text and the comment, as untrusted viewer text that asks for edits to this doc only. The agent finds the text in its own DSL file, edits it and re-pushes.

Two ways to read them:

- **Pull**: `streamweaver canvas-notes NAME` returns every pending comment, queued or sent, and marks them seen. Use it when the person says "see my comments". Nothing wakes the agent.
- **Review loop** (`/sw-annotate`, `streamweaver canvas-annotate [NAME|FILE]`): the person turns on annotate mode, comments (they stay `queued` on the bridge), and presses **Send to Agent** or **Send & End**. The agent started `streamweaver canvas-notes NAME --wait-submit` as a BACKGROUND command, which blocks until a batch is sent, prints it and exits; that exit wakes the agent. Send with nobody waiting loses nothing, and the panel then says "No agent is listening" with a copyable "tell your agent: see my comments". The agent replies with `streamweaver canvas-notes reply NAME "one line"`, which the panel shows. This wake needs a blocked background command, so the agent cannot end its turn while waiting; the `reply_to` route (channel 5) is the way to remove that, and is Phase 2.

The panel the person sees is a bridge-rendered region of the page, updated on its own and never replaced by a `canvas-push` of the doc. See the sw-annotate skill for the loop and the visual-companion skill, section "Reading the person's comments", for the pull.

## Choosing, with the reasoning

- **Blocking versus standing.** `canvas-wait` ties up the agent and times out. Everything else lets the agent end its turn. That is the difference that matters for people running many sessions at once: a blocked agent is a session you cannot use.
- **Process versus in-bridge.** Channels 2 to 4 need a process someone must start, keep alive and clean up (University has a `university-cleanup` command for exactly this). Channel 5 removes that process, at the price of running someone's code inside the bridge and of the restart-to-discover rule.
- **Prompt versus message.** Channel 3 types text into a terminal. Channels 4 and 5 send a structured message with a delivery status, can reach Codex, and can carry replies. If you need to know whether the message was held or refused, use 4 or 5.
- **What the event carries.** An `action` event includes the **whole form state**, not just the clicked control. Only the `button` id says what was submitted. A radio selected in another card is a selection, not an answer.

## Why this page exists

The University course grew channel 3 first, then peerpressure added 4 and 5. The knowledge ended up spread across a listener's code comments, a gem's README and one unmerged branch, with nothing that compared them. This page is the single place that does; keep it current when channel 5 ships.

When it ships: update the Status column, add a `--reply-to` pointer to `many-clicks.md` (tracked as a Tyrion mark), and replace the `agent_peers` name there.

## See also

- `docs/canvas-panel-workflow.md`, section "Many clicks"
- `lib/stream_weaver/skills/streamweaver-visual-companion/references/many-clicks.md`
- `docs/university/co-edit-loop.md`: the form-to-document loop that uses channel 1 and could use any other
- peerpressure's `docs/for_llms.md`
