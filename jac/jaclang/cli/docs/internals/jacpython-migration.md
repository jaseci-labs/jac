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
| calling a C function pointer | Jac can pass named callbacks to C but not call a `ptr` | kept in the owning C file (atexit's lifecycle hooks) |
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
   them.
4. **Exporting data symbols.** A static `PyTypeObject` is a C variable other C
   code takes the address of.
5. **Varargs calls.**
6. **Native emitter: assigning a field of a glob imported from another
   module** fails with `'IntType' object has no attribute 'is_opaque'`. Calling
   a method of the same object that assigns the field lowers correctly
   (`ClassToken.bind`).

Gaps 1 to 4 block the object model and the evaluator.

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

Order, once gaps 1, 2 and 4 are closed: leaf types with little behaviour
(`cellobject.c` 212, `boolobject.c` 227, `namespaceobject.c` 332,
`capsule.c` 366, `iterobject.c` 541, `enumobject.c` 585, `sliceobject.c` 710,
`rangeobject.c` 1,317), then containers (`tupleobject.c`, `listobject.c`,
`setobject.c`, `dictobject.c`), then numbers and text (`floatobject.c`,
`complexobject.c`, `longobject.c`, `bytesobject.c`, `unicodeobject.c`), and
`typeobject.c` (12,312 lines) last. `mimalloc` and `obmalloc.c` stay the
allocator.

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
