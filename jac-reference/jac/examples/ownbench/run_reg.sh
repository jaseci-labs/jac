#!/usr/bin/env bash
# One-command region-experiment reproduction (osp_regions paper):
# compiles the four region kernels, generates the bare rgraph baseline
# with rerase.jac, runs the full differential + measurement matrix, and
# writes results/regions_results.json.
#
#   ./run_reg.sh            # full sizes, 10 invocations per cell
#   ./run_reg.sh --quick    # small sizes, fast sanity pass
set -euo pipefail
cd "$(dirname "$0")"

jac run harness/rbench.jac "$@"

echo "region experiments complete: results/regions_results.json"
