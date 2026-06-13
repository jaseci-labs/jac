#!/usr/bin/env bash
# Build cef-subprocess from cef_subprocess.na.jac via jac nacompile.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

SRC="$HERE/cef_subprocess.na.jac"
BIN="$HERE/cef-subprocess"

command -v jac >/dev/null 2>&1 || { echo "ERROR: jac not found on PATH." >&2; exit 1; }

echo ">> compiling cef-subprocess (jac nacompile)"
jac nacompile "$SRC" -o "$BIN"

# Ensure libcef.so is found in the same directory at runtime.
if command -v patchelf >/dev/null 2>&1; then
    patchelf --set-rpath '$ORIGIN' "$BIN" 2>/dev/null || \
        echo "WARNING: patchelf could not set rpath (section headers stripped); libcef.so must be on LD_LIBRARY_PATH at runtime" >&2
else
    echo "WARNING: patchelf not found; libcef.so must be on LD_LIBRARY_PATH at runtime" >&2
fi

echo ">> built: $BIN ($(stat -c%s "$BIN") bytes)"
echo "OK."
