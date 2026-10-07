# Shared runner helpers for QA shell suites.
# Always execute scripts with JAC_JS_RUNNER (set by run_reg.jac); do not hardcode node.
# shellcheck shell=bash

: "${JAC_JS_RUNNER:=bin/js_engine}"

regression_runner_name() {
  basename "$JAC_JS_RUNNER"
}

# Run a JS/MJS file with the selected regression runner.
# Usage: regression_run_js <path-to-script>
regression_run_js() {
  "$JAC_JS_RUNNER" "$1"
}

# Expect script/module must not run successfully (parse or runtime failure).
# Usage: regression_expect_run_fail <label> <path-to-script>
regression_expect_run_fail() {
  local label="$1"
  local script="$2"
  if "$JAC_JS_RUNNER" "$script" >/dev/null 2>&1; then
    regression_record_fail "${label}: expected run/parse failure"
  fi
}
