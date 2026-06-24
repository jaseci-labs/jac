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
# Exact CEF version to fetch. The struct/vtable offsets in cef_dispatch.na.jac
# are verified against this exact build, so the runtime ABI must match it byte
# for byte -- "latest 119.x" is not good enough (a point release can shift a
# struct). The single source of truth is cef_sums.lock (the `# version:`
# directive); CEF_VERSION may override it for a deliberate, manual bump.
#
# Pinned to 119.x — CEF 133+ uses the Universal C API with version checks
# that fail on Spotify CDN builds (cef_api_version returns -1, causing all
# CToCpp wrappers to crash with "invalid version -1"). CEF 119 uses the
# legacy C API which works correctly with client-side vtable structs.
SUMS_LOCK="$HERE/cef_sums.lock"
if [ ! -f "$SUMS_LOCK" ]; then
    echo "ERROR: missing trust anchor $SUMS_LOCK" >&2
    exit 1
fi
LOCKED_VERSION="$(sed -n 's/^# version:[[:space:]]*//p' "$SUMS_LOCK" | head -1)"
CEF_VERSION="${CEF_VERSION:-$LOCKED_VERSION}"
if [ -z "$CEF_VERSION" ]; then
    echo "ERROR: no '# version:' directive in $SUMS_LOCK" >&2
    exit 1
fi
# Major-version prefix, kept for staging stamps and user-facing messages.
CEF_MAJOR="${CEF_VERSION%%.*}"

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
    && [ "$(cat "$VERSION_STAMP")" = "${CEF_VERSION}" ] \
    && [ -f "$DIST_DIR/libcef.so" ] \
    && [ -f "$HEADERS_MARKER" ]; then
    echo ">> CEF ${CEF_VERSION} already staged in $DIST_DIR"
    exit 0
fi

# --- Determine platform -----------------------------------------------
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  PLAT_TAG="linux64" ;;
    aarch64) PLAT_TAG="linuxarm64" ;;
    *)       echo "ERROR: unsupported architecture $ARCH" >&2; exit 1 ;;
esac

# --- Resolve the exact pinned archive ----------------------------------
# The filename is fully determined by the pinned version + platform, so it is
# derived directly rather than discovered from the index. The in-tree
# cef_sums.lock is the authoritative trust anchor; the live index is consulted
# only as a secondary cross-check that surfaces a tampered release host.
ARCHIVE="cef_binary_${CEF_VERSION}_${PLAT_TAG}.tar.bz2"
RESOLVED="https://cef-builds.spotifycdn.com/$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$ARCHIVE")"

# Authoritative expected digest: the in-tree pin (fail closed if absent).
EXPECTED_SHA1="$(python3 -c "
import sys
want = sys.argv[1]
for line in open('$SUMS_LOCK'):
    line = line.strip()
    if not line or line.startswith('#'):
        continue
    parts = line.split()
    if len(parts) == 2 and parts[1] == want:
        print(parts[0]); break
" "$ARCHIVE")"

if [ -z "$EXPECTED_SHA1" ]; then
    echo "ERROR: no pinned SHA-1 for $ARCHIVE in cef_sums.lock." >&2
    echo "  Refusing to download an unverified CEF archive. Add the digest" >&2
    echo "  (verified out-of-band) to cef_sums.lock for this version/platform." >&2
    exit 1
fi

echo ">> resolving CEF ${CEF_VERSION} for ${PLAT_TAG}"
echo ">> resolved: $RESOLVED"

# Secondary cross-check: the digest the live index advertises for this exact
# archive must agree with the in-tree pin. A mismatch means the release host
# (or our pin) is stale/tampered -- stop before downloading 700MB+.
API_URL="https://cef-builds.spotifycdn.com/index.json"
TMP_JSON="$HERE/.cef_index.json"
if curl -fsSL --retry 3 -o "$TMP_JSON" "$API_URL" 2>/dev/null; then
    INDEX_SHA1="$(python3 -c "
import json, sys
want = sys.argv[1]
idx = json.load(open('$TMP_JSON'))
for v in idx.get('$PLAT_TAG', {}).get('versions', []):
    for f in v.get('files', []):
        if f.get('name') == want:
            print(f.get('sha1', '')); sys.exit(0)
" "$ARCHIVE" 2>/dev/null || true)"
    rm -f "$TMP_JSON"
    if [ -n "$INDEX_SHA1" ] && [ "$INDEX_SHA1" != "$EXPECTED_SHA1" ]; then
        echo "ERROR: index SHA-1 for $ARCHIVE disagrees with cef_sums.lock" >&2
        echo "  pinned: $EXPECTED_SHA1" >&2
        echo "  index:  $INDEX_SHA1" >&2
        echo "  The release host or the in-tree pin is out of date/tampered." >&2
        exit 1
    fi
else
    echo ">> note: could not fetch index for cross-check; relying on in-tree pin" >&2
fi

if [ ! -f "$CACHED_TARBALL" ]; then
    echo ">> downloading CEF binary distribution..."
    curl -fsSL --retry 3 -o "$CACHED_TARBALL" "$RESOLVED"
else
    echo ">> using cached tarball ($CACHED_TARBALL)"
fi

# --- Verify SHA-1 checksum against the in-tree pin (fail closed) -------
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
echo "${CEF_VERSION}" > "$VERSION_STAMP"

# --- Report ------------------------------------------------------------
echo ">> staged CEF ${CEF_VERSION} in $DIST_DIR"
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
