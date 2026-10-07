#!/usr/bin/env bash
# GC-PKG-001: package.json "exports" resolution must survive collections
# (_PKG_JSON_CACHE values must be pinned). Regression: unpinned parsed
# package.json swept → subpath resolution against the cached object fails
# with "Cannot find module '<target>' in package" (vite@6 'vite/module-runner'
# --gc failure).
# Symlinks node_modules → _fixtures_node_modules (same pattern as
# 04_node_modules/22_packages) and forces the engine's --gc flag itself.
set -uo pipefail
: "${JAC_JS_RUNNER:=bin/js_engine}"
dir=$(dirname "${BASH_SOURCE[0]}")
here=$(cd "$dir" && pwd)
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"

runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: __JS_ENGINE_GC / --gc requires js_engine)"
    regression_finish_test_case "regression/gc/test_gc_pkg_resolve.sh"
fi

cleanup() {
    if [[ -L "$here/node_modules" ]]; then rm -f "$here/node_modules"; fi
}
trap cleanup EXIT
ln -sfn "$here/_fixtures_node_modules" "$here/node_modules"

exit_code=0
out=$("$JAC_JS_RUNNER" --gc "$dir/gc_pkg_resolve.fixture.mjs" 2>&1) || exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    regression_record_fail "GC-PKG-001 package exports cache swept by GC (exit $exit_code): $out"
elif [[ "$out" == *"FAIL:"* ]]; then
    regression_record_fail "GC-PKG-001: $out"
fi

regression_finish_test_case "regression/gc/test_gc_pkg_resolve.sh"
