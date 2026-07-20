#!/usr/bin/env bash
# Umbrella: run both experiment families end to end.
#   ./run_all.sh              # native-bridge suite, then cross-runtime suite
# Arguments are forwarded to each family's measurement harness only; invoke
# run_bridges.sh / run_xruntime.sh directly for per-family options.
set -euo pipefail
cd "$(dirname "$0")"

./run_bridges.sh "$@"
./run_xruntime.sh "$@"

echo "interopbench complete (native bridges + cross-runtime)"
