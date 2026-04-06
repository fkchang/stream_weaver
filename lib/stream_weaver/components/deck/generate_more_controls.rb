# frozen_string_literal: true

module StreamWeaver
  module Components
    module Deck
      # Generate-more controls rendered within a deck slide footer.
      # Provides prompt input, count dropdown, generate/cancel buttons,
      # and status display during generation.
      #
      # sw- CSS classes:
      #   sw-generate-more                  - controls wrapper
      #   sw-generate-more__form            - form with prompt + count + button
      #   sw-generate-more__prompt          - prompt text input
      #   sw-generate-more__count           - count dropdown
      #   sw-generate-more__btn             - generate button
      #   sw-generate-more__btn--cancel     - cancel button
      #   sw-generate-more__status          - status banner during generation
      #   sw-generate-more__status-dot      - animated pulse dot
      #   sw-generate-more__status-text     - status text
      #
      # @example
      #   GenerateMoreControls.new("arch", generate_state: gen_state)
      class GenerateMoreControls < Base
        attr_reader :slide_id

        # @param slide_id [String] Slide this controls belong to
        # @param generate_state [Hash] Current generation state from DeckState
        # @param timeout [Integer] Timeout in seconds (default: 15)
        def initialize(slide_id, generate_state: {}, timeout: 15, **options)
          @slide_id = slide_id.to_s
          @generate_state = generate_state
          @timeout = timeout
          super(**options)
        end

        def render(view, state)
          view.adapter.render_generate_more_controls(view, self, state)
        end

        # Current generation status
        # @return [Symbol] :idle, :generating, :timed_out, or :cancelled
        def status
          (@generate_state["status"] || "idle").to_sym
        end

        def generating?
          status == :generating
        end

        def timed_out?
          status == :timed_out
        end

        def requested_count
          @generate_state["requested_count"] || 0
        end

        def received_count
          @generate_state["received_count"] || 0
        end

        def remaining_count
          generating? ? [requested_count - received_count, 0].max : 0
        end

        def prompt
          @generate_state["prompt"]
        end

        def request_id
          @generate_state["request_id"]
        end

        def timeout
          @timeout
        end

        def css_classes
          "sw-generate-more"
        end
      end
    end
  end
end
