#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/../../../bin/js_engine"
TESTS_DIR="$SCRIPT_DIR"
PER_TEST_TIMEOUT="${JAC_TEST_TIMEOUT:-60}"  # seconds per test (override via env)

if [[ ! -x "$ENGINE" ]]; then
    echo "ERROR: engine not found at $ENGINE  (run 'make all' first)" >&2
    exit 1
fi

# /usr/bin/time -v reports max RSS via %M (KB). Skip mem reporting if absent.
TIME_BIN=""
if [[ -x /usr/bin/time ]]; then
    TIME_BIN="/usr/bin/time"
fi

fmt_mem() {
    local kb="$1"
    if [[ -z "$kb" || ! "$kb" =~ ^[0-9]+$ ]]; then
        echo "  -  "
        return
    fi
    if [[ $kb -ge 1048576 ]]; then
        echo "$(echo "scale=1; $kb/1048576" | bc)GB"
    elif [[ $kb -ge 1024 ]]; then
        echo "$(echo "scale=1; $kb/1024" | bc)MB"
    else
        echo "${kb}KB"
    fi
}

# Optional filter: pass one or more test filenames (or substrings) as arguments.
#   bash run_tests.sh test_node_https.js          — run only that file
#   bash run_tests.sh https http                  — run files matching *https* or *http*
FILTERS=("$@")

total=0
total_passed=0
total_failed=0
suite_failures=()
run_start=$(date +%s%3N)

for f in "$TESTS_DIR"/test_*.js; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"

    # Apply filter if arguments were given
    if [[ ${#FILTERS[@]} -gt 0 ]]; then
        match=0
        for pat in "${FILTERS[@]}"; do
            if [[ "$name" == *"$pat"* ]]; then match=1; break; fi
        done
        [[ $match -eq 1 ]] || continue
    fi

    total=$((total + 1))

    t_start=$(date +%s%3N)
    mem_file=""
    max_kb=""
    exit_code=0
    if [[ -n "$TIME_BIN" ]]; then
        mem_file="$(mktemp)"
        output="$("$TIME_BIN" -f '%M' -o "$mem_file" timeout "$PER_TEST_TIMEOUT" "$ENGINE" "$f" 2>&1)" || exit_code=$?
        max_kb="$(tr -d '[:space:]' < "$mem_file" 2>/dev/null || true)"
        rm -f "$mem_file"
    else
        output="$(timeout "$PER_TEST_TIMEOUT" "$ENGINE" "$f" 2>&1)" || exit_code=$?
    fi
    mem_fmt="$(fmt_mem "$max_kb")"
    # Track peak across suite
    if [[ -n "$max_kb" && "$max_kb" =~ ^[0-9]+$ ]]; then
        if [[ -z "${peak_kb:-}" ]] || [[ $max_kb -gt ${peak_kb:-0} ]]; then
            peak_kb=$max_kb
            peak_name="$name"
        fi
    fi
    t_end=$(date +%s%3N)
    elapsed_ms=$(( t_end - t_start ))
    if [[ $elapsed_ms -ge 1000 ]]; then
        elapsed_fmt="$(echo "scale=2; $elapsed_ms/1000" | bc)s"
    else
        elapsed_fmt="${elapsed_ms}ms"
    fi

    # timeout(1) returns 124 when the child is killed
    if [[ $exit_code -eq 124 ]]; then
        total_failed=$((total_failed + 1))
        suite_failures+=("$name")
        printf "TO    %-45s  %8s  %8s  (killed after ${PER_TEST_TIMEOUT}s)\n" "$name" "$elapsed_fmt" "$mem_fmt"
        continue
    fi

    # Collect FAIL lines
    fail_lines="$(echo "$output" | grep -E "^FAIL[: ]" || true)"
    # Parse summary line: "=== Foo tests: N passed, M failed ==="
    summary="$(echo "$output" | grep -E "===.*passed.*failed" | tail -1 || true)"

    suite_failed=0
    if [[ -n "$summary" ]]; then
        suite_failed=$(echo "$summary" | grep -oE "[0-9]+ failed" | grep -oE "^[0-9]+" || echo 0)
    elif [[ $exit_code -ne 0 ]]; then
        suite_failed=1
    fi

    if [[ "$suite_failed" -gt 0 || $exit_code -ne 0 ]]; then
        total_failed=$((total_failed + 1))
        suite_failures+=("$name")
        printf "FAIL  %-45s  %8s  %8s\n" "$name" "$elapsed_fmt" "$mem_fmt"
        if [[ -n "$fail_lines" ]]; then
            echo "$fail_lines" | sed 's/^/      /'
        fi
        if [[ -n "$summary" ]]; then
            echo "      $summary"
        elif [[ $exit_code -ne 0 ]]; then
            echo "      (engine exited with code $exit_code)"
            echo "$output" | tail -5 | sed 's/^/      /'
        fi
    else
        total_passed=$((total_passed + 1))
        suite_passed=$(echo "$summary" | grep -oE "[0-9]+ passed" | grep -oE "^[0-9]+" || echo "?")
        printf "ok    %-45s  %8s  %8s  %s tests passed\n" "$name" "$elapsed_fmt" "$mem_fmt" "$suite_passed"
    fi
done

echo ""
echo "══════════════════════════════════════════════════"
run_end=$(date +%s%3N)
total_ms=$(( run_end - run_start ))
if [[ $total_ms -ge 1000 ]]; then
    total_time="$(echo "scale=2; $total_ms/1000" | bc)s"
else
    total_time="${total_ms}ms"
fi
echo "  Suites: $total total  |  $total_passed passed  |  $total_failed failed  |  ${total_time} total"
if [[ -n "${peak_kb:-}" ]]; then
    echo "  Peak memory: $(fmt_mem "$peak_kb")  (${peak_name})"
fi
echo "══════════════════════════════════════════════════"

if [[ ${#suite_failures[@]} -gt 0 ]]; then
    echo ""
    echo "Failed suites:"
    for s in "${suite_failures[@]}"; do
        echo "  • $s"
    done
    exit 1
fi
