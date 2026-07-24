#!/usr/bin/env bash
# Re-run the xop_feed_payload cardinality sweep across all 16 registered sizes,
# writing one per-size JSON (now carrying raw per-invocation `metric_samples`,
# see harness/common.jac:aggregate_runs) into $OUTDIR. Feed those to
# assemble_cis.py to build results/payload_sweep_results.json with bootstrap CIs.
#
# Usage: OUTDIR=/path INVOCATIONS=9 scripts/rerun_payload_sweep.sh
set -euo pipefail

BENCH="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="${OUTDIR:-/tmp/payload_sweep_raw}"
INVOCATIONS="${INVOCATIONS:-9}"
SIZES=(p1 p10 p50 p100 p250 p500 p1000 p2000 p5000 p10000 \
       p20000 p30000 p40000 p50000 p75000 p100000)

mkdir -p "$OUTDIR"
cd "$BENCH"
pkill -f "jaclang start feedbatch" 2>/dev/null || true
sleep 1

for size in "${SIZES[@]}"; do
  echo "=== size $size  invocations=$INVOCATIONS  $(date +%T) ==="
  jac run harness/xbench.jac --experimental --kernels xop_feed_payload \
    --sizes "$size" --invocations "$INVOCATIONS" \
    --out "$OUTDIR/pay_$size.json" > "$OUTDIR/pay_$size.log" 2>&1
  echo "  exit=$? -> $OUTDIR/pay_$size.json"
  pkill -f "jaclang start feedbatch" 2>/dev/null || true
  sleep 1
done
echo "ALL SIZES DONE $(date +%T) -> $OUTDIR"
