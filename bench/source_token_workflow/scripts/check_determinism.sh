#!/usr/bin/env bash
set -euo pipefail

benchmark_dir=$(cd "$(dirname "$0")/.." && pwd)
python_bin="$benchmark_dir/.venv/bin/python"
first="$benchmark_dir/tmp/results-first.json"

mkdir -p "$benchmark_dir/tmp"
"$python_bin" "$benchmark_dir/scripts/measure.py" >/dev/null
cp -f "$benchmark_dir/results.json" "$first"
"$python_bin" "$benchmark_dir/scripts/measure.py" >/dev/null
cmp "$first" "$benchmark_dir/results.json"
echo "deterministic results: pass"
