# Blog Post Draft: Why a DSL Beats Raw HTML for AI Agent UIs

## Working Title
"From 10,000 Tokens to 200: Why StreamWeaver's DSL Is the Future of Agent-to-Browser Communication"

## Thesis
Every coding agent that needs visual output is reinventing the same wheel: generate
HTML/CSS/JS, serve it, open browser. This is expensive (tokens), fragile (CSS bugs),
and duplicated across every project. A reactive DSL solves all three.

## Outline

### 1. The Problem: ASCII Art Has Hit Its Wall
- Terminal agents default to box-drawing characters for diagrams
- Tables wrap and break beyond 3 columns
- Design decisions need visual comparison, not text descriptions
- Two excellent projects prove the demand: pi-design-deck, visual-explainer

### 2. The Current Solution: Generate HTML Every Time
- Agent generates full HTML documents with inline CSS/JS
- pi-design-deck: ~2000-token JSON slide definitions + agent generates options
- visual-explainer: agent generates entire HTML pages from reference patterns
- Every interaction regenerates substantial markup
- Token cost analysis: [INSERT NUMBERS FROM ANALYSIS]

### 3. The DSL Alternative: Describe Intent, Not Markup
- StreamWeaver example: design deck in ~50 lines of Ruby DSL
- vs. the equivalent: hundreds of lines of generated HTML/CSS/JS
- The DSL is the protocol — agent sends structured data, DSL renders it
- Re-rendering is free (server-side, no token cost)

### 4. Token Efficiency Math
- Raw HTML approach: [X] tokens per design deck interaction
- DSL approach: [Y] tokens per design deck interaction
- Reduction: [Z]%
- At scale (20 interactions/session): savings compound

### 5. Beyond Efficiency: The Toolkit Advantage
- pi-design-deck is one tool. visual-explainer is another. Each standalone.
- StreamWeaver unifies: Mermaid, code highlighting, themes, slides, tables
  are shared components used by BOTH use cases
- New skills get these for free — no re-implementation
- Community can build on the foundation

### 6. The Architecture
- Agent sends compact DSL commands or structured data
- StreamWeaver server renders reactive HTML (Puma + Pushable)
- Browser stays open, state persists across interactions
- AlpineJS handles client-side reactivity
- SSE for live updates (generate-more, progress tracking)

### 7. What This Means for the Ecosystem
- Skills become smaller (less prompt engineering for HTML generation)
- Works with Pi, Claude Code, Codex (any agent that can POST JSON)
- Open source Ruby gem — not locked to one agent platform
- The Streamlit parallel: just as Streamlit democratized data app UIs,
  StreamWeaver democratizes agent UIs

### 8. Show Don't Tell
- Side-by-side: pi-design-deck JSON → StreamWeaver equivalent
- Side-by-side: visual-explainer HTML generation → StreamWeaver equivalent
- Token counts for each

## Key Quotes to Develop
- "TUI isn't always the best way, but this is a token-efficient way"
- "If you can describe it in 10 lines of DSL, why generate 200 lines of HTML?"
- "The best agent UI framework is the one where adding a new visualization
  costs zero tokens — because the component already exists"

## Target Audience
- AI coding agent builders (Pi, Claude Code, Codex ecosystem)
- Ruby developers interested in AI tooling
- People frustrated with ASCII art in their terminals
