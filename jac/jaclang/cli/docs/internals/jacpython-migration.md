# JacPython Migration

JacPython builds CPython 3.14.6 with parts of it replaced by native Jac.
`jac/bootstrap/python/cpython-sources.txt` records every replaced C file as a
`# removed:` entry; the build fails if one reappears. This page records how a
module is ported, what stays C and why, and the design for the two tiers that
cannot be ported yet: the object model (`Objects/`) and the evaluator
(`Python/`).

## Porting a module

Four generated files and two lists do the bookkeeping. A port touches only
the module's own Jac files and one line in each list.

| Piece | Produced by | Holds |
|---|---|---|
| `jac/bootstrap/python/jacpython-modules.txt` | hand | module name, upstream test modules, extra linker flags |
| `jac/bootstrap/python/jacpython-clinic.txt` | hand | modules whose argument parsing is generated |
| `runtime/python/cpython_api.jac` | `scripts/jacpython/gen_capi.jac` | typed clib declarations of every CPython function the Jac code calls |
| `runtime/python/bindings/clinic/<name>.jac` | `scripts/jacpython/gen_clinic.jac` | signatures, converters, return conversion, method/getset tables |
| `runtime/python/modules/<name>_constants.<os>.jac` | `scripts/jacpython/gen_constants.jac` | system constants as the target's C headers define them |
| `cpython-sources.txt` line counts | `scripts/jacpython_manifest.jac --write` | per-file and total source lines |

Steps for a module `_foo` built from `Modules/_foomodule.c`:

1. Add `_foo` to `jacpython-clinic.txt` and run `jac run scripts/jacpython/gen_clinic.jac _foo`.
   The generated file imports `<c_basename>_impl` functions, C macro defaults
   and module converters from `runtime/python/modules/foo.jac`.
2. Write `modules/foo.jac`: one `_impl` function per clinic function, with the C
   name and the C parameter list (`PyObject *` is `ptr[PyObject]`,
   `Py_ssize_t` is `i64`, `Py_buffer` is `BufferArgument`). The body calls the
   CPython API by its own names.
3. Write `bindings/foo.jac`: the `ModuleDefinition`, any `TypeDefinition`s,
   the exec hook (constants, exception types, module state) and
   `def:pub PyInit__foo`. Classes whose methods take `defining_class` bind their
   `ClassToken` here.
   `PyInit__foo` is the only `:pub` name. `:pub` exports an unqualified C
   symbol, so two modules with a `:pub` of the same name fail the link;
   plain `def` and `glob` stay importable from other Jac modules.
4. Run `jac run scripts/jacpython/gen_capi.jac` so every new API call has a
   declaration.
5. Import `PyInit__foo` in `compiler/backends/py/jacpython/native_api.jac`,
   add the registry line, comment the C files in `cpython-sources.txt` as
   `# removed: 0 source lines`, and run `jac run scripts/jacpython_manifest.jac --write`.
6. `JAC_NO_DEV_SOURCE=1 jac check` each new file. A single-file check reports
   native lowering failures (E5092) and native placement errors (E5090) for
   the file itself; `jac check native_api.jac` checks the closure's lowering.

`build.sh` writes the `Setup.local` `*static*` block from the registry and fails
when `native_api.jac` does not import a listed `PyInit`. `smoke.py` and the CI
compatibility step read the same registry.

A module over a library that CPython vendors and builds itself names the
library's archive as its linker flag: `_md5` lists
`Modules/_hacl/libHacl_Hash_MD5.a`. A registry entry has no C source, so no
makesetup rule depends on the archive; `build.sh` makes every such target
before linking the interpreter. The Jac module declares the library's
functions by their linked names (HACL* prefixes them with `_Py_LibHacl_`).
Code that only exists on some architectures goes in a `<name>.<arch>.jac`
variant beside a portable `<name>.jac` (`modules/blake2_simd.x86_64.jac`).

A Jac module can also define interpreter functions under their C names: the
atexit port defines `PyUnstable_AtExit`, `_PyAtExit_Call` and `_PyAtExit_Fini`
as `def:pub`, which `pylifecycle.c` and `pystate.c` call. `gen_capi.jac` does
not declare a name a JacPython source defines.

Clinic coverage of the retained modules: 1,050 of 1,074 signatures generate.
The rest have C-expression defaults (`GET_YEAR(self)`, `POLLIN | POLLPRI`) or
optional groups; the generated file lists them and the module binding parses
them by hand.

## What stays C

`jacpython.o` links into libpython, so any non-static CPython function is
callable from Jac. `gen_capi.jac` declares `PyAPI_FUNC` functions and the
`extern` functions of `Include/internal/`. C remains only where Jac cannot
express the operation:

| C residue | Why | Where |
|---|---|---|
| data symbols (`PyExc_*`, `Py*_Type`, `_Py_NoDefaultStruct`) | Jac cannot take the address of an extern variable | `jacpy_exception_type`, `jacpy_runtime_object` |
| macros and static inline functions with no exported form (`PyTuple_Check`, `PyList_GET_ITEM`) | no symbol to call | one-line `jacpy_*` helpers in `object_api.c` |
| varargs (`Py_BuildValue`, `PyErr_Format`, `PyObject_CallMethod`) | Jac clib calls are fixed-arity | helpers that fix the format |
| struct fields of object layouts (`tp_richcompare`, `ob_alloc`, weakref lists) | layout differs between builds | helpers |
| pointer arithmetic (`p + n`, `end - start`) | `ptr[T]` has no arithmetic | `jacpy_offset`, `jacpy_distance` |
| calling a C function pointer | Jac can pass named callbacks to C but not call a `ptr` | a trampoline helper (`jacpy_atexit_call` runs atexit's `PyUnstable_AtExit` callbacks) |
| returning a C struct by value (`PyStatus`) | Jac definitions return scalars and pointers | the hook stays C (`_PyAtExit_Init` in `compiler_runtime.c`) |
| CPU feature probes (CPUID) | an intrinsic | `jacpy_hacl_simd_features` |
| vendored libraries (HACL*, libmpdec, expat, zlib, bzip2, xz, zstd, sqlite, OpenSSL, mimalloc) | external dependencies, not CPython | built and linked as before |

`object_api.c`, `compiler_runtime.c` and `binding_api.c` hold only these. They
take and return typed pointers (`PyObject *`, `Py_buffer *`,
`PyUnicodeWriter *`), and `gen_capi.jac` derives their Jac declarations from
the C, so the two sides cannot drift.

## Object handles

A Python object is `ptr[PyObject]`, an opaque C type. The checker rejects
passing, returning or assigning an integer where a handle is expected, and any
arithmetic on a handle; `NULL` is `ptr[PyObject]()`. `==` between a handle and
an integer is still accepted by the checker, so null tests are written
`not h` / `h.is_null()`. Every PyObject-headed layout (`PyTypeObject`,
`PyLongObject`, `PySTEntryObject`, ...) is declared as `ptr[PyObject]`,
matching the casts CPython's own C makes; non-object records
(`PyThreadState`, `PyUnicodeWriter`, `Py_buffer`, `z_stream`) keep their own
types. `Py_buffer` and library records like `z_stream` and `struct passwd` are
C-layout Jac structs, so fields are read directly.

## Language gaps

The ports so far needed these, each worked around in C or by a pattern:

1. **Pointer arithmetic and pointer/integer conversion.** zlib's output window
   and input buffer compute `next_out + n` and `end - next_in`.
2. **Reading through a pointer without copying.** `p.view(1)[0]` copies a
   struct; there is no `p.field` on `ptr[T]`.
3. **Calling a function pointer.** `atexit` stores C callbacks and later calls
   them; a C trampoline (`jacpy_atexit_call`) makes the call. Typed
   fn-pointer FIELDS (`obj ops { has do_it: def(i32) -> i32 }`) are already
   callable: the generic call path evaluates a non-name callee and
   `_codegen_callable_value` (calls.impl.jac) calls any `ptr→FunctionType`
   value with coercion; a runtime smoke test is pending
   (`/tmp/gap4test/gap3_smoke.jac`). Still missing: calling an ERASED address
   (`p: ptr`, i64), as atexit does, which needs explicit cast syntax to a
   function type (e.g. the gap-1 conversion form against a `def` target);
   design when gap 3 activates.
4. **Exporting data symbols.** A static `PyTypeObject` is a C variable other C
   code takes the address of.
5. **Varargs calls.**

Gaps 1 to 4 block the object model and the evaluator.

Status of the gap closures (2026-10-06, branch-local, uncommitted):

- **Gap 1 (pointer arithmetic / integer conversion): done.** Checker in
  `types/operations.jac` (`get_pointer_arith_result_type`): `p+n`/`p-n` scale
  by `sizeof(T)`, `p-q` yields element count as `int`, `n+p` stays E1055;
  `int(p)` and `ptr[T](i)` are identities (values are i64 addresses in the
  native IR). Native lowering in `na_ir_gen_pass.impl/c_interop.impl.jac`
  (`_codegen_ptr_arith`). Verified on clarity2: checker positives and native
  smoke (`2 / 8 / 4 / 4 / done`).
- **Gap 2 (`ptr[T].field` without copy): done.**
  Checker resolves the field via `foreign_struct_of_type` +
  `_lookup_object_member`, normalized to instance type; native loads/stores go
  through `inttoptr(addr+offset)` with augmented-assignment support.
  Checker fix re-verified on clarity2 (`1 passed`); native smoke green
  (`42 / 2.5 / 7 / 1`).
- **Gap 3 (typed fn-ptr fields): done.** Runtime smoke green on clarity2
  (`/tmp/gap4test/gap3_smoke.jac` prints `15` / `gap3 done`): a
  `Callable[[i32], i32]` field is assigned a named function and called
  through the instance. Still missing: calling an ERASED address
  (`p: ptr`, i64), as atexit does, which needs explicit cast syntax to a
  function type (e.g. the gap-1 conversion form against a `def` target);
  design when gap 3 activates.
- **Gap 4 (export data symbols): done.**
  `glob [access] X: SomeCStruct = SomeCStruct(args...);` with all-constant
  members emits the clib archetype's inline C-layout struct as the global
  (`:pub` = external linkage, C can `extern` it) built as an LLVM
  `ConstantStruct`: literal scalars coerced per field type, string literals
  become private interned NUL-terminated C strings (address relocated into
  ptr/i64 fields), named functions bitcast/ptrtoint into fn-ptr fields,
  static-glob references relocate by address, nested ctor calls inline by
  value, `None`/omitted members zero. Non-constant members raise E5092.
  Struct-typed globs are used as pointers (no load) in `expr.impl.jac`,
  ABI-identical to boxed globs. Runtime-boxed `my_struct()` globs (the
  `shared_glob_struct.jac` fixture path) keep `__jac_glob_init`. Files:
  `na_ir_gen_pass.jac` (state + decls), `globals.impl.jac` (builders),
  `expr.impl.jac` (use path), `core.impl.jac` (finalize flush).
  Verified on clarity2: checker clean on `/tmp/gap4test/gap4_smoke.jac`
  (scalars, C strings, nested struct, fn-ptr and fn-ref relocations) and
  runtime prints `7 / 1 / done`; direct `THE_THING.count` use works.
  llvmlite >= 0.44 gotcha (cost a day): `ir.GlobalVariable.type` returns a
  `PointerType`, so `isinstance(gv.type, IdentifiedStructType)` NEVER
  matches and struct-typed globs were silently `load`ed as scalar garbage.
  Struct globs are detected via `gv.type.pointee` +
  `pointee.name in self.clib_struct_names` (expr NameAtom returns the
  global itself; the trailer field path falls back to the same name check
  when the checker-side base type is missing). Static member lowering
  accepts `uni.String`/`MultiString` literals, and E5092 for a failed
  member names the field's LLVM type and the member AST node class.

## Verification environment (clarity2)

- Box: Ubuntu 20.04 (glibc 2.31, no sudo), 20 cores. Repo at
  `~/repos/jacpy-comp`. Build: `cd jac && ~/tools/zig/zig build fetch-llvm
  && ~/tools/zig/zig build -Ddev -j8` (`-Ddev` links the compiler live from
  the checkout: rsync the edited files, no rebuild needed). glibc workaround:
  `python3 ~/repos/fixinterp.py zig-out/bin/jac` (PT_INTERP patch), then run
  through `~/g/jacpy`, a wrapper exporting
  `LD_LIBRARY_PATH=/home/madhu/sysroot/noble/...`. Never export that
  `LD_LIBRARY_PATH` globally (it breaks system tools).
- **Any edit under `jaclang/compiler/types/` invalidates the stub catalog.**
  The next invocation pays a one-time ~13 min rebuild; batch all type-file
  edits into one sync before testing.
- **Never run two `jac` invocations concurrently on the box.** They thrash
  the stub/cache files: warm 2-second checks have timed out at 300 s when
  raced against a test run. Serialize remote jobs.
- **Backend/`types/` edits invalidate the native-units kernel**: the next
  invocation rebuilds `libjac_compiler.so` (~30 min at O2). `kernel_options`
  (`kernel_resolve.jac`) is pinned to `opt_level=0`, `native_threads=1`:
  the O2 build peaks at ~50 GB RSS and the OOM killer takes `jac` down
  (62 GB box, training jobs resident); O0 fits. Flip back only when >55 GB
  is free.
- **Long remote jobs must run server-side under `nohup`** writing a done
  sentinel; poll with short ssh. Never pipe a live `jac` build/check into
  `head`: after head exits, the writer gets SIGPIPE and `jac` dies
  mid-build with the cache half-written (redirect to a file, then grep).
  Killed sessions can leave orphaned `build_kernel` processes burning a
  core for hours; check `ps aux | grep build_kernel` and kill them.
- **`glob:pub` / `def:pub` route `jac run` into app preparation** (silent
  exit, no program output). For plain native smokes use `glob`/`def`.
- **Importing a clib by absolute path segfaults the native binary at its
  first imported call** (verified 2026-10-07: `import from
  "/usr/lib/x86_64-linux-gnu/libc.so.6"` crashes before any output, the
  same body with `import from "libc.so.6"` runs green). Use the soname in
  fixtures; file upstream against the ELF/link lane. Output lost to
  buffering on a crash looks like "no output"; run `stdbuf -o0`.
- The `opt_level=0` kernel also links in ~100 s (was ~30 min at O2), so
  backend-edit rebuilds are cheap enough for bisection again. A reboot
  wipes `/tmp` (keep fixture copies on the workstation) and leaves `git`
  crashing under the `~/g/jacpy` LD_LIBRARY_PATH wrapper (kernel derivation
  falls back to a full rebuild, noisy but harmless).
- `-j16` locally OOMs 14 GB and the workstation disk has no headroom; the
  full compiler suite (`JAC_TEST_JOBS=auto jac test tests`) is ~90 min there
  and has no clean baseline yet (500 failed / 295 error on the first-ever
  run, likely environmental: no postgres 19, absent services).
- **The 11 pointer/clib subset failures are environmental, not code**
  (2026-10-07): the 5 subset files give `15 passed, 11 failed, 1 skipped`
  and every failure is `/usr/bin/cc: symbol lookup error: sysroot libc
  _dl_audit_symbind_alt`: tests that shell out to `cc` inherit the
  `~/g/jacpy` focal-sysroot `LD_LIBRARY_PATH` and the noble `cc` refuses
  it. Same failures at HEAD; identical under a baseline tree. A CI-style
  container would not see them.

## Object model (`Objects/`, 143k lines)

CPython C extensions compile against the object layouts, so the layouts are
the ABI: `PyObject` (refcount, type), `PyVarObject`, `PyTypeObject` and the
concrete layouts that macros read (`PyTupleObject.ob_item`,
`PyListObject.ob_item`, `PyBytesObject.ob_sval`, the compact unicode forms).
A Jac object model keeps these byte for byte. It needs:

- C-layout structs for each layout, with interior pointers and in-place field
  writes through a pointer (gaps 1 and 2);
- static type objects exported under their C names (gap 4);
- slot functions exported as C function pointers in those type objects; Jac
  already emits named callbacks into C records;
- refcounting as inline operations in Jac, since a call per `Py_INCREF` into
  C costs a function call that ThinLTO cannot remove (`jacpython.o` enters the
  link as machine code). Emitting `jacpython.o` as bitcode for the ThinLTO link
  removes that boundary if Jac's LLVM and Zig's LLVM agree on the bitcode
  version.
  Status: `prepare_native.py` emits `jacpython.bc` + `llvm-version` next to
  the machine-code object; `build.sh` folds the bitcode into the
  `--with-lto=thin` link (`zig cc -c -x ir -flto=thin -fPIC`) only when zig's
  clang major equals Jac's LLVM major, else keeps machine code. Today they do
  NOT agree (Jac shim LLVM 22.1.8 vs zig 0.16.0 clang 21.1.8, and bitcode is
  forward-incompatible), so the build falls back; upgrading zig past LLVM 22
  flips the path automatically with no further edits.

Order, once gaps 1, 2 and 4 are closed: leaf types with little behaviour
(`cellobject.c` 212, `boolobject.c` 227, `namespaceobject.c` 332,
`capsule.c` 366, `iterobject.c` 541, `enumobject.c` 585, `sliceobject.c` 710,
`rangeobject.c` 1,317), then containers (`tupleobject.c`, `listobject.c`,
`setobject.c`, `dictobject.c`), then numbers and text (`floatobject.c`,
`complexobject.c`, `longobject.c`, `bytesobject.c`, `unicodeobject.c`), and
`typeobject.c` (12,312 lines) last. `mimalloc` and `obmalloc.c` stay the
allocator.

`cellobject.c` is the first port. `runtime/python/cellobject.jac` declares
the extern C data symbol inside the clib import (`glob PyType_Type:
PyTypeObject_Layout;`; `GlobalVars` under an `Import` is now a legal
parent in the AST validator) and exports `PyCell_Type` as a `glob:pub`
static type object with the full 53-field `PyTypeObject` layout initialized
positionally. Assigning a clib-struct-typed global where a pointer is
expected is the C address-decay rule and is accepted by the checker in
native context (`PyType_Type` for `ob_type`, `cell_getsetlist` for
`tp_getset`); the static-const relocation emits the global's address
(`extern struct` semantics). Static arrays of structs are not an
initializer form yet, so `cell_getsetlist` is a two-field record with the
bytes of `PyGetSetDef[2]`. C residue: `jacpy_cell_repr` (varargs
`PyUnicode_FromFormat` + `tp_name` read), `jacpy_is_cell`, and
`jacpy_cell_new_too_many` (formatted TypeError). Registration: import the
type in `native_api.jac`; `Objects/cellobject.c` is commented out in
`cpython-sources.txt`. Verified on clarity2: single-file check passes
(`JAC_NO_DEV_SOURCE=1 jac check jaclang/runtime/python/cellobject.jac`) and
the `native_api.jac` closure check passes with the type in it; runtime
verification waits on the first full `build.sh` run. The port forced four
shared-infra fixes: extern `glob` declarations inside clib imports (AST
validator), the address-decay assignment rule (checker, native context),
extern-glob registration for clib data symbols, and null-pointer calls
(`ptr[T]()`), parenthesized atoms and nested struct constructors in the
static-initializer constant builder.

`boolobject.c` is the second port. `runtime/python/boolobject.jac` imports
`PyTypeObject_Layout` from `cellobject.jac` and adds the
`struct _longobject` layout (`PyLongObject_Layout`: PyObject head, `lv_tag`,
one digit) for the `_Py_FalseStruct`/`_Py_TrueStruct` singletons, exported
with the exact immortal initial refcount (`(3 << 30) | (5 << 48)` on GIL
builds) and `_PyLong_FALSE_TAG`/`_PyLong_TRUE_TAG` (`lv_tag` 1 and 8: sign
in the low two bits, digit count in bit 3). `PyBool_Type` uses named-field
initialization of the same 53-field layout (`tp_base=PyLong_Type`,
`tp_as_number=bool_as_number`, `tp_vectorcall=bool_vectorcall`). The number
slots live in a defined static `PyNumberMethods` (36-field C layout;
uninitialized slots default to `0`, `nb_reserved` to a null pointer);
`bool_invert` warns via `PyErr_WarnEx` then falls back through
`PyLong_Type.tp_as_number` cast to the typed struct (typed field-call idiom),
and `bool_and`/`bool_or`/`bool_xor` compare the operands' `ob_type` against
`PyBool_Type`'s address and return the singletons. `PyBool_FromLong` is a
`def:pub` in Jac, the first defined-API handoff between two ported modules;
gen_capi still declares it in `cpython_api.jac` for the modules that call it
through C. `PyVectorcall_NARGS`
is a C static inline, so `bool_vectorcall` inlines the argument-count mask
(`nargsf & 0x7FFFFFFFFFFFFFFF`). Extern declarations verified against the
pinned headers before use: `_Py_SetImmortal` (pycore_object.h),
`PyErr_WarnEx` (warnings.h), `PyObject_IsTrue` (object.h),
`_PyArg_NoKwnames`/`_PyArg_CheckPositional` (pycore_modsupport.h). C
residue: `jacpy_bool_new_too_many` (formatted TypeError, same rule as cell).

`namespaceobject.c` is the third port. `runtime/python/namespaceobject.jac`
adds `PyMemberDef`/`PyMethodDef` layouts and byte-identical record structs
for their C arrays (`_PyNamespace_Members`, `_PyNamespace_Methods`; the
sentinel entry is the defaulted record), the `_PyNamespaceObject` layout
(`tp_basicsize` 24, `tp_dictoffset` 16), and a `PyASCIIObject_Layout` head
for the `PyUnicode_GET_LENGTH` read on compact strings. `_PyNamespace_Type`
uses named-field initialization with `tp_flags` 17408 (`DEFAULT|HAVE_GC|
BASETYPE`), `tp_alloc=PyType_GenericAlloc` and `tp_free=PyObject_GC_Del` as
extern C functions relocated by name, and `tp_methods`/`tp_members`
decaying to the record globals. The methods take the wide C calling shape
(`PyMethodDef.ml_meth` is declared `(any, any, any) -> ptr[PyObject]`); the
`METH_NOARGS` entry never reads the third slot, which the C
`_PyCFunction_CAST` also guarantees. The repr loop reads values with
`PyDict_GetItemWithError` (borrowed, `NULL` plus a set error on failure)
instead of `PyDict_GetItemRef`, whose `PyObject **` out-parameter has no
native shape yet; `_PyType_Name` supplies the subtype name for the
unpack error. New residue: `jacpy_namespace_too_many`, `jacpy_namespace_pair`
(`%U=%R`), `jacpy_namespace_repr_closed` (`%s(%S)`),
`jacpy_namespace_repr_selfref` (`%s(...)`), `jacpy_namespace_reduce_pack`
(`PyTuple_Pack(3, …)`), `jacpy_namespace_replace_type_error` (`%N`/`%T`),
and `jacpy_vectorcall_arg` (bool's `PyObject *const *` element load; the
native checker does not type pointer-to-pointer subscripts yet, E1001).

`capsule.c` is the fourth port (`runtime/python/capsule.jac`). The
`PyCapsule` layout (head + pointer + name + context + destructor +
traverse_func + clear_func, 64 bytes) drives `PyCapsule_Type` (flags 16384);
the whole API surface (`PyCapsule_New/IsValid/Get*/Set*/Import`,
`_PyCapsule_SetTraverse`) is `def:pub` in Jac, so gen_capi stops declaring
them. `_PyCapsule_SetTraverse` stores a `traverseproc`/`inquiry` pair and
tracks the object through two C residue helpers
(`jacpy_capsule_is_tracked`/`jacpy_capsule_track`, because the GC macros write GC
header bits). `PyCapsule_Import` walks dotted names over a `PyMem_Malloc`ed
copy; the in-place `*dot++ = 0` split is residue
(`jacpy_capsule_split`), as are the repr (`%p`) and the two PyErr_Format
errors. The destructor/traverse/clear fields are opaque `ptr` in the Jac
layout (same C ABI) and are invoked through `jacpy_capsule_call_destructor`,
`jacpy_capsule_call_traverse` and `jacpy_capsule_call_clear`, since indirect
calls do not lower natively. `strcmp`/`strlen`/`memcpy` are plain libc
externs.

`iterobject.c` is the fifth port (`runtime/python/iterobject.jac`), with three
GC iterator types: `PySeqIter_Type` ("iterator"), `PyCallIter_Type`
("callable_iterator"), and `_PyAnextAwaitable_Type` ("anext_awaitable",
which carries a defined static `PyAsyncMethods` record decayed into
`tp_as_async`). All slot bodies are Jac except the indirect slot calls:
`tp_iternext` and `am_await` dispatch go through `jacpy_type_call_iternext`
and `jacpy_type_call_am_await` (enumobject and namespaceobject use the same
family for `tp_alloc`/`tp_free`), `_PyObject_HasLen` reads `tp_as_sequence->sq_length` through a
cast, and the GC track/untrack reuse the capsule residue helpers. Residue:
the `Py_BuildValue` formats for `__reduce__`, the `PyObject_CallMethod`
proxy for send/throw/close, and `jacpy_iter_builtin`
(`_PyEval_GetBuiltin(&_Py_ID(iter))`; the static-identifier machinery
stays beside its consumer). `_PyGen_SetStopIterationValue` is declared as a
plain extern (real symbol, pycore_genobject).

`enumobject.c` is the sixth port (`runtime/python/enumobject.jac`):
`PyEnum_Type` ("enumerate", 56-byte `enumobject`, flags 17408) and
`PyReversed_Type` ("reversed", 32-byte `reversedobject`), both with the
clinic `__new__` wrappers re-expressed as Jac arg parsing plus
`vectorcall` constructors (the inlined `PyVectorcall_NARGS` mask and
`jacpy_vectorcall_arg` element loads). The C critical sections and
`FT_ATOMIC_*` accessors are GIL-build no-ops, so `enum_next`'s
uniquely-referenced tuple recycling path (`_PyObject_IsUniquelyReferenced`
→ refcount read, static inline `_PyTuple_Recycle` → `jacpy_tuple_recycle`
residue, macro `PyTuple_SET_ITEM` →
`jacpy_tuple_set_item` residue) ports one-to-one. `_PyLong_GetOne` (static
inline), the `__class_getitem__` = `Py_GenericAlias` method, the
`_PyObject_LookupSpecial(&_Py_ID(__reversed__))` static identifier, and the
`Py_BuildValue`/`%.200s` formatters are residue helpers
(`jacpy_enum_*`, `jacpy_reversed_*`, `jacpy_long_one`,
`jacpy_tuple_item/set_item`, `jacpy_enum_result_tuple`).

`sliceobject.c` is the seventh port (`runtime/python/sliceobject.jac`):
the Ellipsis singleton (`PyEllipsis_Type` + `_Py_EllipsisObject`, the
`Py_Ellipsis` macro target, immortal head with flags 0) and
`PySlice_Type` (40-byte `PySliceObject`, flags 16384, `tp_hash`/
`tp_richcompare`/`tp_methods`/`tp_members`). The four C-API index helpers
keep their exact ABI (`def:pub`): `PySlice_GetIndices`/`Unpack` write
through the caller's `Py_ssize_t` pointers via `jacpy_isize_store/load`
residue; `_PySlice_GetLongIndices` computes into an internal record and
the pub wrapper stores through the callers' `PyObject **` via
`jacpy_ptr_store3`. `PySlice_Check` is exact-type (no subclasses in the
check, matching the C macro). The freelist was first dropped (allocations went
straight through `PyObject_GC_New`/`Del`; the perf pass below restored it
through C helpers). Long sign/tag logic (`lv_tag & 3`) is shared logic
with boolobject.jac; residue: the `%R`/`%O` formatters, the UnpackTuple
arg-count errors, `jacpy_long_zero` (static inline), and `jacpy_slice_hash`
(the u64 xxHash rotation; `u64.wrap` and the `wrapping_*` builtins could
now express it in Jac).

`rangeobject.c` is the eighth port (`runtime/python/rangeobject.jac`).
`PyRange_Type` keeps the four owned `PyLong` fields and exact 48-byte layout;
its constructor, length/index/slice paths, membership, equality/hash, repr,
pickling, and sequence/mapping/number slots are Jac. Length and reverse
iteration take overflow-checked C-long fast paths before falling back to
arbitrary-precision arithmetic. The 40-byte `range_iterator` and
`longrange_iterator` layouts cover both representations, including
`__length_hint__`, `__reduce__`, and `__setstate__`. Range objects and
range iterators allocate through the `ranges` / `range_iters` freelists, as
in C. C residue is limited to allocation, `_PyIndex_Check`, formatted range
errors/repr/reduce, and the `iter` builtin lookup/reduction formatter.

`Py_None` and `Py_NotImplemented` are macros with no exported symbol of their
own, so the ports declare the real data symbols (`_Py_NoneStruct`,
`_Py_NotImplementedStruct`) as extern `PyObject_Layout` globals and bind them
to a `ptr[PyObject]` local where used, the same decay as `PyLong_Type`.

Running the `JACPYTHON=1` build surfaced further native-ABI rules for the
ports. `tp_traverse` receives `visit` as a C function pointer, so every
`Py_VISIT` goes through `jacpy_visit`; a `Callable` parameter would be called
as a Jac closure. `&mut` locals passed to a Jac `def:pub` taking bare `ptr`
do not lower to addresses, so rangeobject declares `_PySlice_GetLongIndices`
as a C extern with `&mut ptr[PyObject]` out-params, which do. Jac's `u64`
casts and arithmetic are checked, so C's unsigned-wraparound code
(`get_len_of_range`, `range_reverse`, the iterator's end-of-range step) uses
`u64.wrap` and the `wrapping_*` builtins. Calls through a C struct's
function-pointer field (`ty.tp_iternext(it)` on a `ptr[T]`) lower to a direct
load and indirect call.

Refcounting goes through `refcount.jac` (`py_incref`/`py_decref`, the
3.14 64-bit logic) so it inlines: the native object is linked as machine
code, so `Py_IncRef`/`Py_DecRef` would be real calls where C inlines its
macros. The slice and range freelists are restored through small C helpers
(`jacpy_slice_alloc/free`, `jacpy_range_obj_alloc/free`,
`jacpy_rangeiter_alloc/free`). A port's extern C declaration of a function another
port defines (`PyBool_FromLong`) must come from `cpython_api.jac`, never a
local `import from c` block, and the name must not be in the compiler's
reserved C symbols, or the definition is renamed `__jac_def_*`.
`compiler-bridge.patch` drops each removed object's `Objects/*.o` from
`OBJECT_OBJS`.

## Evaluator (`Python/`, 132k lines)

The instruction set is defined once, in the DSL of `Python/bytecodes.c`
(5,549 lines, 359 instruction, op, macro and family definitions);
`Tools/cases_generator` turns it into `generated_cases.c.h` (12,528 lines).
The Jac evaluator follows the clinic pattern: a Jac backend for
`cases_generator` reads the same definitions and emits Jac instruction
bodies. The bodies are restricted C over macros (`DEOPT_IF`, `ERROR_IF`,
`PyStackRef_*`), so that backend is a translator for that dialect, not a
general C translator. Requirements beyond the object model:

- tagged stack references (`_PyStackRef` stores tag bits in the pointer):
  pointer/integer conversion and bit operations (gap 1);
- the tail-call dispatch the release build requires
  (`Py_TAIL_CALL_INTERP`, checked by `smoke.py`): `musttail` calls in the
  native backend;
- frames, the thread state and the interpreter state are C structs the rest
  of the runtime reads (C-layout structs with in-place writes, gap 2);
- the performance gate in `scripts/python_evaluator_bench.py`.

The compiler replacement (parser, symbol table, code generation, assembler)
is already Jac; the evaluator is the next boundary after the object model.
