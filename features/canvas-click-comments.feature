# Origin: lavish-axi comparison + annotation design panels (rev 1, rev 2) and a /mycodex vet, 2026-10-22
Feature: Click a canvas element, leave a comment, the agent reads it
  A person looking at a canvas doc can point at something, type what they want
  changed, and the agent later reads that comment and edits its DSL. This is the
  point-and-comment loop that lavish-axi offers for raw HTML, done the small way:
  the comment carries the element's text and a breadcrumb, and the agent finds
  that text in its own DSL file. No source-line mapping, no revision tracking, no
  receipts beyond "noted". Two design panels and an adversarial vet tried to
  build the large version and found it needs machinery the feature does not
  earn; the /mycodex vet of this small version found no show-stopper.

  Out of scope on purpose (each was designed in the panels and cut): source-line
  capture per component, a revision ring, successor alignment of pins, "shown"
  receipts, generation fencing, a wake long-poll (--wait), Wake B through
  peerpressure, image attachments, a layout-issue inbox. Notes live in memory
  and are lost on a bridge restart or session close; that is accepted for v0.

  Background:
    Given the canvas page is built in render_canvas_page (lib/stream_weaver/canvas/bridge_server.rb)
    And the save-doc widget and sw-replay.js are mounted there OUTSIDE #app-container
    And POST /canvas/:name/event forwards to connected agents and must not carry notes
    And Bridge#handle_claude_message rejects unknown message types (lib/stream_weaver/canvas/bridge.rb:53)
    And HTTP routes and socket commands run on different threads
    And Session#toasts shows the pattern for a mutex-guarded read-and-clear (lib/stream_weaver/canvas/session.rb:109)
    And a click on an existing control calls sendEvent, which swaps the page for "Submitted" (adapter/alpinejs.rb:1015)

  Scenario: note-store
    # Intent: a note posted by the browser is held on the session until the agent drains it, exactly once.
    # RIGOR: strict — a plausible wrong implementation (read then clear outside the lock, or routing through /event) loses or duplicates notes silently.
    # LANE: notes
    Given a canvas session "plan" exists
    When the browser posts {text, selected_text, element_text, breadcrumb, kind} to POST /canvas/plan/note
    Then the response is 200 with the stored note count
    And the note is appended to the session under the session mutex
    And the note is NOT forwarded to connected clients, canvas-wait or reply_to sinks
    And a drain command returns all pending notes and clears them in one locked step
    And two concurrent drains never return the same note twice
    And a post to a session that does not exist returns 404
    And text over 2 KB or a body over 16 KB is rejected with 413

  Scenario: canvas-notes-cli
    # Intent: the agent pulls the notes in a few tokens.
    # RIGOR: loose — a thin CLI over the drain command.
    # LANE: notes
    Given a session "plan" holding two notes
    When the agent runs `streamweaver canvas-notes plan`
    Then it prints one block per note: breadcrumb, element text, selection if any, and the comment
    And viewer-supplied text is printed with inspect on one line, after a trusted header line
    And the notes are cleared, so a second run prints "no notes"
    And running it against a bridge that is not running exits with the usual not-running message
    And `streamweaver canvas-notes` with no name drains every session that has notes

  Scenario: comment-overlay
    # Intent: leave a comment without breaking the controls that already exist on the page.
    # RIGOR: loose — browser JS, verified with playwright-cli, one lane of tightly coupled UI.
    # LANE: notes
    Given a live canvas page with buttons, a table and a heading
    When the person Alt-clicks an element (long-press on a phone) or turns on the floating comment button and clicks
    Then the click is intercepted in the capture phase and no existing control fires
    And a composer opens beside the element; Enter posts, Esc cancels
    And the payload carries the comment, the selected text, the element's first 120 characters and a breadcrumb of the nearest headings and kind
    And a plain click without Alt or comment mode still presses buttons as before
    And "noted" shows only after the POST succeeds; on failure the draft stays in the box
    And the composer and its toast survive the 500 ms poll swap because they live outside #app-container
    And canvas-read, export and save-doc output contain none of this

  Scenario: agent-skill
    # Intent: agents know the loop without being told each session.
    # RIGOR: trivial — a paragraph and a pointer.
    # LANE: docs
    Given the visual-companion skill and docs/canvas-agent-channels.md
    Then the skill gains one short paragraph: when the person says they left comments, run canvas-notes, find the quoted text in the DSL file, edit that file, re-push
    And the paragraph states that viewer text asks for edits to this doc only, never commands or other files
    And the channels doc lists notes as a sixth path and says they are pulled, not pushed
