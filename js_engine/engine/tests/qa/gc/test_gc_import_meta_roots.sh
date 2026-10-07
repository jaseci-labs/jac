#!/usr/bin/env bash
# GC-META-001: import.meta must survive collections (realm.import_meta_cache
# is a GC root). Regression: unrooted cache → live meta object swept →
# import.meta.url read back as undefined (vite@6 constants.js crash).
# Forces the engine's --gc flag itself so this is a real GC test even in the
# default (non---gc) QA run.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"

runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: __JS_ENGINE_GC / --gc requires js_engine)"
    regression_finish_test_case "regression/gc/test_gc_import_meta_roots.sh"
fi

exit_code=0
out=$("$JAC_JS_RUNNER" --gc "$dir/gc_import_meta.fixture.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "GC-META-001 import.meta swept by GC (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "GC-META-001: $out"
fi

regression_finish_test_case "regression/gc/test_gc_import_meta_roots.sh"
