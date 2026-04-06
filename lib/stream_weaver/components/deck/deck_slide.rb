# frozen_string_literal: true

module StreamWeaver
  module Components
    module Deck
      # A single decision slide within a DesignDeck.
      # Contains DeckOption children rendered as a grid of option cards.
      #
      # Auto-column detection based on option count:
      #   1 option  -> 1 column
      #   2 options -> 2 columns
      #   3 options -> 3 columns
      #   4+ options -> 2 columns
      #
      # sw- CSS classes:
      #   sw-deck-slide              - slide wrapper
      #   sw-deck-slide__title       - slide title
      #   sw-deck-slide__context     - context text above options
      #   sw-deck-slide__grid        - options grid container
      #
      # @example
      #   slide "arch", "System Architecture", context: "Choose the backend" do
      #     option "Monolith" do
      #       code_block "...", lang: "ts"
      #     end
      #   end
      class DeckSlide < Base
        attr_reader :id, :title, :context_text, :columns
        attr_accessor :children

        # @param id [String] Unique slide identifier
        # @param title [String, nil] Slide title
        # @param context [String, nil] Context text displayed above the options
        # @param columns [Integer, nil] Override auto-detected column count
        # @param options [Hash] Additional options
        def initialize(id, title = nil, context: nil, columns: nil, **options)
          @id = id.to_s
          @title = title
          @context_text = context
          @columns = columns
          @children = []
          super(**options)
        end

        def render(view, state)
          view.adapter.render_deck_slide(view, self, state)
        end

        # Auto-detect the number of grid columns from option count.
        # Can be overridden with the columns: parameter.
        #
        # @return [Integer] Number of grid columns
        def auto_columns
          return @columns if @columns

          count = option_count
          case count
          when 0, 1 then 1
          when 2 then 2
          when 3 then 3
          else 2
          end
        end

        # Count only DeckOption children (not other components)
        def option_count
          @children.count { |c| c.is_a?(DeckOption) }
        end

        # CSS class list
        def css_classes
          "sw-deck-slide"
        end
      end
    end
  end
end
