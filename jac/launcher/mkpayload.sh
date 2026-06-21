#!/usr/bin/env bash
# Assemble the jac single-binary runtime payload: a private CPython (shared
# libpython + stdlib) plus the jaclang `site/`, tarred + zstd-compressed. The
# launcher (launcher.zig) dlopens the shared libpython at runtime, so -- unlike a
# static embed -- lib-dynload (the extension .so) must be KEPT.
#
# Usage:
#   mkpayload.sh <pbs-python-dir> <jaclang-source-dir> <out.tar.zst>
#
#   <pbs-python-dir>      extracted python-build-standalone `python/` dir
#                         (must contain install/lib/libpython3.12.{dylib,so})
#   <jaclang-source-dir>  the in-repo `jac/` source (clean-break: NOT PyPI)
#
# Env:
#   PRECOMPILE=0   skip the _precompiled JIR step (faster build, ~30s first run)
set -euo pipefail

PBS="${1:?pbs python dir}"; JACSRC="${2:?jaclang source dir}"; OUT="${3:?output .tar.zst}"
PRECOMPILE="${PRECOMPILE:-1}"

case "$(uname -s)" in
  Darwin) LIBPY=libpython3.12.dylib ;;
  *)      LIBPY=libpython3.12.so ;;
esac
PY="$PBS/install/bin/python3.12"
[ -x "$PY" ] || PY="$PBS/install/bin/python3"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
site="$WORK/site"; stage="$WORK/stage"

echo "==> pip install jaclang (from source) into site/"
"$PY" -m ensurepip --upgrade >/dev/null 2>&1 || true
"$PY" -m pip install --quiet --upgrade pip >/dev/null 2>&1 || true
"$PY" -m pip install --quiet "$JACSRC" --target "$site"
[ -f "$site/_jac_finder.py" ] || { echo "error: _jac_finder.py missing from site"; exit 1; }

# Strip build-time-only tooling (never needed at runtime).
( cd "$site" && rm -rf pip pip-* setuptools setuptools-* pkg_resources _distutils_hack \
    && rm -f ./*.dist-info/RECORD ) 2>/dev/null || true

if [ "$PRECOMPILE" = "1" ]; then
  echo "==> precompiling jaclang -> _precompiled JIR (fast first run)"
  pc="$site/jaclang/utils/precompile_bytecode.jac"
  if [ -f "$pc" ]; then
    boot="$WORK/precompile_boot.py"
    {
      echo "import sys"
      echo "import _jac_finder; _jac_finder.install()"
      echo "sys.argv = ['jac', 'run', r'''$pc''', r'''$site''']"
      echo "from jaclang.jac0core.cli_boot import start_cli"
      echo "start_cli()"
    } > "$boot"
    # The precompiler intentionally CANNOT bytecode-compile a handful of core
    # modules (jir/archetype/modresolver) and so exits non-zero -- that is
    # expected, not a failure. Judge success by the JIR actually produced, not
    # by the exit code (these modules just compile at runtime instead).
    PYTHONHOME="$PBS/install" PYTHONPATH="$site" PYTHONUTF8=1 HOME="$WORK" PATH=/usr/bin:/bin \
      "$PY" -S "$boot" >"$WORK/precompile.log" 2>&1 || true
    jir=$(find "$site/jaclang/_precompiled" -name '*.jir' 2>/dev/null | wc -l | tr -d ' ')
    skipped=$(grep -cE 'Error: FAIL:' "$WORK/precompile.log" 2>/dev/null || echo 0)
    if [ "${jir:-0}" -ge 300 ]; then
      echo "   _precompiled: ${jir} JIR generated (${skipped} core modules compile at runtime by design)"
    else
      echo "   WARNING: only ${jir:-0} JIR produced -- first run will be slow. See $WORK/precompile.log"
      tail -20 "$WORK/precompile.log" || true
    fi
  fi
fi

echo "==> staging runtime tree (shared libpython + stdlib + site)"
mkdir -p "$stage/python/lib"
cp "$PBS/install/lib/$LIBPY" "$stage/python/lib/"
cp -R "$PBS/install/lib/python3.12" "$stage/python/lib/python3.12"
# Prune heavy/build-only stdlib bits. KEEP lib-dynload (extension .so for the
# shared interpreter) and KEEP encodings/etc.
for d in test idlelib turtledemo tkinter ensurepip lib2to3; do
  rm -rf "$stage/python/lib/python3.12/$d"
done
rm -rf "$stage"/python/lib/python3.12/config-3.12-* 2>/dev/null || true
cp -R "$site" "$stage/site"

# macOS hygiene: AppleDouble (._*) sidecars are not valid source and break
# jaclang's .impl scanner; .DS_Store likewise.
find "$stage" \( -name '._*' -o -name '.DS_Store' \) -delete

echo "==> packing tar | zstd -19"
( cd "$stage" && COPYFILE_DISABLE=1 tar --no-xattrs -cf "$WORK/payload.tar" python site )
zstd -19 -T0 -f -q "$WORK/payload.tar" -o "$OUT"
echo "==> payload: $(du -h "$OUT" | cut -f1)  ->  $OUT"
