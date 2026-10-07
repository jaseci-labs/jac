#!/usr/bin/env bash
# GC-GLOB-001: module top-level bindings in the VM globals map must be GC roots.
# Regression: gc_mark_roots skipped self.globals, so a self-referential
# top-level function's captured cell was swept mid-execution (vite@6 debug
# chunk → "Cannot read properties of undefined (reading 'useColors')").
# Forces the engine's --gc flag itself.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"

runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: __JS_ENGINE_GC / --gc requires js_engine)"
    regression_finish_test_case "regression/gc/test_gc_module_global_roots.sh"
fi

exit_code=0
out=$("$JAC_JS_RUNNER" --gc "$dir/gc_module_global_roots.fixture.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "GC-GLOB-001 module-global binding swept by GC (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "GC-GLOB-001: $out"
fi

regression_finish_test_case "regression/gc/test_gc_module_global_roots.sh"
