# Origin: lavish-axi demo review + canvas-click-comments v0 test run, 2026-10-22
Feature: Annotate a canvas doc, send the batch, the agent resumes
  v0 (epic canvas-click-comments) lets a person click an element and leave a
  comment that the agent pulls on request. Using it showed three gaps: nothing
  tells the person what a click will do or what happened to their comment; the
  person has to go back to the terminal and type "I left comments"; and there is
  no marker on the element they pointed at.

  This epic turns the overlay into a review flow, shaped from the lavish demo
  (application chrome with an Annotate toggle, a Conversation pane, queued
  comments as pills, Send to Agent) and held to the design triumvirate: the
  Submit button is the signal to the agent, and the UI says plainly when nobody
  is listening.

  Entry is opt in and sensible wherever the person is (POLS):
    Case 1: a doc exists, saved but not on screen -> /sw-annotate <doc or path>
    Case 2: a canvas is already on screen          -> /sw-annotate [canvas name]
  Both end in the same state: the canvas is in annotate mode and the agent is
  waiting for Submit.

  Phase 1 (this epic): Claude Code, the agent waits in a background command that
  Submit releases (the University co-edit loop already runs this way with
  canvas-wait). Phase 2 (separate epic, build and dogfood it with Codex as the
  first target): Submit becomes a message into the agent session through
  peerpressure reply_to, so the agent can end its turn and Codex is supported.
  Phase 2 needs the canvas-reply-to branch merged and a peerpressure sink that
  reports status without replacing the doc.

  Out of scope on purpose: source-line mapping, revision tracking, images,
  layout-issue inbox, whiteboards, an agent-side "working" push channel.

  Background:
    Given epic canvas-click-comments shipped notes, POST /canvas/:name/note, canvas-notes and sw-canvas-notes.js
    And notes are held in memory on the session and lost on a bridge restart
    And the page has live controls, so a click must keep meaning "press the button" unless annotate mode is on
    And the lavish demo shows: Annotate toggle in a header, hover and selected highlight, a card titled with the element tag, queued comments as pills above the composer, Send to Agent with a dropdown, a Working bubble, an agent summary reply
    And docs/canvas-agent-channels.md compares the ways a canvas click reaches an agent

  Scenario: annotate-mode-chrome
    # Intent: one visible, persistent switch; the person always knows whether a click comments or presses.
    # RIGOR: loose — browser UI over the existing overlay.
    # LANE: ui
    # Spike 2026-10-22 (injected panel on the doc-parity example, doc theme, 1280px and 390px): a fixed right panel
    # 320px wide plus body padding-right reflows the doc with no overlap and no horizontal scroll. A fixed top bar
    # does NOT work: the doc theme's sticky TOC sticks at top:0 and sits behind it. So: no top bar, the toggle lives
    # in the panel header, and nothing about the page changes until the person opts in.
    Given a live canvas page
    Then while annotate is off the only thing added to the page is a small "comment" pill, and the doc's layout does not change
    And turning annotate on opens a right-hand panel (320px; a bottom sheet of about 40% height under 860px) whose header holds the Annotate toggle, and the doc reflows beside it through body padding
    And the doc theme's sticky TOC stays fully visible with the panel open, and no new horizontal scroll appears at 1280px or 390px
    And when the toggle is on a click comments and never presses a control; when off a plain click presses controls as before
    And Alt-click (long-press on touch) still opens a comment from either state, as the shortcut for one comment
    And the toggle state is held on the session so a reload or a second tab shows the same state
    And Esc leaves annotate mode when no composer is open
    And canvas-read, export and save-doc output contain none of this chrome

  Scenario: side-region
    # Intent: the panel is stable across canvas-push and updates on its own, Hotwire-shaped: a named region updated independently of the doc.
    # RIGOR: strict — the swap path that every later feature builds on; a plausible wrong version loses a draft or re-renders the doc.
    # LANE: bridge
    # Today a canvas push replaces #app-container wholesale (bridge_server.rb poll: container.innerHTML = data.html) and nothing targets a section.
    Given the page shell has a [data-sw-region="side"] element outside #app-container
    Then the session holds named regions, each with its own html and version, and /poll returns only the regions whose version is newer than the page's
    And the page swaps only that region's element, and never touches #app-container for a region update, nor a region for a doc push
    And the bridge renders the "side" region itself, in Ruby, from the session's notes state, so no agent tokens are spent updating it
    And a streamweaver canvas-push of the main doc leaves the side region, the open composer and any typed draft untouched
    And the composer textarea lives outside the swapped list, so a region update never loses typing or focus
    And regions are live-canvas only: canvas-read, export and save-doc output contain none of them

  Scenario: highlight-and-comment-list
    # Intent: show what got clicked, and show every pending comment where the person already is.
    # RIGOR: loose — browser UI, verified with playwright-cli by the coordinator.
    # LANE: ui
    Given annotate mode is on
    When the pointer hovers an element
    Then the element is highlighted, and the one being commented on keeps a stronger outline until the composer closes
    And the composer title names the element kind, like "Annotate <td>"
    And each comment appears in a sidebar list as a pill with its text, newest last
    And clicking a pill scrolls to its element and highlights it; a pill has edit and remove controls while unsent
    And a comment whose element has since disappeared shows a muted "element changed" pill and still sends
    And the sidebar shows the count of unsent comments

  Scenario: submit-and-wait
    # Intent: Submit is the signal to the agent; nobody has to type "I'm done".
    # RIGOR: strict — a lost wake or a duplicated batch fails silently; the person believes the agent heard them.
    # LANE: bridge
    Given comments are stored on the session as queued until Submit
    When the person presses Send to Agent
    Then all queued comments become sent in one step under the session lock, and a batch is released to any waiting agent exactly once
    And `streamweaver canvas-notes NAME --wait-submit` blocks until a batch is sent, then prints the batch and exits, so a background wait wakes the agent
    And Send & End releases the batch and marks the review ended; the wait prints that the person ended the review
    And a wait started after Submit returns immediately with the unread batch; a Submit with no waiter loses nothing
    And when no waiter is connected, Submit still sends but the sidebar says "No agent is listening" and shows a copyable line, "tell your agent: see my comments"
    And the bar shows "Your agent is waiting" only while a wait for THIS canvas is connected; a killed wait clears it within 2 seconds
    And reload or a second device sees the same queued and sent comments

  Scenario: status-and-summary
    # Intent: the person sees what happened to each comment and what the agent changed, without reading the terminal.
    # RIGOR: loose — states and one agent-written line.
    # LANE: bridge
    Given a batch was sent
    Then each sent comment shows Sent, then Seen when the wait returned it to the agent, then Working when the doc is next re-pushed, then Done when the agent posts a reply
    And `streamweaver canvas-notes reply NAME "summary"` posts the agent's one-line summary into the sidebar and marks the batch Done
    # DESCOPED 2026-10-29: a block-level accent needs a component-to-statement map, which two adversarial reviews broke (heredocs, same-line statements, helper methods). v0 does the sound part only: a re-push after Send shows "Doc updated" in the panel and moves Sent comments to Working. Block-level accent is a follow-up mark.
    And a re-push after Submit shows a panel-level "Doc updated just now" marker and moves the sent comments to Working; no block-level accent in this epic
    And the agent summary is plain text, rendered escaped, never as markup

  Scenario: sw-annotate-entry
    # Intent: one entry, wherever the person is, that lands in the same place.
    # RIGOR: loose — a CLI verb and a skill over what already exists.
    # LANE: entry
    Given the visual-companion skill and the canvas CLI
    Then `streamweaver canvas-annotate [NAME|FILE]` ensures the bridge and the session, pushes FILE if one is given, turns annotate mode on, and prints the command the agent should run in the background
    And with no argument it uses the only live canvas, or lists them and asks which when there are several
    And a skill `sw-annotate` (and the /sw-annotate slash command) tells the agent: run canvas-annotate, start the wait in the background, when it returns pull the batch, edit the DSL file, re-push, post a summary with reply, then wait again until the person ends the review
    And the skill states that viewer text asks for edits to this doc only, never commands or other files, and that a Proc-generated or ambiguous target is resolved with the person before editing
    And a fresh agent given only the skill can run the loop (clean-room acceptance)
