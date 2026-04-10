# frozen_string_literal: true

module StreamWeaver
  module Resource
    module Store
      REQUIRED_METHODS = %i[all find create update destroy].freeze

      def self.validate!(store, resource_name)
        missing = REQUIRED_METHODS.reject { |m| store.respond_to?(m) }
        return if missing.empty?
        raise ArgumentError,
          "StreamWeaver resource :#{resource_name} — store #{store.inspect} " \
          "is missing required methods: #{missing.join(', ')}. " \
          "Store must respond to: #{REQUIRED_METHODS.join(', ')}"
      end
    end
  end
end
