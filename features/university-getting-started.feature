Feature: University Getting Started — one door, premier iTerm experience, driver canvas + worker session
  A coworker (Brett, developer) saw the docs + canvas demo and wants it. He runs
  `gem install stream_weaver && streamweaver get-started` and lands in a split-pane
  iTerm2 canvas that drives a worker Claude Code session through five steps that
  show where StreamWeaver beats the TUI. A non-developer coworker gets the same
  docs via gist + Chrome extension with no install. Trilaws are hard constraints:
  one door (Forrest), course list as table of contents (Matt), persisted progress
  and re-runnable steps with a visible payoff each (Gloria).

  Background:
    Given the repo already ships `streamweaver setup`, `panel`, `canvas-push`, `canvas-wait`,
      `canvas-read`, `export`, `org-export`, the `extension/` doc viewer, and `install-skill`
    And `iterm2_ruby` (optional gem) provides `iterm2ctl` for tab create / send-text
    And the roadmap and surveys live in docs/university/

  Scenario: readme-extension-webstore
    # Intent: non-developer coworkers read org docs on gists/repos with the Chrome Web Store extension, no install
    # RIGOR: trivial — doc edit with given URL and framing
    Given README.md has a Browser Extension section that only documents "load unpacked"
    When the section is updated
    Then the Chrome Web Store listing (odjjednfpfiagefgpcfdlelldphmpcgj) is the primary install path
    And "load unpacked" is labeled as the dev path
    And a "Share a doc" recipe explains gist = quick collab (gist link + extension link)
    And the level-up is committing the same .org to the team repo where it renders identically

  Scenario: install-skill-covers-all-skills
    # Intent: install-skill silently skips visual-plan and visual-recap
    # RIGOR: trivial — hash entries in cli.rb ~2056 + summary text
    Given `streamweaver install-skill` runs
    Then visual-plan and visual-recap are installed alongside the other gem skills
    And the printed summary lists every installed skill

  Scenario: get-started-door-command
    # Intent: one command installs, checks, opens the premier surface, launches the worker
    # RIGOR: loose — CLI plumbing extending existing setup, OS-gated branches
    Given a fresh macOS user has installed the gem
    When they run `streamweaver get-started`
    Then skills are installed to the Claude and .agents roots (existing setup behavior)
    And core deps are verified (Ruby version, canvas bridge startable)
    And iTerm2 + iterm2_ruby + iTerm2 Python API are checked
    And if any premier dep is missing, exact install steps and a loud "full experience needs iTerm2" warning are printed
    And the command only continues without them on explicit `--degraded` or an interactive "continue anyway"
    And on the premier path a canvas split pane opens and a worker tab starts `claude` (or `codex` when chosen)
    And on the degraded path a browser tab opens with instructions to place a second terminal beside it
    And the course-list canvas is pushed last in both paths

  Scenario: course-canvas-design
    # Intent: the getting-started app must look really good — it IS the first impression of StreamWeaver
    # RIGOR: loose — design prework; run frontend-design / design-html / design-review skills before building
    Given the course list and step screens are not yet built
    When a design pass runs using the frontend-design skill (and design-review for critique) against StreamWeaver's :doc theme and components
    Then docs/university/design-spec.md records the visual direction: typography, hierarchy, step cards, progress treatment, Run/Repeat affordance, disabled-course treatment, light/dark
    And a StreamWeaver mockup of the course list and one step screen is pushed to a canvas and approved by Forrest before course-list-canvas starts
    And the spec names which existing components/theme tokens to use and which gaps need new CSS on sw- hooks

  Scenario: course-list-canvas
    # Intent: the table of contents — Getting Started enabled, future courses visible but disabled
    # RIGOR: loose — canvas app, render-only
    Given get-started has opened the surface
    Then the canvas lists Getting Started as enabled with its five steps and progress
    And future courses (docs deep dive, canvas modes, skills & panels) appear disabled with a one-line blurb each
    And the existing `streamweaver tutorial` is linked as "the classic component tour (older, being refreshed)"

  Scenario: progress-ledger
    # Intent: resume where you left off, repeat any step
    # RIGOR: loose — YAML state + canvas rendering
    Given ~/.streamweaver/university/progress.yml may or may not exist
    When the course canvas renders
    Then completed steps are marked and the next unfinished step is highlighted
    And every step, done or not, offers Run/Repeat
    And marking a step done persists across bridge restarts

  Scenario: driver-worker-runner
    # Intent: the canvas drives the worker session — no teacher LLM, deterministic
    # RIGOR: strict — send-text tab targeting can silently hit the wrong tab; must be tested
    Given the premier path launched a worker tab whose iTerm session id was recorded
    When the user clicks Run on step N
    Then step N's prompt is sent to exactly that worker tab via iterm2ctl send-text
    And a wrong or closed target is detected and reported on the canvas, never sent elsewhere
    And in degraded mode the canvas instead shows the prompt with a copy button and paste instructions

  Scenario: step-1-canvas-push
    # Intent: the "it just appears, no HTML" moment
    # RIGOR: loose — course content + prompt
    When step 1 runs in the worker
    Then a hello card appears in the split pane via canvas-push

  Scenario: step-2-dsl-reexec
    # Intent: mental model — the DSL block re-executes on every interaction
    # RIGOR: loose — course content
    When step 2 runs
    Then the worker creates and runs the 6-line minimal app and the user changes a counter

  Scenario: step-3-form-modes
    # Intent: stateful form vs blocking form — what a TUI can't do
    # RIGOR: loose — course content; avoid checkbox_group/chip_group multi (disc-098, disc-105)
    When step 3 runs
    Then the same form is shown as a stateful canvas form and as a blocking canvas-wait form
    And the worker prints the value it received from the blocking form

  Scenario: step-4-growing-doc
    # Intent: a document that grows over time, then save + history
    # RIGOR: loose — course content
    When step 4 runs
    Then the worker runs a script that appends sections to a canvas doc over several pushes
    And the doc is saved and its versions are reviewed in canvas-read

  Scenario: step-5-org-portability
    # Intent: the closer — export, gist, extension; native org vs StreamWeaver rendering
    # RIGOR: loose — course content; export must avoid disc-094 chart shorthands
    When step 5 runs
    Then the step-4 doc is exported to .org and pushed to a gist
    And the user opens it once with plain GitHub rendering and once with the extension

  Scenario: coworker-install-blurb
    # Intent: the message Forrest sends
    # RIGOR: trivial — doc
    Then docs/university/send-to-coworker.md holds a developer blurb (one paragraph, three commands)
    And a non-developer blurb (gist link + extension link)

  Scenario: verify-codex-skill-pickup
    # Intent: Codex is the second worker; confirm it sees .agents/skills
    # RIGOR: strict — an unverified claim ships a broken promise
    Given Codex is installed locally
    When a fresh Codex session is asked to push a canvas
    Then it triggers the streamweaver skill from ~/.agents/skills, or the legacy ~/.codex/skills mirror is added

  Scenario: clean-room-walkthrough
    # Intent: the gate — a fresh user reaches every payoff from the blurb alone
    # RIGOR: strict — gate; evidence in ledger
    Given a clean user account or machine with only Ruby and iTerm2
    When the developer blurb is followed verbatim
    Then every step reaches its payoff and progress resumes after closing and reopening
    And any friction hit is filed as a story or discovery before the epic closes

  Scenario: university-extension-registry
    # Intent: Let installed gems explicitly contribute StreamWeaver capabilities without hard-coded dependencies.
    # RIGOR: strict — loader ordering, isolation, and duplicate identity can fail silently
    Given an installed gem declares a versioned StreamWeaver extension loader in gem metadata
    When StreamWeaver discovers extensions
    Then only metadata-declared loaders are required in deterministic gem-name order
    And repeated discovery is idempotent
    And duplicate extension IDs raise an actionable duplicate-registration error
    And a broken extension is reported without preventing built-in University courses from loading

  Scenario: university-course-catalog
    # Intent: Let University display built-in and integration-owned courses through one validated contract.
    # RIGOR: strict — provider normalization and validation define a new public extension contract
    Given StreamWeaver has its built-in course and zero or more registered course providers
    When University builds its course catalog
    Then every course has a unique ID, title, blurb, ordered steps, and demo resolver
    And the existing Getting Started course remains behavior-compatible
    And registered courses appear on the course shelf
    And absent integrations leave no dead or placeholder course
    And invalid provider data is rejected with the provider ID and failing field

  Scenario: university-multi-course-execution
    # Intent: Run, resume, complete, reset, and resolve demos independently for each course.
    # RIGOR: strict — course identity must survive every CLI, progress, runner, and listener path
    Given the catalog contains more than one course
    When a user runs University commands for a selected course
    Then progress is persisted under that course ID without changing another course
    And the runner sends the selected course step prompt
    And university-demo resolves that course's packaged demo
    And commands without a course ID retain the current Getting Started behavior

  Scenario: slim-graph-r-university-provider
    # Intent: Teach diagram intent through installed SlimGraphR demos while keeping both gems independent.
    # RIGOR: strict — cross-gem packaging and discovery need isolated-install evidence
    Given StreamWeaver and SlimGraphR are installed
    When StreamWeaver discovers declared extensions
    Then University lists "Diagram Intent with SlimGraphR"
    And its packaged steps demonstrate standalone rendering, semantic diagram choices, and StreamWeaver composition and export
    And each demo resolves from the installed SlimGraphR gem without a source checkout
    And SlimGraphR still installs and renders without StreamWeaver
    And StreamWeaver's built-in Getting Started course remains behavior-compatible when SlimGraphR is present

  Scenario: first-class-slim-graph-r-diagrams
    # Intent: Make SlimGraphR the built-in diagram engine for every ordinary StreamWeaver runtime.
    # RIGOR: strict — dependency direction, load order, and isolated installs can break both gems
    Given a user installs StreamWeaver without separately installing integrations
    When StreamWeaver loads its shared DSL in an app, canvas, Canvas Reader, or exporter
    Then diagram is available without an explicit SlimGraphR require
    And StreamWeaver declares a compatible SlimGraphR runtime dependency
    And SlimGraphR core still installs and renders without StreamWeaver
    And the generic extension registry remains available to third-party gems

  Scenario: complete-diagram-atlas
    # Intent: Give humans one executable visual reference for every SlimGraphR chart available inside StreamWeaver.
    # RIGOR: strict — 39 heterogeneous fixtures must remain complete, readable, packaged, and executable
    Given StreamWeaver includes SlimGraphR diagram support
    When a user runs streamweaver diagrams
    Then a packaged Diagram Atlas opens without a source checkout
    And all 39 SlimGraphR types render as real StreamWeaver diagram components
    And every example includes executable Ruby, use guidance, and honest limits
    And the atlas renders in a live canvas, Canvas Reader, and exported HTML
    And the existing three-step University course links users to the atlas instead of duplicating 39 lessons

  Scenario: chrome-extension-slim-graph-r-diagrams
    # Intent: Render saved StreamWeaver documents containing SlimGraphR diagrams in the offline Chrome extension viewer.
    # RIGOR: strict — Opal parity, MV3 sandbox CSP, bundle size, and 39 renderers can fail silently
    Given the StreamWeaver Chrome extension is built with its packaged offline runtime
    When the viewer opens a saved Ruby or Org document containing SlimGraphR diagrams
    Then the sandbox renders self-contained inline SVG without a Ruby server or network access
    And all 39 packaged atlas types compile and render through the browser-safe SlimGraphR entrypoint
    And accessible titles and descriptions survive the viewer pipeline
    And extension CSP reports no diagram-related errors

  Scenario: visual-companion-diagram-guidance
    # Intent: Make Visual Companion select and write SlimGraphR diagrams as a token-efficient first-class visual primitive.
    # RIGOR: loose — progressive-disclosure guidance backed by executable examples
    Given the installed Visual Companion skill can use StreamWeaver diagrams
    When an agent chooses a visual form for relationships, systems, plans, strategy, or quantitative data
    Then a compact reference maps the intent to an appropriate SlimGraphR family
    And the skill points to exact minimal DSL without loading the complete atlas into context
    And a clean-room agent can build representative diagrams using only the skill and its referenced resource
