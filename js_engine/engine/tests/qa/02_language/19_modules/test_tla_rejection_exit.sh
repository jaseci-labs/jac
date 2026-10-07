#!/usr/bin/env bash
# TLA-REJ-001..002: a top-level `await` that rejects in the entry module prints
# the error and exits 1 (Node). Regression: the resumed module frame has no
# result promise, so the rejection was dropped — the process printed nothing and
# exited 0, hiding every failed `await import(...)` in an ESM entry.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../../_harness/regression_case_sh.sh"

suite="regression/02_language/19_modules/test_tla_rejection_exit.sh"

for fx in mod_tla_reject.fixture.mjs mod_tla_reject_settled.fixture.mjs; do
    exit_code=0
    out=$("$JAC_JS_RUNNER" "$dir/$fx" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 1 ]]; then
        regression_record_fail "$fx: exit $exit_code, expected 1: $out"
    fi
    if [[ "$out" != *"tla-boom"* ]]; then
        regression_record_fail "$fx: error not reported: $out"
    fi
    if [[ "$out" == *"tla-after"* ]]; then
        regression_record_fail "$fx: code after the rejected await ran: $out"
    fi
done

regression_finish_test_case "$suite"
