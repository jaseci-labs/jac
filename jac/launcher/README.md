# jac single-binary launcher (Jac, dlopen embed)

`jac` is one self-contained executable: a small native launcher stub with the
jaclang runtime + a private CPython appended as a payload. It needs **no system
Python, uv, or pip** at install or runtime. The launcher and packaging policy are Jac; a private Zig archive supplies operations needed before CPython can load:

| Piece | Where | Tier |
|---|---|---|
| Launcher stub (`launcher.jac`) | this directory | native (`jac build --as native` / `nacompile`) |
| Private bootstrap archive (`platform.zig`) | this directory | Zig standard library, statically linked |
| Fused-runtime library | `jaclang/dist/fused/` | native, shipped in the payload |
| Payload tool (fetch, stage, precompile, pack) | `jaclang/dist/payload/` | Python tier, run on source-built CPython |
| Bootstrap seeds (`build_python.zig`, `fetch_typeshed.zig`), `pins.json` | `bootstrap/` | Zig + the pin files |
| `build.zig` | `jac/` | the one-command entry; also the C/C++ cross-compiler for the LLVM shim and the vendored runtimes |

Instead of statically linking CPython, the launcher **`dlopen`s the bundled
`libpython` at runtime** -- the same way jac-native loads LLVM. The stub links
the private bootstrap archive and system libraries. Linux retains `libdl` and
`libpthread` explicitly for glibc 2.17; nothing Python is linked at build time.

## The fused-runtime library (`jaclang/dist/fused/`)

| Module | Role |
|---|---|
| `trailer.jac` | The ONE definition of the on-disk trailer format (`JACBIN01` / `JABOVL01`, 80 bytes) and the content-addressed `rt/<hash16>` cache key. Pure Jac, so the same source binds on the native pathway (the stub) and the Python pathway (`jaclang.dist.fused_binary`: `jac build --as binary`, the desktop graft, the payload tool's `pack`). |
| `materialize.jac` | Validate trailers, resolve the cache root, verify SHA256, and extract the payload through the private bootstrap interface. Publish a per-process staging directory with an `.ok` marker and atomic rename; touch last-use markers and reclaim expired runtimes. |
| `embed.jac` | dlopen the bundled libpython (`RTLD_NOW\|RTLD_GLOBAL`), bind the C-API the hosts use (`PyApi`: function-pointer fields filled by `dlsym`), and initialize through the PEP 741 init-config API: home, module search paths and program name go to CPython directly, never through the environment (#7047). Worker mode (`parse_argv`) and print-and-exit flags (`-V`, `-h`) are honoured. |
| `bringup.jac` | `open_runtime(exe)` = materialize + dlopen; `engine_boot()` = the desktop host's bring-up (materialize, dlopen, init with no argv). |
| `report.jac` | `die` (message + exit 70) and `say` (cold-start narration) to stderr, before CPython exists. |
| `_libc.jac` | Positional reads, complete writes, directory iteration, and the C string storage needed by PEP 741. Reuses the private platform interface and the compiler’s C string conversion. |

`platform.jac` declares the private C interface implemented by
`launcher/platform.zig`. Zig's standard library supplies filesystem operations,
SHA256, streaming zstd decoding, and PAX tar parsing. It accepts regular files
and directories, rejects archive traversal and links, and reads every compressed
layer before publication. The single-threaded archive includes its compiler
runtime support and is staged through the existing floor archive infrastructure
as `libjacbootstrap.a`, so desktop hosts use the same implementation.

`dl.jac` and `dl.darwin.jac` contain only the platform's dynamic-loader declarations
and flags. Linux explicitly retains `libdl.so.2` for the glibc 2.17 baseline.
No public Python stdlib module is required before loading the interpreter.

The desktop host (`jaclang/client/targets/desktop`) imports the same
library: the builder stages `fused/` beside the generated host so `import from
fused.bringup { engine_boot }` resolves, and grafts the running jac's
`[ payload ][ trailer ]` onto the host binary. There is no longer a
`libjacpyembed` shim.

## Binary shape

```
jac = [ launcher stub + private bootstrap ][ runtime.tar.zst ][ trailer ]
trailer = "JACBIN01" | payload_len(u64 LE) | sha256_hex(64)   (80 bytes, at EOF)
```

A `jac build --as binary` app binary appends its sealed `.jab` after that, with
its own 80-byte overlay trailer (same codec, distinct magic):

```
app = [ base jac (verbatim) ][ app.jab ][ overlay trailer ]
overlay trailer = "JABOVL01" | jab_len(u64 LE) | sha256_hex(64)
```

The base bytes are the installed `jac`, byte-for-byte: `fused_binary.append_overlay`
copies this binary and appends the `.jab` (no CPython unpack/repack). At boot the
launcher detects the `JABOVL01` marker, steps over the overlay to find the real
payload trailer, and exports `JAC_APP_OVERLAY_OFF/_LEN` so `cli_boot` slices the
`.jab` out of the running binary and mounts it exactly like `jac run app.jab`.

The payload is two concatenated zstd frames (a content-addressed deps frame the
build reuses across runs, and a small per-commit jac frame) whose decoded
layers are both read by the launcher. Materialized to `<cache>/rt/<hash16>/`
on first run; copies of the same payload share the same runtime cache:

```
python/lib/libpython3.14.{dylib,so}   <- dlopened (RTLD_NOW|RTLD_GLOBAL)
python/lib/python3.14/                 <- stdlib (incl. lib-dynload: extension .so)
site/                                  <- jaclang + _jac_finder
```

## Build

```bash
cd jac

zig build test-launcher              # targeted private extraction tests
zig build test                       # all bootstrap unit tests (no network needed)
zig build stub                       # just the launcher stub (no payload)
zig build                            # -> zig-out/bin/jac (stock CPython)
JACPYTHON=1 zig build                 # opt in to the native JacPython compiler
./zig-out/bin/jac --version

zig build -Dpayload-progress         # stream the payload build live
zig build -Dpayload=/tmp/p.tar.zst   # pack a prebuilt payload (skip fetch+assemble)
zig build -Ddev                      # editable dev binary: link the compiler from this tree
```

`zig build` first builds CPython from the checksum-pinned sources in
`bootstrap/python/sources.json` and fetches the pinned typeshed stubs. The
Python bootstrap uses Zig for C compilation and archiving, with the upstream
configure/make recipes retained for platform probes and generated files.
No installed Python, Jac, or python-build-standalone distribution is needed.
Build hosts need Zig 0.16.0, make, Perl, a POSIX shell, and network access.
macOS also needs the SDK provided by Xcode command line tools.

Builds use stock CPython by default. `JACPYTHON=1` selects JacPython's native
parser/compiler replacement at build time; unset or any other value selects
CPython. Each binary bundles one runtime. For JacPython, the CPython VM and
object runtime remain. A separate build-only CPython host runs Jac's
native compiler to emit that object. The build rejects interpreted demotions;
no replacement bytecode, compiler seed, or Python adapter ships in the payload.
`zig build build-python` builds only the selected runtime and its native libraries.
Its cache in `.python-build/<cpython|jacpython>/<platform>` contains the interpreter,
shared library, stdlib, licenses, CA certificates, and static archives for Jac's
native backend. For JacPython, the adjacent `<platform>.host` tree is only a
build tool. Precompile and payload-layer caches are also separated by variant.
A content fingerprint covers the source checksums, source allowlist, recipes,
Zig version, target, and macOS SDK version. A cache hit skips compilation; a miss builds from
source and checks relocation before marking the distribution complete.
`JAC_PYTHON_JOBS` controls build parallelism (default 4).

Each supported release platform builds on its matching runner. Linux targets
retain the glibc 2.17 floor; Intel macOS targets 12.0 and ARM macOS targets 11.0.
The existing launcher still loads the shared CPython library from its payload.
The source-built runtime excludes Tk, curses, readline, dbm, and CPython test
extensions. `bootstrap/python/cpython-sources.txt` is the source allowlist:
each line names a file or a directory ending in `/`, relative to the pinned
CPython archive. Only those paths survive extraction into the build tree;
stock CPython (including the build-only host) restores entries marked
`# removed:`. The shipped JacPython runtime omits those entries. Changes to JacPython
or the Jac compiler that produces its native object invalidate the runtime cache;
they do not invalidate the build-only host.
Blank lines and full-line comments are allowed; globs, missing paths, and
overlapping entries fail the build. The archive is still downloaded and
checksum-verified as a whole. Other dependency archives use `sources.json`.

Stable and rolling dev releases build both runtimes per selected platform.
Stock CPython uses `jac-<version>-<platform>` (or `jac-dev-<platform>`);
JacPython adds `-jacpython`. Each asset has its own `.sha256` checksum.
The installer defaults to CPython; pass `--jacpython` to select JacPython.
Docker images use the default CPython assets.
Intel Mac remains a manually selected release target.

The list starts with the C implementations needed by the Linux/macOS release
builds, their headers/generated tables, the Python standard library, and the
upstream configure/make inputs and license notices. Tests and unsupported GUI
packages are excluded. Upstream's default make target still requires
`Programs/_testembed.c`; it is a build prerequisite, not a retained test suite.
Generated files created by configure/make do not need their own source entries.

When a Jac implementation replaces a C component, connect it to the runtime,
update the build recipe, and remove the corresponding source entries and any
unused headers. Split a directory entry into its remaining files before
retiring only part of it. The runtime fingerprint and CI cache keys include
the list, so every change rebuilds and verifies the resulting Python runtime.
Deleting an entry alone does not substitute Jac code for a CPython C API.
The separate ignored CPython reference checkout remains a generator input.
The initial source recipe uses `-O2` without PBS's PGO/LTO optimizations;
performance parity has not been established.

* `JAC_NA_DEBUG=1 jac build --native launcher/launcher.jac` prints why a function in
  the stub's closure would be demoted to Python-only; the stub must lower in
  full (a demoted function cannot run before CPython exists).
* To boot a freshly built stub against an existing payload:
  `jac run` a script that calls `jaclang.dist.fused_binary.graft_runtime(<installed jac>, <stub copy>)`,
  then run the copy with a fresh `HOME`.
* `jac test jac/tests/payload/` covers the trailer codec, deterministic staging,
  frame routing and the payload CLI. `zig build test-launcher` covers the private
  decoder, concatenated layers, PAX paths, permissions, truncation, and traversal.
