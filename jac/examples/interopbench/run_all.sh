#!/usr/bin/env bash
# Umbrella: run both experiment families end to end.
#   ./run_all.sh                         # native-bridge suite only
#   ./run_all.sh --experimental          # both suites (cross-runtime opt-in)
# Arguments after --experimental are forwarded to the cross-runtime harness.
set -euo pipefail
cd "$(dirname "$0")"

if [[ "${1:-}" == "--experimental" ]]; then
  shift
  ./run_bridges.sh
  ./run_xruntime.sh --experimental "$@"
  echo "interopbench complete (native bridges + cross-runtime)"
else
  ./run_bridges.sh "$@"
  echo "interopbench native-bridge suite complete"
  echo "cross-runtime cells are experimental; use ./run_all.sh --experimental"
fi
