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
# 1. Get a matching LLVM (20.1.x) prebuilt with static archives + headers:
#    https://github.com/llvm/llvm-project/releases/download/llvmorg-20.1.8/LLVM-20.1.8-Linux-X64.tar.xz
#    (extract somewhere; it ships lib/libLLVM*.a + include/)
# 2. Compile the shim + statically link LLVM into libjacllvm.so:
cd jac && zig build jacllvm -Dllvm-dir=/path/to/LLVM-20.1.8-Linux-X64
#    -> jac/zig-out/lib/libjacllvm.so  (312 LLVMPY_* symbols)
```

The Jac binding finds the shim via `JAC_LLVM_SHIM=/path/to/libjacllvm.so` (falls
back to the llvmlite wheel's `.so` on `sys.path` while the wheel is still
bundled).

**Remaining to fully retire the wheel** (each needs a heavier build op):

- a pure-Zig `fetch-llvm` step (pinned download, mirrors `fetch-pbs`) so the
  build is reproducible without a manual `-Dllvm-dir`;
- payload assembly builds `jacllvm` and drops the `llvmlite` pip-install
  (`launcher/payload.zig`) + the `jac.toml` pin;
- (optional) link the shim into the `jac` executable and load via
  `ctypes.CDLL(None)` for a true single-binary, instead of the sidecar `.so`.

See `docs/docs/internals/llvmlite_decoupling.md` and issue #6925.
