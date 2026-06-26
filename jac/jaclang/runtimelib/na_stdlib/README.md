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

## Shipped modules

- **`os/path.na.jac`** (#6940 Phase 0) -- pure-string POSIX path helpers
  (`normpath`, `dirname`, `basename`, `split`, `splitext`, `isabs`).
- **`json.na.jac`** (#6940 Phase 1) -- a recursive-descent `loads` over boxed
  `any` (dict/list/str/int/float/bool/None) plus a `dumps` serializer matching
  CPython's default `(', ', ': ')` separators and insertion-ordered keys.
  Two documented divergences: `dumps` of a bare float uses the native
  `str(float)` (`%g`), not CPython's shortest-round-trip repr (parity is gated on
  the Ryu float repr, #6940 Phase 0.3); and only the control set + JSON
  metacharacters are escaped, so congruence holds for ASCII payloads
  (`ensure_ascii` of non-ASCII is a follow-up).
- **`datetime.na.jac`** (#6940 Phase 1 / #6951) -- a UTC `datetime` and
  `timezone` pair. `timezone.utc` is a class attribute and `datetime.now` /
  `datetime.fromtimestamp` are class-level constructors, riding the native
  static-method and class-attribute capability added for #6951. The civil date
  is computed from the POSIX epoch (Hinnant's days->civil) over the `time`
  intercept, so it is exact for a fixed timestamp; `year`/`month`/`day`/`hour`/
  `minute`/`second`, `weekday()`, and `isoformat()` match CPython. SCOPE: UTC /
  fixed-offset only (no tz database, DST, leap seconds, or microseconds).

The syscall-backed `os` / `os.path` entry points (`makedirs`, `realpath`,
`mkdir`, `exists`, ...) are Mechanism-A/H compiler intercepts, reached via the
flat `import os`, not bundled here (see
`compiler/passes/native/na_ir_gen_pass.impl/os.impl.jac`).

## Adding a module

1. Drop `<name>.na.jac` (or `<pkg>/<name>.na.jac` for a dotted import) here,
   exporting its API with `def:pub`.
2. Use only the native-supported subset; prefer typed containers
   (`list[str]`, `dict[str, any]`). A bare `list = []` defaults to `i64`
   elements. An empty `list[any] = []` then grown with `.append(x)` lowers and
   boxes correctly, but a `list[any]` *literal* with scalar elements
   (`[1, 2, 3]`) does not yet box them -- build `any`-lists via `.append` (or
   `json.loads`). `dict[str, any]` literals box their values fine. Unbox a
   boxed scalar before operating on it (`i: int = some_any; str(i)`), and check
   container/None branches with `isinstance` -- `x is None` does not lower to a
   branch condition on the native pathway.
3. Add a tri-backend equivalence fixture
   (`jac/jaclang/compiler/tests/fixtures/prim_<name>.jac`) and register it in
   `test_prim_equivalence.jac` with `require=["na"]` so sv/na congruence is
   enforced, not assumed.

## Mechanism / portability

- **B (here)**: pure-Jac on primitives; portable to every native target
  (ELF/Mach-O/PE/WASM). Preferred. Example: `os/path.na.jac`.
- **A**: compiler intrinsics over libm/libc/syscalls (`math`, `time`, `os`,
  `random`, `struct`); native-host only.
- **F**: thin FFI wrappers over a system C library; native-host only. Example:
  `urllib/request.na.jac` -- `urlopen` over the libcurl floor (issue #6940
  Phase 3), pinned sv<->na congruent by `test_urllib_equivalence.jac` against a
  loopback HTTP server. An F module declares its C entry points with
  `import from <lib> { def ...; }`; a trailing `*rest` param marks a C *variadic*
  function (e.g. `curl_easy_setopt(handle, option, *rest)`) so the backend emits
  the `var_arg` declaration the platform psABI requires. The future `zlib` over
  libz lands the same way.

Functions that need a syscall (`os.path.realpath`, `exists`, ...) stay as
Mechanism-A intercepts, not here.

## Mechanism F: FFI floor + pure-Jac surface (`zlib`)

`zlib` is the first Mechanism-F module (#6940 Phase 2): the DEFLATE engine is
never reimplemented; it is the system `libz`, reached through a thin FFI floor,
exactly as CPython's `zlib` wraps the same library. The split is deliberate:

- `_zlib_native.na.jac`: the **FFI floor**. An `import from z { def ... }` block
  binds `libz` by logical name (`z` → `libz.so` / `libz.dylib` / `z.dll`) and
  re-exports each entry behind a `z_`-prefixed wrapper.
- `zlib.na.jac`: the **pure-Jac surface**: the Python-shaped API
  (`compress` / `decompress` / `crc32` / `adler32`, CPython argument orders and
  defaults), layered on the floor.

Two conventions make foreign byte I/O work:

- A **`bytes` parameter on a foreign signature** lowers to a raw `i8*` to the
  element data (the C buffer-protocol convention), not the internal jacbytes
  `{ i64 len, [n x i8] }` struct pointer; the element count travels through a
  separate explicit length parameter.
- A clib extern is declared into the **shared native symbol table under its C
  symbol name**, so a libz symbol that collides with a public surface name (e.g.
  `crc32`) would shadow it. Bind the non-colliding variant instead; the floor
  uses `crc32_z` / `adler32_z`.

Mechanism-F modules are native-host only: a wasm target gets a clean link error
rather than silent breakage.

[#6404]: https://github.com/jaseci-labs/jaseci/issues/6404
[#6940]: https://github.com/jaseci-labs/jaseci/issues/6940
