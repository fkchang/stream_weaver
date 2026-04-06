# Lessons Learned — Visual Skills Development Process

## Meta: This Document
This captures the process of porting pi-design-deck and visual-explainer into
StreamWeaver, with the goal of extracting a repeatable skill for
"analyze N reference projects → design unified solution → implement via subagents."

---

## Phase 1: Setup & Analysis

### Lesson 1: Clone reference repos locally
**What:** Git clone both projects into the parent workspace so subagents can
read all source files without web fetch rate limits or API constraints.
**Why:** WebFetch hit 429 rate limits on the first attempt. Local files are instant
and unlimited. Subagents need to read *every* file, not just READMEs.
**Skill extraction:** Any "port from reference" workflow should start with local clones.

### Lesson 2: Parallel deep-analysis with shared template
**What:** Launch one subagent per reference project with identical analysis
structure (Intent → Features → Architecture → UX → Gherkin → Token Cost).
**Why:** Consistent output format enables mechanical overlap detection in the next
phase. If agent A uses one taxonomy and agent B uses another, the diff is noise.
**Skill extraction:** The analysis template IS the skill's core IP. Standardize it.

### Lesson 3: Gherkin as the bridge format
**What:** Have analysis agents write cucumber/Gherkin scenarios capturing all
user-facing behavior.
**Why:** Gherkin is:
  - Precise enough for implementation
  - Readable enough for design review
  - Diff-friendly for overlap analysis
  - Model-friendly (LLMs handle it well)
  - Testable (can become actual integration tests)
**Skill extraction:** Always produce Gherkin as intermediate artifact.

### Lesson 4: Research the orchestration pattern BEFORE designing implementation
**What:** Researched GSD's ralph-loop / subagent orchestration pattern up front.
**Why:** The implementation approach (how to break work into subagent-sized chunks)
constrains the design (how modular the architecture needs to be). Knowing we'll
use context-sharded subagents means the design MUST be decomposable into
independently-implementable units.
**Key GSD insights:**
  - **Context sharding**: Each task gets fresh 200k context, reads specs from files
  - **Atomic tasks**: 2-3 tasks per plan, each fitting ~50% of context window
  - **File-tracked state**: PLAN.md, STATE.md, REQUIREMENTS.md are the handoff
  - **Immediate commits**: Each task commits independently → git bisect works
  - **Orchestrator stays lean**: Main thread only tracks task completion, not implementation

### Lesson 5: Track evolution, not just final state
**What:** Maintain PROGRESS.md with running log, design evolution history,
and decision rationale at every step.
**Why:** Future LLMs advancing this work need to understand *why* decisions were made,
not just what was decided. A design doc without history is a puzzle without context.
**Skill extraction:** Every phase produces a dated log entry.

### Lesson 6: Multi-model vetting before implementation
**What:** User wants to vet progression/plans with other models before implementing.
**Why:** Different models catch different things. Codex for second opinions, DHH
reviewer for Ruby idiom quality, possibly Gemini for a third perspective.
**Skill extraction:** Build review gates into the process.

---

## Phase 2: Overlap Analysis

### Lesson 7: User's intuition was validated by data
**What:** User predicted ~1/3 code overlap. Analysis yielded 37%.
**Why this matters:** Domain experts have good intuitions. The analysis doesn't replace intuition — it validates and refines it. If the number had been 15% or 60%, the architecture would change significantly.
**Skill extraction:** Always ask the user for their hypothesis before running analysis. It calibrates expectations and highlights surprises.

### Lesson 8: Asymmetric token savings reveal architectural insight
**What:** Design deck saves 30-45% (already uses structured JSON). Visual explainer saves 80-85% (reads 30K tokens of reference material per invocation).
**Why this matters:** The savings aren't uniform. The biggest win comes from moving the design system FROM the prompt INTO the framework. This is an architectural argument, not just an optimization.
**Skill extraction:** Token cost analysis should be a required section in every analysis. It reveals where the real value is.

### Lesson 9: Blog material emerges from process, don't reconstruct later
**What:** User identified 4 blog posts from the process mid-stream.
**Why this matters:** The process IS content. Waiting until the end means losing the "in the moment" insights.
**Skill extraction:** Add "blog-worthy observations" as a running section in the progress doc.

## Phase 3: Design

### Lesson 10: Parallel reviews catch different things
**What:** DHH reviewer focused on Ruby idiom/simplicity. Codex focused on edge cases/scalability. Gemini found a race condition and proposed a better architecture for generate-more (push-to-state).
**Why:** Each model has different strengths. DHH caught over-engineering. Codex caught missing failure modes. Gemini caught a race condition and offered a structural improvement. No single review found everything.
**Skill extraction:** Always run at least 2 reviews from different angles. Consider: idiom/simplicity, edge cases/scaling, adversarial/what-if.

### Lesson 11: "Adversarial perspective" prompt yields best insights
**What:** Telling Gemini "I've had two favorable reviews, I need the adversarial perspective" produced the session's best architectural insight (push-to-state).
**Why:** Favorable reviews confirm the design but don't improve it. Adversarial reviews find the improvements. Explicitly requesting adversarial framing overcomes the model's tendency to be agreeable.
**Skill extraction:** Third review should always request adversarial/contrarian angle.

### Lesson 12: Save a SESSION-CONTEXT.md before compaction
**What:** Before context window fills, write a comprehensive recovery document listing all artifacts, key decisions, current status, and next steps.
**Why:** Context compaction loses nuance. The recovery doc is the insurance policy. Future sessions read it first to rebuild working context.
**Skill extraction:** Add "pre-compaction checkpoint" to the process template.

## Phase 4: Implementation
_To be filled as we progress_

---

## Process Anti-Patterns Observed
_Running list of things that didn't work_

1. WebFetch for GitHub READMEs — rate limited quickly. Use `gh api` + base64 decode instead.
2. WebFetch for GitHub READMEs — rate limited quickly. Use `gh api` + base64 decode instead.
3. **Token cost asymmetry reveals the real value proposition.** pi-design-deck saves 30-45% (already somewhat efficient with JSON), but visual-explainer saves 80-85% because it reads ~30K tokens of reference material per invocation. The design system living in framework code (0 prompt tokens) vs in the prompt is the killer advantage. This should be the lead of the blog post.
4. **Subagent analysis cost is reasonable.** Each deep analysis used ~140-150K tokens and took 5-6 minutes. The output quality (exhaustive feature inventories, Gherkin scenarios, token cost estimates, porting recommendations) would have consumed far more main-thread context if done inline. Good tradeoff.
5. **Analysis template should request architecture recommendations.** Both agents provided excellent "what maps directly / needs rearchitecting / can be dropped" sections. This wasn't in the original template but emerged organically. Add it to the skill template.

---

## Skill Template (Draft)
When this process is complete, the repeatable skill should look like:

```
/port-from-reference <repo1> <repo2> [--target <our-project>]

Phase 1: Clone & Analyze (parallel subagents)
  → analysis/<project>.md with standardized sections + Gherkin

Phase 2: Overlap Analysis (single agent)
  → overlap.md with shared/unique feature matrix
  → unified-specs.feature

Phase 3: Design (main thread + review agents)
  → architecture.md
  → codex-review.md, dhh-review.md
  → evolution.md

Phase 4: Implementation Planning
  → GSD-style task breakdown
  → Each task: scope, input files, output files, acceptance criteria

Phase 5: Implementation (ralph-loop subagents)
  → One subagent per task, fresh context, reads specs from disk
  → Atomic commits per task

Phase 6: Verification & Documentation
  → Run Gherkin scenarios
  → Blog post / docs
  → Updated lessons-learned
```
