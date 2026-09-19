import difflib
import hashlib
import json
from pathlib import Path

import tiktoken


TOKENIZER_VERSION = "0.11.0"
ENCODING_NAME = "cl100k_base"
root = Path(__file__).resolve().parents[1]
fixture = root / "fixture.json"
shared_css = root / "shared" / "dashboard.css"
measurement_files = [root / "requirements.txt", Path(__file__), root / "scripts" / "verify_outputs.py", root / "scripts" / "render_all.sh"]

implementations = {
    "streamweaver": {
        "initial": root / "implementations" / "streamweaver" / "initial.rb",
        "final": root / "implementations" / "streamweaver" / "revised.rb",
        "styles": [shared_css],
        "helpers": [],
        "harness": [root / "implementations" / "streamweaver" / "render.rb"],
        "dependencies": [root / "implementations" / "streamweaver" / "dependencies.txt"],
    },
    "plain_html_css": {
        "initial": root / "implementations" / "plain" / "initial.rb",
        "final": root / "implementations" / "plain" / "revised.rb",
        "styles": [shared_css],
        "helpers": [root / "implementations" / "plain" / "dashboard.erb"],
        "harness": [root / "implementations" / "plain" / "render.rb"],
        "dependencies": [root / "implementations" / "plain" / "dependencies.txt"],
    },
    "react": {
        "initial": root / "implementations" / "react" / "initial.jsx",
        "final": root / "implementations" / "react" / "revised.jsx",
        "styles": [shared_css],
        "helpers": [root / "implementations" / "react" / "components.jsx"],
        "harness": [root / "implementations" / "react" / "render.jsx"],
        "dependencies": [root / "package.json", root / "package-lock.json"],
    },
}


def content(path):
    return path.read_text(encoding="utf-8")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def token_count(encoding, paths):
    return sum(len(encoding.encode(content(path))) for path in paths)


def relative(path):
    return str(path.relative_to(root))


def manifest(paths):
    return [{"path": relative(path), "sha256": digest(path), "bytes": path.stat().st_size} for path in paths]


if tiktoken.__version__ != TOKENIZER_VERSION:
    raise SystemExit(f"expected tiktoken {TOKENIZER_VERSION}, got {tiktoken.__version__}")

encoding = tiktoken.get_encoding(ENCODING_NAME)
results = {
    "method": {
        "tokenizer": "tiktoken",
        "version": TOKENIZER_VERSION,
        "encoding": ENCODING_NAME,
        "counting": "UTF-8 source text including formatting and comments; each listed file tokenized separately and summed",
        "patch": "Python difflib unified_diff with stable benchmark-relative labels and three context lines",
    },
    "fixture": manifest([fixture]),
    "measurement_infrastructure": {
        "tokens": token_count(encoding, measurement_files),
        "inputs": manifest(measurement_files),
        "included_in_implementation_totals": False,
    },
    "implementations": {},
}

for name, config in implementations.items():
    initial = config["initial"]
    final = config["final"]
    stable = [fixture, *config["styles"], *config["helpers"], *config["harness"], *config["dependencies"]]
    initial_full = [initial, *stable]
    final_full = [final, *stable]
    patch = "".join(difflib.unified_diff(
        content(initial).splitlines(keepends=True),
        content(final).splitlines(keepends=True),
        fromfile=relative(initial),
        tofile=relative(final),
        n=3,
    ))
    counts = {
        "initial_app": token_count(encoding, [initial]),
        "shared_local_styles": token_count(encoding, config["styles"]),
        "reusable_helpers": token_count(encoding, config["helpers"]),
        "render_harness": token_count(encoding, config["harness"]),
        "dependency_records": token_count(encoding, config["dependencies"]),
        "fixture_spec": token_count(encoding, [fixture]),
        "initial_existing_project": token_count(encoding, [initial, fixture, *config["styles"], *config["helpers"]]),
        "initial_all_recorded": token_count(encoding, initial_full),
        "full_source_reread": token_count(encoding, initial_full),
        "revision_patch": len(encoding.encode(patch)),
        "final_app": token_count(encoding, [final]),
        "final_existing_project": token_count(encoding, [final, fixture, *config["styles"], *config["helpers"]]),
        "final_all_recorded": token_count(encoding, final_full),
    }
    results["implementations"][name] = {
        "counts": counts,
        "initial_inputs": manifest(initial_full),
        "final_inputs": manifest(final_full),
        "revision_patch_sha256": hashlib.sha256(patch.encode("utf-8")).hexdigest(),
        "revision_patch": patch,
    }

destination = root / "results.json"
destination.write_text(json.dumps(results, indent=2, sort_keys=True) + "\n", encoding="utf-8")

for name, data in results["implementations"].items():
    counts = data["counts"]
    print(f"{name}: initial={counts['initial_all_recorded']} patch={counts['revision_patch']} final={counts['final_all_recorded']}")
