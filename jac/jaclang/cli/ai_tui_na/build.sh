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

# ── resolve the jac toolchain to build with ─────────────────────────────────
# jaclang ships as the self-contained `jac` binary (Zig launcher + bundled
# CPython); `pip install -e jac` is gone. Resolution order:
#   1. $JAC_BIN            — explicit override (also set by auto-build in tui_shared)
#   2. jac/zig-out/bin/jac — the repo's freshly built binary (CI builds this via
#                            the setup-jac action; locally via `cd jac && zig build`)
#   3. .venv editable      — legacy local-dev fallback: an editable jaclang whose
#                            source still resolves into the working tree (no zig
#                            needed), so the dev loop survives without a zig install
# PATH is intentionally not consulted — a stale global `jac` is a common dev-tree
# footgun. Set JAC_BIN, build zig-out, or use the repo .venv.
# This dir lives at jac/jaclang/cli/ai_tui_na, so the repo root is four levels up.
# Canonicalize it (no trailing `..`) so the editable venv's sys.prefix matches
# and python doesn't emit a "Unexpected value in sys.prefix" RuntimeWarning.
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REPO_JAC="$REPO_ROOT/jac/zig-out/bin/jac"
REPO_VENV="$REPO_ROOT/.venv"
if [ -n "${JAC_BIN:-}" ]; then
    JAC=("$JAC_BIN")
    echo "==> Using \$JAC_BIN: $JAC_BIN"
elif [ -n "${JAC_PY:-}" ]; then
    # A python interpreter to drive `-m jaclang` (no single `jac` binary). Used by
    # the launcher payload build (jac/launcher/payload.zig buildTui), which runs
    # the bundled pbs python against the staged jaclang tree -- there is no
    # $JAC_BIN, repo zig-out, or .venv in that ephemeral staging dir.
    JAC=("$JAC_PY" -m jaclang)
    echo "==> Using \$JAC_PY: $JAC_PY -m jaclang"
elif [ -x "$REPO_JAC" ]; then
    JAC=("$REPO_JAC")
    echo "==> Using repo-built jac binary: $REPO_JAC"
elif [ -x "$REPO_VENV/bin/python" ]; then
    JAC=("$REPO_VENV/bin/python" -m jaclang)
    echo "==> Using repo editable jaclang: $REPO_VENV/bin/python -m jaclang"
else
    echo "==> No jac build toolchain found." >&2
    echo "    Set JAC_BIN to your jac binary, or:" >&2
    echo "      (cd jac && zig build)   # -> jac/zig-out/bin/jac" >&2
    echo "      python -m venv .venv && .venv/bin/pip install -e jac" >&2
    exit 1
fi

# ── select the TTY backend ───────────────────────────────────────────────────
# Override with JAC_AI_TUI_TARGET=linux|darwin (e.g. cross-compile from
# a Linux CI runner to produce a macOS artifact without a macOS runner).
HOST="$(uname -s 2>/dev/null || echo "unknown")"
case "${JAC_AI_TUI_TARGET:-}" in
    linux)  TTY=linux  ;;
    darwin) TTY=darwin ;;
    *)
        case "$HOST" in
            Linux*)       TTY=linux  ;;
            Darwin*)      TTY=darwin ;;
            *)
                echo "==> Unsupported host '$HOST'." \
                     "Set JAC_AI_TUI_TARGET=linux|darwin"
                exit 1
                ;;
        esac
        ;;
esac

case "$TTY" in
    linux)  LIBNAME=libtui.so;    STAGE=tty/libc_tty.linux.na.jac  ;;
    darwin) LIBNAME=libtui.dylib; STAGE=tty/libc_tty.darwin.na.jac ;;
esac

BINNAME="jac-na-tui"

# Cross-compile flag: a darwin target must be explicit on a foreign host
# because nacompile derives is_macos from --target, not from sys.platform.
# XFLAGS is a plain string (not an array) so bash 3.x (macOS default
# /bin/bash) does not raise "unbound variable" on empty expansion when
# set -u is active — a bash 3.2 quirk that only affects empty arrays.
XFLAGS=""
case "$TTY" in
    darwin) [[ "$HOST" != Darwin* ]] && XFLAGS="--target darwin" ;;
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

# ── build in-process shared library (host.na.jac :pub surface) ─
# Explicit -o keeps the exact path (no lib<stem>.so renaming); the sv host
# ctypes.CDLL's this. Needs the PT_GNU_STACK compiler fix so CPython's dlopen
# accepts the .so on a hardened kernel.
echo "==> Compiling $LIBNAME (in-process host) ..."
"${JAC[@]}" nacompile host.na.jac --shared ${XFLAGS:+$XFLAGS} -o "bin/$LIBNAME"
echo "==> Done. Shared lib: $SCRIPT_DIR/bin/$LIBNAME"

if [ "$QUICK" -eq 1 ]; then
    echo "==> Quick build complete (skipped tests)."
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
