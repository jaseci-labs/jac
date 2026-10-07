#!/usr/bin/env bash
# VIT-CLI-004: Phase 0 — vite dev on minimal fixture (baseline signature)
set -uo pipefail

dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"
# shellcheck disable=SC1091
source "$dir/_vite_cli_lib.sh"

trap 'vite_cli_cleanup_temp' EXIT

if ! vite_cli_skip_unless_configured "VIT-CLI-dev-smoke"; then
  regression_finish_test_case "regression/05_integration/test_vite_cli_dev_smoke.sh"
fi

VITE_CLI_TIMEOUT_SEC="${VITE_CLI_TIMEOUT_SEC:-60}"

fixture=$(vite_cli_minimal_fixture_dir)
VITE_DEV_PORT=55173

if [[ ! -f "${fixture}/vite.config.js" ]]; then
  regression_record_fail "VIT-CLI-004: minimal fixture missing at ${fixture}"
else
  vite_cli_run "$fixture" dev --port "$VITE_DEV_PORT" --host 127.0.0.1 --strictPort
  vite_cli_assert_phase0_baseline "VIT-CLI-004: dev"
fi

if [[ "$__REGRESSION_FAILURES" -gt 0 ]]; then
  echo "--- stdout (${VITE_CLI_LAST_STDOUT_BYTES:-?} bytes) ---"
  cat "${VITE_CLI_LAST_STDOUT_FILE:-/dev/null}" 2>/dev/null || true
  echo "--- stderr (${VITE_CLI_LAST_STDERR_BYTES:-?} bytes) ---"
  cat "${VITE_CLI_LAST_STDERR_FILE:-/dev/null}" 2>/dev/null || true
fi

regression_finish_test_case "regression/05_integration/test_vite_cli_dev_smoke.sh"
