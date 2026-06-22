#!/usr/bin/env bash
# Download and stage a pinned CEF prebuilt binary bundle.
#
# CEF (Chromium Embedded Framework) ships as a self-contained tarball with
# libcef.so, companion GPU libraries, ICU data, V8 snapshots, .pak resources,
# locale files, and the chrome-sandbox setuid helper. This script fetches a
# pinned version for the host platform and unpacks it into a staging directory
# that the CefDesktopTarget build pipeline copies from.
#
# Output: ./cef_dist/ beside this script, containing the full CEF runtime.
#
# Re-run is idempotent: it reuses a cached tarball and skips extraction if the
# staging directory already matches the pinned version.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

# --- Pin ---------------------------------------------------------------
# CEF major version to fetch. Finds the latest stable build matching this
# prefix. Update when moving to a new Chromium major version.
#
# Pinned to 119.x — CEF 133+ uses the Universal C API with version checks
# that fail on Spotify CDN builds (cef_api_version returns -1, causing all
# CToCpp wrappers to crash with "invalid version -1"). CEF 119 uses the
# legacy C API which works correctly with client-side vtable structs.
CEF_MAJOR="${CEF_MAJOR:-119}"

HEADERS_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --headers-only) HEADERS_ONLY=1 ;;
    esac
done

DIST_DIR="$HERE/cef_dist"
VERSION_STAMP="$DIST_DIR/.cef_version"
HEADERS_DIR="$HERE/cef_headers"
HEADERS_MARKER="$HEADERS_DIR/include/capi/cef_app_capi.h"
CACHED_TARBALL="$HERE/.cef_tarball.tar.bz2"

# --- Skip if headers-only and headers already staged ------------------
if [ "$HEADERS_ONLY" = "1" ] && [ -f "$HEADERS_MARKER" ]; then
    echo ">> CEF headers already staged in $HEADERS_DIR"
    exit 0
fi

# --- Skip if runtime + headers already staged -------------------------
if [ "$HEADERS_ONLY" = "0" ] \
    && [ -f "$VERSION_STAMP" ] \
    && [ "$(cat "$VERSION_STAMP")" = "${CEF_MAJOR}.x" ] \
    && [ -f "$DIST_DIR/libcef.so" ] \
    && [ -f "$HEADERS_MARKER" ]; then
    echo ">> CEF ${CEF_MAJOR}.x already staged in $DIST_DIR"
    exit 0
fi

# --- Determine platform -----------------------------------------------
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  PLAT_TAG="linux64" ;;
    aarch64) PLAT_TAG="linuxarm64" ;;
    *)       echo "ERROR: unsupported architecture $ARCH" >&2; exit 1 ;;
esac

# --- Fetch index and resolve download URL ------------------------------
echo ">> resolving CEF ${CEF_MAJOR}.x stable download URL for ${PLAT_TAG}"

API_URL="https://cef-builds.spotifycdn.com/index.json"
TMP_JSON="$HERE/.cef_index.json"
curl -fsSL --retry 3 -o "$TMP_JSON" "$API_URL" || {
    echo "ERROR: failed to fetch CEF index from $API_URL" >&2
    exit 1
}

# Extract the URL and SHA-1 for the pinned major version using python.
RESOLVED="$(python3 -c "
import json, urllib.parse, sys
with open('$TMP_JSON') as f:
    idx = json.load(f)
versions = idx.get('$PLAT_TAG', {}).get('versions', [])
for v in versions:
    if v.get('cef_version', '').startswith('${CEF_MAJOR}.') and v.get('channel') == 'stable':
        for f in v.get('files', []):
            name = f['name']
            if '${PLAT_TAG}.tar.bz2' in name and not any(s in name for s in ['client', 'minimal', 'tools']):
                url = 'https://cef-builds.spotifycdn.com/' + urllib.parse.quote(name)
                sha1 = f.get('sha1', '')
                print(url + ' ' + sha1)
                sys.exit(0)
print('', end='')
" 2>/dev/null || true)"

EXPECTED_SHA1="${RESOLVED#* }"
RESOLVED="${RESOLVED%% *}"

rm -f "$TMP_JSON"

if [ -z "$RESOLVED" ]; then
    echo "ERROR: could not resolve CEF ${CEF_MAJOR}.x tarball URL" >&2
    echo "Visit https://cef-builds.spotifycdn.com/ to find a matching build." >&2
    exit 1
fi

echo ">> resolved: $RESOLVED"

if [ ! -f "$CACHED_TARBALL" ]; then
    echo ">> downloading CEF binary distribution..."
    curl -fsSL --retry 3 -o "$CACHED_TARBALL" "$RESOLVED"
else
    echo ">> using cached tarball ($CACHED_TARBALL)"
fi

# --- Verify SHA-1 checksum ---------------------------------------------
if [ -n "$EXPECTED_SHA1" ]; then
    ACTUAL_SHA1="$(sha1sum "$CACHED_TARBALL" | cut -d' ' -f1)"
    if [ "$ACTUAL_SHA1" != "$EXPECTED_SHA1" ]; then
        echo "ERROR: SHA-1 mismatch for cached/downloaded tarball" >&2
        echo "  expected: $EXPECTED_SHA1" >&2
        echo "  actual:   $ACTUAL_SHA1" >&2
        echo "  Deleting corrupted tarball." >&2
        rm -f "$CACHED_TARBALL"
        exit 1
    fi
    echo ">> SHA-1 verified: $ACTUAL_SHA1"
else
    echo "WARNING: no SHA-1 available in index; skipping integrity check" >&2
fi

# --- Headers-only: extract headers then exit (no runtime download) ----
if [ "$HEADERS_ONLY" = "1" ]; then
    if [ ! -f "$HEADERS_MARKER" ]; then
        echo ">> extracting CEF SDK headers to $HEADERS_DIR (headers-only)"
        rm -rf "$HEADERS_DIR"
        python3 -c "
import tarfile, os, shutil
tb = '$CACHED_TARBALL'
out = '$HEADERS_DIR'
with tarfile.open(tb, 'r:bz2') as tf:
    for m in tf:
        parts = m.name.split('/', 1)
        if len(parts) < 2: continue
        rel = parts[1]
        if not rel.startswith('include/'): continue
        target = os.path.join(out, rel)
        if m.isdir():
            os.makedirs(target, exist_ok=True)
        else:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with tf.extractfile(m) as src, open(target, 'wb') as dst:
                shutil.copyfileobj(src, dst)
" || {
            echo "ERROR: CEF header extraction failed" >&2; exit 1
        }
    else
        echo ">> CEF SDK headers already staged in $HEADERS_DIR"
    fi
    echo "OK."
    exit 0
fi

# --- Extract runtime (skip if libcef.so already present) ---------------
if [ ! -f "$DIST_DIR/libcef.so" ]; then
echo ">> extracting CEF runtime to $DIST_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# The CEF tarball layout is:
#   <top>/Release/libcef.so, libEGL.so, libGLESv2.so, v8_context_snapshot.bin, chrome-sandbox
#   <top>/Resources/icudtl.dat, *.pak, locales/
# Use python to extract — GNU tar --wildcards is inconsistent across distros
# and the tarball is ~800MB (slow to list).
python3 -c "
import tarfile, os, shutil, sys
tb = '$CACHED_TARBALL'
out = '$DIST_DIR'
need = {'libcef.so', 'libEGL.so', 'libGLESv2.so', 'libvk_swiftshader.so',
        'vk_swiftshader_icd.json', 'v8_context_snapshot.bin',
        'chrome-sandbox', 'icudtl.dat'}
with tarfile.open(tb, 'r:bz2') as tf:
    for m in tf:
        parts = m.name.split('/', 1)
        if len(parts) < 2: continue
        rel = parts[1]
        base = rel.split('/')[-1]
        seg0 = rel.split('/')[0]
        want = False
        if base in need: want = True
        elif base.endswith('.pak'): want = True
        elif seg0 == 'locales' or rel.startswith('locales/'): want = True
        if not want: continue
        # Flatten Release/ and Resources/ prefixes
        flat = rel
        for pfx in ('Release/', 'Resources/', 'Debug/'):
            if flat.startswith(pfx): flat = flat[len(pfx):]; break
        target = os.path.join(out, flat)
        if m.isdir():
            os.makedirs(target, exist_ok=True)
        else:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with tf.extractfile(m) as src, open(target, 'wb') as dst:
                shutil.copyfileobj(src, dst)
" || {
    echo "ERROR: CEF extraction failed" >&2; exit 1
}
else
    echo ">> CEF runtime already present in $DIST_DIR"
fi

# --- Stamp version -----------------------------------------------------
echo "${CEF_MAJOR}.x" > "$VERSION_STAMP"

# --- Report ------------------------------------------------------------
echo ">> staged CEF ${CEF_MAJOR}.x in $DIST_DIR"
echo ">> key files:"
ls -lh "$DIST_DIR/libcef.so" 2>/dev/null | awk '{print "   " $NF ": " $5}' || true
echo ">> companion libraries:"
for f in libEGL.so libGLESv2.so chrome-sandbox; do
    if [ -f "$DIST_DIR/$f" ]; then echo "   $f ($(stat -c%s "$DIST_DIR/$f") bytes)"; fi
done
echo ">> locales: $(ls "$DIST_DIR/locales/" 2>/dev/null | wc -l) files"

# --- Stage CEF SDK headers (for build_cef_dispatch.sh, not shipped in the wheel) -
if [ ! -f "$HEADERS_MARKER" ]; then
    echo ">> extracting CEF SDK headers to $HEADERS_DIR"
    rm -rf "$HEADERS_DIR"
    python3 -c "
import tarfile, os, shutil
tb = '$CACHED_TARBALL'
out = '$HEADERS_DIR'
with tarfile.open(tb, 'r:bz2') as tf:
    for m in tf:
        parts = m.name.split('/', 1)
        if len(parts) < 2: continue
        rel = parts[1]
        if not rel.startswith('include/'): continue
        target = os.path.join(out, rel)
        if m.isdir():
            os.makedirs(target, exist_ok=True)
        else:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with tf.extractfile(m) as src, open(target, 'wb') as dst:
                shutil.copyfileobj(src, dst)
" || {
        echo "ERROR: CEF header extraction failed" >&2; exit 1
    }
else
    echo ">> CEF SDK headers already staged in $HEADERS_DIR"
fi

# Warn about chrome-sandbox setuid requirement.
if [ -f "$DIST_DIR/chrome-sandbox" ]; then
    if [ "$(stat -c%a "$DIST_DIR/chrome-sandbox" 2>/dev/null)" != "4755" ]; then
        echo ""
        echo "  ⚠  chrome-sandbox does NOT have setuid root (mode 4755)."
        echo "     The CEF subprocess will fail on Linux unless you either:"
        echo "       1. sudo chown root:root $DIST_DIR/chrome-sandbox && sudo chmod 4755 $DIST_DIR/chrome-sandbox"
        echo "       2. Pass --no-sandbox at runtime (security trade-off; OK for dev)."
    fi
fi

echo "OK."
