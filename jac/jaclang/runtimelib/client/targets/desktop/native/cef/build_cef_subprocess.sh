#!/usr/bin/env bash
# Build cef-subprocess: splice cef_platform.na.jac into cef_subprocess.na.jac.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

BUILD_DIR="$HERE/.build"
mkdir -p "$BUILD_DIR"
BUILD_SRC="$BUILD_DIR/cef_subprocess_build.na.jac"
BIN="$HERE/cef-subprocess"
JAC_BIN="${JAC_BIN:-jac}"

command -v "$JAC_BIN" >/dev/null 2>&1 || { echo "ERROR: jac not found: $JAC_BIN" >&2; exit 1; }

awk -v plat="$HERE/cef_platform.na.jac" '
  /^# PLATFORM$/ { while ((getline line < plat) > 0) print line; next }
  /^# ENTRY$/ { next }
  { print }
' "$HERE/cef_subprocess.na.jac" > "$BUILD_SRC"

echo ">> compiling cef-subprocess (jac nacompile)"
"$JAC_BIN" nacompile "$BUILD_SRC" -o "$BIN"

if command -v patchelf >/dev/null 2>&1; then
    patchelf --set-rpath '$ORIGIN' "$BIN" 2>/dev/null || \
        echo "WARNING: patchelf could not set rpath (section headers stripped); libcef.so must be on LD_LIBRARY_PATH at runtime" >&2
else
    echo "WARNING: patchelf not found; libcef.so must be on LD_LIBRARY_PATH at runtime" >&2
fi

echo ">> built: $BIN ($(stat -c%s "$BIN") bytes)"
echo "OK."
