#!/usr/bin/env bash
# build_selftest.sh — build the dev-only golden-render harness binary.
#
# Compiles selftest_render.na.jac -> bin/selftest_render: a standalone native
# binary (no embedded CPython, no fused-runtime trailer) that imports the REAL
# screen_render and dumps framed, byte-exact frames to stdout. Used by the
# golden-render regression test (tests/cli/test_tui_render_golden.jac) to
# capture baselines and guard the Plan 01 refactor.
#
# This mirrors build_embed.sh's TTY-backend + libjacpyembed staging exactly
# (screen_render's import closure reaches libc_tty via terminal, and jacpyembed
# via transport), but skips the trailer/payload step — the selftest never boots
# Python. patchelf is unnecessary: nacompile emits a $ORIGIN runpath that
# resolves the sibling shim at runtime.
#
# Usage: bash build_selftest.sh
# Run from any directory; paths resolve relative to this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REPO_JAC="$REPO_ROOT/jac/zig-out/bin/jac"
REPO_VENV="$REPO_ROOT/.venv"

# ── resolve the jac toolchain for nacompile (same order as build_embed.sh) ────
if [ -n "${JAC_BIN:-}" ]; then
    JAC=("$JAC_BIN")
    echo "==> Using \$JAC_BIN: $JAC_BIN"
elif [ -n "${JAC_PY:-}" ]; then
    JAC=("$JAC_PY" -m jaclang)
    echo "==> Using \$JAC_PY: $JAC_PY -m jaclang"
elif [ -x "$REPO_JAC" ]; then
    JAC=("$REPO_JAC")
    echo "==> Using repo-built jac binary: $REPO_JAC"
elif [ -x "$REPO_VENV/bin/python" ]; then
    JAC=("$REPO_VENV/bin/python" -m jaclang)
    echo "==> Using repo editable jaclang: $REPO_VENV/bin/python -m jaclang"
else
    echo "==> No jac build toolchain found (set JAC_BIN, build zig-out, or .venv)." >&2
    exit 1
fi

# ── select the TTY backend (same matrix as build_embed.sh) ────────────────────
HOST="$(uname -s 2>/dev/null || echo "unknown")"
case "${JAC_AI_TUI_TARGET:-}" in
    linux)  TTY=linux  ;;
    darwin) TTY=darwin ;;
    *)
        case "$HOST" in
            Linux*)  TTY=linux  ;;
            Darwin*) TTY=darwin ;;
            *) echo "==> Unsupported host '$HOST'; set JAC_AI_TUI_TARGET" >&2; exit 1 ;;
        esac
        ;;
esac
case "$TTY" in
    linux)  PLAT=tty/tty_plat.linux.na.jac;  SHIM=libjacpyembed.so    ;;
    darwin) PLAT=tty/tty_plat.darwin.na.jac; SHIM=libjacpyembed.dylib ;;
esac

XFLAGS=""
case "$TTY" in
    darwin) [[ "$HOST" != Darwin* ]] && XFLAGS="--target darwin" ;;
esac

echo "==> TTY backend: $TTY   shim: $SHIM"

# ── locate the libjacpyembed shim (same path logic as build_embed.sh) ─────────
SHIM_SRC="${JAC_PYEMBED_SHIM:-$REPO_ROOT/jac/jaclang/runtimelib/client/targets/desktop/native/$SHIM}"
if [ ! -f "$SHIM_SRC" ]; then
    echo "==> libjacpyembed shim not found at $SHIM_SRC" >&2
    echo "    Rebuild the jac binary (cd jac && zig build) so the shim is present." >&2
    exit 1
fi

# ── stage TTY backend + shim into the compile dir; clean up on any exit ──────
# All three are gitignored build scratch. nacompile resolves `import from
# .libc_tty` and `import from jacpyembed` from its cwd (= this dir).
cp "$PLAT" tty_plat.na.jac
cp tty/libc_tty_base.na.jac libc_tty.na.jac
cp "$SHIM_SRC" "$SHIM"

# Stage Phase 5 nested tui/ + components/ modules flat for nacompile.
# shellcheck source=_stage_modules.sh
source "$SCRIPT_DIR/_stage_modules.sh"
stage_tui_modules

mkdir -p bin
OUT="bin/selftest_render"
TMP="bin/.selftest_render.partial.$$"
trap "rm -f tty_plat.na.jac libc_tty.na.jac '$SCRIPT_DIR/$SHIM' '$SCRIPT_DIR/$TMP'; cleanup_staged_modules" EXIT

# ── nacompile the selftest entry ─────────────────────────────────────────────
echo "==> Compiling selftest_render (golden harness) ..."
"${JAC[@]}" nacompile selftest_render.na.jac ${XFLAGS:+$XFLAGS} -o "$TMP"
echo "==> Compiled: $SCRIPT_DIR/$TMP"

# ── stage the shim $ORIGIN-adjacent so the emitted runpath binds at load ─────
cp "$SHIM_SRC" "bin/$SHIM"
mv -f "$TMP" "$OUT"
echo "==> Done. Golden-render harness: $SCRIPT_DIR/$OUT (+ bin/$SHIM)"
echo "    Capture baseline: GOLDEN_UPDATE=1 pytest jac/tests/cli/test_tui_render_golden.jac"
echo "    Verify:           pytest jac/tests/cli/test_tui_render_golden.jac"
