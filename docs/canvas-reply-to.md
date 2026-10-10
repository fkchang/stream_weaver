# Canvas reply_to: a canvas that messages its recipient

`canvas-wait` blocks an agent until the person clicks, and a hand-built listener has to stay running
or clicks are lost: the bridge forwards a canvas event only to clients connected at that moment, and
drops it otherwise. `reply_to` moves the recipient into the bridge. A canvas session carries a
`reply_to` string, and an installed gem's extension turns each browser event for that session into
whatever "delivering to a recipient" means. Nothing has to stay connected, so a form never times out.

StreamWeaver does not know what a recipient is. It routes on a prefix and hands the event to the
extension that registered for it.

## Using it

```bash
streamweaver canvas-push mycanvas --reply-to "peerpressure:SESSION_OR_JSON" <<'RUBY'
  radio_group :choice, ["A", "B"]
  button "Send"
RUBY
```

- `--reply-to` is accepted by `canvas` and `canvas-push`. A push can set or replace it on an existing
  session; an empty string clears it; a push that does not mention it leaves it alone. A push that
  fails to render changes nothing, including `reply_to`.
- It survives `canvas-snapshot` and `canvas-restore`, and shows in `canvas-list` output only when set.
- Delivery to a connected `canvas-wait` is unchanged and happens first. `reply_to` adds a second
  recipient; it never replaces the first.

The first extension is the [peerpressure](https://github.com/fkchang/peerpressure) gem, which turns a
button press into a message to a Claude Code or Codex session (`peer reply-to` prints the value).

## The contract

`reply_to` is an opaque string `"<extension id>:<payload>"`, split on the first colon. StreamWeaver
never interprets the payload. If the id names no registered sink, the bridge logs one line per event
and does nothing else.

A sink is a callable registered by an extension:

```ruby
# my_gem/stream_weaver.rb  (advertised in the gemspec, see below)
StreamWeaver.register_extension(:my_gem, canvas_event_sink: ->(context) {
  context.name          # the canvas session name
  context.extension_id  # "my_gem"
  context.payload       # what followed the colon in reply_to
  context.event         # {type: "event", name:, event: "action", data: {type:, button:, state:}}
  context.state         # a copy of the session's form state
  context.push(dsl)     # re-render the canvas, like canvas-push (keeps the session's source_dir)
})
```

```ruby
spec.metadata["stream_weaver.extensions.v1"] = "my_gem/stream_weaver"
```

Guarantees, all covered by `spec/canvas/event_sink_spec.rb`:

- The sink runs on its own thread, after connected clients have the event, so the browser's request
  never waits for it.
- A sink that raises is logged and changes nothing else: not the HTTP response, not other sinks, not
  delivery to `canvas-wait`.
- A session with no `reply_to` never reaches any sink.

Limits to design around:

- **No ordering guarantee.** Every event gets its own thread, so two quick events can reach a sink in
  either order. A sink that needs order or a concurrency limit serializes for itself.
- **Every browser event arrives**, `change` events included (a text field posts as you type). The
  sink filters; the peerpressure sink acts only on `action` events.
- **The extension must be installed where the bridge runs**, and the bridge discovers extensions once,
  at boot. Install the gem, then restart the bridge (`streamweaver canvas-restart` keeps open
  sessions). Discovery failures are logged to `~/.streamweaver/canvas.log`, never fatal.
- A sink is your gem's code running inside the long-lived bridge process. Install only extensions you trust.
