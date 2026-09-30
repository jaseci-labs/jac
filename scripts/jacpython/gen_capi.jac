"""Generate jac/jaclang/runtime/python/cpython_api.jac from the pinned CPython headers.

Native Jac modules call the CPython C API by its own names. This script reads
every PyAPI_FUNC declaration from the checksum-pinned CPython archive's
Include/ tree and emits a typed clib declaration for each function the JacPython
sources use, so a Jac port reads like the C it replaces:

    jac run scripts/jacpython/gen_capi.jac            # rewrite the file
    jac run scripts/jacpython/gen_capi.jac --check    # fail on drift

Exported functions and data symbols are declared. A variadic function's `...`
is `*args: any`, so a call passes its extra arguments with C's default
promotions (`PyTuple_Pack(2, a, b)`). A PyAPI_DATA variable (or
an internal header's `extern` one) becomes a `glob` of the clib block: an
object pointer such as `PyExc_TypeError` is read in place as ptr[PyObject],
and a C object such as `PyLong_Type` is declared with the opaque PyObject type
and used by address, `addressof(PyLong_Type)`. `Py_None`, `Py_NotImplemented`
and `Py_Ellipsis`, macros for such an address, are globs of it. Other macros
and static inline helpers have no linkable symbol; capi.jac expresses them
through exported functions and the C helpers. A use of a name that is not
declared here is an ordinary unresolved-name error from `jac check`.
"""
import argparse;
import re;
import sys;
import from pathlib { Path }
import from common {
    BOOTSTRAP,
    REPO,
    RUNTIME,
    SOURCES,
    archive_texts,
    format_jac,
    pin,
    write_or_check
}

glob OUTPUT: Path = RUNTIME / "cpython_api.jac",
     # C helpers for what has no exported function: macros, struct fields and
     # errno. Their Jac declarations come from these files too.
     HELPER_SOURCES: list[Path] = [
         BOOTSTRAP / "object_api.c",
         BOOTSTRAP / "compiler_runtime.c"
     ];

# Opaque C types a declaration may point to. Each becomes `obj Name;` and is
# usable only as ptr[Name]. Every object layout that begins with a PyObject
# header is declared as ptr[PyObject], matching the casts CPython's own C makes;
# the remaining opaque types are not Python objects.
glob OPAQUE: list[str] = [
         "PyObject",
         "PyThreadState",
         "PyInterpreterState",
         "PyUnicodeWriter",
         "PyModuleDef",
         "PyCompilerFlags",
         "PyBytesWriter",
         "PyMutex",
         "_Py_freelists",
         "PyLongWriter",
         "_PyUnicodeWriter",
         "_PyRuntimeState",
         "FILE"
     ],
     OBJECT_LAYOUTS: set[str] = {
         "PyTypeObject",
         "PyLongObject",
         "PyCodeObject",
         "PyFrameObject",
         "PyDictObject",
         "PyListObject",
         "PyTupleObject",
         "PyBytesObject",
         "PyVarObject",
         "PyUnicodeObject",
         "PyFloatObject",
         "PyByteArrayObject",
         "PySetObject",
         "PySTEntryObject",
         "PyWeakReference",
         "PyFunctionObject",
         "PyGenObject"
     },
     # Field names differ from C where C's are Jac keywords; layout is by position.
     STRUCTS: dict[str, str] = {
         "Py_complex": "obj Py_complex { has real: f64, imag: f64; }",
         "PyMethodDef": (
             "obj PyMethodDef { has ml_name: ptr[u8], ml_meth: ptr, ml_flags: i32, "
             + "ml_doc: ptr[u8]; }"
         ),
         "Py_buffer": (
             "obj Py_buffer { has buf: ptr, owner: ptr[PyObject], length: i64, itemsize: i64, "
             + "readonly: i32, ndim: i32, format_: ptr[u8], shape: ptr[i64], strides: ptr[i64], "
             + "suboffsets: ptr[i64], internal: ptr; }"
         ),
         "PyMemberDef": (
             "obj PyMemberDef { has name: ptr[u8] = ptr[u8](), type_: i32 = 0, "
             + "offset: i64 = 0, flags: i32 = 0, doc: ptr[u8] = ptr[u8](); }"
         ),
         # PyLong_Export() and PyLong_GetNativeLayout() (Include/cpython/longintrepr.h).
         "PyLongExport": (
             "obj PyLongExport { has value: i64 = 0, negative: u8 = 0, ndigits: i64 = 0, "
             + "digits: ptr = ptr(), _reserved: u64 = 0; }"
         ),
         "PyLongLayout": (
             "obj PyLongLayout { has bits_per_digit: u8 = 0, digit_size: u8 = 0, "
             + "digits_order: i8 = 0, digit_endianness: i8 = 0; }"
         ),
         # A heap type's spec, for PyType_FromModuleAndSpec from C data.
         "PyType_Slot": "obj PyType_Slot { has slot: i32 = 0, pfunc: ptr = ptr(); }",
         "PyType_Spec": (
             "obj PyType_Spec { has name: ptr[u8] = ptr[u8](), basicsize: i32 = 0, "
             + "itemsize: i32 = 0, flags: u32 = 0, slots: ptr[PyType_Slot] = ptr[PyType_Slot](); }"
         ),
         "_PyTimeFraction": "obj _PyTimeFraction { has numer: i64 = 0, denom: i64 = 0; }",
         "_Py_clock_info_t": (
             "obj _Py_clock_info_t { has implementation: ptr[u8] = ptr[u8](), "
             + "monotonic: i32 = 0, adjustable: i32 = 0, resolution: f64 = 0.0; }"
         ),
         # <locale.h> struct lconv. glibc and macOS agree up to n_sign_posn;
         # the trailing int_* fields, which no port reads, follow macOS order.
         # The char fields are read as bytes; their signedness follows the
         # target's CHAR_MAX.
         "lconv": (
             "obj lconv { has decimal_point: ptr[u8], thousands_sep: ptr[u8], "
             + "grouping: ptr[u8], int_curr_symbol: ptr[u8], currency_symbol: ptr[u8], "
             + "mon_decimal_point: ptr[u8], mon_thousands_sep: ptr[u8], "
             + "mon_grouping: ptr[u8], positive_sign: ptr[u8], negative_sign: ptr[u8], "
             + "int_frac_digits: u8, frac_digits: u8, p_cs_precedes: u8, "
             + "p_sep_by_space: u8, n_cs_precedes: u8, n_sep_by_space: u8, "
             + "p_sign_posn: u8, n_sign_posn: u8, int_p_cs_precedes: u8, "
             + "int_n_cs_precedes: u8, int_p_sep_by_space: u8, int_n_sep_by_space: u8, "
             + "int_p_sign_posn: u8, int_n_sign_posn: u8; }"
         )
     },
     # C-layout records of interpreter internals a JacPython source walks.
     INTERNAL_STRUCTS: dict[str, str] = {
         "atexit_callback": (
             "obj atexit_callback { has func: Callable[[ptr], None], data: ptr, "
             + "next: ptr[atexit_callback]; }"
         ),
         # The union read through its `expat` member: 16 salt bytes, then the
         # legacy XML_SetHashSalt() salt.
         "_Py_HashSecret_t": (
             "obj _Py_HashSecret_t { has expat_hashsalt16_head: u64, "
             + "expat_hashsalt16_tail: u64, expat_hashsalt: i64; }"
         )
     },
     # Macros that name the address of a C object; each is a glob of that
     # address beside NULL, so Jac reads `value == Py_None` as C does.
     ADDRESS_MACROS: dict[str, str] = {
         "Py_None": "_Py_NoneStruct",
         "Py_NotImplemented": "_Py_NotImplementedStruct",
         "Py_Ellipsis": "_Py_EllipsisObject"
     },
     # Records a caller builds in Jac and lends for the call: a pointer
     # parameter to one is a borrow (`&T` when const, else `&mut T`).
     BORROWED: set[str] = {
         "PyMemberDef",
         "_PyTimeFraction",
         "_Py_clock_info_t",
         "PyLongExport"
     },
     # C library records whose layout differs between platforms. They are
     # declared by per-OS variant modules, imported from there, and borrowed.
     PLATFORM_RECORDS: dict[str, str] = {
         "timespec": "jaclang.runtime.python.modules.time_records",
         "timeval": "jaclang.runtime.python.modules.time_records",
         "tm": "jaclang.runtime.python.modules.time_records",
         "_Py_stat_struct": "jaclang.runtime.python.modules.stat_records"
     },
     SCALARS: dict[str, str] = {
         "int": "i32",
         "signed int": "i32",
         "unsigned int": "u32",
         "unsigned": "u32",
         "short": "i16",
         "unsigned short": "u16",
         "char": "i8",
         "signed char": "i8",
         "unsigned char": "u8",
         "long": "i64",
         "unsigned long": "u64",
         "long long": "i64",
         "unsigned long long": "u64",
         "size_t": "u64",
         "Py_ssize_t": "i64",
         "Py_hash_t": "i64",
         "Py_uhash_t": "u64",
         "int8_t": "i8",
         "uint8_t": "u8",
         "int16_t": "i16",
         "uint16_t": "u16",
         "int32_t": "i32",
         "uint32_t": "u32",
         "int64_t": "i64",
         "uint64_t": "u64",
         "intptr_t": "i64",
         "uintptr_t": "u64",
         "PyTime_t": "i64",
         "time_t": "i64",
         "_PyTime_round_t": "i32",
         # Enums of C int values.
         "PyGILState_STATE": "i32",
         "PySendResult": "i32",
         "wchar_t": "i32",
         "Py_UCS4": "u32",
         "Py_UCS1": "u8",
         "Py_UCS2": "u16",
         "uid_t": "u32",
         "gid_t": "u32",
         "double": "f64",
         "float": "f32",
         # 32-bit on every JacPython target (glibc and macOS).
         "wchar_t": "i32"
     },
     # Pointer typedefs passed through opaquely; a function pointer typedef
     # here can be passed NULL but not a Jac callback.
     POINTER_TYPEDEFS: dict[str, str] = {
         "PyCapsule_Destructor": "ptr",
         "PyThread_type_lock": "ptr",
         "vectorcallfunc": "ptr",
         "Py_tracefunc": "ptr",
         # A tp_traverse visitor, passed on as received.
         "visitproc": "ptr"
     },
     # A `const char *` parameter is a NUL-terminated C string (Jac `str`) unless
     # the function reads a sized payload; those take raw memory as `bytes`.
     PAYLOAD_PARAMETERS: dict[str, set[int]] = {
         "PyBytes_FromStringAndSize": {0},
         "PyByteArray_FromStringAndSize": {0},
         "PyUnicode_DecodeUTF8": {0},
         "PyUnicode_Decode": {0},
         "PyUnicode_FromStringAndSize": {0},
         "PyUnicode_DecodeLatin1": {0},
         "PyUnicode_DecodeASCII": {0},
         "PyUnicodeWriter_WriteUTF8": {1},
         "PyLong_FromNativeBytes": {0},
         "PyFloat_Unpack2": {0},
         "PyFloat_Unpack4": {0},
         "PyFloat_Unpack8": {0}
     },
     # Pointer parameters that take memory the caller holds as a raw address
     # (a HACL* digest buffer, a Py_buffer, a path read after fork(), an
     # optional out-flag passed as NULL, a keyword-name array defined as C
     # data), not a Jac value; they take `ptr`.
     ADDRESS_PARAMETERS: dict[str, set[int]] = {
         "PyArg_ParseTupleAndKeywords": {3},
         "PyOS_string_to_double": {0, 1},
         "_Py_string_to_number_with_underscores": {0, 5},
         "_Py_strhex": {0},
         "_PyBytes_Find": {0, 2},
         "_PyBytes_ReverseFind": {0, 2},
         "_PyMem_Strdup": {0},
         "PyBytes_DecodeEscape": {0},
         "PyMember_GetOne": {0},
         "PyMember_SetOne": {0},
         "PyBytes_FromString": {0},
         "PyUnicode_DecodeFSDefault": {0},
         "PyUnicode_DecodeASCII": {0},
         "PyUnicode_DecodeCharmap": {0},
         "PyUnicodeDecodeError_Create": {0, 1},
         "PyUnicode_DecodeLatin1": {0},
         "PyUnicode_DecodeLocale": {0},
         "PyUnicode_DecodeLocaleAndSize": {0},
         "PyUnicode_DecodeUTF7Stateful": {0},
         "PyUnicode_DecodeUTF8Stateful": {0},
         "PyUnicode_DecodeUTF16Stateful": {0},
         "PyUnicode_DecodeUTF32Stateful": {0},
         "_PyUnicode_DecodeRawUnicodeEscapeStateful": {0},
         "_PyUnicode_DecodeUnicodeEscapeStateful": {0},
         "_Py_open_noraise": {0},
         "jacpy_opendir": {0},
         "_Py_set_inheritable_async_safe": {2}
     },
     # Pointer parameters that accept NULL. A `const char *` (an `errors` or
     # `encoding` name, where NULL selects the default) takes the C string
     # address `ptr[u8]` that clinic's nullable str converter produces; an
     # out-pointer takes `&mut T | None`, so None passes NULL.
     NULLABLE_PARAMETERS: dict[str, set[int]] = {
         "PyBytes_DecodeEscape": {2, 4},
         "PyOS_double_to_string": {4},
         "PyCodec_Decode": {1, 2},
         "PyCodec_Encode": {1, 2},
         "PyDict_SetDefaultRef": {3},
         "PyErr_WarnExplicit": {4},
         "PyUnicode_AsWideCharString": {1},
         "PyUnicode_DecodeASCII": {2},
         "PyUnicode_DecodeCharmap": {3},
         "PyUnicode_DecodeLocale": {1},
         "PyUnicode_DecodeLatin1": {2},
         "PyUnicode_DecodeUTF7Stateful": {2, 3},
         "PyUnicode_DecodeUTF8Stateful": {2, 3},
         "PyUnicode_DecodeUTF16Stateful": {2, 4},
         "PyUnicode_DecodeUTF32Stateful": {2, 4},
         "_PyUnicode_AsASCIIString": {1},
         "_PyUnicode_AsLatin1String": {1},
         "_PyUnicode_AsUTF8String": {1},
         "_PyUnicode_DecodeRawUnicodeEscapeStateful": {2, 3},
         "_PyUnicode_DecodeUnicodeEscapeStateful": {2, 3},
         "_PyUnicode_EncodeCharmap": {2},
         "_PyUnicode_EncodeUTF7": {3},
         "_PyUnicode_EncodeUTF16": {1},
         "_PyUnicode_EncodeUTF32": {1},
         # atomic_flag_works: NULL where the platform has no SOCK_CLOEXEC.
         "_Py_set_inheritable": {2}
     },
     # `void *` out-parameters of converters whose C type the function fixes.
     TYPED_OUT_PARAMETERS: dict[str, dict[int, str]] = {
         "_PyLong_UnsignedShort_Converter": {1: "&mut u16"},
         "_PyLong_UnsignedInt_Converter": {1: "&mut u32"},
         "_PyLong_UInt16_Converter": {1: "&mut u16"},
         "_PyLong_UInt32_Converter": {1: "&mut u32"},
         "_PyLong_UInt8_Converter": {1: "&mut u8"},
         "_PyLong_UInt64_Converter": {1: "&mut u64"}
     },
     # `void *` parameters of a PyArg converter (`int conv(PyObject *, void *)`)
     # that receive the converted object.
     OBJECT_OUT_PARAMETERS: dict[str, set[int]] = {
         "PyUnicode_FSConverter": {1},
         "PyType_GetBaseByToken": {2}
     },
     # Pointer out-parameters the Jac side writes through `&mut`.
     OUT_POINTERS: dict[str, str] = {
         "PyObject **": "&mut ptr[PyObject]",
         "void **": "&mut ptr",
         "char **": "&mut ptr[u8]",
         "Py_ssize_t *": "&mut i64",
         "int *": "&mut i32",
         "double *": "&mut f64",
         "int64_t *": "&mut i64",
         "PyTime_t *": "&mut i64",
         "time_t *": "&mut i64",
         "long *": "&mut i64",
         "size_t *": "&mut u64",
         "uint64_t *": "&mut u64",
         "uint32_t *": "&mut u32",
         "uid_t *": "&mut u32",
         "gid_t *": "&mut u32"
     },
     KEYWORDS: set[str] = set(
         (
             "obj node edge walker root here visitor self super init has can def glob "
             + "impl sem test entry exit spawn visit disengage report ignore by to with "
             + "in is not and or if else elif for while return yield break continue try "
             + "except finally raise assert del import from as lambda async await class "
             + "enum include skip match case switch default flow wait priv pub protect "
             + "static override abs kw let type any str int float bool bytes list dict "
             + "set tuple ptr object len format hash iter next callable id"
         ).split()
     ),
     UNNAMED_TYPES: tuple[str, ...] = (
         "const",
         "struct",
         "unsigned",
         "signed",
         "long",
         "short"
     ),
     UNNAMED_NAMES: tuple[str, ...] = (
         "int",
         "long",
         "char",
         "short",
         "double",
         "float",
         "unsigned",
         "signed"
     ),
     API_FUNC: str = r"PyAPI_FUNC\(((?:[^()]|\([^()]*\))*)\)\s*([A-Za-z_]\w*)\s*\(((?:[^()]|\([^()]*\))*)\)",
     INTERNAL_EXTERN: str = r"^[ \t]*extern[ \t]+((?:const[ \t]+)?[A-Za-z_]\w*(?:[ \t]+\w+)*[ \t\*]*?[ \t]*\**?)\b([A-Za-z_]\w*)\s*\(((?:[^()]|\([^()]*\))*)\)\s*;",
     API_DATA: str = r"PyAPI_DATA\(([^()]*)\)\s*([A-Za-z_]\w*)\s*;",
     # A function the headers export with PyAPI_DATA (pycore_long.h's
     # `PyAPI_DATA(double) _PyLong_Frexp(PyLongObject *a, int64_t *e);`).
     API_DATA_FUNC: str = r"PyAPI_DATA\(([^()]*)\)\s*([A-Za-z_]\w*)\s*\(((?:[^()]|\([^()]*\))*)\)\s*;",
     INTERNAL_DATA: str = r"^[ \t]*extern[ \t]+((?:const[ \t]+)?[A-Za-z_]\w*[ \t\*]*?)[ \t]*\b([A-Za-z_]\w*)[ \t]*;",
     HELPER_DEF: str = r"^(?!static)((?:const )?\w+(?: \w+)*\s*\**)\s*(jacpy_\w+)\(([^)]*)\)\s*\{",
     # Typedef structs of the C helpers whose fields are all scalars.
     STRUCT_NAMES: dict[str, list[tuple[str, str]]] = {},
     # Names the JacPython sources call, as opposed to only mention.
     CALLED: set[str] = set();

def normal(ctype: str) -> str {
    ctype = " ".join(ctype.replace("*", " * ").split());
    return ctype.replace("* *", "**").strip();
}

def parameters(raw: str) -> list[tuple[str, str]] {
    params: list[tuple[str, str]] = [];
    if not raw or raw == "void" {
        return params;
    }
    # Split at the top-level commas: a function-pointer parameter's own
    # parameter list stays one piece.
    pieces: list[str] = [];
    depth = 0;
    current = "";
    for character in raw {
        if character == "," and depth == 0 {
            pieces.append(current);
            current = "";
            continue;
        }
        if character == "(" {
            depth += 1;
        } elif character == ")" {
            depth -= 1;
        }
        current += character;
    }
    pieces.append(current);
    for piece in pieces {
        piece = piece.strip();
        split = re.match(r"^(.*?[\s\*])([A-Za-z_]\w*)$", piece);
        if split is not None
            and piece != "..."
            and split.group(1).strip()
            and split.group(1).strip() not in UNNAMED_TYPES
            and split.group(2) not in UNNAMED_NAMES
            and normal(piece) not in SCALARS {
            params.append((normal(split.group(1)), split.group(2)));
        } else {
            params.append((normal(piece), ""));
        }
    }
    return params;
}

# Header text without comments or line continuations.
def plain(text: str) -> str {
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S);
    return re.sub(r"//[^\n]*", " ", text).replace("\\\n", " ");
}

def declarations(
    texts: dict[str, str]
) -> dict[str, tuple[str, list[tuple[str, str]]]] {
    functions: dict[str, tuple[str, list[tuple[str, str]]]] = {};
    for path in sorted(texts) {
        text = plain(texts[path]);
        found = list(re.finditer(API_FUNC, text, re.S))
            + list(re.finditer(API_DATA_FUNC, text, re.S));
        # Internal headers (and posixmodule.h) also declare plain `extern`
        # functions. jacpython.o links into libpython itself, so they resolve
        # like exported ones.
        if path.startswith("Include/internal/") or path == "Modules/posixmodule.h" {
            for hit in re.finditer(INTERNAL_EXTERN, text, re.M | re.S) {
                if '"' not in hit.group(0) {
                    found.append(hit);
                }
            }
        }
        for hit in found {
            name = hit.group(2);
            if name not in functions {
                functions[name] = (
                    normal(hit.group(1)),
                    parameters(" ".join(hit.group(3).split()))
                );
            }
        }
    }
    return functions;
}

# C types of the data symbols: PyAPI_DATA variables and, from the internal
# headers, plain `extern` variables (libpython resolves both for jacpython.o).
def data_declarations(texts: dict[str, str]) -> dict[str, str] {
    variables: dict[str, str] = {};
    for path in sorted(texts) {
        text = plain(texts[path]);
        found = list(re.finditer(API_DATA, text));
        if path.startswith("Include/internal/") {
            found += list(re.finditer(INTERNAL_DATA, text, re.M));
        }
        for hit in found {
            if hit.group(2) not in variables {
                variables[hit.group(2)] = normal(hit.group(1));
            }
        }
    }
    return variables;
}

# A data symbol's Jac type: an object pointer is read in place; a C object
# (a static type or singleton) is the opaque PyObject, used by address.
def data_type(ctype: str) -> str | None {
    base = ctype.replace("const ", "").replace(" const", "").strip();
    if base in ("PyObject *", "PyTypeObject *") {
        return "ptr[PyObject]";
    }
    if normal(base) == "char *" {
        return "ptr[u8]";
    }
    if base in OBJECT_LAYOUTS or base == "PyObject" {
        return "PyObject";
    }
    if base in INTERNAL_STRUCTS {
        return base;
    }
    # An opaque C object (_PyRuntime) is used by address.
    if base in OPAQUE {
        return base;
    }
    return SCALARS.get(base);
}

def jac_type(function: str, ctype: str, index: int | None) -> str | None {
    # A raw address, whatever the C type (a buffer position, a callback).
    if index is not None and index in ADDRESS_PARAMETERS.get(function, set()) {
        return "ptr";
    }
    # A vector of object arguments (`PyObject *const *args` of the vectorcall
    # API) is read, not written.
    if index is not None
        and re.fullmatch(r"PyObject\s*\*\s*const\s*\*", ctype.strip()) {
        return "ptr[ptr[PyObject]]";
    }
    base = ctype.replace("const ", "").replace(" const", "").strip();
    if normal(base) in ("void * *", "void **") and index is None {
        return "ptr[ptr]";
    }
    if index is not None and index in TYPED_OUT_PARAMETERS.get(function, {}) {
        return TYPED_OUT_PARAMETERS[function][index];
    }
    record = re.match(r"^(?:struct )?(\w+) \*$", base);
    if record
        and (record.group(1) in BORROWED or record.group(1) in PLATFORM_RECORDS) {
        if index is None {
            return None;
        }
        return ("&" if "const" in ctype else "&mut ") + record.group(1);
    }
    base = base.removeprefix("struct ");
    if base in STRUCT_NAMES or base in STRUCTS or base in INTERNAL_STRUCTS {
        return base;
    }
    if base == "void" {
        return "None";
    }
    if base in SCALARS {
        return SCALARS[base];
    }
    if base in POINTER_TYPEDEFS {
        return POINTER_TYPEDEFS[base];
    }
    if index is not None and base.endswith("*") {
        if index in OBJECT_OUT_PARAMETERS.get(function, set()) {
            return "&mut ptr[PyObject]";
        }
    }
    nullable = index is not None and index in NULLABLE_PARAMETERS.get(function, set());
    if base == "char *" {
        if index is None or nullable {
            return "ptr[u8]";
        }
        if index in PAYLOAD_PARAMETERS.get(function, set()) or "const" not in ctype {
            return "bytes";
        }
        return "str";
    }
    if base == "void *" {
        return "ptr";
    }
    if base in ("PyObject * *", "PyObject **") and index is None {
        return "ptr[ptr[PyObject]]";
    }
    if ctype in OUT_POINTERS or base in OUT_POINTERS {
        if index is None {
            return None;
        }
        out = OUT_POINTERS.get(ctype, OUT_POINTERS.get(base));
        return f"{out} | None" if nullable else out;
    }
    hit = re.match(r"^(\w+(?: \w+)*) \*$", base);
    if hit {
        pointee = hit.group(1);
        if pointee in OBJECT_LAYOUTS {
            return "ptr[PyObject]";
        }
        if pointee in OPAQUE or pointee in STRUCTS or pointee in INTERNAL_STRUCTS {
            return f"ptr[{pointee}]";
        }
        if pointee in SCALARS {
            return f"ptr[{SCALARS[pointee]}]";
        }
    }
    return None;
}

# Exported jacpy_* definitions and scalar typedef structs of the C helpers.
def helpers -> tuple[
    dict[str, tuple[str, list[tuple[str, str]]]],
    dict[str, list[tuple[str, str]]]
] {
    functions: dict[str, tuple[str, list[tuple[str, str]]]] = {};
    structs: dict[str, list[tuple[str, str]]] = {};
    for path in HELPER_SOURCES {
        text = re.sub(r"/\*.*?\*/", " ", path.read_text(), flags=re.S);
        for hit in re.finditer(r"typedef struct \{([^{}]*)\}\s*(\w+);", text) {
            fields: list[tuple[str, str]] = [];
            scalar_only = True;
            for decl in hit.group(1).split(";") {
                decl = " ".join(decl.split());
                if not decl {
                    continue;
                }
                split = re.match(r"^(\w+(?: \w+)*?) (\w+(?:, \w+)*)$", decl);
                if not split or split.group(1) not in SCALARS {
                    scalar_only = False;
                    break;
                }
                fields += [
                    (split.group(1), name.strip()) for name in split.group(2).split(",")
                ];
            }
            if fields and scalar_only {
                structs[hit.group(2)] = fields;
            }
        }
        for hit in re.finditer(HELPER_DEF, text, re.M) {
            params: list[tuple[str, str]] = [];
            raw = " ".join(hit.group(3).split());
            if raw and raw != "void" {
                for piece in raw.split(",") {
                    split = re.match(r"^(.*?[\s\*])(\w+)$", piece.strip());
                    if split is not None {
                        params.append((normal(split.group(1)), split.group(2)));
                    }
                }
            }
            functions[hit.group(2)] = (normal(hit.group(1)), params);
        }
    }
    return (functions, structs);
}

def used_names(known: set[str]) -> set[str] {
    names: set[str] = set();
    # Functions a JacPython source defines under their C names (the interpreter
    # hooks of atexit) are provided, not called through a declaration.
    defined: set[str] = set();
    for tree in SOURCES {
        for path in tree.rglob("*.jac") {
            # A generator's formatting scratch directory (.gen_*) holds a
            # copy of the output while another run formats it.
            if path == OUTPUT
                or any(part.startswith(".") for part in path.relative_to(tree).parts) {
                continue;
            }
            # Comments, docstrings and string literals mention C names
            # without calling them.
            text = re.sub(r'"""(?:.|\n)*?"""', "", path.read_text());
            text = re.sub(r"(?m)^\s*#.*$", "", text);
            text = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', text);
            names.update(re.findall(r"\b((?:_?Py|jacpy_)[A-Za-z0-9_]*)\b", text));
            CALLED.update(re.findall(r"\b((?:_?Py|jacpy_)[A-Za-z0-9_]*)\s*\(", text));
            # jac fmt joins the definitions of a C block onto the line that
            # closes the previous one (`}  def PyUnstable_AtExit(...) {`).
            defined.update(
                re.findall(
                    r"(?m)(?:^|\})\s*def(?::\w+)?\s+((?:_?Py|jacpy_)[A-Za-z0-9_]*)\b[^;{]*\{",
                    text
                )
            );
            # A source may declare a function itself when its C type has no
            # mapping here (a PyStatus returned by value, typed with the
            # layouts.jac record).
            defined.update(
                re.findall(
                    r"(?m)(?:^|(?<=[;}]))\s*def(?::\w+)?\s+((?:_?Py|jacpy_)[A-Za-z0-9_]*)\b[^;{]*;",
                    text
                )
            );
        }
    }
    CALLED.difference_update(defined);
    return {
        name
        for name in names
        if name in known and name not in defined
    };
}

def render(
    functions: dict[str, tuple[str, list[tuple[str, str]]]],
    names: set[str],
    version: str,
    structs: dict[str, list[tuple[str, str]]],
    variables: dict[str, str],
    data_names: set[str],
    macros: set[str]
) -> str {
    lines = [
        '"""CPython C API declarations for native Jac modules.',
        "",
        f"Generated by scripts/jacpython/gen_capi.jac from CPython {version} headers;",
        "do not edit. Only the functions and data symbols the JacPython sources use",
        "are declared.",
        '"""',
        "import from c {"
    ];
    lines += [f"    obj {name};" for name in OPAQUE];
    lines += [f"    {STRUCTS[name]}" for name in sorted(STRUCTS)];
    lines += [f"    {INTERNAL_STRUCTS[name]}" for name in sorted(INTERNAL_STRUCTS)];
    for (name, fields) in sorted(structs.items()) {
        body = ", ".join(f"{field}: {SCALARS[kind]}" for (kind, field) in fields);
        lines.append(f"    obj {name} {{ has {body}; }}");
    }
    failures: list[str] = [];
    for name in sorted(names) {
        result: str = functions[name][0];
        params: list[tuple[str, str]] = functions[name][1];
        returned = jac_type(name, result, None);
        rendered: list[str] = [];
        mapped = True;
        for (index, (ctype, pname)) in enumerate(params) {
            # A C variadic function takes its extra arguments with C's default
            # promotions.
            if ctype == "..." {
                rendered.append("*args: any");
                break;
            }
            jtype = jac_type(name, ctype, index);
            if jtype is None {
                mapped = False;
                break;
            }
            pname = pname or f"arg{index}";
            # A parameter named like a type (pytime's `struct tm *tm`) would
            # shadow it.
            if pname in KEYWORDS or pname in PLATFORM_RECORDS or pname in STRUCTS {
                pname = pname + "_";
            }
            rendered.append(f"{pname}: {jtype}");
        }
        if returned is None or not mapped {
            if name in CALLED {
                failures.append(
                    f"{name}: {result} ({', '.join(c for (c, _) in params)})"
                );
            }
            continue;
        }
        tail = "" if returned == "None" else f" -> {returned}";
        lines.append(f"    def {name}({', '.join(rendered)}){tail};");
    }
    globs: list[str] = [];
    for name in sorted(data_names) {
        jtype = data_type(variables[name]);
        if jtype is None {
            failures.append(f"{name}: data {variables[name]}");
            continue;
        }
        globs.append(f"{name}: {jtype}");
    }
    if globs {
        lines.append(f"    glob {', '.join(globs)};");
    }
    lines.append("}");
    # Platform records a declaration borrows come from their variant modules.
    declared = "\n".join(lines);
    for module in sorted(set(PLATFORM_RECORDS.values()), reverse=True) {
        records = sorted(
            n
            for (n, m) in PLATFORM_RECORDS.items()
            if m == module and re.search(rf"&(?:mut )?{n}\b", declared)
        );
        if records {
            lines.insert(
                lines.index('"""', 1) + 1,
                f"import from {module} {{ {', '.join(records)} }}"
            );
        }
    }
    lines += ["", "glob NULL: ptr[PyObject] = ptr[PyObject]();"];
    for name in sorted(macros) {
        lines.append(
            f"glob {name}: ptr[PyObject] = addressof({ADDRESS_MACROS[name]});"
        );
    }
    if failures {
        sys.exit(
            "No Jac mapping for these used symbols (add a C helper or a mapping):\n  "
                + "\n  ".join(failures)
        );
    }
    return "\n".join(lines) + "\n";
}

with entry:__main__ {
    parser = argparse.ArgumentParser(description="Generate cpython_api.jac");
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    headers = {
        path: text
        for (path, text) in archive_texts(("Include/", )).items()
        if path.endswith(".h")
    };
    functions = declarations(headers);
    variables = data_declarations(headers);
    found = helpers();
    defined = found[0];
    structs = found[1];
    STRUCT_NAMES.update(structs);
    functions.update(defined);
    used = used_names(set(functions) | set(variables) | set(ADDRESS_MACROS));
    names = {
        name
        for name in used
        if name in functions
    };
    macros = {
        name
        for name in used
        if name in ADDRESS_MACROS
    };
    data_names = {
        name
        for name in used
        if name in variables
    }
        | {ADDRESS_MACROS[name] for name in macros};
    unused = sorted(set(defined) - names);
    if unused {
        print(
            "C helpers no JacPython source uses:", ", ".join(unused), file=sys.stderr
        );
    }
    text = format_jac(
        render(
            functions, names, pin()["version"], structs, variables, data_names, macros
        ),
        OUTPUT
    );
    if not write_or_check(OUTPUT, text, args.check, "scripts/jacpython/gen_capi.jac") {
        sys.exit(1);
    }
}
