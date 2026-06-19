#!/usr/bin/env bash
# Build the NA TUI binary — nacompile only, no gcc, no custom C.
# Run from any directory; script resolves paths relative to its own location.

set -euo pipefail

QUICK=0
for arg in "$@"; do
    case "$arg" in
        --quick) QUICK=1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── resolve the jaclang to build with ───────────────────────────────────────
# Prefer the repo's editable jaclang (the venv at the repo root) over any global
# `jac` on PATH — a global uv-tool install can be stale and miss compiler fixes
# this TUI depends on (e.g. multi-`with entry` codegen).
REPO_VENV="$SCRIPT_DIR/../../../.venv"
if [ -x "$REPO_VENV/bin/python" ]; then
    JAC=("$REPO_VENV/bin/python" -m jaclang)
    echo "==> Using repo jaclang: $REPO_VENV/bin/python -m jaclang"
else
    JAC=(jac)
    echo "==> Using jac on PATH (no repo .venv found)"
fi

# ── select the TTY backend ───────────────────────────────────────────────────
# Override with JAC_AI_TUI_TARGET=linux|darwin|win32 (e.g. cross-compile from
# a Linux CI runner to produce a Windows artifact without a Windows runner).
HOST="$(uname -s 2>/dev/null || echo "unknown")"
case "${JAC_AI_TUI_TARGET:-}" in
    linux)  TTY=linux  ;;
    darwin) TTY=darwin ;;
    win32)  TTY=win32  ;;
    *)
        case "$HOST" in
            Linux*)       TTY=linux  ;;
            Darwin*)      TTY=darwin ;;
            MINGW*|MSYS*) TTY=win32  ;;
            *)
                echo "==> Unsupported host '$HOST'." \
                     "Set JAC_AI_TUI_TARGET=linux|darwin|win32"
                exit 1
                ;;
        esac
        ;;
esac

case "$TTY" in
    linux)  LIBNAME=libtui.so;    STAGE=tty/libc_tty.linux.na.jac  ;;
    darwin) LIBNAME=libtui.dylib; STAGE=tty/libc_tty.darwin.na.jac ;;
    win32)  LIBNAME=tui.dll;      STAGE=tty/console.win32.na.jac    ;;
esac

BINNAME="jac-na-tui"
if [ "$TTY" = "win32" ]; then
    BINNAME="jac-na-tui.exe"
fi

# Cross-compile flags: win32 and darwin targets must be explicit on a foreign
# host because nacompile derives is_windows/is_macos from --target, not from
# sys.platform.  XFLAGS is a plain string (not an array) so bash 3.x (macOS
# default /bin/bash) does not raise "unbound variable" on empty expansion when
# set -u is active — a bash 3.2 quirk that only affects empty arrays.
XFLAGS=""
case "$TTY" in
    darwin) [[ "$HOST" != Darwin* ]] && XFLAGS="--target darwin" ;;
    win32)  XFLAGS="--target windows" ;;
esac

echo "==> TTY backend: $TTY  shared-lib: $LIBNAME"

# ── stage the platform TTY module ───────────────────────────────────────────
# libc_tty.na.jac is gitignored; tui.na.jac / host.na.jac import it statically.
# Copy the right platform file before nacompile, remove it on exit (trap fires
# on both normal and error exits so the build tree stays clean on failure too).
cp "$STAGE" libc_tty.na.jac
trap "rm -f libc_tty.na.jac" EXIT

mkdir -p bin

# ── build main NA binary (subprocess fallback renderer) ──────────────────────
echo "==> Compiling $BINNAME ..."
"${JAC[@]}" nacompile tui.na.jac ${XFLAGS:+$XFLAGS} -o "bin/$BINNAME"
echo "==> Done. Binary: $SCRIPT_DIR/bin/$BINNAME"

# ── build in-process shared library (host.na.jac :pub surface, plan §5/§11.2) ─
# Explicit -o keeps the exact path (no lib<stem>.so renaming); the sv host
# ctypes.CDLL's this. Needs the PT_GNU_STACK compiler fix (§11.1, already landed)
# so CPython's dlopen accepts the .so on a hardened kernel.
echo "==> Compiling $LIBNAME (in-process host) ..."
"${JAC[@]}" nacompile host.na.jac --shared ${XFLAGS:+$XFLAGS} -o "bin/$LIBNAME"
echo "==> Done. Shared lib: $SCRIPT_DIR/bin/$LIBNAME"

if [ "$QUICK" -eq 1 ]; then
    echo "==> Quick build complete (skipped tests)."
    exit 0
fi

# ── skip tests for cross-compiled Windows artifacts ─────────────────────────
if [ "$TTY" = "win32" ]; then
    echo "==> Win32 cross-compile complete." \
         "Run tests natively on a Windows host."
    exit 0
fi

# ── headless logic tests (no TTY needed) ─────────────────────────────────────
echo "==> Building + running picker logic tests ..."
"${JAC[@]}" nacompile test_pickers.na.jac -o bin/test_pickers
"$SCRIPT_DIR/bin/test_pickers"
echo "==> Tests passed."

# ── headless host gate: load libtui.so under CPython, parse+render (no TTY) ───
echo "==> Running in-process host gate (ctypes) ..."
"${JAC[@]}" run test_host.jac
echo "==> Host gate passed."

# ── quick smoke-test ─────────────────────────────────────────────────────────
echo "==> Smoke-test (piped stdin, expect non-zero exit) ..."
echo "---" | timeout 2 "$SCRIPT_DIR/bin/jac-na-tui" || true
echo "==> Build complete."
