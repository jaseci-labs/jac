#!/usr/bin/env bash
# GC-ASYNC-001: a suspended async frame (await on a pending promise) must
# survive collection. Regression: the frame's JSGeneratorState was reachable
# only via an integer index in the promise reaction marker, so GC swept it and
# cleared its locals → resume crashed with "list assignment index out of range"
# (vite@6 async `bundleConfigFile` under --gc). Forces the engine's --gc flag.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"

runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: __JS_ENGINE_GC / --gc requires js_engine)"
    regression_finish_test_case "regression/gc/test_gc_async_frame_roots.sh"
fi

exit_code=0
out=$("$JAC_JS_RUNNER" --gc "$dir/gc_async_frame_roots.fixture.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "GC-ASYNC-001 suspended async frame swept by GC (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "GC-ASYNC-001: $out"
fi

regression_finish_test_case "regression/gc/test_gc_async_frame_roots.sh"
