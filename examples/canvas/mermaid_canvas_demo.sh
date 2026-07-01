#!/bin/bash
# Demo: Mermaid diagrams pushed to a canvas session
#
# Shows how to use mermaid in canvas-push mode — useful when an AI agent
# or script needs to render a diagram without running a full StreamWeaver app.
#
# Usage: bash examples/canvas/mermaid_canvas_demo.sh

set -e

SESSION="mermaid-demo-$$"
STEPS=3

echo "=== StreamWeaver Mermaid Canvas Demo ==="
echo ""
echo "Starting canvas session: $SESSION"

# streamweaver panel handles browser opening automatically (iTerm2 split pane or
# external browser fallback) — no need to capture output or parse URLs here.
streamweaver panel "$SESSION" 2>/dev/null

sleep 1

# Prime the page with a spinner placeholder while the user reads the terminal output.
streamweaver canvas-push "$SESSION" <<'RUBY'
div style: "display:flex;align-items:center;justify-content:center;min-height:60vh;flex-direction:column;gap:1rem" do
  spinner size: :lg
  md "Loading demo — press **Enter** in the terminal to begin step 1…"
end
RUBY

echo ""
read -rp "Ready. Press Enter for step 1/$STEPS (architecture diagram)... " _

# -----------------------------------------------------------------------
# Push 1/3: Architecture diagram with zoom
# -----------------------------------------------------------------------
echo ""
echo "[1/$STEPS] Pushing architecture diagram..."
streamweaver canvas-push "$SESSION" <<'RUBY'
hstack spacing: :md, align: :center do
  badge "1 / 3", variant: :info
  header1 "System Architecture"
end
md "Use `zoom: true` for large diagrams — adds +/−/↺ controls and Ctrl+scroll zoom."

mermaid <<~MERMAID, zoom: true
  graph TD
    Browser["Browser"]
    SW["StreamWeaver Server"]
    Canvas["Canvas Bridge"]
    Agent["AI Agent / Script"]

    Agent -->|"canvas-push DSL"| Canvas
    Canvas -->|"WebSocket"| SW
    SW -->|"SSE update"| Browser
    Browser -->|"canvas-wait result"| Canvas
    Canvas -->|"JSON"| Agent

    style Agent  fill:#dbeafe,stroke:#3b82f6,color:#1e3a5f
    style Canvas fill:#dcfce7,stroke:#22c55e,color:#166534
    style SW     fill:#fef3c7,stroke:#f59e0b,color:#92400e
MERMAID
RUBY

read -rp "Step 1/$STEPS pushed. Press Enter for step 2/$STEPS (compact diagrams in cards)... " _

# -----------------------------------------------------------------------
# Push 2/3: Two compact sequence diagrams side-by-side
# -----------------------------------------------------------------------
echo ""
echo "[2/$STEPS] Pushing compact side-by-side diagrams..."
streamweaver canvas-push "$SESSION" <<'RUBY'
hstack spacing: :md, align: :center do
  badge "2 / 3", variant: :warning
  header1 "Compact Diagrams in Cards"
end
md "Use `compact: true` when embedding inside a `card` — reduces diagram padding."

columns widths: ['50%', '50%'] do
  column do
    card do
      header3 "Happy Path"
      mermaid <<~MERMAID, compact: true
        sequenceDiagram
          Client->>API: Request
          API->>DB: Query
          DB-->>API: Data
          API-->>Client: 200 OK
      MERMAID
    end
  end
  column do
    card do
      header3 "Error + Retry"
      mermaid <<~MERMAID, compact: true
        sequenceDiagram
          Client->>API: Request
          API->>DB: Query
          DB-->>API: Error
          API-->>Client: 500
          Client->>API: Retry
          API-->>Client: 200 OK
      MERMAID
    end
  end
end
RUBY

read -rp "Step 2/$STEPS pushed. Press Enter for step 3/$STEPS (theme vars)... " _

# -----------------------------------------------------------------------
# Push 3/3: Theme vars (use a variable — heredoc + multi-line hash is invalid Ruby)
# -----------------------------------------------------------------------
echo ""
echo "[3/$STEPS] Pushing themed diagram..."
streamweaver canvas-push "$SESSION" <<'RUBY'
hstack spacing: :md, align: :center do
  badge "3 / 3", variant: :success
  header1 "Custom Theme Variables"
end
md "Pass `theme_vars:` to override Mermaid colors per-diagram. StreamWeaver auto-derives `mainBkg` from `primaryColor`."

indigo = { primaryColor: "#6366f1", primaryTextColor: "#ffffff", primaryBorderColor: "#4f46e5", lineColor: "#6366f1", secondaryColor: "#e0e7ff" }
mermaid <<~MERMAID, theme_vars: indigo
  graph LR
    Idea --> Spike
    Spike --> Build
    Build --> Ship
    Ship --> Learn
    Learn --> Idea
MERMAID
RUBY

read -rp "Step 3/$STEPS pushed. Press Enter to see the completion summary... " _

echo ""
echo "All $STEPS steps complete."

streamweaver canvas-push "$SESSION" <<'RUBY'
div style: "text-align:center;padding:4rem" do
  badge "Complete", variant: :success
  div(style: "margin-top:1rem") { header1 "All 3 steps complete!" }
  md "Press **Enter** in the terminal to close this session."
end
RUBY

read -rp "Press Enter to close the session... " _

streamweaver canvas-close "$SESSION" 2>/dev/null || true
echo "Session closed."
