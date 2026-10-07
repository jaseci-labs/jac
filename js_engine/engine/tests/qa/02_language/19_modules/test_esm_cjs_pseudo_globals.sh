#!/usr/bin/env bash
# EPG: CJS pseudo-global names (require/module/exports/__dirname/__filename) in
# ES module scope — a DECLARED module-level `var` of one of those names must
# resolve (Rollup inlines package.json as `var exports = {…}`), while UNBOUND
# references keep the helpful "not defined in ES module scope" ReferenceError
# and `typeof` stays tolerant. Regression for the guard in _op_load_global.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"

suite="regression/02_language/19_modules/test_esm_cjs_pseudo_globals.sh"

check() {
    local label=$1 file=$2 okmark=$3
    local exit_code=0 out
    out=$("$JAC_JS_RUNNER" "$dir/$file" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        regression_record_fail "$label crashed (exit $exit_code): $out"
    elif [[ "$out" == *"FAIL:"* ]]; then
        regression_record_fail "$label: $out"
    elif [[ "$out" != *"$okmark"* ]]; then
        regression_record_fail "$label did not complete: $out"
    fi
}

check "EPG-declared" esm_pseudo_declared.fixture.mjs "EPG-DECLARED OK"
check "EPG-unbound"  esm_pseudo_unbound.fixture.mjs  "EPG-UNBOUND OK"

regression_finish_test_case "$suite"
