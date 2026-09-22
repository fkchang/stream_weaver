# Consulting Deck Spike: Northstar Research Kickoff
# ------------------------------------------------------
# Shared DSL fragment: bare component calls, consumed both by the
# standalone app wrapper (consulting_deck_spike.rb) and by
# `streamweaver export` / canvas-push. Spike for the presentation genre:
# four slide types reproduced from the reference 16:9 consulting deck --
# a title slide with a three-phase strip, a green section divider, a 2x3
# success-criteria card grid, and a five-node dated milestone timeline.
# Every slide renders inside a 16:9 stage with a recurring footer and
# slide-number chrome; Back/Next buttons and arrow keys navigate the deck.

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
  # Slide 2: Section divider (reference page 3)
  # =========================================================
  slide "section-01", "Project Overview & Success Criteria",
        type: :section,
        number: "01",
        subtitle: "Why the search experience is moving from POC to production, and what success looks like"

  # =========================================================
  # Slide 3: Success-criteria card grid (reference page 5)
  # =========================================================
  slide "success-criteria", "The project is done when...",
        type: :cards,
        kicker: "SUCCESS CRITERIA" do
    grid columns: 3, gap: :md do
      card do
        header4 "Real-time comment sync"
        text "A comment created, edited, or deleted in the source database is reflected end-to-end in the knowledge base without manual intervention or duplication."
      end
      card do
        header4 "All four query categories live"
        text "Static, Dynamic, Advisor-Specific and Longitudinal/Historical are implemented and meet per-category thresholds agreed in Phase 1, on a domain-expert-reviewed dataset."
      end
      card do
        header4 "Tier enforcement holds"
        text "A subscriber never receives content from a tier above their entitlement; cross-selling messages trigger correctly when paywalled content is relevant."
      end
      card do
        header4 "Internal, locked-down service"
        text "The search service is deployed on the existing Kubernetes platform with workload identity, not exposed to the internet, performing no authentication or authorization of its own."
      end
      card do
        header4 "Ticker resolution is reliable"
        text "A bare-ticker query reliably resolves to the right company and returns the current research stance across all four categories."
      end
      card do
        header4 "UAT clean & go-live stable"
        text "UAT completes without blocking issues across subscription tiers; go-live runs with active monitoring, no critical incidents in the first 24 hours, runbooks and KT delivered."
      end
    end
  end

  # =========================================================
  # Slide 4: Milestone timeline (reference page 19)
  # =========================================================
  slide "next-steps", "From today's kickoff to project-plan sign-off",
        type: :milestones,
        kicker: "NEXT STEPS",
        meta: "Cadence: 2-week sprints, weekly status meeting, shared decision log and RAID register from day one." do
    milestone "Sep 22", "Kickoff (today)",
              "Agree the re-planned calendar; confirm customer counterparts."
    milestone "Sep 25", "RACI & access requests",
              "Named owner and date for every dependency; MySQL, AWS, EKS and Jenkins access requested."
    milestone "Sep 30", "Volumetrics workshop",
              "Backfill throughput, Bedrock quota and cost model; domain expert named."
    milestone "Oct 7", "Phase-1 decisions closed",
              "Thresholds, NFRs, entitlement, taxonomy, Guardrails, 12 vs. 24-month backfill."
    milestone "Oct 9", "Project plan sign-off",
              "The customer signs off the plan; Phase 2 starts Oct 13."
  end
end
