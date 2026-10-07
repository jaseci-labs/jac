#!/usr/bin/env bash
# GC-NATIVE-001: a native builtin's in-flight values (map/filter result array,
# reduce accumulator, Array.from result) must survive a collection fired during
# a callback VM re-entry — they live in native locals invisible to the root
# walk (CallFrame.native_roots is the fix). Real-world: vite cac Option.names
# corruption → "reading 'split'" crash on jac-client app builds under --gc.
# Forces the engine's --gc flag itself.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"

runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: __JS_ENGINE_GC / --gc requires js_engine)"
    regression_finish_test_case "regression/gc/test_gc_native_inflight_roots.sh"
fi

exit_code=0
out=$("$JAC_JS_RUNNER" --gc "$dir/gc_native_inflight_roots.fixture.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "GC-NATIVE-001 native in-flight value swept by GC (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "GC-NATIVE-001: $out"
fi

regression_finish_test_case "regression/gc/test_gc_native_inflight_roots.sh"
