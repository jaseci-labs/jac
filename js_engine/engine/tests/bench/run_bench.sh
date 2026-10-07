#!/usr/bin/env bash
# js_engine benchmark suite runner.
#
#   engine/tests/bench/run_bench.sh [ENGINE_BINARY] [SCALE] [CORE]
#
# Runs every *.js workload in this directory (except _h.js) on the engine and
# on node (interpreter-only: --no-opt --no-sparkplug --no-maglev, and JIT),
# pinned to one core, each under a 16 GB virtual-memory limit and a timeout,
# diffs the engine's output against node's (every workload prints a
# checksum), and prints a table of wall-clock seconds, max RSS and ratios.
# SCALE multiplies every workload's iteration count (default 1).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
JB="$(cd "$HERE/../../.." && pwd)"
ENGINE="${1:-$JB/bin/js_engine}"
SCALE="${2:-1}"
CORE="${3:-4}"
MEM_KB=16777216          # 16 GiB virtual address space
TIMEOUT=600
export LD_LIBRARY_PATH="$JB/lib:$JB/lib/llhttp/lib"
OUT="$HERE/results"; mkdir -p "$OUT"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$OUT/bench-$STAMP.txt"

run_one() {  # cmd... -> prints "seconds rss_kb" on stdout; program output to $1 (file)
  local outfile="$1"; shift
  /usr/bin/time -f "%e %M" -o "$outfile.time" bash -c "ulimit -v $MEM_KB; exec timeout $TIMEOUT taskset -c $CORE \"\$@\"" _ "$@" > "$outfile" 2>"$outfile.err"
  tail -1 "$outfile.time"
}

printf "%-22s %9s %9s %9s %8s %8s %8s %s\n" workload engine_s node_i_s node_jit_s "x_interp" "x_jit" "rss_MB" check | tee "$LOG"
tot_e=0; tot_i=0; tot_j=0
for f in "$HERE"/*.js; do
  name="$(basename "$f" .js)"; [ "$name" = "_h" ] && continue
  e=$(run_one "$OUT/$name.engine.out" "$ENGINE" --gc "$f" "$SCALE")
  i=$(run_one "$OUT/$name.nodei.out" node --no-opt --no-sparkplug --no-maglev "$f" "$SCALE")
  j=$(run_one "$OUT/$name.nodej.out" node "$f" "$SCALE")
  es=${e% *}; er=${e#* }; is=${i% *}; js=${j% *}
  if diff -q "$OUT/$name.engine.out" "$OUT/$name.nodej.out" >/dev/null 2>&1; then chk=ok; else chk="DIFF"; fi
  [ -s "$OUT/$name.engine.out" ] || chk="NO-OUTPUT"
  xi=$(awk -v a="$es" -v b="$is" 'BEGIN{ if (b>0) printf "%.1f", a/b; else print "-" }')
  xj=$(awk -v a="$es" -v b="$js" 'BEGIN{ if (b>0) printf "%.1f", a/b; else print "-" }')
  printf "%-22s %9s %9s %9s %8s %8s %8.0f %s\n" "$name" "$es" "$is" "$js" "$xi" "$xj" "$(awk -v r="$er" 'BEGIN{print r/1024}')" "$chk" | tee -a "$LOG"
  tot_e=$(awk -v a="$tot_e" -v b="$es" 'BEGIN{print a+b}'); tot_i=$(awk -v a="$tot_i" -v b="$is" 'BEGIN{print a+b}'); tot_j=$(awk -v a="$tot_j" -v b="$js" 'BEGIN{print a+b}')
done
printf "%-22s %9s %9s %9s %8s %8s\n" TOTAL "$tot_e" "$tot_i" "$tot_j" "$(awk -v a="$tot_e" -v b="$tot_i" 'BEGIN{printf "%.1f", a/b}')" "$(awk -v a="$tot_e" -v b="$tot_j" 'BEGIN{printf "%.1f", a/b}')" | tee -a "$LOG"
echo "engine: $ENGINE  scale: $SCALE  core: $CORE  mem limit: ${MEM_KB} KB  log: $LOG"
