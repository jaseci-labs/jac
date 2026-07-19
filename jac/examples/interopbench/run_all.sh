#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

./run_bridges.sh "$@"

echo "interopbench complete (implemented family: native bridges)"
