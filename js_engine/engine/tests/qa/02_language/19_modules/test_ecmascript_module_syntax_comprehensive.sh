#!/usr/bin/env bash
# ECMASCRIPT_MODULE_SYNTAX_COMPREHENSIVE_TEST_PLAN.md — ESM-* (module syntax, TLA, dynamic import)
set -euo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_runner.sh"

run_mjs() {
    local label="$1"
    local file="$2"
    local exit_code=0
    local out
    out=$("$JAC_JS_RUNNER" "$dir/$file" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        regression_record_fail "$label (exit $exit_code): $out"
    elif [[ "$out" == *"FAIL:"* ]]; then
        regression_record_fail "$label: $out"
    fi
}

expect_parse_fail_mjs() {
    regression_expect_run_fail "$1" "$dir/$2"
}

expect_parse_fail_script() {
    regression_expect_run_fail "$1" "$dir/$2"
}

run_mjs "ESM comprehensive driver" "test_ecmascript_module_syntax_comprehensive_driver.mjs"
run_mjs "ESM-I-005 import hoisting order" "esm_syntax_i005_hoist_order.mjs"
run_mjs "ESM-C-003/004 cyclic live bindings" "test_esm_cyclic_live.mjs"

expect_parse_fail_mjs "ESM-X-005 duplicate export" "esm_syntax_invalid_dup_export.mjs"
expect_parse_fail_script "ESM-A-002 top-level await in script" "esm_syntax_invalid_nonmodule_await.fixture.cjs"

regression_finish_test_case "regression/02_language/19_modules/test_ecmascript_module_syntax_comprehensive.sh"
