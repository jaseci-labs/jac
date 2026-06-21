#!/usr/bin/env bash
# Download + extract a python-build-standalone tree for the given platform into
# <dest>/python. Idempotent: a no-op if <dest>/python/PYTHON.json already exists.
# Used by build.zig so `zig build` is self-contained (no manual pbs step).
#
#   fetch-pbs.sh <os-arch> <dest-dir>
#     <os-arch>: macos-aarch64 | macos-x86_64 | linux-x86_64 | linux-aarch64
set -euo pipefail

OSARCH="${1:?os-arch (e.g. macos-aarch64)}"
DEST="${2:?dest dir}"

# Pinned pbs release. Must stay a non-LTO ('pgo', not 'pgo+lto') *full* archive:
# the launcher dlopens the shared libpython, so a full archive (with the .dylib/
# .so + lib-dynload) is required; non-LTO avoids LLVM-bitcode link issues.
PBS_TAG="20241206"
PBS_PY="3.12.8"
case "$OSARCH" in
  macos-aarch64) PLAT="aarch64-apple-darwin" ;;
  macos-x86_64)  PLAT="x86_64-apple-darwin" ;;
  linux-x86_64)  PLAT="x86_64-unknown-linux-gnu" ;;
  linux-aarch64) PLAT="aarch64-unknown-linux-gnu" ;;
  *) echo "fetch-pbs: unsupported platform '$OSARCH'" >&2; exit 1 ;;
esac
ASSET="cpython-${PBS_PY}+${PBS_TAG}-${PLAT}-pgo-full.tar.zst"

if [ -f "$DEST/python/PYTHON.json" ]; then
  exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "fetch-pbs: curl required" >&2; exit 1; }
command -v zstd >/dev/null 2>&1 || { echo "fetch-pbs: zstd required" >&2; exit 1; }

mkdir -p "$DEST"
url="https://github.com/astral-sh/python-build-standalone/releases/download/${PBS_TAG}/${ASSET}"
tmp="$DEST/.dl.$$"; mkdir -p "$tmp"; trap 'rm -rf "$tmp"' EXIT
echo "fetch-pbs: downloading ${ASSET}"
curl -fsSL -o "$tmp/pbs.tar.zst" "$url"
zstd -d -q --long=31 -f "$tmp/pbs.tar.zst" -o "$tmp/pbs.tar"
tar -C "$DEST" -xf "$tmp/pbs.tar"
[ -f "$DEST/python/PYTHON.json" ] || { echo "fetch-pbs: extract failed (no PYTHON.json)" >&2; exit 1; }
echo "fetch-pbs: ready at $DEST/python"
