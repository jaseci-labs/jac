#!/usr/bin/env bash
# LET-004: let redeclaration in same scope must throw SyntaxError (parse-time error)
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"

# Case 1: same-scope redeclaration must fail (non-zero exit)
exit_code=0
"$JAC_JS_RUNNER" "$dir/test_let_redeclaration.fixture.js" >/dev/null 2>&1 || exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    regression_record_fail "LET-004: same-scope let redeclaration should produce an error (exited 0)"
fi

regression_finish_test_case "regression/02_language/01_variables/test_let_redeclaration.sh"
