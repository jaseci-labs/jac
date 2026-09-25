"""Generate jac/jaclang/runtime/python/cpython_api.jac from the pinned CPython headers.

Native Jac modules call the CPython C API by its own names. This script reads
every PyAPI_FUNC declaration from the checksum-pinned CPython archive's
Include/ tree and emits a typed clib declaration for each function the JacPython
sources use, so a Jac port reads like the C it replaces:

    jac run scripts/jacpython/gen_capi.jac            # rewrite the file
    jac run scripts/jacpython/gen_capi.jac --check    # fail on drift

Only exported functions are declared. Macros, static inline helpers and data
symbols (PyExc_*, Py*_Type, Py_None) have no linkable function; capi.jac
expresses the macros through exported functions and compiler_runtime.c
exposes the data symbols. A use of a name that is not declared here is an
ordinary unresolved-name error from `jac check`.
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
     # C helpers for what has no exported function: data symbols, macros, struct
     # fields, varargs and errno. Their Jac declarations come from these files too.
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
         "PyMethodDef",
         "PyType_Spec",
         "PyCompilerFlags",
         "PyBytesWriter"
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
         "Py_buffer": (
             "obj Py_buffer { has buf: ptr, owner: ptr[PyObject], length: i64, itemsize: i64, "
             + "readonly: i32, ndim: i32, format_: ptr[u8], shape: ptr[i64], strides: ptr[i64], "
             + "suboffsets: ptr[i64], internal: ptr; }"
         )
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
         "Py_UCS4": "u32",
         "Py_UCS1": "u8",
         "Py_UCS2": "u16",
         "double": "f64",
         "float": "f32"
     },
     POINTER_TYPEDEFS: dict[str, str] = {"PyThread_type_lock": "ptr"},
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
         "PyFloat_Unpack8": {0},
         "PyBytes_DecodeEscape": {0}
     },
     # Pointer out-parameters the Jac side writes through `&mut`.
     OUT_POINTERS: dict[str, str] = {
         "PyObject **": "&mut ptr[PyObject]",
         "Py_ssize_t *": "&mut i64",
         "int *": "&mut i32",
         "double *": "&mut f64",
         "int64_t *": "&mut i64",
         "PyTime_t *": "&mut i64",
         "size_t *": "&mut u64",
         "uint64_t *": "&mut u64"
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
     INTERNAL_EXTERN: str = r"^[ \t]*extern[ \t]+((?:const[ \t]+)?[A-Za-z_]\w*(?:[ \t]+\w+)*[ \t\*]*?)[ \t]*\**?\b([A-Za-z_]\w*)\s*\(((?:[^()]|\([^()]*\))*)\)\s*;",
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
    for piece in raw.split(",") {
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

def declarations(
    texts: dict[str, str]
) -> dict[str, tuple[str, list[tuple[str, str]]]] {
    functions: dict[str, tuple[str, list[tuple[str, str]]]] = {};
    for path in sorted(texts) {
        text = re.sub(r"/\*.*?\*/", " ", texts[path], flags=re.S);
        text = re.sub(r"//[^\n]*", " ", text).replace("\\\n", " ");
        found = list(re.finditer(API_FUNC, text, re.S));
        # Internal headers also declare plain `extern` functions. jacpython.o
        # links into libpython itself, so they resolve like exported ones.
        if path.startswith("Include/internal/") {
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

def jac_type(function: str, ctype: str, index: int | None) -> str | None {
    base = ctype.replace("const ", "").replace(" const", "").strip();
    if base in STRUCT_NAMES or base in STRUCTS {
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
    if base == "char *" {
        if index is None {
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
    if ctype in OUT_POINTERS or base in OUT_POINTERS {
        if index is None {
            return None;
        }
        return OUT_POINTERS.get(ctype, OUT_POINTERS.get(base));
    }
    hit = re.match(r"^(\w+) \*$", base);
    if hit {
        pointee = hit.group(1);
        if pointee in OBJECT_LAYOUTS {
            return "ptr[PyObject]";
        }
        if pointee in OPAQUE or pointee in STRUCTS {
            return f"ptr[{pointee}]";
        }
        if pointee in SCALARS {
            return f"ptr[{SCALARS[pointee]}]";
        }
    }
    if base in ("PyObject * *", "PyObject **") and index is None {
        return "ptr[ptr[PyObject]]";
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

def used_names(functions: dict[str, tuple[str, list[tuple[str, str]]]]) -> set[str] {
    names: set[str] = set();
    for tree in SOURCES {
        for path in tree.rglob("*.jac") {
            if path == OUTPUT {
                continue;
            }
            # Comments and docstrings mention C names without calling them.
            text = re.sub(r'"""(?:.|\n)*?"""', "", path.read_text());
            text = re.sub(r"(?m)^\s*#.*$", "", text);
            names.update(re.findall(r"\b((?:_?Py|jacpy_)[A-Za-z0-9_]*)\b", text));
            CALLED.update(re.findall(r"\b((?:_?Py|jacpy_)[A-Za-z0-9_]*)\s*\(", text));
        }
    }
    return {
        name
        for name in names
        if name in functions
    };
}

def render(
    functions: dict[str, tuple[str, list[tuple[str, str]]]],
    names: set[str],
    version: str,
    structs: dict[str, list[tuple[str, str]]]
) -> str {
    lines = [
        '"""CPython C API declarations for native Jac modules.',
        "",
        f"Generated by scripts/jacpython/gen_capi.jac from CPython {version} headers;",
        "do not edit. Only functions the JacPython sources call are declared.",
        '"""',
        "import from c {"
    ];
    lines += [f"    obj {name};" for name in OPAQUE];
    lines += [f"    {STRUCTS[name]}" for name in sorted(STRUCTS)];
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
            jtype = jac_type(name, ctype, index);
            if jtype is None or ctype == "..." {
                mapped = False;
                break;
            }
            pname = pname or f"arg{index}";
            if pname in KEYWORDS {
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
    lines.append("}");
    lines += ["", "glob NULL: ptr[PyObject] = ptr[PyObject]();"];
    if failures {
        sys.exit(
            "No Jac mapping for these called functions (add a C helper or a mapping):\n  "
                + "\n  ".join(failures)
        );
    }
    return "\n".join(lines) + "\n";
}

with entry:__main__ {
    parser = argparse.ArgumentParser(description="Generate cpython_api.jac");
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    functions = declarations(
        {
            path: text
            for (path, text) in archive_texts(("Include/", )).items()
            if path.endswith(".h")
        }
    );
    found = helpers();
    defined = found[0];
    structs = found[1];
    STRUCT_NAMES.update(structs);
    functions.update(defined);
    names = used_names(functions);
    unused = sorted(set(defined) - names);
    if unused {
        print(
            "C helpers no JacPython source uses:", ", ".join(unused), file=sys.stderr
        );
    }
    text = format_jac(render(functions, names, pin()["version"], structs), OUTPUT);
    if not write_or_check(OUTPUT, text, args.check, "scripts/jacpython/gen_capi.jac") {
        sys.exit(1);
    }
}
