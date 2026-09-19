#!/usr/bin/env bash
set -euo pipefail

benchmark_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$benchmark_dir/../.." && pwd)
output_dir="$benchmark_dir/tmp/rendered"

mkdir -p "$output_dir"
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bundle exec ruby -I"$repo_dir/lib" "$benchmark_dir/implementations/streamweaver/render.rb" initial
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bundle exec ruby -I"$repo_dir/lib" "$benchmark_dir/implementations/streamweaver/render.rb" revised
bundle exec ruby "$benchmark_dir/implementations/plain/render.rb" initial
bundle exec ruby "$benchmark_dir/implementations/plain/render.rb" revised
cp -f "$benchmark_dir/shared/dashboard.css" "$output_dir/dashboard.css"
npm --prefix "$benchmark_dir" ci --ignore-scripts
npm --prefix "$benchmark_dir" run render
python3 "$benchmark_dir/scripts/verify_outputs.py"
