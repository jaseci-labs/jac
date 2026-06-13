#!/usr/bin/env bash
# Build libcef_dispatch.so from cef_dispatch.na.jac via jac nacompile --shared.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

SRC="$HERE/cef_dispatch.na.jac"
SO="$HERE/libcef_dispatch.so"

command -v jac >/dev/null 2>&1 || { echo "ERROR: jac not found on PATH." >&2; exit 1; }

echo ">> compiling libcef_dispatch.so (jac nacompile --shared)"
jac nacompile --shared "$SRC" -o "$SO"

# Ensure libcef.so is found in the same directory at runtime.
if command -v patchelf >/dev/null 2>&1; then
    patchelf --set-rpath '$ORIGIN' "$SO"
else
    echo "WARNING: patchelf not found; libcef.so must be on LD_LIBRARY_PATH at runtime" >&2
fi

echo ">> built: $SO ($(stat -c%s "$SO") bytes)"
echo "OK."
