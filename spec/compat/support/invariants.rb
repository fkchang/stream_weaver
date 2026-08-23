# frozen_string_literal: true

# The mechanical half of the compatibility matrix.
#
# Each method here takes a delivered document (see delivery_contexts.rb) and
# returns nil if the matrix's verdict still holds, or the failure message to
# print if it does not. Written as predicates rather than as inline
# expectations for two reasons: the same check runs against four contexts
# without four copies of the message, and the suite can feed each one a
# deliberately-regressed document to prove the check still fires -- which is
# the only way "a component whose backend-less behavior regresses fails the
# suite" is a fact rather than a hope.
module Compat
  module Invariants
    module_function

    # Every failure names both documents, because a matrix verdict and the
    # advice built on it always move together. Whoever changes the behavior
    # owns changing them.
    def violation(headline, mechanism)
      "#{headline}\n\n" \
        "Mechanism: #{mechanism}\n\n" \
        "This is a compatibility-matrix verdict, not a local detail. " \
        "#{Compat::MATRIX_DOC} records it per component and per context, and " \
        "#{Compat::ADVICE_DOC} turns it into advice authors and agents follow. " \
        "If the new behavior is correct, update both in this commit. If it is not, " \
        "a component just went quietly dead in a backend-less context."
    end

    # M1. An exported file is opened from disk with nothing behind it, so the
    # exporter deliberately never ships htmx. That omission -- not the absence
    # of hx-* attributes, which are still emitted -- is what makes every
    # hx-post an export carries inert instead of a 404 per keystroke.
    #
    # Ship htmx into an export and every one of those attributes comes alive
    # against a server that isn't there, flipping the matrix's whole C column
    # from "silent" to "noisy".
    #
    # Matched on the <script> tag rather than on a bare "htmx.org" substring:
    # the substring form would miss a vendored copy, which is exactly how a
    # library sneaks into an export (spec/export/html_exporter_spec.rb makes
    # the same point about mermaid and Chart.js).
    def htmx_never_ships_in_an_export(document)
      return nil unless document.match?(/<script[^>]*htmx/i)

      violation(
        'An export shipped htmx. Exports are opened from disk, so every hx-* attribute ' \
        'in the document would start firing at a server that does not exist.',
        'M1 -- hx-* attributes are emitted in every context; only context C is safe, and ' \
        'only because htmx is never loaded there (html_exporter.rb collect_cdn_scripts).'
      )
    end

    # M2. sendEvent is defined in exactly one place: the bridge's
    # websocket_init_script, which rides in on Adapter::AlpineJS#cdn_scripts.
    # Any document whose markup calls it without that script is disc-095 all
    # over again -- a control that looks live, self-disables on click, then
    # throws a ReferenceError into a console nobody has open.
    #
    # Stated over the delivered document rather than over the adapter on
    # purpose: the reader builds a websocket-mode adapter whose cdn_scripts do
    # define sendEvent, and then deliberately does not emit them. Only the page
    # itself knows which half actually shipped.
    def send_event_is_defined_where_it_is_called(document)
      calls = document.scan('sendEvent(').length
      return nil if calls.zero? || document.include?('window.sendEvent =')

      violation(
        "The document calls sendEvent #{calls} time(s) but never defines it. Those controls " \
        'render as live, self-disable on click, and then throw a ReferenceError.',
        'M2 -- sendEvent exists only inside the bridge cdn_scripts. Markup that dispatches ' \
        'through it must ship alongside them or must degrade honestly instead.'
      )
    end

    # The other half of the same pairing, and the one that catches the fix
    # being applied backwards: a context with no bridge behind it must not
    # define sendEvent either, because a stub would swallow the click and
    # restore exactly the lie disc-095 removed.
    def send_event_is_undefined_where_there_is_no_bridge(document)
      return nil unless document.include?('window.sendEvent =')

      violation(
        'A backend-less document defines sendEvent. Nothing is listening, so every dispatch ' \
        'is swallowed -- the control looks like it worked and the agent never hears about it.',
        'M2 -- the reader omits the bridge cdn_scripts on purpose and renders inert instead. ' \
        'Defining a no-op stub would be the honest-degradation fix applied backwards.'
      )
    end

    # disc-095. Inert output must not merely avoid dispatching -- it must not
    # carry the optimistic half of a dispatch either. `$el.disabled=true;
    # sendEvent(...)` failed in that exact order: the button greyed itself out
    # and then threw.
    #
    # What makes the handler dead is the missing definition, not the disable:
    # on a live canvas that same disable is correct, because the click really
    # does reach an agent. So the check is the conjunction, which lets it be
    # stated over every context at once instead of over a hand-kept list of the
    # backend-less ones -- a list that would go stale the moment a fifth
    # delivery context appears.
    def no_self_disabling_dead_handlers(document)
      return nil unless document.include?('$el.disabled=true')
      return nil if document.include?('window.sendEvent =')

      violation(
        'A backend-less document carries a self-disabling click handler. The control greys ' \
        'itself out on click and then has nothing to dispatch to.',
        'disc-095 / M2 -- inert rendering disables the control up front with an explanatory ' \
        'title. A handler that disables it on click is the failure mode, not the fix.'
      )
    end

    # disc-094. The gate is on the whole chart family, so this is stated as an
    # equivalence rather than as "charts get the library": an export that ships
    # Chart.js for an app with no chart is a smaller bug, but it is still the
    # gate having drifted away from the components.
    #
    # Also matched on the tag: the adapter's lazy-loader prints "Failed to load
    # Chart.js from CDN" and the canvas page carries a "<!-- Chart.js -->"
    # comment, either of which would make a bare substring answer "shipped" for
    # a document that shipped nothing. An equivalence is only as good as the
    # weaker of its two sides.
    def chart_library_tracks_chart_components(document, app:)
      charts = app_has_chart?(app)
      ships  = document.match?(%r{<script[^>]*chart\.(?:umd|js)}i)
      return nil if charts == ships

      violation(
        charts ? 'An export containing a chart shipped no Chart.js. The chart renders as an ' \
                 'empty box with a silent console.'
               : 'An export with no chart shipped Chart.js anyway.',
        'disc-094 / M5 -- the CDN gate keys on Components::ChartBase so every chart shorthand ' \
        '(bar_chart, pie_chart, sparkline, ...) is covered. Gating on a narrower class is what ' \
        'shipped chartless exports before.'
      )
    end

    # M7. The deck reaches its server from inlined JS, not from attributes, so
    # nothing about the markup stops it -- only the adapter refusing to emit
    # the call. Stated as an equivalence so it also catches the read-only
    # rendering leaking into the one context that does serve /deck/*.
    def deck_calls_match_the_declared_deck_server(document, read_only:)
      calls = document.scan('/deck/').length
      return nil if read_only == calls.zero?

      violation(
        read_only ? "A deck rendered where deck_read_only? is true still offers #{calls} " \
                    '/deck/* call(s). Every one of them 404s, after painting the choice as accepted.'
                  : 'A deck rendered against the standalone server offers no /deck/* call at all, ' \
                    'so nothing it records can reach the server that is right there.',
        'disc-096 / M7 -- /deck/select, /deck/note, /deck/submit and friends are mounted by the ' \
        'standalone server only. Every other context must render the deck read-only.'
      )
    end

    # The residue the fixes did not remove, pinned rather than asserted away.
    # Exports still carry hx-* attributes; they are harmless only because
    # htmx_never_ships_in_an_export holds. Pinning the set means the list can
    # only change on purpose, and whoever changes it has to come here and say
    # which way it moved.
    def export_hx_attributes_are_the_pinned_set(document, pinned:)
      found = document.scan(/\shx-[a-z-]+=/).map { |a| a.strip.delete_suffix('=') }.uniq.sort
      return nil if found == pinned.sort

      violation(
        "The set of hx-* attributes an export carries changed.\n" \
        "  pinned: #{pinned.sort.inspect}\n" \
        "  found:  #{found.inspect}\n" \
        'Shrinking it is progress and wanted -- update the pin. Growing it means a new call site ' \
        'started emitting htmx attributes into a document that will never load htmx.',
        'M1 -- most htmx_attrs call sites render identically in every context. See ' \
        'spec/canvas/htmx_call_site_sweep_spec.rb, which owns the per-call-site ledger; this pin ' \
        'is only the shape that residue takes once it reaches a delivered export.'
      )
    end

    # App#has_charts? asks only about ChartBase, which the generic `chart type:`
    # DSL does not build (Components::Chart descends from Base directly), so on
    # its own it would answer "no charts" for the one call the exporter's gate
    # names first. The second half reaches the private walker underneath it,
    # the same way spec/canvas/deck_honest_ui_spec.rb reaches deck_read_only?.
    def app_has_chart?(app)
      app.has_charts? || app.send(:components_include?, StreamWeaver::Components::Chart)
    end
  end
end

# Reads as the claim it is ("this context upholds the pairing") and prints the
# invariant's own message on failure instead of "expected nil, got <a wall of
# text>". Takes a Compat::Context rather than a bare string so the failure can
# open with the matrix's own name for the column that broke.
RSpec::Matchers.define :uphold do |invariant, **kwargs|
  match do |context|
    @violation = Compat::Invariants.public_send(invariant, context.document, **kwargs)
    @violation.nil?
  end

  failure_message { "In #{actual.matrix_column}:\n\n#{@violation}" }
  failure_message_when_negated { "expected #{invariant} to be violated in #{actual.matrix_column}, but it held" }
  description { invariant.to_s.tr('_', ' ') }
end
