#!/usr/bin/env bash
# Umbrella: run both experiment families end to end.
#   ./run_all.sh              # ownership suite, then region suite
# Arguments are not forwarded; invoke run_own.sh / run_reg.sh directly
# for per-family options.
set -euo pipefail
cd "$(dirname "$0")"

./run_own.sh
./run_reg.sh

echo "ownbench complete (ownership + regions)"
