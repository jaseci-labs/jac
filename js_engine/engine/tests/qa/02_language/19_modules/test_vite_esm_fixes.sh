#!/usr/bin/env bash
# Vite-related ESM regressions found while making `vite build` run on js_engine:
#   - import shadowing (param/local shadows a same-named ESM import)
#   - relative dynamic import() + import.meta.url resolve vs the importing module
#   - Function.prototype.toString of a fn in an ESM module is real source
#   - named imports from a CJS module whose exports are enumerable getters
#   - renamed re-export from a CJS module (export { x as y } from './cjs')
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

run_mjs "MOD-ISH-001 import shadowing" "test_esm_import_shadowing.mjs"
run_mjs "MOD-DYNREF-001 dynamic import referrer" "test_esm_dynamic_import_referrer.mjs"
run_mjs "MOD-FNSRC-001 ESM function toString" "test_esm_function_tostring.mjs"
run_mjs "MOD-CJSGET-001 CJS getter named imports" "test_esm_cjs_getter_exports.mjs"
run_mjs "MOD-CJSREEXP-001 renamed re-export from CJS" "test_esm_cjs_reexport_rename.mjs"

regression_finish_test_case "regression/02_language/19_modules/test_vite_esm_fixes.sh"
