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
#                         (must contain install/lib/libpython3.14.{dylib,so})
#   <jaclang-source-dir>  the in-repo `jac/` source (clean-break: NOT PyPI)
#
# Env:
#   PRECOMPILE=0   skip the _precompiled JIR step (faster build, ~30s first run)
set -euo pipefail

PBS="${1:?pbs python dir}"; JACSRC="${2:?jaclang source dir}"; OUT="${3:?output .tar.zst}"
PRECOMPILE="${PRECOMPILE:-1}"

# Bundled CPython minor version -- keep in lockstep with fetch-pbs.sh (PBS_PY)
# and launcher.zig (py_ver).
PYVER=3.14
case "$(uname -s)" in
  Darwin) LIBPY="libpython${PYVER}.dylib" ;;
  *)      LIBPY="libpython${PYVER}.so" ;;
esac
PY="$PBS/install/bin/python${PYVER}"
[ -x "$PY" ] || PY="$PBS/install/bin/python3"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
site="$WORK/site"; stage="$WORK/stage"

echo "==> assembling jaclang site from source (no pyproject build)"
"$PY" -m ensurepip --upgrade >/dev/null 2>&1 || true
"$PY" -m pip install --quiet --upgrade pip >/dev/null 2>&1 || true
mkdir -p "$site"
# typeshed stdlib stubs are gitignored (fetched at the pinned commit, not
# committed). Materialize them before the copy so they ride into the payload.
if [ ! -f "$JACSRC/jaclang/vendor/typeshed/stdlib/VERSIONS" ]; then
  bash "$JACSRC/launcher/fetch-typeshed.sh"
fi
# jaclang is pure source + data (no compiled extension of its own), so copy it
# straight from the tree instead of building a wheel -- no pyproject backend.
cp -R "$JACSRC/jaclang" "$site/jaclang"
# _jac_finder: the lazy .jac import finder (launcher BOOT_SRC calls its
# install()) plus add_project_venv_to_path(). sitecustomize runs the latter
# during interpreter startup in BOTH the jac CLI and bare `jac -m <tool>` mode,
# so a project's .jac/venv (deps + plugins) is on sys.path for both. No .pth
# shim is shipped (that was editable-install-only).
cp "$JACSRC/_jac_finder.py" "$site/"
cp "$JACSRC/sitecustomize.py" "$site/"
find "$site/jaclang" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
find "$site/jaclang" -name '*.pyc' -delete 2>/dev/null || true
rm -rf "$site/jaclang/_precompiled" 2>/dev/null || true
# Ship typeshed stdlib stubs only -- third-party stubs are installed per-project
# into .jac/venv by `jac add` (PEP 561 types-*). The vendored tree is already
# stdlib-only; this defensive prune covers a stray full typeshed checkout.
rm -rf "$site/jaclang/vendor/typeshed/stubs" 2>/dev/null || true
[ -f "$site/_jac_finder.py" ] || { echo "error: _jac_finder.py missing from site"; exit 1; }

# Minimal dist-info so importlib.metadata sees jaclang -- the version drives JIR
# keying (pkg_version('jaclang')) and the entry points back the pytest11 plugin
# (`jac test`) and the built-in `jac.modules` (desktop). Version comes from
# jac.toml, so the build never reads pyproject.toml.
ver="$("$PY" -c "import tomllib,sys; print(tomllib.load(open(sys.argv[1],'rb'))['project']['version'])" "$JACSRC/jac.toml")"
di="$site/jaclang-${ver}.dist-info"; mkdir -p "$di"
printf 'Metadata-Version: 2.1\nName: jaclang\nVersion: %s\n' "$ver" > "$di/METADATA"
cat > "$di/entry_points.txt" <<EOT
[pytest11]
jaclang = jaclang.pytest_plugin

[jac.modules]
desktop = jaclang.runtimelib.client.desktop_plugin_config:desktop_sdk_path

[jac.module_exports]
desktop = jaclang.runtimelib.client.desktop_plugin_config:desktop_sdk_exports
EOT

# The sole runtime dependency (a binary wheel; from PyPI, not the jaclang repo).
# Pin to jac.toml's declared constraint (single source of truth) so a breaking
# llvmlite release can't silently get baked into the binary.
llvmlite_spec=$(grep -oE 'llvmlite[^"]+' "$JACSRC/jac.toml" | head -1)
echo "==> fetching runtime dep: ${llvmlite_spec:-llvmlite>=0.43.0}"
"$PY" -m pip install --quiet "${llvmlite_spec:-llvmlite>=0.43.0}" --target "$site"

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
    # DONTWRITEBYTECODE so importing _jac_finder/jaclang here doesn't litter
    # `site/__pycache__` -- its presence makes the later `pip install --target`
    # refuse the directory. JIR generation is independent of .pyc writing.
    PYTHONHOME="$PBS/install" PYTHONPATH="$site" PYTHONUTF8=1 PYTHONDONTWRITEBYTECODE=1 HOME="$WORK" PATH=/usr/bin:/bin \
      "$PY" -S "$boot" >"$WORK/precompile.log" 2>&1 || true
    jir=$( { find "$site/jaclang/_precompiled" -name '*.jir' 2>/dev/null || true; } | wc -l | tr -d ' ')
    skipped=$(grep -cE 'Error: FAIL:' "$WORK/precompile.log" 2>/dev/null || echo 0)
    if [ "${jir:-0}" -ge 300 ]; then
      echo "   _precompiled: ${jir} JIR generated (${skipped} core modules compile at runtime by design)"
    else
      # Below the healthy floor means the precompiler crashed, not the handful of
      # by-design skips. Fail the build rather than silently shipping a binary
      # that takes the slow cold-start path with no precompiled JIR.
      echo "   ERROR: only ${jir:-0} JIR produced (expected >=300); precompiler likely crashed." >&2
      tail -40 "$WORK/precompile.log" >&2 || true
      exit 1
    fi
  fi
fi

# Bundle runtime helpers so the sealed binary needs no system Python or pip:
#   pytest + pytest-xdist -> `jac test`
#   watchdog               -> `jac start --dev` file watching
#   tomlkit                -> format-preserving TOML writes for `jac` project /
#                             release tooling (version bumps in jac.toml)
# Installed AFTER precompile so the precompiler's package walk only sees jaclang
# (extra packages yield 0 JIR).
echo "==> bundling pytest + pytest-xdist (jac test) + watchdog (jac start --dev)"
# Drop any stray bytecode cache so pip doesn't refuse the populated --target dir.
rm -rf "$site"/__pycache__ 2>/dev/null || true
"$PY" -m pip install --quiet pytest pytest-xdist "watchdog>=3.0.0" tomlkit --target "$site"

echo "==> staging runtime tree (shared libpython + stdlib + site)"
mkdir -p "$stage/python/lib"
# Stage the shared libpython under its bare name. Linux pbs may ship it only as
# libpython3.14.so.1.0 (with a .so symlink); the launcher dlopens the bare name,
# so dereference (-L) the real library into "$LIBPY".
srclib="$PBS/install/lib/$LIBPY"
if [ ! -e "$srclib" ]; then
  srclib="$(ls "$PBS/install/lib/${LIBPY}".* 2>/dev/null | head -1 || true)"
fi
[ -n "${srclib:-}" ] && [ -e "$srclib" ] || { echo "error: shared libpython not found under $PBS/install/lib" >&2; exit 1; }
cp -L "$srclib" "$stage/python/lib/$LIBPY"
cp -R "$PBS/install/lib/python${PYVER}" "$stage/python/lib/python${PYVER}"
# Prune heavy/build-only stdlib bits. KEEP lib-dynload (extension .so for the
# shared interpreter) and KEEP encodings/etc. KEEP ensurepip: `jac install`
# bootstraps a project venv with `<binary> -m ensurepip --default-pip`, so
# pruning it broke venv creation for every project that has dependencies.
for d in test idlelib turtledemo tkinter lib2to3; do
  rm -rf "$stage/python/lib/python${PYVER}/$d"
done
rm -rf "$stage"/python/lib/python${PYVER}/config-${PYVER}-* 2>/dev/null || true
cp -R "$site" "$stage/site"

# macOS hygiene: AppleDouble (._*) sidecars are not valid source and break
# jaclang's .impl scanner; .DS_Store likewise.
find "$stage" \( -name '._*' -o -name '.DS_Store' \) -delete

echo "==> packing tar | zstd -19"
( cd "$stage" && COPYFILE_DISABLE=1 tar --no-xattrs -cf "$WORK/payload.tar" python site )
zstd -19 -T0 -f -q "$WORK/payload.tar" -o "$OUT"
echo "==> payload: $(du -h "$OUT" | cut -f1)  ->  $OUT"
