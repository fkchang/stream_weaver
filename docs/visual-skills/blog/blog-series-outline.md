# Blog Series: StreamWeaver Visual Skills

## Post 1: Token Efficiency — "From 30K Tokens to 3K"
**Angle:** The design system belongs in the framework, not the conversation.
- visual-explainer reads ~30K tokens of CSS patterns EVERY invocation → 0 with StreamWeaver
- 80-85% reduction isn't incremental — it's architectural
- **The Ruby angle:** Ruby's DSL capabilities make this natural. `mermaid "graph TD\n..."` vs generating 200 lines of HTML+JS. The language's expressiveness IS the token efficiency.
- **The attitude of Ruby:** Convention over configuration, developer happiness, "make programmers happy" — these principles produce concise DSLs that are inherently token-efficient. Ruby was optimized for human readability; turns out that's also LLM readability.
- Compare: Python Streamlit (close but more verbose), JS/TS (pi-design-deck's approach — more boilerplate)

## Post 2: Claude Code as Collaborative Architect
**Angle:** What AI-assisted engineering actually looks like at scale.
- Parallel subagent analysis while main thread does non-overlapping work (GSD research, blog outlines, progress tracking, lessons learned)
- Quality of analysis: 45 Gherkin scenarios from reading TypeScript source, token cost estimates, architecture recommendations — all emerged without being explicitly prompted
- The "ultrathink" instruction: asking for thoroughness yields thoroughness
- Not "AI writes code" but "AI does the research, analysis, and grunt work so the human can make better decisions faster"
- The human's role: specifying the process, predicting outcomes (1/3 overlap → confirmed at 37%), setting quality bars, choosing what to vet

## Post 3: The Engineering Process That GenAI Rewards
**Angle:** Specification depth is the new 10x multiplier.
- Most people: "build me a design deck" → 1-shot, mediocre result, tech debt from day 1
- This approach: clone references → deep analysis → overlap matrix → unified specs → reviewed design → subagent implementation
- **The code reuse prediction:** Hypothesized ~1/3 overlap, confirmed at 37%. Most engineers can't predict this because they don't analyze before building. GenAI makes analysis cheap enough to always do it.
- **DRY at the architecture level:** Not just "don't copy-paste functions" but "don't build 50 components when 37% are shared infrastructure." The component inventory (9 shared, 10 deck, 19 explainer, 12 enhanced) exists because we analyzed first.
- **Why this matters for long-lived projects:** StreamWeaver isn't a weekend hack. Shared Mermaid rendering, theme system, code highlighting — these compound. Every future skill gets them for free. The upfront analysis cost (3 subagents, ~370K tokens) pays for itself on the second skill.
- **The uncomfortable truth:** Most people won't do this. Not because they can't, but because they don't value the analysis phase. GenAI amplifies whatever process you bring — if your process is "just build it," you get fast garbage. If your process is "understand, then build," you get fast quality.

## Post 4: The Repeatable Process (Skill Extraction)
**Angle:** If it worked once, encode it.
- The full process: clone → parallel analysis (shared template) → overlap matrix → unified Gherkin → OO design → multi-model review → GSD-style subagent implementation
- Why each step exists (lessons learned)
- The skill template for `/port-from-reference`
- Meta-lesson: the process of creating the process is itself the valuable artifact
- Connection to SDRD: this IS spike-driven discovery — we're building to learn what the architecture should be

## Cross-Cutting Themes
- **Forrest's Law in action:** Zero friction (DSL is trivial to use) + substantial perks (80% token savings, visual quality, shared infrastructure)
- **SDRD validated:** We didn't over-plan. We analyzed reference implementations, discovered the real requirements, and are designing from evidence — not imagination.
- **GEA-compatible:** The parallel subagent pattern works because it's file-tracked. 20 sessions could contribute to this without stepping on each other.
