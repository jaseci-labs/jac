#!/usr/bin/env bash
set -uo pipefail

# Pins the engine's feature-gate defaults (docs/VM_REARCH_PLAN.md V0.5).
# Commit 72df095 rewrote `getenv(X) != "0"` as `getenv(X) != None` and so
# silently turned six default-on gates off: shapes, dense elements, both
# bytecode-optimizer gates, inline calls and property ICs. Nothing failed, the
# engine just ran 1.5x slower. `js_engine --feature-gates` prints each gate's
# live state after the same init a script run does; this checks that every
# gate is on with its variable unset, empty or "1", and that "0" turns off
# only that gate.
: "${JAC_JS_RUNNER:=bin/js_engine}"

dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck disable=SC1091
source "$dir/../_harness/regression_case_sh.sh"

runner_name=$(basename "$JAC_JS_RUNNER")
if [[ "$runner_name" == "node" ]]; then
    echo "Test passed (skipped: --feature-gates is a js_engine engine flag)"
    regression_finish_test_case "regression/cli/test_feature_gate_defaults.sh"
fi

GATES=(JS_SHAPES JS_DENSE JS_BCOPT JS_BCOPT_P3 JS_INLINE_CALLS JS_IC JS_REG_ISA)

unset_all=()
for g in "${GATES[@]}"; do unset_all+=(-u "$g"); done

# Expected report with every gate on except `off` (empty: none off).
expected() {
    local off="$1" g
    for g in "${GATES[@]}"; do
        if [[ "$g" == "$off" ]]; then echo "$g=0"; else echo "$g=1"; fi
    done
}

# check <label> <gate expected off, or ""> [VAR=value...]
check() {
    local label="$1" off="$2"
    shift 2
    local out exit_code=0
    out=$(env "${unset_all[@]}" "$@" "$JAC_JS_RUNNER" --feature-gates 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        regression_record_fail "$label: --feature-gates exited $exit_code: $out"
        return
    fi
    local want
    want=$(expected "$off")
    if [[ "$out" != "$want" ]]; then
        regression_record_fail "$label: expected
$want
got
$out"
    fi
}

check "defaults (all gate variables unset)" ""
for g in "${GATES[@]}"; do
    check "$g=0 turns only $g off" "$g" "$g=0"
    check "$g= (empty) keeps $g on" "" "$g="
    check "$g=1 keeps $g on" "" "$g=1"
done

regression_finish_test_case "regression/cli/test_feature_gate_defaults.sh"
