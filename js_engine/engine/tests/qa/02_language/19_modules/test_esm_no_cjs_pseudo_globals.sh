#!/usr/bin/env bash
# testing_plans/04_node_globals/NODE_COMMONJS_PSEUDO_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NCJS-CTX-* (run .mjs entry)
set -euo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"
set +e
"$JAC_JS_RUNNER" "$dir/test_esm_no_cjs_pseudo_globals.mjs"
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  regression_record_fail "NCJS-CTX-*: ESM entry exited with code $ec"
fi
regression_finish_test_case "regression/02_language/19_modules/test_esm_no_cjs_pseudo_globals.sh"
