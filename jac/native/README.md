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
- These `.cpp` files are kept verbatim (numba/llvmlite v0.47.0) so they track
  upstream llvmlite for a given LLVM version (currently **LLVM 20.1.x**).

## Building

```bash
cd jac
zig build fetch-llvm   # one-time: download + verify + extract pinned LLVM 20.1.x
                       # into .llvm-build/ (pure Zig, ~1.9 GB)
zig build              # compiles the shim, statically links LLVM, packs it into
                       # the jac binary, AND drops it in-tree (gitignored) for the
                       # editable dev loop. No manual step, no JAC_LLVM_SHIM.
```

`zig build jacllvm` builds just the shim (`jac/zig-out/lib/libjacllvm.so`, 312
`LLVMPY_*` symbols) and places it at
`jaclang/compiler/passes/native/llvm/libjacllvm.so` (gitignored) so the editable
dev loop -- which runs jaclang from source, not the binary's payload -- finds
it. `JAC_LLVM_SHIM=/path/to/libjacllvm.so` overrides the lookup if needed.

The shim rides in the payload trailer exactly like the bundled libpython:
packed into the single `jac` binary, extracted at first run, and ctypes-loaded
by the Jac binding (resolution order: `JAC_LLVM_SHIM`, the payload's
`libjacllvm.so`, then the llvmlite wheel as a fallback).

**Notes / size follow-ups:**

- The full LLVM release links all targets; a host-only pruned build (or a
  pruned archive set) would shrink the shim from ~134 MB.
- `--skip-precompile` (mkpayload) skips the JIR precompile for fast link
  validation; shipping builds keep it for fast first-run startup.
- The `jac.toml` `llvmlite` pin remains for the wheel fallback path; it can be
  dropped once `fetch-llvm` is the guaranteed default.

See `docs/docs/internals/llvmlite_decoupling.md` and issue #6925.
