# jac single-binary launcher (Jac, dlopen embed)

`jac` is one self-contained executable: a small native launcher stub with the
jaclang runtime + the JacPython runtime appended as a payload. It needs **no system
Python, uv, or pip** at install or runtime. Both halves are Jac:

| Piece | Where | Tier |
|---|---|---|
| Launcher stub (`launcher.jac`) | this directory | native (`jac build --as native` / `nacompile`) |
| Fused-runtime library | `jaclang/dist/fused/` | native, shipped in the payload |
| Payload tool (fetch, stage, precompile, pack) | `jaclang/dist/payload/` | Python tier, run on the JacPython runtime |
| Bootstrap seeds (`build_python.zig`, `fetch_typeshed.zig`), `pins.json` | `bootstrap/` | Zig + the pin files |
| `build.zig` | `jac/` | the one-command entry; also the C/C++ cross-compiler for the LLVM shim and the vendored runtimes |

Instead of statically linking the runtime, the launcher **`dlopen`s JacPython's
bundled `libpython` at runtime** -- the same way jac-native loads LLVM. The stub links
only libc (and `libdl` on Linux, so it also runs on glibc < 2.34); nothing
Python is linked at build time.

## The fused-runtime library (`jaclang/dist/fused/`)

| Module | Role |
|---|---|
| `trailer.jac` | The ONE definition of the on-disk trailer format (`JACBIN01` / `JABOVL01`, 80 bytes) and the `rt/<hash16>-<pathhash>` cache key. Pure Jac, so the same source binds on the native pathway (the stub) and the Python pathway (`jaclang.dist.fused_binary`: `jac build --as binary`, the desktop graft, the payload tool's `pack`). |
| `materialize.jac` | Find the trailer at the end of the running executable (stepping over a `.jab` overlay), resolve the cache dir (`$XDG_CACHE_HOME` / `$HOME/.cache` / per-uid tmp), and on first run verify (sha256) + extract the payload: `ZstdFile(io.BytesIO(payload))` into `tarfile.open(..., mode="r|").extractall()` -- the bundled native `compression.zstd` / `tarfile` / `io` modules, exactly what the runtime itself would run. Per-pid temp dir, `.ok` marker, atomic rename, GC of this binary's older trees. |
| `embed.jac` | dlopen the bundled libpython (`RTLD_NOW\|RTLD_GLOBAL`), bind the C-API the hosts use (`PyApi`: function-pointer fields filled by `dlsym`), and initialize through the PEP 741 init-config API: home, module search paths and program name go to the runtime directly, never through the environment (#7047). Worker mode (`parse_argv`) and print-and-exit flags (`-V`, `-h`) are honoured. |
| `bringup.jac` | `open_runtime(exe)` = materialize + dlopen; `engine_boot()` = the desktop host's bring-up (materialize, dlopen, init with no argv). |
| `report.jac` | `die` (message + exit 70) and `say` (cold-start narration) to stderr, before the Python runtime exists. |
| `_libc.jac` | The portable libc floor: positional reads (`fopen`/`fseeko`/`fread`), directory listing, malloc'd C strings and the `char**` lists PEP 741 takes. |

The OS-specific pieces are bundled native stdlib floors with per-OS variants
(`na_stdlib/_dl_native.{linux,darwin}.jac`, `_exec_native.{linux,darwin}.jac`).

The desktop host (`jaclang/client/targets/desktop`) imports the same
library: the builder stages `fused/` beside the generated host so `import from
fused.bringup { engine_boot }` resolves, and grafts the running jac's
`[ payload ][ trailer ]` onto the host binary. There is no longer a
`libjacpyembed` shim.

## Binary shape

```
jac = [ launcher stub (links libc/libdl only) ][ runtime.tar.zst ][ trailer ]
trailer = "JACBIN01" | payload_len(u64 LE) | sha256_hex(64)   (80 bytes, at EOF)
```

A `jac build --as binary` app binary appends its sealed `.jab` after that, with
its own 80-byte overlay trailer (same codec, distinct magic):

```
app = [ base jac (verbatim) ][ app.jab ][ overlay trailer ]
overlay trailer = "JABOVL01" | jab_len(u64 LE) | sha256_hex(64)
```

The base bytes are the installed `jac`, byte-for-byte: `fused_binary.append_overlay`
copies this binary and appends the `.jab` (no runtime unpack/repack). At boot the
launcher detects the `JABOVL01` marker, steps over the overlay to find the real
payload trailer, and exports `JAC_APP_OVERLAY_OFF/_LEN` so `cli_boot` slices the
`.jab` out of the running binary and mounts it exactly like `jac run app.jab`.

The payload is two concatenated zstd frames (a content-addressed deps frame the
build reuses across runs, and a small per-commit jac frame) whose decoded
concatenation is one tar stream. Materialized to `<cache>/rt/<hash16>-<pathhash>/`
on first run (`<pathhash>` folds in the binary's own path, #7012):

```
python/lib/libpython3.14.{dylib,so}   <- dlopened (RTLD_NOW|RTLD_GLOBAL)
python/lib/python3.14/                 <- stdlib (incl. lib-dynload: extension .so)
site/                                  <- jaclang + _jac_finder
```

## Build

```bash
cd jac

zig build test                       # bootstrap unit tests (no network needed)
zig build stub                       # just the launcher stub (no payload)
zig build build-python               # just the JacPython runtime and its native libraries
zig build                            # -> zig-out/bin/jac
./zig-out/bin/jac --version

zig build -Djacpython-host=seed      # build the runtime on the bootstrap seed
zig build -Dpayload-progress         # stream the payload build live
zig build -Dpayload=/tmp/p.tar.zst   # pack a prebuilt payload (skip fetch+assemble)
zig build -Ddev                      # editable dev binary: link the compiler from this tree
```

`zig build` first builds the JacPython runtime (`bootstrap/build_python.zig`)
and fetches the pinned typeshed stubs. A JacPython build runs on an earlier
JacPython: the previous build's output when it is complete and on the pinned
Python version, else the checksum-pinned bootstrap seed in
`bootstrap/python/seed.json`. `.github/workflows/build-seeds.yml` publishes the
seeds to the rolling `deps` prerelease. `-Djacpython-host=seed|<path>` picks the
host instead: always the seed, or an installed runtime's prefix
(`.../python/install`) or the build output holding it. If a build fails on the
previous runtime, `-Djacpython-host=seed` rules out a defect carried forward
from it.

The vendored C libraries (zlib, bzip2, zstd, sqlite, xz, libffi, mpdecimal,
expat, OpenSSL) are reused from the host when it built them under the current
pins in `bootstrap/python/sources.json`; when those pins or
`bootstrap/python/vendored.sh` change, `vendored.sh` rebuilds them from source
with Zig's C toolchain. The Python standard library and the other runtime
inputs are vendored in `bootstrap/python/src` (PSF license); the C API headers
and opcode tables the Jac generators write are in `bootstrap/python/generated`.
No installed Python or Jac is needed. Build hosts need Zig 0.16.0, a POSIX
shell and network access, plus make and Perl when the vendored libraries are
rebuilt. macOS also needs the SDK provided by Xcode command line tools.

The runtime tree is `.python-build/<platform>`: the interpreter, shared
library, standard library, licenses, CA certificates, and the static archives
Jac's native backend links. A failed build never replaces a good tree.
`JAC_PYTHON_JOBS` controls build parallelism (default 4).

Each supported release platform builds on its matching runner. Linux targets
retain the glibc 2.17 floor; Intel macOS targets 12.0 and ARM macOS targets 11.0.
Stable and rolling dev releases build one binary per selected platform:
`jac-<version>-<platform>` (or `jac-dev-<platform>`), each with its own
`.sha256` checksum. Docker images use the same assets. Intel Mac remains a
manually selected release target.

* `JAC_NA_DEBUG=1 jac build --native launcher/launcher.jac` prints why a function in
  the stub's closure would be demoted to Python-only; the stub must lower in
  full (a demoted function cannot run before the Python runtime exists).
* To boot a freshly built stub against an existing payload:
  `jac run` a script that calls `jaclang.dist.fused_binary.graft_runtime(<installed jac>, <stub copy>)`,
  then run the copy with a fresh `HOME`.
* `jac test jac/tests/payload/` covers the trailer codec, deterministic staging,
  frame routing and the payload CLI; the bundled `compression.zstd` / `tarfile`
  equivalence tests cover the decode path the launcher uses.
