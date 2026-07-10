*Source: Perplexity Deep Research, 2026-07-09, commissioned to scope multi-tool skill-install support for StreamWeaver's `streamweaver setup`/`install-skill` commands.*

# Comparing Coding-Agent Skill Conventions: Codex, Gemini CLI, GitHub Copilot vs. Claude Code's SKILL.md

> **Correction (post-verification, 2026-07-09):** the table and prose below say Claude Code also scans a `.agents/skills/` alias. That's wrong — checked against Claude Code's own official docs (code.claude.com/docs, platform.claude.com/docs), which list only `.claude/skills/` (project), `~/.claude/skills/` (user), and plugin-bundled skills. No `.agents/skills/` support. The alias claim *did* check out independently for Codex CLI (learn.chatgpt.com/docs/build-skills), Gemini CLI (geminicli.com/docs/cli/skills/ — where `.agents/skills/` actually takes precedence over `.gemini/skills/`), and GitHub Copilot (docs.github.com — `.github/skills`, `.claude/skills`, or `.agents/skills` all accepted). Net effect: `.agents/skills/` reaches Codex + Gemini CLI + Copilot, not Claude Code — implemented that way in `streamweaver install-skill`/`setup`.

> **Baseline (given, not derived):** Claude Code uses `~/.claude/skills/<name>/SKILL.md` (global) or `<project>/.claude/skills/<name>/SKILL.md` (project-local). Each `SKILL.md` has YAML frontmatter with required `name` and `description` fields, an optional markdown body, and optional bundled files in the same directory. Activation is automatic: the agent matches the `description` field against the current task intent — no explicit slash command required.

***

## Master Comparison Table

| Tool | Concept name | File format | Metadata schema | Location convention | Discovery/trigger mechanism | Maturity | Key limitation vs. Claude Code SKILL.md |
|------|-------------|-------------|-----------------|--------------------|-----------------------------|----------|-----------------------------------------|
| **Claude Code** *(baseline)* | Agent Skill | Directory + `SKILL.md` (YAML frontmatter + Markdown body) | **Required:** `name`, `description`; **Optional:** `license`, `compatibility`, `metadata`, `allowed-tools` | `~/.claude/skills/<name>/` (global); `<project>/.claude/skills/<name>/` (project-local); `.agents/skills/` alias also scanned | Names+descriptions loaded at startup; agent auto-triggers based on description match; full `SKILL.md` loaded on activation | Stable (open standard since Dec 2025) | — (baseline) |
| **OpenAI Codex** | Agent Skill (+ legacy: AGENTS.md for project context) | Directory + `SKILL.md`; also `agents/openai.yaml` for UI metadata | Same as agentskills.io spec; optional `agents/openai.yaml` adds `interface`, `policy`, `dependencies` YAML blocks | `~/.agents/skills/` or `$HOME/.agents/skills/` (user); `$REPO_ROOT/.agents/skills/` (repo-root); `$CWD/.agents/skills/` (working dir); also `~/.codex/skills/` historically; `/etc/codex/skills/` (admin/system) | Same progressive-disclosure model; explicit `$skill-name` mention or `/skills` picker; implicit auto-match by description | Stable — skills GA, AGENTS.md separately donated to Linux Foundation AAIF Dec 2025 | `agents/openai.yaml` sidecar can disable implicit invocation (`allow_implicit_invocation: false`); more complex plugin-packaging layer on top of raw skills |
| **Google Gemini CLI** | Agent Skill (+ GEMINI.md for always-on context) | Directory + `SKILL.md`; GEMINI.md is a separate always-loaded plain Markdown file with no frontmatter | Same as agentskills.io spec for skills; GEMINI.md has zero frontmatter schema | Skills: `~/.gemini/skills/` or `~/.agents/skills/` (user); `.gemini/skills/` or `.agents/skills/` in repo (workspace); also available via extensions | Skills: auto-triggered via `activate_skill` tool call with user consent prompt; GEMINI.md always loaded verbatim into every session | Stable — skills added ~early 2026; GEMINI.md is older and stable | User consent prompt required before skill injection (friction vs. Claude Code); GEMINI.md is always-on, not skill-gated — creates a two-mechanism system |
| **GitHub Copilot** | Agent Skill (+ legacy: `copilot-instructions.md`, `*.instructions.md`, `*.prompt.md`) | Directory + `SKILL.md`; legacy formats are standalone Markdown files with their own frontmatter | Same as agentskills.io spec for skills; `*.instructions.md` uses `applyTo` and `excludeAgent` frontmatter; `*.prompt.md` uses `mode`, `tools`, `model` frontmatter | Skills: `.github/skills/`, `.claude/skills/`, `.agents/skills/` (project); `~/.copilot/skills/`, `~/.agents/skills/` (personal). Legacy `copilot-instructions.md`: `.github/copilot-instructions.md`. Legacy prompt files: `.github/prompts/` | Skills: auto-triggered by description match + explicit `/skill-name` slash command; legacy `copilot-instructions.md` always appended; `*.instructions.md` conditionally by glob (`applyTo`); `*.prompt.md` explicitly invoked | Skills: Stable (GA Dec 2025); legacy instructions: Stable; prompt files: Stable | VS Code-specific `context: fork` subagent field not in base spec; `argument-hint`, `user-invocable`, `disable-model-invocation` are Copilot extensions on top of spec |

***

## The Underlying Open Standard: agentskills.io

The decisive structural story is that what began as Anthropic's internal Claude Code convention became a published open standard. On December 18, 2025, Anthropic released the Agent Skills specification publicly, and OpenAI, Google, and Microsoft adopted it within weeks. The specification is governed at **agentskills.io** under Apache 2.0.[1][2][3][4]

The canonical format is:

```
skill-name/
├── SKILL.md          # Required: YAML frontmatter + Markdown body
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation / reference files
└── assets/           # Optional: templates, static resources
```

**Required SKILL.md frontmatter (identical across all tools):**

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | Yes | 1–64 chars; `[a-z0-9-]` only; no leading/trailing/consecutive hyphens; must match parent directory name |
| `description` | Yes | 1–1024 chars; must describe both what the skill does and when to trigger it |

**Optional SKILL.md frontmatter (all tools):**

| Field | Notes |
|-------|-------|
| `license` | License name or reference to bundled license file |
| `compatibility` | Max 500 chars; environment requirements |
| `metadata` | Arbitrary key-value map (`author`, `version`, etc.) |
| `allowed-tools` | Space-separated string of pre-approved tools (experimental per spec) |

All four tools — Claude Code, Codex, Gemini CLI, and GitHub Copilot — accept a `SKILL.md` in this format verbatim with no per-tool translation. As of mid-2026, 27+ agent products support the spec.[5][6][7][8][9][3]

***

## Tool-by-Tool Deep Dive

### 1. OpenAI Codex

**Concept name:** Agent Skill (primary); AGENTS.md (project-context, separate mechanism)

Codex adopted the open SKILL.md standard natively. Skills are loaded with three-tier progressive disclosure: at startup, only `name` and `description` are injected into context (capped at 2% of the model's context window or 8,000 characters if the context window is unknown); the full `SKILL.md` body loads only when Codex decides to use a skill; bundled `scripts/`, `references/`, and `assets/` files load only when referenced in instructions.[5]

**File format and location:**

```
# User-wide (any repo)
~/.agents/skills/<skill-name>/SKILL.md

# Repo-root (all subfolders)
$REPO_ROOT/.agents/skills/<skill-name>/SKILL.md

# Working directory (nearest scope)
$CWD/.agents/skills/<skill-name>/SKILL.md

# Admin / shared machine
/etc/codex/skills/<skill-name>/SKILL.md
```

Codex also scans ancestor directories up to the repo root. The older `~/.codex/skills/` path was used before the standard was adopted.[10][11][5]

**AGENTS.md — separate mechanism:** AGENTS.md is a *context file*, not a skill. It is plain Markdown with no frontmatter, no required fields, always loaded verbatim into every session — conceptually closer to GEMINI.md than to SKILL.md. It was released by OpenAI in August 2025 and donated to the Linux Foundation's Agentic AI Foundation in December 2025 alongside Anthropic's MCP. Multiple locations are merged hierarchically: `~/.codex/AGENTS.md` → `AGENTS.override.md` → `AGENTS.md` (repo root) → nested directory overrides. Discovery requires no frontmatter; Codex reads it automatically before every task.[12][13][14][15]

**Optional sidecar — `agents/openai.yaml`:** Within a skill directory, an `agents/openai.yaml` file adds Codex-app-specific metadata:[5]

```yaml
interface:
  display_name: "Optional user-facing name"
  short_description: "..."
  icon_small: "./assets/small-logo.svg"
  brand_color: "#3B82F6"
  default_prompt: "..."
policy:
  allow_implicit_invocation: false   # disables auto-trigger; forces explicit $skill invocation
dependencies:
  tools:
    - type: "mcp"
      value: "openaiDeveloperDocs"
      transport: "streamable_http"
      url: "https://developers.openai.com/mcp"
```

**Discovery/trigger:** Explicit via `/skills` picker or `$skill-name` in prompt; implicit auto-match against `description`. Setting `allow_implicit_invocation: false` in `openai.yaml` disables auto-trigger. Codex previously had custom prompt commands but now marks them deprecated in favor of skills.[16][5]

**Maturity:** Skills are GA. AGENTS.md is stable and now an AAIF/Linux Foundation open standard. The `agents/openai.yaml` sidecar is a Codex-proprietary extension.

**Source:** https://developers.openai.com/codex/skills[5]

**What Codex does NOT support relative to Claude Code SKILL.md:**
- No `~/.codex/skills/` as the canonical global path (migrated to `~/.agents/skills/`)
- The `agents/openai.yaml` sidecar is Codex-only and not part of the shared spec
- Plugin packaging layer (distributable bundles of multiple skills + MCP config) is an additional concept above raw skills, with no Claude Code equivalent

***

### 2. Google Gemini CLI

**Concept name:** Agent Skill (primary); GEMINI.md (always-on context); custom slash commands (TOML-based, separate mechanism); Extensions (`gemini-extension.json`, separate mechanism)

**Agent Skills — SKILL.md (primary skill mechanism):**

Gemini CLI adopted the agentskills.io open standard and uses exactly the same `SKILL.md` format. Discovery tiers (lowest to highest precedence):[17][8]

```
~/.gemini/skills/<skill-name>/SKILL.md          # User-global
~/.agents/skills/<skill-name>/SKILL.md          # User-global (alias)
<project>/.gemini/skills/<skill-name>/SKILL.md  # Workspace
<project>/.agents/skills/<skill-name>/SKILL.md  # Workspace (alias)
```

Extension-bundled skills also populate the skill pool.[18][17]

**Discovery/trigger:** At session start, all skill `name` + `description` fields are injected into context. When Gemini matches a task to a skill description, it calls the `activate_skill` tool. **Distinctive behavior:** A user consent prompt appears before the skill body and directory are injected — the user must type `y`. This is friction that Claude Code does not have. Manual commands: `/skills list`, `/skills disable <name>`, `/skills reload`.[19][20][17]

**GEMINI.md — always-on context file:**

GEMINI.md is a plain Markdown file with **zero frontmatter** and no required fields, loaded verbatim before every session. It is always in context — it does not have on-demand loading. Multiple GEMINI.md files are concatenated in hierarchical order:[21][22]

```
~/.gemini/GEMINI.md              # Global
<ancestor-dirs>/GEMINI.md        # Walking up to filesystem root
<project>/GEMINI.md              # Project-local
<subdirectory>/GEMINI.md         # Component-specific
```

The filename is configurable via `context.fileName` in `settings.json`. This means you can point Gemini CLI at `CLAUDE.md` files with a one-line config change: `"contextFileName": "CLAUDE.md"`. `/init` generates a starter GEMINI.md by scanning the codebase.[23][24][21]

**Custom slash commands — TOML (distinct mechanism, not skills):**

Custom slash commands are defined as `.toml` files under `~/.gemini/commands/<name>.toml` (global) or `.gemini/commands/<name>.toml` (project). These are explicitly invoked reusable prompts, not auto-triggered by task description. They carry no frontmatter schema — the TOML file itself defines the command behavior. Only activated by explicit `/command-name` invocation; never auto-triggered.[25][26]

**gemini-extension.json — Extensions (distinct mechanism):**

Extensions live at `~/.gemini/extensions/<ext-name>/gemini-extension.json`. The manifest schema:[18]

```json
{
  "name": "extension-name",          // required; lowercase, hyphens
  "version": "1.0.0",               // required
  "description": "...",             // optional; shown on geminicli.com/extensions
  "contextFileName": "CONTEXT.md",  // optional; custom context file for extension
  "mcpServers": { ... },            // optional; MCP servers to load
  "excludeTools": [ ... ],          // optional; tools to suppress
  "settings": [ ... ]               // optional; user-prompted config vars
}
```

Extensions bundle context, MCP servers, slash commands, and hooks into a distributable package. They auto-load on startup if enabled.[27][28]

**Maturity:** SKILL.md support stable (early 2026). GEMINI.md stable and longstanding. Custom slash commands stable (released July 2025). Extensions stable.

**Source:** https://geminicli.com/docs/cli/skills/; https://cloud.google.com/blog/topics/developers-practitioners/gemini-cli-custom-slash-commands[25][17]

**What Gemini CLI does NOT support relative to Claude Code SKILL.md:**
- User consent prompt before skill activation (friction not present in Claude Code)
- GEMINI.md and skills are two separate mechanisms serving different purposes; Claude Code uses SKILL.md for on-demand and CLAUDE.md for always-on, but the SKILL.md spec is shared
- Extensions add a third mechanism with no direct Claude Code equivalent

***

### 3. GitHub Copilot

**Concept name:** Agent Skill (primary, open standard); plus three legacy formats with separate frontmatter schemas

GitHub Copilot has the richest customization surface — Agent Skills (the open standard), `copilot-instructions.md` (always-on), `*.instructions.md` (path-targeted, always-on), `*.prompt.md` (explicitly invoked), and `.agent.md` custom agents.[29][30]

**Agent Skills — SKILL.md (primary skill mechanism):**

Copilot natively supports the agentskills.io standard, announced December 17, 2025. VS Code, GitHub Copilot CLI, and the Copilot cloud agent all read skills from the same locations:[31][6]

```
.github/skills/<skill-name>/SKILL.md      # Project (shared via Git)
.claude/skills/<skill-name>/SKILL.md      # Project (Claude compat alias)
.agents/skills/<skill-name>/SKILL.md      # Project (cross-tool alias)
~/.copilot/skills/<skill-name>/SKILL.md   # Personal (user-global)
~/.agents/skills/<skill-name>/SKILL.md    # Personal (cross-tool alias)
```

**VS Code-specific SKILL.md frontmatter extensions** (beyond the base spec):[6]

| Field | Required | Description |
|-------|----------|-------------|
| `argument-hint` | No | Hint text displayed in chat when skill is used as slash command |
| `user-invocable` | No | `true` (default): skill appears in `/` menu; `false`: hidden from menu but still auto-matched |
| `disable-model-invocation` | No | `true`: requires explicit `/skill-name` command; disables auto-trigger |
| `context` | No | `fork` (experimental): runs skill in dedicated subagent context; only final result returned |
| `allowed-tools` | No | Space-separated pre-approved tools (as per base spec, but Copilot explicitly enforces it) |

The `gh skill` GitHub CLI command provides install/update/publish lifecycle management.[32]

**Discovery/trigger:** Progressive disclosure (name+description at startup, full body on activation). Both auto-trigger (description match) and explicit `/skill-name` slash command work. VS Code shows skills in the `/` menu alongside prompt files. The `disable-model-invocation` field can make a skill explicit-only; `user-invocable: false` hides it from the menu but keeps auto-trigger.[6]

**Legacy: `copilot-instructions.md` — always-on context:**

Location: `.github/copilot-instructions.md`. Format: plain Markdown, **no frontmatter**. Always appended to the system prompt on every request, last in order (highest precedence for conflicts). No conditional loading; equivalent to GEMINI.md or AGENTS.md. Soft limit: ~1,000 lines before behavior becomes inconsistent.[33][34][30]

**Legacy: `*.instructions.md` — glob-targeted always-on:**

Location: `.github/instructions/` directory. Format: Markdown with optional YAML frontmatter:[29]

```yaml
---
applyTo: "**/*.py"          # glob pattern; "*" = all files
excludeAgent: "code-review" # optional; exclude from specific agent
---
```

Applied automatically to matching file contexts. No slash command — purely automatic.[34][35]

**Legacy: `*.prompt.md` — explicit reusable prompts:**

Location: `.github/prompts/`. Format: Markdown with YAML frontmatter:[36][33]

```yaml
---
mode: "agent"          # or "ask" or "edit"
tools: ["github", "terminal"]  # tools the prompt enables
model: "gpt-4o"        # optional model pin
---
```

Explicitly invoked by the user (attach to chat, or use `/prompt-name` in some contexts). Does NOT auto-trigger based on description. Unlike skills, prompt files carry no `description` field — they are invoked by user choice, not agent judgment.[30]

**Custom Agents — `.agent.md`:**

Location: `.github/agents/<name>.agent.md`. Defines a persona + tool set as a named `@agent` in Copilot Chat. Supports tool enable/disable and model selection in frontmatter, plus handoffs (suggestions for next steps after the agent completes). Available via agent picker in Visual Studio 2026 Insiders.[37][30]

**Maturity:** Skills GA (Dec 2025). `copilot-instructions.md` stable. `*.instructions.md` stable (preview in Visual Studio and JetBrains, stable in VS Code). `*.prompt.md` stable. Custom agents in preview (VS 2026 Insiders). `context: fork` experimental.

**Source:** https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills; https://code.visualstudio.com/docs/agent-customization/agent-skills[32][6]

**What GitHub Copilot does NOT support relative to Claude Code SKILL.md (base spec):**
- `context: fork`, `argument-hint`, `user-invocable`, `disable-model-invocation` are Copilot extensions not in the shared spec; writing these fields in a skill deployed to Codex or Gemini CLI will cause those fields to be silently ignored (spec-compliant behavior)
- The legacy `*.prompt.md` and `copilot-instructions.md` formats have no Claude Code equivalent and no cross-tool portability

***

## Cross-Tool Standard Status (Question 4)

**The answer is yes, and it happened faster than expected.** The AGENTS.md spec — a flat, frontmatter-free project context file — was released by OpenAI in August 2025, donated to the Linux Foundation's Agentic AI Foundation (AAIF) in December 2025 alongside Anthropic's MCP. AGENTS.md is now adopted by 60,000+ open-source repositories.[14][15][38][39]

More directly relevant to skills: the **agentskills.io** specification — which is Anthropic's SKILL.md format formalized into an open standard — was published in December 2025. As of mid-2026, all four tools (Claude Code, Codex, Gemini CLI, GitHub Copilot) natively read the identical `SKILL.md` file format without any translation. The `.agents/skills/` path alias is explicitly supported by Codex, Gemini CLI, and GitHub Copilot  as a cross-tool neutral location.[7][2][9][3][17][32][5]

In practice, a skill placed in `.agents/skills/<name>/SKILL.md` in a project repo is discovered by all four tools with zero per-tool adaptation — assuming no Copilot-only frontmatter extensions are used.

***

## Frontmatter Schema Translation Table (Question 5)

This table shows the effort of translating a Claude Code `SKILL.md` to each tool's format. Since all four tools now share the same base spec, the translation is zero for required fields.

| Field in SKILL.md | Claude Code | Codex | Gemini CLI | GitHub Copilot | Notes |
|-------------------|-------------|-------|------------|----------------|-------|
| `name` (required) | ✅ | ✅ | ✅ | ✅ | Identical; must match directory name across all tools |
| `description` (required) | ✅ | ✅ | ✅ | ✅ | Identical; used for auto-trigger matching across all tools |
| `license` (optional) | ✅ | ✅ | ✅ | ✅ | In spec; silently ignored if not recognized |
| `compatibility` (optional) | ✅ | ✅ | ✅ | ✅ | In spec |
| `metadata` (optional) | ✅ | ✅ | ✅ | ✅ | In spec; arbitrary key-value map |
| `allowed-tools` (optional) | ✅ (experimental) | ✅ (experimental) | ✅ (experimental) | ✅ (enforced) | In spec but marked experimental; Copilot adds security warnings for `shell`/`bash` |
| `argument-hint` | — | — | — | ✅ VS Code only | Copilot extension; ignored by other tools |
| `user-invocable` | — | — | — | ✅ VS Code only | Copilot extension; ignored by other tools |
| `disable-model-invocation` | — | — | — | ✅ VS Code only | Copilot extension; ignored by other tools |
| `context: fork` | — | — | — | ✅ Experimental | Copilot extension; ignored by other tools |
| Bundled `scripts/`, `references/`, `assets/` dirs | ✅ | ✅ | ✅ | ✅ | All tools discover bundled files; Copilot requires Markdown link references in body |
| Directory-of-files model | ✅ | ✅ | ✅ | ✅ | All tools: one directory per skill, `SKILL.md` at root |

**Translation cost: Zero for the base `name` + `description` + markdown body pattern.** Copilot-only frontmatter extensions (`argument-hint`, `user-invocable`, `disable-model-invocation`, `context`) are additive and silently ignored by other tools — they do not break cross-tool portability.

***

## Prior Art: Cross-Tool Skill Installers and Utilities (Question 6)

Several open-source projects address the "write once, deploy to N agents" problem:

### `npx skills` (vercel-labs/skills)
The most mature cross-tool installer. Released by Vercel Labs in January 2026:[40][41]
- **Repo:** https://github.com/vercel-labs/skills
- **Registry:** https://skills.sh/
- **Key commands:**
  ```bash
  npx skills add <owner/repo>[@skill]   # install from GitHub
  npx skills add <owner/repo> -g        # install globally (user-level)
  npx skills add <owner/repo> --agent claude-code cursor  # target specific agents
  npx skills list                        # list installed skills
  npx skills find <query>               # search registry
  npx skills init my-skill             # scaffold new SKILL.md
  ```
- Supports 70+ agents including Claude Code, Codex, Gemini CLI, GitHub Copilot, Cursor, Windsurf, Goose, OpenCode, Kimi Code[42][40]
- Auto-detects installed agents and places skills in the correct directories[43]

### `npx agent-skills-cli` (alirezarezvani/claude-skills)
Another universal installer:[44]
```bash
npx agent-skills-cli add <owner/repo>                # all agents
npx agent-skills-cli add <owner/repo> --agent claude  # Claude Code only
npx agent-skills-cli add <owner/repo> --agent vscode  # GitHub Copilot only
```
Installs to: Claude Code → `~/.claude/skills/`; Cursor → `.cursor/skills/`; VS Code → `.github/skills/`; Goose → `~/.config/goose/skills/`.[44]

### `npx add-skill` (pratikshadake/claude-product-management-skills)
Simpler single-command installer:[45]
```bash
npx add-skill pratikshadake/claude-product-management-skills
```
Targets Claude Code CLI, Codex, Gemini CLI, GitHub Copilot, Amp, Kimi Code CLI, OpenCode simultaneously.[45]

### `gh skill` (GitHub CLI extension)
GitHub's own skill management command (public preview, requires GitHub CLI v2.90.0+):[32]
```bash
gh skill search TOPIC
gh skill preview OWNER/REPOSITORY SKILL
gh skill install OWNER/REPOSITORY SKILL [--agent claude-code] [--scope user]
gh skill update --all
gh skill publish
```
The `--agent` flag can install to non-Copilot targets including `claude-code`.[32]

### `skills-ref` (agentskills/agentskills)
Reference library and validator from the agentskills.io spec maintainers:[2]
```bash
skills-ref validate ./my-skill
skills-ref validate ./my-skill --fix
```

### Blog post: "Claude Skills, anywhere: making them first-class in Codex CLI"
Pre-standard prior art by Robert Glaser (October 2025) describing a manual shell script that walked `skills/**/SKILL.md`, parsed YAML frontmatter, and exposed skills to Codex before native support existed. URL: https://www.robert-glaser.de/claude-skills-in-codex-cli/[11]

### YouTube: "How to Share Skills Between Claude Code, Codex, Cursor & GitHub Copilot"
Practical walkthrough showing symlink-based cross-tool skill sharing (April 2026): https://www.youtube.com/watch?v=Sl2NilOq9gw[46]

***

## Quick Take: Translation Work Estimate

**The situation is substantially better than the question's framing anticipated.** The convergence on agentskills.io happened in late 2025 / early 2026, meaning the answer to questions 1–3 is essentially: all three tools natively support Anthropic's SKILL.md convention with zero required changes.

| Translation scenario | Effort | Reasoning |
|----------------------|--------|-----------|
| Claude Code `SKILL.md` → Codex | **Trivial** | Identical spec; copy directory to `.agents/skills/` or `~/.agents/skills/`; works immediately |
| Claude Code `SKILL.md` → Gemini CLI | **Trivial** | Identical spec; copy to `.gemini/skills/` or `~/.gemini/skills/`; activation gains a user consent prompt (behavioral diff, not a format diff) |
| Claude Code `SKILL.md` → GitHub Copilot | **Trivial** | Identical spec; copy to `.github/skills/` or `~/.copilot/skills/`; Copilot-only frontmatter extensions are additive, not required |
| Any tool `SKILL.md` → Any other tool | **Trivial** | All four tools read the same two-field frontmatter (`name` + `description`) + markdown body |
| Copilot-specific fields (`context: fork`, `argument-hint`) → other tools | **Not translatable** | Silently ignored by Codex and Gemini CLI; no semantic equivalent; fork behavior must be re-architected per-tool if needed |
| AGENTS.md (Codex/project context) → Claude Code equivalent | **Trivial** | Claude Code reads `CLAUDE.md` for always-on context; rename or symlink; no frontmatter to translate either way |
| GEMINI.md → Claude Code CLAUDE.md | **Trivial** | Both are plain Markdown with no frontmatter; rename/symlink |
| Copilot `*.prompt.md` (explicit) → other tools | **Moderate** | No equivalent auto-discovered format in Codex or Gemini CLI; must be converted to a `SKILL.md` with `disable-model-invocation: false` semantics — possible but requires restructuring the invocation model |
| Copilot `*.instructions.md` (glob-targeted) → other tools | **Significant** | No spec equivalent for `applyTo` glob targeting across Codex or Gemini CLI; nearest equivalent is embedding the glob-specific rules into `AGENTS.md`/`GEMINI.md` with prose-level conditionals |

**Bottom line:** A canonical-source multi-tool skill installer that syncs the `SKILL.md` directory structure across all four tools requires exactly the same work as `cp -r` (or a symlink), plus handling the `.agents/skills/` vs. tool-specific path aliases — which `npx skills` and `gh skill` already do. The trigger semantics (description-match auto-activation) are identical across all four tools. The only structural divergence is Copilot's `context: fork` subagent pattern and the `*.prompt.md` explicit-only format, both of which are Copilot-only and have no cross-tool expression.
