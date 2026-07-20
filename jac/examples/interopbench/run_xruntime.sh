#!/usr/bin/env bash
# One-command cross-runtime experiment reproduction:
# compiles wasm artifacts when needed, starts loopback providers per cell,
# runs the full differential + measurement matrix, and writes
# results/xruntime_results.json.
#
#   ./run_xruntime.sh            # full sizes, 30 invocations per cell
#   ./run_xruntime.sh --quick    # small sizes, fast sanity pass
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1/2 cross-runtime identity gate =="
./ci_xruntime.sh

echo "== 2/2 cross-runtime measurement =="
jac run harness/xbench.jac "$@"

echo "cross-runtime experiments complete: results/xruntime_results.json"
