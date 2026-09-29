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
6. `jac check` each new file (from the repository root, so the dev source
   reroute checks with this tree's compiler). A single-file check reports
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
Data tables CPython generates into headers become C data definitions a
generator writes from the pinned headers, not a data-only C object:
`scripts/jacpython/gen_unicodedata.jac` reads `Modules/unicodedata_db.h` and
`Modules/unicodename_db.h` (Tools/unicode/makeunicodedata.py output) and
writes `modules/unicodedata_db.jac` and `modules/unicodename_db.jac`, and its
`--check` fails when they are stale. The tables are the bytes the C arrays
hold, laid out at link time, so the binary's size and start-up are
unchanged; the two functions `unicodedata_db.h` carries become data (a
shift and a list of case pairs). `scripts/jacpython/gen_cjkcodecs.jac` does
the same for the CJK codecs' `Modules/cjkcodecs/mappings_*.h`, writing
`modules/cjkcodecs_mappings_<locale>.jac`: each code array is a bytes
literal (`common.jac`'s `bytes_literal()`), each 256-row index a u32 array
packing a row's offset and bounds, and each `MAPPING_*` entry a `DbcsMap`
record the module publishes as its `__map_<charset>` capsule. The codecs
themselves are `MultibyteCodec` records whose entry points are named Jac
functions, which `_multibytecodec` calls through the record as C does.
Code a C file generates by including a template header more than once is
generated the same way: sre.c includes `sre_lib.h` once per character
width, and `scripts/jacpython/gen_sre.jac` writes the Jac template
`scripts/jacpython/sre_lib.jac.in` as `modules/sre_ucs1.jac`,
`sre_ucs2.jac` and `sre_ucs4.jac` (with `sre_constants.jac` from
`Modules/_sre/sre_constants.h`). The matcher keeps sre_lib.h's explicit
stack of match contexts and is one function, as the C is: an opcode
dispatch loop whose `match` lowers to a jump table, inside a loop over the
C's other labels (a context's exit, the label a DO_JUMP resumes at, the
head of a loop a DO_JUMP interrupts), with the template spelling the C's
control macros and the generator expanding them. A `match`-in-a-loop
dispatcher is not threaded through the loop header by LLVM, so the opcode
loop is its own loop and only jumps between labels pass the step switch.
The calls a regular expression makes most bind their positional arguments
directly and fall back to the generated clinic glue for keywords or
conversions, so error messages stay the C module's.
Code that only exists on some architectures goes in a `<name>.<arch>.jac`
variant beside a portable `<name>.jac` (`modules/blake2_simd.x86_64.jac`), and
code that differs between C libraries in a `<name>.<os>.jac` variant
(`modules/semaphore_platform.darwin.jac`). A linker flag only one OS needs
carries that OS as a prefix: glibc 2.17 keeps `shm_open` in librt, so
`_posixshmem` lists `linux:-lrt`.
A record or constant table that differs between the architectures of one
system goes in `<name>.<os>.<arch>.jac`, which the native compiler prefers
over `<name>.<arch>.jac`, `<name>.<os>.jac` and `<name>.jac`
(`modules/stat_records.linux.x86_64.jac`); `gen_constants.jac --arch` writes
such a table (`mmap_constants.linux.x86_64.jac` alone has `MAP_32BIT`).
Constants the portable Jac code reads on every platform are listed in
`gen_constants.jac`'s `PORTABLE` and declared as 0 where the headers lack
them.

Functions the C module parses with `PyArg_ParseTuple` or
`PyArg_ParseTupleAndKeywords` instead of Argument Clinic use
`ArgumentFormat` in `bindings/arguments.jac` with the same format units, so
their conversions and messages are `getargs.c`'s.

Argument errors match CPython's text because the glue uses CPython's own
calling conventions. `gen_clinic.jac` reads the `PyMethodDef` flags and the
parser Tools/clinic generates for each function (limited C API sources
included) and emits the same flags with a callback of that shape
(`MethodCallbacks.positional` for `METH_NOARGS`/`METH_O`/`METH_VARARGS`,
`fast` for `METH_FASTCALL`, `fast_keywords` with `METH_KEYWORDS`), so
CPython's call machinery reports "`_mod.f() takes no keyword arguments`" with
the qualified name. The `CallSignature` names the getargs routine the C parser
calls (`parser=PARSE_POSITIONAL` for `_PyArg_CheckPositional`,
`PARSE_KEYWORDS` for `_PyArg_UnpackKeywords`, `PARSE_FORMAT` and
`PARSE_FORMAT_KEYWORDS` for `PyArg_ParseTuple` and
`PyArg_ParseTupleAndKeywords`); `bindings/arguments.jac` implements each with
its messages. A hand-written binding picks the same flags and parser as the C
module's clinic output. A C type's `PyMemberDef` fields are real member
descriptors: `TypeDefinition(members=..., record_size=...)` keeps the fields
in the instance and `jacpy_binding_record()` gives their address
(`select.kevent`, `_multiprocessing.SemLock`).

A module whose types are static in C because a C API exposes them keeps
them static. `_datetime` defines `PyDateTime_DateType` and the other types,
the immortal `utc_timezone` and the `PyDateTime_CAPI` capsule record as C
data under their C names, with the layouts of `Include/datetime.h` from
`layouts.jac`, so `_zoneinfo` and other C extensions read the objects
through the header's macros. `_PyDateTime_InitTypes()`, which
`pylifecycle.c` calls, fills each type's `tp_methods` with
`method_table()` from its `MethodDefinition` list (clinic glue included)
before readying it; its IsoCalendarDate heap type is a `PyType_Spec` of C
data whose slots are `ptr(function)`.

Heap types can be C data too: `_decimal`'s `PyType_Spec`s, slot arrays and
`PyMethodDef` tables are C data whose callbacks are `ptr(function)`, and a
`Py_tp_token` slot of `ptr()` (`Py_TP_USE_SPEC`) makes each spec its type's
token for `PyType_GetBaseByToken()`, as in C.

A Jac module can also define interpreter functions under their C names: the
atexit port defines `_PyAtExit_Init` (which returns a `PyStatus` by value),
`PyUnstable_AtExit`, `_PyAtExit_Call` and `_PyAtExit_Fini` in an
`import from c` block, and `pylifecycle.c` and `pystate.c` call them.
`gen_capi.jac` does not declare a name a JacPython source defines.

The generated glue keeps C's argument types where they matter. A `str`
argument that may be NULL (it accepts None, or its C default is NULL, like
`_codecs`' `errors`) stays C's `const char *`: `ptr[u8]`, NULL when absent.
`gen_capi.jac` declares the matching C parameters in `NULLABLE_PARAMETERS`,
where a nullable out-pointer becomes `&mut T | None` and a literal None passes
NULL. `Py_buffer(accept={str, buffer})` reads a str as its UTF-8. A function
clinic compiles only under `MS_WINDOWS` is left out and listed in the
generated docstring; a function that exists only on some POSIX systems (the
gettext functions of `_locale`) is filtered by the binding from a flag in a
`<name>.<os>.jac` variant, as `resource.prlimit` is. A callable made at run
time with a bound `self`, like `_abc`'s weakref callback, comes from a
`FunctionTable` in `bindings/module.jac`. A module's own converter (`SEM_HANDLE_converter`) types its variable by the
Jac converter's return type. A `PyBytesObject` or `PyByteArrayObject`
parameter (format unit `S` or `Y`) is checked as `object(subclass_of=...)`
over bytes or bytearray. A module built from several C files (`_zstd`'s
`Modules/_zstd/`) gets one glue file for all of them. A default read from the
module state or the receiver's C fields (`clinic_state()->ConnectionType`,
`((pysqlite_Cursor *)self)->arraysize`) is a module function over the
receiver (`clinic_state_ConnectionType(receiver)`, `self_arraysize(receiver)`),
and an optional argument of a module's own converter (`_sqlite3`'s
`Autocommit`) keeps the C default when omitted. A parameter clinic deprecates
with `[from X.Y]` warns as its parser does: the `CallSignature` carries the
message and the argument counts that trigger it. A clinic block whose `_impl`
the C file never defines, a clone kept for its docstring and method table
entry (`_sqlite3.connect`), contributes only `<c_basename>_doc`, and the
binding supplies the function. `TypeHooks(finalize=...)` is `tp_finalize`; a
dealloc calls `PyObject_CallFinalizerFromDealloc()` first, as
`sqlite3.Connection` does.

Clinic coverage of the retained modules: 1,050 of 1,074 signatures generate.
The rest have C-expression defaults (`GET_YEAR(self)`, `POLLIN | POLLPRI`) or
optional groups; the generated file lists them and the module binding parses
them by hand.

## What stays C

`jacpython.o` links into libpython, so any non-static CPython symbol is
reachable from Jac. `gen_capi.jac` declares `PyAPI_FUNC` functions, the
`extern` functions of `Include/internal/` and `Modules/posixmodule.h`, and the data symbols the sources
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
| struct fields of object layouts and interpreter state (`tp_richcompare`, `ob_alloc`, weakref lists, `PyCFunctionObject.m_ml`, `interp->atexit`, `interp->cached_objects`) and of `struct dirent` | layout differs between builds (macOS x86_64 binds the `$INODE64` `readdir`) | helpers (`jacpy_typing_types` returns the interpreter's typing types) |
| CPU feature probes (CPUID) | an intrinsic | `jacpy_hacl_simd_features` |
| the libm functions Zig's compiler-rt also defines (`log`, `sin`, `fma`, ...) | a Mach-O link binds compiler-rt's weak copies ahead of libSystem's | `jacpy_libm_*` look them up in libSystem |
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
C-layout Jac structs, so fields are read directly. `PyMutex` is opaque: a port
keeps one in raw memory (`PyMem_RawCalloc(1, 1)`), so its address stays put
while threads park on it, and calls `PyMutex_Lock`/`PyMutex_Unlock` (`_zstd`).

## Language gaps

The ports so far needed these. All seven are closed in the language; use
the Jac form, not a C helper:

1. **Pointer arithmetic and pointer/integer conversion.** Arithmetic follows
   C: `p + n` and `p - n` step n elements of T (bytes for bare `ptr` or an
   opaque T), `p - q` is the distance in elements, `p += n` works, `p < q`
   (and `<=`, `>`, `>=`) orders two pointers of one pointee type by unsigned
   address, `int(p)` is the address and `ptr[T](n)` makes a pointer from one. zlib's output window
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
   functions for callback fields, nested struct constructors, and `ptr[T](...)`
   casts of these addresses). A `list[T]` symbol is a C array, such as a
   `PyMethodDef` table, and `addressof(table)` is its first element. `ptr(f)`
   is the address of the named function `f`, as C's `_PyCFunction_CAST(f)`
   erases its type, for a bare `ptr` field such as `PyMethodDef.ml_meth` or
   `PyType_Slot.pfunc`: a method table's `ml_meth` takes `ptr(range_count)` or
   `ptr(namespace_replace)` whatever the calling convention. An array of sized
   integers may instead be initialized with a bytes literal of its
   little-endian elements (`glob t: list[u16] = b"\x34\x12";`), one token
   per line of a large generated table rather than one expression per
   element; the unicodedata port lays out its 700 KB of Unicode database
   tables this way.

5. **Varargs.** A call to a variadic C function passes each extra argument
   with C's default promotions, and a borrowed one (`&mut x`) as the
   variable's address, so a port calls `fcntl`, `syslog`, `PyTuple_Pack`,
   `Py_BuildValue` or `PyArg_UnpackTuple(args, "bool", 0, 1, &mut x)` as C
   does; `gen_capi.jac` declares a variadic function's `...` as
   `*args: any`. `def PyErr_Format(exception: ptr[PyObject],
   format: ptr[u8], *args: VaList)` defines a C variadic function, a
   `VaList` parameter receives a C `va_list` (`PyErr_FormatV`),
   `args.arg(T)` reads the next argument as the C type T, and a `VaList`
   passes on to a C function that takes a `va_list`.

6. **C functions defined in Jac.** A `def` with a body in an `import from c`
   block defines a C function under that exact symbol with the C calling
   convention, including structs by value in either direction; C code and
   other modules call it as any C function. CPython's API functions a port
   defines (`PyBool_FromLong`) are written this way.

7. **Tail calls.** `return tail f(args);` is a guaranteed tail call: the
   native backend lowers it to `musttail`, so the evaluator's tail-call
   dispatch (`Py_MUSTTAIL return (INSTRUCTION_TABLE[op])(TAIL_CALL_ARGS);`)
   is `return tail table.view(1)[0].handler(frame, stack, tstate, next,
   oparg);` from one C function defined in Jac to the next, in constant
   stack at every optimization level. The handlers share one signature;
   a call that cannot reuse the frame is `E5113` naming why.

## Object model (`Objects/`, 143k lines)

CPython C extensions compile against the object layouts, so the layouts are
the ABI: `PyObject` (refcount, type), `PyVarObject`, `PyTypeObject` and the
concrete layouts that macros read (`PyTupleObject.ob_item`,
`PyListObject.ob_item`, `PyBytesObject.ob_sval`, the compact unicode forms).
A Jac object model keeps these byte for byte. `Objects/boolobject.c` is the
pilot port; it established the pieces below.

**Layouts are generated and verified.** `scripts/jacpython/gen_layouts.jac`
writes `runtime/python/layouts.jac`: one C-layout struct per layout it lists
(`_object`, `PyVarObject`, `PyTypeObject`, the slot tables, `PyGetSetDef`,
`PyLongObject`, `PyTupleObject`, `PyCellObject`, `PySliceObject`,
`_PyRangeIterObject`, and datetime.h's `PyDateTime_DateTime` and
`PyDateTime_CAPI`, ...), read from the pinned headers through
a small preprocessor that keeps the `#if` branches of the release build
(64-bit, little-endian, GIL-enabled, 30-bit digits). An object struct a `.c`
file keeps private (`rangeobject`, `PyCapsule`, `enumobject`) is read from that
file (`OBJECT_SOURCES`); the port owns it from then on, and the check below
repeats the upstream definition so the Jac layout is still asserted against C.
Function-pointer slots and members are `Callable[...]` fields, pointers to
listed layouts are `ptr[Layout]`, and
pointers to records no port reads yet are opaque. `PyObject` stays the opaque
handle of `cpython_api.jac`; its layout is `_object`, reached by casting a
handle (`ptr[_object](op).view(1)[0].ob_type`). The 3.14 refcount union is its
widest member, `ob_refcnt_full: i64`; a trailing C array `T name[1]` is one
`T` field, and further elements are reached by pointer arithmetic. A fixed
array `T name[N]` is N fields, `name` and `name_1` to `name_<N-1>`, so
`_zoneinfo` reads a datetime's year as `(data << 8) | data_1`. The same
script writes the header constants initializers need (`Py_TPFLAGS_*`, the
immortal refcount, `_PyLong_*_TAG`, `offsetof`/`sizeof` values) as `Final`
globs, read back from a configured build's headers.

It also writes `bootstrap/python/layouts_check.c`: `_Static_assert`s on the
offset, size, kind (integer, pointer, record) and signedness of every
generated field, each struct's size and alignment, and each constant's value.
`build.sh` compiles it against the configured headers of every JacPython build
before `make`, so a layout that differs on any platform fails the build.
`gen_layouts.jac --check` fails when either file is stale. To add a layout or
constant, extend `LAYOUTS` or `CONSTANTS` in the script and rerun it.

**Static objects are C data definitions.** A port defines each static type
and singleton under its C name in an `import from c` block, with the
initializer the C macros produce. `object_model/bool.jac` defines
`PyBool_Type` with `ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT`
(`PyVarObject_HEAD_INIT`: immortal, statically allocated flag in the high
bits) and `ob_type=addressof(PyType_Type)`, and `_Py_FalseStruct` /
`_Py_TrueStruct` as `PyLongObject`s whose `lv_tag` is `_PyLong_FALSE_TAG` /
`_PyLong_TRUE_TAG` and whose digit is 0 / 1. C's `Py_True` is the address of
the Jac-defined object. Slot tables (`bool_as_number`) are `glob:priv`
definitions; slots name Jac functions directly. Static C functions are plain
`def`s; non-static ones are C function definitions under their C names in an
`import from c` block (`PyBool_FromLong`), so `gen_capi.jac` drops their
declarations and Jac callers import them from the port. The extern types a port uses (`PyType_Type`, `PyLong_Type`,
`PyExc_*`) are `glob` declarations typed with their layouts, and inherited
slots are called through them:
`addressof(PyLong_Type).view(1)[0].tp_as_number.view(1)[0].nb_and(a, b)`.
`object_model/header.jac` holds the header's static inline operations
(`Py_TYPE`, `Py_IS_TYPE`, `Py_SIZE`, `PyType_HasFeature`) as Jac reads of the
layouts.

**Removing the C file.** The port marks the file `# removed:` in
`cpython-sources.txt`, `compiler-bridge.patch` deletes its object from
`OBJECT_OBJS` (the build-only host keeps it), and `native_api.jac` imports the
port so its definitions are in `jacpython.o`. The build's absent-input check
then proves the C object is gone.

What boolobject needed beyond the layouts:

- `_Py_ID(True)` and `_Py_ID(False)` (the statically allocated identifier
  strings) are fields of `_PyRuntime`, whose layout differs between platform
  builds. Interning returns them, since the static strings are interned at
  startup, so `bool_repr` is `PyUnicode_InternFromString("True")`.
- `bool_new` calls `PyArg_UnpackTuple(args, "bool", 0, 1, &mut x)` as C does.
  A borrowed variadic argument passed the variable's value instead of its
  address; both backends now pass the address.
- The `_PyArg_NoKeywords`, `_PyArg_NoKwnames` and `_PyArg_CheckPositional`
  macros are written out: the fast test inline, then the exported function.
- Two compiler fixes: a module-level `Final` glob is a C constant in data
  initializers (`tp_flags=Py_TPFLAGS_DEFAULT`, also inside `|`, `+`, `<<`
  expressions), and `Final[T]` lowers as `T` natively; C data may be typed with
  a foreign struct another module declares (declarations wait until every
  module's structs are registered).
- A `:pub` definition named after a C function the native backend itself
  declares (`NATIVE_RESERVED_C_SYMBOLS` in `codeinfo.jac`) is emitted as
  `__jac_def_<name>`, so a port defines CPython's API functions in an
  `import from c` block instead (`def PyBool_FromLong(ok: i64) ->
  ptr[PyObject] { ... }`), which exports the exact C name with the C ABI.

The leaf types (`cellobject.c`, `namespaceobject.c`, `capsule.c`,
`iterobject.c`, `enumobject.c`, `sliceobject.c`, `rangeobject.c`) followed,
as `object_model/cell.jac`, `namespace.jac`, `capsule.jac`, `iterator.jac`,
`enumerate.jac`, `slice.jac` and `range.jac`. Every exported function and the
interpreter-internal ones other C files call (`_PyBuildSlice_ConsumeRefs`,
`_PySlice_GetLongIndices`, `PyAnextAwaitable_New`, `_PyNamespace_New`) are C
definitions under their names; tables and types are C data. What they added:

- Method tables are `list[PyMethodDef]` C data. `ml_meth` is a `ptr`, and
  `ptr(f)` is the address of the named function `f` whatever its calling
  convention, as `_PyCFunction_CAST(f)` erases it in C (`ptr(range_count)`,
  `ptr(namespace_replace)`, `ptr(Py_GenericAlias)`). Slots and callback fields
  may name functions other modules define (`tp_getattro=PyObject_GenericGetAttr`).
  A C function fills a slot directly when only Jac's integer representation of
  pointers differs, so the interpreter's slot comparisons hold; a Jac function
  is reached through a C-entry trampoline that leaves the open region.
- A callback field read as an address, `int(cap.view(1)[0].destructor)`,
  tests or returns the pointer C stored (`PyCapsule_GetDestructor`,
  `tp_iternext == NULL`); an address is stored with `field = int(p)`.
- `tp_traverse` implementations take the visitor as a `ptr` and visit with
  `bindings/module.jac`'s `visit_reference` (Py_VISIT).
- The slice and range freelists are `struct _Py_freelists` fields of the
  interpreter state; `jacpy_freelists()` in `object_api.c` returns that
  struct, and `header.jac`'s `freelist_pop` / `freelist_push` implement
  `_Py_FREELIST_POP` / `_Py_FREELIST_FREE` over the `_Py_freelists_*` offsets
  gen_layouts asserts.
- `header.jac` also holds `Py_REFCNT`, the tuple item macros,
  `_PyTuple_Recycle`, `PyObject_TypeCheck`, `Py_RETURN_RICHCOMPARE` and
  `_PyEval_GetBuiltin(&_Py_ID(name))` (by interning, as bool_repr does).
- Unsigned C arithmetic (the range length formula, the slice hash) uses
  `u64.wrap` and the `wrapping_*` builtins; sized-int arithmetic otherwise
  traps on overflow, which C leaves undefined and the ports never reach.
- `enumerate.__new__` parses with `PyArg_ParseTupleAndKeywords` over a C data
  keyword array, as the clinic glue's messages are getargs.c's.

Refcounting from Jac is still a call into C (`Py_IncRef`, `jacpy_release`);
with `_object` declared, inline immortality-aware reference operations in Jac
are the next shared helper. `jacpython.o` enters the link as machine code,
so a call into C costs a call ThinLTO cannot remove; emitting it as bitcode
for the ThinLTO link removes that boundary if Jac's LLVM and Zig's LLVM agree
on the bitcode version.

Order after the leaf types: containers (`tupleobject.c`, `listobject.c`,
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
  (`Py_TAIL_CALL_INTERP`, checked by `smoke.py`): `return tail` calls
  (gap 7);
- frames, the thread state and the interpreter state are C structs the rest
  of the runtime reads (C-layout structs with in-place writes, gap 2);
- the performance gate in `scripts/python_evaluator_bench.py`.

The compiler replacement (parser, symbol table, code generation, assembler)
is already Jac; the evaluator is the next boundary after the object model.
