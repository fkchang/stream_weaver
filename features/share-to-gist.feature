Feature: Share to Gist — bounce a canvas doc off a coworker before committing to it
  The floating Save-as-doc dialog (SaveDocWidget, save_doc_widget.rb) answers "where do
  I keep this?" via This-repo/Global radios. It has no answer for "let me show this to
  someone before I commit to it." Add Gist as a third destination radio in the SAME
  dialog: publish both a rendered .org and the re-runnable .rb to one secret GitHub
  gist via `gh api`, auto-copy the URL, and remember the gist by doc name so the next
  save from the same canvas updates the same link instead of minting a duplicate.
  Full design: docs/plans/giggly-humming-token.md (or the plan the coordinator was
  given — see epic context note).

  Background:
    Given `gh` 2.65.0 authenticated with the `gist` scope, already confirmed present
    And the existing scope toggle in save_doc_widget.rb:266-277 (repo/global radios)
    And DocStore's atomic-write + normalize_name pattern (doc_store.rb) as the model to mirror
    And Org::Writer (org/writer.rb) for DSL -> org-mode text + coverage, reused as-is

  Scenario: gist-store
    # Intent: persistent id/url/revision-count lookup keyed by doc base name, so a second
    # save from the same canvas knows which gist to PATCH instead of creating a new one.
    # RIGOR: loose — a straightforward mirror of DocStore's already-proven persistence idiom
    Given lib/stream_weaver/canvas/doc_store.rb's atomic tmp-then-rename write and ENV-override pattern
    When lib/stream_weaver/canvas/gist_store.rb is created
    Then it persists JSON at ~/.streamweaver/canvas/gists.json, overridable via STREAMWEAVER_GIST_STORE
    And it exposes lookup(name), record(name, id:, url:, revisions:), latest_for_prefix(prefix), all, forget(name)
    And writes are atomic (tmp file + rename), matching DocStore.save's crash-safety
    And a spec (spec/canvas/gist_store_spec.rb) covers record/lookup/latest_for_prefix/forget and the ENV override

  Scenario: gist-publisher
    # Intent: the one place that shells out to `gh` and talks to GitHub's API. Both files
    # (.org rendered doc + .rb re-runnable source) go up in ONE api call so one save = one
    # gist revision, keeping the revision timeline meaningful.
    # RIGOR: strict — shell-out + network + an external, user-visible write; the only
    # story in this epic where a bug ships wrong content to a URL a coworker will open
    Given DocStore.normalize_name for name validation and DocStore.dsl_with_metadata for the .rb payload
    And Org::Writer#call/#coverage for the .org payload, identical to bridge_server.rb:164-166's existing use
    And Open3.capture3 with array argv (bin/browser_smoke.rb:100-104 is the in-repo model) — no shell string, ever
    When lib/stream_weaver/canvas/gist_publisher.rb is created with publish(name:, dsl:, theme:, layout:, existing_id: nil)
    Then a create builds `{name}.org` and `{name}.rb` in one `gh api -X POST /gists --input -` call, secret (no `public` key)
    And an update (existing_id present) issues one `gh api -X PATCH /gists/<id> --input -` call with both files, never two separate `gh gist edit` calls
    And the call is wrapped in Timeout.timeout so a network stall cannot hang the Sinatra request thread
    And a 404 on update (gist deleted upstream) falls back to create and returns a signal to forget the stale id, rather than raising
    And gist visibility is never sent on a PATCH (visibility is immutable after creation on GitHub's API)
    And gh_available? does a cheap presence check (not an auth check) so a missing gh CLI surfaces as one clear error, not a stack trace
    And non-zero gh exit returns {ok: false, error:} with gh's auth-failure stderr mapped to actionable copy naming `gh auth login` and the `gist` scope
    And a spec (spec/canvas/gist_publisher_spec.rb) stubs Open3.capture3 and asserts: exact array argv, both files present under the right base name, POST vs PATCH by existing_id, no `public` key ever, the 404-fallback-to-create path, and non-zero exit shape — no spec touches the real network

  Scenario: save-doc-widget-gist
    # Intent: Gist joins This-repo/Global as a third radio in the SAME dialog — no new
    # button, no format question when Gist is chosen (both files always go up together).
    # RIGOR: loose — UI/Alpine wiring on an established, already-spec'd component
    Given save_doc_widget.rb's existing scope_toggle_html (repo/global radios) and orgNotice() (org-coverage amber notice)
    When SaveDocWidget.render gains a gist: kwarg (available:, unavailable_reason:, known: {name => {url, revisions}}, prefill_name:)
    Then the radio row renders when EITHER source_dir OR gist is present (today it renders only on source_dir)
    And a disabled Gist radio shows unavailable_reason when gh is not available, rather than hiding the option
    And selecting Gist hides the Save / Save-as-Org button pair and shows one Create-gist/Update-gist button
    And the button reads "Update gist" when the typed name matches a known gist, "Create gist" otherwise — live as the name field is edited
    And openDialog() prefills gistPrefill (the already-shared name) instead of a fresh timestamp, when a gist is already known for this canvas
    And scope never defaults to 'gist' — This-repo/Global remain the only defaults, exactly as today
    And on a successful gist save the dialog does NOT auto-close (URL is the payload): shows the URL, auto-copies it to the clipboard via a try/catch-guarded navigator.clipboard call, and shows Open-gist / Revisions links (Revisions -> <gist_url>/revisions)
    And spec/canvas/save_doc_widget_spec.rb is updated: Gist radio present with gist:, absent without; disabled+reason when unavailable; scope never initializes to 'gist'

  Scenario: bridge-canvas-gist-endpoint
    # Intent: wire GistStore + GistPublisher into the live canvas's POST /save-doc so
    # scope: 'gist' actually publishes, exactly the way scope: 'repo'/'global' already
    # writes files today.
    # RIGOR: loose — integration wiring over two already-tested collaborators; the risky
    # logic (shell-out, stale-id recovery) is proven in gist-publisher's own spec
    Given bridge_server.rb:144-200's existing POST /canvas/:name/save-doc (format/scope handling for rb/org)
    And bridge_server.rb:310-336's save_doc_widget(session_name, session) call site
    When scope == 'gist' is handled before the existing format branch
    Then it calls GistPublisher.publish using session.dsl/theme/layout and GistStore.lookup's existing id for this doc name
    And a successful publish calls GistStore.record and returns {ok:true, gist_url:, gist_id:, revisions:, action:, coverage:}
    And a GistStore.record write failure does NOT fail an otherwise-successful publish — it returns ok:true with a warning: string instead
    And save_doc_widget(session_name, session) passes gist: built from GistPublisher.gh_available? and GistStore.latest_for_prefix(session_name)
    And error mapping matches the existing rb/org branches' shape: ArgumentError -> 422, publisher failure -> 502, other StandardError -> 500
    And spec/canvas/bridge_save_doc_gist_spec.rb covers: 200 with gist_url on scope:'gist', 404 no session, 422 no dsl, 502 on publisher failure — following bridge_save_doc_spec.rb's Dir.mktmpdir + ENV around-hook idiom, no real gh call

  Scenario: reader-gist-parity
    # Intent: canvas-read's history-promotion Save-as-doc gets the same Gist option as
    # the live canvas, so a snapshot can be shared without first reopening the live session.
    # RIGOR: loose — mirrors bridge-canvas-gist-endpoint's now-settled pattern; parity is
    # exactly what spec/canvas/canvas_action_parity_spec.rb exists to catch
    Given reader.rb:583-639's existing POST /save-doc (format/scope handling, reading the history snapshot at :614)
    And reader_layout.erb:572-599's existing save_doc_widget call site (is_history-gated)
    When the reader's POST /save-doc gets the same scope == 'gist' branch as the bridge endpoint, calling the identical GistPublisher/GistStore contract
    Then reader_layout.erb passes gist: the same way bridge_server.rb does, keyed to the doc's own name (not session-scoped, since the reader has no live session)
    And the existing note (reader.rb:608-613) that history snapshots carry no session theme/layout still holds — no dsl_with_metadata injection for gist publishes from the reader either
    And spec/canvas/canvas_action_parity_spec.rb is extended (or a sibling spec added) to assert the bridge and reader gist branches produce equivalent behavior for the same DSL input
    And spec/canvas/reader_promote_history_spec.rb gains gist-scope coverage following its existing FileList/configure_files! fixture idiom
