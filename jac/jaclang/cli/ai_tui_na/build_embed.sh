#!/usr/bin/env bash
# Build the self-hosting embed TUI binary (host_embed.na.jac -> bin/jac-ai-tui).
#
# Unlike build.sh (which nacompiles the subprocess renderer + the --shared
# libtui.so the Python `jac` CLI dlopens), this produces a SINGLE executable that
# IS the host: the renderer is linked Jac and the agent runs in an embedded
# CPython brought up by libjacpyembed. It mirrors the native desktop build
# (native_desktop_target.impl.jac) one-for-one:
#   1. nacompile host_embed.na.jac -> bin/jac-ai-tui  (libjacpyembed staged in the
#      compile dir so `import from jacpyembed` resolves; $ORIGIN runpath emitted)
#   2. stage libjacpyembed.so $ORIGIN-adjacent (bin/) so the DT_NEEDED binds at load
#   3. append the fused `jac` binary's [payload][trailer] so jac_engine_boot()
#      materializes the SAME bundled CPython + jaclang the CLI ships
#
# Run from any directory; paths resolve relative to this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REPO_JAC="$REPO_ROOT/jac/zig-out/bin/jac"
REPO_VENV="$REPO_ROOT/.venv"

# ── flags ─────────────────────────────────────────────────────────────────────
# --no-trailer: stop after step 2, emitting the ~472KB trailerless host (just the
# NA ELF + the $ORIGIN-adjacent shim). It cannot self-boot -- it borrows a runtime
# via JAC_RT_DIR -- and is the variant the payload bakes for the fused `jac` CLI
# (which hands it its own materialized rt). The default (no flag) appends the
# [payload][trailer] so the binary is self-contained for dev / standalone use.
NO_TRAILER=""
for arg in "$@"; do
    case "$arg" in
        --no-trailer) NO_TRAILER=1 ;;
        *) echo "==> unknown flag: $arg" >&2; exit 2 ;;
    esac
done

# ── resolve the jac toolchain for nacompile (same order as build.sh) ──────────
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

# ── resolve a FUSED jac binary for the trailer payload (skipped --no-trailer) ──
# Only a binary carrying the [payload][trailer] qualifies (an editable jaclang
# has none). Prefer $JAC_BIN, then the repo zig-out binary.
if [ -z "$NO_TRAILER" ]; then
    FUSED_JAC=""
    if [ -n "${JAC_BIN:-}" ] && [ -x "${JAC_BIN}" ]; then
        FUSED_JAC="$JAC_BIN"
    elif [ -x "$REPO_JAC" ]; then
        FUSED_JAC="$REPO_JAC"
    fi
    if [ -z "$FUSED_JAC" ]; then
        echo "==> No fused jac binary for the trailer payload." >&2
        echo "    Build one: (cd jac && zig build) -> jac/zig-out/bin/jac, or set JAC_BIN." >&2
        echo "    (Or pass --no-trailer to emit the runtime-borrowing payload variant.)" >&2
        exit 1
    fi
    echo "==> Trailer source (fused runtime): $FUSED_JAC"

    # ── a python for the byte surgery (trailer append) -- stdlib, any python3 ──
    if [ -x "$REPO_VENV/bin/python" ]; then
        PY="$REPO_VENV/bin/python"
    else
        PY="$(command -v python3 || true)"
    fi
    [ -n "$PY" ] || { echo "==> No python3 for trailer append." >&2; exit 1; }
fi

# ── select the TTY backend (same matrix as build.sh) ──────────────────────────
HOST="$(uname -s 2>/dev/null || echo "unknown")"
case "${JAC_AI_TUI_TARGET:-}" in
    linux)  TTY=linux  ;;
    darwin) TTY=darwin ;;
    *)
        case "$HOST" in
            Linux*)       TTY=linux  ;;
            Darwin*)      TTY=darwin ;;
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

# ── locate the libjacpyembed shim in the running jaclang tree ─────────────────
# Dev tree ships it under desktop/native/; payload-staged builds carry the same.
# $JAC_PYEMBED_SHIM overrides the REPO_ROOT-derived path: the payload stages the
# shim under <site>/jaclang/... where this script's REPO_ROOT (computed from its
# own location) would not point, so payload.zig passes the staged path directly.
SHIM_SRC="${JAC_PYEMBED_SHIM:-$REPO_ROOT/jac/jaclang/runtimelib/client/targets/desktop/native/$SHIM}"
if [ ! -f "$SHIM_SRC" ]; then
    echo "==> libjacpyembed shim not found at $SHIM_SRC" >&2
    echo "    Rebuild the jac binary (cd jac && zig build) so the shim is present." >&2
    exit 1
fi

# ── stage the split TTY backend + the shim into the compile dir ──────────────
# The TTY backend is a shared logic module (tty/libc_tty_base.na.jac) plus a
# per-platform bindings+constants module (tty/tty_plat.<os>.na.jac). Stage both:
# shared -> libc_tty.na.jac (host_embed.na.jac imports .libc_tty statically),
# platform -> tty_plat.na.jac (imported by libc_tty_base). host_embed also does
# `import from jacpyembed`; nacompile resolves both from its cwd (= this dir).
# All three are gitignored build scratch -- the trap removes them on any exit.
cp "$PLAT" tty_plat.na.jac
cp tty/libc_tty_base.na.jac libc_tty.na.jac
cp "$SHIM_SRC" "$SHIM"

# Stage Phase 5 nested tui/ + components/ modules flat for nacompile.
# shellcheck source=_stage_modules.sh
source "$SCRIPT_DIR/_stage_modules.sh"
stage_tui_modules

mkdir -p bin

# Build into a temp path and atomically rename into place only on success, so a
# killed or failed compile never leaves a partial/corrupt binary at OUT (a stale
# reader booting against a live writer). The trap sweeps the temp on any exit.
OUT="bin/jac-ai-tui"
TMP="bin/.jac-ai-tui.partial.$$"
trap "rm -f tty_plat.na.jac libc_tty.na.jac '$SCRIPT_DIR/$SHIM' '$SCRIPT_DIR/$TMP'; cleanup_staged_modules" EXIT

# ── 1. nacompile the embed host ───────────────────────────────────────────────
echo "==> Compiling jac-ai-tui (embed host) ..."
"${JAC[@]}" nacompile host_embed.na.jac ${XFLAGS:+$XFLAGS} -o "$TMP"
echo "==> Compiled: $SCRIPT_DIR/$TMP"

# ── 2. stage the shim $ORIGIN-adjacent (next to the binary) + set $ORIGIN rpath ─
cp "$SHIM_SRC" "bin/$SHIM"
if command -v patchelf >/dev/null 2>&1; then
    patchelf --set-rpath '$ORIGIN' "$TMP" || \
        echo "==> patchelf rpath patch failed; rely on a sibling $SHIM at runtime"
else
    echo "==> patchelf not found; the native backend's emitted \$ORIGIN runpath is used"
fi

# ── 3. append the fused-runtime [payload][trailer] (mirror _bundle_runtime) ────
if [ -n "$NO_TRAILER" ]; then
    mv -f "$TMP" "$OUT"
    echo "==> --no-trailer: emitting runtime-borrowing host (no trailer appended)"
    echo "==> Done. Trailerless TUI host: $SCRIPT_DIR/$OUT (+ bin/$SHIM)"
    echo "    Boots only with JAC_RT_DIR pointing at a materialized rt (payload use)."
    exit 0
fi

echo "==> Appending fused-runtime trailer payload ..."
"$PY" - "$FUSED_JAC" "$TMP" <<'PYEOF'
import sys
src, host = sys.argv[1], sys.argv[2]
data = open(src, "rb").read()
magic = b"JACBIN01"
tlen = 8 + 8 + 64  # magic | payload_len(u64 LE) | sha256 hex
if len(data) < tlen or data[-tlen:-tlen + 8] != magic:
    sys.exit(f"{src} carries no fused-runtime trailer (need a `zig build` jac)")
payload_len = int.from_bytes(data[-tlen + 8:-tlen + 16], "little")
suffix = data[-(tlen + payload_len):]
with open(host, "ab") as f:
    f.write(suffix)
print(f"   appended {len(suffix)} bytes ([payload]={payload_len} + [trailer]={tlen})")
PYEOF

mv -f "$TMP" "$OUT"
# Record input freshness so `jac ai tui` can reject stale/corrupt artifacts.
python3 - "$SCRIPT_DIR" "$SCRIPT_DIR/bin" <<'PYEOF'
import glob, os, sys
na_dir, bindir = sys.argv[1], sys.argv[2]
newest = 0.0
for pattern in (os.path.join(na_dir, "**", "*.na.jac"),):
    for path in glob.glob(pattern, recursive=True):
        try:
            newest = max(newest, os.path.getmtime(path))
        except OSError:
            pass
for name in ("build_embed.sh", "_stage_modules.sh"):
    p = os.path.join(na_dir, name)
    try:
        newest = max(newest, os.path.getmtime(p))
    except OSError:
        pass
repo_root = os.path.normpath(os.path.join(na_dir, "..", "..", "..", ".."))
shim = os.path.join(
    repo_root, "jac", "jaclang", "runtimelib", "client", "targets",
    "desktop", "native", "libjacpyembed.so",
)
try:
    newest = max(newest, os.path.getmtime(shim))
except OSError:
    pass
with open(os.path.join(bindir, ".embed_build_stamp"), "w", encoding="utf-8") as f:
    f.write(f"{newest}\n")
PYEOF
echo "==> Done. Self-hosting TUI binary: $SCRIPT_DIR/$OUT"
echo "    Boot test (stub agent, no byllm): ./bin/jac-ai-tui"
echo "    Real agent: set JAC_AI_TUI_BYLLM_SRC + JAC_AI_TUI_DEPS, then ./bin/jac-ai-tui"
