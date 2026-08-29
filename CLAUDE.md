# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

## Work tracking authority

Tyrion is authoritative for all new StreamWeaver work. Run `tyrion prime` and
`tyrion status` at session start, and use the Tyrion skills for shaping, importing,
claiming, implementing, gating, checkpointing, and completing stories.

Beads remains readable only as a legacy backlog. Existing Beads IDs may be searched,
updated, and closed, but never use `bd create`, `bd ready`, `bd update --claim`, or
`bv` to create or select new work. Re-home still-relevant legacy work in Tyrion and
record the Beads ID in the Tyrion note/evidence trail.


## Build & Test

_Add your build and test commands here_

```bash
# Example:
# npm install
# npm test
```

## Architecture Overview

_Add a brief overview of your project architecture_

## Visual Output

Whenever about to show something visually — a UI mockup, diagram, dashboard, layout/design comparison, or long-form doc — use the `streamweaver-visual-companion` skill. Do NOT use the `Artifact` tool, and do NOT write a local HTML file and open/screenshot it via Chrome browser tools (claude-in-chrome, superpowers-chrome, playwright) for this purpose. StreamWeaver's canvas-push is 5-7x cheaper in tokens than the chrome route and avoids GEA session conflicts. The skill's own "Fall back to Artifact only when..." section covers the rare exceptions (StreamWeaver unavailable, or a claude.ai-hosted link that must persist/reach someone outside this repo).

## Conventions & Patterns

### Git Hygiene Policy

This repo is destined for **open source release**. Every commit is a candidate for public history — git history cannot be sanitized after the fact without rewriting it.

**Staging rules:**

- NEVER use `git add -A`, `git add .`, or `git add -u`. Stage explicit paths only, and only files you created or intentionally changed for the task at hand.
- Every staged file must be StreamWeaver-related. Personal tooling state (`.registry/`, `.serena/`, `.beads/`), build artifacts (`dist/`, `*.gem`), and session/agent scratch content stay out (most are gitignored — if you see one in `git status`, add it to `.gitignore` rather than committing it).
- Do not commit content containing personal info: home directory paths (`/Users/...`), personal emails, employer references, real names of testers/colleagues, travel/location details. Use placeholders or relative paths.

**Enforcement:**

- `bin/check_git_hygiene` runs automatically from `.githooks/pre-commit`. It BLOCKS on home paths, personal email, personal-system references, secret-shaped strings, and staged files over 500KB; it WARNS on employer/tester-name references (full pattern list lives in the script itself, which is exempt from its own scan).
- False positive? Bypass once with `SW_HYGIENE_SKIP=1 git commit ...` — never disable the hook itself.

**Before the public flip (tracked in epic stream_weaver-b9g):**

- Full-history scan for the block patterns (e.g. `gitleaks` or `git log -S`), docs/ cleanup (stream_weaver-wh2), and repo hygiene sweep (stream_weaver-kj0).
- Decide the public committer identity — history currently uses a work email.

<!-- BEGIN TYRION-MANAGED-BLOCK v1 sha256:bc9a54f4421ec81e87306bdadc00e7524d992aaa63e04ed655f8670b5cd1bc0f -->
## Tyrion

This repo is tracked by Tyrion, a resumability ledger for coding agents.

Rules:
- claim before code (tyrion claim-next)
- evidence via tyrion note/check, not ad hoc

Run `tyrion prime` for the live session briefing — active epic/story, next action, unmet criteria.
<!-- END TYRION-MANAGED-BLOCK -->
