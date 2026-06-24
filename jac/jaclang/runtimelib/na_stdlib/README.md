# Bundled native standard library (`na_stdlib`)

Pure-Jac `.na.jac` modules shipped with jaclang that implement a
Python-congruent **standard library for the native (na) compiler pathway**
(issues [#6404] / [#6940]). This is **Mechanism B**: ordinary Jac compiled and
linked like user code, with zero per-module backend work.

## How resolution works

`jaclang.jac0core.codeinfo.resolve_native_module` is the single shared resolver
used by `BoundaryAnalysisPass`, `NaIRGenPass`, and `NativeCompilePass`. It
searches **nearest-wins**:

1. the importing project's own tree (a flat sibling, then the dotted hierarchy
   walked up to the filesystem root), then
2. this bundled root (`native_stdlib_root()`).

So `import from os.path { normpath }` binds CPython's `posixpath` on the sv
(Python) pathway and `na_stdlib/os/path.na.jac` on the na (native) pathway (the
*same source* on both), while a user module of the same name always shadows the
bundled one. A bundled module links through the existing cross-module machinery
(binding population, then extern forward-decl, then `link_in`), on both the AOT
(`jac nacompile`) and JIT execution paths.

## Adding a module

1. Drop `<name>.na.jac` (or `<pkg>/<name>.na.jac` for a dotted import) here,
   exporting its API with `def:pub`.
2. Use only the native-supported subset; prefer typed containers
   (`list[str]`, `dict[str, any]`). A bare `list = []` defaults to `i64`
   elements and an empty `list[any] = []` is not yet lowered.
3. Add a tri-backend equivalence fixture
   (`jac/jaclang/compiler/tests/fixtures/prim_<name>.jac`) and register it in
   `test_prim_equivalence.jac` with `require=["na"]` so sv/na congruence is
   enforced, not assumed.

## Mechanism / portability

- **B (here)**: pure-Jac on primitives; portable to every native target
  (ELF/Mach-O/PE/WASM). Preferred.
- **A**: compiler intrinsics over libm/libc/syscalls (`math`, `time`, `os`,
  `random`, `struct`); native-host only.
- **F**: thin FFI wrappers over a system C library (`zlib` over libz, TLS over
  libcurl); native-host only.

Functions that need a syscall (`os.path.realpath`, `exists`, ...) stay as
Mechanism-A intercepts, not here.

[#6404]: https://github.com/jaseci-labs/jaseci/issues/6404
[#6940]: https://github.com/jaseci-labs/jaseci/issues/6940
