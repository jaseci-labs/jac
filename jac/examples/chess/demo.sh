#!/usr/bin/env bash
# Benchmark the same chess engine across every Jac backend, 20-game run each.
# Run from this directory with the project venv active (provides python3 + jac).

# Collected wall-clock times for the summary table (filled in per section).
t_python="n/a"; t_jac="n/a"; t_autonative="n/a"; t_na="n/a"; t_native="n/a"; t_cpp="n/a"
t_na_compile="n/a"; t_na_run="n/a"
t_autonative_compile="n/a"; t_autonative_run="n/a"

# Warm the Jac compiler/bytecode cache so the one-time "Setting up Jac for first
# use" bootstrap does not pollute the timed runs below. (-b 1 = single game.)
echo "Warming caches (untimed)..."
jac run chess.jac -b 1 >/dev/null 2>&1
jac run --autonative chess.jac -b 1 >/dev/null 2>&1
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
echo "2) Jac (default backend)"
echo "Running: time jac run chess.jac -b 20"
echo "=============================================="
_s=$(date +%s.%N); time jac run chess.jac -b 20; _e=$(date +%s.%N)
t_jac=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
echo "interesting..."
sleep 1

echo
echo "=============================================="
echo "3) Jac, auto-native promotion (compiles on run)"
echo "Running: time jac run --autonative chess.jac -b 20"
echo "=============================================="
# Compiles to native on every run; a 1-game run is almost all compile, so it
# stands in for the compile cost and the 20-game total minus it is the run.
echo "  compile proxy: jac run --autonative chess.jac -b 1"
_s=$(date +%s.%N); jac run --autonative chess.jac -b 1 >/dev/null 2>&1; _e=$(date +%s.%N)
t_autonative_compile=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
_s=$(date +%s.%N); time jac run --autonative chess.jac -b 20; _e=$(date +%s.%N)
t_autonative=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
t_autonative_run=$(awk "BEGIN{printf \"%.3f\", $t_autonative-$t_autonative_compile}")
echo "interesting..."
sleep 1

echo
echo "=============================================="
echo "4) Jac run of a .na.jac (native source by extension)"
echo "Copying chess.jac -> chess.na.jac (+ impl), then: time jac run chess.na.jac -b 20"
echo "=============================================="
cp chess.jac chess.na.jac
cp chess.impl.jac chess.na.impl.jac
# .na.jac compiles to native on every run. A 1-game run is almost all compile
# (native run of one game is ~0.1s), so it stands in for the compile cost; the
# 20-game total minus that approximates the native run portion.
echo "  compile proxy: jac run chess.na.jac -b 1"
_s=$(date +%s.%N); jac run chess.na.jac -b 1 >/dev/null 2>&1; _e=$(date +%s.%N)
t_na_compile=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
_s=$(date +%s.%N); time jac run chess.na.jac -b 20; _e=$(date +%s.%N)
t_na=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
t_na_run=$(awk "BEGIN{printf \"%.3f\", $t_na-$t_na_compile}")
rm -f chess.na.jac chess.na.impl.jac
echo "interesting..."
sleep 1

echo
echo "=============================================="
echo "5) Native binary (AOT compile, then run)"
echo "Running: jac nacompile chess.jac  then  time ./chess -b 20"
echo "=============================================="
jac nacompile chess.jac
_s=$(date +%s.%N); time ./chess -b 20; _e=$(date +%s.%N)
t_native=$(awk "BEGIN{printf \"%.3f\", $_e-$_s}")
echo "interesting..."
sleep 1

echo
echo "=============================================="
echo "6) C++ reference (faithful OOP port of the Jac types)"
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
printf "%-38s %12s\n" "2) Jac, default backend"               "$t_jac"
printf "%-38s %12s   (compile ~%s + run ~%s)\n" "3) Jac, --autonative"       "$t_autonative" "$t_autonative_compile" "$t_autonative_run"
printf "%-38s %12s   (compile ~%s + run ~%s)\n" "4) Jac run of chess.na.jac" "$t_na" "$t_na_compile" "$t_na_run"
printf "%-38s %12s\n" "5) Native binary (AOT, run only)"      "$t_native"
printf "%-38s %12s\n" "6) C++ reference (faithful OOP)"        "$t_cpp"
echo "==================================================================="
