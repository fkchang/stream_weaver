# Unified Gherkin Specification: StreamWeaver Visual Skills
#
# This specification covers ALL functionality from both pi-design-deck and
# visual-explainer, adapted for StreamWeaver's Ruby DSL architecture.
#
# Organization:
#   Part 1: Shared Component Features (used by both projects)
#   Part 2: Design Deck Features (deck-specific)
#   Part 3: Visual Explainer Features (explainer-specific)

# =============================================================================
# PART 1: SHARED COMPONENT FEATURES
# =============================================================================

Feature: Mermaid Diagram Rendering
  As a StreamWeaver app developer
  I want to render Mermaid diagrams in my pages
  So that I can visualize system architecture, flows, and relationships

  Background:
    Given a StreamWeaver app is running

  Scenario: Render a basic Mermaid diagram
    Given the app includes a mermaid component with code "graph TD\n  A-->B\n  B-->C"
    When the page renders
    Then Mermaid.js is loaded from CDN (mermaid@11 ESM)
    And the diagram renders as an inline SVG
    And the SVG uses theme: 'base' with custom themeVariables

  Scenario: Mermaid diagram respects dark/light theme
    Given the app includes a mermaid component
    When the page loads in dark mode
    Then the Mermaid themeVariables use dark palette colors
    When the page loads in light mode
    Then the Mermaid themeVariables use light palette colors
    And the theme is determined once at load time via matchMedia

  Scenario: Mermaid diagram with zoom controls
    Given the app includes a mermaid component with zoom: true
    When the page renders
    Then the diagram is wrapped in a zoom-enabled container
    And zoom controls appear: +, -, reset, 1:1, expand
    And Ctrl/Cmd+scroll zooms the diagram
    And click-and-drag pans the diagram
    And clicking without dragging opens full-size in a new tab
    And double-click fits the diagram to the container

  Scenario: Mermaid diagram in compact mode
    Given the app includes a mermaid component with compact: true
    When the page renders
    Then the diagram renders without zoom controls
    And the container height adapts to the SVG dimensions
    And the diagram is suitable for embedding within a card

  Scenario: Mermaid diagram with per-block theme overrides
    Given the app includes a mermaid component with theme variables { primaryColor: "#ff0000" }
    When the page renders
    Then the diagram uses the overridden primaryColor
    And other theme variables fall back to defaults

  Scenario: Mermaid diagram with ELK layout
    Given the app includes a mermaid component with layout: :elk
    When the page renders
    Then the @mermaid-js/layout-elk CDN module is loaded
    And the diagram uses ELK layout algorithm

# -----------------------------------------------------------------------------

Feature: Code Syntax Highlighting
  As a StreamWeaver app developer
  I want to display syntax-highlighted code blocks
  So that code is readable and visually appealing

  Background:
    Given a StreamWeaver app is running

  Scenario: Render a code block with language
    Given the app includes a code_block component with code "const x = 1;" and lang: "javascript"
    When the page renders
    Then Prism.js is loaded from CDN with autoloader
    And the code is syntax-highlighted for JavaScript
    And the block has a monospace font from the theme

  Scenario: Render a code block with file header
    Given the app includes a code_block component with file: "src/server.ts"
    When the page renders
    Then a file header appears above the code showing "src/server.ts"
    And the header has a distinct background from the code body

  Scenario: Code block with scroll container
    Given the app includes a code_block with 50 lines of code
    When the page renders
    Then the code block has a scrollable container
    And the maximum height is constrained

  Scenario: Code block truncation for thumbnails
    Given the app includes a code_block with truncate: 3
    When the page renders
    Then only the first 3 lines of code are shown
    And no scrollbar appears

  Scenario: Code block within a card
    Given the app includes a code_block inside a card component
    When the page renders
    Then the code block uses recessed depth styling
    And padding and margins integrate with the card layout

# -----------------------------------------------------------------------------

Feature: Theme Management
  As a StreamWeaver app user
  I want the page to respect my color scheme preference
  So that the visual output matches my environment

  Background:
    Given a StreamWeaver app is running

  Scenario: Auto theme follows OS preference
    Given the app uses theme mode: :auto
    When the OS is in light mode
    Then the page renders with light palette CSS custom properties
    When the OS switches to dark mode
    Then the page renders with dark palette via prefers-color-scheme
    And no page reload is required for CSS-only elements

  Scenario: Dark theme is default
    Given the app uses theme mode: :dark
    When the page loads
    Then the page renders with dark theme variables
    And the meta theme-color is set to the dark background color

  Scenario: Manual theme toggle via keyboard
    Given the app has a theme toggle shortcut configured as "mod+shift+l"
    When the user presses Cmd+Shift+L on Mac (or Ctrl+Shift+L elsewhere)
    Then the theme switches between light and dark
    And the override is saved to localStorage
    And meta theme-color is updated

  Scenario: Manual theme toggle via button
    Given the app includes a theme_toggle component
    When the page renders
    Then a toggle button appears with sun/moon icons
    When the user clicks the toggle
    Then the theme switches

  Scenario: Theme override persists across sessions
    Given the user previously toggled to light theme
    When the page reloads
    Then the light theme is applied from localStorage
    And the auto/default mode is overridden

  Scenario: CSS custom properties define theme tokens
    Given the app is using the theme system
    Then the following CSS custom properties are defined:
      | Property    | Purpose                    |
      | --bg        | Page background            |
      | --surface   | Card/container background  |
      | --border    | Low-opacity border         |
      | --text      | Primary text color         |
      | --text-dim  | Secondary text color       |
      | --accent    | Primary accent color       |
      | --accent-dim| Accent at low alpha        |

# -----------------------------------------------------------------------------

Feature: Keyboard Shortcuts
  As a StreamWeaver app user
  I want keyboard shortcuts for common actions
  So that I can interact efficiently without a mouse

  Background:
    Given a StreamWeaver app is running
    And the keyboard shortcut system is initialized

  Scenario: Register a keyboard shortcut
    Given the app registers a shortcut for "mod+s" with action :save
    When the user presses Cmd+S on Mac
    Then the :save action fires
    And the default browser save dialog is prevented

  Scenario: Context-aware shortcut suppression
    Given the app registers arrow keys for slide navigation
    And focus is inside a scrollable mermaid diagram container
    When the user presses ArrowRight
    Then the slide does NOT advance
    And the mermaid container handles the event instead

  Scenario: Context-aware shortcut suppression for text inputs
    Given the app registers number keys 1-9 for quick selection
    And focus is inside a textarea or text input
    When the user presses "3"
    Then the character "3" is typed into the input
    And no selection action occurs

  Scenario: Reduced motion respects system preference
    Given the OS has prefers-reduced-motion: reduce enabled
    When any keyboard-triggered transition occurs
    Then the transition completes instantly without animation

# -----------------------------------------------------------------------------

Feature: HTML Export
  As a StreamWeaver app developer
  I want to export my page as a self-contained HTML file
  So that it can be viewed offline or shared without a server

  Background:
    Given a StreamWeaver app is running

  Scenario: Export current page as HTML
    Given the app has rendered a page with mermaid diagrams and styled cards
    When the export action is triggered
    Then a single HTML file is generated
    And all CSS is inlined in a <style> tag
    And CDN links for Mermaid.js and fonts are preserved
    And the file works when opened directly from the filesystem

  Scenario: Export with inlined images
    Given the page contains images served from the StreamWeaver server
    When the export action is triggered with inline_images: true
    Then images are base64-encoded as data URIs in the HTML
    And no external image references remain

  Scenario: Export preserves both themes
    Given the page has light and dark theme support
    When the exported HTML is opened
    Then it responds to prefers-color-scheme media queries
    And both themes render correctly

  Scenario: Export writes to specified path
    Given the export action specifies output: "~/.agent/diagrams/my-review.html"
    When the export completes
    Then the file exists at the specified path
    And the file is a valid HTML5 document

# -----------------------------------------------------------------------------

Feature: Slide Navigation
  As a StreamWeaver app user
  I want to navigate between slides
  So that I can view content sequentially

  Background:
    Given a StreamWeaver app is running with a slide-based layout

  Scenario: Navigate with arrow keys
    Given the app is showing slide 1 of 5
    When the user presses ArrowRight
    Then slide 2 becomes visible
    And a transition animation plays (unless reduced motion is on)

  Scenario: Navigate with buttons
    Given the app has Back and Next navigation buttons
    And the app is showing slide 2 of 5
    When the user clicks "Next"
    Then slide 3 becomes visible
    When the user clicks "Back"
    Then slide 2 becomes visible again

  Scenario: Progress bar updates on navigation
    Given the app has a progress bar
    And the app is showing slide 2 of 5
    Then the progress bar shows 40% completion
    When the user navigates to slide 4
    Then the progress bar shows 80% completion

  Scenario: Back button disabled on first slide
    Given the app is showing slide 1
    Then the Back button is disabled
    And the Next button is enabled

  Scenario: Keyboard navigation respects interactive element focus
    Given an interactive element (mermaid diagram, table, code block) has focus
    When the user presses an arrow key
    Then the slide does NOT change
    And the interactive element handles the key event

# -----------------------------------------------------------------------------

Feature: Responsive Layout
  As a StreamWeaver app user on various devices
  I want pages to adapt to my screen size
  So that content is readable on any device

  Background:
    Given a StreamWeaver app is running

  Scenario: Grid collapses on narrow screens
    Given the app uses a grid component with columns: 3
    When the viewport width is below 900px
    Then the grid collapses to a single column
    And content remains readable

  Scenario: Auto-detect grid columns from content count
    Given the app uses a grid component with auto_columns: true
    And the grid contains 4 child elements
    When the page renders at desktop width
    Then the grid displays in 2 columns
    When the grid contains 3 child elements
    Then the grid displays in 3 columns

  Scenario: Page respects max-width constraint
    Given the app sets max_width: 1200
    When the viewport is 1920px wide
    Then the content area is centered at 1200px
    And side margins are equal

# =============================================================================
# PART 2: DESIGN DECK FEATURES
# =============================================================================

Feature: Design Deck Creation
  As an AI agent
  I want to create interactive design decks via StreamWeaver DSL
  So that users can view and select from visual design options

  Background:
    Given a StreamWeaver app is configured for design deck mode

  Scenario: Create a deck with slides and options
    Given the agent defines a deck with the DSL:
      """ruby
      design_deck "Architecture Direction" do
        slide "arch", "System Architecture", context: "Choose the backend architecture" do
          option "Monolith", aside: "Simpler to deploy" do
            mermaid "graph TD\n  Client-->API\n  API-->DB"
            code_block "app.listen(3000)", lang: "ts"
          end
          option "Microservices", recommended: true do
            mermaid "graph LR\n  Gateway-->Auth\n  Gateway-->Orders"
          end
        end
      end
      """
    When the StreamWeaver app starts
    Then a local server starts on an available port
    And the browser opens to the deck URL
    And the first slide displays with options in a grid
    And a progress bar shows 1/2 (plus summary)

  Scenario: Deck with preview blocks renders correctly
    Given a slide has options with mermaid, code, and image blocks
    When the deck renders
    Then mermaid blocks render as inline SVG diagrams (compact mode)
    And code blocks render with Prism.js syntax highlighting
    And image blocks display from the asset serving endpoint
    And blocks stack vertically within each option card

  Scenario: Deck with per-slide column override
    Given a slide specifies columns: 1
    When the deck renders that slide
    Then options display in a single-column layout
    And other slides use auto-detected column counts

  Scenario: Deck with context text
    Given a slide has a context property
    When the deck renders that slide
    Then the context text appears below the slide title
    And it is styled as secondary text with constrained width

  Scenario: Deck rejects invalid configuration
    Given a deck config has a slide with id "summary"
    When the deck tries to render
    Then it raises an error: "summary is a reserved slide id"

  Scenario: Only one deck active at a time
    Given a design deck is already active
    When the agent tries to create another deck
    Then it receives an error: "A design deck is already active"

# -----------------------------------------------------------------------------

Feature: Deck Slide Navigation
  As a user viewing a design deck
  I want to navigate between decision slides
  So that I can review all design dimensions

  Scenario: Navigate forward with button
    Given the deck is showing slide 1 of 3
    When I click the "Next" button
    Then slide 2 becomes active with a fade transition
    And the progress bar updates to 2/4
    And the heading of slide 2 receives focus

  Scenario: Navigate backward
    Given the deck is showing slide 2 of 3
    When I click the "Back" button
    Then slide 1 becomes active
    And the Back button becomes disabled

  Scenario: Navigate to auto-generated summary
    Given the deck is showing the last regular slide
    When I click "Next"
    Then the summary slide appears
    And the Next button shows "Done" and is disabled

  Scenario: Arrow keys navigate slides
    Given the deck is showing slide 1
    And no option card is focused
    When I press the Right arrow key
    Then slide 2 becomes active

  Scenario: Arrow keys navigate options when focused
    Given an option card has focus
    When I press the Down arrow key
    Then focus moves to the next option card
    And the slide does not change

# -----------------------------------------------------------------------------

Feature: Option Selection
  As a user viewing a design deck
  I want to select one option per slide
  So that my design choices are communicated to the agent

  Scenario: Select option by clicking
    Given slide 1 has 3 options
    When I click option "Microservices"
    Then option "Microservices" shows as selected
    And a checkmark badge appears with a pop animation
    And the radio indicator fills with accent color
    And the selection is saved to state

  Scenario: Select option by number key
    Given slide 1 has 3 options
    When I press the "2" key
    Then the second option becomes selected

  Scenario: Select option by Space key
    Given an option card has focus
    When I press Space
    Then that option becomes selected

  Scenario: Change selection deselects previous
    Given option "Monolith" is selected on slide 1
    When I click option "Microservices"
    Then "Microservices" becomes selected
    And "Monolith" is deselected
    And dirty state is marked

  Scenario: Selection persists across page reload
    Given I have selected options on slides 1 and 2
    When I reload the page
    Then my previous selections are restored from persisted state

  Scenario: Add notes to an option
    Given option "Microservices" is selected
    When I type "Use event sourcing" in the notes textarea
    Then the notes are saved to state
    And notes appear in the summary slide

  Scenario: Recommended badge displays on unselected option
    Given an option has recommended: true
    And it is not currently selected
    Then a "Recommended" badge appears in the header

  Scenario: Aside text displays below preview
    Given an option has aside text with newlines
    Then the aside text renders below the preview
    And newline characters render as line breaks

# -----------------------------------------------------------------------------

Feature: Generate More Options
  As a user who wants additional design options
  I want to request AI-generated alternatives
  So that I have more choices to consider

  Background:
    Given a design deck is active in StreamWeaver

  Scenario: Generate one additional option
    Given the deck is showing a slide with 2 options
    When I click "Generate" with count set to 1
    Then a skeleton placeholder with shimmer animation appears in the grid
    And the button shows "Generating..." with a spinner
    And the agent receives a generate-more callback with the slide id and count
    When the agent pushes a new option via the StreamWeaver API
    Then the skeleton is replaced with the new option card
    And the card has an entry animation
    And a "Generated" badge appears on the option
    And the grid rebalances for the new option count

  Scenario: Generate multiple options at once
    When I select count "3" and click "Generate"
    Then 3 skeleton placeholders appear
    When the agent pushes 3 options
    Then skeletons are replaced one by one as options arrive via SSE

  Scenario: Generate with custom prompt
    Given I type "make it more minimal" in the prompt input
    When I click "Generate"
    Then the prompt text is included in the agent callback
    And the prompt input is cleared

  Scenario: Generation timeout
    Given I clicked "Generate"
    And 30 seconds pass without receiving an option
    Then a toast notification shows "Generation timed out"
    And the generate button is restored to its default state

  Scenario: Regenerate all options on a slide
    Given the slide has 3 options
    When I click "Regenerate all"
    Then a skeleton overlay covers the existing options grid
    And the agent receives a regenerate callback
    When the agent pushes 3 replacement options
    Then the overlay is removed
    And new options appear with staggered entry animations
    And the previous selection for this slide is cleared

  Scenario: Concurrent generation prevented
    Given a generation is already in progress
    Then the Generate and Regenerate buttons are disabled

# -----------------------------------------------------------------------------

Feature: Save and Load Decks
  As a user who wants to preserve design decisions
  I want to save, load, and export deck snapshots
  So that I can resume work or share decisions

  Background:
    Given a design deck is active in StreamWeaver

  Scenario: Manual save with keyboard shortcut
    Given I have selections on 2 slides
    When I press Cmd+S
    Then the deck state is saved to a snapshot file
    And a toast notification shows the save path
    And the save status shows "Saved at HH:MM"

  Scenario: Auto-save on submit
    Given auto-save is enabled (default)
    When I submit the deck
    Then a snapshot is saved with "-submitted" suffix
    And image assets are copied to the snapshot directory

  Scenario: Auto-save on cancel with selections
    Given I have selected options on at least one slide
    When I cancel the deck
    Then a snapshot is saved with "-cancelled" suffix

  Scenario: List saved decks
    Given there are 3 saved deck snapshots
    When the agent queries for saved decks
    Then it receives an array of deck metadata
    And each entry includes id, title, savedAt, status, slideCount

  Scenario: Open a saved deck
    Given a deck snapshot exists with id "api-design-main-submitted"
    When the agent opens that deck
    Then the deck loads with selections pre-populated
    And notes are restored
    And the user can modify and re-submit

  Scenario: Export deck as standalone HTML
    Given a submitted deck exists
    When the agent exports it as HTML
    Then a self-contained HTML file is generated
    And it contains embedded CSS and inlined images
    And all slides are visible simultaneously (no navigation)
    And selected options are highlighted with a badge

  Scenario: Dirty state tracking
    Given I make a selection
    Then the save status shows "Unsaved changes"
    When I save
    Then the status shows "Saved at HH:MM"

# -----------------------------------------------------------------------------

Feature: Deck Keyboard Navigation
  As a user who prefers keyboard interaction
  I want full keyboard support for the deck
  So that I can navigate, select, and submit efficiently

  Scenario: Quick select by number
    Given slide 1 has 4 options
    When I press "3"
    Then the third option is selected

  Scenario: Enter advances to next slide
    Given I am on slide 1
    And no interactive element has focus
    When I press Enter
    Then slide 2 becomes active

  Scenario: Enter on summary submits
    Given I am on the summary slide
    And all selections are made
    When I press Enter
    Then the deck is submitted

  Scenario: Escape shows confirmation then cancels
    Given I have selections
    When I press Escape
    Then a confirmation bar appears at the top
    When I press Escape again
    Then the deck is cancelled
    And selections are auto-saved

  Scenario: Escape with no selections cancels immediately
    Given I have no selections
    When I press Escape
    Then the deck is cancelled immediately without confirmation

  Scenario: Arrow keys navigate between options
    Given an option card has focus
    When I press ArrowDown
    Then focus moves to the next option
    When I press ArrowUp
    Then focus moves to the previous option

# -----------------------------------------------------------------------------

Feature: Model Selection
  As a user who wants control over option generation
  I want to choose which AI model generates new options
  So that I can get options from different model capabilities

  Background:
    Given a design deck is active in StreamWeaver

  Scenario: Model bar appears with multiple models
    Given the agent has 3 or more models available
    When the deck loads
    Then a model bar appears below the header
    And "Current" is the active selection by default

  Scenario: Select a different model
    Given the model bar is visible
    When I select "gemini-3.1-pro" from the model list
    Then subsequent generate-more requests use this model

  Scenario: Save model as default
    Given a model is selected
    When I check the "Default" checkbox
    Then the model preference is saved to settings
    And future decks pre-select this model

  Scenario: Model bar hidden with fewer than 2 models
    Given the agent has only 1 model available
    When the deck loads
    Then no model bar appears

# =============================================================================
# PART 3: VISUAL EXPLAINER FEATURES
# =============================================================================

Feature: Web Diagram Generation
  As a developer using an AI agent
  I want to generate visual HTML diagrams via StreamWeaver
  So that I can understand complex systems better than ASCII art

  Background:
    Given the StreamWeaver visual-explainer skill is loaded

  Scenario: Generate a basic diagram
    Given the user invokes the web-diagram command with topic "WebSocket message flow"
    When the agent generates a StreamWeaver page with the DSL
    Then the page uses a distinctive aesthetic direction (not default/generic)
    And the page is served via StreamWeaver or exported as self-contained HTML
    And the browser opens to display it
    And the agent reports the URL or file path

  Scenario: Diagram uses distinctive typography
    Given a diagram page is being generated
    Then the body font is NOT Inter, Roboto, Arial, Helvetica, or system-ui alone
    And the font pairing is loaded from Google Fonts CDN
    And the pairing is chosen from the curated list of 13 recommended pairings

  Scenario: Diagram avoids AI slop patterns
    Given a diagram page is being generated
    Then accent colors do NOT include the forbidden indigo/violet hex values
    And headings do NOT use gradient text with background-clip
    And section headers do NOT use emoji icons
    And cards do NOT have animated glowing box-shadows

  Scenario: Diagram renders with Mermaid zoom controls
    Given the page includes a Mermaid diagram
    Then it is wrapped in a zoom-enabled container with controls
    And supports mouse wheel zoom, pan, and click-to-expand

  Scenario: Diagram works in both themes
    Given a diagram has been generated
    When the OS is in light mode
    Then the page renders with light palette
    When the OS switches to dark mode
    Then the page renders with dark palette
    And both themes look intentional, not broken

  Scenario: Optional AI image generation
    Given surf-cli is available on the system
    When the agent generates a diagram that would benefit from an image
    Then it generates an image via surf-cli
    And embeds it as a base64 data URI

  Scenario: Graceful degradation without surf-cli
    Given surf-cli is NOT available
    When the agent generates a diagram
    Then image generation is skipped without error
    And the page uses CSS and typography alone

# -----------------------------------------------------------------------------

Feature: Visual Plan Generation
  As a developer
  I want a visual implementation plan for a feature
  So that I can understand the design before coding

  Background:
    Given the StreamWeaver visual-explainer skill is loaded

  Scenario: Generate a visual plan
    Given the user invokes the visual-plan command for "user authentication"
    When the agent gathers data
    Then it parses the feature request
    And reads relevant codebase files
    And understands extension points and prior art
    And generates a 10-section StreamWeaver page

  Scenario: Plan includes state machine diagram
    Given a visual plan has been generated
    Then section 3 contains a Mermaid state diagram or flowchart
    And it shows the lifecycle of the feature's core entity

  Scenario: Plan includes code snippets
    Given a visual plan has been generated
    Then section 5 shows modified functions with syntax-highlighted code
    And each snippet has an explanation of the change

  Scenario: Verification checkpoint before rendering
    Given the agent has gathered all data for the plan
    Then it creates a verification fact sheet
    And cross-references claims against actual code
    Before generating the final StreamWeaver page

# -----------------------------------------------------------------------------

Feature: Slide Deck Generation
  As a presenter
  I want to convert technical content into a presentation
  So that I can present findings to a team

  Background:
    Given the StreamWeaver visual-explainer skill is loaded

  Scenario: Slide deck is opt-in only
    Given the agent encounters complex content
    Then it NEVER auto-selects slide format
    And slides are only generated via explicit command or flag

  Scenario: Generate a slide deck
    Given the user invokes the slides command for "API Gateway Redesign"
    When the agent generates the deck
    Then it uses scroll-snap with 100dvh per slide
    And it picks from 4 slide presets (Midnight Editorial, Warm Signal, Terminal Mono, Swiss Clean)
    And the deck has multiple slide types (title, content, split, diagram, dashboard, etc.)

  Scenario: Slide deck keyboard navigation
    Given a slide deck is displayed
    When the user presses ArrowRight or ArrowDown
    Then the next slide scrolls into view smoothly
    And Space, PageDown, PageUp, Home, End keys also work
    And touch swipe (>50px) navigates between slides
    And a progress bar, nav dots, and slide counter are visible

  Scenario: Content completeness over polish
    Given a source document has 7 sections and 6 decisions
    Then the slide deck covers all 7 sections and all 6 decisions
    And a 22-slide complete deck beats a 13-slide polished but incomplete deck

  Scenario: Cinematic slide transitions
    Given a slide scrolls into view
    Then it fades in with translateY(40px) and scale(0.98)
    And child elements with reveal class stagger in at 0.1s intervals
    And @media (prefers-reduced-motion: reduce) disables all transitions

  Scenario: Compositional variety
    Given a slide deck is being generated
    Then consecutive slides vary their spatial approach
    And the deck alternates between centered, left-heavy, right-heavy, split compositions

  Scenario: Slides flag on other commands
    Given the user invokes "/diff-review main --slides"
    Then data is gathered using the diff-review workflow
    But presented as a slide deck instead of a scrollable page

# -----------------------------------------------------------------------------

Feature: Diff Review
  As a developer
  I want a visual diff review via StreamWeaver
  So that I can understand code changes with architecture context

  Background:
    Given the StreamWeaver visual-explainer skill is loaded

  Scenario: Diff review against main branch
    Given the user invokes the diff-review command with no argument
    When the agent gathers data
    Then it runs git diff --stat and --name-status against main
    And reads all changed files in full
    And checks CHANGELOG.md and README.md for needed updates
    And generates a verification fact sheet
    And renders a 10-section StreamWeaver page

  Scenario: Diff review of a specific PR
    Given the user invokes diff-review for PR #42
    Then the agent runs "gh pr diff 42" for the diff data

  Scenario: Diff review of a commit hash
    Given the user invokes diff-review for "abc123"
    Then the agent runs "git show abc123" for the diff data

  Scenario: Executive summary provides aha moment
    Given a diff review has been generated
    Then section 1 uses hero depth styling
    And leads with WHY the changes exist
    And a reader of only this section understands the essence

  Scenario: Code review has Good/Bad/Ugly structure
    Given a diff review has been generated
    Then the code review section has 4 categories: Good, Bad, Ugly, Questions
    And each uses colored left-border cards (green, red, amber, blue)
    And each item references specific files and line ranges

  Scenario: Module architecture has Mermaid diagram
    Given a diff review has been generated
    Then section 3 contains a Mermaid dependency graph
    And the diagram has zoom controls

  Scenario: Decision log captures rationale
    Given a diff review has been generated
    Then each decision card shows: decision, rationale, alternatives, confidence
    And confidence levels have visual treatment (green/blue/amber)

# -----------------------------------------------------------------------------

Feature: Plan Review
  As a developer
  I want to compare a plan against the actual codebase
  So that I can identify gaps and risks before implementation

  Background:
    Given the StreamWeaver visual-explainer skill is loaded

  Scenario: Plan review with plan file
    Given the user invokes plan-review for "docs/plan.md"
    When the agent gathers data
    Then it reads the plan file in full
    And reads every file the plan references
    And reads files that import/depend on referenced files
    And maps the blast radius
    And generates a 9-section StreamWeaver page

  Scenario: Current vs planned architecture diagrams
    Given a plan review has been generated
    Then it shows current and planned Mermaid diagrams
    And both use the same node names for visual comparison
    And new nodes are highlighted with accent borders
    And removed nodes have reduced opacity

  Scenario: Risk assessment includes cognitive complexity
    Given a plan review has been generated
    Then the risk section includes cognitive complexity flags
    And each has severity and mitigation suggestion

  Scenario: Understanding gaps dashboard
    Given a plan review has been generated
    Then the closing section shows a rationale gaps dashboard
    And provides explicit pre-implementation documentation recommendations

# -----------------------------------------------------------------------------

Feature: Project Recap
  As a developer returning to a project after time away
  I want a visual mental model snapshot
  So that I can quickly re-orient and resume productive work

  Background:
    Given the StreamWeaver visual-explainer skill is loaded

  Scenario: Default 2-week recap
    Given the user invokes project-recap with no argument
    When the agent gathers data
    Then it uses a 2-week time window
    And reads README.md, CHANGELOG.md, and project config
    And runs git log --since="2 weeks ago"
    And checks for uncommitted changes and stale branches
    And generates an 8-section StreamWeaver page

  Scenario: Custom time window
    Given the user invokes project-recap with "3m"
    Then the agent uses a 3-month time window

  Scenario: Architecture snapshot as visual anchor
    Given a project recap has been generated
    Then the architecture Mermaid diagram uses hero depth styling
    And labels nodes with what they DO, not just file names

  Scenario: Cognitive debt hotspots surfaced
    Given a project recap has been generated
    Then the cognitive debt section uses amber-tinted cards
    And each hotspot has severity indicator and remediation suggestion

# -----------------------------------------------------------------------------

Feature: Fact Check
  As a developer
  I want to verify generated documents match actual code
  So that I can trust the information in reviews and plans

  Background:
    Given the StreamWeaver visual-explainer skill is loaded

  Scenario: Fact check the most recent output
    Given the user invokes fact-check with no argument
    Then the agent finds the most recently generated page
    And extracts every verifiable claim
    And verifies each against the actual codebase
    And corrects inaccuracies in place
    And adds a verification summary section
    And reports results

  Scenario: Fact check a specific file
    Given the user invokes fact-check for a specific HTML file path
    Then the agent reads that specific file
    And proceeds with the standard verification process

  Scenario: Claims are classified
    Given a fact check is in progress
    Then each claim is classified as Confirmed, Corrected, or Unverifiable
    And the verification summary includes counts for each category

  Scenario: Corrections preserve page structure
    Given corrections are being applied
    Then layout, CSS, and diagrams are preserved
    And only factual content is changed
    And subjective analysis is never modified

# -----------------------------------------------------------------------------

Feature: Share and Deploy
  As a developer
  I want to share generated pages with a live URL
  So that teammates can view them without local access

  Background:
    Given the StreamWeaver visual-explainer skill is loaded

  Scenario: Share a page via Vercel
    Given the user invokes share for a generated HTML file
    And vercel-deploy is available
    Then the HTML is deployed to Vercel
    And a live URL is returned
    And a claim URL for account transfer is returned
    And the deployment is public with 30-day retention

  Scenario: Share a live StreamWeaver page
    Given the user invokes share for a currently running StreamWeaver page
    Then the page is exported as self-contained HTML first
    And then deployed to Vercel

  Scenario: Share without vercel-deploy
    Given vercel-deploy is NOT available
    When the user invokes share
    Then an error message explains the missing dependency

# -----------------------------------------------------------------------------

Feature: Auto-Trigger on Complex Output
  As a developer
  I want complex tabular data automatically rendered visually
  So that I do not have to explicitly request visual treatment

  Background:
    Given the StreamWeaver visual-explainer skill is loaded

  Scenario: Table with 4+ rows triggers visual rendering
    Given the agent is about to present tabular data
    And the table has 4 or more rows
    Then the agent generates a StreamWeaver page instead of ASCII art
    And opens it in the browser
    And may include a brief text summary in the terminal

  Scenario: Table with 3+ columns triggers visual rendering
    Given the agent is about to present tabular data
    And the table has 3 or more columns
    Then the agent generates a StreamWeaver page

  Scenario: Small table does not trigger
    Given the table has fewer than 4 rows AND fewer than 3 columns
    Then the agent renders it as normal text in the terminal

  Scenario: Auto-generated table has proper styling
    Given an HTML table is auto-generated via StreamWeaver
    Then the table has a sticky header
    And alternating row backgrounds
    And row hover highlighting
    And status indicators use styled spans, never emoji
    And wide tables have a scrollable container
