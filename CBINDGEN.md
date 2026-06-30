# cbindgen - C-header to native-FFI binding generator

> Status: P0-P2 shipped; P3 (aggregates / globals) open pending a design call.
> Sibling tool to c2jac (see `PLAN.md` / `IMPLEMENTATION.md`). Where c2jac
> transpiles a C *translation unit* into idiomatic Jac, cbindgen reads a C
> *header* and emits a thin native-FFI binding so Jac can call into a prebuilt
> shared library.

## 1. Thesis

`jac cbindgen <header> --lib <name>` produces a `.na.jac` binding block of the
shape the hand-written `na_stdlib` FFI files already use:

```jac
import from z { def compressBound(slen: u64) -> u64; }
glob Z_OK: int = 0;
```

It reuses c2jac's front-end (pcpp preprocessing + the vendored pycparser), so it
inherits the same self-contained, no-system-toolchain story. cbindgen does *not*
translate function bodies (there are none in a header); it maps declarations to
FFI signatures and named constants, and is honest about what it cannot model.

## 2. Pipeline

```
C header (.h/.c)                         already-preprocessed (.i)
   |  preprocess_c_collect (pcpp)            |  (skipped)
   v                                         v
flattened TU  +  object-like macro table  --+
   |  pycparser CParser.parse
   v
pycparser C AST
   |  _emit_bindings
   |    - functions: _func_node / _func_signature / ffi_type
   |    - constants: _emit_consts (enum AST + macro table)
   |    - types:     _collect_typedefs + _scalar_for_names
   v
.na.jac binding text  +  BindReport (counts)
```

Entry points (`jac/jaclang/compiler/c2jac/bindgen.jac`):

- `generate_bindings(filename, lib, ...)` - reads the file, used by the CLI.
- `bindings_from_source(c_src, filename, lib, ...)` - string entry, used by tests.

CLI command: `cbindgen` in `jac/jaclang/cli/commands/transform.jac` (decl) +
`impl/transform.impl.jac` (impl). Flag surface mirrors c2jac: `-I`/`-D`/`-U`/
`--force-include`/`--nostdinc`, plus `--lib`, `--allow`, `--block`, `-o/--output`.

## 3. Type mapping

Scalar return/param types resolve through `_scalar_for_names`, which tries, in
order:

1. Fixed-width / size name map `_STDINT_SCALARS` (`uint32_t` to `u32`,
   `size_t` to `u64`, `ssize_t` to `i64`, `intptr_t`, `ptrdiff_t`, ...). Matched
   by *name*, deliberately ahead of step 2, because pycparser's bundled fake
   libc defines these with placeholder widths; resolving the alias would be
   wrong. Widths assume an LP64 native target (the only target nacompile emits).
2. Same-TU typedef table `_collect_typedefs` (`typedef double real_t;` makes
   `real_t` resolve to `f64`). Recursive, depth-bounded against cycles.
3. C-keyword reading `ffi_prim` (`unsigned long` to `u64`, `double` to `f64`,
   ...).

Pointers (`_ptr_ffi`): `const char *` (no signedness) maps to `str`; a pointer
to any other FFI scalar maps to `bytes`; everything else (opaque/struct/void
pointers) maps to `int` (an opaque handle). A `(void)` param list becomes no
params. A trailing `...` becomes `*rest` and is counted as variadic (the
`va_list` semantics are not modelled; each call site needs a human check).

## 4. Constants

`_emit_consts` binds named integer constants to `glob NAME: int = N;` from two
sources:

- **C `enum` enumerators**, read from the pycparser AST, following C's
  implicit-sequential rule (`{ A, B = 5, C }` gives 0, 5, 6). Bare and
  typedef'd enums both work. An enumerator whose initializer is not a plain int
  (or unary +/- over one) makes the whole enum skip, never a guessed value.
- **Object-like `#define` int macros**, read from the pcpp macro table (pcpp
  consumes `#define` before pycparser sees it, so the table is the only place
  the constant survives). Decimal / hex / octal / binary all normalize to a
  decimal literal; string, float, and function-like macros are skipped.

`--allow` / `--block` filter functions and constants alike; the first binding of
a name wins, later collisions are skipped (two block-scoped C enums can legally
share a name, two Jac module globals cannot).

## 5. Phasing

- **P0 - functions:** DONE. Extern prototypes to `import from <lib> { def ... }`;
  primitive widths, `const char*` to `str`, scalar buffers to `bytes`, `(void)`
  drop, opaque-pointer return to `int`, variadic `*rest`.
- **P1 - integer constants:** DONE. enum enumerators + object-like `#define`
  ints to `glob NAME: int = N;` (section 4). Added `preprocess_c_collect` to
  surface the macro table; `BindReport.constants`.
- **P2 - typedef + fixed-width scalars:** DONE. `_STDINT_SCALARS` name map and
  the same-TU typedef table (section 3), so `uint32_t` / `size_t` / user aliases
  bind to real FFI scalars instead of collapsing to `int`.
- **P3 - aggregates and globals:** OPEN, blocked on a design call (section 6).
  Candidates: struct / union typedefs, global-variable externs.

## 6. Open question for P3

Before binding structs, settle how native FFI represents them. The hand-written
`na_stdlib` FFI files never bind a struct *layout*; struct pointers are passed
as opaque `int` handles. So "struct binding" may mean emitting an opaque alias
(or nothing) rather than a Jac `obj` with fields. Resolve by spiking what
`import from <lib> { ... }` accepts for a non-function data symbol and whether
nacompile can express field offsets, then scope P3 to what is actually callable.
Until then cbindgen treats every struct/union pointer as an opaque `int`, which
is correct (if coarse) for the handle-passing idiom those libraries use.

## 7. Tests

`jac/tests/compiler/c2jac/test_bindgen.jac` (run via `jac test`), with
self-contained fixtures under `fixtures/bindgen/` (no system headers, so the
suite is portable regardless of how pycparser was installed):

- `test.h` - every primitive width, the string/buffer idioms, `(void)`, opaque
  pointer return, variadic (P0).
- `consts.h` - enum (sequential + explicit), typedef'd enum, `#define` ints
  (decimal/hex/negative), skipped string + function-like macros (P1).
- `stdint.h` - fixed-width typedefs, a deliberately-wrong-width fake proving the
  name map wins, a user scalar alias (P2).

## References

- `jac/jaclang/compiler/c2jac/bindgen.jac` - the generator.
- `jac/jaclang/compiler/c2jac/preprocess.jac` - shared pcpp front-end.
- `jac/jaclang/runtimelib/na_stdlib/_zlib_native.na.jac`,
  `_ssl_native.na.jac`, `socket.na.jac` - hand-written FFI bindings cbindgen
  reproduces.
