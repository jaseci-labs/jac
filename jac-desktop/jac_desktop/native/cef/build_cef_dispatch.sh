#!/usr/bin/env bash
# Build libcef_dispatch.so — thin C vtable dispatch wrappers for CEF.
#
# Required by cef.na.jac when CEF objects need method calls through their
# vtable pointers, or when data structs (cef_settings_t, cef_window_info_t,
# etc.) need allocation with correct C layout including cef_string_t fields.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

CEF_DIST="$HERE/cef_dist"
CEF_HEADERS="$HERE/cef_headers"
SRC="$HERE/cef_dispatch.c"
SO="$HERE/libcef_dispatch.so"

command -v gcc >/dev/null 2>&1 || { echo "ERROR: gcc not found." >&2; exit 1; }

if [ ! -f "$CEF_DIST/libcef.so" ]; then
    echo "ERROR: $CEF_DIST/libcef.so not found. Run fetch_libcef.sh first." >&2
    exit 1
fi

BUILD_DIR="$HERE/.build"
mkdir -p "$BUILD_DIR"

echo ">> compiling libcef_dispatch.so"
gcc -std=c11 -DNDEBUG -fPIC -O2 -Wall -Wextra \
    -I"$CEF_HEADERS" \
    -c "$SRC" -o "$BUILD_DIR/cef_dispatch.o"

gcc -shared -fPIC -Wl,-soname,libcef_dispatch.so \
    "$BUILD_DIR/cef_dispatch.o" \
    -L"$CEF_DIST" -lcef \
    -Wl,-rpath,'$ORIGIN' \
    -o "$SO"

echo ">> built: $SO ($(stat -c%s "$SO") bytes)"
echo "OK."
