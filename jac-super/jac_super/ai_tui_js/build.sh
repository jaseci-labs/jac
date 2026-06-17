#!/usr/bin/env bash
# Compile Jac sidecar sources (*.cl.jac) to runnable JS under dist/.
# Uses `jac jac2js` only — no project-local Python build script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REPO_VENV="$SCRIPT_DIR/../../../.venv"
if [ -x "$REPO_VENV/bin/python" ]; then
    JAC=("$REPO_VENV/bin/python" -m jaclang)
    echo "==> Using repo jaclang: $REPO_VENV/bin/python -m jaclang"
else
    JAC=(jac)
    echo "==> Using jac on PATH (no repo .venv found)"
fi

mkdir -p dist

count=0
for src in *.cl.jac; do
    [ -f "$src" ] || continue
    base="${src%.cl.jac}"
    out="dist/${base}.js"
    echo "  $src -> $out"
    "${JAC[@]}" jac2js "$src" > "$out"
    count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
    echo "ERROR: no *.cl.jac sources found" >&2
    exit 1
fi

echo "==> Built $count module(s) into $SCRIPT_DIR/dist"
