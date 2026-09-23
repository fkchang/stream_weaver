# Consulting Deck Full: Northstar Research Kickoff (20 slides)
# -------------------------------------------------------------
# Shared DSL fragment: bare component calls, consumed both by the
# standalone app wrapper (consulting_deck_full.rb) and by
# `streamweaver export` / canvas-push. Batch A established the baseline for
# the presentation genre: a complete 20-slide consulting kickoff deck
# composed ONLY from low-level StreamWeaver primitives (presentation,
# slide, grid, columns, column, card, div, header*, text, md, phase,
# milestone) plus local composition helpers. Batch B extracted the helpers
# that repeated >= 3 times into the reusable, deck-genre-generic module in
# consulting_deck_components.rb — no framework components or DSL helpers
# were added for this deck.
#
# All content is fictionalized: Northstar Research (customer) and
# CloudWorks (vendor) are invented names, and the wording is rewritten
# as a sanitized representative example, not a copied deliverable.
#
# Extracted helpers (occurrences in this file):
#   agenda_item(number, heading, description)      -- 5  (slide 2)
#   glance_row(label, value)                       -- 6  (slide 4)
#   criterion_card(heading, body)                  -- 6  (slide 5)
#   labeled_card(tag, body, heading:)              -- 8  (slides 16, 17)
#   labeled_card(tag, body, label_style: :inline)  -- 3  (slide 12)
#   phase_detail(label, title, meta, bullets_md)   -- 3  (slide 13)
#
# Density note (Batch A browser-gate pass): the 16:9 stage is 638px tall at
# the 1135px reference width, and webviews that inflate text need extra
# headroom. Dense slides therefore use compact typography (0.7-0.8rem body,
# line-height ~1.3, 0.5-0.6rem card padding, tight gaps) and terse copy.

# Load the extracted composition helpers. `require_relative` resolves
# whenever this fragment is evaluated with its path (standalone wrapper,
# spec, `streamweaver export`); under canvas-push the module text is
# concatenated ahead of this body instead (no filename, so require_relative
# cannot resolve), and the defined?/respond_to? guards keep both paths
# idempotent.
unless respond_to?(:labeled_card)
  require_relative 'consulting_deck_components' unless defined?(ConsultingDeckComponents)
  extend ConsultingDeckComponents
end

presentation footer: "CloudWorks · Project Kickoff · Northstar Research · September 2026" do

  # =========================================================
  # Slide 1: Title (reference page 1)
  # =========================================================
  slide "title", "Northstar Research",
        type: :title,
        kicker: "PROJECT KICKOFF · NORTHSTAR RESEARCH × CLOUDWORKS",
        subtitle: "Intelligent Search Engine — Production MVP",
        meta: "Kickoff Sep 22, 2026 · Project start Sep 23, 2026 · Go-live Jan 19, 2027 · Project close Jan 27, 2027" do
    phase "PHASE 1", "Discovery & Planning", "2.5 weeks · Sep 23 – Oct 9"
    phase "PHASE 2", "Implementation", "10 weeks · Oct 13 – Dec 18"
    phase "PHASE 3", "Validation & Go-Live", "3.5 weeks · Jan 4 – Jan 27"
  end

  # =========================================================
  # Slide 2: Agenda (reference page 2)
  # =========================================================
  slide "agenda", "What we'll cover today",
        kicker: "AGENDA" do
    agenda_item "01", "Project overview & success criteria",
                "Why the search experience moves from pilot to production, and how we will know we are done"
    agenda_item "02", "Implementation proposal",
                "Two workstreams, the query-service contract, target architecture and scope guardrails"
    agenda_item "03", "High-level timeline",
                "Re-planned calendar: backfill decoupled into Phase 2, go-live Jan 19, 2027, close Jan 27, 2027"
    agenda_item "04", "Key open items & decisions",
                "What we need to agree today, and what must close before Phase 1 exit on Oct 9"
    agenda_item "05", "Next steps",
                "The path from today's kickoff to project-plan sign-off"
  end

  # =========================================================
  # Slide 3: Section divider 01 (reference page 3)
  # =========================================================
  slide "section-01", "Project Overview & Success Criteria",
        type: :section,
        number: "01",
        subtitle: "Why the search experience is moving from pilot to production, and what success looks like"

  # =========================================================
  # Slide 4: Business context + at-a-glance sidebar (page 4)
  # =========================================================
  slide "business-context", "Why this project, why now",
        kicker: "BUSINESS CONTEXT" do
    columns widths: ["1fr", "265px"] do
      column do
        md <<~MD, style: "font-size: 0.75rem; line-height: 1.28;"
          - **Where we start.** A working intelligent-search pilot (accepted Nov 2025): ~130 documents, 6 content categories, two of the four query categories.
          - **Where we are going.** Production-grade search on the customer's existing cloud and Kubernetes estate — all 64 active content categories, 16 years of archives.
          - **Subscriber & analyst demand.** Natural-language answers that surface the right comment, framework or attachment instantly, with tier-based access enforced.
          - **Ticker-centric queries are the quality bar.** Reliable company/ticker identification and weighting across all four query categories.
        MD
      end
      column do
        card style: "padding: 0.55rem 0.8rem; background: var(--sw-surface-elevated, #f4f7f6);" do
          text "AT A GLANCE", style: "font-size: 0.66rem; font-weight: 800; letter-spacing: 0.1em; margin: 0 0 0.35rem 0;"
          glance_row "Customer", "Northstar Research, LLC"
          glance_row "Project", "Intelligent Search Engine — MVP"
          glance_row "Agreement signed", "August 28, 2026"
          glance_row "Key dates", "Kickoff Sep 22, 2026 · Go-live Jan 19, 2027 · Close Jan 27, 2027"
          glance_row "Prior engagement", "Search pilot (Nov 2025)"
          glance_row "Consumer of output", "Subscriber site & analyst tools"
        end
      end
    end
  end

  # =========================================================
  # Slide 5: Success-criteria card grid (reference page 5)
  # =========================================================
  slide "success-criteria", "The project is done when...",
        type: :cards,
        kicker: "SUCCESS CRITERIA" do
    grid columns: 3, gap: "0.6rem" do
      criterion_card "Real-time comment sync",
                     "Comment create/edit/delete in the source database is reflected end-to-end in the knowledge base — no manual steps."
      criterion_card "All four query categories live",
                     "Static, Dynamic, Advisor-Specific and Longitudinal/Historical meet Phase-1 thresholds on an expert-reviewed dataset."
      criterion_card "Tier enforcement holds",
                     "A subscriber never receives content above their entitlement; cross-selling triggers correctly on paywalled hits."
      criterion_card "Internal, locked-down service",
                     "Deployed on the existing Kubernetes platform with workload identity; no internet exposure, no auth of its own."
      criterion_card "Ticker resolution is reliable",
                     "A bare-ticker query resolves to the right company and returns the current research stance across all four categories."
      criterion_card "UAT clean & go-live stable",
                     "UAT completes without blockers across tiers; monitored go-live, no critical incidents in 24 hours, runbooks and KT delivered."
    end
  end

  # =========================================================
  # Slide 6: Section divider 02 (reference page 6)
  # =========================================================
  slide "section-02", "Implementation Proposal",
        type: :section,
        number: "02",
        subtitle: "Two workstreams — production ingestion & retrieval, and migrating the search service into the customer's Kubernetes clusters as an internal, zero-trust service"

  # =========================================================
  # Slide 7: Two workstreams (reference page 7)
  # =========================================================
  slide "workstreams", "Everything in scope rolls up into one of these",
        kicker: "TWO WORKSTREAMS" do
    columns widths: ["1fr", "1fr"] do
      column do
        card style: "padding: 0.5rem 0.85rem;" do
          header4 "1 · Data Ingestion & Knowledge Base", style: "margin: 0 0 0.15rem 0; font-size: 0.95rem;"
          text "Get every source — comments, transcripts, static docs — reliably into a production-grade knowledge base",
               tone: :muted, style: "font-size: 0.76rem; margin-top: 0; line-height: 1.3;"
          md <<~MD, style: "font-size: 0.7rem; line-height: 1.26;"
            - Relational-database integration for comments (publish-time signal over polling), queue + dead-letter orchestration, idempotent workers
            - Show transcripts (object storage) and the static corpus ingested alongside comments
            - Per-document image/table extraction via foundation models, merged into unified per-comment documents
            - Four query categories over a managed knowledge base + vector index — ticker, content-type and tier filtering, cross-sell hooks
            - Reusable historical backfill pipeline (12-month default, up to 24), run through Phase 2 in low-traffic windows
          MD
        end
      end
      column do
        card style: "padding: 0.5rem 0.85rem;" do
          header4 "2 · Application, Security & Operations", style: "margin: 0 0 0.15rem 0; font-size: 0.95rem;"
          text "Migrate the search service into the customer's own infrastructure, hardened and observable",
               tone: :muted, style: "font-size: 0.76rem; margin-top: 0; line-height: 1.3;"
          md <<~MD, style: "font-size: 0.7rem; line-height: 1.26;"
            - Migrate the Python search service from the pilot's container deployment to the customer's Kubernetes clusters, internal-only
            - Workload-identity IAM and network policies — the service performs no authentication/authorization itself
            - Streaming responses via the model provider's streaming API; pilot web frontend reused, integrated via embed or redirect
            - Content guardrails (PII/prohibited-topic filtering) plus defense-in-depth sanitization against prompt injection
            - Two-tier audit log (database 90-day + object archive), dashboards, infrastructure-as-code, CI/CD with a manual prod gate
          MD
        end
      end
    end
  end

  # =========================================================
  # Slide 8: Interface contract (reference page 8)
  # =========================================================
  slide "interface-contract", "Delivered as an internal service — the customer frontend is the only caller, by design",
        kicker: "QUERY SERVICE — INTERFACE CONTRACT" do
    columns widths: ["1fr", "1fr"] do
      column do
        card style: "padding: 0.7rem 1rem;" do
          text "INPUT", style: "font-size: 0.72rem; font-weight: 800; letter-spacing: 0.1em; color: var(--sw-accent, #0f9d58); margin: 0 0 0.25rem 0;"
          header4 "A natural-language question + subscription tier"
          text "The customer frontend passes the query plus the caller's entitlement as a plain-text parameter — the service performs no auth of its own.",
               style: "margin: 0; font-size: 0.85rem;"
        end
      end
      column do
        card style: "padding: 0.7rem 1rem;" do
          text "OUTPUT", style: "font-size: 0.72rem; font-weight: 800; letter-spacing: 0.1em; color: var(--sw-accent, #0f9d58); margin: 0 0 0.25rem 0;"
          header4 "A streamed, cited answer filtered to the caller's tier"
          text "Grounded in comments, transcripts and static docs, with correct markdown rendering for images, tables and citations.",
               style: "margin: 0; font-size: 0.85rem;"
        end
      end
    end
    header4 "Why it's built this way", style: "margin: 0.9rem 0 0.3rem 0; text-transform: uppercase; letter-spacing: 0.06em; font-size: 0.85rem;"
    md <<~MD, style: "font-size: 0.8rem; line-height: 1.4;"
      - Four distinct retrieval profiles — Static/Framework, Dynamic/Current Positioning, Advisor-Specific hybrid retrieval, Longitudinal/Historical agentic multi-call — rather than one generic retrieval pass
      - Ticker/company identification is a first-class quality bar, not a secondary filter — most subscriber questions are ticker-centric
      - Research vs. signal/alert content is tagged and weighted separately, so a ticker question returns the research stance, not incidental signal mentions
      - The Category 3/4 tool-calling architecture is designed so future sources (dashboards, pricing, other datasets) are additive, not rewrites
    MD
  end

  # =========================================================
  # Slide 9: Architecture at a glance (reference page 9)
  # =========================================================
  slide "architecture", "An internal service inside the customer's own Kubernetes clusters — no new cloud account, no internet exposure",
        kicker: "ARCHITECTURE AT A GLANCE" do
    columns widths: ["1fr", "48px", "1.2fr"], style: "align-items: center; margin-top: 0.3rem;" do
      column do
        text "CUSTOMER'S EXISTING PLATFORM", style: "font-size: 0.64rem; font-weight: 800; letter-spacing: 0.08em; color: var(--sw-text-dim, #666); margin-bottom: 0.3rem;"
        card style: "padding: 0.5rem 0.85rem; margin-bottom: 0.5rem;" do
          header4 "Relational database — comments", style: "margin: 0 0 0.1rem 0; font-size: 0.9rem;"
          text "Publish-time signal (scoped read access or export mechanism)",
               tone: :muted, style: "margin: 0; font-size: 0.74rem; line-height: 1.3;"
        end
        card style: "padding: 0.5rem 0.85rem;" do
          header4 "Object storage — transcripts & static corpus", style: "margin: 0 0 0.1rem 0; font-size: 0.9rem;"
          text "Customer-produced; CloudWorks ingests via storage events",
               tone: :muted, style: "margin: 0; font-size: 0.74rem; line-height: 1.3;"
        end
      end
      column do
        text "→", style: "font-size: 1.5rem; font-weight: 800; color: var(--sw-accent, #0f9d58); text-align: center; margin: 0;"
      end
      column do
        text "CLOUDWORKS-DELIVERED, INTERNAL KUBERNETES SERVICE", style: "font-size: 0.64rem; font-weight: 800; letter-spacing: 0.08em; color: var(--sw-text-dim, #666); margin-bottom: 0.3rem;"
        card style: "padding: 0.4rem 0.85rem; margin-bottom: 0.4rem; border-left: 4px solid var(--sw-accent, #0f9d58);" do
          text "Queue → workers → document automation — ingestion pipeline",
               style: "margin: 0; font-size: 0.78rem; line-height: 1.3;"
        end
        card style: "padding: 0.4rem 0.85rem; margin-bottom: 0.4rem; border-left: 4px solid var(--sw-accent, #0f9d58);" do
          text "Managed knowledge base + vector index — hybrid retrieval",
               style: "margin: 0; font-size: 0.78rem; line-height: 1.3;"
        end
        card style: "padding: 0.4rem 0.85rem; border-left: 4px solid var(--sw-accent, #0f9d58);" do
          text "Python search service on Kubernetes (workload identity) → streaming model API — observability + audit",
               style: "margin: 0; font-size: 0.78rem; line-height: 1.3;"
        end
      end
    end
  end

  # =========================================================
  # Slide 10: Out of scope (reference page 10)
  # =========================================================
  slide "out-of-scope", "Scope guardrails — what this MVP does not include",
        kicker: "OUT OF SCOPE" do
    columns widths: ["1fr", "1fr"] do
      column do
        md <<~MD, style: "font-size: 0.85rem; line-height: 1.45;"
          - The separate chatbot pilot's production work — this engagement covers the intelligent search engine only
          - Re-architecture or modification of the customer's existing legacy application services
          - Edge protection and public-edge enforcement (WAF, rate limiting, TLS termination) — the customer's responsibility
          - Custom LLM or embedding-model training, fine-tuning, or model-weight modification
          - Migration of the existing vector store (a unification spike is included; migration itself is deferred)
        MD
      end
      column do
        md <<~MD, style: "font-size: 0.85rem; line-height: 1.45;"
          - Data labeling and annotation beyond what's required to curate the evaluation dataset
          - Historical backfill beyond the agreed Phase-1 scope (default last 12–24 months)
          - Ongoing operational support beyond the post-go-live monitoring window and knowledge-transfer period
          - Producing, transcribing, or loading show transcripts into object storage — assumed to already exist there
          - Additional data sources beyond comments, static corpus and show transcripts — enabled by the delivered documentation but deferred to future engagements
        MD
      end
    end
  end

  # =========================================================
  # Slide 11: Section divider 03 (reference page 11)
  # =========================================================
  slide "section-03", "High-Level Timeline",
        type: :section,
        number: "03",
        subtitle: "A re-planned calendar that protects go-live: backfill decoupled into Phase 2, go-live Jan 19, 2027, project close Jan 27, 2027"

  # =========================================================
  # Slide 12: Schedule re-plan (reference page 12)
  # =========================================================
  slide "schedule-replan", "Why go-live moves to January",
        kicker: "SCHEDULE RE-PLAN",
        meta: "Decision requested today: agree the re-planned calendar." do
    columns widths: ["1fr", "1fr"] do
      column do
        header4 "What the feasibility review found", style: "text-transform: uppercase; letter-spacing: 0.05em; font-size: 0.72rem; margin: 0 0 0.15rem 0;"
        text "The project is technically feasible; the binding constraint is the calendar: load testing, a backfill ~85–170× the pilot volume, UAT, cutover and handover in ten days (Dec 11–20) with zero float — go-live five days before the winter holidays.",
             style: "font-size: 0.75rem; line-height: 1.28; margin-top: 0;"
        header4 "What changes", style: "text-transform: uppercase; letter-spacing: 0.05em; font-size: 0.72rem; margin: 0.35rem 0 0.1rem 0;"
        md <<~MD, style: "font-size: 0.75rem; line-height: 1.26;"
          - Backfill runs through Phase 2 in low-traffic windows, decoupled from go-live
          - Go-live moves to Jan 19, 2027; project close Jan 27, 2027
        MD
        header4 "What does not change", style: "text-transform: uppercase; letter-spacing: 0.05em; font-size: 0.72rem; margin: 0.35rem 0 0.1rem 0;"
        md <<~MD, style: "font-size: 0.75rem; line-height: 1.26;"
          - Scope, deliverables, success criteria and team
          - Phase 1 and Phase 2 keep their agreed durations (2.5 + 10 weeks)
        MD
      end
      column do
        text "ORIGINAL PLAN VS. RE-PLAN", style: "font-size: 0.64rem; font-weight: 800; letter-spacing: 0.08em; color: var(--sw-text-dim, #666); margin-bottom: 0.3rem;"
        labeled_card "Original plan · go-live Dec 20, 2026",
                     "1.5-week Phase 3 with zero float; backfill inside the cutover window; any defect lands in the holidays.",
                     label_style: :inline
        labeled_card "Holiday window · Dec 21 – Jan 1",
                     "Production change freeze. Backfill completes in low-traffic windows; non-prod capacity absorbs Phase-2 slip.",
                     label_style: :inline
        labeled_card "Re-plan · go-live Jan 19, 2027",
                     "Phase 3 becomes 3.5 weeks (Jan 4–27): load test, UAT, go-live after the mid-January holiday, hypercare, handover.",
                     label_style: :inline
      end
    end
  end

  # =========================================================
  # Slide 13: Three-phase detailed timeline (reference page 13)
  # =========================================================
  slide "phase-timeline", "Sep 23, 2026 – Jan 27, 2027 · Go-live Jan 19, 2027",
        kicker: "PHASE TIMELINE" do
    grid columns: 3, gap: "0.6rem" do
      phase_detail "PHASE 1", "Discovery & Planning", "2.5 weeks · Sep 23 – Oct 9, 2026", <<~MD
        - Pilot technical audit & tech-debt list; security refactor, IaC per environment, prod provisioning, CI/CD
        - Alignment + Phase-1 exit items: volumetrics & backfill scope, thresholds, NFRs, entitlement, taxonomy, guardrails
        - Customer sign-off on the project plan — Oct 9
      MD
      phase_detail "PHASE 2", "Implementation", "10 weeks · Oct 13 – Dec 18, 2026", <<~MD
        - Ingestion pipelines, static documents, knowledge base & retrieval (all four query categories), evaluation system
        - Kubernetes service migration, frontend & UI polish; security, observability & operations
        - Historical backfill decoupled: pilot from Nov 16, full run from Nov 23 in low-traffic windows
      MD
      phase_detail "PHASE 3", "Validation & Go-Live", "3.5 weeks · Jan 4 – Jan 27, 2027", <<~MD
        - Jan 4–8: load/performance testing against agreed NFRs, capacity tuning, backfill validation
        - Jan 11–15: UAT across tiers and internal analysts · Jan 19: production go-live
        - Jan 19–26: hypercare & knowledge transfer · Jan 27: closing deliverables, project close
      MD
    end
    text "Dec 21 – Jan 1: holiday window — production change freeze, backfill completion and buffer for Phase 2. Vendor holidays and US public holidays are factored in.",
         tone: :muted, style: "font-size: 0.64rem; margin-top: 0.2rem;"
  end

  # =========================================================
  # Slide 14: Key milestones (reference page 14)
  # =========================================================
  slide "key-milestones", "From kickoff to project close",
        type: :milestones,
        kicker: "KEY MILESTONES",
        meta: "All dates assume customer dependencies land on their needed-by dates (see Client Dependencies)." do
    milestone "Oct 9", "Project plan sign-off",
              "Phase-1 exit items closed; the customer signs off the plan before Phase 2 begins."
    milestone "Nov 23", "Backfill starts",
              "Full historical backfill in low-traffic windows, decoupled from go-live (pilot from Nov 16)."
    milestone "Dec 18", "Implementation complete",
              "Phase 2 done; holiday change freeze Dec 21 – Jan 1."
    milestone "Jan 11 – 19", "UAT & go-live",
              "UAT across tiers Jan 11–15; production cutover Tue Jan 19 with intensive monitoring."
    milestone "Jan 27", "Project close",
              "Hypercare done, KT and closing docs delivered; float to Jan 29."
  end

  # =========================================================
  # Slide 15: Section divider 04 (reference page 15)
  # =========================================================
  slide "section-04", "Key Open Items & Decisions",
        type: :section,
        number: "04",
        subtitle: "What the feasibility review surfaced — one decision for today, and the items that must close before Phase 1 exit on Oct 9"

  # =========================================================
  # Slide 16: Key open items (reference page 16)
  # =========================================================
  slide "open-items", "One decision today, three Phase-1 exit items",
        type: :cards,
        kicker: "KEY OPEN ITEMS" do
    grid columns: 2, gap: "0.6rem" do
      labeled_card "Decision today",
                   "Decouple the historical backfill into Phase 2, use the holiday window as change freeze and buffer, and move go-live to Jan 19, 2027 (close Jan 27). Needs customer agreement before Phase 1 work begins.",
                   heading: "Re-planned go-live calendar"
      labeled_card "Phase-1 exit · Oct 9",
                   "Production is ~85–170× the pilot: ~11k comments for 12 months (~22k for 24), ~45–60k image extractions and ~3.5k PDFs per year. Workshop → throughput, quota and cost model; 12-month default until validated.",
                   heading: "Backfill volumetrics & scope"
      labeled_card "Phase-1 exit · Oct 9",
                   "Replace “at or above the pilot baseline” with per-category numeric thresholds, including a faithfulness floor, on a dataset reviewed by a named customer domain expert.",
                   heading: "Measurable acceptance criteria"
      labeled_card "Design proposed · needs sign-off",
                   "Index each comment once (dedup on comment ID) tagged with all its categories; decide legacy-ledger handling; add a negative-path tier-leakage test; written acceptance of the no-auth service and plain-text tier parameter.",
                   heading: "Entitlement & access model"
    end
    text "Each item is tracked in the RAID log with a named owner and due date.",
         tone: :muted, style: "font-size: 0.72rem; margin-top: 0.35rem;"
  end

  # =========================================================
  # Slide 17: Key open items, continued (reference page 17)
  # =========================================================
  slide "open-items-cont", "Phase-1 items that shape design and testing",
        type: :cards,
        kicker: "KEY OPEN ITEMS (CONT.)" do
    grid columns: 2, gap: "0.6rem" do
      labeled_card "Vendor-owned · timeboxed",
                   "Static-doc parser, vector-store and evaluation-framework spikes, timeboxed with a written default if inconclusive. The vector-store spike is shortened — the pilot showed multi-value metadata filtering is unsupported.",
                   heading: "Technical spikes"
      labeled_card "Phase-1 exit · Oct 9",
                   "Agree p50/p95 latency, concurrent users, availability and ingestion-lag SLO — the pass/fail criteria for Phase 3 load tests and the input for cluster and index sizing. No targets exist today.",
                   heading: "Non-functional requirements"
      labeled_card "Phase-1 exit · Oct 9",
                   "Provide the prohibited-topic list (e.g., performance/track-record questions, long-range risk-band levels) and a compliance owner; agree audit-log retention with the compliance team.",
                   heading: "Guardrails & compliance policy"
      labeled_card "Needs clarification",
                   "Confirm the advisor daily briefing exists (not in the 64-category inventory), the capital-allocation move to a dashboard format, and the image-table → HTML-table migrations; retrieval design adjusts.",
                   heading: "Advisor-specific (Category 3) sources"
    end
    text "Also to define in Phase 1: handling strategy for non-PDF attachments (.ics, .xlsx, .csv).",
         tone: :muted, style: "font-size: 0.72rem; margin-top: 0.35rem;"
  end

  # =========================================================
  # Slide 18: Client dependencies (reference page 18)
  # =========================================================
  slide "client-dependencies", "What we need from the customer — and by when",
        kicker: "CLIENT DEPENDENCIES" do
    columns widths: ["1fr", "1fr"] do
      column do
        md <<~MD, style: "font-size: 0.85rem; line-height: 1.45;"
          - Customer owner named for every item in the project RACI — **Sep 25**
          - Evaluation domain expert named, with review dates committed — **Sep 30**
          - Research vs. signal/alert content taxonomy — **Oct 9**
          - Subscription-tier model and tier → category mapping — **Oct 9**
          - Publish-time signal design agreed (payload vs. reference) — **Oct 9**
        MD
      end
      column do
        md <<~MD, style: "font-size: 0.85rem; line-height: 1.45;"
          - Database access (read replica or export) incl. networking — **Oct 9**
          - Comment→company mapping production-reliable (schema, reliability SLO) — **before ingestion starts, Oct 13**
          - Prohibited-topic list, compliance owner and audit-log retention — **Oct 9**
          - Kubernetes network-policy allowances for upstream services — **Nov 13**
          - UAT participants across tiers + internal analysts (Cat. 3 & 4) — named by **Dec 11**, sessions Jan 11–15
        MD
      end
    end
  end

  # =========================================================
  # Slide 19: Next steps (reference page 19)
  # =========================================================
  slide "next-steps", "From today's kickoff to project-plan sign-off",
        type: :milestones,
        kicker: "NEXT STEPS",
        meta: "Cadence: 2-week sprints, weekly status meeting, shared decision log and RAID register from day one." do
    milestone "Sep 22", "Kickoff (today)",
              "Agree the re-planned calendar; confirm customer counterparts."
    milestone "Sep 25", "RACI & access requests",
              "Named owner and date for every dependency; database, cloud, Kubernetes and CI access requested."
    milestone "Sep 30", "Volumetrics workshop",
              "Backfill throughput, model quota and cost model; domain expert named."
    milestone "Oct 7", "Phase-1 decisions closed",
              "Thresholds, NFRs, entitlement, taxonomy, guardrails, 12 vs. 24-month backfill."
    milestone "Oct 9", "Project plan sign-off",
              "The customer signs off the plan; Phase 2 starts Oct 13."
  end

  # =========================================================
  # Slide 20: Questions closer (reference page 20)
  # =========================================================
  slide "questions", "Questions?",
        type: :section,
        subtitle: "Thank you — the shared project channel and weekly status meeting are open from today."
end
