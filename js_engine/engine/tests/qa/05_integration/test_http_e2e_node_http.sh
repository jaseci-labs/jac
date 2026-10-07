#!/usr/bin/env bash
# E2E depth: engine/tests/e2e/test_node_http.js (58 checks, local only)
set -uo pipefail

dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"
# shellcheck disable=SC1091
source "$dir/../_harness/regression_runner.sh"

e2e_js="$(cd "$dir/../../e2e" && pwd)/test_node_http.js"
out_file="$(mktemp)"
if ! "$JAC_JS_RUNNER" "$e2e_js" >"$out_file" 2>&1; then
  regression_record_fail "test_node_http.js exit non-zero"
fi
if ! grep -q "0 failed" "$out_file"; then
  regression_record_fail "test_node_http.js reported failures"
fi
if ! grep -q "58 passed" "$out_file"; then
  regression_record_fail "test_node_http.js expected 58 passed"
fi
if [[ "$__REGRESSION_FAILURES" -gt 0 ]]; then
  tail -20 "$out_file" >&2
fi
rm -f "$out_file"

regression_finish_test_case "regression/05_integration/test_http_e2e_node_http.sh"
