#!/usr/bin/env bash
# GC-LAZYSLICE-001: long slices are lazy views that survive collections (see fixture).
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"
runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: __JS_ENGINE_GC / --gc requires js_engine)"
    regression_finish_test_case "regression/gc/test_gc_lazy_slices.sh"
fi
exit_code=0
out=$("$JAC_JS_RUNNER" --gc "$dir/gc_lazy_slices.fixture.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "GC-LAZYSLICE-001 (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "GC-LAZYSLICE-001: $out"
fi
regression_finish_test_case "regression/gc/test_gc_lazy_slices.sh"
