#!/usr/bin/env bash
# MOD-010 through MOD-015: ESM static imports/exports
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"

run_case() {
    local label="$1"
    local fixture="$2"
    local exit_code=0
    local out
    out=$("$JAC_JS_RUNNER" "$dir/$fixture" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        regression_record_fail "$label (exit $exit_code): $out"
    elif [[ "$out" == *"FAIL:"* ]]; then
        regression_record_fail "$label: $out"
    fi
}

run_case "MOD-010/MOD-012 named imports"      "test_esm_named.fixture.mjs"
run_case "MOD-011/MOD-012 default import"     "test_esm_default.fixture.mjs"
run_case "MOD-013 namespace import"           "test_esm_namespace.fixture.mjs"
run_case "MOD-015 dynamic import"             "test_esm_dynamic.fixture.mjs"

regression_finish_test_case "regression/02_language/19_modules/test_esm_modules.sh"
