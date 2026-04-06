# frozen_string_literal: true

module StreamWeaver
  module Components
    module Deck
      # Top-level orchestrator for a design deck.
      # Contains DeckSlide children, wraps in SlideContainer with :swap mode,
      # validates uniqueness of slide IDs, and auto-appends navigation.
      #
      # NOT an App subclass -- it is a component composed via DSL methods on App.
      #
      # sw- CSS classes:
      #   sw-deck             - outermost deck wrapper
      #   sw-deck__title      - deck title heading
      #
      # @example
      #   design_deck "Architecture Direction" do
      #     slide "arch", "System Architecture" do
      #       option "Monolith" do
      #         code_block "app.listen(3000)", lang: "ts"
      #       end
      #     end
      #   end
      class DesignDeck < Base
        attr_reader :title
        attr_accessor :children

        # @param title [String] Deck title
        # @param options [Hash] Additional options
        def initialize(title, **options)
          @title = title
          @children = []
          super(**options)
        end

        def render(view, state)
          view.adapter.render_design_deck(view, self, state)
        end

        # Validate the deck structure.
        # Raises if duplicate slide IDs are found.
        def validate!
          ids = @children
            .select { |c| c.is_a?(DeckSlide) }
            .map(&:id)

          dupes = ids.group_by(&:itself).select { |_k, v| v.size > 1 }.keys
          unless dupes.empty?
            raise ArgumentError, "Duplicate slide IDs in design_deck: #{dupes.join(', ')}"
          end
        end

        # CSS class list
        def css_classes
          "sw-deck"
        end
      end
    end
  end
end
