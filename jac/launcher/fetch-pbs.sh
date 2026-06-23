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

# Pinned pbs release. We want a *full* archive (the shared .dylib/.so +
# lib-dynload, since the launcher dlopens the shared libpython) and prefer the
# 'pgo' flavor (most optimized, non-LTO -- LTO ships LLVM bitcode in the static
# libs, which we avoid). python-build-standalone does NOT publish a PGO build
# for aarch64 Linux (PGO needs to run the target during the build), so that one
# platform falls back to 'lto-full'. The launcher only links libc and loads the
# finished shared libpython at runtime, so the LTO-bitcode concern (a static-
# link issue) does not apply to it.
PBS_TAG="20241206"
PBS_PY="3.12.8"
FLAVOR="pgo-full"
case "$OSARCH" in
  macos-aarch64) PLAT="aarch64-apple-darwin" ;;
  macos-x86_64)  PLAT="x86_64-apple-darwin" ;;
  linux-x86_64)  PLAT="x86_64-unknown-linux-gnu" ;;
  linux-aarch64) PLAT="aarch64-unknown-linux-gnu"; FLAVOR="lto-full" ;;
  *) echo "fetch-pbs: unsupported platform '$OSARCH'" >&2; exit 1 ;;
esac
ASSET="cpython-${PBS_PY}+${PBS_TAG}-${PLAT}-${FLAVOR}.tar.zst"

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

# Verify integrity against the release's SHA256SUMS: this archive becomes the
# libpython embedded in every distributed binary, so a swapped/MITM'd asset must
# not slip through.
curl -fsSL -o "$tmp/SHA256SUMS" \
  "https://github.com/astral-sh/python-build-standalone/releases/download/${PBS_TAG}/SHA256SUMS"
expected="$(awk -v a="$ASSET" '$2 == a {print $1}' "$tmp/SHA256SUMS")"
[ -n "$expected" ] || { echo "fetch-pbs: no checksum for ${ASSET} in SHA256SUMS" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$tmp/pbs.tar.zst" | awk '{print $1}')"
else
  actual="$(shasum -a 256 "$tmp/pbs.tar.zst" | awk '{print $1}')"
fi
[ "$actual" = "$expected" ] || {
  echo "fetch-pbs: checksum mismatch for ${ASSET}" >&2
  echo "  expected $expected" >&2
  echo "  actual   $actual" >&2
  exit 1
}

zstd -d -q --long=31 -f "$tmp/pbs.tar.zst" -o "$tmp/pbs.tar"
tar -C "$DEST" -xf "$tmp/pbs.tar"
[ -f "$DEST/python/PYTHON.json" ] || { echo "fetch-pbs: extract failed (no PYTHON.json)" >&2; exit 1; }
echo "fetch-pbs: ready at $DEST/python"
