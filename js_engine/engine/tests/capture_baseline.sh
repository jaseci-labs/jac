#!/usr/bin/env bash
# Capture regression baseline for js_engine refactoring safety net.
# Usage: bash engine/tests/capture_baseline.sh [output_dir]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/regression_logs/baseline_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT"
cd "$ROOT"

echo "Capturing baseline to $OUT"
echo "git=$(git rev-parse HEAD 2>/dev/null || echo unknown)" > "$OUT/meta.txt"
date -Iseconds >> "$OUT/meta.txt"

run_and_log() {
    local name="$1"
    shift
    echo "=== $name ===" | tee "$OUT/${name}.log"
  if "$@" >> "$OUT/${name}.log" 2>&1; then
        echo "PASS" >> "$OUT/${name}.status"
    else
        echo "FAIL (exit $?)" >> "$OUT/${name}.status"
    fi
}

make build >> "$OUT/build.log" 2>&1 || true
run_and_log test_unit make test_unit
run_and_log test make test
run_and_log test_node make test_node
run_and_log test_e2e make test_e2e
run_and_log test_napi make test_napi

if [ -f engine/tests/test262/run_test262.py ]; then
    run_and_log test262 python3 engine/tests/test262/run_test262.py --summary 2>/dev/null || \
        echo "test262 skipped (submodule or deps missing)" >> "$OUT/test262.status"
fi

echo "Baseline captured at $OUT"
ls -la "$OUT"
