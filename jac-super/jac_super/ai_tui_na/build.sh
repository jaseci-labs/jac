#!/usr/bin/env bash
# Build the NA TUI binary — nacompile only, no gcc, no custom C.
# Run from any directory; script resolves paths relative to its own location.

set -euo pipefail

QUICK=0
for arg in "$@"; do
    case "$arg" in
        --quick) QUICK=1 ;;
    esac
done

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

# ── build main NA binary (subprocess fallback renderer) ──────────────────────
echo "==> Compiling jac-na-tui ..."
"${JAC[@]}" nacompile tui.na.jac -o bin/jac-na-tui

echo "==> Done. Binary: $SCRIPT_DIR/bin/jac-na-tui"

# ── build in-process shared library (host.na.jac :pub surface, plan §5/§11.2) ─
# Explicit -o keeps the exact path (no lib<stem>.so renaming); the sv host
# ctypes.CDLL's this. Needs the PT_GNU_STACK compiler fix (§11.1, already landed)
# so CPython's dlopen accepts the .so on a hardened kernel.
echo "==> Compiling libtui.so (in-process host) ..."
"${JAC[@]}" nacompile host.na.jac --shared -o bin/libtui.so

echo "==> Done. Shared lib: $SCRIPT_DIR/bin/libtui.so"

if [ "$QUICK" -eq 1 ]; then
    echo "==> Quick build complete (skipped tests)."
    exit 0
fi

# ── headless logic tests (no TTY needed) ─────────────────────────────────────
echo "==> Building + running picker logic tests ..."
"${JAC[@]}" nacompile test_pickers.na.jac -o bin/test_pickers
"$SCRIPT_DIR/bin/test_pickers"
echo "==> Tests passed."

# ── headless host gate: load libtui.so under CPython, parse+render (no TTY) ───
echo "==> Running in-process host gate (ctypes) ..."
if [ -x "$REPO_VENV/bin/python" ]; then
    PYBIN="$REPO_VENV/bin/python"
else
    PYBIN="python3"
fi
"$PYBIN" "$SCRIPT_DIR/test_host.py"
echo "==> Host gate passed."

# ── quick smoke-test ─────────────────────────────────────────────────────────
echo "==> Smoke-test (piped stdin, expect non-zero exit) ..."
echo "---" | timeout 2 "$SCRIPT_DIR/bin/jac-na-tui" || true
echo "==> Build complete."
