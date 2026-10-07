#!/usr/bin/env bash
# Optional HTTP soak: JAC_HTTP_SOAK=1 JAC_HTTP_SOAK_COUNT=1000 ./run_http_soak.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="${JAC_ENGINE_ROOT:+$JAC_ENGINE_ROOT/bin/js_engine}"
ENGINE="${ENGINE:-$SCRIPT_DIR/../../bin/js_engine}"
COUNT="${JAC_HTTP_SOAK_COUNT:-1000}"
MAX_MS="${JAC_HTTP_SOAK_MAX_MS:-120000}"

if [[ ! -x "$ENGINE" ]]; then
  echo "ERROR: engine not found at $ENGINE" >&2
  exit 1
fi

export JAC_HTTP_PERF_TARGET="$COUNT"
export JAC_ENGINE_ROOT="${JAC_ENGINE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

echo "HTTP soak: $COUNT sequential keep-alive GETs (max ${MAX_MS}ms)"

t0=$(date +%s%3N)
out="$(timeout "$((MAX_MS / 1000 + 10))" "$ENGINE" \
  "$SCRIPT_DIR/../qa/04_node_modules/19_http/test_http_perf_smoke.js" 2>&1)" || ec=$?
elapsed=$(( $(date +%s%3N) - t0 ))
echo "$out"
echo "elapsed_ms=$elapsed"

if [[ "${ec:-0}" -ne 0 ]]; then
  echo "SOAK FAIL: exit ${ec:-?}" >&2
  exit 1
fi
if ! echo "$out" | grep -q 'failures=0'; then
  echo "SOAK FAIL: harness reported failures" >&2
  exit 1
fi
echo "SOAK OK"
