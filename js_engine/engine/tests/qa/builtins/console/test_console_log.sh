#!/usr/bin/env bash
set -uo pipefail

# Asserts console.log uses stdout so shell capture sees it
# (see issues/issue-console-log-stdout.md).
: "${JAC_JS_RUNNER:=bin/js_engine}"

dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"
exit_code=0
output=$("$JAC_JS_RUNNER" "$dir/test_console_log.fixture.js" 2>&1) || exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "expected engine exit code 0, got $exit_code"
fi

if [[ "$output" != *"JAC_CONSOLE_STDIO_LOG"* ]]; then
    regression_record_fail "expected captured stdout/stderr to contain JAC_CONSOLE_STDIO_LOG (console.log via stdio)"
fi

if [[ $__REGRESSION_FAILURES -gt 0 ]]; then
    echo "--- captured output ---"
    echo "$output"
fi

regression_finish_test_case "regression/builtins/console/test_console_log.sh"
