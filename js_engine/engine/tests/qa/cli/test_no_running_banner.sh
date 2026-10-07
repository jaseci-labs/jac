#!/usr/bin/env bash
set -uo pipefail

# Asserts js_engine does not write the "Running: …" banner to stdout (see issues/cli/issue-running-banner-default.md).
: "${JAC_JS_RUNNER:=bin/js_engine}"

dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"
stdout=$(mktemp)
stderr=$(mktemp)
trap 'rm -f "$stdout" "$stderr"' EXIT

exit_code=0
"$JAC_JS_RUNNER" "$dir/test_no_running_banner.fixture.js" >"$stdout" 2>"$stderr" || exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "expected exit code 0, got $exit_code"
fi

first_line=$(head -n 1 "$stdout" | tr -d '\r')
if [[ "$first_line" == Running:* ]]; then
    regression_record_fail "first line of stdout must not be the engine 'Running:' banner"
fi

if ! grep -q "JAC_NO_BANNER_OK" "$stdout"; then
    regression_record_fail "expected script output (JAC_NO_BANNER_OK) on stdout"
fi

if [[ $__REGRESSION_FAILURES -gt 0 ]]; then
    echo "--- stdout ---"
    cat "$stdout"
    echo "--- stderr ---"
    cat "$stderr"
fi

regression_finish_test_case "regression/cli/test_no_running_banner.sh"
