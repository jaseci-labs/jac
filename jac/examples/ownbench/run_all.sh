#!/usr/bin/env bash
# One-command ownbench reproduction:
#   1. differential identity + erasure gate (small sizes)
#   2. measured runs, all kernels x all modes -> results/results.json
#   3. IR audit -> results/ir_audit.json
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1/3 differential identity + erasure gate =="
./ci_identity.sh

echo "== 2/3 measurement (10 invocations per cell) =="
jac run harness/measure.jac --skip-compile "$@"

echo "== 3/3 IR audit =="
jac run harness/audit.jac

echo "ownbench complete: results/results.json, results/ir_audit.json"
