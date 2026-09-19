# Source-token workflow: one constructed dashboard

## Result

For this single constructed fixture, StreamWeaver has the smallest initial existing-project source set: **1,100 tokens**, compared with **1,393** for reusable plain HTML/CSS and **1,346** for React. React has the smallest page-specific initial source (**210 tokens**) and the smallest revision patch (**383 tokens**). These are source-size measurements for this fixture, not a universal ranking.

The fixture is a release-readiness dashboard with one title, three metrics, a four-row status table, and a badge. The fixed revision adds a `Status` column and changes the badge rule:

- Initial: `ON TRACK` when the blocked metric is at most one; otherwise `AT RISK`.
- Revised: `ACTION NEEDED` when any row status is `Blocked`; otherwise `ON TRACK`.

StreamWeaver uses its public `stat_display`, `table`, `badge`, and grid DSL. React uses reusable `Dashboard`, `Metric`, `Badge`, and `StatusTable` components. The plain implementation uses initial/revised data modules plus one reusable ERB template that emits dependency-free semantic HTML/CSS. All three share the same local responsive stylesheet and meet the same below-700px stacking/table-scroll requirement.

## Token counts

Tokenizer: `tiktoken==0.11.0`, encoding `cl100k_base`. Formatting, whitespace, and comments count. Each file is tokenized separately and the counts are summed, so tokens never merge across file boundaries.

| Measurement | StreamWeaver | Plain HTML/CSS | React |
|---|---:|---:|---:|
| Initial app-specific source | 292 | 230 | **210** |
| Shared local styles | 558 | 558 | 558 |
| Reusable local helpers | 0 | 355 | 328 |
| Canonical fixture specification | 250 | 250 | 250 |
| **Initial existing-project subtotal** | **1,100** | 1,393 | 1,346 |
| Render harness | 158 | 138 | 203 |
| Dependency records / locks | 27 | 29 | 6,985 |
| Initial all-recorded-files / full-source reread | **1,285** | 1,560 | 8,534 |
| Fixed revision unified diff | 432 | 386 | **383** |
| Final app-specific source | 308 | 238 | **216** |
| Final existing-project subtotal | **1,116** | 1,401 | 1,352 |
| Final all-recorded-files | **1,301** | 1,568 | 8,540 |

“Full-source reread” intentionally equals the initial all-recorded-files set: it measures reading the same complete recorded inputs again. “Existing-project” is the authoring/maintenance set: app, canonical fixture, shared local CSS, and reusable local helpers. It excludes render harnesses and dependency records for every implementation. “All-recorded-files” adds both excluded categories back.

React’s dependency-record count is dominated by the pinned `package-lock.json`; this is why the existing-project subtotal is the headline comparison. The all-recorded-files row remains visible, but it is not an empty-directory cost comparison: StreamWeaver and plain HTML use this repository’s existing Ruby bundle, while React carries an installable lockfile in the benchmark. The React app-specific and patch rows remain visible because they are the smallest in this sample. Render harnesses are reported separately so an SSR verification script is not confused with application maintenance source.

## What is counted

| Category | StreamWeaver | Plain HTML/CSS | React |
|---|---|---|---|
| App source | `initial.rb` / `revised.rb` | `initial.rb` / `revised.rb` data/rules | `initial.jsx` / `revised.jsx` |
| Shared local styles | `shared/dashboard.css` | Same file | Same file |
| Reusable local helpers | Existing external StreamWeaver components; 0 local tokens | `dashboard.erb` | `components.jsx` |
| Render harness | `render.rb` | `render.rb` | `render.jsx` |
| Dependency records / locks | Version inventory in `dependencies.txt` | Platform/version inventory in `dependencies.txt` | Installable `package.json`, `package-lock.json` |
| Fixture | `fixture.json` | Same file | Same file |

The source of StreamWeaver itself, browser engine code, React/ReactDOM/tsx package contents, generated HTML, `node_modules`, and Python environment packages are excluded. Versions or locks are recorded, but only React’s records form an independently installable dependency lock. Reproduction of the StreamWeaver and plain variants assumes this repository and its Ruby bundle.

The measurement apparatus (`requirements.txt`, measurement script, semantic verifier, render orchestrator) is hashed and counted separately at **1,876 tokens**, but excluded from every implementation total because it measures all three equally.

## Reproduce

From the repository root:

```bash
cd bench/source_token_workflow
uv venv .venv
uv pip install --python .venv/bin/python -r requirements.txt
./scripts/render_all.sh
.venv/bin/python scripts/measure.py
./scripts/check_determinism.sh
git diff --exit-code results.json
```

`render_all.sh` renders six ignored HTML artifacts and runs semantic verification against the fixed fixture. The verifier checks the title, all three metrics, four rows, initial badge/no-status behavior, and revised badge/status behavior for every implementation.

To inspect them from one server:

```bash
python3 -m http.server 4581 --directory tmp/rendered
```

- `http://127.0.0.1:4581/streamweaver-initial.html`
- `http://127.0.0.1:4581/plain-initial.html`
- `http://127.0.0.1:4581/react-initial.html`
- Replace `initial` with `revised` for the fixed revision.

The machine-readable record is [`bench/source_token_workflow/results.json`](../../bench/source_token_workflow/results.json). It includes tokenizer identity, every input path and SHA-256 hash, category counts, normalized unified diffs, and their hashes.

## Limits

These counts are source-size proxies. They are not model billing tokens, prompt/input/reasoning cost, measured generation effort, elapsed generation speed, edit-tool cost, code comprehension, maintainability, or user performance. The unified-diff token count measures a reproducible textual patch; it does not measure what an editor or model would have to generate to apply the revision.

The semantic content and responsive requirement match, but the rendered defaults are not pixel-identical; this is not a visual-fidelity benchmark. Coordinator browser UAT verified the three initial dashboards and all three revised dashboards at desktop and 390px: revised outputs showed `Work / Owner / Due / Status`, `ACTION NEEDED`, and no page overflow.

This is one deliberately small constructed fixture. It does not establish that one approach is generally smaller or better. Broader conclusions require multiple independently selected fixtures and a predeclared aggregation method.
