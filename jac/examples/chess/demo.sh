#!/usr/bin/env bash
# Benchmark the same chess engine across every Jac backend, 20-game run each.
# Run from this directory with the project venv active (provides python3 + jac).
#
# Since the native-by-default switch, plain `jac run chess.jac` compiles the
# module natively on every run (no marker, no flag). The old Python backend is
# still reachable by setting `[build] default_codespace = "server"` in a
# jac.toml, which is how section 2 pins it for comparison.

# Collected wall-clock times for the summary table (filled in per section).
t_python="n/a"; t_server="n/a"; t_jac="n/a"; t_native="n/a"; t_cpp="n/a"
t_jac_compile="n/a"; t_jac_run="n/a"

# The server-backend leg pins the old Python codespace via a throwaway
# jac.toml; make sure it never outlives this script.
cleanup() { rm -f jac.toml; }
trap cleanup EXIT

# Warm the Jac compiler/bytecode cache so the one-time "Setting up Jac for first
# use" bootstrap does not pollute the timed runs below. (-b 1 = single game.)
echo "Warming caches (untimed)..."
printf '[project]\nname = "chess"\n\n[build]\ndefault_codespace = "server"\n' > jac.toml
jac run chess.jac -b 1 >/dev/null 2>&1
rm -f jac.toml
jac run chess.jac -b 1 >/dev/null 2>&1
echo "warm."
echo

echo "=============================================="
echo "1) Python"
echo "Running: time python3 other_langs/chess.py -b 20"
echo "=============================================="
_s=$(date +%s.%N); time python3 other_langs/chess.py -b 20; _e=$(date +%s.%N)
t_python=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
echo "interesting..."
sleep 1

echo
echo "=============================================="
echo "2) Jac, server backend (Python bytecode)"
echo "Pinned via jac.toml: [build] default_codespace = \"server\""
echo "Running: time jac run chess.jac -b 20"
echo "=============================================="
printf '[project]\nname = "chess"\n\n[build]\ndefault_codespace = "server"\n' > jac.toml
_s=$(date +%s.%N); time jac run chess.jac -b 20; _e=$(date +%s.%N)
t_server=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
rm -f jac.toml
echo "interesting..."
sleep 1

echo
echo "=============================================="
echo "3) Jac, native by default (compiles on run)"
echo "Running: time jac run chess.jac -b 20"
echo "=============================================="
# The default codespace is native: every run compiles the module natively. A
# 1-game run is almost all compile (native run of one game is ~0.1s), so it
# stands in for the compile cost and the 20-game total minus it is the run.
echo "  compile proxy: jac run chess.jac -b 1"
_s=$(date +%s.%N); jac run chess.jac -b 1 >/dev/null 2>&1; _e=$(date +%s.%N)
t_jac_compile=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
_s=$(date +%s.%N); time jac run chess.jac -b 20; _e=$(date +%s.%N)
t_jac=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
t_jac_run=$(awk "BEGIN{printf \"%.3f\", $t_jac-$t_jac_compile}")
echo "interesting..."
sleep 1

echo
echo "=============================================="
echo "4) Native binary (AOT compile, then run)"
echo "Running: jac nacompile chess.jac  then  time ./chess -b 20"
echo "=============================================="
jac nacompile chess.jac
_s=$(date +%s.%N); time ./chess -b 20; _e=$(date +%s.%N)
t_native=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
echo "interesting..."
sleep 1

echo
echo "=============================================="
echo "5) C++ reference (faithful OOP port of the Jac types)"
echo "Running: c++ -O2 -o chess_cpp other_langs/chess.cpp  then  time ./chess_cpp -b 20"
echo "=============================================="
c++ -O2 -o chess_cpp other_langs/chess.cpp
_s=$(date +%s.%N); time ./chess_cpp -b 20; _e=$(date +%s.%N)
t_cpp=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
echo "interesting..."

echo
echo "=================== RESULTS (20-game benchmark) ==================="
printf "%-38s %12s\n" "Backend" "Wall time (s)"
printf "%-38s %12s\n" "--------------------------------------" "------------"
printf "%-38s %12s\n" "1) Python (chess.py)"                  "$t_python"
printf "%-38s %12s\n" "2) Jac, server backend (pinned)"       "$t_server"
printf "%-38s %12s   (compile ~%s + run ~%s)\n" "3) Jac, native default"     "$t_jac" "$t_jac_compile" "$t_jac_run"
printf "%-38s %12s\n" "4) Native binary (AOT, run only)"      "$t_native"
printf "%-38s %12s\n" "5) C++ reference (faithful OOP)"        "$t_cpp"
echo "==================================================================="
