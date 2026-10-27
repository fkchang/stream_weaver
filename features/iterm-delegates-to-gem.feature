Feature: StreamWeaver delegates its iTerm browser panes to iterm2_ruby 0.4
  StreamWeaver::ITerm carries its own copy of the browser-pane override and the plugin and setting probes that iterm2_ruby 0.4.0 now owns. Delete the copy, call the gem, and keep every fallback.

  Scenario: iterm-delegates-browser-split-to-gem
    # RIGOR: strict — a behaviour-preserving refactor over a live terminal: a plausible wrong version opens the pane in the wrong place or fails silently
    # Intent: One implementation of the browser-pane trick, in the gem, with StreamWeaver keeping only its guards and fallbacks.
    As a StreamWeaver user running canvases from iTerm
    In order to get the same split pane from a single maintained implementation
    I want StreamWeaver to open browser panes through iterm2_ruby
    Given StreamWeaver running inside iTerm on macOS with iterm2_ruby 0.4 or newer installed
    When it opens a browser pane for a canvas panel, the get-started controller window, or a worker tab
    Then every browser pane is made with the gem's split_browser_pane, and the calling pane is found with ITerm2.current_session_id
    And lib/stream_weaver/iterm.rb no longer holds its own copy of the Custom Command and Initial URL overrides, the plugin bundle id, the preference key, or the mdfind and defaults probes
    And the plugin and browser-profile checks come from ITerm2::Browser, so a plugin in the usual folders never depends on a Spotlight timeout
    And with an iterm2_ruby older than 0.4 it falls back to the system browser, says the gem needs 0.4 or newer, and never raises
    And outside iTerm, off macOS, or with the gem absent behaviour is unchanged: the system browser opens and the URL is printed
    And the Gemfile pins iterm2_ruby ~> 0.4 and the gemspec's optional-gem note names 0.4
    And the existing iTerm specs are updated to assert delegation, the too-old-gem fallback and the unchanged fallbacks, and the full suite stays green
    And a real run of streamweaver panel opens a split pane beside the calling session in iTerm, checked live
