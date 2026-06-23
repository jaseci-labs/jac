# jac single-binary launcher (Zig, dlopen embed)

`jac` is built as a Zig project (`jac/build.zig`) that produces **one
self-contained executable**: a tiny native launcher with the jaclang runtime +
a private CPython appended as a payload. It needs **no system Python, uv, or
pip** at install or runtime.

Instead of statically linking CPython (reconstructing 100+ objects, bundled
archives and OS frameworks from pbs's `PYTHON.json`), the launcher **`dlopen`s a
shared `libpython` at runtime** -- the same way jac-native loads LLVM/native code
(llvmlite + ctypes, see `jaclang/jac0core/native_marshal.jac`). This keeps the
build trivial: the launcher links only libc, with **zero Python at build time**.

## Files

| File | Role |
|---|---|
| `launcher.zig` | Process entry. Materializes the payload, `dlopen`s the bundled libpython, `dlsym`s ~6 `Py_*` functions, runs the jaclang boot dance. No `@cImport`, no Python headers. |
| `runtime.zig` | Pure-Zig payload materialization: trailer parse, cache resolution, zstd+tar extract into `~/.cache/jac/rt/<hash16>`, stale GC. Unit-tested (`zig build test`). |
| `pack.zig` | Build-time tool: `[stub][payload.tar.zst][trailer]` -> final `jac`. |
| `mkpayload.sh` | Build-time payload assembler (pip-install jaclang from source, stage CPython + site, tar+zstd). |
| `tests/fixtures/payload.tar.zst` | Fixture for the materialize unit test. |

## Binary shape

```
jac = [ launcher stub (links libc only) ][ runtime.tar.zst ][ trailer ]
trailer = "JACBIN01" | payload_len(u64 LE) | sha256_hex(64)   (80 bytes, at EOF)
```

Payload, materialized to `<cache>/rt/<hash16>/` on first run:

```
python/lib/libpython3.12.{dylib,so}   <- dlopened (RTLD_NOW|RTLD_GLOBAL)
python/lib/python3.12/                 <- stdlib (incl. lib-dynload: extension .so)
site/                                  <- jaclang + _jac_finder + llvmlite
```

> Unlike a static embed, the shared interpreter loads its C extensions from
> `lib-dynload/` on demand, so that directory is **kept** (a static build prunes
> it). The launcher points the interpreter at this tree via `PYTHONHOME`.

## Build

```bash
cd jac

zig build test                       # launcher unit tests (no libpython needed)
zig build stub                       # just the launcher (links only libc)

# Full binary: assemble a payload, then pack it onto the stub.
#   <pbs-python-dir> = extracted python-build-standalone `python/` dir (3.12, full or install_only)
./launcher/mkpayload.sh <pbs-python-dir> . /tmp/payload.tar.zst
zig build -Dpayload=/tmp/payload.tar.zst -Doptimize=ReleaseSmall
./zig-out/bin/jac --version
```

The launcher cross-compiles to any target with `zig build -Dtarget=...`
(`x86_64-linux-gnu.2.17`, `aarch64-macos`, ...) -- `dlopen` is uniform across
Linux (`.so`) and macOS (`.dylib`), no per-OS framework enumeration. The pbs
archive is only a payload input; it is never linked.

## Status / follow-ups

- **Validated on macos-aarch64**: `jac --version` and `jac run` (obj + methods +
  comprehensions) work from a clean `HOME`; warm start ~0.3s.
- **Precompiled JIR bundle ships** (`mkpayload.sh` with `PRECOMPILE=1`, the
  default): 334 modules precompiled, so a cold run does **0 live compilations**
  (vs ~100 without the bundle). The precompiler intentionally leaves a few core
  modules (`jir`, `archetype`, `modresolver`) to compile at runtime and exits
  non-zero; the script judges success by JIR produced, not the exit code.
  - Cold start is then dominated by payload extraction + first-time JIR cache
    laundering, not compilation. Sealing the runtime (shipping JIR-only, no
    `.jac`/live compile of the bootstrap layer) is the further win -- issue
    #6852 Phase 4.
- **Linux**: ensure the staged shared lib is named `libpython3.12.so` (pbs may
  ship `libpython3.12.so.1.0` -- symlink/copy to the bare name in staging).
