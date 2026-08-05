#!/usr/bin/env bash
# M4 on-device gate: build → install → launch → DexClassLoader hot-swap → verify.
#
# Asserts on logcat render markers emitted from the app process, NOT on
# `uiautomator dump`. Compose text only lives in the semantics tree, which the
# shell `uiautomator` tool reads through the system accessibility service in
# system_server, and that service ANRs under the headless swiftshader emulator
# in CI, so the dump hangs forever. Logging from the app's own process bypasses
# the accessibility service entirely:
#   - JacDevHostActivity.mountModule logs `JAC_COMPOSE_MOUNTED v=<version>` when
#     a freshly downloaded classes.dex is applied.
#   - JacDevEntry.mount runs a `SideEffect` that logs `JAC_COMPOSE_RENDERED`
#     only after the Compose tree composes without throwing.
# A launch/compose crash (e.g. a Compose runtime/compiler skew) surfaces as a
# FATAL EXCEPTION in logcat and the missing RENDERED marker, so the gate still
# fails on real regressions without ever touching the accessibility service.
#
# Note: literal Compose text (title/counter) is intentionally NOT asserted here
# Reading it needs the accessibility service or an in-process Compose test.
# This gate covers the pipeline integrity instead: launch, dex load, compose
# without crashing, source-edit → rebuild → hot-swap → remount → recompose.
#
# Requires: jac on PATH, ANDROID_HOME / ANDROID_SDK_ROOT, a booted emulator or device
# (jac start will auto-start the AVD from jac.toml when none is connected).
#
# Usage (from repo root):
#   bash scripts/android_compose_device_e2e.sh
#
# Environment:
#   COMPOSE_ANDROID_DIR   — project dir (default: jac/examples/compose_android)
#   JAC_ANDROID_DEV_PORT  — dev-server port (default: ephemeral free port)
#   TIMEOUT_HMR_READY     — seconds to wait for initial HMR (default: 600)
#   TIMEOUT_HOT_SWAP      — seconds to wait for hot dex rebuild (default: 300)
#   JAC_DEV_LOG           — jac stdout log path (default: /tmp/jac-android-e2e.log)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_DIR="${COMPOSE_ANDROID_DIR:-$ROOT/jac/examples/compose_android}"
MAIN_JAC="$EXAMPLE_DIR/main.jac"
LOG_FILE="${JAC_DEV_LOG:-/tmp/jac-android-e2e.log}"
TIMEOUT_HMR_READY="${TIMEOUT_HMR_READY:-600}"
TIMEOUT_HOT_SWAP="${TIMEOUT_HOT_SWAP:-300}"
ORIG_TITLE='Jac → Jetpack Compose'
E2E_MARKER='__JAC_E2E_HMR_MARKER__'
RENDER_MARKER='JAC_COMPOSE_RENDERED'
HMR_TAG='JacHmr'

if [[ -n "${JAC_ANDROID_DEV_PORT:-}" ]]; then
  DEV_PORT="$JAC_ANDROID_DEV_PORT"
else
  DEV_PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')"
fi

if [[ -n "${ANDROID_HOME:-}" ]]; then
  ADB="$ANDROID_HOME/platform-tools/adb"
elif [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
  ADB="$ANDROID_SDK_ROOT/platform-tools/adb"
else
  ADB="$(command -v adb || true)"
fi
if [[ ! -x "$ADB" ]]; then
  echo "adb not found (set ANDROID_HOME or ANDROID_SDK_ROOT)" >&2
  exit 1
fi

JAC_PID=""

restore_main_jac() {
  if [[ -f "${MAIN_JAC}.e2e.bak" ]]; then
    mv -f "${MAIN_JAC}.e2e.bak" "$MAIN_JAC"
  fi
}

cleanup() {
  if [[ -n "$JAC_PID" ]] && kill -0 "$JAC_PID" 2>/dev/null; then
    kill "$JAC_PID" 2>/dev/null || true
    wait "$JAC_PID" 2>/dev/null || true
  fi
  restore_main_jac
}
trap cleanup EXIT

# Dump only our HMR info-level log lines (-s TAG:LEVEL silences every other tag).
logcat_jac() {
  "$ADB" shell logcat -d -s "$HMR_TAG:I" 2>/dev/null
}

clear_logcat() {
  "$ADB" logcat -c 2>/dev/null || true
}

wait_for_logcat() {
  local needle="$1" timeout="${2:-120}" elapsed=0
  while (( elapsed < timeout )); do
    if logcat_jac | grep -Fq -- "$needle"; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  echo "TIMEOUT waiting for logcat marker: $needle" >&2
  echo "Recent $HMR_TAG log lines:" >&2
  logcat_jac | tail -20 >&2 || true
  return 1
}

wait_for_log() {
  local pattern="$1" timeout="${2:-600}" elapsed=0
  while (( elapsed < timeout )); do
    if grep -q "$pattern" "$LOG_FILE" 2>/dev/null; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  echo "TIMEOUT waiting for log pattern: $pattern" >&2
  tail -40 "$LOG_FILE" >&2 || true
  return 1
}

manifest_version() {
  curl -sf "http://localhost:${DEV_PORT}/_jac/dev/modules/manifest.json" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])"
}

echo "==> Waiting for adb device..."
"$ADB" wait-for-device
booted=0
for _ in $(seq 1 90); do
  boot="$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  if [[ "$boot" == "1" ]]; then
    booted=1
    break
  fi
  sleep 2
done
if [[ "$booted" != "1" ]]; then
  echo "Emulator/device did not finish booting" >&2
  exit 1
fi
echo "==> Device ready: $("$ADB" devices -l | awk '/device product:/{print $1; exit}')"

clear_logcat
rm -f "$LOG_FILE"
cd "$EXAMPLE_DIR"

echo "==> Starting jac android dev (port $DEV_PORT, log $LOG_FILE)..."
jac start --client android --dev -p "$DEV_PORT" >"$LOG_FILE" 2>&1 &
JAC_PID=$!

wait_for_log "HMR ready" "$TIMEOUT_HMR_READY"
INITIAL_VER="$(manifest_version)"
echo "==> HMR ready — initial hot module v${INITIAL_VER}"

wait_for_logcat "$RENDER_MARKER" 120
echo "==> Initial Compose tree rendered (logcat marker)"

# Reset the logcat window so the post-hot-swap markers are unambiguous.
clear_logcat

cp "$MAIN_JAC" "${MAIN_JAC}.e2e.bak"
python3 - "$MAIN_JAC" "$ORIG_TITLE" "$E2E_MARKER" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
needle = sys.argv[2]
marker = sys.argv[3]
text = path.read_text(encoding="utf-8")
if needle not in text:
    raise SystemExit(f"expected {needle!r} in {path}")
path.write_text(text.replace(needle, marker), encoding="utf-8")
PY

wait_for_log "Hot module swapped" "$TIMEOUT_HOT_SWAP"
NEW_VER="$(manifest_version)"
if [[ "$NEW_VER" == "$INITIAL_VER" ]]; then
  echo "Manifest version unchanged after hot rebuild ($NEW_VER)" >&2
  exit 1
fi
echo "==> Hot dex swapped v${INITIAL_VER} → v${NEW_VER}"

wait_for_logcat "JAC_COMPOSE_MOUNTED v=${NEW_VER}" 120
echo "==> Hot-swapped module applied"

wait_for_logcat "$RENDER_MARKER" 120
echo "==> Hot-swapped Compose tree rendered"

echo "android_compose_device_e2e: PASSED"
