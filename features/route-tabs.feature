Feature: Route Tabs — bookmarkable URL-driven tab navigation
  Add `tabs :key, url: true`: active tab encoded as a query parameter, switched
  client-side via the History API, seeded server-side on full GET. Bookmarks,
  shared links, and back/forward all land on the right tab, in both hosting
  modes. Design is Codex-vetted (see route-tabs.context.md); the pivotal
  decision is client-side pushState over HTMX GET, which dissolves four of the
  eight review P1s. Existing tabs without url: are byte-for-byte unchanged.

  Background:
    Given the StreamWeaver tabs component (DSL app.rb:838-874, renderer alpinejs.rb render_tabs)
    And the canvas-mode precedent from commit e414edc (websocket_mode? suppresses sync POST)

  Scenario: dsl-url-option
    # Intent: The url: option exists, is validated, and invalid combinations fail loudly at build time.
    # RIGOR: strict — validation rules with silent-wrong risk (reserved keys, option conflicts)
    Given an app declares tabs with url: true
    When the DSL is evaluated
    Then the option is stored on the Tabs component
    And declaring url: true with lazy: true raises ArgumentError naming the unsupported combination
    And declaring a url: true key of app_id, splat, or captures raises naming the reserved-key conflict
    And declaring a url: true key already claimed by another url: true tabs group in the same app raises

  Scenario: index-clamp
    # Intent: A stale or malformed active index can never blank the panel area — for ALL tabs, route or plain.
    # RIGOR: strict — numeric edge logic, silent-wrong risk (?key=999 renders zero panels today)
    Given a three-tab group whose state holds index 7
    When the tabs are evaluated
    Then tab 0 renders active with all panels intact
    And negative and non-numeric indices also resolve to tab 0

  Scenario: renderer-url-mode
    # Intent: Route tabs render eagerly and own their history client-side — no HTMX, no hidden input.
    # RIGOR: strict — URL parsing, query merging, popstate, mode branching all carry silent-wrong risk; failing specs first
    Given a tabs group with url: true in http mode
    When render_tabs runs
    Then triggers carry Alpine attributes plus a pushState helper call, and no hx-post/hx-vals/hx-swap
    And no hidden state-sync input is emitted for the group
    And x-data initializes activeTab from location.search with validation and clamping; absent or invalid resolves to tab 0, never the server-rendered index (D2)
    And the pushState helper merges this key into live location.search, preserving unrelated params and other groups' keys
    And a popstate listener re-derives activeTab from the URL
    And in websocket mode the url: option is ignored, plain client tabs render, and one warning is logged per render pass
    And tabs without url: render byte-for-byte identical to the pre-change baseline, asserted by an explicit output-comparison spec, not merely by existing specs staying green

  Scenario: server-param-authority
    # Intent: On full GET the URL is authoritative for route-tab keys — same URL always renders the same tabs.
    # RIGOR: strict — request/state logic with session-leak risk (Codex P1: absent param must not inherit session value)
    Given a page containing tabs :view, url: true
    When it is loaded via GET with ?view=2
    Then the server renders tab index 2 active
    When it is loaded with no view parameter regardless of prior session tab state
    Then tab 0 is active
    And ?view=999, ?view=abc, and ?view[]= all return 200 with tab 0 active
    And two identical GETs with arbitrary tab interactions between them render the same active tab (idempotence — the session-leak regression)
    And the authority contract is applied at tabs evaluation from the request-params snapshot per D8, not via a route-key registry at import time

  Scenario: service-param-seeding
    # Intent: Route tabs behave identically under the multi-app service.
    # RIGOR: strict — same authority/coercion contract applied to a second request path (service.rb GET /apps/:app_id)
    Given the multi-app service hosts an app with tabs :view, url: true
    When /apps/dashboard?view=1 is loaded
    Then tab index 1 renders active, matching standalone-server behavior
    And /apps/dashboard with no view parameter renders tab 0 regardless of prior session state
    And ?view=999, ?view=abc, and ?view[]= under the service all return 200 with tab 0 active

  Scenario: browser-verification
    # Intent: The behaviors only a real browser can prove — history, composition, morph self-correction.
    # RIGOR: loose — MAIN THREAD ONLY per repo rule (subagent playwright-cli fails); screenshots required
    Given the implemented route tabs booted in standalone and service mode
    When verified with playwright-cli from the main session
    Then direct load of ?view=2 lands on tab 2
    And tab clicks update the URL with no network request, and back/forward restore selection
    And two route-tab groups compose: both params in the URL, selections independent
    And a deferred-form submit morph does not revert the visible active tab
    And url: true DSL pushed to a canvas renders working tabs, leaves the URL untouched, and logs the fallback warning

  Scenario: docs-update
    # Intent: Docs reflect the new option and its authority/validation rules.
    # RIGOR: trivial — documented behavior is fully specified by the design
    Given the feature is implemented
    When docs/components_reference.md Tabs section and docs/for_llms.md + llms.txt are updated
    Then they describe url:, URL authority, validation degradation, and the canvas fallback

  Scenario: deprecate-lazy-post-morph
    # Intent: Forrest's "C" — retire the POST-morph lazy mode in favor of future lazy route tabs; trails the epic.
    # NOTE: Forrest-mandated scope beyond the original spec delta, reconciled in openspec proposal.md 2026-08-20;
    #       the warning is the only behavior change and supersedes the "no behavior change" promise for this mode only.
    # RIGOR: loose — deprecation warning + docs + compat lock, no other behavior change
    Given route tabs are shipped
    When lazy: true (without url:) is used
    Then a deprecation warning names the future lazy-route-tabs replacement
    And existing lazy behavior is unchanged and covered by a compat spec
    And docs mark the mode deprecated with the migration story
