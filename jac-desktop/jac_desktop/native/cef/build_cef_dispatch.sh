#!/usr/bin/env bash
# Build libcef_dispatch.so: splice cef_platform.na.jac into cef_dispatch.na.jac.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

BUILD_DIR="$HERE/.build"
mkdir -p "$BUILD_DIR"
BUILD_SRC="$BUILD_DIR/cef_dispatch_build.na.jac"
SO="$HERE/libcef_dispatch.so"

command -v jac >/dev/null 2>&1 || { echo "ERROR: jac not found on PATH." >&2; exit 1; }

awk -v plat="$HERE/cef_platform.na.jac" '
  /^# PLATFORM$/ { while ((getline line < plat) > 0) print line; next }
  { print }
' "$HERE/cef_dispatch.na.jac" > "$BUILD_SRC"

echo ">> compiling libcef_dispatch.so (jac nacompile --shared)"
jac nacompile --shared "$BUILD_SRC" -o "$SO"

if command -v patchelf >/dev/null 2>&1; then
    patchelf --set-rpath '$ORIGIN' "$SO"
else
    echo "WARNING: patchelf not found; libcef.so must be on LD_LIBRARY_PATH at runtime" >&2
fi

echo ">> built: $SO ($(stat -c%s "$SO") bytes)"
echo "OK."
