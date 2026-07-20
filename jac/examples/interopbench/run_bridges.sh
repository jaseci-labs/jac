#!/usr/bin/env bash
# One-command native-bridge experiment reproduction:
#   1. differential identity + manifest gate (small sizes)
#   2. measured runs, all enabled iop_* cells -> results/bridges_results.json
#   3. manifest/wrapper audit -> results/interop_audit.json
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1/3 differential identity and manifest gate =="
./ci_bridges.sh

echo "== 2/3 native-bridge measurement (30 invocations per cell) =="
jac run harness/measure.jac "$@"

echo "== 3/3 native interop audit =="
jac run harness/audit.jac

echo "native-bridge experiments complete: results/bridges_results.json, results/interop_audit.json"
