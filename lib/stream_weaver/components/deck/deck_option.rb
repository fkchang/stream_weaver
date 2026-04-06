# frozen_string_literal: true

module StreamWeaver
  module Components
    module Deck
      # A selectable option card within a DeckSlide.
      # Displays a label, optional preview content (mermaid, code_block, etc.),
      # optional aside text, recommended badge, and a notes textarea.
      #
      # ARIA: role="radio", aria-checked (selection state is T8 concern,
      # but the structural ARIA attributes are set here).
      #
      # sw- CSS classes:
      #   sw-deck-option                  - option card wrapper
      #   sw-deck-option--recommended     - when recommended: true
      #   sw-deck-option__radio           - radio indicator circle
      #   sw-deck-option__header          - label header area
      #   sw-deck-option__label           - label text
      #   sw-deck-option__badge           - "Recommended" badge
      #   sw-deck-option__preview         - preview content area
      #   sw-deck-option__aside           - aside text below preview
      #   sw-deck-option__notes           - notes textarea container
      #   sw-deck-option__notes-input     - the textarea itself
      #
      # @example
      #   option "Monolith", aside: "Simple deployment", recommended: true do
      #     mermaid "graph TD; A-->B", compact: true
      #   end
      class DeckOption < Base
        attr_reader :label, :aside, :recommended, :description
        attr_accessor :children, :slide_id, :option_index

        # @param label [String] Option label text
        # @param aside [String, nil] Aside text displayed below the preview
        # @param recommended [Boolean] Whether to show "Recommended" badge
        # @param description [String, nil] Description text (for tooltip/aria)
        # @param options [Hash] Additional options
        def initialize(label, aside: nil, recommended: false, description: nil, **options)
          @label = label
          @aside = aside
          @recommended = recommended
          @description = description
          @children = []
          super(**options)
        end

        def render(view, state)
          view.adapter.render_deck_option(view, self, state)
        end

        # CSS class list (selected state added dynamically by adapter)
        def css_classes(selected: false)
          classes = ["sw-deck-option"]
          classes << "sw-deck-option--recommended" if @recommended
          classes << "sw-deck-option--selected" if selected
          classes.join(" ")
        end
      end
    end
  end
end
