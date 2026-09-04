# frozen_string_literal: true

require_relative "../display_dsl"
require_relative "../app"

module StreamWeaver
  module Org
    # Evaluates a saved DSL body (the same text canvas-read instance_evals to
    # render HTML) against a bare context that shares StreamWeaver::DisplayDSL's
    # real component-building logic, WITHOUT rendering anything. After eval,
    # `components` holds the exact same Components::* tree (with real
    # #children/#before_children/#after_children) the live renderer would
    # build -- the Writer walks this tree directly instead of re-parsing
    # Ruby source.
    #
    # #state and #render_state exist only because DisplayDSL#table calls them
    # unconditionally (even for a plain static headers:/rows: table, not just
    # column-DSL tables) -- nothing else in this class's supported vocabulary
    # needs them, but table's own body isn't optional to satisfy.
    #
    # #use_theme/#use_layout exist because DocStore.dsl_with_metadata
    # (doc_store.rb) prepends `use_theme :x` / `use_layout :y` lines to every
    # real saved doc at Save-as-doc time -- these are App-only methods, not
    # part of DisplayDSL, so any real saved doc crashes instance_eval without
    # them. No-ops here: the Writer only needs the component tree, not
    # theme/layout state (org format doesn't represent either).
    #
    # Everything ELSE the DSL can say -- App's whole interactive vocabulary
    # (radio_group, text_field, form, ...), charts, layout shells -- is
    # absorbed by #method_missing as an UnsupportedCall placeholder rather
    # than raising, so a Save-as-Org can never die on a call this context
    # does not define. That is a claim about UNDEFINED calls only: a
    # DisplayDSL method that this context's half-set-up state trips over
    # never reaches method_missing at all (see @_state in #initialize for the
    # one that did), so new state DisplayDSL starts depending on has to be
    # set up here explicitly.
    class RecordingContext
      include StreamWeaver::DisplayDSL

      # Stand-in for a DSL call this context builds no real component for.
      # It records WHAT was called and nothing else -- deciding what a saved
      # .org should do with it is the Writer's job (Writer::INTERACTIVE_CALLS).
      UnsupportedCall = Struct.new(:name)

      attr_accessor :components
      attr_reader :state, :render_state

      def initialize
        @components = []
        # @_state is the ivar DisplayDSL's own stateful components write to
        # directly -- `select` does `@_state[key] = ...` with no nil guard on
        # the write path (display_dsl.rb), so leaving it nil turned any doc
        # containing a select into a NoMethodError on nil at save time. It is
        # the same throwaway hash as #state here: this context records a
        # component tree and never renders, so nothing reads either back.
        @state = @_state = {}
        @render_state = StreamWeaver::App::RenderState.new
      end

      def use_theme(_name); end
      def use_layout(_name); end

      # Two things the code below can't say for itself:
      #
      # The block is deliberately NOT evaluated. For an interactive container
      # (`form do ... end`) its children are part of the control the Writer
      # drops; for anything else the whole statement -- block included -- is
      # what Writer#raw_passthrough recovers verbatim from the source.
      #
      # `to_*` keeps raising, because it's Ruby's implicit-conversion
      # protocol (to_ary/to_str/to_hash/to_proc): answering one of those with
      # a nil placeholder turns a harmless duck-type probe into a TypeError
      # somewhere far away.
      def method_missing(name, *_args, **_kwargs, &_block)
        return super if name.to_s.start_with?("to_")

        components << UnsupportedCall.new(name)
        nil
      end

      def respond_to_missing?(name, _include_private = false)
        !name.to_s.start_with?("to_")
      end
    end
  end
end
