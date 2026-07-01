Feature: Doc Parity — :doc theme, component polish, dark mode, content 1:1
  Make StreamWeaver's Ruby DSL produce an apples-to-apples match of the
  Anthropic "Calendar-Driven Travel State" HTML PRD artifact. Add a new :doc
  built-in theme ported 1:1 from the artifact CSS, fix visual regressions
  (sticky sidebar, TOC numbers, dark mermaid, table/card styling), reach
  content parity, support :doc in canvas mode, and ship a reusable agent skill.

  Reference artifact: docs/reference/travel-state-prd.artifact.html
  Resume checkpoint: docs/sw-doc-parity-checkpoint.md

  Background:
    Given a StreamWeaver project with DocHeader, DocSectionHeader, SidebarToc components built
    And examples/components/prd_demo.rb running as a standalone :document theme app
    And examples/components/prd_dsl.rb as the inner DSL body for canvas-push
    And the Anthropic artifact at docs/reference/travel-state-prd.artifact.html as design spec

  # ── PHASE 1 ────────────────────────────────────────────────────────────────

  Scenario: doc-theme-light
    # Intent: Add body.sw-theme-doc { } to views.rb with artifact-exact CSS tokens.
    # Base 15px sans, 1.65 line-height, serif only for titles, compact spacing.
    # RIGOR: medium — new theme block alongside default/dashboard/document
    Given the artifact CSS tokens: bg #F5F4EF, accent #1E4ED8, serif Charter stack, sans system, mono SFMono
    When body.sw-theme-doc is added to views.rb after the existing theme blocks
    Then app "Title", theme: :doc renders with bg #F5F4EF and 15px sans base
    And section titles render in Charter serif at ~1.45rem
    And body/container padding matches the artifact compact spacing (~52px section gap)
    And the new theme does not affect :default, :dashboard, or :document themes

  Scenario: doc-theme-dark
    # Intent: Add body.sw-theme-doc[data-sw-theme="dark"] dark variant.
    # Designed dark: warm near-black bg, same accent at higher brightness.
    # RIGOR: medium — mirrors light variant with dark token overrides
    Given the :doc light theme is registered
    When data-sw-theme="dark" is set on <html> in a :doc app
    Then bg shifts to warm near-black #1A1714, surface #232019
    And text remains readable at near-white #ECEAE3
    And accent shifts to #6699FF for sufficient contrast
    And callout/border/code-bg tokens flip correctly

  Scenario: register-doc-theme
    # Intent: Add :doc to BUILT_IN_THEMES allowlist in app.rb and theme.rb.
    # RIGOR: trivial — add symbol to two constant arrays
    Given the :doc CSS block exists in views.rb
    When :doc is added to BUILT_IN_THEMES in app.rb lines 11-12 and 49-53
    And :doc is added to BUILT_IN_THEMES in theme.rb line 152
    Then app "Title", theme: :doc boots without error
    And theme metadata is available to ThemeSwitcher

  # ── PHASE 2 ────────────────────────────────────────────────────────────────

  Scenario: toc-numbers
    # Intent: Add CSS counters to sidebar_toc so links show 01 02 … prefix.
    # Pure CSS, zero Ruby change — counter on nav, ::before on links.
    # RIGOR: trivial — 6 lines of CSS in sidebar_toc_css
    Given sidebar_toc renders .sw-sidebar-toc__link elements
    When CSS counters are added: counter-reset on nav, counter-increment + decimal-leading-zero on ::before
    Then each TOC link displays its zero-padded number (01, 02 … 11) in mono/faint color
    And the counter is purely presentational — no data change

  Scenario: sticky-sidebar
    # Intent: Replace float+negative-margin hack with CSS grid (220px 1fr) + align-self:start.
    # align-self:start on sidebar is the load-bearing fix for position:sticky inside grid.
    # RIGOR: medium — affects layout for all docs using sidebar_toc; verify mobile bar still works
    Given the sidebar scrolls away on the current float+margin-left:-224px implementation
    When the doc container becomes grid-template-columns: 220px minmax(0,1fr) when sidebar_toc is present
    And .sw-sidebar-toc gets position:sticky; top:2rem; align-self:start; grid-column:1
    Then scrolling the page leaves the TOC visible at a fixed position
    And the doc_header spans grid-column: 1 / -1 (full width)
    And on screens <1000px the existing horizontal-bar responsive layout is preserved

  Scenario: table-caps-blue
    # Intent: Edit render_table inline styles so th is uppercase + table-dim color,
    # and td:first-child is accent-blue monospace. CSS overrides won't work (inline wins).
    # RIGOR: trivial — edit two style strings in alpinejs.rb render_table method
    Given table th inline style at alpinejs.rb line ~1143 has only font-weight:600
    When text-transform:uppercase; letter-spacing:.07em; color:var(--sw-color-text-dim) are added to th_style
    And col_idx==0 td gets color:var(--sw-color-accent); font-family:monospace; font-size:.8rem
    Then table headers render ALL-CAPS in dim color
    And the first column of each row renders in accent blue monospace

  Scenario: card-header-badge-meta
    # Intent: Add badge: and meta: options to card_header DSL so C1/C2/C3 headers
    # render a colored badge + title + right-aligned meta, matching the artifact.
    # RIGOR: medium — touches CardHeader component, card_header DSL method, card-header CSS
    Given card_header currently renders a plain div with no layout
    When card_header "C1 — Title", badge: "C1", meta: "scheduler secretary" is called
    Then the header renders as a flex row: badge | title | meta (margin-left:auto)
    And the badge uses accent-bg + accent-text, mono font, ~11px
    And existing card_header calls without badge:/meta: are unaffected

  Scenario: mermaid-dark-fix
    # Intent: Unify dark signal so data-sw-theme="dark" is always set when dark is active.
    # ThemeSwitcher currently only sets .dark class; mermaid reads data-sw-theme exclusively.
    # RIGOR: medium — touches ThemeSwitcher toggle in alpinejs.rb + verify init order
    Given ThemeSwitcher dark toggle at alpinejs.rb lines 2050-2057 sets only .dark class
    And mermaid getMermaidTheme() at sw-mermaid-zoom.js line 30 reads data-sw-theme only
    When ThemeSwitcher toggle also sets document.documentElement.dataset.swTheme = "dark"/"light"
    Then toggling dark via ThemeSwitcher makes mermaid re-render with dark theme
    And mermaid renders correctly in both light and dark modes
    And AutoMode (which already sets both .dark and data-sw-theme) is unaffected

  Scenario: theme-toggle-light-default
    # Intent: Add visible theme_toggle to prd_demo.rb and force light default.
    # App currently inherits OS dark via AutoMode; PRD should default to light.
    # RIGOR: trivial — add theme_toggle call to prd_demo.rb; set data-sw-color-scheme preference
    Given prd_demo.rb has no visible theme control and renders dark on a dark-OS machine
    When theme_toggle is added to the doc (after doc_header)
    Then the page opens in light mode regardless of OS preference
    And a visible toggle lets users switch to dark

  # ── PHASE 3 ────────────────────────────────────────────────────────────────

  Scenario: prd-content-1to1
    # Intent: Bring prd_dsl.rb content to full parity with the artifact.
    # Add missing sub-sections: C1 entry-format code blocks + type-inference table,
    # C2 sources/detection/schedule/staleness, C3 when-to-show/skip/correction,
    # Data Model second context file, Integrations staleness-check Ruby block.
    # RIGOR: medium — content edit only, no component changes
    Given prd_dsl.rb is a condensed version of the artifact content
    And docs/reference/travel-state-prd.artifact.html is the content source of truth
    When each artifact section is compared and the missing content is added to prd_dsl.rb
    Then every artifact section, sub-section, and code block is present in the StreamWeaver version
    And component choices match artifact structure (callout→callout, table→table, code→code_block)

  Scenario: shared-dsl-dedup
    # Intent: Make prd_demo.rb load prd_dsl.rb as its body so standalone + canvas stay in sync.
    # Single source of truth for content; demo just wraps it in app "Title", theme: :doc do...end.
    # RIGOR: trivial — require_relative + inline the DSL body via instance_eval or load
    Given prd_demo.rb and prd_dsl.rb have duplicated content
    When prd_demo.rb is refactored to load prd_dsl.rb as its body
    Then changing content in prd_dsl.rb is reflected in both standalone and canvas-push runs
    And ruby examples/components/prd_demo.rb still boots and renders correctly

  # ── PHASE 4 ────────────────────────────────────────────────────────────────

  Scenario: canvas-theme-support
    # Intent: Let canvas sessions use :doc theme (currently hardcodes sw-theme-default).
    # Add theme attr to Session, plumb through bridge create_session, inject in bridge_server body class.
    # RIGOR: medium — touches session.rb, bridge.rb, bridge_server.rb
    Given canvas body at bridge_server.rb:236 hardcodes class="sw-theme-default sw-layout-..."
    When Session gains a theme attribute defaulting to :default
    And streamweaver panel <name> --theme=doc sets session.theme = :doc
    Then the canvas body class becomes sw-theme-doc
    And the :doc CSS tokens + dark variant are available in canvas mode
    And mermaid dark fix is active (data-sw-theme set correctly)

  Scenario: save-as-doc-verify
    # Intent: Confirm the existing Save as doc flow round-trips correctly with :doc theme.
    # canvas-push PRD → click Save as doc → confirm docs/streamweaver_canvas/prd-test.rb written.
    # RIGOR: verification only — no code change expected, just confirm end-to-end
    Given a canvas session prd-test with :doc theme running the prd_dsl.rb content
    When the Save as doc button is clicked in the canvas UI
    Then docs/streamweaver_canvas/prd-test.rb is written with the DSL body
    And the saved file can be re-pushed to produce identical output

  # ── PHASE 5 ────────────────────────────────────────────────────────────────

  Scenario: streamweaver-doc-builder-skill
    # Intent: Ship a reusable SKILL.md teaching agents to build editorial docs.
    # Covers: when to use :doc, full component vocabulary, shared-DSL pattern,
    # canvas workflow, token-economics rationale, copy-paste template.
    # RIGOR: medium — new file, no code change
    Given no skill exists for building document-style StreamWeaver apps
    When lib/stream_weaver/skills/streamweaver-doc-builder/SKILL.md is created
    Then the skill covers: theme :doc, doc_header/doc_section_header/sidebar_toc/callout/table/card/comparison/code_block/mermaid
    And documents the shared-DSL pattern (one prd_dsl.rb body for both standalone + canvas-push)
    And covers the canvas workflow: panel → canvas-push → interact → Save as doc
    And includes a minimal copy-paste template an agent can adapt in <5 minutes

  # ── PHASE 6 ────────────────────────────────────────────────────────────────

  Scenario: ruby-vs-react-doc-seed
    # Intent: Seed a blog post: Ruby thinking made this the obvious ask.
    # Angles: token savings (~160 DSL vs ~780 HTML), DSL as right abstraction,
    # React/TS groupthink overhead, canvas interactivity + Save as doc advantage,
    # Forrest's 10th Rule applied to doc generation.
    # RIGOR: low — draft only, docs/blog/ directory
    Given no blog seed exists for this insight
    When docs/blog/ruby-docs-beat-react-artifacts.md is created
    Then it covers: token economics, DSL-as-abstraction, React/TS ceremony overhead
    And the canvas + Save-as-doc capabilities the static artifact lacks
    And Forrest's 10th Rule as the meta-point

  # ── PHASE 7 (post-parity) ──────────────────────────────────────────────────

  Scenario: sanitize-prd-content
    # Intent: Replace personal travel details with neutral placeholder content before committing.
    # Must happen AFTER visual parity is confirmed so we're rewriting a verified good example.
    # RIGOR: content edit — then remove gitignore entries for prd_demo.rb and prd_dsl.rb
    Given prd_demo.rb and prd_dsl.rb contain personal travel/location details
    And visual parity with the Anthropic artifact has been confirmed
    When the content is rewritten with neutral placeholder names/locations/dates
    And the gitignore entries for the personal files are removed
    Then prd_demo.rb and prd_dsl.rb can be committed to the public repo
    And docs/reference/travel-state-prd.artifact.html is either sanitized or replaced with a CSS-only extract

