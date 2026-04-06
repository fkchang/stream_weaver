#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Visual Explainer — Diff Review
# A comprehensive code review document showcasing every explainer component.
# Scenario: AI agent reviews a PR that migrates from session-based auth to JWT.
#
# Run with: bundle exec ruby examples/visual_skills/explainer_demo.rb

require_relative '../../lib/stream_weaver'

ExplainerApp = app "Diff Review: feature/auth-migration", theme: :dark do
  # -- Theme & chrome ----------------------------------------------------------
  theme_preset :editorial
  theme_toggle mode: :auto, hotkey: "mod+shift+l"

  # -- Sidebar TOC with scroll spy ---------------------------------------------
  sidebar_toc sections: [
    { id: "summary",      label: "Summary" },
    { id: "kpis",         label: "Key Metrics" },
    { id: "architecture", label: "Architecture" },
    { id: "file-changes", label: "File Changes" },
    { id: "auth-before-after", label: "Auth Diff" },
    { id: "middleware",    label: "Middleware" },
    { id: "pipeline",     label: "CI Pipeline" },
    { id: "test-coverage", label: "Test Coverage" },
    { id: "risks",        label: "Risk Analysis" },
    { id: "verdict",      label: "Verdict" }
  ]

  # -- Hero section ------------------------------------------------------------
  div id: "summary" do
    hero do
      header1 "Diff Review: feature/auth-migration"
      md "**PR #347** &mdash; Migrate from session-based authentication to JWT tokens"
      hstack spacing: :md, align: :center do
        badge "87 files changed", variant: :info
        badge "+2,041 / -1,388", variant: :warning
        badge "3 open threads", variant: :danger
        badge "CI passing", variant: :success
      end
    end
  end

  # -- Executive summary (prose) -----------------------------------------------
  prose dropcap: true do
    md <<~MARKDOWN
      This pull request replaces the legacy cookie-based session authentication
      system with a stateless JWT token architecture. The migration touches the
      authentication middleware, all protected API endpoints, the user model,
      and the front-end token refresh logic. Session storage in Redis is replaced
      by short-lived access tokens (15 min) paired with long-lived refresh tokens
      (7 days) stored in an HttpOnly cookie.

      The change is motivated by three factors: horizontal scaling without sticky
      sessions, enabling a mobile API surface, and reducing Redis operational
      burden. The overall approach is sound, but several security and performance
      concerns require resolution before merge.
    MARKDOWN
  end

  pullquote(
    "Stateless auth is not free -- you trade server-side revocation for scalability. Make sure the trade is worth it.",
    attribution: "Security Review Bot"
  )

  # -- KPI dashboard -----------------------------------------------------------
  div id: "kpis" do
    header2 "Key Metrics"

    kpi_dashboard metrics: [
      { value: "87",     label: "Files Changed",     color: :blue,   trend: :up },
      { value: "+2,041", label: "Lines Added",        color: :green,  trend: :up },
      { value: "-1,388", label: "Lines Removed",      color: :red,    trend: :down },
      { value: "94.2%",  label: "Test Coverage",      color: :green,  trend: :up },
      { value: "15 min", label: "Access Token TTL",   color: :orange },
      { value: "7 days", label: "Refresh Token TTL",  color: :purple }
    ]
  end

  # -- Test coverage chart -----------------------------------------------------
  div id: "test-coverage" do
    header2 "Test Coverage Trend"

    chart type: :line, data: {
      labels: ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5", "This PR"],
      datasets: [
        {
          label: "Line Coverage %",
          data: [88.1, 89.3, 90.0, 91.5, 92.8, 94.2],
          borderColor: "#22c55e",
          backgroundColor: "rgba(34, 197, 94, 0.1)",
          fill: true,
          tension: 0.3
        },
        {
          label: "Branch Coverage %",
          data: [72.4, 74.0, 75.2, 78.1, 80.5, 83.7],
          borderColor: "#3b82f6",
          backgroundColor: "rgba(59, 130, 246, 0.1)",
          fill: true,
          tension: 0.3
        }
      ]
    }, options: {
      plugins: { title: { display: true, text: "Coverage Over Sprint" } },
      scales: {
        y: { min: 60, max: 100, ticks: { callback: "function(v){return v+'%'}" } }
      }
    }, height: 280

    md "*Coverage improved from 88.1% to 94.2% across the sprint. Branch coverage still trails at 83.7%.*"
  end

  # -- Architecture diagram (Mermaid) ------------------------------------------
  div id: "architecture" do
    header2 "Authentication Architecture"

    mermaid <<~MERMAID, zoom: true
      graph TD
        Client["Client (Browser / Mobile)"]
        API["API Gateway"]
        AuthSvc["Auth Service"]
        UserDB[("Users DB")]
        TokenStore["Token Blacklist<br/>(Redis)"]
        Protected["Protected Resources"]

        Client -->|"1. POST /auth/login<br/>email + password"| API
        API -->|"2. Forward"| AuthSvc
        AuthSvc -->|"3. Verify credentials"| UserDB
        AuthSvc -->|"4. Issue JWT pair"| API
        API -->|"5. Set HttpOnly cookie<br/>+ access_token body"| Client

        Client -->|"6. GET /api/resource<br/>Authorization: Bearer token"| API
        API -->|"7. Verify JWT signature<br/>+ check blacklist"| TokenStore
        API -->|"8. Forward (valid)"| Protected
        Protected -->|"9. Response"| Client

        Client -->|"10. POST /auth/refresh"| AuthSvc
        AuthSvc -->|"11. Rotate refresh token"| TokenStore

        style Client fill:#dbeafe,stroke:#3b82f6,color:#1e3a5f
        style AuthSvc fill:#dcfce7,stroke:#22c55e,color:#166534
        style TokenStore fill:#fef3c7,stroke:#f59e0b,color:#92400e
        style UserDB fill:#f3e8ff,stroke:#a855f7,color:#6b21a8
        style Protected fill:#e0e7ff,stroke:#6366f1,color:#3730a3
        style API fill:#f1f5f9,stroke:#94a3b8,color:#334155
    MERMAID
  end

  # -- File changes (dir_tree + legend) ----------------------------------------
  div id: "file-changes" do
    header2 "File Changes"

    legend items: [
      { color: "#22c55e", label: "New" },
      { color: "#f59e0b", label: "Modified" },
      { color: "#ef4444", label: "Deleted" }
    ]

    dir_tree <<~TREE
      app/
        controllers/
          auth_controller.rb [modified]
          sessions_controller.rb [deleted]
          api/
            base_controller.rb [modified]
        middleware/
          jwt_authenticator.rb [new]
          session_authenticator.rb [deleted]
        models/
          user.rb [modified]
          refresh_token.rb [new]
        services/
          token_service.rb [new]
          token_blacklist_service.rb [new]
      config/
        initializers/
          jwt.rb [new]
          session_store.rb [deleted]
        routes.rb [modified]
      spec/
        services/
          token_service_spec.rb [new]
          token_blacklist_service_spec.rb [new]
        middleware/
          jwt_authenticator_spec.rb [new]
        requests/
          auth_spec.rb [modified]
          refresh_spec.rb [new]
      lib/
        jwt_encoder.rb [new]
    TREE
  end

  # -- Before / After comparison -----------------------------------------------
  div id: "auth-before-after" do
    header2 "Authentication Diff"

    comparison(before_label: "Session Auth (before)", after_label: "JWT Auth (after)") do
      before do
        code_block <<~RUBY, lang: "ruby", file: "app/controllers/application_controller.rb"
          class ApplicationController < ActionController::Base
            before_action :require_login

            private

            def require_login
              unless session[:user_id]
                redirect_to login_path
              end
            end

            def current_user
              @current_user ||= User.find(session[:user_id])
            end
          end
        RUBY
      end

      after do
        code_block <<~RUBY, lang: "ruby", file: "app/controllers/api/base_controller.rb"
          class Api::BaseController < ActionController::API
            before_action :authenticate!

            private

            def authenticate!
              token = extract_token(request)
              payload = TokenService.decode(token)
              raise JWT::DecodeError if TokenBlacklistService.revoked?(payload["jti"])
              @current_user = User.find(payload["sub"])
            rescue JWT::DecodeError, JWT::ExpiredSignature => e
              render json: { error: "Unauthorized" }, status: :unauthorized
            end

            def extract_token(request)
              request.headers["Authorization"]&.split(" ")&.last
            end
          end
        RUBY
      end
    end
  end

  # -- Middleware code block ---------------------------------------------------
  div id: "middleware" do
    header2 "New Middleware: JWT Authenticator"

    code_block <<~RUBY, lang: "ruby", file: "app/middleware/jwt_authenticator.rb"
      # frozen_string_literal: true

      class JwtAuthenticator
        EXCLUDED_PATHS = %w[/auth/login /auth/refresh /health].freeze

        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new(env)
          return @app.call(env) if skip_auth?(request.path)

          token = extract_bearer_token(env)
          return unauthorized_response unless token

          payload = TokenService.decode(token)
          return unauthorized_response unless payload
          return unauthorized_response if TokenBlacklistService.revoked?(payload["jti"])

          env["jwt.payload"] = payload
          env["jwt.user_id"] = payload["sub"]
          @app.call(env)
        rescue JWT::ExpiredSignature
          expired_response
        rescue JWT::DecodeError
          unauthorized_response
        end

        private

        def skip_auth?(path)
          EXCLUDED_PATHS.any? { |p| path.start_with?(p) }
        end

        def extract_bearer_token(env)
          auth = env["HTTP_AUTHORIZATION"]
          return nil unless auth&.start_with?("Bearer ")
          auth.split(" ", 2).last
        end

        def unauthorized_response
          [401, { "Content-Type" => "application/json" },
           ['{"error":"Unauthorized","code":"invalid_token"}']]
        end

        def expired_response
          [401, { "Content-Type" => "application/json" },
           ['{"error":"Token expired","code":"token_expired"}']]
        end
      end
    RUBY

    flow_arrow label: "Token lifecycle"

    code_block <<~RUBY, lang: "ruby", file: "app/services/token_service.rb", truncate: 20
      # frozen_string_literal: true

      class TokenService
        ACCESS_TTL  = 15.minutes
        REFRESH_TTL = 7.days

        class << self
          def issue(user)
            jti = SecureRandom.uuid
            access_token = encode(
              sub: user.id,
              jti: jti,
              exp: ACCESS_TTL.from_now.to_i,
              roles: user.roles.pluck(:name)
            )
            refresh_token = RefreshToken.create!(
              user: user,
              token: SecureRandom.hex(32),
              expires_at: REFRESH_TTL.from_now
            )
            { access_token: access_token, refresh_token: refresh_token.token }
          end

          def decode(token)
            JWT.decode(token, secret_key, true, algorithm: "HS256").first
          end

          def revoke(jti, exp)
            TokenBlacklistService.revoke(jti, ttl: exp - Time.now.to_i)
          end

          private

          def encode(payload)
            JWT.encode(payload, secret_key, "HS256")
          end

          def secret_key
            Rails.application.credentials.jwt_secret_key
          end
        end
      end
    RUBY
  end

  # -- CI Pipeline visualization -----------------------------------------------
  div id: "pipeline" do
    header2 "CI Pipeline Status"

    pipeline steps: [
      { label: "Lint",          description: "RuboCop + ESLint",         status: :complete },
      { label: "Unit Tests",    description: "RSpec (412 examples)",     status: :complete },
      { label: "Integration",   description: "Request specs + JWT flow", status: :complete },
      { label: "Security Scan", description: "Brakeman + bundler-audit", status: :active },
      { label: "Staging Deploy", description: "Auto-deploy to staging",  status: :pending },
      { label: "QA Sign-off",   description: "Manual verification",      status: :pending }
    ]
  end

  # -- Callouts (all variants) -------------------------------------------------
  div id: "risks" do
    header2 "Risk Analysis"

    callout(variant: :error, title: "Critical: Token Revocation Gap") do
      md <<~MD
        Access tokens remain valid for up to **15 minutes** after a user is
        deactivated or their password is changed. The blacklist check mitigates
        this for explicit logouts, but admin-initiated deactivation does not
        currently trigger token revocation.

        **Recommendation:** Add an `after_update` callback on `User` that
        blacklists all active JTIs when `deactivated_at` changes.
      MD
    end

    callout(variant: :warning, title: "Refresh Token Rotation") do
      md <<~MD
        The current implementation does **not** rotate refresh tokens on use.
        A stolen refresh token grants persistent access for the full 7-day window.

        **Recommendation:** Implement refresh token rotation -- issue a new
        refresh token on each `/auth/refresh` call and invalidate the old one.
        Detect token reuse as a sign of compromise and revoke the entire family.
      MD
    end

    callout(variant: :info, title: "CORS Configuration") do
      md <<~MD
        The JWT-based API will be consumed by the mobile app and potentially
        third-party integrations. Ensure `Access-Control-Allow-Headers` includes
        `Authorization` and that the CORS origin whitelist is properly configured
        in `config/initializers/cors.rb`.
      MD
    end

    callout(variant: :success, title: "Improved Horizontal Scalability") do
      md <<~MD
        With session state removed from Redis, the application can now be
        load-balanced across any number of instances without sticky sessions.
        Token verification is purely CPU-bound (HMAC-SHA256), enabling true
        stateless horizontal scaling.
      MD
    end

    callout(variant: :tip, title: "Future Enhancement: Key Rotation") do
      md <<~MD
        Consider implementing JWT signing key rotation using JWK Sets (JWKS).
        This enables zero-downtime key rotation and allows token verification
        by external services without sharing the secret key.
      MD
    end
  end

  # -- Test breakdown chart ----------------------------------------------------
  chart type: :bar, data: {
    labels: [
      "TokenService", "JwtAuthenticator", "AuthController",
      "RefreshToken", "Blacklist", "Integration"
    ],
    datasets: [
      {
        label: "Tests Added",
        data: [18, 14, 12, 8, 6, 24],
        backgroundColor: "#22c55e"
      },
      {
        label: "Tests Modified",
        data: [0, 0, 8, 3, 0, 12],
        backgroundColor: "#f59e0b"
      },
      {
        label: "Tests Removed",
        data: [0, 0, 6, 0, 0, 4],
        backgroundColor: "#ef4444"
      }
    ]
  }, options: {
    plugins: {
      title: { display: true, text: "Test Suite Changes by Component" }
    },
    scales: {
      x: { stacked: true },
      y: { stacked: true, title: { display: true, text: "Number of Tests" } }
    }
  }, height: 300

  # -- Verdict -----------------------------------------------------------------
  div id: "verdict" do
    header2 "Review Verdict"

    hstack spacing: :md, align: :center do
      status_dot status: :yellow, pulse: true
      header3 "Request Changes"
    end

    prose do
      md <<~MARKDOWN
        The architectural approach is solid and well-structured. The separation
        of concerns between `TokenService`, `TokenBlacklistService`, and the
        `JwtAuthenticator` middleware is clean and testable. Test coverage has
        improved meaningfully.

        However, **two blocking issues** must be resolved:

        1. **Token revocation on user deactivation** -- admin-initiated account
           disabling must immediately invalidate all outstanding tokens.
        2. **Refresh token rotation** -- the current implementation is vulnerable
           to refresh token theft without rotation and reuse detection.

        Additionally, the CORS configuration should be verified in a staging
        environment before merging.
      MARKDOWN
    end

    pullquote(
      "The bones are excellent. Fix the revocation gap and token rotation, and this ships.",
      attribution: "AI Review Agent v2.4"
    )

    # -- Score summary table ---------------------------------------------------
    header3 "Review Scores"
    score_table scores: [
      { label: "Code Quality",       score: 9,  max: 10 },
      { label: "Test Coverage",      score: 8,  max: 10 },
      { label: "Security Posture",   score: 6,  max: 10 },
      { label: "Architecture",       score: 9,  max: 10 },
      { label: "Documentation",      score: 7,  max: 10 },
      { label: "Migration Safety",   score: 7,  max: 10 }
    ]
  end
end

ExplainerApp.run! if __FILE__ == $0
