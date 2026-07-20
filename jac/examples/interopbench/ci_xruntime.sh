#!/usr/bin/env bash
# Fast differential-identity gate for family 2 (cross-runtime): all enabled
# xop_* cells at small sizes with one invocation per variant. Requires node on
# PATH for client/wasm adapters; loopback providers only.
set -euo pipefail
cd "$(dirname "$0")"

jac run harness/xbench.jac \
  --kernels xop_svc_split,xop_feed,xop_wasm_call \
  --sizes small \
  --invocations 1 \
  --quick \
  --out /tmp/interop_xruntime_ci.json

echo "interopbench cross-runtime identity gate passed"
