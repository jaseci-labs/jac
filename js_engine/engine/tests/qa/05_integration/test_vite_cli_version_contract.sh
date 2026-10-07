#!/usr/bin/env bash
# VIT-CLI-001b: vite --version contract (stdout, semver, repeat, fast exit)
set -uo pipefail

dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"
# shellcheck disable=SC1091
source "$dir/_vite_cli_lib.sh"

trap 'vite_cli_cleanup_temp' EXIT

if ! vite_cli_skip_unless_configured "VIT-CLI-version-contract"; then
  regression_finish_test_case "regression/05_integration/test_vite_cli_version_contract.sh"
fi

VITE_CLI_TIMEOUT_SEC=30
vite_cli_run "${VITE_ROOT}" --version
vite_cli_assert_version_contract "VIT-CLI-001b: --version contract"
if [[ "${VITE_CLI_LAST_TIMED_OUT:-0}" == "1" ]]; then
  regression_record_fail "VIT-CLI-001b: timed out (unref timer may be broken)"
fi

vite_cli_run "${VITE_ROOT}" --version --version
vite_cli_assert_version_contract "VIT-CLI-001c: repeated --version"

vite_cli_run "${VITE_ROOT}" -d --version
vite_cli_assert_version_contract "VIT-CLI-001d: -d --version"

regression_finish_test_case "regression/05_integration/test_vite_cli_version_contract.sh"
