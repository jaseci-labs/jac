#!/usr/bin/env bash
# GC-TMPL-001: tagged-template site arrays must survive collections
# (realm.template_cache is a GC root). Regression class: unrooted cache →
# frozen strings array swept between evaluations → identity/content broken.
# Forces the engine's --gc flag itself.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"

runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: __JS_ENGINE_GC / --gc requires js_engine)"
    regression_finish_test_case "regression/gc/test_gc_template_cache.sh"
fi

exit_code=0
out=$("$JAC_JS_RUNNER" --gc "$dir/gc_template_cache.fixture.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "GC-TMPL-001 template site array swept by GC (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "GC-TMPL-001: $out"
fi

regression_finish_test_case "regression/gc/test_gc_template_cache.sh"
