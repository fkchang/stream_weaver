# frozen_string_literal: true

require 'spec_helper'
require 'pathname'
require_relative 'support/delivery_contexts'
require_relative 'support/invariants'

# The executable compatibility matrix.
#
# docs/research/frontend-only-matrix.md says which StreamWeaver components work
# in each backend-less context and how each one degrades; docs/frontend-only.md
# turns that into advice authors and agents act on. Both are prose, and prose
# about emitted markup rots the first time someone edits the adapter. This
# suite is the part that cannot: it renders the same DSL through all four
# documents a reader can actually receive and asserts the matrix's mechanical
# verdicts against them.
#
# It is deliberately an umbrella and not a fifth copy of the specs underneath
# it. Four sibling suites already own their own corner:
#
#   spec/canvas/htmx_call_site_sweep_spec.rb  -- per-call-site dispositions
#   spec/canvas/reader_inert_controls_spec.rb -- the reader's inert rendering
#   spec/canvas/deck_honest_ui_spec.rb        -- the deck, JS run under node
#   spec/export/html_exporter_spec.rb         -- the CDN gate per chart DSL
#
# What none of them can state is the cross-cutting form: that the pairing holds
# in *every* context at once, over a document assembled the way production
# assembles it. A component can pass its own spec and still ship a control that
# calls a function its page never defines. That gap is what this file closes.
RSpec.describe 'backend-less compatibility matrix' do
  # ===========================================================================
  # The fixtures arrived intact
  # ===========================================================================

  # Every invariant below is of the form "this document must not contain X",
  # and an empty document satisfies all of them. Both servers answer 200 for a
  # doc that failed to render, so without this the whole suite could go
  # permanently, silently vacuous behind one DSL typo.
  describe 'each context delivered the fixture' do
    Compat::NAMES.each do |name|
      it "rendered the gallery, controls and all, in the #{name} document" do
        body = Compat.context(:gallery, name).body

        expect(body).to include('Compatibility Gallery')
        expect(body).to include('<button')
        expect(body).to include('<input')
      end
    end
  end

  # ===========================================================================
  # M2 -- sendEvent and the bridge script that defines it, paired
  # ===========================================================================

  # The single most expensive lesson in the epic (disc-095, disc-097): markup
  # and <head> drifted apart, and every individual spec stayed green because
  # each one only ever looked at its own half.
  describe 'sendEvent is paired with the script that defines it' do
    Compat::FIXTURES.each_key do |fixture|
      Compat::NAMES.each do |name|
        it "holds for the #{fixture} fixture in the #{name} document" do
          expect(Compat.context(fixture, name)).to uphold(:send_event_is_defined_where_it_is_called)
        end
      end
    end

    it 'is a live pairing on the canvas, not a vacuous one' do
      document = Compat.context(:gallery, :canvas).document

      expect(document).to include('sendEvent(')
      expect(document).to include('window.sendEvent =')
    end

    # Both directions. A stub would satisfy the pairing above and restore the
    # exact lie the reader fix removed.
    Compat::WITHOUT_BRIDGE.each do |name|
      it "leaves sendEvent undefined in the #{name}, where nothing is listening" do
        expect(Compat.context(:gallery, name)).to uphold(:send_event_is_undefined_where_there_is_no_bridge)
      end
    end
  end

  # ===========================================================================
  # disc-095 -- honest degradation, stated across contexts
  # ===========================================================================

  describe 'no document carries a dead handler' do
    Compat::NAMES.each do |name|
      it "holds in the #{name} document" do
        expect(Compat.context(:gallery, name)).to uphold(:no_self_disabling_dead_handlers)
      end
    end

    # The reader is the context the matrix calls B, and the one a Save-as-doc
    # reader actually lands on. Its controls must be visibly inert rather than
    # merely non-dispatching -- a disabled control with a reason is honest; a
    # live-looking control that does nothing is the bug.
    it 'renders the reader controls disabled, with a reason' do
      body = Compat.context(:gallery, :reader).body

      expect(body).to match(/<button[^>]*disabled/)
      expect(body).to include(%(title="#{StreamWeaver::Adapter::AlpineJS::INERT_TITLE}"))
    end

    # The live canvas keeps its optimistic disable, because there a click
    # really does reach an agent. Pinned here so "no dead handlers" is never
    # mistaken for "no handlers".
    it 'leaves the live canvas button dispatching, disable and all' do
      expect(Compat.context(:gallery, :canvas).document).to include('$el.disabled=true')
    end
  end

  # ===========================================================================
  # M1 -- htmx, and why context C is the quiet one
  # ===========================================================================

  describe 'an export never ships htmx' do
    Compat::FIXTURES.each_key do |fixture|
      it "holds for the #{fixture} fixture" do
        expect(Compat.context(fixture, :export)).to uphold(:htmx_never_ships_in_an_export)
      end
    end

    # The invariant above is the load-bearing one, and this is why. Exports
    # still carry hx-* attributes from every call site that never learned to
    # ask what context it is in (the ledger is in
    # spec/canvas/htmx_call_site_sweep_spec.rb); they are inert only because
    # the library that would act on them is absent. Pinning the set keeps that
    # residue visible instead of letting it read as "exports are clean".
    #
    # Tracked as stream_weaver-66mg. Shrinking this list is the fix; growing it
    # is a regression.
    it 'still carries the pinned set of inert hx-* attributes (known residue)' do
      expect(Compat.context(:gallery, :export)).to uphold(
        :export_hx_attributes_are_the_pinned_set,
        pinned: %w[
          hx-disabled-elt hx-include hx-indicator hx-post hx-swap hx-target hx-trigger hx-vals
        ]
      )
    end

    it 'carries no hx-* attributes at all when the doc has no controls' do
      expect(Compat.context(:flat, :export)).to uphold(
        :export_hx_attributes_are_the_pinned_set, pinned: []
      )
    end

    # The live half of the same M1 row, and the half that actually costs a
    # user something. A and B both load htmx (the adapter's cdn_scripts and
    # reader_layout.erb respectively) while still emitting hx-post at routes
    # neither server mounts -- so there the attributes above are not inert,
    # they are a 404 per keystroke. Tracked as disc-106; characterized here
    # because the export pin says nothing without it.
    %i[canvas reader].each do |name|
      it "loads htmx in the #{name}, where those attributes are live (known, tracked)" do
        target = Compat.context(:gallery, name)

        expect(target.document).to match(/<script[^>]*htmx/i)
        expect(target.body).to include('hx-post=')
      end
    end
  end

  # ===========================================================================
  # disc-094 / M5 -- the chart library follows the chart components
  # ===========================================================================

  # html_exporter_spec walks every chart DSL method and proves each one gets the
  # library. The cross-cutting claim is the equivalence: across a fixture set
  # where some apps have charts and some do not, shipping Chart.js tracks
  # containing a chart, in both directions.
  describe 'Chart.js ships exactly when an export contains a chart' do
    Compat::FIXTURES.each_key do |fixture|
      it "holds for the #{fixture} fixture" do
        expect(Compat.context(fixture, :export))
          .to uphold(:chart_library_tracks_chart_components, app: Compat.app(fixture))
      end
    end

    it 'exercises the equivalence in both directions across the fixtures' do
      with_chart, without_chart = Compat::FIXTURES.keys.partition do |fixture|
        Compat::Invariants.app_has_chart?(Compat.app(fixture))
      end

      expect(with_chart).not_to be_empty, 'no fixture contains a chart, so the gate is untested'
      expect(without_chart).not_to be_empty, 'every fixture contains a chart, so the negative case is untested'
    end
  end

  # ===========================================================================
  # disc-096 / M7 -- the deck is read-only wherever nothing serves /deck/*
  # ===========================================================================

  describe 'deck interactivity matches the declared deck server' do
    Compat::NAMES.each do |name|
      it "holds in the #{name} document" do
        target = Compat.context(:deck, name)

        expect(target).to uphold(
          :deck_calls_match_the_declared_deck_server,
          read_only: target.adapter.send(:deck_read_only?)
        )
      end
    end

    # The equivalence is only worth anything if the two sides disagree
    # somewhere. Standalone is the one context that serves /deck/*.
    it 'is the standalone server alone that declares a deck server' do
      declarations = Compat::NAMES.to_h do |name|
        [name, Compat.context(:deck, name).adapter.send(:deck_read_only?)]
      end

      expect(declarations).to eq(standalone: false, canvas: true, reader: true, export: true)
    end
  end

  # ===========================================================================
  # Flat content, the matrix's one unqualified WORKS row
  # ===========================================================================

  # Every piece of advice in docs/frontend-only.md rests on this: prose,
  # headings and tables survive intact in all three backend-less contexts, so
  # "write the doc, then decide what interactivity it can afford" is sound
  # guidance rather than wishful thinking.
  describe 'flat content survives every context' do
    Compat::NAMES.each do |name|
      it "renders in the #{name} document" do
        body = Compat.context(:flat, name).body

        expect(body).to include('Flat')
        expect(body).to include('Nothing here needs a backend.')
        expect(body).to include('<table')
      end
    end
  end

  # ===========================================================================
  # The guard itself
  # ===========================================================================

  # "A component whose backend-less behavior regresses fails the suite with a
  # message naming the matrix" is a claim about this file, and the only way to
  # check it is to regress something on purpose. Each example below doctors a
  # real delivered document the way the corresponding fix could be undone, then
  # asserts the invariant fires and says where to look.
  #
  # Without this block every invariant above is green by construction and
  # nothing proves any of them can go red.
  describe 'the invariants fire, and name the matrix when they do' do
    def expect_violation(invariant, document, **kwargs)
      message = Compat::Invariants.public_send(invariant, document, **kwargs)

      expect(message).not_to be_nil, "#{invariant} stayed silent on a deliberately regressed document"
      expect(message).to include(Compat::MATRIX_DOC).and include(Compat::ADVICE_DOC)
    end

    it 'catches an export that started shipping htmx' do
      regressed = Compat.context(:gallery, :export).document
        .sub('</head>', '<script src="https://unpkg.com/htmx.org@2.0.4"></script></head>')

      expect_violation(:htmx_never_ships_in_an_export, regressed)
    end

    it 'catches sendEvent markup delivered without the bridge script' do
      # Exactly disc-095: websocket-mode markup, bridge cdn_scripts omitted.
      regressed = Compat.context(:gallery, :canvas).document.sub('window.sendEvent =', 'window.notSendEvent =')

      expect_violation(:send_event_is_defined_where_it_is_called, regressed)
    end

    it 'catches a no-op sendEvent stub reintroduced into the reader' do
      regressed = Compat.context(:gallery, :reader).document
        .sub('</head>', '<script>window.sendEvent = function() {};</script></head>')

      expect_violation(:send_event_is_undefined_where_there_is_no_bridge, regressed)
    end

    it 'catches a self-disabling handler reaching the reader' do
      regressed = Compat.context(:gallery, :reader).document
        .sub('<button', '<button @click="$el.disabled=true; sendEvent(\'action\', {})"')

      expect_violation(:no_self_disabling_dead_handlers, regressed)
    end

    # disc-094 exactly: the CDN tag stops being emitted while the x-init that
    # constructs the chart stays, so the page renders an empty box in silence.
    it 'catches an export that lost Chart.js while still containing a chart' do
      regressed = Compat.context(:chart, :export).document.gsub(%r{<script[^>]*chart[^>]*>\s*</script>}i, '')

      expect(regressed).to include('new Chart(')
      expect_violation(:chart_library_tracks_chart_components, regressed, app: Compat.app(:chart))
    end

    it 'catches a deck offering /deck/* where nothing serves it' do
      regressed = Compat.context(:deck, :export).document
        .sub('<body', '<body data-regressed="fetch(\'/deck/select\')"')

      expect_violation(:deck_calls_match_the_declared_deck_server, regressed, read_only: true)
    end

    it 'catches a new hx-* attribute appearing in an export' do
      regressed = Compat.context(:gallery, :export).document.sub('<body', '<body hx-boost="true"')

      expect_violation(:export_hx_attributes_are_the_pinned_set, regressed, pinned: [])
    end
  end

  # ===========================================================================
  # No opt-in
  # ===========================================================================

  # A compatibility suite nobody runs is a document with extra steps. This
  # belongs to the normal `rspec` run, and the one way it could quietly stop
  # being part of it -- moving to a path the configured pattern does not
  # collect -- is checkable from in here by asking the filesystem, not by
  # restating this file's own path and matching that.
  describe 'the suite itself' do
    it 'sits where a bare rspec run collects it' do
      root = Pathname(RSpec.configuration.default_path).expand_path
      relative = Pathname(__FILE__).relative_path_from(root).to_s

      expect(Dir.glob(RSpec.configuration.pattern, base: root.to_s)).to include(relative),
        "#{relative} is not collected by RSpec's configured pattern " \
        "(#{RSpec.configuration.pattern.inspect}), so a bare `rspec` run would skip the " \
        "compatibility matrix entirely. See #{Compat::MATRIX_DOC}."
    end

    it 'is not dropped by an exclusion in .rspec' do
      expect(File.read(File.expand_path('../../.rspec', __dir__))).not_to match(/--exclude-pattern/)
    end

    it 'carries no tag that would skip it' do
      expect(self.class.metadata[:skip]).to be_falsey
    end
  end
end
