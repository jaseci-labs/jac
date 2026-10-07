#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE="$(cd "$(dirname "${1:-$ROOT/bin/js_engine}")" && pwd)/$(basename "${1:-$ROOT/bin/js_engine}")"
NAPI_INC="${NAPI_INC:-/usr/include/node}"
PER_TEST_TIMEOUT="${JAC_TEST_TIMEOUT:-60}"

if [[ ! -x "$ENGINE" ]]; then
    echo "ERROR: engine not found at $ENGINE  (run 'make all' first)" >&2
    exit 1
fi

TESTS=(
    01_math
    02_string
    03_counter
    04_vec3
    05_stats
    06_hash
    07_typecheck
    08_matrix
    09_promise
    10_registry
    11_tsfn
    12_tsfn_async
    13_rollup_audit
    14_binary
    15_async_work
)

TIME_BIN=""
if [[ -x /usr/bin/time ]]; then
    TIME_BIN="/usr/bin/time"
fi

fmt_mem() {
    local kb="$1"
    if [[ -z "$kb" || ! "$kb" =~ ^[0-9]+$ ]]; then echo "  -  "; return; fi
    if [[ $kb -ge 1048576 ]]; then echo "$(echo "scale=1; $kb/1048576" | bc)GB"
    elif [[ $kb -ge 1024 ]];  then echo "$(echo "scale=1; $kb/1024"    | bc)MB"
    else echo "${kb}KB"; fi
}

total=0
total_passed=0
total_failed=0
suite_failures=()
run_start=$(date +%s%3N)

for dir in "${TESTS[@]}"; do
    addon_c="$SCRIPT_DIR/$dir/addon.c"
    addon_node="$SCRIPT_DIR/$dir/addon.node"
    test_js="$SCRIPT_DIR/$dir/test.js"
    name="$dir/test.js"
    total=$((total + 1))

    # Build addon
    if ! cc -shared -fPIC -I"$NAPI_INC" -lm -o "$addon_node" "$addon_c" 2>/dev/null; then
        total_failed=$((total_failed + 1))
        suite_failures+=("$name")
        printf "FAIL  %-45s  (build error)\n" "$name"
        continue
    fi

    t_start=$(date +%s%3N)
    mem_file=""
    max_kb=""
    exit_code=0
    if [[ -n "$TIME_BIN" ]]; then
        mem_file="$(mktemp)"
        output="$("$TIME_BIN" -f '%M' -o "$mem_file" timeout "$PER_TEST_TIMEOUT" "$ENGINE" "$test_js" 2>&1)" || exit_code=$?
        max_kb="$(tr -d '[:space:]' < "$mem_file" 2>/dev/null || true)"
        rm -f "$mem_file"
    else
        output="$(timeout "$PER_TEST_TIMEOUT" "$ENGINE" "$test_js" 2>&1)" || exit_code=$?
    fi
    mem_fmt="$(fmt_mem "$max_kb")"

    if [[ -n "$max_kb" && "$max_kb" =~ ^[0-9]+$ ]]; then
        if [[ -z "${peak_kb:-}" ]] || [[ $max_kb -gt ${peak_kb:-0} ]]; then
            peak_kb=$max_kb; peak_name="$name"
        fi
    fi

    t_end=$(date +%s%3N)
    elapsed_ms=$(( t_end - t_start ))
    if [[ $elapsed_ms -ge 1000 ]]; then elapsed_fmt="$(echo "scale=2; $elapsed_ms/1000" | bc)s"
    else elapsed_fmt="${elapsed_ms}ms"; fi

    if [[ $exit_code -eq 124 ]]; then
        total_failed=$((total_failed + 1))
        suite_failures+=("$name")
        printf "TO    %-45s  %8s  %8s  (killed after ${PER_TEST_TIMEOUT}s)\n" "$name" "$elapsed_fmt" "$mem_fmt"
        continue
    fi

    # Count assert/assertClose/assertEq calls as a proxy for total assertions
    assert_count="$(grep -cE '\bassert[A-Za-z]*\(' "$test_js" 2>/dev/null || echo '?')"
    fail_lines="$(echo "$output" | grep -E "^FAIL[: ]" || true)"

    if [[ $exit_code -ne 0 || -n "$fail_lines" ]]; then
        total_failed=$((total_failed + 1))
        suite_failures+=("$name")
        printf "FAIL  %-45s  %8s  %8s\n" "$name" "$elapsed_fmt" "$mem_fmt"
        if [[ -n "$fail_lines" ]]; then
            echo "$fail_lines" | sed 's/^/      /'
        fi
        if [[ $exit_code -ne 0 && -z "$fail_lines" ]]; then
            echo "      (engine exited with code $exit_code)"
            echo "$output" | tail -5 | sed 's/^/      /'
        fi
    else
        total_passed=$((total_passed + 1))
        printf "ok    %-45s  %8s  %8s  %s tests passed\n" "$name" "$elapsed_fmt" "$mem_fmt" "$assert_count"
    fi
done

echo ""
echo "══════════════════════════════════════════════════"
run_end=$(date +%s%3N)
total_ms=$(( run_end - run_start ))
if [[ $total_ms -ge 1000 ]]; then total_time="$(echo "scale=2; $total_ms/1000" | bc)s"
else total_time="${total_ms}ms"; fi
echo "  Suites: $total total  |  $total_passed passed  |  $total_failed failed  |  ${total_time} total"
if [[ -n "${peak_kb:-}" ]]; then
    echo "  Peak memory: $(fmt_mem "$peak_kb")  (${peak_name})"
fi
echo "══════════════════════════════════════════════════"

if [[ ${#suite_failures[@]} -gt 0 ]]; then
    echo ""
    echo "Failed suites:"
    for s in "${suite_failures[@]}"; do echo "  • $s"; done
    exit 1
fi
