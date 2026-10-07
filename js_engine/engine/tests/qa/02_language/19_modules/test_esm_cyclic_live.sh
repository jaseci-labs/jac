#!/usr/bin/env bash
# ESM-C-003 / ESM-C-004b: bidirectional cyclic ESM with export-let live bindings.
# Standalone wrapper so run_reg.py discovers this as an independent suite.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"

runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: cyclic ESM live-binding test requires js_engine)"
    regression_finish_test_case "regression/02_language/19_modules/test_esm_cyclic_live.sh"
fi

exit_code=0
out=$("$JAC_JS_RUNNER" "$dir/test_esm_cyclic_live.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "ESM-C-003/004b cyclic live bindings (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "ESM-C-003/004b cyclic live bindings: $out"
fi

regression_finish_test_case "regression/02_language/19_modules/test_esm_cyclic_live.sh"
