#!/usr/bin/env bash
# Fast differential-identity gate for family 2 (cross-runtime): all enabled
# xop_* cells at small sizes with one invocation per variant. Requires node on
# PATH for client/wasm adapters; loopback providers only.
set -euo pipefail
cd "$(dirname "$0")"

if [[ "${1:-}" != "--experimental" ]]; then
  echo "cross-runtime cells are experimental; rerun as ./ci_xruntime.sh --experimental" >&2
  exit 2
fi
shift

jac run harness/xbench.jac \
    --experimental \
  --kernels xop_svc_split,xop_feed,xop_wasm_call \
  --sizes small \
  --invocations 1 \
  --quick \
  --out /tmp/interop_xruntime_ci.json

echo "interopbench cross-runtime identity gate passed"
