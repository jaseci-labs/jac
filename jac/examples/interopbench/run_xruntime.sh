#!/usr/bin/env bash
# One-command cross-runtime experiment reproduction:
# compiles wasm artifacts when needed, starts loopback providers per cell,
# runs the full differential + measurement matrix, and writes
# results/xruntime_results.json.
#
#   ./run_xruntime.sh --experimental            # full sizes, 30 invocations per cell
#   ./run_xruntime.sh --experimental --quick    # small sizes, fast sanity pass
set -euo pipefail
cd "$(dirname "$0")"

if [[ "${1:-}" != "--experimental" ]]; then
  echo "cross-runtime cells are experimental; rerun as ./run_xruntime.sh --experimental" >&2
  exit 2
fi
shift

extra_args=(--experimental)
extra_args+=("$@")

echo "== 1/2 cross-runtime identity gate =="
./ci_xruntime.sh --experimental

echo "== 2/2 cross-runtime measurement =="
jac run harness/xbench.jac "${extra_args[@]}"

echo "cross-runtime experiments complete: results/xruntime_results.json"
