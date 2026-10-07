#!/usr/bin/env bash
# MOD-CJSENTRY-001: an entry `.cjs` file runs as CommonJS even when the nearest
# package.json says "type": "module" (Node: the .cjs extension always wins).
# Regression: the entry-format check consulted the package type before the
# extension, so `js_engine x.cjs` in a Vite/ESM project threw "require is not
# defined in ES module scope".
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"

suite="regression/02_language/19_modules/test_cjs_entry_in_type_module.sh"

exit_code=0
out=$("$JAC_JS_RUNNER" "$dir/fixtures_cjs_entry_type_module/entry.cjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail ".cjs entry in a type:module package failed (exit $exit_code): $out"
elif [[ "$out" != *"CJS-ENTRY function,object,object,string"* ]]; then
    regression_record_fail ".cjs entry did not get the CommonJS bindings: $out"
fi

regression_finish_test_case "$suite"
