#!/usr/bin/env bash
# Build libcef_shim.so — the C bridge between Jac FFI and CEF's vtable C API.
#
# Requires:
#   - cef_dist/libcef.so (from fetch_libcef.sh)
#   - cef_headers/include/ (CEF SDK headers, staged by fetch_libcef.sh)
#   - gcc with -fPIC
#
# Output: ./libcef_shim.so (SONAME=libcef_shim.so) beside this script.
# Re-run is idempotent: rebuilds when cef_shim.c or libcef.so changes.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

CEF_DIST="$HERE/cef_dist"
CEF_HEADERS="$HERE/cef_headers"
SHIM_SRC="$HERE/cef_shim.c"
SHIM_SO="$HERE/libcef_shim.so"

# --- Prerequisites -----------------------------------------------------------
command -v gcc >/dev/null 2>&1 || {
    echo "ERROR: gcc not found (install build-essential)." >&2
    exit 1
}

if [ ! -f "$CEF_DIST/libcef.so" ]; then
    echo "ERROR: $CEF_DIST/libcef.so not found. Run fetch_libcef.sh first." >&2
    exit 1
fi

if [ ! -f "$CEF_HEADERS/include/capi/cef_app_capi.h" ]; then
    echo "ERROR: CEF headers not found at $CEF_HEADERS/include/." >&2
    echo "       Re-run fetch_libcef.sh to stage headers from the CEF tarball." >&2
    exit 1
fi

# --- Compile -----------------------------------------------------------------
BUILD_DIR="$HERE/.build"
mkdir -p "$BUILD_DIR"

echo ">> compiling libcef_shim.so"
gcc -std=c11 -DNDEBUG -fPIC -O2 -Wall -Wextra \
    -I"$CEF_HEADERS" \
    -c "$SHIM_SRC" -o "$BUILD_DIR/cef_shim.o"

gcc -shared -fPIC -Wl,-soname,libcef_shim.so \
    "$BUILD_DIR/cef_shim.o" \
    -L"$CEF_DIST" -lcef \
    -Wl,-rpath,'$ORIGIN' \
    -o "$SHIM_SO"

echo ">> built: $SHIM_SO ($(stat -c%s "$SHIM_SO") bytes)"
echo ">> DT_NEEDED:"
readelf -d "$SHIM_SO" | grep NEEDED | sed 's/^/   /'
echo "OK."
