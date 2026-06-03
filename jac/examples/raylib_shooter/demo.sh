#!/usr/bin/env bash
#
# Build & run the Jac-native raylib shooter.
#
#   1. detect the platform / architecture
#   2. download the matching *precompiled* raylib release from GitHub
#   3. stage its shared library as ./libraylib.so  (the file shooter.na.jac
#      links against via `import from "./libraylib.so" { ... }`)
#   4. compile shooter.na.jac into a standalone native binary (`jac nacompile`)
#   5. run it
#
# The Jac native linker records the import path verbatim as the binary's
# needed-library entry (DT_NEEDED on ELF, LC_LOAD_DYLIB on Mach-O). Because that
# path contains a slash it is resolved relative to the current directory at
# load time, so the binary must be launched from this folder - which this
# script does.
#
set -euo pipefail

RAYLIB_VERSION="6.0"
BASE_URL="https://github.com/raysan5/raylib/releases/download/${RAYLIB_VERSION}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
BUILD_DIR="$HERE/.build"
mkdir -p "$BUILD_DIR"

os="$(uname -s)"
arch="$(uname -m)"

# ── 1. Map platform -> release asset + library glob ─────────────────────────
case "$os" in
  Linux)
    case "$arch" in
      x86_64|amd64)  asset="raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz" ;;
      aarch64|arm64) asset="raylib-${RAYLIB_VERSION}_linux_arm64.tar.gz" ;;
      i386|i686)     asset="raylib-${RAYLIB_VERSION}_linux_i386.tar.gz"  ;;
      *) echo "Unsupported Linux architecture: $arch" >&2; exit 1 ;;
    esac
    lib_glob="libraylib.so*"
    ;;
  Darwin)
    # The macOS release ships a universal (x86_64 + arm64) dylib.
    asset="raylib-${RAYLIB_VERSION}_macos.tar.gz"
    lib_glob="libraylib*.dylib"
    ;;
  *)
    echo "Unsupported OS: $os (this demo targets Linux and macOS)" >&2
    exit 1
    ;;
esac

echo ">> platform : $os / $arch"
echo ">> raylib   : $asset"

# ── 2. Download the precompiled release (cached in .build/) ─────────────────
tarball="$BUILD_DIR/$asset"
if [ ! -f "$tarball" ]; then
  echo ">> fetching $BASE_URL/$asset"
  curl -fL --retry 3 -o "$tarball" "$BASE_URL/$asset"
else
  echo ">> using cached $tarball"
fi

# ── 3. Extract and stage the shared library as ./libraylib.so ───────────────
extract_dir="$BUILD_DIR/extracted"
rm -rf "$extract_dir"; mkdir -p "$extract_dir"
tar xzf "$tarball" -C "$extract_dir"

# Pick the real (non-symlink) shared object out of the release tree.
lib_file="$(find "$extract_dir" -type f -name "$lib_glob" | sort | head -1)"
if [ -z "$lib_file" ]; then
  echo "Could not locate $lib_glob inside the raylib release." >&2
  exit 1
fi
cp -f "$lib_file" "$HERE/libraylib.so"
echo ">> staged   : $(basename "$lib_file") -> ./libraylib.so"

# ── 4. Locate the jac CLI and compile ───────────────────────────────────────
if command -v jac >/dev/null 2>&1; then
  JAC="jac"
elif [ -x "$HERE/../../../.venv/bin/jac" ]; then
  JAC="$HERE/../../../.venv/bin/jac"   # in-repo virtualenv fallback
else
  echo "Could not find the 'jac' CLI on PATH or in ../../../.venv." >&2
  echo "Install jaclang (pip install jaclang) or activate the repo venv." >&2
  exit 1
fi

echo ">> compiling: $JAC nacompile shooter.na.jac"
"$JAC" nacompile shooter.na.jac

# ── 5. Run (from this directory, so ./libraylib.so resolves) ────────────────
echo ">> launching ./shooter   -   arrows = aim, WASD = move, space = fire, Esc = quit"
exec ./shooter
