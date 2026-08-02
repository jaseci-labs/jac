#!/usr/bin/env bash
# Second-machine portability re-capture for JacInteropBench.
#
# Purpose: demonstrate that the PAPER'S RATIOS port across machines while the
# ABSOLUTE nanosecond figures are clock-specific -- the single-machine
# generalizability objection. Run this on a DIFFERENT box (ideally arm64) from
# the canonical Ultra 7 255H, then compare the printed ratios against the
# canonical values below.
#
# Canonical (Ultra 7 255H, performance governor, turbo off):
#   placement slope ratio  sv/na  ~= 42x        (iop_cb.free 212 / na_local 5.0)
#   payload serialization  rpc/direct ~= 2.6x   (890 / 342 ns/element)
#   callback twin-gap intercept        ~= 2.0us
#   cross-runtime floors   svc_split 374x, feed 241x, wasm 6.8x
# The RATIOS should reproduce within a few percent on any machine; the ns
# ABSOLUTES will differ with clock/uarch. That contrast IS the result.
#
# Requirements: a working `jac` (0.34.x), `node` on PATH, pinned governor.
# Usage:
#   scripts/portability_recapture.sh <machine-label>
# writes results/portability/<machine-label>/{env,sweep,payload,xruntime}.json
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="${1:?usage: portability_recapture.sh <machine-label> (e.g. arm64-m2)}"
OUT="results/portability/${LABEL}"
mkdir -p "$OUT"

# Optional fast dry-run overrides (defaults match the canonical protocol):
#   REPS=2 PAYLOAD_SIZES=p1,p100 XRUN_INV=3 scripts/portability_recapture.sh smoke
REPS="${REPS:-20}"
PAYLOAD_SIZES="${PAYLOAD_SIZES:-}"      # empty => full 16-point sweep
XRUN_INV="${XRUN_INV:-20}"
# Sweep parallelism. Default matches sweep_controlled.py (8, fine on the pinned
# many-core canonical box). On a small shared runner (e.g. a 4-core hosted CI
# box) set JOBS<=cores: oversubscription starves the tiniest cells and drops
# samples, which the exact-reps gate then (correctly) refuses.
JOBS="${JOBS:-8}"

# --- guardrail: refuse unless governor is pinned (matches sweep_controlled) ---
GOV="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
if [[ "$GOV" != "performance" && "$GOV" != "unknown" ]]; then
  echo "ABORT: governor is '$GOV', not 'performance'. Pin it first:" >&2
  echo "  echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor" >&2
  exit 2
fi
TURBO="$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo NA)"
[[ "$TURBO" == "1" || "$TURBO" == "NA" ]] || \
  echo "WARNING: turbo not disabled (no_turbo=$TURBO); absolutes will drift." >&2

echo "== 1/4 environment provenance =="
# capture_env exits non-zero on a dirty tree; that is a provenance note, not a
# reason to abort a re-capture. The manifest is still written.
python3 scripts/capture_env.py -o "$OUT/env.json" >/dev/null || \
  echo "  note: env manifest flags a dirty/non-frozen tree (recorded in env.json)"

echo "== 2/4 family-1 work sweep (iop_call/iop_cb/iop_symmetric), reps=$REPS =="
python3 scripts/sweep_controlled.py --reps "$REPS" --jobs "$JOBS" --out "$OUT/sweep.json"

echo "== 3/4 payload sweep (xop_feed_payload N=1..100k), n=$XRUN_INV =="
python3 scripts/payload_sweep_controlled.py --invocations "$XRUN_INV" --reps 1 \
  ${PAYLOAD_SIZES:+--sizes "$PAYLOAD_SIZES"} --out "$OUT/payload.json"

echo "== 4/4 cross-runtime small (svc_split/feed), n=$XRUN_INV =="
( cd jac/examples/interopbench && \
  jac run harness/xbench.jac --experimental \
    --kernels xop_svc_split,xop_feed --sizes small \
    --invocations "$XRUN_INV" --out "$(pwd)/../../../$OUT/xruntime.json" )

# wasm/native is a separate, TARGET-DEPENDENT leg: it needs a jac built with the
# wasm32 LLVM backend. On toolchains without that target (e.g. the hosted arm64
# image, whose release binary omits wasm32) the compile fails with "No available
# targets are compatible with triple wasm32-unknown-unknown". That is an expected
# portability gap, not a capture failure -- record its absence and KEEP the
# svc_split/feed floors and the placement/payload ratios we already captured.
echo "== 4b/4 cross-runtime wasm (target-dependent, non-fatal) =="
if ( cd jac/examples/interopbench && \
     jac run harness/xbench.jac --experimental \
       --kernels xop_wasm_call --sizes small \
       --invocations "$XRUN_INV" --out "$(pwd)/../../../$OUT/xruntime_wasm.json" ); then
  python3 - "$OUT" <<'PY'
import json, sys
out = sys.argv[1]
main = json.load(open(f"{out}/xruntime.json"))
main["cells"].update(json.load(open(f"{out}/xruntime_wasm.json"))["cells"])
json.dump(main, open(f"{out}/xruntime.json", "w"), indent=2)
PY
  echo "  wasm/native captured and merged into xruntime.json"
else
  echo "  wasm/native SKIPPED: no wasm32 target in this jac toolchain (recorded as absent)"
  printf '{"skipped": "no wasm32 target in this jac toolchain"}\n' \
    > "$OUT/xruntime_wasm_skipped.json"
fi

echo
echo "== portability summary for '$LABEL' (compare RATIOS to canonical above) =="
python3 - "$OUT" <<'PY'
import json, sys, statistics as st
out = sys.argv[1]

def fit(pw):
    xs = sorted(int(w) for w in pw)
    X = [(w, pw[str(w)]["median_per_call_ns"]) for w in xs]
    n=len(X); sx=sum(w for w,_ in X); sy=sum(y for _,y in X)
    sxx=sum(w*w for w,_ in X); sxy=sum(w*y for w,y in X)
    b=(n*sxy-sx*sy)/(n*sxx-sx*sx); a=(sy-b*sx)/n
    return a,b

sw = json.load(open(f"{out}/sweep.json"))["cells"]
cb = fit(sw["iop_cb"]["variants"]["free"]["per_work"])[1]
na = fit(sw["iop_symmetric"]["variants"]["na_local"]["per_work"])[1]
print(f"  placement slope ratio sv/na = {cb/na:5.1f}x   (canonical ~42x)")

ps = json.load(open(f"{out}/payload.json"))["cells"]["xop_feed_payload"]["per_size"]
def pfit(key):
    pts=sorted((s["N"], s[key]["per_call_ns"]) for s in ps.values())
    n=len(pts); sx=sum(x for x,_ in pts); sy=sum(y for _,y in pts)
    sxx=sum(x*x for x,_ in pts); sxy=sum(x*y for x,y in pts)
    return (n*sxy-sx*sy)/(n*sxx-sx*sx)
if len(ps) < 8:
    print(f"  payload fit skipped ({len(ps)} points; needs the full 16-size sweep)")
else:
    ds, rs = pfit("direct"), pfit("rpc")
    print(f"  payload serialization rpc/direct = {rs/ds:4.2f}x   (canonical ~2.6x)")
    print(f"    direct {ds:.0f} ns/el,  rpc {rs:.0f} ns/el  (absolutes are machine-specific)")

xr = json.load(open(f"{out}/xruntime.json"))["cells"]
for cell in ("xop_svc_split","xop_feed","xop_wasm_call"):
    if cell not in xr:
        print(f"  {cell:16s} SKIPPED (no wasm32 target in this toolchain; x86-only cell)")
        continue
    v=xr[cell]["variants"]; ref="direct" if "direct" in v else "native"
    oth=[k for k in v if k!=ref][0]
    print(f"  {cell:16s} {oth}/{ref} = {v[oth]['median_ns']/v[ref]['median_ns']:6.1f}x")
PY
echo "done -> $OUT/"
