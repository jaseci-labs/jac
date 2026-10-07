#!/usr/bin/env bash
# TLA-SEQ-001..005: sequential top-level `await import()` of distinct uncached
# modules must not crash. Regression for the frame-pool locals-aliasing bug
# (see test_tla_sequential_import.fixture.mjs + docs/VITE_BLOCKER_SEQUENTIAL_TLA_IMPORT.md).
# Standalone wrapper so run_reg.jac discovers this as an independent suite; the
# ESM entry (.fixture.mjs, not itself discovered) needs the .mjs runner path.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"

suite="regression/02_language/19_modules/test_tla_sequential_import.sh"

runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    # Node runs the same .mjs identically; keep it in the Node lane too so the
    # expected behaviour stays pinned to real Node semantics.
    :
fi

exit_code=0
out=$("$JAC_JS_RUNNER" "$dir/test_tla_sequential_import.fixture.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "sequential top-level await import() crashed (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "sequential top-level await import() wrong result: $out"
elif [[ "$out" != *"TLA-SEQ OK"* ]]; then
    regression_record_fail "sequential top-level await import() did not complete: $out"
fi

regression_finish_test_case "$suite"
