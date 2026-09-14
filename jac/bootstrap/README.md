# Building the compiler

Jac builds its compiler with an independently released Jac executable. The
version, download locations, and SHA-256 hashes live in `pins.json`. The Zig
fetch step verifies the executable on every use, including cache hits. An
installed `jac` and the checkout's Python import path are not bootstrap inputs.
The pin supports Linux x86-64, Linux ARM64, and macOS ARM64. Compiler images
build on a matching host; adding a host requires a verified prior compiler
artifact for that host.

The build graph has explicit artifacts:

1. The pinned compiler builds the native frontend kernel and its class layout.
2. The pinned compiler compiles the current compiler, runtime, CLI, and packaging
   modules into a stage-1 image using ordinary full compilation.
3. A source-built C CPython host runs stage 1, which builds the typeshed catalog
   and emits the native Python compiler object using the ordinary native backend.
4. The runtime build consumes that explicit object. Packaging consumes the verified
   image, catalog, native libraries, and source-built native JacPython runtime.
5. `compiler-stage2` rebuilds the kernel and image with stage 1. This checks the
   compiler's ability to build its successor independently of the original pin.

The producer executes its own compiled modules. Target sources live in an
isolated temporary snapshot. The historical pin requires an empty `jac0core`
resolver marker in that snapshot; it contains no code and is removed before
publication. The current compiler has no seed transpiler or seed membership list.
Current-only native build options pass through a typed keyword mapping in the
bootstrap recipe, which the prior compiler checks and stage 1 executes.

```bash
cd jac
zig build fetch-llvm
zig build compiler-image
zig build compiler-stage2
zig build verify-compiler-stage2
zig build verify-compiler-image
zig build
```

`zig-out/compiler-site` is the stage-1 development image. Select it explicitly:

```bash
export JAC_COMPILER_IMAGE="$PWD/zig-out/compiler-site"
./zig-out/bin/jac run ../my-program.jac
```

Rebuild `compiler-image` after changing compiler sources. Unset
`JAC_COMPILER_IMAGE` to use a binary's bundled compiler. A bare source directory
is not an image, and an invalid image is an error. Selection happens before
compiler imports; a process cannot switch its loaded compiler.

The `.compiler-build` cache stores JIR modules using the existing source and
compile-time dependency checks. Its generation includes the producing compiler,
build recipe, source layout, and configuration. Source edits invalidate their
consumers, while a changed producer or recipe starts a new generation. Corrupt
entries are rebuilt. The image codec in `image.py` owns the wire
format, bytecode loading, and path relocation; application publishing uses the
same codec.

Native libraries and their generated class layouts are assembled into the image
after source compilation. They are verified image payloads, but are not inputs
to the pinned producer's module cache. Changing the target parser therefore
does not invalidate unrelated Python modules.

Image modules contain executable bytecode and the compile-time dependencies
needed to validate build-cache reuse. They do not carry the producer's analysis
interfaces or diagnostics. The running compiler owns those results and caches
them under its own identity, so a predecessor's type analysis cannot become the
successor's source of truth.

The installed compiler's identity comes from its image manifest. Runtime cache
keys do not rescan a checkout or guess which compiler source tree is active.
`-Dcompiler-jobs=N` controls image workers; the default is two because full
compiler workers can retain several GiB each. Image builds report per-module
cache reuse and elapsed time. Compare cold and warm builds separately.

Compiler build steps inherit only executable lookup, home/cache locations,
the operating system temporary directory, and proxy settings. CI run identifiers
and ambient compiler overrides do not invalidate or redirect build artifacts.
Source inputs are ordered deterministically before entering the build cache.

Native JacPython is mandatory in the distribution. The C compiler host is a
build artifact only. `zig build python-native` emits `jacpython.o`;
`zig build build-python` consumes it to build the runtime. The runtime builder
never imports the compiler or discovers a source checkout. Native Python
implementation sources are excluded from the interpreted compiler image; their
CPython license is preserved. The CPython virtual machine and object runtime
remain part of the product.

Stage 1 maps its temporary native Python source directory to the stable
`jaclang` prefix. The compiler applies source-prefix mappings to native symbol
identity, embedded assertion locations and debug metadata, includes them in code-generation
cache identity, and preserves them across native imports. Identical emitted
objects let the runtime's existing content cache reuse CPython after compiler
edits that leave the native Python implementation unchanged.
