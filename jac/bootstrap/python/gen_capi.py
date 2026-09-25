"""Generate jaclang/runtime/python/cpython_api.jac from the pinned CPython headers.

Native Jac modules call the CPython C API by its own names. This script reads
every PyAPI_FUNC declaration from the checksum-pinned CPython archive's
Include/ tree and emits a typed clib declaration for each function the JacPython
sources use, so a Jac port reads like the C it replaces:

    python3 jac/bootstrap/python/gen_capi.py            # rewrite the file
    python3 jac/bootstrap/python/gen_capi.py --check    # fail on drift

Only exported functions are declared. Macros, static inline helpers and data
symbols (PyExc_*, Py*_Type, Py_None) have no linkable function; capi.jac
expresses the macros through exported functions and compiler_runtime.c
exposes the data symbols. A use of a name that is not declared here is an
ordinary unresolved-name error from `jac check`.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tarfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from jac_format import format_jac  # noqa: E402

HERE = Path(__file__).resolve().parent
JAC = HERE.parents[1]
REPO = JAC.parent
OUTPUT = JAC / "jaclang/runtime/python/cpython_api.jac"
# C helpers for what has no exported function: data symbols, macros, struct
# fields, varargs and errno. Their Jac declarations come from these files too.
HELPER_SOURCES = [HERE / "object_api.c", HERE / "compiler_runtime.c"]
SOURCES = [
    JAC / "jaclang/runtime/python",
    JAC / "jaclang/compiler/frontend/python",
    JAC / "jaclang/compiler/backends/py/jacpython",
]

# Opaque C types a declaration may point to. Each becomes `obj Name;` and is
# usable only as ptr[Name]. Every object layout that begins with a PyObject
# header is declared as ptr[PyObject], matching the casts CPython's own C makes;
# the remaining opaque types are not Python objects.
OPAQUE = [
    "PyObject", "PyThreadState", "PyInterpreterState", "PyUnicodeWriter",
    "PyModuleDef", "PyMethodDef", "PyType_Spec", "PyCompilerFlags", "PyBytesWriter",
]
OBJECT_LAYOUTS = {
    "PyTypeObject", "PyLongObject", "PyCodeObject", "PyFrameObject", "PyDictObject",
    "PyListObject", "PyTupleObject", "PyBytesObject", "PyVarObject",
    "PyUnicodeObject", "PyFloatObject", "PyByteArrayObject", "PySetObject",
    "PySTEntryObject", "PyWeakReference", "PyFunctionObject", "PyGenObject",
}
STRUCTS = {
    "Py_complex": "obj Py_complex { has real: f64, imag: f64; }",
    "Py_buffer": (
        # Field names differ from C where C's are Jac keywords; layout is by position.
        "obj Py_buffer { has buf: ptr, owner: ptr[PyObject], length: i64, itemsize: i64, "
        "readonly: i32, ndim: i32, format_: ptr[u8], shape: ptr[i64], strides: ptr[i64], "
        "suboffsets: ptr[i64], internal: ptr; }"
    ),
}
SCALARS = {
    "int": "i32", "signed int": "i32", "unsigned int": "u32", "unsigned": "u32",
    "short": "i16", "unsigned short": "u16", "char": "i8", "signed char": "i8",
    "unsigned char": "u8", "long": "i64", "unsigned long": "u64",
    "long long": "i64", "unsigned long long": "u64", "size_t": "u64",
    "Py_ssize_t": "i64", "Py_hash_t": "i64", "Py_uhash_t": "u64",
    "int8_t": "i8", "uint8_t": "u8", "int16_t": "i16", "uint16_t": "u16",
    "int32_t": "i32", "uint32_t": "u32", "int64_t": "i64", "uint64_t": "u64",
    "intptr_t": "i64", "uintptr_t": "u64", "PyTime_t": "i64", "Py_UCS4": "u32",
    "Py_UCS1": "u8", "Py_UCS2": "u16", "double": "f64", "float": "f32",
}
POINTER_TYPEDEFS = {"PyThread_type_lock": "ptr"}
# A `const char *` parameter is a NUL-terminated C string (Jac `str`) unless the
# function reads a sized payload; those take raw memory as `bytes`.
PAYLOAD_PARAMETERS = {
    "PyBytes_FromStringAndSize": {0}, "PyByteArray_FromStringAndSize": {0},
    "PyUnicode_DecodeUTF8": {0}, "PyUnicode_Decode": {0},
    "PyUnicode_FromStringAndSize": {0}, "PyUnicode_DecodeLatin1": {0},
    "PyUnicode_DecodeASCII": {0}, "PyUnicodeWriter_WriteUTF8": {1},
    "PyLong_FromNativeBytes": {0},
    "PyFloat_Unpack2": {0}, "PyFloat_Unpack4": {0}, "PyFloat_Unpack8": {0},
    "PyBytes_DecodeEscape": {0},
}
# Pointer out-parameters the Jac side writes through `&mut`.
OUT_POINTERS = {"PyObject **": "&mut ptr[PyObject]", "Py_ssize_t *": "&mut i64",
                "int *": "&mut i32", "double *": "&mut f64", "int64_t *": "&mut i64",
                "PyTime_t *": "&mut i64", "size_t *": "&mut u64", "uint64_t *": "&mut u64"}
KEYWORDS = {
    "obj", "node", "edge", "walker", "root", "here", "visitor", "self", "super",
    "init", "has", "can", "def", "glob", "impl", "sem", "test", "entry", "exit",
    "spawn", "visit", "disengage", "report", "ignore", "by", "to", "with", "in",
    "is", "not", "and", "or", "if", "else", "elif", "for", "while", "return",
    "yield", "break", "continue", "try", "except", "finally", "raise", "assert",
    "del", "import", "from", "as", "lambda", "async", "await", "class", "enum",
    "include", "skip", "match", "case", "switch", "default", "flow", "wait",
    "priv", "pub", "protect", "static", "override", "abs", "kw", "let", "type",
    "any", "str", "int", "float", "bool", "bytes", "list", "dict", "set", "tuple",
    "ptr", "object", "len", "format", "hash", "iter", "next", "callable", "id",
}


def archive_path() -> Path:
    pin = json.loads((HERE / "sources.json").read_text())["cpython"]
    path = JAC / ".python-build/jacpython/sources" / f"{pin['sha256']}.tar.gz"
    if not path.is_file():
        sys.exit(f"Pinned CPython archive not found: {path}; run a JacPython build once")
    if hashlib.sha256(path.read_bytes()).hexdigest() != pin["sha256"]:
        sys.exit(f"{path} does not match the pinned SHA256")
    return path


def headers(archive: Path) -> dict[str, str]:
    found = {}
    with tarfile.open(archive) as bundle:
        for member in bundle.getmembers():
            relative = member.name.split("/", 1)[-1]
            if member.isfile() and relative.startswith("Include/") and relative.endswith(".h"):
                found[relative] = bundle.extractfile(member).read().decode("utf-8", "replace")
    return found


def declarations(texts: dict[str, str]) -> dict[str, tuple[str, list[tuple[str, str]]]]:
    functions: dict[str, tuple[str, list[tuple[str, str]]]] = {}
    for path in sorted(texts):
        text = re.sub(r"/\*.*?\*/", " ", texts[path], flags=re.S)
        text = re.sub(r"//[^\n]*", " ", text).replace("\\\n", " ")
        pattern = r"PyAPI_FUNC\(((?:[^()]|\([^()]*\))*)\)\s*([A-Za-z_]\w*)\s*\(((?:[^()]|\([^()]*\))*)\)"
        found = list(re.finditer(pattern, text, re.S))
        # Internal headers also declare plain `extern` functions. jacpython.o
        # links into libpython itself, so they resolve like exported ones.
        if path.startswith("Include/internal/"):
            internal = r"^[ \t]*extern[ \t]+((?:const[ \t]+)?[A-Za-z_]\w*(?:[ \t]+\w+)*[ \t\*]*?)[ \t]*\**?\b([A-Za-z_]\w*)\s*\(((?:[^()]|\([^()]*\))*)\)\s*;"
            for match in re.finditer(internal, text, re.M | re.S):
                if '"' not in match.group(0):
                    found.append(match)
        for match in found:
            result, name, raw = match.group(1), match.group(2), " ".join(match.group(3).split())
            if name in functions:
                continue
            params: list[tuple[str, str]] = []
            if raw and raw != "void":
                for index, piece in enumerate(raw.split(",")):
                    piece = piece.strip()
                    split = re.match(r"^(.*?[\s\*])([A-Za-z_]\w*)$", piece)
                    unnamed = (
                        piece == "..." or not split or not split.group(1).strip()
                        or split.group(1).strip() in ("const", "struct", "unsigned", "signed", "long", "short")
                        or split.group(2) in ("int", "long", "char", "short", "double", "float", "unsigned", "signed")
                        or normal(piece) in SCALARS
                    )
                    if unnamed:
                        params.append((normal(piece), ""))
                    else:
                        params.append((normal(split.group(1)), split.group(2)))
            functions[name] = (normal(result), params)
    return functions


def normal(ctype: str) -> str:
    ctype = " ".join(ctype.replace("*", " * ").split())
    return ctype.replace("* *", "**").replace(" *", " *").strip()


STRUCT_NAMES: dict = {}


def jac_type(function: str, ctype: str, index: int | None) -> str | None:
    base = ctype.replace("const ", "").replace(" const", "").strip()
    if base in STRUCT_NAMES:
        return base
    if base == "void":
        return "None"
    if base in SCALARS:
        return SCALARS[base]
    if base in STRUCTS:
        return base
    if base in POINTER_TYPEDEFS:
        return POINTER_TYPEDEFS[base]
    if base == "char *":
        if index is None:
            return "ptr[u8]"
        if index in PAYLOAD_PARAMETERS.get(function, ()) or "const" not in ctype:
            return "bytes"
        return "str"
    if base in ("void *",):
        return "ptr"
    if ctype in OUT_POINTERS or base in OUT_POINTERS:
        return OUT_POINTERS.get(ctype, OUT_POINTERS.get(base)) if index is not None else None
    match = re.match(r"^(\w+) \*$", base)
    if match and match.group(1) in OBJECT_LAYOUTS:
        return "ptr[PyObject]"
    if match and (match.group(1) in OPAQUE or match.group(1) in STRUCTS):
        return f"ptr[{match.group(1)}]"
    if match and match.group(1) in SCALARS:
        return f"ptr[{SCALARS[match.group(1)]}]"
    if base in ("PyObject * *", "PyObject **") and index is None:
        return "ptr[ptr[PyObject]]"
    return None


def helpers() -> tuple[dict, dict[str, list[tuple[str, str]]]]:
    """Exported jacpy_* definitions and scalar typedef structs of the C helpers."""
    functions: dict[str, tuple[str, list[tuple[str, str]]]] = {}
    structs: dict[str, list[tuple[str, str]]] = {}
    for path in HELPER_SOURCES:
        text = re.sub(r"/\*.*?\*/", " ", path.read_text(), flags=re.S)
        for match in re.finditer(r"typedef struct \{([^{}]*)\}\s*(\w+);", text):
            fields = []
            for decl in match.group(1).split(";"):
                decl = " ".join(decl.split())
                if not decl:
                    continue
                split = re.match(r"^(\w+(?: \w+)*?) (\w+(?:, \w+)*)$", decl)
                if not split or split.group(1) not in SCALARS:
                    fields = None
                    break
                fields += [(split.group(1), name.strip()) for name in split.group(2).split(",")]
            if fields:
                structs[match.group(2)] = fields
        pattern = r"^(?!static)((?:const )?\w+(?: \w+)*\s*\**)\s*(jacpy_\w+)\(([^)]*)\)\s*\{"
        for match in re.finditer(pattern, text, re.M):
            raw = " ".join(match.group(3).split())
            params = []
            if raw and raw != "void":
                for piece in raw.split(","):
                    split = re.match(r"^(.*?[\s\*])(\w+)$", piece.strip())
                    params.append((normal(split.group(1)), split.group(2)))
            functions[match.group(2)] = (normal(match.group(1)), params)
    return functions, structs


CALLED: set[str] = set()


def used_names(functions: dict) -> set[str]:
    names: set[str] = set()
    for root in SOURCES:
        for path in root.rglob("*.jac"):
            if path == OUTPUT:
                continue
            # Comments and docstrings mention C names without calling them.
            text = re.sub(r'"""(?:.|\n)*?"""', "", path.read_text())
            text = re.sub(r"(?m)^\s*#.*$", "", text)
            names.update(re.findall(r"\b((?:_?Py|jacpy_)[A-Za-z0-9_]*)\b", text))
            CALLED.update(re.findall(r"\b((?:_?Py|jacpy_)[A-Za-z0-9_]*)\s*\(", text))
    return {name for name in names if name in functions}


def render(functions: dict, names: set[str], pin: str, structs: dict) -> str:
    lines = [
        '"""CPython C API declarations for native Jac modules.',
        "",
        f"Generated by jac/bootstrap/python/gen_capi.py from CPython {pin} headers;",
        "do not edit. Only functions the JacPython sources call are declared.",
        '"""',
        "import from c {",
    ]
    lines += [f"    obj {name};" for name in OPAQUE]
    lines += [f"    {STRUCTS[name]}" for name in sorted(STRUCTS)]
    for name, fields in sorted(structs.items()):
        body = ", ".join(f"{field}: {SCALARS[kind]}" for kind, field in fields)
        lines.append(f"    obj {name} {{ has {body}; }}")
    failures = []
    for name in sorted(names):
        result, params = functions[name]
        returned = jac_type(name, result, None)
        rendered = []
        for index, (ctype, pname) in enumerate(params):
            jtype = jac_type(name, ctype, index)
            if jtype is None or ctype == "...":
                rendered = None
                break
            pname = pname or f"arg{index}"
            if pname in KEYWORDS:
                pname += "_"
            rendered.append(f"{pname}: {jtype}")
        if returned is None or rendered is None:
            if name in CALLED:
                failures.append(f"{name}: {result} ({', '.join(c for c, _ in params)})")
            continue
        tail = "" if returned == "None" else f" -> {returned}"
        lines.append(f"    def {name}({', '.join(rendered)}){tail};")
    lines.append("}")
    lines += ["", "glob:pub NULL: ptr[PyObject] = ptr[PyObject]();"]
    if failures:
        sys.exit("No Jac mapping for these called functions (add a C helper or a mapping):\n  " + "\n  ".join(failures))
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate cpython_api.jac")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    pin = json.loads((HERE / "sources.json").read_text())["cpython"]["version"]
    functions = declarations(headers(archive_path()))
    own, structs = helpers()
    STRUCT_NAMES.update(structs)
    functions.update(own)
    names = used_names(functions)
    unused = sorted(set(own) - names)
    if unused:
        print("C helpers no JacPython source uses:", ", ".join(unused), file=sys.stderr)
    text = format_jac(render(functions, names, pin, structs), OUTPUT)
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_text() != text:
            sys.exit("cpython_api.jac is stale; rerun jac/bootstrap/python/gen_capi.py")
        print("cpython_api.jac is current")
        return
    OUTPUT.write_text(text)
    print(f"wrote {OUTPUT.relative_to(REPO)}")


if __name__ == "__main__":
    main()
