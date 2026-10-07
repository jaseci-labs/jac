#!/usr/bin/env bash
# VIT-CLI-002: vite --help — full help text on stdout with real newlines
set -uo pipefail

dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"
# shellcheck disable=SC1091
source "$dir/_vite_cli_lib.sh"

trap 'vite_cli_cleanup_temp' EXIT

if ! vite_cli_skip_unless_configured "VIT-CLI-002"; then
  regression_finish_test_case "regression/05_integration/test_vite_cli_help_smoke.sh"
fi

VITE_CLI_TIMEOUT_SEC=30
vite_cli_run "${VITE_ROOT}" --help
vite_cli_assert_help_contract "VIT-CLI-002: --help"
if [[ "${VITE_CLI_LAST_TIMED_OUT:-0}" == "1" ]]; then
  regression_record_fail "VIT-CLI-002: timed out"
fi

if [[ "$__REGRESSION_FAILURES" -gt 0 ]]; then
  echo "--- stdout (${VITE_CLI_LAST_STDOUT_BYTES:-?} bytes) ---"
  cat "${VITE_CLI_LAST_STDOUT_FILE:-/dev/null}" 2>/dev/null || true
  echo "--- stderr (${VITE_CLI_LAST_STDERR_BYTES:-?} bytes) ---"
  cat "${VITE_CLI_LAST_STDERR_FILE:-/dev/null}" 2>/dev/null || true
fi

regression_finish_test_case "regression/05_integration/test_vite_cli_help_smoke.sh"
