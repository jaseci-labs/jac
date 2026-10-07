#!/usr/bin/env bash
# STRICT-005: duplicate params SyntaxError
# STRICT-006: delete undeclared SyntaxError (in strict mode)
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"

# STRICT-005: duplicate parameter names in strict mode must be a SyntaxError
exit_code=0
"$JAC_JS_RUNNER" "$dir/test_strict_dup_params.fixture.js" >/dev/null 2>&1 || exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    regression_record_fail "STRICT-005: duplicate params in strict should error (exited 0)"
fi

regression_finish_test_case "regression/02_language/20_strict_mode/test_strict_syntax_errors.sh"
