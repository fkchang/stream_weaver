# frozen_string_literal: true

module StreamWeaver
  module Components
    module Deck
      # Shimmer animation placeholder shown while options are being generated.
      # Rendered for (requested_count - received_count) placeholders.
      #
      # sw- CSS classes:
      #   sw-skeleton                  - skeleton card wrapper
      #   sw-skeleton__line            - shimmer line element
      #   sw-skeleton__line--title     - wider title line
      #   sw-skeleton__line--body      - narrower body line
      #
      # @example
      #   SkeletonPlaceholder.new(index: 0)
      class SkeletonPlaceholder < Base
        attr_reader :index

        # @param index [Integer] Index of this skeleton (for staggered animation)
        def initialize(index: 0, **options)
          @index = index
          super(**options)
        end

        def render(view, state)
          view.adapter.render_skeleton_placeholder(view, self, state)
        end

        def css_classes
          "sw-skeleton"
        end
      end
    end
  end
end
