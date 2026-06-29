# jac/native - LLVM-C (`LLVMPY_*`) shim

Verbatim C++ source of numba/llvmlite's FFI shim (`ffi/*.cpp`), which wraps
LLVM's C++ API and exports a flat `LLVMPY_*` C ABI. It is **unmodified
third-party code** under BSD-2-Clause (see [`LICENSE`](LICENSE)).

Zig compiles these sources and statically links a host-only LLVM into the `jac`
binary, exporting the `LLVMPY_*` symbols so the in-tree Jac binding
(`jaclang/compiler/passes/native/llvm/binding/`) resolves them in-process via
`ctypes`. This replaces the bundled 167 MB `libllvmlite.so` from the llvmlite
wheel.

- The Jac side (IR builder + ctypes binding) is a `py2jac` translation and is
  maintained as first-party code under `jaclang/compiler/passes/native/llvm/`.
- These `.cpp` files are kept verbatim (numba/llvmlite v0.48.0rc1) so they track
  upstream llvmlite for a given LLVM version (currently **LLVM 22.1.x**).

## Building

```bash
cd jac
zig build fetch-llvm   # one-time: range-fetch ONLY the ~84 MB the shim needs
                       # (lib/libLLVM*.a + llvm/llvm-c headers, +macOS libLTO) out
                       # of the jaseci-labs/llvm-slice repackaged zip into
                       # .llvm-build/ -- no xz, no clang/tools. Pure Zig.
zig build              # compiles the shim, statically links LLVM, packs it into
                       # the jac binary, AND drops it in-tree (gitignored) for the
                       # editable dev loop. No manual step, no JAC_LLVM_SHIM.
```

The shim is built with the **system C++ compiler** to match the official LLVM
release's C++ standard library: macOS uses Apple `clang++`/libc++; Linux uses
`g++` with `-static-libstdc++` (the LLVM 22 Linux release is built against GNU
libstdc++, not libc++ as LLVM 20 was -- a `link_libcpp` shim leaves LLVM's
`std::__1::*` API calls unresolved against the release's `std::__cxx11::*`).

`zig build jacllvm` builds just the shim (`jac/zig-out/lib/libjacllvm.so`, 310
`LLVMPY_*` symbols) and places it at
`jaclang/compiler/passes/native/llvm/libjacllvm.so` (gitignored) so the editable
dev loop -- which runs jaclang from source, not the binary's payload -- finds
it. `JAC_LLVM_SHIM=/path/to/libjacllvm.so` overrides the lookup if needed.

The shim rides in the payload trailer exactly like the bundled libpython:
packed into the single `jac` binary, extracted at first run, and ctypes-loaded
by the Jac binding (resolution order: `JAC_LLVM_SHIM`, the payload's
`libjacllvm.so`, then the llvmlite wheel as a fallback).

**Notes / size follow-ups:**

- The shim registers all LLVM targets (jac compiles to WebAssembly as well as
  the host -- see `wasm_build.jac`), so it links the full archive set (~129 MB
  on Linux). A host-only pruned build is not viable while non-host targets are
  in use.
- `--skip-precompile` (mkpayload) skips the JIR precompile for fast link
  validation; shipping builds keep it for fast first-run startup.

See `docs/docs/internals/llvmlite_decoupling.md` and issue #6925.
