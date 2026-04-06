# frozen_string_literal: true

module StreamWeaver
  module Components
    module Deck
      # AI model picker for generate-more functionality.
      # Renders provider filter pills and a model list.
      # Selected model is stored in DeckState for use by generate-more.
      #
      # sw- CSS classes:
      #   sw-model-selector              - outermost wrapper
      #   sw-model-selector__pills       - provider filter pill row
      #   sw-model-selector__pill        - individual provider pill
      #   sw-model-selector__pill--active - active provider pill
      #   sw-model-selector__list        - model list container
      #   sw-model-selector__item        - individual model item
      #   sw-model-selector__item--selected - selected model item
      #   sw-model-selector__name        - model display name
      #   sw-model-selector__provider    - model provider label
      #
      # @example
      #   model_selector(
      #     models: [
      #       { id: "claude-3", name: "Claude 3 Opus", provider: "Anthropic" },
      #       { id: "gpt-4", name: "GPT-4", provider: "OpenAI" }
      #     ],
      #     default_model: "claude-3"
      #   )
      class ModelSelector < Base
        attr_reader :models, :default_model

        # @param models [Array<Hash>] Array of { id:, name:, provider: } hashes
        # @param default_model [String, nil] ID of the default selected model
        # @param options [Hash] Additional options
        def initialize(models: [], default_model: nil, **options)
          @models = normalize_models(models)
          @default_model = default_model || @models.first&.dig(:id)
          super(**options)
        end

        def render(view, state)
          view.adapter.render_model_selector(view, self, state)
        end

        # All unique provider names from the model list, sorted.
        # @return [Array<String>]
        def providers
          @models.map { |m| m[:provider] }.uniq.sort
        end

        # Models filtered by provider (nil returns all).
        # @param provider [String, nil] Provider name or nil for all
        # @return [Array<Hash>]
        def models_for_provider(provider)
          return @models if provider.nil? || provider == "All"
          @models.select { |m| m[:provider] == provider }
        end

        # Whether to show the selector (hidden when fewer than 2 models).
        # @return [Boolean]
        def visible?
          @models.length >= 2
        end

        # CSS class list
        def css_classes
          "sw-model-selector"
        end

        private

        def normalize_models(models)
          models.map do |m|
            {
              id: (m[:id] || m["id"]).to_s,
              name: (m[:name] || m["name"]).to_s,
              provider: (m[:provider] || m["provider"]).to_s
            }
          end
        end
      end
    end
  end
end
