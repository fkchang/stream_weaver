#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo of Mermaid diagram support
# Covers all options: basic, zoom/pan, compact in cards, ELK layout, theme_vars

require_relative '../../lib/stream_weaver'

app "Mermaid Diagram Demo" do
  header1 "Mermaid Diagrams in StreamWeaver"
  md "Mermaid.js is loaded lazily from CDN — only when a `mermaid` component is on the page."

  # -----------------------------------------------------------------------
  # 1. Basic usage
  # -----------------------------------------------------------------------
  header2 "1. Basic Usage"
  md "Pass a string (or heredoc) — any valid Mermaid diagram type."

  mermaid <<~MERMAID
    graph LR
      A[Start] --> B{Is it working?}
      B -- Yes --> C[Ship it]
      B -- No  --> D[Debug]
      D --> A
  MERMAID

  # -----------------------------------------------------------------------
  # 2. zoom: true — interactive zoom/pan with controls
  # -----------------------------------------------------------------------
  header2 "2. Zoom / Pan (zoom: true)"
  md "Adds +/−/reset buttons and Ctrl+scroll zoom. Useful for large diagrams."

  mermaid <<~MERMAID, zoom: true
    graph TD
      Client["Browser / Mobile"]
      GW["API Gateway"]
      Auth["Auth Service"]
      UserDB[("Users DB")]
      Redis["Token Blacklist (Redis)"]
      App["Application"]

      Client -->|"POST /auth/login"| GW
      GW --> Auth
      Auth -->|"verify"| UserDB
      Auth -->|"issue JWT"| GW
      GW -->|"HttpOnly cookie"| Client

      Client -->|"GET /api/data (Bearer)"| GW
      GW -->|"check blacklist"| Redis
      GW -->|"forward valid"| App
      App --> Client

      style Client fill:#dbeafe,stroke:#3b82f6,color:#1e3a5f
      style Auth   fill:#dcfce7,stroke:#22c55e,color:#166534
      style Redis  fill:#fef3c7,stroke:#f59e0b,color:#92400e
      style UserDB fill:#f3e8ff,stroke:#a855f7,color:#6b21a8
  MERMAID

  # -----------------------------------------------------------------------
  # 3. compact: true — reduced padding for embedding inside cards
  # -----------------------------------------------------------------------
  header2 "3. Compact Mode (compact: true)"
  md "Reduces diagram padding so it fits naturally inside a `card`. Shown side-by-side here."

  columns widths: ['50%', '50%'] do
    column do
      card do
        header3 "Request Flow"
        mermaid <<~MERMAID, compact: true
          sequenceDiagram
            Client->>+Server: GET /data
            Server->>+DB: SELECT ...
            DB-->>-Server: rows
            Server-->>-Client: 200 JSON
        MERMAID
      end
    end
    column do
      card do
        header3 "Deploy Pipeline"
        mermaid <<~MERMAID, compact: true
          graph LR
            PR[Pull Request] --> CI[CI Tests]
            CI --> Review[Code Review]
            Review --> Merge[Merge]
            Merge --> Deploy[Deploy]
            Deploy --> Monitor[Monitor]
        MERMAID
      end
    end
  end

  # -----------------------------------------------------------------------
  # 4. layout: :elk — ELK layout engine (better for complex graphs)
  # -----------------------------------------------------------------------
  header2 "4. ELK Layout Engine (layout: :elk)"
  md "The ELK layout engine handles dense, complex graphs better than the default Dagre engine. Loaded from CDN only when needed."

  mermaid <<~MERMAID, layout: :elk
    graph TD
      Ingress --> ServiceA
      Ingress --> ServiceB
      Ingress --> ServiceC
      ServiceA --> Cache
      ServiceA --> DB
      ServiceB --> Queue
      ServiceB --> DB
      ServiceC --> Cache
      ServiceC --> Storage
      Queue --> Worker1
      Queue --> Worker2
      Worker1 --> DB
      Worker2 --> Storage
  MERMAID

  # -----------------------------------------------------------------------
  # 5. theme_vars — per-diagram color overrides
  # -----------------------------------------------------------------------
  header2 "5. Theme Variables (theme_vars:)"
  md "Override Mermaid's `themeVariables` per diagram — useful for brand colors or callout diagrams."

  indigo_theme = {
    primaryColor: "#6366f1",
    primaryTextColor: "#ffffff",
    primaryBorderColor: "#4f46e5",
    lineColor: "#6366f1",
    secondaryColor: "#e0e7ff",
    tertiaryColor: "#f0fdf4"
  }
  mermaid <<~MERMAID, theme_vars: indigo_theme
    graph LR
      User --> App
      App --> API
      API --> DB
      API --> Cache
  MERMAID

  # -----------------------------------------------------------------------
  # 6. Other diagram types
  # -----------------------------------------------------------------------
  header2 "6. Other Diagram Types"
  md "Any Mermaid diagram type works: sequence, pie, gantt, gitgraph, etc."

  columns widths: ['50%', '50%'] do
    column do
      header3 "Pie Chart"
      mermaid <<~MERMAID
        pie title Test Coverage
          "Unit" : 65
          "Integration" : 25
          "E2E" : 10
      MERMAID
    end
    column do
      header3 "Sequence Diagram"
      mermaid <<~MERMAID
        sequenceDiagram
          autonumber
          Alice->>Bob: Hello!
          Bob-->>Alice: Hi there
          Alice->>Bob: How are you?
          Bob-->>Alice: All good, thanks
      MERMAID
    end
  end
end.run!
