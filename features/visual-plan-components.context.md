# Epic Context: Visual Plan Components

## Goal

Port Builder.io's planning-phase component vocabulary into StreamWeaver's live canvas system. The result is a set of new DSL methods and components that give Claude Code agents first-class planning artifacts — implementation maps, architecture decisions, annotated code, code diffs, wireframes with device chrome — all updatable in real time, unlike Builder's static publish model.

## Source Analysis

Full gap analysis: `docs/visual/builder-visual-plan-analysis.md`
Builder reference repo (cloned for design inspection): `~/work/reference/builderio-skills/`
Key reference docs:
- `~/work/reference/builderio-skills/skills/visual-plan/references/wireframe.md` — HTML wireframe quality spec, `--wf-*` token system
- `~/work/reference/builderio-skills/skills/visual-plan/references/document-quality.md` — component usage rules
- `~/work/reference/builderio-skills/skills/visual-plan/references/canvas.md` — artboard/surface model

## Component Architecture Pattern

All components follow the same pattern:
1. Ruby class in `lib/stream_weaver/components/<name>.rb` extending `Base`
2. `render(view, state)` delegates to `view.adapter.render_<name>(view, component, state)`
3. DSL method registered in `lib/stream_weaver/display_dsl.rb`
4. Adapter method added to `lib/stream_weaver/adapter/`
5. Tests in `test/components/` and integration test in `test/display_dsl_test.rb`

Existing example: `lib/stream_weaver/components/callout.rb` + `lib/stream_weaver/components/code_block.rb`

## CSS Token Strategy

Builder's `--wf-*` tokens (ink, muted, line, paper, card, accent, accent-soft, warn, ok, radius) will be scoped inside a `.sw-wireframe-surface` wrapper class so they don't conflict with StreamWeaver's main `--sw-*` theme tokens.

The sketch aesthetic (rough.js + Excalifont) is applied by the renderer to wireframe containers only. Load rough.js from CDN (same pattern as Prism.js in code_block.rb). In non-sketch mode, wireframes render clean — same HTML, different CSS.

## Cross-Cutting Concerns

- **CDN dependencies**: rough.js and Excalifont load via `component_assets.rb` pattern, injected once per page when the wireframe component is used
- **Prism.js already loaded**: annotated_code and diff can reuse Prism.js infrastructure from code_block
- **`diffy` gem**: diff block uses server-side `diffy` gem for generating unified diffs from before/after strings. Add to gemspec.
- **All new components**: add DSL method, component class, adapter render method, and tests together as a unit

## Deferred / Out of Scope

- Artboard/DesignBoard spatial canvas model (major architecture undertaking — P3)
- `json_explorer` (niche — P3)
- `QuestionForm` async review workflow (canvas-wait covers live sessions — P3)
- `data_model` (mermaid ER covers most cases — P3)
- `data-goto` prototype navigation in wireframes (defer to v2 of wireframe)

## Implementation Order

Stories are ordered by dependency and value:
1. callout tones (trivial, warmup, proves path)
2. implementation_map (P0, no deps)
3. decision block (P0, no deps)
4. wf-token CSS foundation (prerequisite for wireframe)
5. annotated_code (P1, reuses Prism.js)
6. diff block (P1, needs diffy gem — gating dep for visual-recap skill)
7. wireframe component (P1, needs wf-token CSS)
8. api_endpoint (P2)
9. sketch mode (P2, needs wireframe)
10. /visual-plan skill (P0 components needed first)
11. /visual-recap skill (needs diff block)
