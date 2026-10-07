#!/usr/bin/env bash
# GC-REENTRY-001..013: natives that re-enter the VM keep receiver/args/results
# rooted across a collection fired inside the callback (see the fixture).
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"
runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: __JS_ENGINE_GC / --gc requires js_engine)"
    regression_finish_test_case "regression/gc/test_gc_native_reentry_roots.sh"
fi
exit_code=0
out=$("$JAC_JS_RUNNER" --gc "$dir/gc_native_reentry_roots.fixture.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "GC-REENTRY native in-flight values swept (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "GC-REENTRY: $out"
fi
regression_finish_test_case "regression/gc/test_gc_native_reentry_roots.sh"
