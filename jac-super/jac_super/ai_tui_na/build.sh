#!/usr/bin/env bash
# Build the NA TUI binary — nacompile only, no gcc, no Bun, no custom C.
# Run from any directory; script resolves paths relative to its own location.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── resolve the jaclang to build with ───────────────────────────────────────
# Prefer the repo's editable jaclang (the venv at the repo root) over any global
# `jac` on PATH — a global uv-tool install can be stale and miss compiler fixes
# this TUI depends on (e.g. multi-`with entry` codegen).
REPO_VENV="$SCRIPT_DIR/../../../.venv"
if [ -x "$REPO_VENV/bin/python" ]; then
    JAC=("$REPO_VENV/bin/python" -m jaclang)
    echo "==> Using repo jaclang: $REPO_VENV/bin/python -m jaclang"
else
    JAC=(jac)
    echo "==> Using jac on PATH (no repo .venv found)"
fi

mkdir -p bin

# ── build main NA binary ────────────────────────────────────────────────────
echo "==> Compiling jac-na-tui ..."
"${JAC[@]}" nacompile tui.na.jac -o bin/jac-na-tui

echo "==> Done. Binary: $SCRIPT_DIR/bin/jac-na-tui"

# ── headless logic tests (no TTY needed) ─────────────────────────────────────
echo "==> Building + running picker logic tests ..."
"${JAC[@]}" nacompile test_pickers.na.jac -o bin/test_pickers
"$SCRIPT_DIR/bin/test_pickers"
echo "==> Tests passed."

# ── quick smoke-test ─────────────────────────────────────────────────────────
echo "==> Smoke-test (piped stdin, expect non-zero exit) ..."
echo "---" | timeout 2 "$SCRIPT_DIR/bin/jac-na-tui" || true
echo "==> Build complete."
