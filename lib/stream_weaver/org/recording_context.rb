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
    class RecordingContext
      include StreamWeaver::DisplayDSL

      attr_accessor :components
      attr_reader :state, :render_state

      def initialize
        @components = []
        @state = {}
        @render_state = StreamWeaver::App::RenderState.new
      end

      def use_theme(_name); end
      def use_layout(_name); end
    end
  end
end
