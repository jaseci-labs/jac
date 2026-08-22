#!/usr/bin/env bash
# One-command ownership-experiment reproduction (gradual_ownership paper):
#   1. differential identity + erasure gate (small sizes)
#   2. measured runs, all own_* kernels x all three gc modes -> results/results.json
#   3. IR audit -> results/ir_audit.json
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1/3 differential identity + erasure gate =="
./ci_own.sh

echo "== 2/3 measurement (10 invocations per cell) =="
jac run harness/measure.jac --skip-compile "$@"

echo "== 3/3 IR audit =="
jac run harness/audit.jac

echo "ownership experiments complete: results/results.json, results/ir_audit.json"
