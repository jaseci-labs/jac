#!/usr/bin/env bash
# VIT-CLI-002b: vite --help contract (sections, newlines, -h alias)
set -uo pipefail

dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"
# shellcheck disable=SC1091
source "$dir/_vite_cli_lib.sh"

trap 'vite_cli_cleanup_temp' EXIT

if ! vite_cli_skip_unless_configured "VIT-CLI-help-contract"; then
  regression_finish_test_case "regression/05_integration/test_vite_cli_help_contract.sh"
fi

VITE_CLI_TIMEOUT_SEC=30
vite_cli_run "${VITE_ROOT}" --help
vite_cli_assert_help_contract "VIT-CLI-002b: --help"

vite_cli_run "${VITE_ROOT}" -h
vite_cli_assert_help_contract "VIT-CLI-002c: -h alias"

regression_finish_test_case "regression/05_integration/test_vite_cli_help_contract.sh"
