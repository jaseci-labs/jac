#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1/3 differential identity and manifest gate =="
./ci.sh

echo "== 2/3 native-bridge measurement =="
jac run harness/measure.jac "$@"

echo "== 3/3 native interop audit =="
jac run harness/audit.jac

echo "native-bridge measurement and audit complete"
