#!/usr/bin/env bash
#
# Build & run the raylib cube shooter.
#
#   default   benchmark BOTH builds: run each for a fixed number of seconds,
#             then print the average and max FPS side by side
#   --jac     build & run only the Jac-native shooter (shooter.jac), interactive
#   --zig     build & run only the Zig shooter (shooter.zig), interactive
#
# Either way the script:
#   1. detects the platform / architecture
#   2. downloads the matching *precompiled* raylib release from GitHub
#   3. stages its shared library beside this script
#   4. builds the requested shooter(s)
#   5. runs / benchmarks them
#
# shooter.jac links against raylib by its *logical* name -
# `import from raylib { ... }` (no path, no extension). The native backend picks
# the platform-correct filename (libraylib.so / libraylib.dylib / raylib.dll) for
# the needed-library entry (DT_NEEDED on ELF, LC_LOAD_DYLIB on Mach-O), and emits
# a $ORIGIN / @loader_path runpath so the binary finds the sibling library
# regardless of the directory it is launched from.
#
# shooter.zig is a faithful Zig twin of the same demo: it declares the same
# raylib entry points as `extern fn` (the moral equivalent of Jac's import
# block) and renders through the same scalar rlgl API, so the two builds can be
# compared side by side.
#
# Benchmark switch: this script writes the requested duration into a sibling
# `.bench_seconds` file before launching and deletes it afterwards. Each binary
# reads that file with raylib's own cross-platform helpers (FileExists /
# LoadFileText / TextToInteger); when it is absent the binaries run interactively
# exactly as before. Nothing in the demos changes for normal play.
#
set -euo pipefail

# ── 0. Parse args ───────────────────────────────────────────────────────────
MODE="bench"   # bench | jac | zig | headless
for arg in "$@"; do
  case "$arg" in
    --jac)        MODE="jac" ;;
    --zig)        MODE="zig" ;;
    --bench)      MODE="bench" ;;
    --headless)   MODE="headless" ;;
    -h|--help)
      echo "Usage: ${0##*/} [--jac | --zig | --bench | --headless]"
      echo "  (default)   benchmark both builds for ${BENCH_SECONDS:-8}s each and print avg/max FPS"
      echo "  --jac       build & run only the Jac-native shooter, interactively"
      echo "  --zig       build & run only the Zig shooter, interactively"
      echo "  --bench     explicit form of the default benchmark mode"
      echo "  --headless  benchmark the borrow-checked headless sim under all three"
      echo "              gc modes (no window, no GPU, no raylib download needed);"
      echo "              HEADLESS_FRAMES overrides the frame count (default 100000)"
      exit 0
      ;;
    *) echo "Unknown argument: $arg (try --help)" >&2; exit 1 ;;
  esac
done

RAYLIB_VERSION="6.0"
ZIG_VERSION="0.13.0"
BENCH_SECONDS=8
BASE_URL="https://github.com/raysan5/raylib/releases/download/${RAYLIB_VERSION}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
BUILD_DIR="$HERE/.build"
mkdir -p "$BUILD_DIR"

os="$(uname -s)"
arch="$(uname -m)"

# Locate the jac CLI (PATH first, then the in-repo virtualenv).
find_jac() {
  if command -v jac >/dev/null 2>&1; then
    echo "jac"
  elif [ -x "$HERE/../../../.venv/bin/jac" ]; then
    echo "$HERE/../../../.venv/bin/jac"
  else
    echo "Could not find the 'jac' CLI on PATH or in ../../../.venv." >&2
    echo "Install jaclang (pip install jaclang) or activate the repo venv." >&2
    exit 1
  fi
}

# ── 0.5 Headless mode: no window, no GPU, no raylib - handle it now ─────────
#
# shooter_headless.jac is the shooter's game loop with the renderer swapped
# for a deterministic digest and the ownership dial turned all the way up: it
# passes the enforced borrow checker and compiles headerless with NO collector
# and machine-checked zero reference counting (--enforce-nogc --gc none
# --assert-no-rc). The same source also builds under rc and cycles; identical
# digests across the three prove the borrow-checked build changes nothing.
HEADLESS_FRAMES="${HEADLESS_FRAMES:-100000}"

if [ "$MODE" = "headless" ]; then
  JAC="$(find_jac)"
  echo ">> compiling: shooter_headless.jac under three memory modes"
  echo "   none   : --enforce-nogc --gc none --assert-no-rc  (borrow-checked, zero RC)"
  echo "   rc     : --gc rc                                  (reference counting)"
  echo "   cycles : --gc cycles                              (rc + cycle collector)"
  "$JAC" nacompile shooter_headless.jac --enforce-nogc --gc none --assert-no-rc \
    -o shooter_headless_none >/dev/null
  "$JAC" nacompile shooter_headless.jac --gc rc     -o shooter_headless_rc     >/dev/null
  "$JAC" nacompile shooter_headless.jac --gc cycles -o shooter_headless_cycles >/dev/null

  echo ">> simulating ${HEADLESS_FRAMES} frames per build (240 Hz game tick) ..."
  headless_digests=""
  print_headless_row() {
    local mode="$1" out="$2" digest score ns fps nsf
    digest="$(printf '%s\n' "$out" | sed -n 's/^shooter://p')"
    score="$(printf '%s\n' "$out" | sed -n 's/^score:\([0-9]*\).*/\1/p')"
    ns="$(printf '%s\n' "$out" | sed -n 's/^ns=//p')"
    fps="$(awk -v f="$HEADLESS_FRAMES" -v n="$ns" 'BEGIN{printf "%.0f", f * 1e9 / n}')"
    nsf="$(awk -v f="$HEADLESS_FRAMES" -v n="$ns" 'BEGIN{printf "%.0f", n / f}')"
    printf '  %-9s %11s %11s %8s %12s\n' "$mode" "$fps" "$nsf" "$score" "$digest"
    headless_digests="$headless_digests $digest"
  }

  out_none="$(./shooter_headless_none     "$HEADLESS_FRAMES")"
  out_rc="$(./shooter_headless_rc         "$HEADLESS_FRAMES")"
  out_cycles="$(./shooter_headless_cycles "$HEADLESS_FRAMES")"

  printf '\n'
  printf '==== headless shooter benchmark (%s frames, 240 Hz sim tick) ====\n' "$HEADLESS_FRAMES"
  printf '  %-9s %11s %11s %8s %12s\n' "gc mode" "sim FPS" "ns/frame" "score" "digest"
  print_headless_row "none"   "$out_none"
  print_headless_row "rc"     "$out_rc"
  print_headless_row "cycles" "$out_cycles"
  uniq_digests="$(printf '%s\n' $headless_digests | sort -u | wc -l | tr -d ' ')"
  if [ "$uniq_digests" = "1" ]; then
    echo "  digests identical across gc modes: OK"
  else
    echo "  !! DIGEST MISMATCH across gc modes"
  fi
  printf '  (none = enforced ownership, headerless, machine-checked zero RC)\n'
  printf '================================================================\n'
  [ "$uniq_digests" = "1" ]
  exit $?
fi

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
    stage_name="libraylib.so"
    ;;
  Darwin)
    # The macOS release ships a universal (x86_64 + arm64) dylib.
    asset="raylib-${RAYLIB_VERSION}_macos.tar.gz"
    lib_glob="libraylib*.dylib"
    stage_name="libraylib.dylib"
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

# ── 3. Extract and stage the shared library beside this script ──────────────
extract_dir="$BUILD_DIR/extracted"
rm -rf "$extract_dir"; mkdir -p "$extract_dir"
tar xzf "$tarball" -C "$extract_dir"

# Pick the real (non-symlink) shared object out of the release tree.
lib_file="$(find "$extract_dir" -type f -name "$lib_glob" | sort | head -1)"
if [ -z "$lib_file" ]; then
  echo "Could not locate $lib_glob inside the raylib release." >&2
  exit 1
fi
lib_src_dir="$(dirname "$lib_file")"

# Stage the release's full symlinked library set. The Jac backend records the
# plain logical name `libraylib.so`, but a conventional linker (the Zig build)
# records the library's SONAME / install-name - a versioned name like
# `libraylib.so.600` (Linux) or `@rpath/libraylib.500.dylib` (macOS). Copying the
# real object plus its version symlinks (preserved with `cp -P`) satisfies both:
# whatever name a binary records resolves beside it via the runpath.
if [ "$os" = "Darwin" ]; then
  cp -P "$lib_src_dir"/libraylib*.dylib "$HERE/" 2>/dev/null || true
else
  cp -P "$lib_src_dir"/libraylib.so* "$HERE/" 2>/dev/null || true
fi
echo ">> staged   : raylib shared library set -> ./ (via $stage_name)"

# ── 4. Build helpers ────────────────────────────────────────────────────────

# Compile shooter.jac -> ./shooter with the jac CLI.
build_jac() {
  local JAC
  JAC="$(find_jac)"
  echo ">> compiling: $JAC nacompile shooter.jac"
  "$JAC" nacompile shooter.jac
}

# Locate a Zig toolchain, downloading the single-archive distribution into
# .build/ if `zig` is not already on PATH. Echoes the resolved zig path.
ensure_zig() {
  if command -v zig >/dev/null 2>&1; then
    echo "zig"
    return 0
  fi
  # Map this platform onto Zig's download asset (zig-<os>-<arch>-<ver>).
  local zig_arch zig_os
  case "$arch" in
    x86_64|amd64)  zig_arch="x86_64" ;;
    aarch64|arm64) zig_arch="aarch64" ;;
    *) echo "No prebuilt Zig auto-download for architecture: $arch" >&2
       echo "Install Zig manually (https://ziglang.org/download) and re-run." >&2
       exit 1 ;;
  esac
  case "$os" in
    Linux)  zig_os="linux" ;;
    Darwin) zig_os="macos" ;;
  esac

  local zig_asset zig_url zig_tarball zig_root
  zig_asset="zig-${zig_os}-${zig_arch}-${ZIG_VERSION}.tar.xz"
  zig_url="https://ziglang.org/download/${ZIG_VERSION}/${zig_asset}"
  zig_tarball="$BUILD_DIR/$zig_asset"
  zig_root="$BUILD_DIR/zig-${zig_os}-${zig_arch}-${ZIG_VERSION}"

  if [ ! -x "$zig_root/zig" ]; then
    if [ ! -f "$zig_tarball" ]; then
      echo ">> fetching Zig $ZIG_VERSION  ($zig_url)" >&2
      curl -fL --retry 3 -o "$zig_tarball" "$zig_url" >&2
    else
      echo ">> using cached $zig_tarball" >&2
    fi
    echo ">> unpacking $(basename "$zig_tarball") -> .build/" >&2
    tar xf "$zig_tarball" -C "$BUILD_DIR" >&2
  fi
  if [ ! -x "$zig_root/zig" ]; then
    echo "Zig toolchain not found at $zig_root/zig after unpack." >&2
    exit 1
  fi
  echo "$zig_root/zig"
}

# Compile shooter.zig -> ./shooter_zig against the staged sibling library.
build_zig() {
  local ZIG rpath_value
  ZIG="$(ensure_zig)"
  echo ">> zig      : $ZIG"

  # Bake an $ORIGIN/@loader_path runpath so ./shooter_zig finds the staged
  # library regardless of the directory it is launched from. shooter.zig
  # declares raylib's symbols as `extern fn`, so no headers are needed.
  if [ "$os" = "Darwin" ]; then
    rpath_value="@loader_path"
  else
    rpath_value="\$ORIGIN"
  fi

  echo ">> compiling: zig build-exe shooter.zig -> ./shooter_zig"
  "$ZIG" build-exe shooter.zig \
    -O ReleaseFast \
    -lc \
    -L"$HERE" -lraylib \
    -rpath "$rpath_value" \
    -femit-bin=shooter_zig
  rm -f "$HERE/shooter_zig.o"   # zig leaves the intermediate object behind
}

# Run one binary in benchmark mode for $BENCH_SECONDS and echo its result line
# ("BENCH_RESULT avg max frames seconds") to stdout, or nothing on failure.
# $1 = binary (e.g. ./shooter), $2 = label (for diagnostics).
#
# The binary can't print FPS to the shell on its own (raylib paints the counter
# onto the framebuffer, and the Jac lint rules disallow print()), so it writes
# the result to a sibling `.bench_result` file via raylib's SaveFileText; we read
# that back here. The duration is handed over the same way, via `.bench_seconds`.
run_bench() {
  local bin="$1" label="$2" rc line
  rm -f "$HERE/.bench_result"
  printf '%s' "$BENCH_SECONDS" > "$HERE/.bench_seconds"
  set +e
  # Cap the run in case a binary hangs or has no display to draw to (the binary
  # normally self-exits after $BENCH_SECONDS via raylib's clock).
  if command -v timeout >/dev/null 2>&1; then
    timeout "$((BENCH_SECONDS + 15))" "$bin" >/dev/null 2>&1
  else
    "$bin" >/dev/null 2>&1
  fi
  rc=$?
  set -e
  rm -f "$HERE/.bench_seconds"
  if [ ! -f "$HERE/.bench_result" ]; then
    echo "!! $label: no FPS result (exit $rc) - is a display/GPU available?" >&2
    return 1
  fi
  line="$(cat "$HERE/.bench_result")"
  rm -f "$HERE/.bench_result"
  echo "$line"
}

# Print one row of the benchmark table. $1 = label, $2 = result line (may be empty).
print_bench_row() {
  local label="$1" line="$2" avg max frames
  if [ -z "$line" ]; then
    printf '  %-5s %14s %14s %12s\n' "$label" "n/a" "n/a" "n/a"
    return
  fi
  # shellcheck disable=SC2034
  read -r _tag avg max frames _secs <<<"$line"
  printf '  %-5s %14.1f %14.1f %12s\n' "$label" "$avg" "$max" "$frames"
}

# ── 5. Dispatch ─────────────────────────────────────────────────────────────
case "$MODE" in
  jac)
    build_jac
    rm -f "$HERE/.bench_seconds"   # ensure interactive (no time limit)
    echo ">> launching ./shooter   -   arrows = aim, WASD = move, space = fire, Esc = quit"
    exec ./shooter
    ;;
  zig)
    build_zig
    rm -f "$HERE/.bench_seconds"
    echo ">> launching ./shooter_zig   -   arrows = aim, WASD = move, space = fire, Esc = quit"
    exec ./shooter_zig
    ;;
  bench)
    build_jac
    build_zig
    echo ">> benchmarking each build for ${BENCH_SECONDS}s (a window opens for each) ..."
    jac_line="$(run_bench ./shooter Jac || true)"
    zig_line="$(run_bench ./shooter_zig Zig || true)"

    printf '\n'
    printf '====== raylib cube shooter benchmark (%ss each, uncapped) ======\n' "$BENCH_SECONDS"
    printf '  %-5s %14s %14s %12s\n' "build" "avg FPS" "max FPS" "frames"
    print_bench_row "Jac" "$jac_line"
    print_bench_row "Zig" "$zig_line"
    printf '===============================================================\n'
    ;;
esac
