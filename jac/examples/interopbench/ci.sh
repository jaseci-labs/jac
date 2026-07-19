#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

result=$(mktemp)
audit=$(mktemp)
trap 'rm -f "$result" "$audit"' EXIT

jac run harness/measure.jac \
  --kernels iop_call,iop_cb \
  --variants free,bridge \
  --sizes small \
  --invocations 1 \
  --out "$result"

for size in empty one small; do
  jac run harness/measure.jac \
    --kernels iop_view \
    --variants materialised,view \
    --sizes "$size" \
    --invocations 1 \
    --out "$result"
done

jac run harness/audit.jac \
  --kernels iop_call,iop_cb \
  --out "$audit"

echo "interopbench Phase 3 identity, native-view, and manifest gates passed"
