# Shared helpers for Vite Phase 0 CLI smokes (source only; not executed as a test).
# shellcheck shell=bash

_vite_cli_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd
}

if [[ -z "${VITE_ROOT:-}" ]]; then
  _vite_default="$(_vite_cli_repo_root)/../vite"
  if [[ -f "${_vite_default}/packages/vite/bin/vite.js" ]]; then
    VITE_ROOT="$_vite_default"
  else
    VITE_ROOT=""
  fi
fi
export VITE_ROOT
# Post–RegExp-gate: vite.js parses (hashbang stripped); CLI blocked until dist exists or import errors surface.
: "${VITE_CLI_FORBID_SUBSTR:=Invalid flags supplied to RegExp constructor}"

_vite_cli_integration_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

vite_cli_is_configured() {
  [[ -n "${VITE_ROOT:-}" && -f "${VITE_ROOT}/packages/vite/bin/vite.js" ]]
}

vite_cli_skip_unless_configured() {
  local label="$1"
  if vite_cli_is_configured; then
    return 0
  fi
  echo "SKIP: ${label}: set VITE_ROOT to a Vite repo (default: sibling ../vite)"
  return 1
}

vite_cli_engine() {
  if [[ -n "${JAC_JS_RUNNER:-}" ]]; then
    echo "$JAC_JS_RUNNER"
    return
  fi
  if [[ -n "${JAC_ENGINE_ROOT:-}" && -x "${JAC_ENGINE_ROOT}/bin/js_engine" ]]; then
    echo "${JAC_ENGINE_ROOT}/bin/js_engine"
    return
  fi
  local root
  root=$(_vite_cli_integration_dir)/../../..
  if [[ -x "${root}/bin/js_engine" ]]; then
    echo "${root}/bin/js_engine"
    return
  fi
  echo "bin/js_engine"
}

vite_cli_vite_bin() {
  echo "${VITE_ROOT}/packages/vite/bin/vite.js"
}

vite_cli_dist_cli() {
  echo "${VITE_ROOT}/packages/vite/dist/node/cli.js"
}

vite_cli_pkg_json() {
  echo "${VITE_ROOT}/packages/vite/package.json"
}

# Read pinned vite version from package.json (fallback 8.0.13).
vite_cli_read_version() {
  local pkg ver
  pkg=$(vite_cli_pkg_json)
  if [[ -f "$pkg" ]] && command -v node >/dev/null 2>&1; then
    ver=$(node -e "process.stdout.write(require(process.argv[1]).version)" "$pkg" 2>/dev/null || true)
  fi
  if [[ -z "$ver" ]]; then
    ver="8.0.13"
  fi
  echo "$ver"
}

# Ensure packages/vite/dist exists: use prebuilt dist if present, else hydrate from npm pack cache.
vite_cli_ensure_dist() {
  local dist_cli cache_dir ver tgz extracted
  dist_cli=$(vite_cli_dist_cli)
  if [[ -f "$dist_cli" ]]; then
    return 0
  fi
  cache_dir="$(_vite_cli_integration_dir)/_fixtures/vite_dist_cache"
  ver=$(vite_cli_read_version)
  extracted="${cache_dir}/vite-${ver}"
  if [[ ! -f "${extracted}/dist/node/cli.js" ]]; then
    if ! command -v npm >/dev/null 2>&1; then
      regression_record_fail "vite dist missing and npm unavailable to fetch vite@${ver}"
      return 1
    fi
    mkdir -p "$cache_dir"
    if ! (cd "$cache_dir" && npm pack "vite@${ver}" >/dev/null 2>&1); then
      regression_record_fail "npm pack vite@${ver} failed"
      return 1
    fi
    tgz=$(ls -1 "${cache_dir}"/vite-"${ver}".tgz 2>/dev/null | head -1)
    if [[ -z "$tgz" || ! -f "$tgz" ]]; then
      regression_record_fail "npm pack vite@${ver} produced no tarball"
      return 1
    fi
    rm -rf "$extracted"
    mkdir -p "$extracted"
    if ! tar -xzf "$tgz" -C "$extracted" --strip-components=1; then
      regression_record_fail "failed to extract ${tgz}"
      return 1
    fi
  fi
  if [[ ! -f "${extracted}/dist/node/cli.js" ]]; then
    regression_record_fail "cached vite@${ver} missing dist/node/cli.js"
    return 1
  fi
  mkdir -p "$(dirname "$dist_cli")"
  rm -rf "${VITE_ROOT}/packages/vite/dist"
  cp -a "${extracted}/dist" "${VITE_ROOT}/packages/vite/dist"
}

vite_cli_minimal_fixture_dir() {
  echo "$(_vite_cli_integration_dir)/_fixtures/vite_minimal"
}

# Run Vite CLI via js_engine. Sets VITE_CLI_LAST_* globals.
# Usage: vite_cli_run <cwd> [vite-arg ...]
vite_cli_run() {
  local cwd="$1"
  shift
  local engine vite_bin stdout stderr
  engine=$(vite_cli_engine)
  vite_bin=$(vite_cli_vite_bin)
  if ! vite_cli_is_configured; then
    regression_record_fail "VITE_ROOT not set or missing packages/vite/bin/vite.js"
    VITE_CLI_LAST_EXIT=127
    return
  fi
  if ! vite_cli_ensure_dist; then
    VITE_CLI_LAST_EXIT=127
    return
  fi
  stdout=$(mktemp)
  stderr=$(mktemp)
  VITE_CLI_LAST_STDOUT_FILE=$stdout
  VITE_CLI_LAST_STDERR_FILE=$stderr

  if [[ ! -x "$engine" ]] && ! command -v "$engine" >/dev/null 2>&1; then
    regression_record_fail "runner not executable: $engine"
    VITE_CLI_LAST_EXIT=127
    return
  fi
  if [[ ! -f "$vite_bin" ]]; then
    regression_record_fail "Vite entry missing: $vite_bin (set VITE_ROOT)"
    VITE_CLI_LAST_EXIT=127
    return
  fi

  local exit_code=0
  VITE_CLI_LAST_TIMED_OUT=0
  if [[ -n "${VITE_CLI_TIMEOUT_SEC:-}" ]] && command -v timeout >/dev/null 2>&1; then
    if timeout --foreground "${VITE_CLI_TIMEOUT_SEC}" \
      bash -c 'cd "$1" && shift && exec "$@"' _ "$cwd" "$engine" "$vite_bin" "$@" \
      >"$stdout" 2>"$stderr"; then
      exit_code=0
    else
      exit_code=$?
      if [[ $exit_code -eq 124 ]]; then
        VITE_CLI_LAST_TIMED_OUT=1
      fi
    fi
  else
    (cd "$cwd" && "$engine" "$vite_bin" "$@") >"$stdout" 2>"$stderr" || exit_code=$?
  fi
  VITE_CLI_LAST_EXIT=$exit_code
  VITE_CLI_LAST_STDOUT_BYTES=$(wc -c <"$stdout" | tr -d ' ')
  VITE_CLI_LAST_STDERR_BYTES=$(wc -c <"$stderr" | tr -d ' ')
}

vite_cli_cleanup_temp() {
  rm -f "${VITE_CLI_LAST_STDOUT_FILE:-}" "${VITE_CLI_LAST_STDERR_FILE:-}"
}

# RegExp/hashbang gate cleared: must not see the old bundled-parse SyntaxError.
vite_cli_assert_no_regexp_gate() {
  local label="$1"
  local out err combined
  out=$(cat "${VITE_CLI_LAST_STDOUT_FILE:-/dev/null}" 2>/dev/null || true)
  err=$(cat "${VITE_CLI_LAST_STDERR_FILE:-/dev/null}" 2>/dev/null || true)
  combined="${out}${err}"
  if [[ "$combined" == *"${VITE_CLI_FORBID_SUBSTR}"* ]]; then
    regression_record_fail "${label}: RegExp constructor gate still present (expected cleared)"
  fi
}

# CLI still blocked before dist/node/cli.js (or equivalent) runs successfully.
# js_engine: empty exit 0 after vite.js timer, module-not-found on import, or unhandled rejection.
# node (no dist): ERR_MODULE_NOT_FOUND / Cannot find module.
vite_cli_assert_pre_dist_cli_blocker() {
  local label="$1"
  local out err combined
  out=$(cat "${VITE_CLI_LAST_STDOUT_FILE:-/dev/null}" 2>/dev/null || true)
  err=$(cat "${VITE_CLI_LAST_STDERR_FILE:-/dev/null}" 2>/dev/null || true)
  combined="${out}${err}"
  vite_cli_assert_no_regexp_gate "${label}"
  if [[ "$combined" == *"vite/"* ]] && [[ "${VITE_CLI_LAST_EXIT:-1}" == "0" ]]; then
    regression_record_fail "${label}: unexpected successful CLI version/help output"
  fi
  if [[ "$combined" == *"ERR_MODULE_NOT_FOUND"* ]] ||
     [[ "$combined" == *"Cannot find module"* ]] ||
     [[ "$combined" == *"UNHANDLED PROMISE REJECTION"* ]]; then
    return 0
  fi
  if [[ "${VITE_CLI_LAST_EXIT:-1}" == "0" ]] &&
     [[ "${VITE_CLI_LAST_STDOUT_BYTES:-1}" == "0" ]] &&
     [[ "${VITE_CLI_LAST_STDERR_BYTES:-1}" == "0" ]]; then
    return 0
  fi
  if [[ "${VITE_CLI_LAST_EXIT:-0}" != "0" ]]; then
    return 0
  fi
  regression_record_fail "${label}: missing expected pre-dist CLI blocker signature"
}

# Phase 2A: --version must print vite/<semver> and exit 0.
vite_cli_assert_version_success() {
  local label="$1"
  local out err combined ver
  out=$(cat "${VITE_CLI_LAST_STDOUT_FILE:-/dev/null}" 2>/dev/null || true)
  err=$(cat "${VITE_CLI_LAST_STDERR_FILE:-/dev/null}" 2>/dev/null || true)
  combined="${out}${err}"
  ver=$(vite_cli_read_version)
  vite_cli_assert_no_regexp_gate "${label}"
  if [[ "${VITE_CLI_LAST_EXIT:-1}" != "0" ]]; then
    regression_record_fail "${label}: expected exit 0, got ${VITE_CLI_LAST_EXIT:-?}"
  fi
  if [[ "$combined" != *"${ver}"* ]]; then
    regression_record_fail "${label}: expected version ${ver} in output"
  fi
  if [[ "$combined" != *"vite/"* ]] && [[ "$combined" != *"vite.js/"* ]] &&
     [[ "$combined" != *"vite "* ]] && [[ "$combined" != *"VITE"* ]] &&
     [[ "$combined" != *"cli.js/"* ]]; then
    regression_record_fail "${label}: expected vite/cli version banner in output"
  fi
}

# Contract: version line on stdout, semver present, no silent success.
vite_cli_assert_version_contract() {
  local label="$1"
  local out err ver line
  out=$(cat "${VITE_CLI_LAST_STDOUT_FILE:-/dev/null}" 2>/dev/null || true)
  err=$(cat "${VITE_CLI_LAST_STDERR_FILE:-/dev/null}" 2>/dev/null || true)
  ver=$(vite_cli_read_version)
  vite_cli_assert_version_success "${label}"
  if [[ "${VITE_CLI_LAST_STDOUT_BYTES:-0}" -lt 8 ]]; then
    regression_record_fail "${label}: stdout too small (${VITE_CLI_LAST_STDOUT_BYTES:-?} bytes); silent success?"
  fi
  line=$(printf '%s' "$out" | head -1 | tr -d '\r')
  if [[ -z "$line" ]]; then
    regression_record_fail "${label}: expected non-empty version line on stdout"
  fi
  if [[ ! "$line" =~ /${ver}([[:space:]]|$) ]] && [[ ! "$line" =~ /${ver}/ ]]; then
    regression_record_fail "${label}: first stdout line missing pinned semver ${ver}: ${line}"
  fi
  if [[ "$line" == *"UNHANDLED PROMISE REJECTION"* ]] ||
     [[ "$line" == *"Cannot read properties of undefined"* ]] ||
     [[ "$err" == *"UNHANDLED PROMISE REJECTION"* ]]; then
    regression_record_fail "${label}: version path leaked module-load failure"
  fi
}

# Phase 2A: --help must list CLI usage and exit 0.
vite_cli_assert_help_success() {
  local label="$1"
  local out err combined
  out=$(cat "${VITE_CLI_LAST_STDOUT_FILE:-/dev/null}" 2>/dev/null || true)
  err=$(cat "${VITE_CLI_LAST_STDERR_FILE:-/dev/null}" 2>/dev/null || true)
  combined="${out}${err}"
  vite_cli_assert_no_regexp_gate "${label}"
  if [[ "${VITE_CLI_LAST_EXIT:-1}" != "0" ]]; then
    regression_record_fail "${label}: expected exit 0, got ${VITE_CLI_LAST_EXIT:-?}"
  fi
  if [[ "$combined" != *"vite"* ]] || [[ "$combined" != *"Usage"* && "$combined" != *"usage"* && "$combined" != *"Commands"* && "$combined" != *"OPTIONS"* ]]; then
    regression_record_fail "${label}: expected help text in output"
  fi
}

# Contract: help on stdout with real newlines (template literal escapes), required sections.
vite_cli_assert_help_contract() {
  local label="$1"
  local out err ver
  out=$(cat "${VITE_CLI_LAST_STDOUT_FILE:-/dev/null}" 2>/dev/null || true)
  err=$(cat "${VITE_CLI_LAST_STDERR_FILE:-/dev/null}" 2>/dev/null || true)
  ver=$(vite_cli_read_version)
  vite_cli_assert_help_success "${label}"
  if [[ "${VITE_CLI_LAST_STDOUT_BYTES:-0}" -lt 64 ]]; then
    regression_record_fail "${label}: stdout too small (${VITE_CLI_LAST_STDOUT_BYTES:-?} bytes)"
  fi
  if [[ "$out" == *'Usage:\n'* ]] || [[ "$out" == *'Commands:\n'* ]] || [[ "$out" == *'Options:\n'* ]]; then
    regression_record_fail "${label}: help contains literal backslash-n (template quasi escapes not cooked)"
  fi
  if [[ "$out" != *"Usage:"* ]] || [[ "$out" != *"Commands:"* ]] || [[ "$out" != *"Options:"* ]]; then
    regression_record_fail "${label}: missing Usage/Commands/Options sections on stdout"
  fi
  if [[ "$out" != *"build"* ]] || [[ "$out" != *"preview"* ]]; then
    regression_record_fail "${label}: missing expected subcommands in help"
  fi
  if [[ "$out" != *"${ver}"* ]] && [[ "$out" != *"vite/"* ]] && [[ "$out" != *"vite.js/"* ]]; then
    regression_record_fail "${label}: expected version banner before help body"
  fi
  if [[ "$out" == *"UNHANDLED PROMISE REJECTION"* ]] || [[ "$err" == *"UNHANDLED PROMISE REJECTION"* ]]; then
    regression_record_fail "${label}: help path leaked module-load failure"
  fi
}

# Pre-dist blocker (optimize/dev until further parity).
vite_cli_assert_phase0_baseline() {
  vite_cli_assert_pre_dist_cli_blocker "$1"
}

# Start vite dev in background; sets VITE_DEV_PID. Returns 0 if shell spawn succeeded.
vite_cli_dev_start_background() {
  local cwd="$1"
  shift
  local engine vite_bin stdout stderr
  engine=$(vite_cli_engine)
  vite_bin=$(vite_cli_vite_bin)
  stdout=$(mktemp)
  stderr=$(mktemp)
  VITE_CLI_LAST_STDOUT_FILE=$stdout
  VITE_CLI_LAST_STDERR_FILE=$stderr

  if [[ ! -x "$engine" ]] || [[ ! -f "$vite_bin" ]]; then
    regression_record_fail "vite dev: engine or vite bin missing"
    return 1
  fi

  (cd "$cwd" && "$engine" "$vite_bin" "$@") >"$stdout" 2>"$stderr" &
  VITE_DEV_PID=$!
  VITE_CLI_LAST_EXIT=0
  return 0
}

vite_cli_dev_wait_ready_or_exit() {
  local port="$1"
  local timeout_sec="${2:-5}"
  local i
  for ((i = 0; i < timeout_sec * 2; i++)); do
    if ! kill -0 "${VITE_DEV_PID:-0}" 2>/dev/null; then
      wait "${VITE_DEV_PID}" 2>/dev/null || true
      VITE_CLI_LAST_EXIT=$?
      VITE_CLI_LAST_STDOUT_BYTES=$(wc -c <"${VITE_CLI_LAST_STDOUT_FILE}" 2>/dev/null | tr -d ' ' || echo 0)
      VITE_CLI_LAST_STDERR_BYTES=$(wc -c <"${VITE_CLI_LAST_STDERR_FILE}" 2>/dev/null | tr -d ' ' || echo 0)
      return 1
    fi
    if command -v curl >/dev/null 2>&1; then
      if curl -fsS -o /dev/null -m 1 "http://127.0.0.1:${port}/" 2>/dev/null; then
        return 0
      fi
    fi
    sleep 0.5
  done
  return 2
}

vite_cli_dev_stop() {
  if [[ -n "${VITE_DEV_PID:-}" ]] && kill -0 "$VITE_DEV_PID" 2>/dev/null; then
    kill "$VITE_DEV_PID" 2>/dev/null || true
    wait "$VITE_DEV_PID" 2>/dev/null || true
  fi
}
