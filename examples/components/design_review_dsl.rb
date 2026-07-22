# frozen_string_literal: true
# Inner DSL for a fictional design-review document: "Getting Wayfinder and
# Beacon in front of every agent" -- a genre example proving StreamWeaver's
# doc component family can reach 1:1 visual parity with a claude.ai-hosted
# Artifact for editorial "design review" documents specifically: option
# cards with chips, pick states on both a card and a table row, a
# two-column checklist split, and a full re-skin via one unlayered CSS
# file. Wayfinder/Beacon, the reviewers, and the citations below are
# entirely invented for this example -- see docs/porting-artifacts.md for
# the process this was ported through.
#
# Intended for canvas-push:
#   streamweaver canvas-push <session> < examples/components/design_review_dsl.rb
# CAVEAT: the canvas bridge injects only master-theme CSS -- it cannot carry
# this example's own stylesheet yet (stream_weaver-9uk), so a canvas push shows
# correct structure without the bespoke re-skin. The standalone app is the
# faithful rendering: ruby examples/components/design_review_demo.rb

# ---------------------------------------------------------------------------
# Small helpers, local to this DSL body (same pattern as
# examples/parity/tyrion_warroom_components.rb's inline `def art_glyph`).
# ---------------------------------------------------------------------------

# A "chip": dim dimension label + colored status dot + value text.
# color: is one of :green/:yellow/:red (good/mid/weak).
def ad_chip(dim, color, value)
  div(class: "ad-chip") do
    phrase(dim, class: "ad-chip-dim")
    status_dot(status: color, size: :sm)
    phrase(value)
  end
end

# One option card (section 03). Chips + prose are supplied via the block.
#
# `mechanism` (the subtitle line) is rendered via `md`, not card_header's
# own `meta:` -- CardHeader's meta: renders as escaped plain text
# (view.span { @meta }), so backtick-quoted terms in the subtitle (e.g.
# "the existing `beacon init` pattern") would show up as literal backtick
# characters instead of code pills. Routing it through `md` as an extra
# header child gets the same markdown-to-<code> handling every other prose
# paragraph in this doc already gets.
def ad_option(letter, title, mechanism, recommended: false)
  classes = ["ad-option"]
  classes << "ad-option--pick" if recommended
  card(class: classes.join(" ")) do
    card_header(title, badge: letter) do
      div(class: "ad-option-mech") { md mechanism }
      badge("Recommended", variant: :info) if recommended
    end
    card_body { yield if block_given? }
  end
end

# A raw rating cell for the comparison-matrix table (section 04): colored
# status dot + text, matching the chip's dot but laid out for a table cell.
# Table's own markdown: true option renders cell HTML raw (already used by
# the framework to turn `[text](url)` into <a> tags) -- this reuses that
# same sanctioned escape hatch rather than hand-building component objects
# outside the DSL.
def ad_rate(color, value)
  %(<span class="ad-cell-rating"><span class="sw-status-dot sw-status-dot-#{color} sw-status-dot-sm"></span>#{value}</span>)
end

# One checklist tile (section 06): fixed-width mark glyph + prose line.
def ad_check(mark, text)
  div(class: "ad-check-item") do
    phrase(mark, class: "ad-check-mark")
    md text
  end
end

div(class: "ad-doc") do
  # =========================================================================
  # Header
  # =========================================================================
  doc_header(
    eyebrow: "Design options — internal review",
    title: "Getting Wayfinder and Beacon in front of every agent, without a human having to introduce them"
  )
  div(class: "ad-dek") do
    md "Six ways to make the project registry and the federated knowledge base self-discoverable to Claude Code, Codex, Gemini CLI, and Copilot — scored against discovery, friction, and cognitive-load principles, drafted by a research subagent, July 2026."
  end
  div(class: "ad-meta-row") do
    div { phrase("Subject", class: "ad-meta-label"); phrase(" Wayfinder + Beacon, pre-launch") }
    div { phrase("Client", class: "ad-meta-label"); phrase(" the agent, not the human") }
    div { phrase("Options", class: "ad-meta-label"); phrase(" 6, one recommended") }
  end

  # =========================================================================
  # 01 — The actual problem
  # =========================================================================
  doc_section_header "01 — The actual problem", "", id: "problem"
  callout(title: "Framing") do
    md "The customer whose friction has to hit zero is **the agent itself** — not a human reading a README. Any of the four CLIs, dropped cold into an arbitrary project, needs to (a) discover Wayfinder/Beacon exist, (b) know how to query them, and (c) develop the habit of *writing* durable knowledge back in — with no per-project hand-authoring by a maintainer. The only human cost allowed is `gem install wayfinder` once, plus at most one machine-level setup command. Anything that requires remembering a per-repo step decays under real-world attention scarcity — the cognitive-load principle applied to the maintainer, not just the end user."
  end

  # =========================================================================
  # 02 — Verified landscape, July 2026
  # =========================================================================
  doc_section_header "02 — Verified landscape, July 2026", "What each CLI actually reads on its own", id: "landscape"
  md "Two structural facts fall out of this: a repo with both `AGENTS.md` and a `CLAUDE.md` that imports it covers Claude Code, Codex, *and* Copilot with one canonical body of text — Gemini is the lone holdout needing its own file. And MCP is the only surface all four share, and the only one that's machine-global rather than per-repo."
  div(class: "ad-tbl-scroll") do
    table(
      class: "ad-landscape-table",
      markdown: true,
      headers: ["CLI", "Repo context file", "User-global context", "MCP", "Plugin / skill surface"],
      rows: [
        [
          "Claude Code",
          "<code>CLAUDE.md</code> only — no native AGENTS.md read (tracked in the public issue queue, thousands of reactions); <code>@AGENTS.md</code> import works",
          "<code>~/.claude/CLAUDE.md</code>",
          "Yes — <code>claude mcp add</code>",
          "Skills, plugins, marketplaces"
        ],
        [
          "Codex CLI",
          "<code>AGENTS.md</code> — native, root + nested",
          "<code>~/.codex/AGENTS.md</code>",
          "Yes — can run <em>as</em> an MCP server too",
          "AGENTS.md is the spec it champions"
        ],
        [
          "Gemini CLI",
          "<code>GEMINI.md</code> by default — AGENTS.md not out-of-box (tracked as an open feature request)",
          "<code>~/.gemini/GEMINI.md</code>",
          "Yes — <code>~/.gemini/settings.json</code>",
          "Extensions bundle MCP config + context file together"
        ],
        [
          "Copilot CLI",
          "<code>AGENTS.md</code>, <code>.github/copilot-instructions.md</code> — <em>and also</em> CLAUDE.md &amp; GEMINI.md",
          "user-level instruction files",
          "Yes — command + HTTP",
          "Custom agents, skills, MCP marketplace"
        ]
      ]
    )
  end

  # =========================================================================
  # 03 — Six options
  # =========================================================================
  doc_section_header "03 — Six options", "What “batteries included” could actually mean", id: "options"

  ad_option("A", "Universal context-file writer", "Generalize the existing `beacon init` pattern to every convention that matters") do
    div(class: "ad-chips") do
      ad_chip("Discovery", :green, "Strong")
      ad_chip("Friction", :yellow, "1 cmd/repo")
      ad_chip("Load·user", :green, "Good")
      ad_chip("Load·maint.", :green, "Low burden")
      ad_chip("Cost", :green, "~1 day")
      ad_chip("Robustness", :yellow, "Medium")
    end
    md "One command writes a canonical section into every file that matters: a full section in `AGENTS.md` (covers Codex + Copilot natively), a `CLAUDE.md` created with an `@AGENTS.md` import if missing (covers Claude Code), a thin pointer stub in `GEMINI.md`, and a section in `.github/copilot-instructions.md` if one already exists. All four render from one template in the gem, fenced with `<!-- wayfinder:begin -->` markers so re-runs update in place — the same idiom `lib/wayfinder/beacon/init.rb` already uses for AGENTS.md alone. The section has to state the *write* directive explicitly (\"when you learn something durable, register it; when you produce reusable knowledge, add a page and reindex\") — a context file is the only place you can install a habit, not just a capability. Weakness: someone still has to run it, once, per repo, and static prose drifts from the CLI's real surface over time."
  end

  ad_option("B", "Universal MCP server", "Ship the registry and Beacon as live, structured tools every CLI can call") do
    div(class: "ad-chips") do
      ad_chip("Discovery·find", :green, "Strong")
      ad_chip("Discovery·digest", :yellow, "Weaker")
      ad_chip("Friction", :green, "1 cmd/machine")
      ad_chip("Load·user", :green, "Excellent")
      ad_chip("Load·maint.", :green, "Very low")
      ad_chip("Cost", :yellow, "2–4 days")
      ad_chip("Robustness", :green, "Highest")
    end
    md "`wayfinder mcp` (stdio) exposes structured tools — `wayfinder_locate`, `wayfinder_search`, `wayfinder_show`, `beacon_search`, `beacon_resolve`, plus write tools like `wayfinder_update` and `beacon_register`. A one-time `wayfinder agents install-mcp` writes client config for whichever CLIs it detects, idempotently, the same way `install-hooks` already chains onto an existing pre-commit hook. The property worth dwelling on: once registered at user scope, *every* session of *all four* CLIs, in every directory, sees these tools in its list — no per-repo file, nobody remembering anything. And because the tools *are* the real behavior, they can never drift out of sync with it the way a static snippet can. Cost is real (verify the Ruby MCP SDK's maturity first), and a tool list alone teaches an agent to *read* more readily than to *write*."
  end

  ad_option("C", "Native skill / plugin bundles, one per ecosystem", "A Claude Skill, a Gemini extension, a Copilot agent — each in its own idiom") do
    div(class: "ad-chips") do
      ad_chip("Discovery", :green, "Excellent")
      ad_chip("Friction", :green, "1 cmd/machine")
      ad_chip("Load·user", :green, "Good")
      ad_chip("Load·maint.", :red, "High — 4 formats")
      ad_chip("Cost", :red, "High + ongoing")
      ad_chip("Robustness", :red, "Low–medium")
    end
    md "`wayfinder agents install [claude|gemini|codex|copilot|all]` would drop a real Claude Skill (which can trigger *contextually* — \"when the user references a project by name\" — something a static file can't do), a Gemini extension bundling both MCP config and a GEMINI.md, and a Copilot custom agent. This is the best per-ecosystem experience on the list, and the worst maintenance profile: four young, fast-moving vendor formats, each a separate artifact to keep in sync, each liable to drift exactly as the cognitive-load principle predicts for the maintainer. The seductive trap — skip until one ecosystem clearly earns the investment."
  end

  ad_option("D", "Docs-only bet", "An excellent README and `docs/for-agents.md`, nothing mechanical") do
    div(class: "ad-chips") do
      ad_chip("Discovery", :red, "Weak")
      ad_chip("Friction", :red, "Fails")
      ad_chip("Load·user", :red, "Fails")
      ad_chip("Load·maint.", :green, "~zero")
      ad_chip("Cost", :green, "~zero")
      ad_chip("Robustness", :yellow, "n/a")
    end
    md "Fails the friction principle outright: the agent has to already know to look, and in practice only discovers Wayfinder from *inside* the Wayfinder repo itself — the entire point was discovery from *other* projects. Fails the cognitive-load principle too, since it relies on a human remembering to paste a snippet somewhere. Keep the good README regardless of what else ships — but this alone is the absence of a mechanism, not one."
  end

  ad_option("E", "The tool teaches itself", "Error messages and help output as onboarding, at the moment of contact") do
    div(class: "ad-chips") do
      ad_chip("Discovery", :green, "Perfect in-moment")
      ad_chip("Friction", :green, "Zero / instant")
      ad_chip("Load·user", :green, "Excellent")
      ad_chip("Load·maint.", :green, "Very low")
      ad_chip("Cost", :green, "Hours")
      ad_chip("Robustness", :green, "High")
    end
    md "Orthogonal to every other option, cheap, and compounds with all of them. `beacon check` gate failures already interrupt an agent mid-commit — that's the highest-attention channel it will ever give you, so make the failure text a complete, copy-pasteable remediation plus one line of \"what Beacon is and why.\" Add `wayfinder help --agent` / `beacon help --agent` emitting exactly Option A's canonical snippet. End `wayfinder init` with \"next: run `wayfinder agents init`.\" Give empty `--json` results a `_hint` field. It's an amplifier, not a discovery mechanism on its own — something else still has to cause first contact — but there's no version of \"batteries included\" that shouldn't include it."
  end

  ad_option("F", "Hybrid — MCP as source of truth, context files as habit", "B + A + E, layered in that priority order", recommended: true) do
    div(class: "ad-chips") do
      ad_chip("Discovery", :green, "Excellent")
      ad_chip("Friction", :green, "~zero after setup")
      ad_chip("Load·user", :green, "Excellent")
      ad_chip("Load·maint.", :green, "Low")
      ad_chip("Cost", :yellow, "~1 week total")
      ad_chip("Robustness", :green, "High")
    end
    md "The full story: `gem install wayfinder` puts the binaries on PATH. `wayfinder agents setup`, run once per machine, registers the MCP server with every detected CLI *and* appends a short section to each CLI's user-global context file — global prose installs the habit (\"these tools exist, use them, write back what you learn\"), MCP tools keep the capability always fresh. `wayfinder agents init` stays available per-repo for project-specific pointers (hub location, Beacon membership), and both `beacon init` and `wayfinder init` suggest running it — so it self-propagates. Self-teaching output (E) runs through all of it. Static prose is kept deliberately thin and stable; everything that changes with the CLI's surface lives behind MCP descriptions and `help --agent`, so the sync burden the cognitive-load principle warns about approaches zero."
  end

  # =========================================================================
  # 04 — Comparison
  # =========================================================================
  doc_section_header "04 — Comparison", "Side by side", id: "matrix"
  div(class: "ad-legend") do
    div(class: "ad-legend-item") { status_dot(status: :green, size: :sm); phrase("Strong / low cost") }
    div(class: "ad-legend-item") { status_dot(status: :yellow, size: :sm); phrase("Mixed / moderate") }
    div(class: "ad-legend-item") { status_dot(status: :red, size: :sm); phrase("Weak / high cost") }
  end
  div(class: "ad-tbl-scroll") do
    table(
      class: "ad-matrix-table mono",
      markdown: true,
      headers: ["Option", "Discovery", "Friction", "Load·user", "Load·maint.", "Cost", "Robustness"],
      rows: [
        ["A — Context writer", ad_rate(:green, "Strong"), ad_rate(:yellow, "1/repo"), ad_rate(:green, "Good"), ad_rate(:green, "Low"), ad_rate(:green, "~1 day"), ad_rate(:yellow, "Medium")],
        ["B — MCP server", ad_rate(:yellow, "Find ↑ / digest ↓"), ad_rate(:green, "1/machine"), ad_rate(:green, "Excellent"), ad_rate(:green, "V. low"), ad_rate(:yellow, "2–4 days"), ad_rate(:green, "Highest")],
        ["C — Native bundles", ad_rate(:green, "Excellent"), ad_rate(:green, "1/machine"), ad_rate(:green, "Good"), ad_rate(:red, "High"), ad_rate(:red, "High+ongoing"), ad_rate(:red, "Low–med")],
        ["D — Docs only", ad_rate(:red, "Weak"), ad_rate(:red, "Fails"), ad_rate(:red, "Fails"), ad_rate(:green, "~zero"), ad_rate(:green, "~zero"), ad_rate(:yellow, "n/a")],
        ["E — Self-teaching", ad_rate(:green, "Perfect*"), ad_rate(:green, "Zero"), ad_rate(:green, "Excellent"), ad_rate(:green, "V. low"), ad_rate(:green, "Hours"), ad_rate(:green, "High")],
        ["F — Hybrid (B+A+E)", ad_rate(:green, "Excellent"), ad_rate(:green, "~zero*"), ad_rate(:green, "Excellent"), ad_rate(:green, "Low"), ad_rate(:yellow, "~1 week"), ad_rate(:green, "High")]
      ]
    )
  end
  md "*E: perfect only at the moment an agent already touches the tool — it doesn't cause first contact. F: zero friction only after the one machine-level setup command."

  # =========================================================================
  # 05 — Recommendation
  # =========================================================================
  doc_section_header "05 — Recommendation", "", id: "reco"
  div(class: "ad-reco") do
    callout(title: "Top pick — Option F, built in order E → A → B") do
      md <<~MD
        Two failure modes matter: the agent never hears about the tool, and the maintainer has to keep four vendor artifacts in sync and stops (the cognitive-load principle, maintainer edition). The hybrid solves the first one twice over — global context prose installs the write-back habit in every session on the machine, MCP tools make the capability ambient and self-describing — and solves the second by keeping the volatile parts live (MCP, `help --agent`) and the static parts thin and stable. Option C's per-vendor bundles are the trap: best-in-class UX per ecosystem, worst-in-class rot profile. Skip it until one ecosystem clearly earns it — a Claude Skill is the strongest later candidate, since skills uniquely encode *when* to write, and it can be dogfooded privately first.

        ### Ship-now fallback

        A weekend, pre-launch: Option E (hours — `--agent` help mode, gate-failure remediation text, `_hint` fields) plus Option A (`wayfinder agents init`, generalizing the existing `init.rb` machinery to the CLAUDE.md-imports-AGENTS.md pattern and a GEMINI.md stub). That alone takes Codex from "incidentally best-served" to all four CLIs covered per-repo, from one template. Layer in the MCP server (B) as the flagship feature for the actual launch — it also happens to be the strongest marketing artifact for a public gem, since MCP is what 2026 readers scan for first.
      MD
    end
  end
  div(class: "ad-aside") do
    callout(title: "One note, regardless of which option wins") do
      md "Tool availability alone gets an agent *reading* the registry. The *writing*-knowledge-back behavior — the part that actually builds toward the friction/cognitive-load UX — only happens when instructions say *when* to write: \"learned something durable → registry or wiki, then reindex.\" That sentence belongs in every surface: the AGENTS.md section, the global stub, the MCP tool descriptions, and any Skill built later."
    end
  end

  # =========================================================================
  # 06 — Confidence check
  # =========================================================================
  doc_section_header "06 — Confidence check", "Verified this session, vs. still open", id: "confidence"
  columns(class: "ad-split", gap: "1.2rem") do
    column do
      phrase("Verified via search, July 2026", class: "ad-col-h ad-col-h--v")
      div(class: "ad-checklist ad-checklist--verified") do
        ad_check("✓", "Claude Code has no native AGENTS.md read — tracked in the public issue queue, thousands of reactions; `@AGENTS.md` import and symlinking are the working patterns")
        ad_check("✓", "Gemini CLI's sole out-of-box context filename is GEMINI.md; AGENTS.md support is an open feature request. A per-user `contextFileName` override exists in settings but isn't the out-of-box default other users will have")
        ad_check("✓", "Copilot CLI reads AGENTS.md, .github/copilot-instructions.md, .github/instructions/**, and even CLAUDE.md/GEMINI.md, per its own docs")
        ad_check("✓", "All four CLIs support MCP; Codex can run *as* an MCP server; config lives at `~/.gemini/settings.json`, via `claude mcp add`, and in Copilot's command/HTTP server config")
        ad_check("✓", "Gemini CLI extensions (`gemini extensions install org/repo`) bundle MCP config + context file with vendor-managed updates")
        ad_check("✓", "Claude Code plugins/marketplaces are the current skill-distribution format (`/plugin`, bundling SKILL.md + hooks + MCP config)")
      end
    end
    column do
      phrase("Needs a second reviewer's confirmation", class: "ad-col-h ad-col-h--u")
      div(class: "ad-checklist ad-checklist--unverified") do
        ad_check("?", "Whether the `@AGENTS.md` import works in a freshly-created CLAUDE.md exactly as documented, on the currently installed Claude Code version — test empirically")
        ad_check("?", "Copilot CLI's exact user-level (machine-global) instruction file path and MCP config format — docs found cover the IDE surface best, not the standalone CLI")
        ad_check("?", "Codex's `config.toml` MCP schema's current shape — check against the installed version before writing `install-mcp`")
        ad_check("?", "Whether a maintained official Ruby MCP SDK gem exists to build Option B on — a 10-minute check before committing to that estimate")
      end
    end
  end
  div(class: "ad-sources") do
    md "Sources: notes.example.dev/agent-cli-notes (context-file survey) · github.com/example-cli/example-cli/issues/8841 · cli-docs.example.dev/gemini-md · github.com/example-cli/gemini-cli/issues/5210 · docs.example.dev/copilot-cli/custom-instructions · changelog.example.dev/2025-08-28 · cli-docs.example.dev/extensions · docs.example.dev/plugin-marketplaces · surveys.example.dev/cli-comparison"
  end

  div(class: "ad-footer") do
    phrase("Wayfinder / Beacon — agent discovery options")
    phrase("drafted by a research subagent · reviewed for Priya Osei, Platform Team")
  end
end
