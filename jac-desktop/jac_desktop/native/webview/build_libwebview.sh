#!/usr/bin/env bash
# Build libwebview.so from the upstream webview/webview C library.
#
# This is the OS-native web engine wrapper a Jac-native desktop host binds
# against by its logical name (`import from "libwebview.so" { ... }`). The
# webview project ships no prebuilt Linux .so, so we compile it once here from
# the pinned single-header source against the system WebKitGTK.
#
# Output: ./libwebview.so (SONAME=libwebview.so) beside this script, plus the
# resolved webkit module recorded in ./.webkit_module for downstream scripts.
#
# Re-run is idempotent: it rebuilds from the cached header.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

WEBVIEW_VERSION="${WEBVIEW_VERSION:-0.12.0}"
HEADER_URL="https://raw.githubusercontent.com/webview/webview/${WEBVIEW_VERSION}/core/include/webview/webview.h"
BUILD_DIR="$HERE/.build"
mkdir -p "$BUILD_DIR"

# --- 0. Toolchain check ------------------------------------------------------
command -v g++ >/dev/null 2>&1 || { echo "ERROR: g++ not found (install build-essential)." >&2; exit 1; }
command -v pkg-config >/dev/null 2>&1 || { echo "ERROR: pkg-config not found." >&2; exit 1; }

# Resolve the WebKitGTK pkg-config module (4.1 preferred, then 4.0).
WEBKIT_MOD=""
for mod in webkit2gtk-4.1 webkit2gtk-4.0; do
    if pkg-config --exists "$mod" 2>/dev/null; then WEBKIT_MOD="$mod"; break; fi
done
[ -n "$WEBKIT_MOD" ] || { echo "ERROR: no webkit2gtk-4.x pkg-config module found." >&2; exit 1; }
echo ">> webkit module : $WEBKIT_MOD ($(pkg-config --modversion "$WEBKIT_MOD"))"
echo "$WEBKIT_MOD" > "$HERE/.webkit_module"

# --- 1. Fetch pinned header (cached) -----------------------------------------
HEADER="$BUILD_DIR/webview.h"
if [ ! -f "$HEADER" ]; then
    echo ">> fetching webview $WEBVIEW_VERSION header"
    curl -fsSL --retry 3 -o "$HEADER" "$HEADER_URL"
else
    echo ">> using cached header ($HEADER)"
fi

# --- 2. Compile the C-API implementation into a shared library ---------------
# WEBVIEW_BUILD_SHARED exports the C API; the single header pulls in its own
# webkit2gtk implementation (WEBVIEW_GTK is auto-selected on Linux).
cat > "$BUILD_DIR/webview_impl.cc" <<'EOF'
#include "webview.h"
EOF

echo ">> compiling libwebview.so"
g++ -std=c++17 -DWEBVIEW_BUILD_SHARED -fPIC -O2 \
    -I"$BUILD_DIR" \
    $(pkg-config --cflags gtk+-3.0 "$WEBKIT_MOD") \
    -c "$BUILD_DIR/webview_impl.cc" -o "$BUILD_DIR/webview_impl.o"

g++ -shared -fPIC -Wl,-soname,libwebview.so \
    "$BUILD_DIR/webview_impl.o" \
    $(pkg-config --libs gtk+-3.0 "$WEBKIT_MOD") \
    -o "$HERE/libwebview.so"

# --- 3. Report ---------------------------------------------------------------
echo ">> built: $HERE/libwebview.so ($(stat -c%s "$HERE/libwebview.so") bytes)"
echo ">> exported C API symbols:"
nm -D --defined-only "$HERE/libwebview.so" | grep -E " T webview_" | awk '{print "   " $3}'
echo ">> DT_NEEDED:"
readelf -d "$HERE/libwebview.so" | grep NEEDED | sed 's/^/   /'
echo "OK."
