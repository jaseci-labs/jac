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

`jacpython.o` links into libpython, so any non-static CPython symbol is
reachable from Jac. `gen_capi.jac` declares `PyAPI_FUNC` functions, the
`extern` functions of `Include/internal/`, and the data symbols the sources
use: `PyAPI_DATA` variables and the `extern` variables of the internal
headers. An exception object is read in place
(`object_error(PyExc_ValueError, ...)`,
`PyErr_ExceptionMatches(PyExc_KeyError)`); a static type or singleton is
used by address (`addressof(PyCode_Type)`), and `Py_None`, `Py_NotImplemented`
and `Py_Ellipsis` are declared as that address, as the C macros are. C remains
only where Jac cannot express the operation:

| C residue | Why | Where |
|---|---|---|
| macros and static inline functions with no exported form (`PyTuple_Check`, `PyList_GET_ITEM`) | no symbol to call | one-line `jacpy_*` helpers in `object_api.c` |
| varargs (`Py_BuildValue`, `PyErr_Format`, `PyObject_CallMethod`) | Jac clib calls are fixed-arity | helpers that fix the format |
| struct fields of object layouts and interpreter state (`tp_richcompare`, `ob_alloc`, weakref lists, `interp->atexit`, `interp->cached_objects`) | layout differs between builds | helpers (`jacpy_typing_types` returns the interpreter's typing types) |
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

The ports so far needed these. Gaps 1 to 4 are closed in the language; use
the Jac form, not a C helper:

1. **Pointer arithmetic and pointer/integer conversion.** Arithmetic follows
   C: `p + n` and `p - n` step n elements of T (bytes for bare `ptr` or an
   opaque T), `p - q` is the distance in elements, `p += n` works, `int(p)` is
   the address and `ptr[T](n)` makes a pointer from one. zlib's output window
   writes `window.next += visible` and `data_end - next_in`.
2. **Field access through a pointer.** `p.view(1)[0].field` reads and
   `p.view(1)[0].field = v` writes a C-layout struct in place.
3. **Calling a function pointer.** A C-layout struct declared in an
   `import from c` block with a `Callable[[...], R]` field calls it as
   `rec.view(1)[0].field(args)`. atexit walks the `atexit_callback` records of
   `PyUnstable_AtExit` this way; a slot read from a type (`sq_item`, a
   `visitproc`) is stored into such a field (`slot.call = int(address)`) and
   called.
4. **Data symbols.** In an `import from c` block,
   `glob PyExc_TypeError: ptr[PyObject];` reads and writes the C variable in
   place, and a C object declared with its opaque or C-layout type,
   `glob PyLong_Type: PyObject;`, is used by address,
   `addressof(PyLong_Type)`. With an initializer the block defines the
   symbol: `glob PyBool_Type: PyTypeObject = PyTypeObject(...);` is C-layout
   storage exported under that name (unless `glob:priv`), built at link time
   from C constants (literals, `ptr[u8]("text")`, `addressof(symbol)`, named
   functions for callback fields, nested struct constructors). A
   `list[T]` symbol is a C array, such as a `PyMethodDef` table, and
   `addressof(table)` is its first element.

Still open:

5. **Varargs.** Calling a variadic C function passes only the fixed
   arguments on the C-ABI path, and Jac cannot define one (`PyErr_Format`,
   `Py_BuildValue`).
6. **Structs by value across an exported function.** A `def:pub` taking or
   returning a C struct by value (`PyStatus` in the interpreter
   initialization code) still uses Jac's own convention.
7. **Tail calls.** The evaluator's tail-call dispatch needs `musttail` calls.

## Object model (`Objects/`, 143k lines)

CPython C extensions compile against the object layouts, so the layouts are
the ABI: `PyObject` (refcount, type), `PyVarObject`, `PyTypeObject` and the
concrete layouts that macros read (`PyTupleObject.ob_item`,
`PyListObject.ob_item`, `PyBytesObject.ob_sval`, the compact unicode forms).
A Jac object model keeps these byte for byte. It needs:

- C-layout structs for each layout, with interior pointers and in-place field
  writes through a pointer (gaps 1 and 2);
- static type objects exported under their C names (C data definitions,
  gap 4);
- slot functions exported as C function pointers in those type objects; Jac
  already emits named callbacks into C records;
- refcounting as inline operations in Jac, since a call per `Py_INCREF` into
  C costs a function call that ThinLTO cannot remove (`jacpython.o` enters the
  link as machine code). Emitting `jacpython.o` as bitcode for the ThinLTO link
  removes that boundary if Jac's LLVM and Zig's LLVM agree on the bitcode
  version.

Order: leaf types with little behaviour
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
