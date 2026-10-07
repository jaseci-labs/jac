#!/usr/bin/env bash
# ESM-B-C5: assignment to an import binding must throw TypeError (§10.4.6).
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"

runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: import-binding assignment error test requires js_engine)"
    regression_finish_test_case "regression/02_language/19_modules/test_esm_import_assign_error.sh"
fi

exit_code=0
out=$("$JAC_JS_RUNNER" "$dir/test_esm_import_assign_error.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "ESM-B-C5 import binding assign error (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "ESM-B-C5 import binding assign error: $out"
fi

regression_finish_test_case "regression/02_language/19_modules/test_esm_import_assign_error.sh"
