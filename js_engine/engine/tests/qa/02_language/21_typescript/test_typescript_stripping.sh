#!/usr/bin/env bash
# TS-001 through TS-009: TypeScript syntax stripping (js_engine runtime feature).
# Criteria: stripped fixture runs successfully under the selected regression runner.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_runner.sh"

fixture="$dir/test_typescript_stripping.fixture.js"
if [[ "$(regression_runner_name)" == "node" ]]; then
    # Node v20: no built-in TS strip; use the stripped runtime baseline (same assertions).
    fixture="$dir/test_typescript_stripping.runtime.fixture.js"
fi

exit_code=0
out=$("$JAC_JS_RUNNER" "$fixture" 2>&1) || exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    echo "$out"
    regression_record_fail "TypeScript stripping fixture exited $exit_code"
elif [[ "$out" == *"FAIL:"* ]]; then
    echo "$out"
    regression_record_fail "TypeScript stripping fixture reported FAIL in output"
fi

regression_finish_test_case "regression/02_language/21_typescript/test_typescript_stripping.sh"
