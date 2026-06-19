# frozen_string_literal: true

module StreamWeaver
  module Components
    # Single API endpoint spec card: method badge, path, description, params table, response schema.
    # DSL: api_endpoint(method: "POST", path: "/users", description: "Create user",
    #                   params: [{name: "email", type: "string", required: true}],
    #                   response: {id: "integer", email: "string"})
    class ApiEndpoint < Base
      DEFAULT_BADGE_COLOR = "#6b7280"
      BADGE_COLORS = {
        "GET"     => "#2563eb",
        "POST"    => "#16a34a",
        "PUT"     => "#d97706",
        "PATCH"   => "#d97706",
        "DELETE"  => "#dc2626",
        "HEAD"    => DEFAULT_BADGE_COLOR,
        "OPTIONS" => DEFAULT_BADGE_COLOR
      }.freeze

      attr_reader :http_method, :path, :description, :params, :response

      def initialize(method:, path:, description: nil, params: [], response: {}, **options)
        @http_method = method.to_s.upcase
        @path        = path.to_s
        @description = description
        @params      = Array(params)
        @response    = response.is_a?(Hash) ? response : {}
        @options     = options
      end

      def badge_color = BADGE_COLORS.fetch(@http_method, DEFAULT_BADGE_COLOR)
      def description? = @description && !@description.empty?
      def params?      = @params.any?
      def response?    = !@response.empty?

      def render(view, state)
        view.adapter.render_api_endpoint(view, self, state)
      end
    end
  end
end
