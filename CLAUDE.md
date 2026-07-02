# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->


## Build & Test

_Add your build and test commands here_

```bash
# Example:
# npm install
# npm test
```

## Architecture Overview

_Add a brief overview of your project architecture_

## Conventions & Patterns

### Git Hygiene Policy

This repo is destined for **open source release**. Every commit is a candidate for public history — git history cannot be sanitized after the fact without rewriting it.

**Staging rules:**

- NEVER use `git add -A`, `git add .`, or `git add -u`. Stage explicit paths only, and only files you created or intentionally changed for the task at hand.
- Every staged file must be StreamWeaver-related. Personal tooling state (`.registry/`, `.serena/`, `.beads/`), build artifacts (`dist/`, `*.gem`), and session/agent scratch content stay out (most are gitignored — if you see one in `git status`, add it to `.gitignore` rather than committing it).
- Do not commit content containing personal info: home directory paths (`/Users/...`), personal emails, employer references, real names of testers/colleagues, travel/location details. Use placeholders or relative paths.

**Enforcement:**

- `bin/check_git_hygiene` runs automatically at pre-commit (chained after the beads block in `.beads/hooks/pre-commit`). It BLOCKS on home paths, personal email, personal-system references, secret-shaped strings, and staged files over 500KB; it WARNS on employer/tester-name references (full pattern list lives in the script itself, which is exempt from its own scan).
- False positive? Bypass once with `SW_HYGIENE_SKIP=1 git commit ...` — never disable the hook itself.
- Note: `bd dolt push` in the beads section above is a no-op here — no Dolt remote is configured and Dolt is intentionally not used; beads syncs via `.beads/issues.jsonl` locally.

**Before the public flip (tracked in epic stream_weaver-b9g):**

- Full-history scan for the block patterns (e.g. `gitleaks` or `git log -S`), docs/ cleanup (stream_weaver-wh2), and repo hygiene sweep (stream_weaver-kj0).
- Decide the public committer identity — history currently uses a work email.
