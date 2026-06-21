#!/usr/bin/env bash
# Install the native dependencies needed to build a Jac-native desktop host
# (Phase 0): a C/C++ toolchain + GTK3 + WebKitGTK dev headers.
#
# Targets Debian/Ubuntu (incl. WSL2). WebKitGTK is the OS-native web engine the
# `webview` C library wraps on Linux; build-essential is required because the
# webview project ships no prebuilt Linux .so, so we compile libwebview.so once.
#
# Usage:  sudo ./install_webkit_deps.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "This script installs system packages and must run as root." >&2
    echo "Re-run with:  sudo $0" >&2
    exit 1
fi

echo ">> apt-get update"
apt-get update

# Base toolchain shared by every webkit variant.
BASE_PKGS=(build-essential pkg-config libgtk-3-dev)

# Prefer the modern WebKitGTK 4.1 (libsoup-3); fall back to 4.0, then 6.0.
WEBKIT_PKG=""
for cand in libwebkit2gtk-4.1-dev libwebkit2gtk-4.0-dev libwebkitgtk-6.0-dev; do
    if apt-cache show "${cand}" >/dev/null 2>&1; then
        WEBKIT_PKG="${cand}"
        break
    fi
done

if [[ -z "${WEBKIT_PKG}" ]]; then
    echo "ERROR: no WebKitGTK dev package available in apt sources." >&2
    echo "Tried: libwebkit2gtk-4.1-dev libwebkit2gtk-4.0-dev libwebkitgtk-6.0-dev" >&2
    exit 1
fi

echo ">> installing: ${BASE_PKGS[*]} ${WEBKIT_PKG}"
apt-get install -y "${BASE_PKGS[@]}" "${WEBKIT_PKG}"

echo
echo ">> verifying toolchain"
gcc --version | head -1

# Report the pkg-config module name the build will use.
RESOLVED=""
for mod in webkit2gtk-4.1 webkit2gtk-4.0 webkitgtk-6.0; do
    if pkg-config --exists "${mod}" 2>/dev/null; then
        RESOLVED="${mod}"
        echo "WebKitGTK module: ${mod} ($(pkg-config --modversion "${mod}"))"
        break
    fi
done

if [[ -z "${RESOLVED}" ]]; then
    echo "ERROR: WebKitGTK installed but no pkg-config module resolved." >&2
    exit 1
fi

echo
echo "OK. WebKitGTK ready (${RESOLVED}). Next: build libwebview.so + webview.na.jac."
