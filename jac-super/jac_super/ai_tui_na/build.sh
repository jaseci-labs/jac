#!/usr/bin/env bash
# Build the NA TUI binary and its C helper libraries.
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

# ── locate libopentui.so ────────────────────────────────────────────────────
OPENTUI_SO=$(find ~/.bun -name "libopentui.so" -path "*linux-x64*" 2>/dev/null | head -1 || true)
if [ -z "$OPENTUI_SO" ]; then
    echo "ERROR: libopentui.so not found. Run: bun add -g @opentui/core" >&2
    exit 1
fi
echo "==> Found libopentui.so: $OPENTUI_SO"

# Make libopentui.so visible in the working dir for nacompile link-time resolution
# (import from .opentui looks for libopentui.so next to the .na.jac files)
cp "$OPENTUI_SO" ./libopentui.so

# ── compile C helpers ───────────────────────────────────────────────────────
echo "==> Compiling libtui_helpers.so ..."
gcc -O2 -shared -fPIC -o libtui_helpers.so tui_helpers.c

echo "==> Compiling libopentui_shim.so (linked against libopentui.so) ..."
gcc -O2 -shared -fPIC \
    -Wl,-rpath,'$ORIGIN' \
    -o libopentui_shim.so opentui_shim.c \
    ./libopentui.so

# ── FFI tests ───────────────────────────────────────────────────────────────
echo "==> Running FFI scalar tests ..."
"${JAC[@]}" nacompile test_ffi.na.jac -o bin/test_ffi
cp libtui_helpers.so libopentui_shim.so libopentui.so bin/
echo "--- FFI test output ---"
bin/test_ffi 2>&1 || true
echo "--- end FFI test ---"

# ── build main NA binary ────────────────────────────────────────────────────
echo "==> Compiling jac-na-tui ..."
"${JAC[@]}" nacompile tui.na.jac -o bin/jac-na-tui

# ── deploy all .so files next to binary ─────────────────────────────────────
echo "==> Deploying shared libraries to bin/ ..."
cp libtui_helpers.so libopentui_shim.so bin/
cp "$OPENTUI_SO" bin/libopentui.so

# Clean up working-dir copy of libopentui.so (only needed for nacompile)
rm -f ./libopentui.so

echo "==> Done. Binary: $SCRIPT_DIR/bin/jac-na-tui"

# ── quick smoke-test ─────────────────────────────────────────────────────────
echo "==> Smoke-test (piped stdin, expect non-zero exit) ..."
echo "---" | timeout 2 "$SCRIPT_DIR/bin/jac-na-tui" || true
echo "==> Build complete."
