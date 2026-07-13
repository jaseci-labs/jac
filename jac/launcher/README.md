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
| `runtime.zig` | Pure-Zig payload materialization + the SOLE owner of the on-disk trailer format: `parseTrailer`, cache resolution, gzip+tar extract into `~/.cache/jac/rt/<hash16>-<pathhash>` (path-folded so co-located checkouts don't collide), stale GC, plus the `.jab`-overlay helpers (`overlayForPath`, `appendOverlay`, `graftRuntime`). Unit-tested (`zig build test`). |
| `pack.zig` | Build-time tool: `[stub][payload.tar.gz][trailer]` -> final `jac`. |
| `payload.zig` | Build-time payload tool (pure std): `fetch-pbs` (HTTP + verify + zstd-extract a python-build-standalone tree), `fetch-typeshed` (HTTP tarball + sha256-verify the stdlib stubs), `mkpayload` (stage CPython + jaclang site, tar+gzip). Shells out only to the fetched pbs python for pip + JIR precompile. Replaces the old bash/curl/git/zstd/tar scripts. |
| `tests/fixture.zig` | base64 tar.gz fixture for the materialize unit test. |

## Binary shape

```
jac = [ launcher stub (links libc only) ][ runtime.tar.gz ][ trailer ]
trailer = "JACBIN01" | payload_len(u64 LE) | sha256_hex(64)   (80 bytes, at EOF)
```

A `jac build --as binary` app binary appends its sealed `.jab` after that, with
its own 80-byte overlay trailer (same codec, distinct magic):

```
app = [ base jac (verbatim) ][ app.jab ][ overlay trailer ]
overlay trailer = "JABOVL01" | jab_len(u64 LE) | sha256_hex(64)   (80 bytes, at EOF)
```

The base bytes are the installed `jac`, byte-for-byte -- `jac __appjab <app.jab>
<out>` copies this binary and appends the `.jab` (no CPython unpack/repack). At
boot the launcher detects the `JABOVL01` marker, steps over the overlay to find
the real payload trailer (so the CPython tree extracts unchanged), and exports
`JAC_APP_OVERLAY_OFF/_LEN` so `cli_boot` slices the `.jab` out of the running
binary and mounts it exactly like `jac run app.jab`. The trailer format lives
only here in Zig; nothing in Python parses or writes it.

Payload, materialized to `<cache>/rt/<hash16>-<pathhash>/` on first run (the
`<pathhash>` folds in the binary's own path so two co-located checkouts with
identical payloads get distinct trees):

```
python/lib/libpython3.14.{dylib,so}   <- dlopened (RTLD_NOW|RTLD_GLOBAL)
python/lib/python3.14/                 <- stdlib (incl. lib-dynload: extension .so)
site/                                  <- jaclang + _jac_finder + llvmlite
```

> Unlike a static embed, the shared interpreter loads its C extensions from
> `lib-dynload/` on demand, so that directory is **kept** (a static build prunes
> it). The launcher points the interpreter at this tree through the PEP 741
> init config (`home` / `pythonpath_env`) -- never via `PYTHONHOME`/`PYTHONPATH`
> environment variables, which children would inherit (#7047).

## Build

```bash
cd jac

zig build test                       # launcher unit tests (no libpython needed)
zig build stub                       # just the launcher (links only libc)

# Full binary, one command: zig build runs payload.zig to fetch the pbs tree +
# typeshed over HTTP, assemble the payload, and pack it onto the stub.
zig build                            # -> zig-out/bin/jac
./zig-out/bin/jac --version

zig build -Dpayload-progress         # same, but stream the payload build live
zig build -Dpayload=/tmp/p.tar.gz    # pack a prebuilt payload (skip fetch+assemble)
```

Build-time host deps: just `zig` + network (plus an optional, best-effort
`strip` to shrink the unstripped pbs libpython ~245 MiB -> ~20 MiB; the build
still works without it). `payload.zig` does HTTP, integrity, (de)compression and
tar in std; it shells out only to the freshly-fetched pbs python (pip + JIR
precompile, which need a real CPython). The launcher
cross-compiles to any target with `zig build -Dtarget=...`
(`x86_64-linux-gnu.2.17`, `aarch64-macos`, ...) -- `dlopen` is uniform across
Linux (`.so`) and macOS (`.dylib`), no per-OS framework enumeration. The pbs
archive is only a payload input; it is never linked.

## Status / follow-ups

- **Validated on macos-aarch64**: `jac --version` and `jac run` (obj + methods +
  comprehensions) work from a clean `HOME`; warm start ~0.3s.
- **Precompiled JIR bundle ships** (the `mkpayload` precompile step): 300+
  modules precompiled, so a cold run does **0 live compilations** (vs ~100
  without the bundle). The precompiler intentionally leaves a few core modules
  (`jir`, `archetype`, `modresolver`) to compile at runtime and exits non-zero;
  the tool judges success by the `PRECOMPILE_RESULT.json` completion marker
  written at the end of an uncrashed run, not the exit code, and the seal
  finalize pass verifies every sealable module actually produced a JIR.
- **Sealed runtime (the only bundled shape; #6852 Phase 4 / #7135).** A bundled
  `zig build` payload boots from a sealed JIR *image*: `_precompiled/MANIFEST.json`
  maps module fullnames to JIR (full compiler) + frozen bootstrap JIRs (the
  jac0core layer, incl. `modresolver`), and jaclang's own `JacMetaImporter`
  resolves its modules by name from the manifest **first** -- no filesystem
  `.jac` probing, no per-load source re-hash, no runtime compilation of sealed
  modules. The `.jac` sources still ship alongside (tracebacks, `inspect`, and
  fallback for an unreadable JIR): the seal is about trust and load semantics,
  not source concealment. Trust moves to build time (the manifest) + the
  existing payload sha256 trailer; explicitly registered app images are
  additionally hash-verified per JIR. The runtime fail-closes on a
  manifest/tag/JIR-format mismatch rather than degrading to live compilation.
  Sealing is strict: any precompile failure aborts the build.
  - `--seal` (passed by `mkpayload` for every bundled build) freezes the
    bootstrap layer, verifies completeness, and emits the manifest. It is inert
    only where there is nothing to seal: `-Ddev`/`-Djaclang-dir` (linked
    source, the compiler is served from a live tree) and `-Dskip-precompile`.
    `-Ddebug-src` embeds source text in each JIR so tracebacks render from the
    JIR itself (via the loader's `get_source` + `linecache`); release omits it.
  - One image, three shapes: `jac build --as sealed` emits the manifest+JIR
    image dir for a **user app**, loadable in a host jac via
    `jaclang.jac0core.sealed.register_image(<dir>/_precompiled)`; `--as jab`
    tars that image into a single `.jab`; `--as binary` appends that same `.jab`
    as an overlay onto a copy of the running sealed binary (see **Binary shape**
    above -- no CPython unpack/repack), yielding a self-contained executable that
    `cli_boot` mounts (via `run_jab_image`, the same path as `jac run app.jab`)
    and dispatches to instead of the jac CLI.
- **Linux**: the staged shared lib is named `libpython3.14.so` (pbs may ship
  `libpython3.14.so.1.0` -- `mkpayload` dereferences it to the bare name).
