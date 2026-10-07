#!/usr/bin/env bash
# SCOPE_COMPREHENSIVE_TEST_PLAN §13 — ESM scope, import hoisting, dynamic import
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

# Duplicate binding: must not parse / run successfully
regression_expect_run_fail "SCP-M-003: duplicate import+const" "$dir/test_scope_esm_dup.mjs"

run_mjs "SCP-M-002 import hoisting" "test_scope_esm_hoist.mjs"
run_mjs "SCP-M-004 dynamic import" "test_scope_esm_dynamic.mjs"

regression_finish_test_case "regression/02_language/02_scope/test_scope_modules.sh"
