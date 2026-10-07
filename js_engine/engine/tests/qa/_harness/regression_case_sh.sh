# Source from regression shell suites:  . "$(dirname "$0")/../../_harness/regression_case_sh.sh"
# (Adjust relative path per test file location.)
REGRESSION_TESTCASE_FINISHED="REGRESSION_TESTCASE_FINISHED"
__REGRESSION_FAILURES=0

regression_record_fail() {
  echo "FAIL: $*" >&2
  __REGRESSION_FAILURES=$((__REGRESSION_FAILURES + 1))
}

# Args: suite_path (e.g. regression/cli/test_foo.sh)
regression_finish_test_case() {
  local name="$1"
  echo "${REGRESSION_TESTCASE_FINISHED} name=${name} failures=${__REGRESSION_FAILURES}"
  local ec=$__REGRESSION_FAILURES
  if [[ "$ec" -gt 255 ]]; then
    ec=255
  fi
  exit "$ec"
}
