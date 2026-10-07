#!/usr/bin/env bash
# CON-001: console.log outputs to stdout
# CON-002/CON-003: console.error/warn/info/debug output
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"
stdout=$(mktemp); stderr=$(mktemp)
trap 'rm -f "$stdout" "$stderr"' EXIT

# CON-001: console.log produces output on stdout
exit_code=0
"$JAC_JS_RUNNER" "$dir/test_console_log.fixture.js" >"$stdout" 2>"$stderr" || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "CON-001: fixture exited $exit_code"
fi
if ! grep -q "hello" "$stdout"; then
    regression_record_fail "CON-001: 'hello' not in stdout"
fi
if ! grep -q "42" "$stdout"; then
    regression_record_fail "CON-001: '42' not in stdout"
fi
if ! grep -q "true" "$stdout"; then
    regression_record_fail "CON-001: 'true' not in stdout"
fi
# Multiple args "a" "b" "c" — should all appear in stdout
if ! grep -q "a" "$stdout" || ! grep -q "b" "$stdout" || ! grep -q "c" "$stdout"; then
    regression_record_fail "CON-001: multi-arg log missing from stdout"
fi

# CON-002/CON-003: console.error/warn go to stderr; info/debug may go to stdout or stderr
exit_code=0
"$JAC_JS_RUNNER" "$dir/test_console_stderr.fixture.js" >"$stdout" 2>"$stderr" || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "CON-002: fixture exited $exit_code"
fi
# error message should appear somewhere (stderr or stdout depending on engine)
combined=$(cat "$stdout" "$stderr")
if ! echo "$combined" | grep -q "error message"; then
    regression_record_fail "CON-002: 'error message' not in output"
fi
if ! echo "$combined" | grep -q "warn message"; then
    regression_record_fail "CON-002: 'warn message' not in output"
fi
if ! echo "$combined" | grep -q "info message"; then
    regression_record_fail "CON-003: 'info message' not in output"
fi
if ! echo "$combined" | grep -q "debug message"; then
    regression_record_fail "CON-003: 'debug message' not in output"
fi

regression_finish_test_case "regression/03_builtins/17_console/test_console_output.sh"
