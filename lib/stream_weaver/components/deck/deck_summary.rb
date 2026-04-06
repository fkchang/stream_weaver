# frozen_string_literal: true

module StreamWeaver
  module Components
    module Deck
      # Auto-generated summary slide appended to the end of a design deck.
      # Reads DeckState to display:
      #   - Each slide's title, selected option label, aside text, and notes
      #   - A "Still need: Slide X, Slide Y" message when selections are incomplete
      #   - A final notes textarea for overall comments
      #   - A Submit button gated on all slides having a selection
      #
      # Submit sets state[:_result] with { deck_selections: {...}, deck_notes: {...} }
      # which triggers run_once! to unblock.
      #
      # sw- CSS classes:
      #   sw-deck-summary              - summary slide wrapper
      #   sw-deck-summary__title       - summary heading
      #   sw-deck-summary__cards       - grid of summary cards
      #   sw-deck-summary__card        - individual summary card
      #   sw-deck-summary__card-title  - slide title in card
      #   sw-deck-summary__card-label  - selected option label
      #   sw-deck-summary__card-aside  - aside text
      #   sw-deck-summary__card-notes  - notes text
      #   sw-deck-summary__card--empty - card with no selection
      #   sw-deck-summary__missing     - "still need" message
      #   sw-deck-summary__final-notes - final notes textarea container
      #   sw-deck-summary__submit      - submit button
      #   sw-deck-summary__submit--disabled - disabled submit button
      #
      # @example Auto-appended by design_deck DSL method (no manual usage needed)
      class DeckSummary < Base
        attr_accessor :deck_slides

        def initialize(**options)
          @deck_slides = []
          super(**options)
        end

        def render(view, state)
          view.adapter.render_deck_summary(view, self, state)
        end

        # CSS class list
        def css_classes
          "sw-deck-summary"
        end

        # Check if all slides have selections
        #
        # @param deck_state [DeckState, nil] The deck state instance
        # @return [Boolean] true if every slide has a selection
        def all_selected?(deck_state)
          return false unless deck_state
          return true if @deck_slides.empty?

          @deck_slides.all? { |slide| deck_state.selection(slide.id) }
        end

        # Get list of slide titles that still need selections
        #
        # @param deck_state [DeckState, nil] The deck state instance
        # @return [Array<String>] titles of slides missing selections
        def missing_slides(deck_state)
          return @deck_slides.map { |s| s.title || s.id } unless deck_state

          @deck_slides.reject { |slide| deck_state.selection(slide.id) }
                      .map { |s| s.title || s.id }
        end
      end
    end
  end
end
