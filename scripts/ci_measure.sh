#!/usr/bin/env bash
# Lightweight GNU-time accounting, usable before the Jac binary exists.
set -euo pipefail
mode=$1
shift
case "$mode" in
  record)
    phase=$1
    shift
    # Other setup-jac consumers, including macOS, are not instrumented.
    if [ -z "${JAC_CI_MEASURE_DIR:-}" ]; then exec "$@"; fi
    [[ "$phase" =~ ^[a-z][a-z0-9-]*$ ]]
    mkdir -p "$JAC_CI_MEASURE_DIR"
    exec env LC_ALL=C /usr/bin/time --quiet \
      -o "$JAC_CI_MEASURE_DIR/$phase.time.json" \
      -f '{"wall_seconds":%e,"user_seconds":%U,"system_seconds":%S,"rss_kib":%M,"exit_code":%x}' \
      "$@"
    ;;
  report)
    mkdir -p "$JAC_CI_MEASURE_DIR"
    shopt -s nullglob
    files=("$JAC_CI_MEASURE_DIR/"*.time.json)
    script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    budget_file=${JAC_CI_MEASURE_BUDGETS:-$script_dir/../.github/ci-performance-budgets.json}
    normalized=()
    summary="$JAC_CI_MEASURE_DIR/summary.md"
    {
      echo "## ${GITHUB_JOB:-CI} performance"
      echo
      echo 'RSS is the largest process peak, not total concurrent memory. Only calibrated phases and cache states enforce fixed limits.'
      echo
      echo '| Phase | Wall (s) | CPU (s) | Peak RSS (MiB) | Exit | Mode | Limits (s / MiB) | Result |'
      echo '| --- | ---: | ---: | ---: | ---: | --- | --- | --- |'
    } > "$summary"
    for file in "${files[@]}"; do
      phase=${file##*/}
      phase=${phase%.time.json}
      jq --arg phase "$phase" --arg commit "${GITHUB_SHA:-}" \
        --arg run_id "${GITHUB_RUN_ID:-}" --arg attempt "${GITHUB_RUN_ATTEMPT:-}" \
        --arg runner "${RUNNER_NAME:-}" --arg job "${GITHUB_JOB:-}" \
        --slurpfile context "$JAC_CI_MEASURE_DIR/context.json" \
        'if all([.wall_seconds, .user_seconds, .system_seconds, .rss_kib, .exit_code][];
                type == "number" and . >= 0) then
         {phase:$phase, commit:$commit, run_id:$run_id, run_attempt:$attempt,
          runner:$runner, job:$job, mode:"report", context:$context[0],
          wall_seconds:.wall_seconds, cpu_seconds:(.user_seconds + .system_seconds),
          max_rss_mib:(.rss_kib / 1024), exit_code:.exit_code}
         else error("invalid accounting fields") end' \
        "$file" > "$JAC_CI_MEASURE_DIR/$phase.json"
      normalized+=("$JAC_CI_MEASURE_DIR/$phase.json")
    done
    jq -s --arg job "${GITHUB_JOB:-}" --arg attempt "${GITHUB_RUN_ATTEMPT:-1}" \
      --slurpfile context "$JAC_CI_MEASURE_DIR/context.json" \
      --slurpfile budgets "$budget_file" \
      -f "$script_dir/ci_measure_gate.jq" /dev/null "${normalized[@]}" \
      > "$JAC_CI_MEASURE_DIR/report.json"
    while IFS= read -r phase; do
      jq --arg phase "$phase" '.results[] | select(.phase == $phase)' \
        "$JAC_CI_MEASURE_DIR/report.json" > "$JAC_CI_MEASURE_DIR/$phase.json"
    done < <(jq -r '.results[].phase' "$JAC_CI_MEASURE_DIR/report.json")
    jq -r '.results[] | "| \(.phase) | \(.wall_seconds // "") | \(.cpu_seconds // "") | \(.max_rss_mib // "") | \(.exit_code // "") | \(.mode) | \(if .budget then "\(.budget.wall_seconds) / \(.budget.max_rss_mib)" else "-" end) | \(if (.failures | length) > 0 then (.failures | join("; ")) elif .mode == "enforce" then "Pass" else "Reporting only" end) |"' \
      "$JAC_CI_MEASURE_DIR/report.json" >> "$summary"
    if [ "${#files[@]}" -eq 0 ]; then
      echo 'No commands were measured; inspect job outcomes in context.json.' >> "$summary"
    fi
    cat "$summary"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then cat "$summary" >> "$GITHUB_STEP_SUMMARY"; fi
    jq -r '.failures[] | "::error title=Performance budget::\(.phase): \(.failures | join("; "))"' \
      "$JAC_CI_MEASURE_DIR/report.json"
    jq -e '.failures | length == 0' "$JAC_CI_MEASURE_DIR/report.json" > /dev/null
    ;;
  *) echo "Usage: $0 record PHASE COMMAND... | report" >&2; exit 2 ;;
esac
