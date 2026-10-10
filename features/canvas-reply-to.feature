Feature: Canvas reply_to — a canvas forwards its events to a named recipient, so forms never time out
  Today a canvas click reaches an agent only while something is connected to the bridge
  (canvas-wait, or a hand-built listener); with nobody connected the bridge drops the event
  (bridge_server.rb forward_to_claude writes to claude_connections and nothing else). That is
  why blocking forms expire and why "many clicks" needs a standing listener process.
  reply_to makes the bridge itself hold the recipient: a canvas session may carry an opaque
  reply_to string, and an installed gem's extension may register a canvas_event_sink that the
  bridge calls with each event for sessions whose reply_to names that extension. StreamWeaver
  never learns what a recipient is. The first extension is the peerpressure gem, which turns an
  action event into a message to a Claude Code or Codex session. Design decisions, the verified
  facts and the spike evidence are in features/canvas-reply-to.context.md.

  Background:
    Given the canvas bridge forwards every browser event through BridgeServer#forward_to_claude (the single call site)
    And extensions are discovered from gem metadata (StreamWeaver::Extensions), never by scanning the load path

  Scenario: reply-to-session-field
    # Intent: a canvas session can carry a reply_to string; it survives the places a session's identity travels.
    # RIGOR: loose — plumbing, covered by specs; absent reply_to must change nothing
    Given a canvas session created or pushed with reply_to "peerpressure:SESSION_ID"
    When the bridge lists the session, answers get_dsl, or the canvas is snapshotted and restored
    Then the session reports the same reply_to each time
    And streamweaver canvas and canvas-push accept --reply-to VALUE and send it to the bridge
    And a push may set or replace reply_to on an existing session (create keeps first-wins for theme and layout)
    And a session with no reply_to behaves byte-for-byte as before, including its list and snapshot output

  Scenario: canvas-event-sink
    # Intent: an extension can register a sink that receives a session's events, without blocking or breaking the bridge.
    # RIGOR: strict — public-gem event chokepoint; a plausible wrong version (sink on the request thread, a raising sink failing the click, events reaching the wrong extension) breaks silently
    Given an extension registers canvas_event_sink: with a callable, under its extension id
    And a canvas session whose reply_to is "<that id>:<payload>"
    When the browser posts an event for that session
    Then the bridge calls that extension's sink with a context carrying name, extension id, payload, the event and a push(dsl) that re-renders the canvas
    And the sink runs off the request thread, so the browser's POST returns without waiting for it
    And a sink that raises is logged and never changes the HTTP response, the other sinks, or delivery to connected canvas-wait clients
    And a session whose reply_to names an extension with no sink gets a log line and nothing else
    And a session with no reply_to never reaches any sink
    And delivery to connected Claude clients is unchanged and still happens first
    And the bridge discovers extensions at boot and logs any load failure instead of dying

  Scenario: reply-to-docs
    # Intent: agents and users learn reply_to exists and when to prefer it over canvas-wait and a hand-built listener.
    # RIGOR: trivial — documentation of shipped behavior
    Given the many-clicks reference and the canvas workflow doc currently say many clicks need a listener
    When reply_to ships
    Then docs/canvas-panel-workflow.md and the visual-companion skill references describe reply_to, its extension routing and its limits
    And the docs say a recipient extension must be installed in the bridge's gem environment, and name peerpressure as the first one
