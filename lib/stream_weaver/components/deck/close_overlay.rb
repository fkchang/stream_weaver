# frozen_string_literal: true

module StreamWeaver
  module Components
    module Deck
      # Full-screen overlay shown after deck submit or cancel.
      # Displays a status message with blur backdrop and optional auto-close tab.
      #
      # sw- CSS classes:
      #   sw-close-overlay                  - full-screen overlay wrapper
      #   sw-close-overlay--submitted       - green status (submitted)
      #   sw-close-overlay--cancelled       - amber status (cancelled)
      #   sw-close-overlay__backdrop        - blur backdrop layer
      #   sw-close-overlay__content         - centered content box
      #   sw-close-overlay__icon            - status icon (checkmark or X)
      #   sw-close-overlay__message         - status message text
      #   sw-close-overlay__countdown       - auto-close countdown display
      #   sw-close-overlay__close-btn       - manual close button
      #
      # @example
      #   close_overlay(status: :submitted, message: "Deck submitted successfully!")
      #   close_overlay(status: :cancelled, message: "Deck cancelled.")
      class CloseOverlay < Base
        attr_reader :status, :message, :auto_close_delay

        VALID_STATUSES = [:submitted, :cancelled].freeze

        # @param status [Symbol] Status type (:submitted or :cancelled)
        # @param message [String] Status message to display
        # @param auto_close_delay [Integer] Delay before auto-closing tab in ms (default: 800)
        # @param options [Hash] Additional options
        def initialize(status:, message:, auto_close_delay: 800, **options)
          @status = validate_status(status)
          @message = message
          @auto_close_delay = auto_close_delay
          super(**options)
        end

        def render(view, state)
          view.adapter.render_close_overlay(view, self, state)
        end

        # Whether this is a submitted status.
        # @return [Boolean]
        def submitted?
          @status == :submitted
        end

        # Whether this is a cancelled status.
        # @return [Boolean]
        def cancelled?
          @status == :cancelled
        end

        # Status-specific CSS modifier class.
        # @return [String]
        def status_modifier
          "sw-close-overlay--#{@status}"
        end

        # CSS class list
        def css_classes
          "sw-close-overlay #{status_modifier}"
        end

        # Status icon character.
        # @return [String]
        def icon
          submitted? ? "✓" : "✕"
        end

        private

        def validate_status(status)
          status = status.to_sym
          unless VALID_STATUSES.include?(status)
            raise ArgumentError, "Invalid status '#{status}'. Must be one of: #{VALID_STATUSES.join(', ')}"
          end
          status
        end
      end
    end
  end
end
