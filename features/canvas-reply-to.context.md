# canvas-reply-to — epic context

Verified 2026-10-10 against origin/main 4f5e673 (spikes ran against the dev checkout bridge, 4700).

## Facts (do not re-derive)

- Events reach an agent only through `BridgeServer#forward_to_claude` (lib/stream_weaver/canvas/bridge_server.rb), called once, from `post '/canvas/:name/event'`. It writes the message to `claude_connections` (clients holding a socket open: canvas-wait, `Client.each_event`) and nothing else. With none connected the event is dropped; session state (`session.update_state(event[:state])`) is still kept, so `get_state` and a page reload keep form values.
- The browser's `action` event carries the WHOLE form state: `{type:"event", name:, event:"action", data:{type:"action", button:"btn_<label_slug>_<n>", state:{...}}}`; `change` events carry `field`/`value`. The Save-as-doc widget adds `scope` and `name` keys to every state.
- After a button press the canvas replaces itself with "Submitted. You can close this window." Anything that wants a different page must re-push (the University listener does).
- Canvas DSL is rendered once to HTML (`Bridge#render_dsl`); interactions are events to a waiter. `submit` blocks do NOT run Ruby in the bridge.
- `Session.new` is first-create-wins for theme/layout (`@sessions[name] ||=`); reply_to must be settable by push for that reason.
- Extension discovery already exists (`Extensions.discover`, gemspec metadata `stream_weaver.extensions.v1`, `register_extension(id, course_provider:)`). The bridge boot script (`Client#start_bridge`) requires only `stream_weaver` and `bridge_server`; it never calls discover today.
- Test isolation: `STREAMWEAVER_CANVAS_SOCKET` and `STREAMWEAVER_CANVAS_PID` override the bridge's socket and pid file, so a second bridge can run beside the live one.
- The bridge started by `canvas-restart` runs the lib of the checkout whose CLI started it (`lib_path = File.expand_path('../..', __dir__)`).

## Design decisions

- reply_to is an opaque string `"<extension id>:<payload>"`. Core routes by the prefix; it never interprets the payload. No sink for the prefix means one log line.
- Sinks are called with one context object, off the request thread, errors rescued and logged.
- The first extension is the peerpressure gem (turns `action` events into messages). It lives in that repo, not here; this repo must not depend on it.
- `peerpressure`'s standing-relay path (`peer canvas-relay`) keeps working; reply_to replaces it once the extension is installed.

## Out of scope

Per-event filtering in core (sinks filter), replies back INTO the canvas beyond `push`, any recipient-specific behavior, changing canvas-wait.
