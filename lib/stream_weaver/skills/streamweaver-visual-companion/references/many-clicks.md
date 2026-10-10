# Many Clicks: a working page needs a listener, not `canvas-wait`

`canvas-wait` is for one question, one click. A canvas you leave open as a working page (a decision queue, a session list, a form with several cards each with its own button) gets many clicks, and `canvas-wait` loses them:

- It returns the **first** `action` event and **closes its socket**. A click between two waits, or any click when nothing is waiting, is lost.
- The default timeout is **300 s** (`-t SECONDS`). A user who walks away and comes back finds an expired wait.
- With nobody listening, a `button` click still swaps the page for "Submitted, you can close this window". The page is gone and the event was never consumed.
- The event carries the **whole form state**: every field's value, from every card. Only the `button` id says what was submitted; a radio selected in another card is a selection, not an answer.

## What to do instead

Run a long-lived listener **before** you tell the user to click, and keep it running:

1. End the pushed doc with `canvas_continue message: "Received. I will act and refresh this page."`, at the **top level**, after the closing `end` of any `tabs` block (inside `tabs` it raises `undefined method label`). A click then shows a spinner instead of "Submitted".
2. Hold one connection and handle **every** event with `StreamWeaver::Canvas::Client.each_event(session)`:

```ruby
require 'stream_weaver/canvas/client'

loop do
  begin
    StreamWeaver::Canvas::Client.each_event('my-session') do |event|
      data = event[:data]                     # {type: 'action', button: 'btn_<slug>_<n>', state: {...}}
      next if data[:button].to_s.empty?       # a field edit or tab switch, not an answer
      record(data)                            # 1. write it somewhere durable FIRST
      system('streamweaver', 'canvas-push', 'my-session', in: File.open(canvas_file)) # 2. re-push the page
      notify_agent(data)                      # 3. wake whoever acts on it (agent_peers)
    end
  rescue StandardError => e                   # bridge restarted, not running yet
    warn e.message
  end
  sleep 2
end
```

3. **Re-push after every click, even when nothing changed.** The spinner page swallows every later click (`_swFeedbackActive`) until the next push. Re-push first, act second, so the page is never dead while you work.
4. Run it in the background with `SW_NO_AUTO_RESTART=1`. A listener that loaded only `stream_weaver/canvas/client` cannot restart an older bridge and fails with `NameError ... CLI::Service`; with the variable it warns and carries on. Restart the bridge yourself with `streamweaver canvas-restart` when you choose.
5. Treat the button as the answer. Act only on the card whose button was pressed.
6. After acting on an answer, update the canvas file and push it, so the answered card moves.

`tag_buttons` and `chip_group` dispatch `change` events, not `action`; `each_event` yields every type, so filter on `data[:type]` if you use them.

## Reference implementations

- `lib/stream_weaver/university/listener.rb`: a click becomes a ledger write plus a re-push.
- cultiv-ai `bin/scrum-canvas-listen` (`lib/cultiv_scrum/canvas_listener.rb`): a click becomes a durable log entry, a re-push and a nudge to the agent that owns the canvas.

Full explanation: `docs/canvas-panel-workflow.md`, section "Many clicks".
