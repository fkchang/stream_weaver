# Source-token workflow benchmark

This directory contains one constructed dashboard implemented three ways. It measures source size with one tokenizer; it does not measure model performance.

## Reproduce

```bash
cd bench/source_token_workflow
uv venv .venv
uv pip install --python .venv/bin/python -r requirements.txt
./scripts/render_all.sh
.venv/bin/python scripts/measure.py
git diff --exit-code results.json
```

Serve the ignored rendered fixtures from one local server:

```bash
python3 -m http.server 4581 --directory tmp/rendered
```

Open `http://127.0.0.1:4581/streamweaver-initial.html`, `plain-initial.html`, or `react-initial.html`; replace `initial` with `revised` for the fixed revision.
