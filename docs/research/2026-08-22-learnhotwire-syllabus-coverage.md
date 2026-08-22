# learnhotwire.com Full Syllabus vs. StreamWeaver: Coverage Matrix

Extends `docs/research/2026-08-17-hotwire-concept-map.md` (13 concepts, still the deeper prose
treatment for its topics — read it first) from a hand-picked concept list to the **full
learnhotwire.com course syllabus** (8 sections, ~70 lessons). Reuses that map's findings
verbatim where a syllabus item maps onto one of its 13 concepts; every row below cites the
concept-map section number it draws from, or says "new" when the item wasn't covered there.

**Since the concept map was written (2026-08-17), the route-tabs epic shipped** (2026-08-21,
8/8 stories — `cd27596`, `9695b94`, `d3d79e2`, etc., `CHANGELOG.md` Unreleased). This upgrades
concept-map §11 from "HAVE, narrow gap" to a fuller HAVE: `tabs :key, url: true` gives
client-side pushState/popstate tab routing with server-authoritative GET parsing, and the old
`lazy: true` POST-morph tab mode is now deprecated in favor of a future lazy-route-tabs
replacement (not yet built — see Recommended story additions).

**Also found while grounding this matrix, not in the concept map**: `form_for`
(`lib/stream_weaver/app.rb:598`, shipped 2026-07-10, `af351f3`, "FAC-P3.2a") is a real
block-yielding, resource-bound form builder — seeds from a record, infers create-vs-update,
renders fields via `Resource::FieldInput`, validates, and wires submit to
coerce→validate→store→PRG transition. The concept map's §10 says Rails-style `form_with(model:)`
binding "is not yet implemented... on the roadmap" — that claim is **stale**; `form_for` is
that primitive, already shipped and predates the concept map by five weeks. It is real code but
under-documented: not mentioned in `docs/resource-dsl.md` or `docs/for_llms.md`, only in
`docs/streamweaver-frontend-vision.md` and an old design doc. Rows below use `form_for`, not
"missing," wherever the syllabus calls for record-bound forms.

**learnhotwire/rails repo**: fetched via `gh api` (WebFetch 404'd — GitHub blocks the plain
HTML fetch, `gh` reads the API fine). It's Rails' actual "My Todos" app: models
`Project`/`Todo`/`User`/`Membership`/`Session`; `Todo` uses `acts_as_list scope: :project`
(drag-reorder), `broadcasts_refreshes_to :project`, and `after_create_commit`/
`after_update_commit`/`after_destroy_commit` callbacks calling `broadcast_action_later_to`/
`broadcast_replace_later_to`/`broadcast_remove_to` against a single `_todo.html.erb` partial.
Stimulus controllers present: `autogrow`, `autosubmit`, `hello` (word-count-from-scratch demo),
`reset_form`, `sortable` (drag-and-drop), `tabs`/`tabs2`, `todo`, `todolist`, plus a `bridge/`
dir for native app bridging (out of syllabus scope, not covered below). Parity-demo column
below is grounded in this actual structure, not invented from the syllabus text alone.

---

## 1. Turbo Drive

| Course lesson(s) | What it teaches | StreamWeaver equivalent today | Status | Parity demo |
|---|---|---|---|---|
| Importmaps with Rails | Rails' zero-bundler JS dependency loading | N/A — StreamWeaver ships zero app-authored JS; all framework JS is inline `<script>`/CDN, no importmap concept exists to replace | N-A-BY-DESIGN | n/a |
| Enabling Turbo Drive; History pushState | Boosted `<a>`/form nav updates URL+history without full reload | `hx-boost="true"` at `<body>`, reference impl `lib/stream_weaver/views/canvas/reader_layout.erb` (concept map §1); separately, `route_by`/`route_with`/`tabs url:` push `HX-Push-Url`/client `pushState` for state-driven nav (§11) | PARTIAL | Todo app's project switcher (sidebar nav between projects) built with `hx-boost` body wrapper like the canvas-read reader layout, proving it's a documented, copy-pasteable pattern for a fresh app, not just a canvas-only trick |
| Turbo Page Cache | Instant back/forward via cached prior-page snapshots | None — every nav re-renders from server | MISSING | n/a — StreamWeaver's whole-rerun model has no snapshot cache; back/forward correctness comes from URL-authoritative state re-seeding (§11 HAVE), not a client cache, which is a different (server-truth) strategy, not a missing feature per se |
| The `data-turbo` Attribute (opt individual links/forms out of Turbo) | Per-element escape hatch from Drive interception | No boosted-nav-by-default exists to opt individual elements out of (see row above); `hx-boost` is opt-in at the body level in the one reference layout, so the equivalent question doesn't arise yet | N/A (contingent on Drive row) | n/a |
| Turbo Link Prefetching | Hover-triggered background fetch of the link target | None | MISSING | n/a — low priority; StreamWeaver's server-side render cost per nav is the same regardless of prefetch, no htmx `hx-boost`+preload equivalent wired |
| `data-turbo-confirm`; Turbo Custom Confirm Modal | Native `confirm()` before a destructive action, replaceable with a custom Turbo Stream-inserted dialog | `resource` destroy flow renders an inline warning `alert` + Confirm/Cancel buttons server-side (`docs/resource-dsl.md` "Destroy confirm", `state[:_sw_action] :destroy_confirm`) — same *outcome* (interstitial confirm before destroy), different mechanism (full state transition, not a client-side confirm() intercept) | PARTIAL | Todo delete button routes through `resource :todo`'s built-in destroy-confirm state, rendering an inline "Delete this todo?" alert before calling `store.destroy` — matches the course's custom-confirm-modal lesson's *goal* (no jarring native `confirm()`) via a different, already-shipped path |
| Disabling Form Buttons; `data-turbo-submits-with` | Auto-disable submit button + swap its label during a request | `hx-disabled-elt="this"` on every button (`adapter/alpinejs.rb:704`) — auto-disables on click, no label-swap equivalent | PARTIAL | Todo "Add" button auto-disables mid-request (already true for every StreamWeaver button); label doesn't change to "Adding…" — would need a small `submits_with:` option |
| `data-turbo-method` | Turn a plain `<a>` into a non-GET request | Not needed — StreamWeaver actions are POST-only via `button`/form submit, no `<a method=delete>` convention exists to replace | N-A-BY-DESIGN | n/a |
| `data-turbo-temporary` | Exclude an element from page-cache restoration | N/A — no page cache (see above) | N-A-BY-DESIGN | n/a |
| `data-turbo-track` | Force full reload when a tracked asset (e.g. compiled CSS) changes | N/A — no client asset bundle to track; theme CSS is served by the running process directly | N-A-BY-DESIGN | n/a |
| View Transitions | Native `document.startViewTransition()` on Turbo Drive nav for animated page swaps | None — Alpine `x-transition` exists for component-level enter/leave (e.g. `sw-confirmation-bar`, `alpinejs.rb:5419-5424`) but nothing wraps whole-page/whole-fragment swaps in a View Transition | MISSING | n/a — todo add/remove currently swaps instantly; a View Transitions API wrap around fragment morph would be the parity demo, not yet built |
| Form Redirects And Errors | Rails PRG (post-redirect-get) pattern + re-rendering a form with validation errors | `form_for`'s validate→errors_key→re-render-with-`alert(variant: :error)` path (`app.rb:598-644`) is a direct PRG-equivalent: on success it calls `on_success`/default show transition; on failure it re-renders the same form scope with an error alert, never losing entered values (scope-preserved state) | HAVE | Todo create form: submitting with a blank name re-renders the form with "Name can't be blank" via `form_for`'s built-in `validate:`/errors flow — same course beat (Rails re-renders `new.html.erb` with `@todo.errors`), StreamWeaver's mechanism already shipped |

---

## 2. Turbo Frames

| Course lesson(s) | What it teaches | StreamWeaver equivalent today | Status | Parity demo |
|---|---|---|---|---|
| Web Components From Scratch | Turbo Frame is just `customElements.define` — build a minimal one by hand to demystify it | Already dissected in concept map §2 (`alex_turbo_frames_transcript.txt`); StreamWeaver's `fragment` is a server DSL concept, not a client custom element, so there's no equivalent "build it from scratch" teaching moment needed — the mechanism is inherently server-driven | N/A — different mechanism, not a missing capability | n/a |
| Turbo Frame Inline Editing | Click "Edit", frame swaps to a form, submit swaps back to display, all scoped to one frame | Rails uses two matching-`dom_id` `turbo_frame_tag`s (display + edit) that swap by id; key elements: shared `dom_id`, the edit link living inside the frame it replaces, a narrow nested-resource `url:` for strong-params safety. StreamWeaver does the equivalent via one `fragment("todo-#{id}")` per row branching on `state[:editing_id]`, with `form_for(fields: TITLE_ONLY, record: todo)` inside it — every element rendered inside a fragment auto-scopes to it, so Edit and Save both swap just that row, and `form_for`'s declared `fields:` make the unsafe write unexpressible rather than just discouraged | HAVE | `examples/my_todos/` `/` — click Edit on any of 6 rows, only that row morphs to a form (verified server-side this story: edit fetch 1,327 bytes vs. 108,792-byte full page; save 806 bytes, completed glyph preserved across save) (browser-verified 2026-08-22, main-thread playwright pass complete) |
| Search With Turbo Frames | Type in a search box, frame updates with filtered results, URL unaffected | Rails names a sibling frame from outside it (`data: {turbo_frame: :todos}`) plus a Stimulus `autosubmit` controller calling `requestSubmit()`; key elements: `data-turbo-frame`, `method: :get` for a cacheable URL, a controller most authors get wrong (`submit()` vs `requestSubmit()`). StreamWeaver's `text_field` auto-submits on keystroke with zero controller — the `autosubmit` chapter collapses to nothing — but has no `data-turbo-frame` equivalent: an input can only target its own enclosing fragment or the whole container, never a sibling. Both arrangements filter correctly (the fragment-scoped param-merge bug the spike found is fixed, `deferred-fragments-src`/InteractionRunner) | HAVE (with a documented trade-off) | `examples/my_todos/` `/search` — arrangement A (field outside, Rails' layout): whole-container swap, 3,184 bytes. Arrangement B (field inside, scoped): 800-834 byte scoped morph. Verified server-side this story: outside "milk" then inside "coffee" in sequence produces zero state bleed (834-byte scoped response shows only "coffee" results) (browser-verified 2026-08-22, main-thread playwright pass complete) |
| Hovercards With Turbo Frames | Hover over a name, a lazy frame (`loading=lazy`) fetches and shows a card, keyed correctly per-position (dom_id lesson) | Rails uses `turbo_frame_tag todo.user, :hovercard, src:, loading: :lazy` inside a `div.hovercard`; key elements: CSS does the reveal (`display: none` → `:hover` → `block`), `loading="lazy"`'s IntersectionObserver does the fetch (only because the reveal made it visible), fetch-once, and the frame keyed by position (the todo) not content (the user) — the chapter demos keying by user as a live duplicate-id bug. StreamWeaver does the equivalent via `fragment(:"hovercard_#{todo_id}", lazy: true)` inside the same CSS `:hover` wrapper, keyed by `todo_id` per the same rule (llms.txt "Interactive IDs and keying") | HAVE | `examples/my_todos/` `/hover-cards` — verified server-side this story: 0 eager card fetches on initial GET (6 `sw-fragment-lazy` wrappers, `hx-trigger="intersect once"`, zero card content in the response body); booted with `SW_HOVERCARD_DELAY=1.5`, shell GET took 0.085s (was 9.151s eager); individual card POST fetch took 1.517s/1.530s, paid once, per card (browser-verified 2026-08-22, main-thread playwright pass complete) |
| Infinite Scroll Turbo Frames | Nested lazy frames — each response embeds the next page's already-lazy placeholder frame | Rails nests `turbo_frame_tag :todos_page, @pagy.page` around each page's rows plus a `loading: :lazy` frame for `@pagy.next`, keyed to the next page's URL; key elements: nesting (not replacing) so nothing is ever removed from the DOM, the `@pagy.next` guard so the last page dead-ends cleanly instead of blank-id "Content missing." StreamWeaver does the equivalent via a recursive `scroll_todos_page(n)` helper: page `n`'s rows render inline (in the shell for page 1 — true Turbo shape, corrected 2026-08-22 in dc06bcf after a clean-room skill test caught the earlier all-lazy shape shipping an empty shell), then page `n+1` is declared as a nested `fragment(:"todos_page_#{n+1}", lazy: true)` with an emptiness guard as the `@pagy.next` equivalent; nested ids `parent--child` per the framework's convention | HAVE | `examples/my_todos/` `/infinite-scroll` — verified server-side this story: walked all 6 pages via curl, payload sizes 809/877/934/993/1060/371 bytes (growth is only the lengthening nested-id string, not accumulated rows — O(1) per page vs. the spike's O(n) click-driven design), page 6 terminates with no further nested placeholder (browser-verified 2026-08-22, main-thread playwright pass complete) |

---

## 3. Turbo Streams

| Course lesson(s) | What it teaches | StreamWeaver equivalent today | Status | Parity demo |
|---|---|---|---|---|
| Turbo Streams From Scratch; Turbo Stream HTTP Responses | Server response carries `<turbo-stream action=... target=...>` ops, from a normal controller action | Fragment `updates:` OOB swaps resolve within the same request/response cycle (§7 HAVE) | HAVE | Adding a todo returns the new row (`append`) plus an updated count badge (`replace`) in one action response — this is exactly fragment `updates: %i[todo_list count_badge]` today |
| Turbo Stream From Websockets; `broadcasts_to` and `turbo_stream_from` | Model-level broadcast wired to a subscribed channel, independent of any one request | `Streamer` (`lib/stream_weaver/streamer.rb`, ACTIONS: replace/append/prepend/remove/add_class/remove_class) over SSE, but only reachable from `every(seconds)` timer blocks, not from arbitrary model/store code (§7, §8 PARTIAL) | PARTIAL | A second browser tab open on the same todo list does NOT see a todo added from tab one until an `every` timer polls and re-diffs — Rails' model-callback broadcast has no StreamWeaver equivalent triggerable from `PostStore.create` itself |
| Broadcastable Module Source | Rails source-dive into how `broadcasts_to` is implemented | N/A — source-code-literacy lesson about Rails internals; StreamWeaver's `Streamer` source (`streamer.rb`) is the equivalent artifact to point an agent at, but there's no course-shaped "read the source" lesson need here | N/A — meta lesson, not a capability | n/a |
| `broadcasts_refreshes`; My Todos `broadcasts_refreshes` | Simplest broadcast mode: just tell subscribers "something changed here, go refetch the frame" (no diffing) | No equivalent — the closest primitive (`every` + `streamer.replace`) always pushes computed HTML, never a bare "refresh yourself" signal | MISSING | n/a — a `refresh_fragment(:todo_list)` SSE action that just triggers the client to re-GET that fragment (rather than computing+pushing HTML server-side) doesn't exist; would be a cheap, small primitive to add |
| Morph And Scroll Preservation | `refreshes_morph` mode uses Idiomorph so a full-list refresh doesn't reset scroll/focus | StreamWeaver already runs every request/action response through `alpine-morph`/Idiomorph (`HTMX_SWAP = "morph:innerHTML"`, `adapter/alpinejs.rb:29`) — this is the *default* swap strategy, not a special mode | HAVE (arguably ahead — it's the default, not opt-in) | Scrolling mid-list, then adding a todo via the form, doesn't jump scroll position or blur the active input — true today by default via morph swap, no special configuration needed |

---

## 4. Stimulus

Concept map §9 already gives the architectural verdict (Alpine `x-data` is the chosen substitute,
PARTIAL by design, no enforced lifecycle-cleanup guardrail). This section maps each specific
lesson topic onto that verdict rather than re-deriving it.

| Course lesson(s) | What it teaches | StreamWeaver equivalent today | Status | Parity demo |
|---|---|---|---|---|
| Autosubmit (`autosubmit_controller.js`) | A form auto-submits on any field change | This is StreamWeaver's *default* behavior for every input, not an opt-in controller (`docs/for_llms.md` "ALL input components auto-submit on change") | HAVE — StreamWeaver is ahead here, it's the default not a bolt-on | n/a, already true everywhere |
| Hotwire Spark and Autogrow Textarea (`autogrow_controller.js`) | Textarea grows with content via a small Stimulus controller | No built-in `autogrow:` option found on `text_area`; would need a one-line inline Alpine `x-data` per the framework's own convention, or a registered component | MISSING (cheap) | Todo notes `text_area` grows with typed content — buildable today as one inline Alpine snippet per `docs/streamweaver-frontend-vision.md`'s stated Stimulus→Alpine substitution, just not shipped as a component option |
| Mutation And Intersection Observers | Low-level browser APIs Stimulus controllers wrap | Used internally in framework JS (`sw-mermaid-zoom.js`, `sw-sidebar-toc.js` — both `IntersectionObserver`/`MutationObserver` hits found in `lib/stream_weaver/assets/js/`) for scroll-spy/zoom features, but no DSL-level exposure for app authors to hang their own observer logic off | PARTIAL | n/a — the primitives exist in the codebase for framework features, not as an author-facing hook |
| Turbo Events With Stimulus | Listening for `turbo:*` lifecycle events from a controller | htmx equivalent events (`htmx:afterSwap`, etc.) are used internally (`for_llms.md`'s reader-layout pattern step 5: "Update active-link highlights via `htmx:afterSwap` listener") and are a documented pattern for app authors to hook into directly in inline Alpine/JS | HAVE | The reader layout's active-nav-highlight pattern (already documented) is itself a "listen for the framework's swap event" demo |
| Wrapping Third-Party Libraries; Morphing With Third-Party Libraries | Stimulus controller wraps e.g. a date picker, survives morph via `data-turbo-permanent`-style opt-out | `StreamWeaver.register_component` (`component_registry.rb`, concept map §9) lets an author wrap a Phlex-backed component as a real DSL verb; morph-survival for third-party JS state is the alpine-morph "save and restore manually" pattern already used internally (`adapter/alpinejs.rb:1044-1058` comments) but not documented as an author-facing recipe | PARTIAL | n/a — the registration mechanism exists; a worked "wrap a date picker, preserve its state across morph" doc example doesn't |
| Targets; Values; Value Changed Callbacks; Actions; Keyboard Events; Action Params; CSS Classes; Default CSS Classes; Bound Functions And Event Listeners; Controller Inheritance; Target Callbacks; Outlets | The full Stimulus API surface: typed properties, declarative event wiring, controller-to-controller communication | All of this maps to inline Alpine's own primitives (`x-data`, `@click`, `x-model`, `$dispatch`/`$watch` for outlet-like communication) rather than a StreamWeaver-specific API — StreamWeaver doesn't wrap or replace Alpine's API, it just inlines Alpine declarations into server-rendered markup | N-A-BY-DESIGN (StreamWeaver defers entirely to Alpine's own vocabulary here, doesn't reimplement it) | n/a — no StreamWeaver-specific demo needed; any Alpine tutorial covers this 1:1 |
| Turbo Morph Event | `turbo:morph-element` fires per morphed element, lets a controller re-init state that morph doesn't preserve | htmx's `htmx:afterSwap`/Alpine's own re-init are used the same way internally (`adapter/alpinejs.rb:1058` "afterSettle: alpine-morph initializes newly-morphed-in elements") but not documented as an author hook | PARTIAL | n/a |

---

## 5. More Hotwire

| Course lesson(s) | What it teaches | StreamWeaver equivalent today | Status | Parity demo |
|---|---|---|---|---|
| Cleaning Up The Edit View | Refactoring pass consolidating duplicated frame/form logic | N/A — course pacing/refactoring lesson, no distinct capability | N/A | n/a |
| Turbo Morph Internals with Idiomorph | How Idiomorph's diffing algorithm actually works | StreamWeaver already depends on Idiomorph directly (bd `stream_weaver-2ds`, per `for_llms.md` "Future direction" note) via `htmx-ext-alpine-morph` — same library, same mechanism, not a gap | N/A — shared dependency, no porting needed | n/a |
| Custom Model `broadcasts_to` | Hand-writing the broadcast callback Rails' `broadcasts_to` macro generates | Same gap as §3 above (no model-callback-triggered push) | MISSING (same root cause as §3) | n/a |
| Debugging Turbo Frames | Chrome devtools techniques for diagnosing frame mismatches | `SW_DEBUG=1` env var logs cookie/state size + SSE connections (`for_llms.md` "Debug logging") — general debug aid, not frame-specific since fragments don't have Turbo's ID-mismatch failure mode (concept map §4: self-heal via `HX-Retarget` instead) | N/A — different failure mode by design (§4) | n/a |
| Custom Turbo Stream Actions | Registering a new verb beyond replace/append/prepend/remove (e.g. a `notify` action) | `Streamer::ACTIONS` is a fixed `%i[replace append prepend remove add_class remove_class]` constant (`streamer.rb:17`) — no registration mechanism for a new action | MISSING (cheap-ish — small, additive change) | n/a — a hypothetical `streamer.toast(message)` custom action would need `ACTIONS` to become extensible |
| Custom Layouts With Turbo Frame Support | A layout that conditionally omits chrome when rendering inside a frame request | `layout:` app option (`:default`/`:wide`/`:full`/`:fluid`) is static per-app, not conditional on request type; fragments already omit outer chrome by construction (only the fragment's HTML is returned), so the underlying need (partial responses don't carry full layout) is already met structurally | N/A — met by fragment architecture, not by a layout-conditional feature | n/a |

---

## 6. Testing Hotwire

| Course lesson(s) | What it teaches | StreamWeaver equivalent today | Status | Parity demo |
|---|---|---|---|---|
| Integration Tests with Turbo Stream Responses / Turbo Frames / Turbo Broadcasts | Rack::Test-style assertions on stream/frame HTTP responses | `docs/testing.md`'s Rack::Test pattern (`post '/action/btn_...'`, inspect `last_response.body`) covers the response-shape-assertion case directly; no broadcast-specific ("assert a Streamer push happened") helper documented | PARTIAL | A spec posting to the todo "Add" action and asserting the response body contains the new row's fragment HTML — already a documented pattern (`docs/testing.md`); asserting an SSE `Streamer` push occurred has no documented helper |
| System Tests with Turbo Streams / Turbo Broadcasts / Infinite Scroll | Capybara/browser-driven tests of live-update behavior | `bin/smoke` is StreamWeaver's real-HTTP UAT battery (boots real servers, drives via `Net::HTTP`) but doesn't drive a real browser/JS; the `route-tabs.feature` "browser-verification" scenario shows the actual pattern used for JS-dependent behavior: playwright-cli, run from the main thread only, with screenshots as evidence (not an automated spec suite) | PARTIAL | `bin/smoke` extended with a todo-app fixture proves the HTTP-level contract; true "watch it live-update in a real browser" verification is playwright-cli-driven and manual/one-off per feature, same as route-tabs shipped it |
| Stimulus Drag and Drop System Test | Testing a `sortable_controller.js`-style reorder interaction end-to-end | No drag-and-drop exists in StreamWeaver at all (see §4 Wrapping Third-Party Libraries, and Kanban board explicitly documented as "No drag-and-drop" — `components.rb:808`) | MISSING (blocked on drag-and-drop capability itself) | n/a |

---

## 7. Modal Dialogs

| Course lesson(s) | What it teaches | StreamWeaver equivalent today | Status | Parity demo |
|---|---|---|---|---|
| Inserting the Dialog Element with Turbo Streams | A Turbo Stream response appends a `<dialog>` element into the DOM | `modal :key do ... end` (`app.rb:1083`) renders unconditionally in the initial page (a `div`-based overlay, `render_modal`, `adapter/alpinejs.rb:2633`), toggled by `state[:key_open]` — not inserted via a stream action, but present-and-toggled achieves the same visible outcome | PARTIAL — different insertion mechanism, same visible result | Todo "New Todo" modal: `modal :new_todo_modal do form_for(:todo) ... end`, opened by a button setting `state[:new_todo_modal_open] = true` — this exists today as a working pattern (`docs/for_llms.md` "Modal" section) |
| Opening the Dialog modally with Stimulus | JS calls `.showModal()` for real modal (focus-trap, `::backdrop`, Escape) semantics | StreamWeaver's modal is a styled `div` overlay with Alpine `@click.outside`/`@keydown.escape.window` handlers (`alpinejs.rb:2484-2485, 2653`), not a native `<dialog>` + `showModal()` — no built-in focus trap or `::backdrop` pseudo-element. Notably, the *mermaid fullscreen viewer* (`alpinejs.rb:3368-3398`) **does** use a real `<dialog>` with `showModal()`, proving the pattern is known and used elsewhere in the codebase, just not for the general-purpose `modal` component | PARTIAL — real `<dialog>` pattern exists in the codebase but isn't used for `modal` itself | n/a — porting `modal` to native `<dialog>`/`showModal()` would pick up free focus-trap/Escape/`::backdrop` behavior; today's div-based modal hand-rolls Escape but not focus-trap |
| Embedding Forms in Dialogs with Turbo Frames | A form lives inside a frame inside a dialog, so submit updates the dialog in place without closing it | `form_for` (or `form`) inside a `modal` block is exactly this composition, already working (see resource-dsl.md's default `new_view :modal`) | HAVE | `resource :todo` with default `new_view :modal` renders the create form inside a modal, submits, and either shows validation errors in-place (form_for re-render) or closes+transitions on success — this is the shipped default, not a custom build |
| Close Dialog Buttons | Explicit close button separate from Escape/backdrop-click | `render_modal_close_button` (`alpinejs.rb:2694`) — shipped | HAVE | Todo modal's × close button — already exists on every `modal` |
| Dialog Close Event cleanup | Native `<dialog>`'s `close` event fires cleanup (e.g. clearing form state) | No native `<dialog>` `close` event to hook (see above — div-based, not `<dialog>`-based); state clearing on close is whatever the author wires into the close button's callback manually | PARTIAL | n/a |
| Redirecting Out Of Turbo Frame Server-side | Server tells a frame "actually, navigate the whole page, not just this frame" (`turbo_frame: "_top"`) | `HX-Retarget: #app-container` full-container fallback (concept map §4) is architecturally the same move — server overrides the client's intended narrow target — but triggered by stale-action-ID mismatch, not by deliberate author intent to "break out" of a modal/frame on success | PARTIAL | A `resource` form's on-success transition (e.g. create todo → show todo) already re-renders the whole `#app-container`, which is StreamWeaver's version of "breaking out" since there's no narrower target to begin with in the whole-rerun model |
| Closing The Dialog And Updating The Page | Successful dialog submit both closes the dialog and updates the underlying list/page in one round trip | `form_for`'s `on_success` + `resource`'s modal-close-and-transition default (`docs/resource-dsl.md`) — submitting the "New Todo" modal form both closes the modal and updates the todo list fragment via `updates:`, in the same response | HAVE | Already the `resource :todo, ... new_view: :modal` default behavior — submit closes modal + list updates, one request |

---

## 8. Source Code Walkthroughs

| Course lesson(s) | What it teaches | StreamWeaver equivalent today | Status | Parity demo |
|---|---|---|---|---|
| Turbo.js Overview; Turbo Frame Internals; Turbo Stream Internals; Turbo Stream Source Internals | Reading Turbo's own source to understand its mechanisms | N/A — meta/pedagogical lessons about a specific library's source, not a capability comparison. StreamWeaver's equivalent artifacts for an agent/author to read are `lib/stream_weaver/streamer.rb`, `lib/stream_weaver/interaction_runner.rb`, `lib/stream_weaver/adapter/alpinejs.rb` — already the canonical "read the source" targets, no porting needed | N/A | n/a |
| Trix Morphing With Web Components | How a specific rich-text-editor web component survives Turbo morphing | N/A — no rich-text-editor component exists in StreamWeaver to have this problem; would only become relevant if/when one is added | N/A | n/a |

---

## Not covered by the original 13 concepts

Every syllabus item the concept map missed or compressed away, with a one-line verdict on
whether it matters for StreamWeaver:

1. **Importmaps / zero-bundler JS** — doesn't matter; StreamWeaver has no client build step at all, more radical than Rails' answer, not a gap.
2. **Turbo Page Cache** — matters a little; back/forward is still correct (URL-authoritative re-seed), just never instant-from-cache. Low priority — server-render cost, not correctness, is the trade.
3. **`data-turbo-track` / `data-turbo-temporary`** — doesn't matter; no asset bundle, no page cache, nothing to track or exempt.
4. **Turbo Link Prefetching** — matters a little for perceived latency on nav-heavy apps; not currently discussed anywhere in the repo.
5. **View Transitions API** — matters cosmetically; the concept map's morph coverage (§2, §7) covers *what* updates but not animated transitions between states.
6. **`data-turbo-submits-with` (button label swap during request)** — small, matters for polish; disabling exists (`hx-disabled-elt`), label-swap doesn't.
7. **Hovercards / infinite scroll (visibility-lazy nested frames)** — matters significantly; concept map §6 named the underlying primitive gap (no `loading=lazy` equivalent) but didn't name these two concrete, common use cases that depend on it.
8. **`broadcasts_refreshes` (bare "go refetch yourself" signal, no diffing)** — matters; StreamWeaver's `Streamer` always computes+pushes HTML, has no cheap "just refresh" mode. This is a real, previously-unnamed gap, distinct from §7/§8's "timer-triggered only" framing.
9. **Model-callback-triggered broadcasts (`broadcasts_to`, `broadcast_action_later_to` from `after_create_commit` etc.)** — matters significantly; concept map §7/§8 named "timer-triggered only, not broadcast-from-anywhere" but the syllabus's actual `Todo` model example (fetched above) makes concrete exactly how far that gap reaches: a StreamWeaver `PostStore.create` has no way to push a live update to *other* open sessions at all, only the process's own `every` timers can.
10. **`form_for` already covers most of what the concept map's §10 called "not yet implemented"** — this is a *correction*, not a gap: the concept map is stale on this specific point.
11. **Native `<dialog>`/`showModal()` for the general-purpose `modal` component** — matters for accessibility (focus trap) — not named in concept map at all; ironically the codebase already uses real `<dialog>` for the mermaid fullscreen viewer, so precedent exists internally.
12. **Custom Turbo Stream actions (extensible verb registration)** — small but real gap, not named in the concept map; `Streamer::ACTIONS` is a closed list.
13. **Drag-and-drop (Stimulus `sortable_controller.js` / `acts_as_list`)** — matters for the todo-app parity story specifically since reordering is core to "My Todos"; concept map only mentioned this in passing re: Kanban ("No drag-and-drop... 03 gap"), not as its own syllabus-driven line item.
14. **Dialog close-event cleanup** — small, follows from the native-`<dialog>` gap above.
15. **Autogrow textarea, autosubmit-as-Stimulus-controller** — autosubmit is a non-issue (StreamWeaver does this by default, arguably ahead); autogrow textarea is a small missing component option, not previously named.
16. **Testing Turbo Broadcasts / drag-and-drop system tests** — both blocked on the capability gaps above (broadcast-from-anywhere, drag-and-drop), so not independently actionable until those ship.

---

## Recommended story additions

Beyond the seven already-known items (four-features spike, strict-ids keying, deferred
fragments, visibility-lazy fragments, dev-loud-failure overlay, four-features rebuild,
streamweaver-way skill), full-syllabus parity surfaces these:

**Cheap (docs/demo only — capability already exists)**

- Document `form_for` in `docs/resource-dsl.md` and `docs/for_llms.md` — it already delivers the concept map §10 "missing" capability; this is a documentation debt, not a build.
- Document the native-`<dialog>` pattern from the mermaid fullscreen viewer as the recommended recipe for authors who want real focus-trap/`::backdrop` modals, alongside the existing div-based `modal` DSL.
- Ship a companion "My Todos" example app (`examples/todo_app/` or similar) exercising `resource`, `form_for`, `tabs url:`, fragment `updates:`, and `every`-driven live refresh together — this is the single highest-leverage cheap item since it becomes the concrete parity-demo target for every row above, replacing "n/a — would need" with a real running app.
- Small `submits_with:`-style button option (label swap during request) — additive to existing `hx-disabled-elt` wiring.

**Real builds**

- **Broadcast-from-anywhere** — let `Streamer` be pushed to from arbitrary code (a `resource` store callback, not just `every` timer blocks), the direct fix for gaps #8/#9 above (`broadcasts_to`/`broadcast_action_later_to` equivalents). This also requires fixing the tracked session-scoping leak bug (concept map §7) first, since broadcast-from-anywhere makes that bug's blast radius worse, not smaller.
- **`refresh_fragment` bare-refresh Streamer action** — small addition to `Streamer::ACTIONS`/client, the `broadcasts_refreshes` equivalent (gap #8).
- **Extensible `Streamer::ACTIONS`** — a registration mechanism analogous to `ComponentRegistry` but for custom stream verbs (gap #12).
- **Drag-and-drop primitive** — a `sortable:` option on lists/tables/Kanban lanes wrapping a small Alpine/SortableJS-equivalent, wired to a reorder action — the single largest missing piece for a faithful "My Todos" port, since `acts_as_list`-driven reordering is core to the course's actual app.
- **Lazy route tabs** — already named as the deprecation target for `tabs lazy: true` (route-tabs epic's `deprecate-lazy-post-morph` story) but not yet designed/built; should fold in visibility-lazy semantics (not just click-lazy) to also cover the hovercard/infinite-scroll gap (#7) via the same underlying primitive as deferred/visibility-lazy fragments.
- **Autogrow textarea option** — small, standalone, doesn't block anything else.

---

## Coverage counts

| Status | Count |
|---|---|
| HAVE | 15 |
| PARTIAL | 20 |
| MISSING | 9 |
| N-A-BY-DESIGN / N/A | 21 |
| **Total rows** | **65** |

Counted across all eight section tables above (one row per syllabus lesson-cluster). Updated
2026-08-22 (`my-todos-zero-js`): Turbo Frames' Hovercards and Infinite Scroll rows moved
MISSING → HAVE (`visibility-lazy-fragments` + `deferred-fragments-src` closed both), and Inline
Editing consolidated from a split HAVE/PARTIAL into a clean HAVE (the raw-`fragment` path now
delivers the row-scoped swap `resource` alone didn't). Roughly a third of the full syllabus is
architecturally N/A (no bundler, no page cache, Alpine's own API surface standing in 1:1 for
Stimulus's), and the PARTIAL bucket — still the largest — is dominated by two repeated root
causes: (1) push/broadcast is timer-triggered-only rather than triggerable from arbitrary server
code, and (2) the div-based `modal` hasn't picked up the native-`<dialog>` pattern already proven
elsewhere in the same codebase.

---

## Epic ownership roadmap (added 2026-08-22)

Every non-N/A row above is owned by one Tyrion epic. The arc is chained: each pending
epic's first story (`shape-epic`) is blocked with its unlock condition, and its job is
to re-verify the owned rows and fill placeholder criteria before any build. An
orchestrating session reads `tyrion status` / `tyrion epic show <slug>` to see where
the arc stands.

| Epic (Tyrion slug) | Owns syllabus sections/rows | Status |
|---|---|---|
| streamweaver-way | Turbo Frames (all rows); cross-cutting: strict-ids keying, deferred/eager fragments, visibility-lazy, dev-loud failure, form_for docs; Way skill | ACTIVE (6/8 done, `my-todos-zero-js` in progress) |
| turbo-streams-parity | Turbo Streams (all non-N/A rows): broadcast-from-anywhere, refresh-fragment (broadcasts_refreshes), extensible stream actions, morph/scroll preservation | pending — blocked on streamweaver-way + now-view session-scoped-broadcast fix |
| modal-dialogs-parity | Modal Dialogs (all rows): native `<dialog>` modal, modal form flows, dialog lifecycle | pending — blocked on turbo-streams-parity |
| stimulus-role-parity | Stimulus rows not N-A-by-design: sortable drag-and-drop, submits-with label swap, autogrow textarea, Alpine lifecycle guardrails | pending — blocked on modal-dialogs-parity |
| (unowned, deliberate) | Turbo Drive attribute family rows marked PARTIAL (confirm/prefetch/temporary/track/view transitions) | folded into whichever epic's shape-epic re-verification finds them load-bearing; otherwise remain documented PARTIALs |
| now-view-support (drafted, un-imported) | session-scoped-broadcast (SSE leak) — gate for turbo-streams-parity | separate draft epic, imports on its own track |

Verification convention: as each epic completes, its owned rows gain a verified parity
entry in this file, in the format "Rails uses <mechanism> for <feature>, key elements
<X>; StreamWeaver does equivalent via <Y>" — the `my-todos-zero-js` story does this
for the Turbo Frames rows, and each later epic's closing story does the same for its
own rows. This file is the living answer to "are we matching everything."
