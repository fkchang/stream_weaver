# frozen_string_literal: true

module StreamWeaver
  module Components
    module Deck
      # Fixed top bar for cancel confirmation.
      # Slides down from top with confirm/cancel buttons and auto-hide timer.
      #
      # sw- CSS classes:
      #   sw-confirmation-bar              - fixed top bar wrapper
      #   sw-confirmation-bar--visible     - visible state (slide-down)
      #   sw-confirmation-bar__message     - message text
      #   sw-confirmation-bar__actions     - button container
      #   sw-confirmation-bar__btn         - action button base
      #   sw-confirmation-bar__btn--confirm - confirm (destructive) button
      #   sw-confirmation-bar__btn--cancel  - cancel (dismiss) button
      #   sw-confirmation-bar__timer       - auto-hide countdown display
      #
      # @example
      #   confirmation_bar(
      #     message: "Are you sure you want to cancel?",
      #     confirm_label: "Yes, Cancel",
      #     cancel_label: "Keep Going",
      #     auto_hide: 5
      #   )
      class ConfirmationBar < Base
        attr_reader :message, :confirm_label, :cancel_label, :auto_hide

        # @param message [String] Confirmation message
        # @param confirm_label [String] Label for confirm action (default: "Cancel")
        # @param cancel_label [String] Label for dismiss action (default: "Keep Going")
        # @param auto_hide [Integer, nil] Auto-hide after N seconds (default: 5, nil to disable)
        # @param options [Hash] Additional options
        def initialize(message:, confirm_label: "Cancel", cancel_label: "Keep Going",
                       auto_hide: 5, **options)
          @message = message
          @confirm_label = confirm_label
          @cancel_label = cancel_label
          @auto_hide = auto_hide
          super(**options)
        end

        def render(view, state)
          view.adapter.render_confirmation_bar(view, self, state)
        end

        # Whether auto-hide is enabled.
        # @return [Boolean]
        def auto_hide?
          !@auto_hide.nil? && @auto_hide > 0
        end

        # CSS class list
        def css_classes
          "sw-confirmation-bar"
        end
      end
    end
  end
end
