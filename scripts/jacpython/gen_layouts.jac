"""Generate CPython's object layouts as C-layout Jac declarations.

A native Jac object-model port defines and reads CPython objects in place, so
their layouts are ABI: `PyObject`, `PyVarObject`, `PyTypeObject`, the slot
tables and the concrete object structs must match the pinned headers byte for
byte. This script writes both sides of that contract:

    jac run scripts/jacpython/gen_layouts.jac            # rewrite both files
    jac run scripts/jacpython/gen_layouts.jac --check    # fail on drift

- jaclang/runtime/python/layouts.jac: one foreign struct per layout in LAYOUTS
  (and the structs they embed by value), function-pointer slots as
  `Callable[...]` fields, pointers to layouts as `ptr[Layout]` and pointers to
  records no port reads as opaque types; plus the header constants in
  CONSTANTS that object initializers need.
- bootstrap/python/layouts_check.c: `_Static_assert`s on the offset, size and
  signedness of every generated field, each struct's size and alignment, and
  each constant's value. build.sh compiles it against the configured headers
  of every JacPython build, so a layout that drifts on any platform fails the
  build instead of corrupting objects.

Struct bodies are read from the headers of the pinned archive through a small
preprocessor that evaluates `#if` blocks for the release build every supported
platform shares (64-bit, little-endian, GIL-enabled, 30-bit digits); the
generated asserts are what make that assumption checked rather than trusted.
Constant values are read back from the configured headers of a local JacPython
build, as gen_constants.jac reads system headers.
"""
import argparse;
import re;
import shlex;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from common {
    BOOTSTRAP,
    JAC,
    RUNTIME,
    archive_texts,
    format_jac,
    pin,
    write_or_check
}

glob OUTPUT: Path = RUNTIME / "layouts.jac",
     CHECK: Path = BOOTSTRAP / "layouts_check.c",
     CAPI: Path = RUNTIME / "cpython_api.jac",
     COMMAND: str = "scripts/jacpython/gen_layouts.jac",
     # Headers the layouts are read from, in inclusion order.
     HEADERS: list[str] = [
         "Include/pytypedefs.h",
         "Include/object.h",
         "Include/cpython/object.h",
         "Include/cpython/longintrepr.h",
         "Include/cpython/tupleobject.h",
         "Include/cpython/initconfig.h"
     ],
     # Jac name and C type of each layout the object ports use. Structs a
     # layout embeds by value are emitted too; pointers to anything else are
     # opaque.
     LAYOUTS: list[tuple[str, str]] = [
         ("_object", "struct _object"),
         ("PyVarObject", "PyVarObject"),
         ("PyNumberMethods", "PyNumberMethods"),
         ("PyTypeObject", "struct _typeobject"),
         ("_PyLongValue", "_PyLongValue"),
         ("PyLongObject", "struct _longobject"),
         ("PyTupleObject", "PyTupleObject"),
         ("PyStatus", "PyStatus")
     ],
     # Header constants and layout expressions object initializers need: Jac
     # name, the C expression that defines it, and the Jac type of the C
     # field it initializes.
     CONSTANTS: list[tuple[str, str, str]] = [
         (
             "_Py_STATIC_IMMORTAL_INITIAL_REFCNT",
             "_Py_STATIC_IMMORTAL_INITIAL_REFCNT",
             "i64"
         ),
         ("Py_TPFLAGS_DEFAULT", "Py_TPFLAGS_DEFAULT", "u64"),
         ("Py_TPFLAGS_TUPLE_SUBCLASS", "Py_TPFLAGS_TUPLE_SUBCLASS", "u64"),
         ("_PyLong_FALSE_TAG", "_PyLong_FALSE_TAG", "u64"),
         ("_PyLong_TRUE_TAG", "_PyLong_TRUE_TAG", "u64"),
         (
             "PyLong_DIGITS_OFFSET",
             "offsetof(struct _longobject, long_value.ob_digit)",
             "i64"
         ),
         ("PyLong_DIGIT_SIZE", "sizeof(digit)", "i64"),
         ("_PyStatus_TYPE_OK", "_PyStatus_TYPE_OK", "u32"),
         ("_PyStatus_TYPE_ERROR", "_PyStatus_TYPE_ERROR", "u32"),
         ("PY_BUFFER_SIZE", "sizeof(Py_buffer)", "u64")
     ],
     # The configuration pyconfig.h, pyport.h and the compiler give every
     # supported release build (linux and darwin, x86_64 and aarch64).
     CONFIG: dict[str, int] = {
         "SIZEOF_VOID_P": 8,
         "PY_BIG_ENDIAN": 0,
         "PYLONG_BITS_IN_DIGIT": 30,
         "__clang__": 1,
         "__GNUC__": 4,
         "__STDC_VERSION__": 201112
     },
     # C scalar types: Jac type and whether the C type is signed.
     SCALARS: dict[str, tuple[str, bool]] = {
         "char": ("i8", True),
         "signed char": ("i8", True),
         "unsigned char": ("u8", False),
         "short": ("i16", True),
         "unsigned short": ("u16", False),
         "int": ("i32", True),
         "unsigned int": ("u32", False),
         "long": ("i64", True),
         "unsigned long": ("u64", False),
         "long long": ("i64", True),
         "unsigned long long": ("u64", False),
         "int8_t": ("i8", True),
         "uint8_t": ("u8", False),
         "int16_t": ("i16", True),
         "uint16_t": ("u16", False),
         "int32_t": ("i32", True),
         "uint32_t": ("u32", False),
         "int64_t": ("i64", True),
         "uint64_t": ("u64", False),
         "PY_INT64_T": ("i64", True),
         "PY_UINT64_T": ("u64", False),
         "size_t": ("u64", False),
         "Py_ssize_t": ("i64", True),
         "Py_hash_t": ("i64", True),
         "uintptr_t": ("u64", False),
         "intptr_t": ("i64", True),
         "double": ("f64", True),
         "float": ("f32", True)
     },
     SIZES: dict[str, int] = {
         "i8": 1,
         "u8": 1,
         "i16": 2,
         "u16": 2,
         "i32": 4,
         "u32": 4,
         "f32": 4,
         "i64": 8,
         "u64": 8,
         "f64": 8
     };

"""A header's function-pointer typedef: return and parameter C types."""
obj FunctionType {
    has returns: str,
        params: list[str];
}

"""One generated field: Jac name and type, the C member it mirrors, its
offset and size, and for integers whether the C type is signed."""
obj Field {
    has name: str,
        jac: str,
        offset: int,
        size: int,
        signed: (bool | None) = None,
        array: bool = False;
}

"""One generated struct with its computed layout."""
obj Layout {
    has name: str,
        ctype: str,
        fields: list[Field],
        size: int,
        align: int;
}

"""What the headers declare once their active `#if` branches are kept."""
obj Headers {
    has bodies: dict[str, str] = {},
        aliases: dict[str, str] = {},
        functions: dict[str, FunctionType] = {};
}

# ---------------------------------------------------------------- preprocessor
def strip_comments(text: str) -> str {
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S);
    text = re.sub(r"//[^\n]*", "", text);
    return text.replace("\\\n", " ");
}

def condition(expression: str, defines: dict[str, str]) -> bool {
    pieces: list[str] = [];
    for token in re.findall(
        r"defined\s*\(\s*\w+\s*\)|defined\s+\w+|\w+|&&|\|\||[!=<>]=|<<|>>|[!()<>+\-*]",
        expression
    ) {
        if token.startswith("defined") and token != "defined" {
            name = re.findall(r"\w+", token)[-1];
            pieces.append("1" if name in CONFIG or name in defines else "0");
        } elif token[0].isdigit() {
            pieces.append(re.sub(r"[uUlL]+$", "", token));
        } elif re.fullmatch(r"\w+", token) {
            if token in CONFIG {
                pieces.append(str(CONFIG[token]));
            } else {
                body = defines.get(token, "0").strip() or "1";
                pieces.append(body if re.fullmatch(r"\d+", body) else "0");
            }
        } else {
            words: dict[str, str] = {"&&": " and ", "||": " or ", "!": " not "};
            pieces.append(words[token] if token in words else token);
        }
    }
    try {
        return bool(eval(" ".join(pieces), {"__builtins__": {}}, {}));
    } except Exception {
        sys.exit(f"gen_layouts cannot evaluate #if {expression!r}");
    }
}

# The text of `texts` with inactive `#if` branches and directives removed, and
# object-like macros defined along the way.
def preprocess(texts: list[str], defines: dict[str, str]) -> str {
    kept: list[str] = [];
    # Each frame: (branch active, some branch already taken, parent active).
    stack: list[tuple[bool, bool, bool]] = [];
    for text in texts {
        for line in strip_comments(text).splitlines() {
            active = not stack or stack[-1][0];
            directive = re.match(r"^\s*#\s*(\w+)\s*(.*)$", line);
            if directive is None {
                if active {
                    kept.append(line);
                }
                continue;
            }
            (word, rest) = (directive.group(1), directive.group(2).strip());
            if word in ("if", "ifdef", "ifndef") {
                if word == "ifdef" {
                    taken = rest in CONFIG or rest in defines;
                } elif word == "ifndef" {
                    taken = not (rest in CONFIG or rest in defines);
                } else {
                    taken = active and condition(rest, defines);
                }
                stack.append((active and taken, active and taken, active));
            } elif word == "elif" {
                (_, done, parent) = stack.pop();
                taken = parent and not done and condition(rest, defines);
                stack.append((taken, done or taken, parent));
            } elif word == "else" {
                (_, done, parent) = stack.pop();
                stack.append((parent and not done, True, parent));
            } elif word == "endif" {
                stack.pop();
            } elif word == "define" and active {
                macro = re.match(r"^(\w+)(?!\()\s*(.*)$", rest);
                if macro is not None {
                    defines[macro.group(1)] = macro.group(2);
                }
            }
        }
    }
    return "\n".join(kept);
}

# The index just past the brace that closes the one at `start`.
def closing(text: str, start: int) -> int {
    depth = 0;
    for index in range(start, len(text)) {
        if text[index] == "{" {
            depth += 1;
        } elif text[index] == "}" {
            depth -= 1;
            if depth == 0 {
                return index + 1;
            }
        }
    }
    sys.exit("gen_layouts: unbalanced braces in the headers");
}

def read_headers(found: Headers) -> None {
    texts = archive_texts(tuple(HEADERS));
    missing = [
        h
        for h in HEADERS
        if h not in texts
    ];
    if missing {
        sys.exit(f"Not in the pinned archive: {', '.join(missing)}");
    }
    defines: dict[str, str] = {};
    text = preprocess([texts[h] for h in HEADERS], defines);
    # Expand the object-like macros struct bodies use (PyObject_HEAD).
    for (name, body) in defines.items() {
        if body.strip().endswith(";") {
            text = re.sub(rf"\b{name}\b", body, text);
        }
    }
    for hit in re.finditer(r"\b(typedef\s+)?struct\s*(\w*)\s*\{", text) {
        start = hit.end() - 1;
        end = closing(text, start);
        body = text[start + 1:end - 1];
        if hit.group(2) {
            found.bodies[f"struct {hit.group(2)}"] = body;
        }
        if hit.group(1) {
            alias = re.match(r"\s*(\w+)\s*;", text[end:]);
            if alias is not None {
                found.bodies[alias.group(1)] = body;
            }
        }
    }
    for hit in re.finditer(
        r"\btypedef\s+([\w\s\*]+?)\s*\(\s*\*\s*(\w+)\s*\)\s*\(([^;]*?)\)\s*;", text
    ) {
        params: list[str] = [];
        raw = " ".join(hit.group(3).split());
        if raw and raw != "void" {
            for piece in raw.split(",") {
                piece = piece.strip();
                # Drop a parameter name; keep the type.
                named = re.match(r"^(.*?[\s\*])(\w+)$", piece);
                if named is not None and named.group(2) not in SCALARS {
                    piece = named.group(1);
                }
                params.append(" ".join(piece.split()));
            }
        }
        found.functions[hit.group(2)] = FunctionType(
            returns=" ".join(hit.group(1).split()), params=params
        );
    }
    for hit in re.finditer(r"\btypedef\s+([\w\s]+?)\s+(\w+)\s*;", text) {
        found.aliases[hit.group(2)] = " ".join(hit.group(1).split());
    }
}

# ------------------------------------------------------------------ type model
glob:priv opaque: list[str] = [],
     emitted: dict[str, Layout] = {},
     order: list[str] = [],
     headers: Headers = Headers();

def jac_name_of(ctype: str) -> (str | None) {
    for (name, declared) in LAYOUTS {
        if declared == ctype or name == ctype {
            return name;
        }
    }
    return None;
}

# The layout a C struct type resolves to, or None for a record no port reads.
def struct_of(ctype: str) -> (str | None) {
    resolved = headers.aliases.get(ctype, ctype);
    return jac_name_of(resolved) or jac_name_of(ctype);
}

def scalar_of(ctype: str) -> (tuple[str, bool] | None) {
    seen = 0;
    while ctype not in SCALARS and ctype in headers.aliases and seen < 8 {
        ctype = headers.aliases[ctype];
        seen += 1;
    }
    return SCALARS.get(ctype);
}

def callable_of(function: FunctionType) -> str {
    params = [jac_type(p) for p in function.params];
    returns = "None" if function.returns == "void" else jac_type(function.returns);
    return f"Callable[[{', '.join(params)}], {returns}]";
}

# The Jac type of C type `ctype` in a field or a callback signature.
def jac_type(ctype: str) -> str {
    text = re.sub(r"\b(const|volatile)\b", "", ctype);
    depth = text.count("*");
    base = " ".join(text.replace("*", " ").split());
    if depth == 0 {
        if base in headers.functions {
            return callable_of(headers.functions[base]);
        }
        scalar = scalar_of(base);
        if scalar is not None {
            return scalar[0];
        }
        layout = struct_of(base);
        if layout is not None {
            require(layout);
            return layout;
        }
        sys.exit(f"gen_layouts: no Jac type for C type {ctype!r}");
    }
    if base == "void" {
        inner = "";
    } elif base == "char" {
        inner = "u8";
    } elif base == "PyObject" {
        inner = "PyObject";
    } elif base in headers.functions {
        inner = callable_of(headers.functions[base]);
    } elif scalar_of(base) is not None {
        inner = scalar_of(base)[0];
    } else {
        inner = struct_of(base) or re.sub(r"^struct\s+", "", base);
        if inner not in opaque and struct_of(base) is None {
            opaque.append(inner);
        }
    }
    result = f"ptr[{inner}]" if inner else "ptr";
    for _ in range(depth - 1) {
        result = f"ptr[{result}]";
    }
    return result;
}

def size_align(jac: str) -> tuple[int, int] {
    if jac in SIZES {
        return (SIZES[jac], SIZES[jac]);
    }
    if jac.startswith(("ptr", "Callable")) {
        return (8, 8);
    }
    layout = emitted[jac];
    return (layout.size, layout.align);
}

# The member declarations of a struct body: (C type, member name). An anonymous
# union contributes its first member, which the size asserts prove is its
# widest; an array member `T name[1]` contributes one T (see layouts.jac). A
# member of an inline enum type (`PyStatus._type`) is the enum's integer type,
# unsigned int for enumerators that are all non-negative, which the kind and
# signedness asserts prove.
def members(body: str) -> list[tuple[str, str, bool]] {
    body = body.replace("__extension__", " ");
    while True {
        hit = re.search(r"\benum\s*\{", body);
        if hit is None {
            break;
        }
        end = closing(body, hit.end() - 1);
        if re.search(r"=\s*-", body[hit.end():end - 1]) {
            sys.exit("gen_layouts: only enums without negative values are supported");
        }
        body = body[:hit.start()] + "unsigned int" + body[end:];
    }
    while True {
        hit = re.search(r"\b(union|struct)\s*\{", body);
        if hit is None {
            break;
        }
        end = closing(body, hit.end() - 1);
        tail = re.match(r"\s*(\w*)\s*;", body[end:]);
        if tail is None or tail.group(1) {
            sys.exit("gen_layouts: only anonymous nested unions are supported");
        }
        inner = members(body[hit.end():end - 1]);
        replacement = f"{inner[0][0]} {inner[0][1]}{'[1]' if inner[0][2] else ''};"
            if hit.group(1) == "union"
            else " ".join(f"{t} {n}{'[1]' if a else ''};" for (t, n, a) in inner);
        body = body[:hit.start()] + replacement + body[end + len(tail.group(0)):];
    }
    found: list[tuple[str, str, bool]] = [];
    for statement in body.split(";") {
        statement = " ".join(statement.split());
        if not statement {
            continue;
        }
        declared = re.match(
            r"^(.*?[\s\*])(\w+(?:\s*\[\s*\d+\s*\])?(?:\s*,.*)?)$", statement
        );
        if declared is None {
            sys.exit(f"gen_layouts: cannot read member {statement!r}");
        }
        base = declared.group(1).strip();
        for name in declared.group(2).split(",") {
            name = name.strip();
            array = re.match(r"^(\**\w+)\s*\[\s*(\d+)\s*\]$", name);
            if array is not None {
                if array.group(2) != "1" {
                    sys.exit(
                        f"gen_layouts: fixed array member {name} is not supported"
                    );
                }
                name = array.group(1);
            }
            stars = re.match(r"^(\**)(\w+)$", name);
            if stars is None {
                sys.exit(f"gen_layouts: cannot read member name {name!r}");
            }
            found.append((base + stars.group(1), stars.group(2), array is not None));
        }
    }
    return found;
}

def require(name: str) -> None {
    if name in emitted {
        return;
    }
    ctype = next(
        c
        for (n, c) in LAYOUTS
        if n == name
    );
    body = headers.bodies.get(ctype);
    if body is None {
        body = headers.bodies.get(headers.aliases.get(ctype, ""));
    }
    if body is None {
        sys.exit(f"gen_layouts: no definition of {ctype} in {', '.join(HEADERS)}");
    }
    # Claim the name first so a pointer back to this struct does not recurse.
    layout = Layout(name=name, ctype=ctype, fields=[], size=0, align=1);
    emitted[name] = layout;
    offset = 0;
    for (member_type, member, array) in members(body) {
        jac = jac_type(member_type);
        (size, align) = size_align(jac);
        offset = (offset + align - 1) // align * align;
        scalar = scalar_of(
            " ".join(re.sub(r"\b(const|volatile)\b", "", member_type).split())
        )
            if "*" not in member_type
            else None;
        signed = scalar[1]
            if scalar is not None and jac in SIZES and not jac.startswith("f")
            else None;
        layout.fields.append(
            Field(
                name=member,
                jac=jac,
                offset=offset,
                size=size,
                signed=signed,
                array=array
            )
        );
        offset += size;
        layout.align = max(layout.align, align);
    }
    layout.size = (offset + layout.align - 1) // layout.align * layout.align;
    order.append(name);
}

# --------------------------------------------------------------------- output
# The records cpython_api.jac declares, opaque (`obj PyObject;`) or C-layout
# (`obj PyMethodDef { ... }`); layouts.jac imports them rather than
# redeclaring a distinct type.
def capi_records -> set[str] {
    return set(re.findall(r"\bobj (\w+)\s*[;{]", CAPI.read_text()));
}

def c_type_name(layout: Layout) -> str {
    return layout.ctype;
}

def render_jac(values: dict[str, int]) -> str {
    from_capi = sorted({"PyObject"} | (set(opaque) & capi_records()));
    local = sorted(set(opaque) - set(from_capi));
    lines = [
        '"""CPython object layouts for native Jac object-model ports.',
        "",
        f"Generated by scripts/jacpython/gen_layouts.jac from CPython {pin()[
            'version'
        ]}",
        "headers; do not edit. bootstrap/python/layouts_check.c asserts every offset,",
        "size and constant against the configured headers of each JacPython build.",
        "",
        "`PyObject` stays the opaque handle of cpython_api.jac; `_object` is the",
        "layout behind it (C's `struct _object`), read by casting a handle to",
        "`ptr[_object]`. Its reference count is an anonymous union whose widest",
        "member, `ob_refcnt_full`, stands for it: the release build's 32-bit count,",
        "overflow and flags are the low, middle and high parts of that i64 on every",
        "supported (little-endian) target. A trailing C array `T name[1]`",
        "(`_PyLongValue.ob_digit`, `PyTupleObject.ob_item`) is one T field with",
        "the same offset, size and alignment: element 0 is that field, and the",
        "object's further elements follow it in memory, reached by pointer",
        "arithmetic from the field's offset exactly as C indexes past the declared",
        "bound. Pointers to records no port reads yet are opaque.",
        '"""',
        f"import from jaclang.runtime.python.cpython_api {{ {', '.join(from_capi)} }}",
        "",
        "import from c {"
    ];
    lines += [f"    obj {name};" for name in local];
    for name in order {
        layout = emitted[name];
        fields = ", ".join(f"{f.name}: {f.jac}" for f in layout.fields);
        lines.append(f"    obj {name} {{ has {fields}; }}");
    }
    lines += ["}", ""];
    for (name, _, jac) in CONSTANTS {
        lines.append(f"glob {name}: Final[{jac}] = {values[name]};");
    }
    return "\n".join(lines) + "\n";
}

# GCC's and Clang's __builtin_classify_type class of a field's Jac type.
def type_class(jac: str) -> int {
    if jac.startswith(("ptr", "Callable")) {
        return 5;
    }
    if jac in ("f32", "f64") {
        return 8;
    }
    return 1 if jac in SIZES else 12;
}

def render_check(values: dict[str, int]) -> str {
    lines = [
        "/* Generated by scripts/jacpython/gen_layouts.jac; do not edit.",
        " * Every layout and constant jaclang/runtime/python/layouts.jac declares,",
        " * asserted against the configured CPython headers. build.sh compiles this",
        " * for every JacPython build, so a layout drift fails the build. */",
        "#ifndef Py_BUILD_CORE",
        "#define Py_BUILD_CORE 1",
        "#endif",
        "#include \"Python.h\"",
        "#include \"internal/pycore_long.h\"",
        "#include <stddef.h>",
        "",
        "#define FIELD(type, field, offset, size) \\",
        "    _Static_assert(offsetof(type, field) == (offset), #type \".\" #field \" offset\"); \\",
        "    _Static_assert(sizeof(((type *)0)->field) == (size), #type \".\" #field \" size\")",
        "#define KIND(type, field, class) \\",
        "    _Static_assert(__builtin_classify_type(((type *)0)->field) == (class), \\",
        "                   #type \".\" #field \" kind\")",
        "#define SIGNED(type, field, is_signed) \\",
        "    _Static_assert(((__typeof__(((type *)0)->field))-1 < 0) == (is_signed), \\",
        "                   #type \".\" #field \" signedness\")",
        "#define LAYOUT(type, size, align) \\",
        "    _Static_assert(sizeof(type) == (size), #type \" size\"); \\",
        "    _Static_assert(_Alignof(type) == (align), #type \" alignment\")",
        "#define CONSTANT(expression, value) \\",
        "    _Static_assert((long long)(expression) == (value), #expression)",
        ""
    ];
    for name in order {
        layout = emitted[name];
        ctype = c_type_name(layout);
        lines.append(f"/* {name} */");
        for field in layout.fields {
            lines.append(
                f"FIELD({ctype}, {field.name}, {field.offset}, {field.size});"
            );
            lines.append(
                f"KIND({ctype}, {field.name}{'[0]' if field.array else ''}, {type_class(
                    field.jac
                )});"
            );
            if field.signed is not None {
                lines.append(
                    f"SIGNED({ctype}, {field.name}{'[0]' if field.array else ''}, {1
                        if field.signed
                        else 0});"
                );
            }
        }
        lines.append(f"LAYOUT({ctype}, {layout.size}, {layout.align});");
        lines.append("");
    }
    for (name, expression, _) in CONSTANTS {
        lines.append(f"CONSTANT({expression}, {values[name]}LL);");
    }
    return "\n".join(lines) + "\n";
}

# --------------------------------------------------------------- C toolchain
# The installed headers of a local JacPython build: any platform's will do,
# since the asserts hold the constants to the same values on every build.
def default_include -> Path {
    for config in sorted(
        (JAC / ".python-build/jacpython").glob(
            "*/python/install/include/python3.14/pyconfig.h"
        )
    ) {
        return config.parent;
    }
    sys.exit(
        "No configured CPython headers under jac/.python-build; run a JacPython build or pass --headers"
    );
}

def probe_flags(headers_dir: Path) -> list[str] {
    return [f"-I{headers_dir}", "-DPy_BUILD_CORE=1"];
}

# Constant values as the compiler folds them against the configured headers.
def extract(headers_dir: Path, compiler: list[str]) -> dict[str, int] {
    lines = [
        "#define Py_BUILD_CORE 1",
        "#include \"Python.h\"",
        "#include \"internal/pycore_long.h\"",
        "#include <stddef.h>"
    ];
    for (name, expression, _) in CONSTANTS {
        lines.append(
            f"const long long __jac_layout_{name} = (long long)({expression});"
        );
    }
    with tempfile.TemporaryDirectory() as scratch {
        probe = Path(scratch) / "constants.c";
        probe.write_text("\n".join(lines) + "\n");
        result = subprocess.run(
            compiler + probe_flags(headers_dir) + ["-S", "-O0", "-o", "-", str(probe)],
            capture_output=True,
            text=True
        );
    }
    if result.returncode != 0 {
        sys.exit(result.stderr);
    }
    values: dict[str, int] = {};
    current: (str | None) = None;
    for line in result.stdout.splitlines() {
        line = line.strip();
        label = re.match(r"^_?__jac_layout_(\w+):", line);
        if label {
            current = label.group(1);
            continue;
        }
        if current is None {
            continue;
        }
        data = re.match(r"^\.(?:quad|xword|8byte|dword)\s+(-?\w+)", line);
        if data {
            value = int(data.group(1), 0);
            values[current] = value - (1 << 64) if value >= (1 << 63) else value;
            current = None;
        } elif re.match(r"^\.zero\s+8", line) {
            values[current] = 0;
            current = None;
        }
    }
    missing = [
        n
        for (n, _, _) in CONSTANTS
        if n not in values
    ];
    if missing {
        sys.exit(f"gen_layouts: no value read back for {', '.join(missing)}");
    }
    return values;
}

# Compile the generated asserts against the configured headers.
def verify(check: str, headers_dir: Path, compiler: list[str]) -> None {
    with tempfile.TemporaryDirectory() as scratch {
        probe = Path(scratch) / "layouts_check.c";
        probe.write_text(check);
        result = subprocess.run(
            compiler
                + probe_flags(headers_dir)
                + ["-c", "-o", str(Path(scratch) / "layouts_check.o"), str(probe)],
            capture_output=True,
            text=True
        );
    }
    if result.returncode != 0 {
        sys.exit(f"Generated layouts do not match the headers:\n{result.stderr}");
    }
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate CPython object layouts for native Jac"
    );
    parser.add_argument("--cc", help="C compiler command");
    parser.add_argument(
        "--headers", help="directory holding a configured CPython's Python.h"
    );
    parser.set_defaults(cc="cc");
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    read_headers(headers);
    for (name, _) in LAYOUTS {
        require(name);
    }
    headers_dir = Path(args.headers) if args.headers else default_include();
    compiler = shlex.split(args.cc);
    values = extract(headers_dir, compiler);
    check = render_check(values);
    verify(check, headers_dir, compiler);
    current = write_or_check(
        OUTPUT, format_jac(render_jac(values), OUTPUT), args.check, COMMAND
    );
    current = write_or_check(CHECK, check, args.check, COMMAND) and current;
    if not current {
        sys.exit(1);
    }
}
