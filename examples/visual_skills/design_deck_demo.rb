#!/usr/bin/env ruby
# frozen_string_literal: true

# Design Deck Demo: API Gateway Architecture Review
# ---------------------------------------------------
# A realistic architectural decision deck demonstrating the full
# design_deck component suite: slides, options with mermaid diagrams
# and code blocks, recommended badges, aside text, and theme presets.

require_relative '../../lib/stream_weaver'

App = app "API Gateway Architecture Review", theme: :dark do
  theme_preset :technical
  theme_toggle mode: :auto

  design_deck "API Gateway Architecture Review" do

    # =========================================================
    # Slide 1: Gateway Topology
    # =========================================================
    slide "topology", "Gateway Topology",
          context: "How should traffic enter our platform? This decision affects latency, blast radius, and operational complexity across all downstream services." do

      option "Single Gateway",
             aside: "Lowest operational overhead. One deployment to manage, but a single point of failure.",
             recommended: false do
        mermaid <<~MERMAID, compact: true
          graph TD
            Client([Client Apps]) --> GW[API Gateway]
            GW --> AuthSvc[Auth Service]
            GW --> OrderSvc[Order Service]
            GW --> InventorySvc[Inventory Service]
            GW --> NotifySvc[Notification Service]
            style GW fill:#3b82f6,stroke:#1e40af,color:#fff
        MERMAID
      end

      option "BFF Pattern (Backend for Frontend)",
             aside: "Each client type gets a tailored gateway. Reduces payload bloat for mobile clients by 40-60%.",
             recommended: true do
        mermaid <<~MERMAID, compact: true
          graph TD
            WebApp([Web App]) --> WebBFF[Web BFF]
            MobileApp([Mobile App]) --> MobileBFF[Mobile BFF]
            Partner([Partner API]) --> PartnerBFF[Partner BFF]
            WebBFF --> Services{Microservices}
            MobileBFF --> Services
            PartnerBFF --> Services
            style WebBFF fill:#22c55e,stroke:#15803d,color:#fff
            style MobileBFF fill:#22c55e,stroke:#15803d,color:#fff
            style PartnerBFF fill:#22c55e,stroke:#15803d,color:#fff
        MERMAID
      end

      option "Service Mesh with Sidecar",
             aside: "Maximum observability and zero-trust networking. Higher infra cost and operational complexity." do
        mermaid <<~MERMAID, compact: true
          graph TD
            LB([Load Balancer]) --> Ingress[Ingress Controller]
            Ingress --> PodA
            Ingress --> PodB
            Ingress --> PodC
            subgraph PodA [Pod A]
              ProxyA[Envoy Sidecar] --> SvcA[Auth Service]
            end
            subgraph PodB [Pod B]
              ProxyB[Envoy Sidecar] --> SvcB[Order Service]
            end
            subgraph PodC [Pod C]
              ProxyC[Envoy Sidecar] --> SvcC[Inventory Service]
            end
            style ProxyA fill:#f59e0b,stroke:#b45309,color:#000
            style ProxyB fill:#f59e0b,stroke:#b45309,color:#000
            style ProxyC fill:#f59e0b,stroke:#b45309,color:#000
        MERMAID
      end
    end

    # =========================================================
    # Slide 2: Authentication Strategy
    # =========================================================
    slide "auth", "Authentication Strategy",
          context: "The auth layer must support both first-party SPAs and third-party integrations with distinct security profiles. Target: <5ms overhead per request." do

      option "JWT with Gateway Validation",
             aside: "Stateless tokens validated at the edge. No downstream auth calls needed. Token revocation requires a deny-list.",
             recommended: true do
        code_block <<~CODE, lang: "yaml", file: "gateway/auth-policy.yaml", truncate: 14
          apiVersion: security.istio.io/v1
          kind: AuthorizationPolicy
          metadata:
            name: gateway-jwt-auth
            namespace: api-gateway
          spec:
            selector:
              matchLabels:
                app: api-gateway
            rules:
              - from:
                  - source:
                      requestPrincipals: ["https://auth.platform.io/*"]
                when:
                  - key: request.auth.claims[aud]
                    values: ["api.platform.io"]
                  - key: request.auth.claims[scope]
                    notValues: ["admin:*"]
        CODE
      end

      option "OAuth2 + Opaque Tokens",
             aside: "Tokens validated via introspection endpoint. Simpler revocation but adds ~8ms latency per request." do
        mermaid <<~MERMAID, compact: true
          sequenceDiagram
            participant C as Client
            participant GW as Gateway
            participant AS as Auth Server
            participant API as API Service
            C->>GW: Request + Bearer Token
            GW->>AS: POST /introspect
            AS-->>GW: {active: true, scope: "read"}
            GW->>API: Forward + X-User-Claims
            API-->>GW: Response
            GW-->>C: Response
        MERMAID
      end

      option "mTLS + Service Accounts",
             aside: "Certificate-based identity at transport layer. Best for service-to-service; poor UX for browser clients." do
        code_block <<~CODE, lang: "go", file: "gateway/mtls_config.go", truncate: 16
          package gateway

          import (
              "crypto/tls"
              "crypto/x509"
              "os"
          )

          func NewMTLSConfig() *tls.Config {
              caCert, _ := os.ReadFile("/etc/certs/ca.pem")
              caCertPool := x509.NewCertPool()
              caCertPool.AppendCertsFromPEM(caCert)

              cert, _ := tls.LoadX509KeyPair(
                  "/etc/certs/gateway.pem",
                  "/etc/certs/gateway-key.pem",
              )

              return &tls.Config{
                  ClientCAs:    caCertPool,
                  ClientAuth:   tls.RequireAndVerifyClientCert,
                  Certificates: []tls.Certificate{cert},
                  MinVersion:   tls.VersionTLS13,
              }
          }
        CODE
      end
    end

    # =========================================================
    # Slide 3: Rate Limiting & Resilience
    # =========================================================
    slide "resilience", "Rate Limiting & Resilience",
          context: "Our API serves 12k req/s at peak. We need to protect downstream services from cascading failures while maintaining fair access for all tenants." do

      option "Token Bucket per Tenant",
             aside: "Simple, predictable quotas. Each tenant gets a fixed bucket refilled at a steady rate. Easy to reason about.",
             recommended: true do
        code_block <<~CODE, lang: "ruby", file: "lib/rate_limiter/token_bucket.rb"
          class TokenBucket
            LUA_SCRIPT = <<~LUA
              local key = KEYS[1]
              local capacity = tonumber(ARGV[1])
              local refill_rate = tonumber(ARGV[2])
              local now = tonumber(ARGV[3])
              local requested = tonumber(ARGV[4])

              local bucket = redis.call('hmget', key, 'tokens', 'last_refill')
              local tokens = tonumber(bucket[1]) or capacity
              local last = tonumber(bucket[2]) or now

              local elapsed = math.max(0, now - last)
              tokens = math.min(capacity, tokens + elapsed * refill_rate)

              if tokens >= requested then
                tokens = tokens - requested
                redis.call('hmset', key, 'tokens', tokens, 'last_refill', now)
                redis.call('expire', key, math.ceil(capacity / refill_rate) * 2)
                return 1
              end
              return 0
            LUA

            def initialize(redis, capacity: 100, refill_rate: 10)
              @redis = redis
              @capacity = capacity
              @refill_rate = refill_rate
              @sha = redis.script(:load, LUA_SCRIPT)
            end

            def allow?(tenant_id, tokens: 1)
              @redis.evalsha(@sha, keys: ["rl:\#{tenant_id}"],
                argv: [@capacity, @refill_rate, Time.now.to_f, tokens]) == 1
            end
          end
        CODE
      end

      option "Sliding Window Counter",
             aside: "More accurate than fixed windows. Prevents burst-at-boundary attacks but uses more Redis memory." do
        mermaid <<~MERMAID, compact: true
          graph LR
            subgraph Window ["Sliding Window (60s)"]
              W1[T-60s<br/>Count: 45] -.->|weight: 0.3| Calc((Weighted<br/>Sum))
              W2[T-0s<br/>Count: 30] -.->|weight: 0.7| Calc
            end
            Calc -->|"Est: 34.5"| Decision{Under<br/>Limit?}
            Decision -->|Yes| Allow[Allow]
            Decision -->|No| Reject[429 Too Many]
            style Allow fill:#22c55e,stroke:#15803d,color:#fff
            style Reject fill:#ef4444,stroke:#dc2626,color:#fff
        MERMAID
      end

      option "Adaptive Circuit Breaker",
             aside: "Dynamically adjusts limits based on downstream health. Self-healing but harder to set tenant expectations." do
        mermaid <<~MERMAID, compact: true
          stateDiagram-v2
            [*] --> Closed
            Closed --> Open : Failure rate > 50%
            Open --> HalfOpen : After cooldown (30s)
            HalfOpen --> Closed : Probe succeeds
            HalfOpen --> Open : Probe fails
            note right of Closed : All requests pass through
            note right of Open : All requests rejected (503)
            note right of HalfOpen : Single probe request allowed
        MERMAID
      end
    end

    # =========================================================
    # Slide 4: Observability Stack
    # =========================================================
    slide "observability", "Observability Stack",
          context: "We need distributed tracing, metrics, and structured logging across all gateway instances. Must integrate with existing Grafana dashboards." do

      option "OpenTelemetry Collector Pipeline",
             aside: "Vendor-neutral, CNCF-backed standard. One SDK for traces, metrics, and logs. Growing ecosystem.",
             recommended: true do
        mermaid <<~MERMAID, compact: true
          graph LR
            GW[Gateway<br/>OTel SDK] -->|OTLP/gRPC| Collector[OTel Collector]
            SvcA[Service A<br/>OTel SDK] -->|OTLP/gRPC| Collector
            SvcB[Service B<br/>OTel SDK] -->|OTLP/gRPC| Collector
            Collector -->|Traces| Tempo[(Tempo)]
            Collector -->|Metrics| Prom[(Prometheus)]
            Collector -->|Logs| Loki[(Loki)]
            Tempo --> Grafana[Grafana]
            Prom --> Grafana
            Loki --> Grafana
            style Collector fill:#6366f1,stroke:#4338ca,color:#fff
            style Grafana fill:#f97316,stroke:#c2410c,color:#fff
        MERMAID
      end

      option "Datadog APM",
             aside: "Full-featured SaaS. Fastest time to value. $23/host/month for APM, plus log ingestion costs." do
        code_block <<~CODE, lang: "ruby", file: "config/initializers/datadog.rb"
          require 'datadog/tracing'
          require 'datadog/appsec'

          Datadog.configure do |c|
            c.service = 'api-gateway'
            c.env = ENV.fetch('RACK_ENV', 'development')
            c.version = ENV.fetch('APP_VERSION', '0.0.0')

            c.tracing.instrument :rack
            c.tracing.instrument :http
            c.tracing.instrument :redis
            c.tracing.instrument :pg

            c.tracing.sampling.default_rate = 0.1
            c.tracing.sampling.rate_limit = 100

            c.appsec.enabled = true
            c.appsec.ip_passlist = ENV.fetch('TRUSTED_PROXIES', '').split(',')

            c.runtime_metrics.enabled = true
            c.runtime_metrics.statsd.host = ENV.fetch('DD_AGENT_HOST', 'localhost')
          end
        CODE
      end

      option "ELK Stack (Self-Hosted)",
             aside: "Full control over data retention and cost. Requires dedicated SRE capacity for Elasticsearch cluster management." do
        mermaid <<~MERMAID, compact: true
          graph TD
            GW[Gateway] -->|Filebeat| Logstash[Logstash]
            SvcA[Service A] -->|Filebeat| Logstash
            SvcB[Service B] -->|Filebeat| Logstash
            Logstash -->|Index| ES[(Elasticsearch<br/>Cluster)]
            ES --> Kibana[Kibana]
            GW -->|StatsD| Telegraf[Telegraf]
            Telegraf --> InfluxDB[(InfluxDB)]
            InfluxDB --> GrafanaInf[Grafana]
            style ES fill:#f59e0b,stroke:#b45309,color:#000
            style Logstash fill:#22c55e,stroke:#15803d,color:#fff
        MERMAID
      end
    end

  end
end

App.run! if __FILE__ == $0
