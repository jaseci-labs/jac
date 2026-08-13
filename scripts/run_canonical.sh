#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run_canonical.sh -- the ONE pipeline that produces results/paper-canonical/,
# the single artifact set the paper is built from (STEPS.md Phase A, item 4/5;
# interop-bench#3). Every producer is committed; every output carries raw
# per-invocation samples + a correctness digest; the whole bundle is manifested
# with the exact git sha so a reviewer can trace every paper number back here.
#
# HARD GATES (refuses to run otherwise):
#   * git worktree clean            -- a dirty tree is not a frozen revision
#   * CPU governor == performance   -- absolutes are meaningless otherwise
#   * turbo disabled (no_turbo==1)
#   * every producer oracle passes  -- digest identity across tools/reps
#
# Usage:
#   scripts/run_canonical.sh                    # full canonical run
#   FAST=1 scripts/run_canonical.sh             # tiny smoke (NOT canonical)
#
# The FFI/RPC producers need the comparand venv:
#   python -m venv --system-site-packages scripts/.xtool-venv
#   scripts/.xtool-venv/bin/pip install -r scripts/xtool-requirements.txt
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="results/paper-canonical"
AGG="$OUT/aggregate"
LOG="$OUT/logs"
VENV="scripts/.xtool-venv/bin/python"
BENCH="jac/examples/interopbench"

die() { echo "ABORT: $*" >&2; exit 1; }

# ---- gates -----------------------------------------------------------------
[ -x "$VENV" ] || die "comparand venv missing ($VENV); see header for setup."
# A prior bundle under results/paper-canonical/ is regenerated below (rm'd before
# capture_env runs), so untracked files THERE don't count as a dirty source tree.
# Any tracked modification -- including to the bundle's README -- still trips this.
DIRTY="$(git status --porcelain | grep -v '^?? results/paper-canonical/' || true)"
if [ -n "$DIRTY" ]; then
  echo "$DIRTY" >&2
  die "git worktree is dirty. Commit the exact revision before capturing canonical results."
fi
GOV="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
[ "$GOV" = performance ] || die "CPU governor is '$GOV', not 'performance'. Pin it:
  echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
NOTURBO="$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo missing)"
[ "$NOTURBO" = 1 ] || echo "WARNING: turbo not disabled (no_turbo=$NOTURBO); absolutes will drift." >&2

# smoke vs canonical knobs
if [ "${FAST:-0}" = 1 ]; then
  FFI_MN=500; FFI_IN=200000; FFI_REPS=2
  SWEEP_REPS=3; SWEEP_WORKS="25,100,400,1600"
  PAY_REPS=1; PAY_INV=5; PAY_SIZES="p1,p100,p1000,p10000"
  RPC_WORK=500; RPC_CALLS=20; RPC_REPS=1
else
  FFI_MN=2000; FFI_IN=2000000; FFI_REPS=5
  SWEEP_REPS=20; SWEEP_WORKS="25,50,100,200,400,800,1600,3200"
  PAY_REPS=3; PAY_INV=20; PAY_SIZES=""     # default full 16-point sweep
  RPC_WORK=5000; RPC_CALLS=200; RPC_REPS=3
fi

# Clear previous OUTPUTS only -- keep the tracked README.md so the tree stays
# clean for the env capture below (deleting a tracked file would read as dirty).
rm -rf "$AGG" "$LOG" "$OUT/env.json" "$OUT/MANIFEST.json"
mkdir -p "$AGG" "$LOG"

# Capture env FIRST, while the worktree still holds only committed files, so
# git_dirty certifies the exact source revision the producers ran at. (The
# producer outputs created afterwards are the RESULT of this frozen revision,
# not part of it.)
echo "== capturing env manifest =="
# stderr goes OUTSIDE the tree during the run so it doesn't itself dirty the
# worktree the capture is inspecting; copied into logs/ afterwards.
_envlog="$(mktemp)"
python3 scripts/capture_env.py -o "$OUT/env.json" 2>"$_envlog" \
  || { cp "$_envlog" "$LOG/env.log"; die "capture_env.py rejected the environment (see $LOG/env.log; likely a dirty tree)."; }
cp "$_envlog" "$LOG/env.log"; rm -f "$_envlog"

echo "== [1/4] cross-tool FFI =="
"$VENV" scripts/xtool_ffi.py --reps "$FFI_REPS" --matched-n "$FFI_MN" \
  --isolated-n "$FFI_IN" --jac-na --out "$AGG/xtool_ffi.json" 2>&1 | tee "$LOG/ffi.log"

echo "== [2/4] controlled multi-work sweep =="
python3 scripts/sweep_controlled.py --reps "$SWEEP_REPS" --works "$SWEEP_WORKS" \
  --out "$AGG/sweep.json" 2>&1 | tee "$LOG/sweep.log"

echo "== [3/4] payload-cardinality sweep =="
pay_args=(--reps "$PAY_REPS" --invocations "$PAY_INV" --out "$AGG/payload.json")
[ -n "$PAY_SIZES" ] && pay_args+=(--sizes "$PAY_SIZES")
python3 scripts/payload_sweep_controlled.py "${pay_args[@]}" 2>&1 | tee "$LOG/payload.log"

echo "== [4/4] cross-tool RPC verdict =="
"$VENV" scripts/xtool_rpc.py --work "$RPC_WORK" --calls "$RPC_CALLS" \
  --reps "$RPC_REPS" --out "$AGG/xtool_rpc.json" 2>&1 | tee "$LOG/rpc.log"

# ---- manifest --------------------------------------------------------------
echo "== writing MANIFEST.json =="
GIT_SHA="$(git rev-parse HEAD)"
UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "{"
  echo "  \"git_sha\": \"$GIT_SHA\","
  echo "  \"captured_utc\": \"$UTC\","
  echo "  \"fast_smoke\": ${FAST:-0},"
  echo "  \"governor\": \"$GOV\", \"no_turbo\": \"$NOTURBO\","
  echo "  \"files\": {"
  first=1
  for f in "$OUT/env.json" "$AGG"/*.json; do
    rel="${f#"$OUT"/}"
    sha="$(sha256sum "$f" | cut -d' ' -f1)"
    [ $first = 1 ] || echo ","
    first=0
    printf '    "%s": "%s"' "$rel" "$sha"
  done
  echo ""
  echo "  }"
  echo "}"
} > "$OUT/MANIFEST.json"

echo "== canonical bundle complete: $OUT =="
echo "   run the audit to verify: python3 scripts/audit.py"
