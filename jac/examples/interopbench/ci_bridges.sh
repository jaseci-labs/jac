#!/usr/bin/env bash
# Fast differential-identity gate for family 1 (native bridges): every enabled
# mixed-JIT scalar cell and the symmetric sv↔na pair. Byte-identical canonical
# digests across each oracle group, plus named manifest/wrapper facts for
# audited cells. Timing values never gate CI.
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

jac run harness/measure.jac \
  --kernels iop_symmetric \
  --variants sv_local,sv_to_na,na_local,na_to_sv \
  --sizes small \
  --invocations 1 \
  --out "$result"

jac run harness/audit.jac \
  --kernels iop_call,iop_cb,iop_symmetric \
  --out "$audit"

echo "interopbench native-bridge identity and manifest gates passed"
