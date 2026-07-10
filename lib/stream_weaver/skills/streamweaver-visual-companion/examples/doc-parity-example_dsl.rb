# frozen_string_literal: true
# Inner DSL for the Calendar-Driven Travel State PRD.
# Intended for canvas-push: streamweaver canvas-push <session> < examples/components/prd_dsl.rb
# For standalone app with theme: ruby examples/components/prd_demo.rb

sidebar_toc sections: [
  { id: "problem",      label: "Problem Statement" },
  { id: "principle",    label: "Design Principle" },
  { id: "architecture", label: "Architecture" },
  { id: "c1",           label: "Component 1: Enforcement" },
  { id: "c2",           label: "Component 2: Sync Script" },
  { id: "c3",           label: "Component 3: Checkin Gate" },
  { id: "data-model",   label: "Data Model" },
  { id: "integrations", label: "Integration Points" },
  { id: "scope",        label: "Scope" },
  { id: "success",      label: "Success Criteria" },
  { id: "open",         label: "Open Questions" }
]

doc_header(
  eyebrow: "aria · Personal OS",
  title: "Calendar-Driven Travel State",
  pills: [
    { text: "Draft" },
    "June 25, 2026",
    "Author: Maya Chen",
    "Owner: scheduler secretary + aria_dev"
  ]
)

# 01 — Problem Statement
doc_section_header "01", "Problem Statement", id: "problem"
md <<~MD
  During the June 24 daily checkin, the grandmaster analysis fabricated "Austin, Texas"
  as Maya's location throughout — she was in Frederick, Maryland. The cause was a
  two-part failure:

  1. `current-state.yaml` didn't exist at checkin time, so Claude had no ground truth
  2. Claude pattern-matched "the Rio" (a Maryland venue) against prior journal context
     that had mentioned Austin, and confabulated a coherent but entirely wrong narrative
MD
callout(variant: :warning, title: "Root cause:") do
  text "Stale or absent location context causes Claude to infer location from indirect signals. " \
       "Confident wrong inferences propagate silently through analysis — they don't look uncertain, " \
       "they look authoritative."
end
md "The immediate fix (creating `current-state.yaml` and adding the Ask-Don't-Fabricate directive) " \
   "addresses the symptom. This PRD addresses the cause: `current-state.yaml` was created as a " \
   "manually-maintained file, which will inevitably go stale when juggling 20+ concurrent " \
   "sessions with no bandwidth to remember to update a doc."

# 02 — Design Principle
doc_section_header "02", "Design Principle: Calendar Is Truth", id: "principle"
md "Maya already maintains two calendars — Outlook (work PTO, flights, meetings) and Google " \
   "(family events). These are the existing ground truth for where she is and what she's doing. " \
   "Rather than maintaining a parallel file, the system should read from what already exists."
mermaid <<~MERMAID
  graph LR
    A["Calendar<br/>Outlook + Google<br/><i>ground truth</i>"]
    B["bin/sync-travel-state<br/>daily derivation"]
    C["current-state.yaml<br/>read-only cache"]
    D["Claude sessions<br/>consume, never write"]
    A --> B --> C --> D
    style A fill:#EEF2FF,stroke:#1E4ED8,color:#1E4ED8
MERMAID
callout(variant: :info, title: "Process change required:") do
  text "Driving trips (e.g., Austin) have no flights to detect. The convention is: all travel — " \
       "personal or work, driving or flying — must have an Outlook PTO block before the system " \
       "will track it. The cabinet enforces this rather than relying on memory."
end

# 03 — Architecture
doc_section_header "03", "Architecture Overview", id: "architecture"
md "Three components work together. Each has a single responsibility."
table(
  headers: ["Component", "Responsibility", "Owner", "Trigger"],
  rows: [
    ["Enforcement",           "Require calendar entry before travel is acknowledged", "scheduler secretary",    "Any travel mention"],
    ["bin/sync-travel-state", "Read calendars → write current-state.yaml",           "launchd / morning brief","Daily 6am + post-checkin"],
    ["Checkin gate",          "Human confirms derived state is accurate",             "aria-checkin Step 0",  "Every daily checkin"]
  ]
)

# 04 — Component 1
doc_section_header "04", "Component 1: Calendar Entry Enforcement", id: "c1"
card do
  card_header "Scheduler Secretary Behavior", badge: "C1", meta: "secretary work cycle + direct requests"
  card_body do
    md <<~MD
      When travel is mentioned in any context — daily checkin narrative, voicenote, direct
      message to scheduler — the secretary checks for a corresponding calendar entry before
      acknowledging or routing the trip.

      ### Detection Triggers

      - User says "I'm going to X" / "we're traveling to X" / "trip to X"
      - Voicenote mentions destination + date range
      - Checkin narrative references upcoming travel not in calendar

      ### Behavior: entry exists

      Acknowledge and flag for sync script to pick up at next run. No further action.

      ### Behavior: no entry found

      Create the calendar entry via `aria-outlook` or `aria-google`, confirm with user,
      then acknowledge. Secretary does _not_ write to `current-state.yaml` — that is
      exclusively the sync script's domain.

      #### Entry format (Outlook PTO)
    MD
    code_block(<<~TXT, lang: "text")
      Title:    Maya – PTO [Destination]
                e.g., "Maya – PTO Maryland"
                     "Maya – PTO Austin"
      Type:     All-day event, multi-day
      Calendar: Outlook personal
    TXT
    md <<~MD
      #### Entry format (work travel)
    MD
    code_block(<<~TXT, lang: "text")
      Title:    [Trip name] e.g., "Meridian Analytics summer trip 2026"
                Flight events are detected separately; PTO block still required
      Type:     All-day event
      Calendar: Outlook work
    TXT
    md "### Type Inference Rules"
    table(
      headers: ["Title pattern", "Inferred type"],
      rows: [
        ["contains \"Meridian\" / \"work\" / trip name from work context", "work"],
        ["\"Maya – PTO [Destination]\" with no work keywords",             "vacation"],
        ["Flight pair without PTO block (day trip)",                      "work"],
        ["Google family calendar multi-day event",                        "vacation"]
      ]
    )
  end
end

# 05 — Component 2
doc_section_header "05", "Component 2: bin/sync-travel-state", id: "c2"
card do
  card_header "Calendar Sync Script", badge: "C2", meta: "bin/sync-travel-state · Ruby"
  card_body do
    md <<~MD
      Reads both calendars, derives travel state, overwrites `current-state.yaml`.
      Idempotent — safe to run multiple times per day.

      ### Calendar Sources

      - **Outlook** — via `aria-outlook calendar list`. Reads 60-day window. Detects: PTO
        all-day events, flight events (title contains "flight" / airline names / airport codes).
      - **Google** — via `aria-google calendar list`. Reads Maya's primary calendar + Sam's
        shared calendar. Detects: multi-day events (family trips, shared PTO).

      ### Detection Logic

      - **Active travel:** any PTO event (Outlook) or multi-day non-recurring family event
        (Google) that spans today's date
      - **Upcoming trips:** PTO events or flight pairs within the next 60 days, grouped by
        date proximity (±2 days = same trip)
      - **Trip end date:** last day of PTO block or last flight's arrival date, whichever is later
      - **Destination:** parsed from PTO event title suffix or location field, falling back to
        flight arrival airport city

      ### Schedule

      - Daily at 6:00am via launchd (runs before any sessions likely to start)
      - After daily checkin completes (hooked into checkin flow)
      - Manual: `bin/sync-travel-state --force`

      ### Staleness guard

      If `aria-outlook` or `aria-google` returns an auth error (OAuth expired), the script
      logs the failure and exits without overwriting the existing file. It emits a warning to
      the COS inbox. It never writes a stale derivation.
    MD
    code_block(<<~SH, lang: "bash")
      bin/sync-travel-state            # normal run
      bin/sync-travel-state --dry-run  # print derived state, don't write
      bin/sync-travel-state --force    # run even if synced_at is recent
    SH
  end
end

# 06 — Component 3
doc_section_header "06", "Component 3: Checkin Verification Gate", id: "c3"
card do
  card_header "Daily Checkin — Step 0", badge: "C3", meta: "bin/aria-checkin · before form opens"
  card_body do
    md <<~MD
      A brief confirmation step added before the StreamWeaver form opens. Shows derived state
      and asks for a binary confirm. Catches calendar errors before they flow into analysis.

      ### When to show

      - `travel.active: true` — confirm travel is still ongoing
      - `travel.ends` is today or yesterday — confirm return status
      - `synced_at` is >24h old — warn and offer to re-sync
      - Upcoming trip starts within 3 days — surface it for awareness

      ### When to skip

      - `travel.active: false` and no trip starting within 3 days — no confirmation needed,
        proceed directly to form

      ### UI behavior

      Single yes/no question added to the StreamWeaver form as a pre-flight card. Displayed
      above the main form sections. Estimated time: 5 seconds.
    MD
    code_block(<<~TXT, lang: "text")
      "Derived from calendar: traveling in Maryland through Jun 28.
      Still accurate?"
      → [Yes, continue] [No, something's wrong]
    TXT
    md "If the user selects \"No\": display a correction prompt, update the calendar entry " \
       "(not the yaml directly), trigger `bin/sync-travel-state --force`, then proceed to the " \
       "main form with updated context."
  end
end

# 07 — Data Model
doc_section_header "07", "Data Model", id: "data-model"
callout(variant: :warning, title: "Do not hand-edit this file.") do
  text "It is written exclusively by bin/sync-travel-state. Manual edits will be overwritten " \
       "at next sync. For urgent corrections, update the source calendar entry and run " \
       "bin/sync-travel-state --force."
end
md "### current-state.yaml schema"
code_block(<<~YAML, lang: "yaml")
  # ~/aria-os/current-state.yaml
  # DERIVED FROM CALENDAR — do not hand-edit.
  # Run bin/sync-travel-state to refresh.

  synced_at: "2026-06-25T06:00:00-07:00"   # ISO8601, written by sync script

  location:
    current: "Frederick, MD"                # from PTO event location or title suffix
    home: "Ashland, OR"                      # static — set once in script config

  # travel.active is the primary flag all Claude sessions check.
  # true = away from home, any type. Repeating calendar events do not occur.
  travel:
    active: true
    type: vacation                          # vacation | work | mixed
    destination: "Maryland"                 # parsed from calendar
    ends: "2026-06-28"                      # PTO end date
    source_event_id: "AAMkADk1..."          # Outlook/Google event ID for traceability
    source_calendar: outlook                # outlook | google

  mode: vacation                            # normal | vacation | work-travel | deadline-crunch
  # Note: deadline-crunch is the only mode not derivable from calendar.
  # It must be set manually via: aria-cabinet cos-state set mode deadline-crunch

  mode_implications:
    hobby_teaching: skip    # auto: true when travel.active is true
    hobby_training: skip    # auto: true when travel.type is vacation
    calendar_note: >
      Repeating events (volunteer tutoring, weekend pottery class, etc.) appear
      on calendar but do not occur during travel. Do not log absences.

  travel_schedule:
    - destination: "Austin, TX"
      start: "2026-07-11"
      end: "2026-07-18"
      type: vacation
      source: outlook_pto
      source_event_id: "BBMkADk2..."

    - destination: "Denver, CO"
      start: "2026-07-20"
      end: null                             # return flight not yet booked
      type: work
      source: flight_pair
      flight_departure: "2026-07-20T06:00-04:00"
      flight_return: null
YAML
md <<~MD
  ### Non-calendar context (separate file)

  Data that cannot be derived from calendar — active work deadlines, upcoming notes —
  lives in a separate file read by relevant secretaries:
MD
code_block(<<~YAML, lang: "yaml")
  # ~/aria-os/cabinet/secretaries/cos/context.yaml
  # Hand-maintained by COS secretary. Not overwritten by sync.

  deadline_crunch_status:
    status: "Board deck due Friday — deprioritizing non-essential secretary work"
    review_meeting_planned: "2026-06-27"
YAML

# 08 — Integrations
doc_section_header "08", "Integration Points", id: "integrations"
md "### Systems that read current-state.yaml"
table(
  headers: ["Consumer", "What it reads", "Purpose"],
  rows: [
    ["bin/aria-checkin",      "travel, mode",              "Step 0 verification gate; grandmaster analysis context"],
    ["SessionStart hook",     "synced_at, travel.ends",    "Staleness warning before any session"],
    ["CLAUDE.md directive",   "location.current, travel.active", "Ground truth for location-sensitive reasoning"],
    ["Hobby schedule reasoning", "travel.active, travel.type","Skip training/teaching when traveling"],
    ["Scheduler secretary",   "travel_schedule",           "Plan-ahead awareness, avoid scheduling conflicts"]
  ]
)
md <<~MD
  ### SessionStart staleness check

  Add to the SessionStart hook (alongside `bin/aria-session-nudge`):
MD
code_block(<<~'RUBY', lang: "ruby")
  ruby -ryaml -rdate -e '
    f = File.expand_path("~/aria-os/current-state.yaml")
    exit unless File.exist?(f)
    s = YAML.load_file(f)
    synced = Date.parse(s["synced_at"].to_s.split("T").first) rescue nil
    if synced && Date.today - synced > 1
      puts "⚠️  current-state.yaml is stale (#{Date.today - synced}d) — run bin/sync-travel-state"
    end
    ends_str = s.dig("travel", "ends")
    if ends_str && s.dig("travel", "active") && Date.parse(ends_str) < Date.today
      puts "⚠️  travel.ends (#{ends_str}) is past but travel.active is true — run bin/sync-travel-state"
    end
  '
RUBY

# 09 — Scope
doc_section_header "09", "Scope", id: "scope"
comparison(before_label: "In Scope", after_label: "Out of Scope") do
  before do
    md <<~MD
      - Outlook PTO event detection
      - Google family calendar detection
      - Outlook flight event detection
      - Trip type inference from event titles
      - Destination extraction from title/location field
      - Checkin verification step
      - Scheduler enforcement (require calendar entry)
      - SessionStart staleness warning
      - launchd schedule (6am daily)
    MD
  end
  after do
    md <<~MD
      - Sub-day location tracking
      - Multi-timezone handling
      - Historical travel reconstruction
      - Automatic deadline-crunch mode detection
      - Seattle trip (not yet booked — tracks once calendar entry exists)
      - Drive trip detection without PTO block (process rule: add PTO)
    MD
  end
end

# 10 — Success Criteria
doc_section_header "10", "Success Criteria", id: "success"
table(
  headers: ["#", "Criterion"],
  rows: [
    ["SC1", "Zero location fabrications in grandmaster analysis after build — Claude reads ground truth or asks, never infers from indirect signals"],
    ["SC2", "`current-state.yaml` reflects accurate travel state without manual updates on ≥90% of travel days"],
    ["SC3", "Checkin verification gate catches any remaining discrepancies within 24h"],
    ["SC4", "New travel appears in `current-state.yaml` within 24h of calendar entry creation"],
    ["SC5", "Auth failures (OAuth expired) emit a COS inbox warning rather than silently writing stale data"],
    ["SC6", "Hobby absence during travel is not logged — no false 'missed training' entries accumulate"]
  ]
)

# 11 — Open Questions
doc_section_header "11", "Open Questions", id: "open"
table(
  headers: ["#", "Question", "Context"],
  rows: [
    ["Q1", "aria-google headless auth",
     "The sync script runs via launchd (non-interactive). Confirm that aria-google's OAuth token refresh works headlessly. If not, the Google calendar read will silently fail — the script must detect this and fall back to Outlook-only with a warning rather than writing incomplete state."],
    ["Q2", "Destination parsing from event title",
     "PTO events may not have a location field set. Title parsing needs a convention: \"Maya – PTO Maryland\" works; \"Maya – PTO\" alone does not yield a destination. Worth establishing the naming convention and adding it to the scheduler secretary's entry template."],
    ["Q3", "Sam's Google calendar access",
     "The script needs read access to Sam's shared family calendar to detect joint trips. Confirm aria-google has the correct scope and that the calendar is shared with Maya's Google account."],
    ["Q4", "Work trip hobby implications",
     "Work travel (Denver) is different from vacation — Maya may or may not train depending on the trip. Currently the model sets hobby_training: skip only for vacation type. Confirm whether work trips should also skip or leave as ambiguous (requiring checkin verification to clarify)."]
  ]
)
