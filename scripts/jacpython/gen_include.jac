"""Generate the C API headers from the Jac definitions.

Every header under Include/ (the public ones a C extension compiles against
through Python.h, Include/cpython/ and Include/internal/) is checked in as
jac/bootstrap/python/generated/Include/<path>.in. cpython-sources.txt marks
each one `generated`, so both builds stage these copies where the archive's
were (a header the archive would supply fails the build), and `make install`
puts them where `python3-config --includes` points:

    jac run scripts/jacpython/gen_include.jac            # rewrite them
    jac run scripts/jacpython/gen_include.jac --check    # fail on drift

The Jac definitions own what the runtime defines and reads in place:

- Records. A struct a header defines for a record of
  jaclang/runtime/python/layouts.jac (or a C-layout record of cpython_api.jac
  that gen_layouts.jac maps) has that record's members, in its order and of
  its types. A struct that disagrees is rewritten from the record: a member
  the record still has keeps its declaration (its typedef, const and
  comment), any other member is declared from its Jac type. A struct with
  preprocessor branches, a union, a nested struct or bit-fields, or defined
  more than once, is not rewritten: the script names it and stops. The C
  spelling gen_layouts.jac gives the records (C_ARRAYS, C_MEMBERS) must be
  the headers'.
- Constants. A header's `#define NAME <integer>` for a constant layouts.jac
  declares carries the Jac value, written in the literal's own notation
  (decimal, hexadecimal or `1 << n`) and suffix. A constant whose definition
  is an expression of other macros, or differs between configurations, keeps
  its text; bootstrap/python/layouts_check.c asserts its value.
- Conditional structs. A record's struct with preprocessor branches, or
  defined under several conditions, is written from its body in
  capi_table.jac's CONDITIONAL_STRUCTS; its release-build branches are then
  checked against the record like any other struct.
- C API declarations. Each `PyAPI_FUNC` and `PyAPI_DATA` declaration, and
  each plain `extern` function or variable of an internal header, is an entry
  of capi_table.jac: its header, the `#if` condition it sits under and its C
  text. A declaration whose entry has the same text keeps its own layout; one
  whose entry changed is written from the entry, one without an entry is
  removed, and an entry without a declaration is added at the end of its
  header under its condition. gen_capi.jac reads the same table.
- Global strings. The statically allocated strings (`_Py_ID`, `_Py_STR`)
  are global_strings.jac's tables. The four blocks
  Tools/build/generate_global_objects.py wrote from a scan of the C sources
  (the `_Py_global_strings` struct, the runtime initializers, the interning
  and refcount checks) are written from them.

Everything else in a header (macros, static inline functions, comments) is
the checked-in text, which is CPython's for a header no Jac definition has
changed. The opcode tables are gen_opcode_meta.jac's. build_jacpython.zig
compiles layouts_check.c against the staged headers in every JacPython
build, so a header that disagrees with the Jac layouts fails the build.
"""
import argparse;
import re;
import sys;
import from pathlib { Path }
import from common { RUNTIME, generated_copy, generated_paths }
import from gen_layouts {
    CONSTANTS,
    JAC_KEYWORDS,
    LAYOUTS,
    PRIVATE_LAYOUTS,
    SIZES,
    Field,
    Layout,
    jac_constants,
    jac_layouts,
    jac_records,
    normal_type,
    split_top
}
import from gen_capi { INTERNAL_DATA, INTERNAL_EXTERN }
import from capi_table { CONDITIONAL_STRUCTS, DECLARATIONS }
import from global_strings { IDENTIFIERS, STRINGS }

glob COMMAND: str = "scripts/jacpython/gen_include.jac",
     LAYOUTS_JAC: Path = RUNTIME / "layouts.jac",
     CAPI_JAC: Path = RUNTIME / "cpython_api.jac",
     # Generated headers another script writes.
     OWNED_ELSEWHERE: set[str] = {
         "Include/opcode_ids.h",
         "Include/internal/pycore_opcode_metadata.h",
         "Include/internal/pycore_uop_ids.h",
         "Include/internal/pycore_uop_metadata.h"
     },
     # The typedef a header gives a record's struct type (struct _object is
     # PyObject), filled from the headers.
     TYPEDEFS: dict[str, str] = {},
     # The C type a member added from its Jac type is declared with.
     C_SCALARS: dict[str, str] = {
         "i8": "int8_t",
         "u8": "uint8_t",
         "i16": "int16_t",
         "u16": "uint16_t",
         "i32": "int",
         "u32": "uint32_t",
         "i64": "Py_ssize_t",
         "u64": "uint64_t",
         "f32": "float",
         "f64": "double"
     },
     # Headers the record structs are read from, in inclusion order.
     HEADERS: list[str] = [
         "Include/pytypedefs.h",
         "Include/object.h",
         "Include/cpython/object.h",
         "Include/cpython/longintrepr.h",
         "Include/cpython/tupleobject.h",
         "Include/cpython/listobject.h",
         "Include/cpython/code.h",
         "Include/cpython/bytesobject.h",
         "Include/cpython/bytearrayobject.h",
         "Include/cpython/initconfig.h",
         "Include/pycapsule.h",
         "Include/descrobject.h",
         "Include/cpython/descrobject.h",
         "Include/internal/pycore_descrobject.h",
         "Include/cpython/cellobject.h",
         "Include/sliceobject.h",
         "Include/cpython/pyerrors.h",
         "Include/internal/pycore_range.h",
         "Include/internal/pycore_tuple.h",
         "Include/internal/pycore_list.h",
         "Include/cpython/setobject.h",
         "Include/cpython/dictobject.h",
         "Include/internal/pycore_dict.h",
         "Include/cpython/methodobject.h",
         "Include/cpython/weakrefobject.h",
         "Include/moduleobject.h",
         "Include/internal/pycore_moduleobject.h",
         "Include/internal/pycore_freelist_state.h",
         "Include/datetime.h",
         "Include/pybuffer.h",
         "Include/cpython/memoryobject.h",
         "Include/cpython/floatobject.h",
         "Include/cpython/complexobject.h",
         "Include/cpython/classobject.h",
         "Include/structseq.h",
         "Include/cpython/pymem.h",
         "Include/cpython/objimpl.h",
         "Include/internal/pycore_llist.h",
         "Include/internal/pycore_obmalloc.h",
         "Include/internal/pycore_gc.h",
         "Include/internal/pycore_interp_structs.h",
         "Include/cpython/modsupport.h",
         "Include/internal/pycore_structs.h",
         "Include/internal/pycore_hamt.h",
         "Include/cpython/context.h",
         "Include/internal/pycore_context.h",
         "Include/internal/pycore_hashtable.h",
         "Include/internal/pycore_initconfig.h",
         "Include/cpython/pylifecycle.h",
         "Include/internal/pycore_crossinterp.h",
         "Include/internal/pycore_asdl.h",
         "Include/internal/pycore_ast_state.h",
         "Include/cpython/import.h",
         "Include/internal/pycore_import.h"
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
         "Py_uhash_t": ("u64", False),
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
         "PyTime_t": ("i64", True),
         "size_t": ("u64", False),
         "Py_ssize_t": ("i64", True),
         "Py_hash_t": ("i64", True),
         "uintptr_t": ("u64", False),
         # pycore_obmalloc.h's `#define uint pymem_uint` (unsigned int).
         "uint": ("u32", False),
         "pymem_uint": ("u32", False),
         "intptr_t": ("i64", True),
         # wchar_t is 4 bytes on every supported platform; the runtime reads
         # wide strings as i32 code units.
         "wchar_t": ("i32", True),
         "double": ("f64", True),
         "float": ("f32", True),
         # C's bool: one unsigned byte, which the asserts hold to kind 4.
         "bool": ("u8", False),
         "_Bool": ("u8", False),
         # An enum with a negative enumerator is an int.
         "PySendResult": ("i32", True),
         "_PyXI_errcode": ("i32", True)
     };

"""One header struct to bring in line with its Jac record."""
obj Rewrite {
    has name: str,
        ctype: str,
        fields: list[tuple[str, str]];
}

# ---------------------------------------------------------- the header records
# The C name of a Jac field: a field named after a Jac keyword takes a
# trailing underscore in Jac.
def c_name(field: str) -> str {
    if field.endswith("_") and field[:-1] in JAC_KEYWORDS {
        return field[:-1];
    }
    return field;
}

# The C declaration of `declarator` (a member name, or "" for a parameter)
# with Jac type `jt`.
def c_decl(jt: str, declarator: str) -> str {
    if jt.startswith("Callable[") {
        inner = split_top(jt[len("Callable["):-1]);
        params = [
            c_decl(normal_type(p), "") for p in split_top(inner[0].strip()[1:-1])
        ];
        returns = normal_type(inner[1]);
        target = f"(*{declarator})({', '.join(params) or 'void'})";
        return "void " + target if returns == "None" else c_decl(returns, target);
    }
    if jt == "ptr" {
        return f"void *{declarator}";
    }
    if jt == "ptr[u8]" {
        return f"char *{declarator}";
    }
    if jt.startswith("ptr[") {
        return c_decl(jt[4:-1], "*" + declarator);
    }
    if jt in C_SCALARS {
        base = C_SCALARS[jt];
    } else {
        ctypes = {jac: c for (jac, c) in LAYOUTS};
        base = TYPEDEFS.get(ctypes.get(jt, jt), ctypes.get(jt, jt));
    }
    return f"{base} {declarator}" if declarator else base;
}

# The members one header statement declares, as (Jac field, Jac type), the
# way gen_layouts.jac names them: an array `T x[N]` is x, x_1 ... x_<N-1>.
def statement_fields(statement: str, heads: dict[str, str]) -> list[tuple[str, str]] {
    text = strip_comments(statement);
    for _ in range(8) {
        expanded = text;
        for (name, body) in heads.items() {
            expanded = re.sub(rf"\b{name}\b", body, expanded);
        }
        if expanded == text {
            break;
        }
        text = expanded;
    }
    if not text.strip() {
        return [];
    }
    fields: list[tuple[str, str]] = [];
    for (ctype, member, count) in members(text) {
        jt = jac_type(ctype);
        base = f"{member}_" if member in JAC_KEYWORDS else member;
        for index in range(max(count, 1)) {
            fields.append((base if index == 0 else f"{base}_{index}", jt));
        }
    }
    return fields;
}

# The statements of a struct body, each with the comments before it and the
# comment that ends its line; the text after the last one. A line holding only
# a member macro (PyObject_HEAD) is a statement of its own.
def statements(body: str, heads: dict[str, str]) -> tuple[list[str], str] {
    found: list[str] = [];
    start = 0;
    index = 0;
    while index < len(body) {
        line = re.match(r"[ \t]*(\w+)[ \t]*(?=\n)", body[index:]);
        if line
            and line.group(1) in heads
            and (index == 0 or body[index - 1] == "\n") {
            end = index + len(line.group(0));
            found.append(body[start:end]);
            start = end;
            index = end;
            continue;
        }
        if body.startswith("/*", index) {
            index = body.index("*/", index) + 2;
            continue;
        }
        if body.startswith("//", index) {
            index = body.find("\n", index)
                if body.find("\n", index) >= 0
                else len(body);
            continue;
        }
        if body[index] == ";" {
            trailing = re.match(r"[ \t]*(?:/\*.*?\*/|//[^\n]*)?", body[index + 1:]);
            end = index + 1 + (len(trailing.group(0)) if trailing else 0);
            found.append(body[start:end]);
            start = end;
            index = end;
            continue;
        }
        index += 1;
    }
    return (found, body[start:]);
}

# Where `ctype` is defined in `text`: (index of its `{`, index past its `}`),
# one per definition.
def definitions(text: str, ctype: str) -> list[tuple[int, int]] {
    spans: list[tuple[int, int]] = [];
    if ctype.startswith("struct ") {
        pattern = r"\bstruct\s+" + re.escape(ctype[7:]) + r"\s*\{";
        for hit in re.finditer(pattern, text) {
            spans.append((hit.end() - 1, closing(text, hit.end() - 1)));
        }
        return spans;
    }
    for hit in re.finditer(r"\btypedef\s+struct\s*\w*\s*\{", text) {
        end = closing(text, hit.end() - 1);
        if re.match(rf"\s*{ctype}\s*;", text[end:]) {
            spans.append((hit.end() - 1, end));
        }
    }
    return spans;
}

# A struct body declared from `fields`, keeping each statement of `body`
# that still declares the same members.
def rewritten_body(
    label: str, body: str, fields: list[tuple[str, str]], heads: dict[str, str]
) -> str {
    plain = strip_comments(body);
    if re.search(r"(?m)^\s*#", body) or re.search(r"\b(union|struct)\s*\{", plain) {
        sys.exit(
            f"gen_include: {label} has preprocessor branches or nested records; change it by hand to match its Jac record"
        );
    }
    if re.search(r"\w\s*:\s*\d", plain) {
        sys.exit(f"gen_include: {label} has bit-fields; change it by hand");
    }
    (parts, tail) = statements(body, heads);
    declared = [(part, statement_fields(part, heads)) for part in parts];
    indent = "    ";
    for part in parts {
        lead = re.search(r"\n([ \t]+)\S[^\n]*$", "\n" + part.rstrip());
        if lead {
            indent = lead.group(1);
            break;
        }
    }
    out: list[str] = [];
    index = 0;
    while index < len(fields) {
        kept = False;
        for (part, names) in declared {
            if names and fields[index:index + len(names)] == names {
                out.append(part);
                index += len(names);
                kept = True;
                break;
            }
        }
        if not kept {
            (name, jt) = fields[index];
            out.append(f"\n{indent}{c_decl(jt, c_name(name))};");
            index += 1;
        }
    }
    return "".join(out) + (tail if tail.strip() else "\n");
}

# ------------------------------------------------------------- header constants
glob LITERAL: re.Pattern = re.compile(r"\b(0[xX][0-9a-fA-F]+|\d+)([uUlL]*)\b");

# The value of a C integer constant expression made of literals, or None when
# it names anything else.
def literal_value(expression: str) -> (int | None) {
    folded = LITERAL.sub(literal_digits, expression);
    if not re.fullmatch(r"[\d\s()<|+\-~]+", folded) or not re.search(r"\d", folded) {
        return None;
    }
    try {
        return int(eval(folded, {"__builtins__": {}}, {}));
    } except Exception {
        return None;
    }
}

def literal_digits(hit: re.Match) -> str {
    return str(int(hit.group(1), 0));
}

# `expression` rewritten to evaluate to `value`, in its own notation.
def respelled(expression: str, value: int) -> str {
    literals = list(LITERAL.finditer(expression));
    if "<<" in expression
        and len(literals) == 2
        and value > 0
        and value & (value - 1) == 0 {
        shift = literals[1];
        return expression[:shift.start()]
            + str(value.bit_length() - 1)
            + expression[shift.end():];
    }
    if len(literals) != 1 or "<<" in expression {
        first = literals[0];
        return f"{hex(value) if value >= 0 else value}{first.group(2)}";
    }
    only = literals[0];
    digits = only.group(1);
    if digits.lower().startswith("0x") and value >= 0 {
        width = len(digits) - 2;
        text = f"{value:0{width}x}";
        if digits[2:] != digits[2:].lower() {
            text = text.upper();
        }
        spelled = digits[:2] + text;
    } else {
        spelled = str(value);
    }
    return expression[:only.start()]
        + spelled
        + only.group(2)
        + expression[only.end():];
}


# ---------------------------------------------------------- the header reader
"""A header's function-pointer typedef: return and parameter C types."""
obj FunctionType {
    has returns: str,
        params: list[str];
}

"""What the headers declare once their active `#if` branches are kept."""
obj Headers {
    has macros: dict[str, str] = {},
        bodies: dict[str, str] = {},
        aliases: dict[str, str] = {},
        functions: dict[str, FunctionType] = {};
}

# ---------------------------------------------------------------- preprocessor
def strip_comments(text: str) -> str {
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S);
    text = re.sub(r"//[^\n]*", "", text);
    # An attribute (PyBytesObject's ob_shash); it does not change the layout.
    text = re.sub(r"\bPy_DEPRECATED\([^)]*\)", "", text);
    return text.replace("\\\n", " ");
}

def condition(expression: str, defines: dict[str, str]) -> bool {
    pieces: list[str] = [];
    for token in re.findall(
        r"defined\s*\(\s*\w+\s*\)|defined\s+\w+|\w+|&&|\|\||[!=<>]=|<<|>>|[!()<>+\-*&|^~]",
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
        sys.exit(f"gen_include cannot evaluate #if {expression!r}");
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
    sys.exit("gen_include: unbalanced braces in the headers");
}

# The parameter C types of a function declarator's parameter list, with any
# parameter names dropped.
def parameter_types(raw: str) -> list[str] {
    params: list[str] = [];
    raw = " ".join(raw.split());
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
    return params;
}

# `[NAME]` with NAME an integer macro (datetime.h's
# `data[_PyDateTime_DATETIME_DATASIZE]`) as the literal it defines.
def array_bounds(text: str, defines: dict[str, str]) -> str {
    pieces: list[str] = [];
    last = 0;
    for hit in re.finditer(r"\[\s*([A-Za-z_]\w*)\s*\]", text) {
        body = defines.get(hit.group(1), "").strip();
        if re.fullmatch(r"\d+", body) {
            pieces.append(text[last:hit.start()] + f"[{body}]");
            last = hit.end();
        }
    }
    pieces.append(text[last:]);
    return "".join(pieces);
}

# The struct bodies, macros, typedefs and function types of HEADERS, read in
# inclusion order with their inactive `#if` branches dropped.
def read_headers(found: Headers, texts: dict[str, str]) {
    defines: dict[str, str] = {};
    text = preprocess([texts[h] for h in HEADERS], defines);
    found.macros = dict(defines);
    # Expand the object-like macros struct bodies use (PyObject_HEAD), and the
    # ones those expand to (datetime.h's _PyTZINFO_HEAD names PyObject_HEAD).
    heads = head_macros(defines);
    for _ in range(8) {
        expanded = text;
        for (name, body) in heads.items() {
            expanded = re.sub(rf"\b{name}\b", body, expanded);
        }
        if expanded == text {
            break;
        }
        text = expanded;
    }
    text = array_bounds(text, defines);
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
        found.functions[hit.group(2)] = FunctionType(
            returns=" ".join(hit.group(1).split()), params=parameter_types(hit.group(3))
        );
    }
    for hit in re.finditer(r"\btypedef\s+([\w\s]+?)\s+(\w+)\s*;", text) {
        found.aliases[hit.group(2)] = " ".join(hit.group(1).split());
    }
}

def head_macros(defines: dict[str, str]) -> dict[str, str] {
    return {
        name: body
        for (name, body) in defines.items()
        if body.strip().endswith(";")
    };
}

# ------------------------------------------------------------------ type model
glob:priv emitted: dict[str, Layout] = {},
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
            read_layout(layout);
            return layout;
        }
        sys.exit(f"gen_include: no Jac type for C type {ctype!r}");
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

# The array declarator of an element count ("" for a scalar member).
def bounds(count: int) -> str {
    return "[" + str(count) + "]" if count else "";
}

# The name a function-pointer member's signature is recorded under in
# `headers.functions`, as if the header had a typedef for it.
def member_function(returns: str, raw: str) -> str {
    function = FunctionType(
        returns=" ".join(returns.split()), params=parameter_types(raw)
    );
    signature = function.returns + "_" + "_".join(function.params);
    name = "__member_fn_" + re.sub(r"\W+", "_", signature.replace("*", "P"));
    headers.functions[name] = function;
    return name;
}

# The member declarations of a struct body: (C type, member name, element
# count), the count 0 for a member that is not an array. An anonymous union
# contributes its first member, which the size asserts prove is its widest; an
# array member `T name[N]` is N elements of T (see layouts.jac). A member of
# an inline enum type (`PyStatus._type`) is the enum's integer type, unsigned
# int for enumerators that are all non-negative, which the kind and signedness
# asserts prove. A function-pointer member (`PyObject *(*f)(int)`) is typed as
# its signature.
glob union_designators: dict[str, str] = {};

def members(body: str) -> list[tuple[str, str, int]] {
    body = body.replace("__extension__", " ");
    while True {
        hit = re.search(r"\benum\s*\{", body);
        if hit is None {
            break;
        }
        end = closing(body, hit.end() - 1);
        if re.search(r"=\s*-", body[hit.end():end - 1]) {
            sys.exit("gen_include: only enums without negative values are supported");
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
        if tail is None or (tail.group(1) and hit.group(1) != "union") {
            sys.exit("gen_include: only anonymous nested structs are supported");
        }
        inner = members(body[hit.end():end - 1]);
        replacement = f"{inner[0][0]} {inner[0][1]}{bounds(inner[0][2])};"
            if hit.group(1) == "union"
            else " ".join(f"{t} {n}{bounds(a)};" for (t, n, a) in inner);
        if tail.group(1) {
            # A named union (pool_header's `ref`) is likewise one field of its
            # first member's type, under the union's name; the asserts reach
            # it through that member.
            union_designators[tail.group(1)] = f"{tail.group(1)}.{inner[0][1]}";
            replacement = f"{inner[0][0]} {tail.group(1)}{bounds(inner[0][2])};";
        }
        body = body[:hit.start()] + replacement + body[end + len(tail.group(0)):];
    }
    found: list[tuple[str, str, int]] = [];
    for statement in body.split(";") {
        statement = " ".join(statement.split());
        if not statement {
            continue;
        }
        pointer = re.match(r"^(.*?)\(\s*\*\s*(\w+)\s*\)\s*\((.*)\)$", statement);
        if pointer is not None {
            found.append(
                (
                    member_function(pointer.group(1), pointer.group(3)),
                    pointer.group(2),
                    0
                )
            );
            continue;
        }
        declared = re.match(
            r"^(.*?[\s\*])(\w+(?:\s*\[\s*\d+\s*\])?(?:\s*,.*)?)$", statement
        );
        if declared is None {
            sys.exit(f"gen_include: cannot read member {statement!r}");
        }
        # The stars before the first name are its declarator's, as the stars
        # of every later name are (`PyObject *start, *stop, *step;`).
        declared_type = declared.group(1).strip();
        lead = "*" * (len(declared_type) - len(declared_type.rstrip("*")));
        base = declared_type.rstrip("*").strip() + " ";
        first = True;
        for name in declared.group(2).split(",") {
            name = (lead if first else "") + name.strip();
            first = False;
            array = re.match(r"^(\**\w+)\s*\[\s*(\d+)\s*\]$", name);
            count = 0;
            if array is not None {
                count = int(array.group(2));
                name = array.group(1);
            }
            stars = re.match(r"^(\**)(\w+)$", name);
            if stars is None {
                sys.exit(f"gen_include: cannot read member name {name!r}");
            }
            found.append((base + stars.group(1), stars.group(2), count));
        }
    }
    return found;
}


# The layout of LAYOUTS record `name` as its header struct declares it: each
# member as gen_layouts.jac names the record's fields (an array `T x[N]` is x,
# x_1 ... x_<N-1>, a member named after a Jac keyword takes a trailing
# underscore) with its C designator. A record no header defines is skipped.
def read_layout(name: str) -> None {
    if name in emitted or name in PRIVATE_LAYOUTS {
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
        sys.exit(f"gen_include: no definition of {ctype} in {', '.join(HEADERS)}");
    }
    # Claim the name first so a pointer back to this struct does not recurse.
    layout = Layout(name=name, ctype=ctype, fields=[], size=0, align=1);
    emitted[name] = layout;
    offset = 0;
    union_designators.clear();
    for (member_type, member, count) in members(body) {
        jac = jac_type(member_type);
        (size, align) = size_align(jac);
        offset = (offset + align - 1) // align * align;
        for index in range(max(count, 1)) {
            jac_member = f"{member}_" if member in JAC_KEYWORDS else member;
            layout.fields.append(
                Field(
                    name=jac_member if index == 0 else f"{jac_member}_{index}",
                    jac=jac,
                    offset=offset,
                    size=size,
                    array=count == 1,
                    member=f"{member}[{index}]"
                        if count > 1
                        else (
                            union_designators.get(member)
                            or (member if jac_member != member else "")
                        )
                )
            );
            offset += size;
        }
        layout.align = max(layout.align, align);
    }
    layout.size = (offset + layout.align - 1) // layout.align * layout.align;
}

# The layouts the headers define, read from `texts`, and what else the headers
# declare.
def header_layouts(texts: dict[str, str]) -> tuple[dict[str, Layout], Headers] {
    if not emitted {
        read_headers(headers, texts);
        for (name, _) in LAYOUTS {
            read_layout(name);
        }
    }
    return (emitted, headers);
}

# ------------------------------------------------------------ C API declarations
glob API_DECLARATION: re.Pattern = re.compile(
         r"(?:\bPy_DEPRECATED\([^()]*\)\s*|\bextern\s+)?\bPyAPI_(?:FUNC|DATA)\((?:[^()]|\([^()]*\))*\)[^;{}#]*;"
     ),
     API_PREFIX: re.Pattern = re.compile(
         r"^(?:Py_DEPRECATED\([^()]*\)\s*|extern\s+)?PyAPI_(?:FUNC|DATA)\((?:[^()]|\([^()]*\))*\)\s*"
     );

"""One declaration of a header: its span in the text, its condition and its
C text with comments dropped and white space collapsed."""
obj Site {
    has start: int,
        end: int,
        guard: str,
        text: str;
}

def blanked(hit: re.Match) -> str {
    return re.sub(r"[^\n]", " ", hit.group(0));
}

# `text` with every comment turned to spaces, so offsets stay the text's.
def blank_comments(text: str) -> str {
    return re.sub(r"/\*.*?\*/|//[^\n]*", blanked, text, flags=re.S);
}

# The name a declaration's C text declares.
def declared_name(text: str) -> str {
    prefix = API_PREFIX.match(text);
    rest = text[prefix.end():] if prefix else re.sub(r"^\s*extern\s+", "", text);
    # A plain declarator (`name(`, `name[`, `name;`) or a function pointer's
    # (`(*name)`), whichever comes first.
    hits = [
        hit
        for hit in [
            re.search(r"\b([A-Za-z_]\w*)\s*[(\[;]", rest),
            re.search(r"\(\s*\*\s*([A-Za-z_]\w*)\s*\)", rest)
        ]
        if hit is not None
    ];
    if not hits {
        sys.exit(f"gen_include: no name in the declaration {text!r}");
    }
    return min(hits, key=re.Match.start).group(1);
}

# Whether `offset` lies on a preprocessor line (a macro body included, its
# continuation lines too).
def in_directive(text: str, offset: int) -> bool {
    start = text.rfind("\n", 0, offset) + 1;
    while start > 1 and text[start - 2] == "\\" {
        start = text.rfind("\n", 0, start - 1) + 1;
    }
    return text[start:offset].lstrip().startswith("#");
}

# A condition as one operand of `&&`.
def operand(clause: str) -> str {
    if re.fullmatch(r"!?(?:defined\(\w+\)|\w+)", clause) {
        return clause;
    }
    return f"({clause})";
}

def negated(clause: str) -> str {
    if re.fullmatch(r"!defined\(\w+\)", clause) {
        return clause[1:];
    }
    if re.fullmatch(r"defined\(\w+\)", clause) {
        return "!" + clause;
    }
    return f"!({clause})";
}

# The condition each offset of `offsets` sits under: the conjunction of the
# branches of every enclosing `#if` but an include guard (`#ifndef X` right
# before `#define X`).
def guards(text: str, offsets: list[int]) -> dict[int, str] {
    found: dict[int, str] = {};
    # Each frame: (conditions of the branches before, the current branch's
    # condition or "" for `#else`, whether the frame is the include guard).
    frames: list[tuple[list[str], str, bool]] = [];
    pending = sorted(offsets);
    position = 0;
    lines = text.split("\n");
    index = 0;
    while index < len(lines) {
        logical = lines[index];
        length = len(lines[index]) + 1;
        while logical.endswith("\\") and index + 1 < len(lines) {
            index += 1;
            logical = logical[:-1] + " " + lines[index];
            length += len(lines[index]) + 1;
        }
        while pending and pending[0] < position + length {
            parts: list[str] = [];
            for (before, current, guard) in frames {
                if guard {
                    continue;
                }
                parts += [negated(c) for c in before];
                if current {
                    parts.append(current);
                }
            }
            found[pending.pop(0)] = " && ".join(operand(p) for p in parts);
        }
        directive = re.match(r"^\s*#\s*(\w+)\s*(.*?)\s*$", logical);
        if directive {
            (word, rest) = (directive.group(1), " ".join(directive.group(2).split()));
            if word == "ifdef" {
                frames.append(([], f"defined({rest})", False));
            } elif word == "ifndef" {
                guard = index + 1 < len(lines)
                    and re.match(
                        rf"^\s*#\s*define\s+{re.escape(rest)}\b", lines[index + 1]
                    )
                        is not None;
                frames.append(([], f"!defined({rest})", guard));
            } elif word == "if" {
                frames.append(([], rest, False));
            } elif word in ("elif", "else") and frames {
                (before, current, guard) = frames.pop();
                frames.append(
                    (before + [current], rest if word == "elif" else "", guard)
                );
            } elif word == "endif" and frames {
                frames.pop();
            }
        }
        position += length;
        index += 1;
    }
    return found;
}

# The C API declarations of one header, in text order: PyAPI_FUNC and
# PyAPI_DATA statements, and in an internal header the plain `extern`
# functions and variables gen_capi.jac reads.
def declaration_sites(path: str, text: str) -> list[Site] {
    plain = blank_comments(text);
    spans: list[tuple[int, int]] = [];
    for hit in API_DECLARATION.finditer(plain) {
        if not in_directive(plain, hit.start()) {
            spans.append((hit.start(), hit.end()));
        }
    }
    if path.startswith("Include/internal/") {
        found = list(re.finditer(INTERNAL_EXTERN, plain, re.M | re.S))
            + list(re.finditer(INTERNAL_DATA, plain, re.M));
        for hit in found {
            start = hit.start() + len(hit.group(0)) - len(hit.group(0).lstrip());
            if '"' in hit.group(0) or in_directive(plain, start) {
                continue;
            }
            if any(s <= start < e for (s, e) in spans) {
                continue;
            }
            spans.append((start, hit.end()));
        }
    }
    spans.sort();
    conditions = guards(plain, [s for (s, _) in spans]);
    return [
        Site(start=s, end=e, guard=conditions[s], text=" ".join(plain[s:e].split()))
        for (s, e) in spans
    ];
}

# `text` with its declarations brought in line with the table's entries for
# `path`; returns the text and the number of declarations changed, removed
# and added.
def declare(path: str, text: str, entries: list[tuple[str, str]]) -> tuple[str, int] {
    wanted: dict[tuple[str, str], list[str]] = {};
    for (guard, c_text) in entries {
        wanted.setdefault((declared_name(c_text), guard), []).append(c_text);
    }
    edits: list[tuple[int, int, str]] = [];
    for site in declaration_sites(path, text) {
        key = (declared_name(site.text), site.guard);
        if wanted.get(key) {
            declared_text = wanted[key].pop(0);
            if declared_text != site.text {
                edits.append((site.start, site.end, declared_text));
            }
            continue;
        }
        # No declared_text: drop the declaration, with its line when it has one alone.
        (start, end) = (site.start, site.end);
        line_start = text.rfind("\n", 0, start) + 1;
        line_end = text.find("\n", end);
        line_end = len(text) if line_end < 0 else line_end;
        if not text[line_start:start].strip() and not text[end:line_end].strip() {
            (start, end) = (line_start, min(line_end + 1, len(text)));
        }
        edits.append((start, end, ""));
    }
    added: list[str] = [];
    for ((_, guard), texts) in wanted.items() {
        for c_text in texts {
            added.append(
                f"#if {guard}\n{c_text}\n#endif\n" if guard else c_text + "\n"
            );
        }
    }
    for (start, end, replacement) in sorted(edits, reverse=True) {
        text = text[:start] + replacement + text[end:];
    }
    if added {
        # Before the closing `extern "C"` block and include guard.
        tail = re.search(r"\n#ifdef __cplusplus\n\}\n#endif\n", text);
        if tail is None {
            tail = re.search(r"\n#endif[^\n]*\n\s*$", text);
        }
        at = tail.start() + 1 if tail else len(text);
        text = text[:at] + "".join(added) + text[at:];
    }
    return (text, len(edits) + len(added));
}

# ---------------------------------------------------------------- global strings
glob GENERATED_START: str = "/* The following is auto-generated by Tools/build/generate_global_objects.py. */",
     GENERATED_END: str = "/* End auto-generated code */",
     STRINGS_HEADER: str = "Include/internal/pycore_global_strings.h",
     INIT_HEADER: str = "Include/internal/pycore_runtime_init_generated.h",
     INTERN_HEADER: str = "Include/internal/pycore_unicodeobject_generated.h",
     FINI_HEADER: str = "Include/internal/pycore_global_objects_fini_generated.h",
     RUNTIME_STRUCTS: str = "Include/internal/pycore_runtime_structs.h",
     # The static objects the runtime initializer does not list, which the
     # debug build's refcount check covers too.
     OTHER_STATIC_OBJECTS: list[str] = [
         "(PyObject *)&_Py_SINGLETON(bytes_empty)",
         "(PyObject *)&_Py_SINGLETON(tuple_empty)",
         "(PyObject *)&_Py_SINGLETON(hamt_bitmap_node_empty)",
         "(PyObject *)&_Py_INTERP_SINGLETON(interp, hamt_empty)",
         "(PyObject *)&_Py_SINGLETON(context_token_missing)"
     ];

# `text` with the lines between its generated-block markers replaced by
# `block` (each line ending in a newline).
def regenerated(text: str, block: str) -> str {
    lines = text.rstrip().splitlines();
    start = lines.index(GENERATED_START);
    end = lines.index(GENERATED_END);
    return "\n".join(lines[:start])
        + "\n"
        + GENERATED_START
        + "\n"
        + block
        + GENERATED_END
        + "\n"
        + "\n".join(lines[end + 1:])
        + "\n";
}

# A `#define NAME { ... }` initializer whose lines continue with backslashes.
def initializer(name: str, items: list[str]) -> str {
    return f"#define {name} {{ \\\n"
        + "".join(f"    {item} \\\n" for item in items)
        + "}\n";
}

def integer_macro(text: str, name: str) -> int {
    hit = re.search(rf"(?m)^#define {name}\s+(\d+)\s*$", text);
    if hit is None {
        sys.exit(f"gen_include: {RUNTIME_STRUCTS} defines no {name}");
    }
    return int(hit.group(1));
}

# The four headers' generated blocks, from global_strings.jac's tables.
def write_global_strings(updated: dict[str, str]) -> int {
    for name in IDENTIFIERS {
        if not name.isidentifier() {
            sys.exit(f"gen_include: global string identifier {name!r} is not a C name");
        }
    }
    by_name = sorted(STRINGS);
    by_value = [
        (name, value) for (value, name) in sorted((v, n) for (n, v) in STRINGS)
    ];
    identifiers = sorted(IDENTIFIERS);
    positive = integer_macro(updated[RUNTIME_STRUCTS], "_PY_NSMALLPOSINTS");
    negative = integer_macro(updated[RUNTIME_STRUCTS], "_PY_NSMALLNEGINTS");
    blocks: dict[str, str] = {};
    blocks[STRINGS_HEADER] = "struct _Py_global_strings {\n    struct {\n"
        + "".join(
            f"        STRUCT_FOR_STR({name}, \"{value}\")\n"
            for (name, value) in by_name
        )
        + "    } literals;\n\n    struct {\n"
        + "".join(f"        STRUCT_FOR_ID({name})\n" for name in identifiers)
        + "    } identifiers;\n"
        + "    struct {\n        PyASCIIObject _ascii;\n        uint8_t _data[2];\n    } ascii[128];\n"
        + "    struct {\n        PyCompactUnicodeObject _latin1;\n        uint8_t _data[2];\n    } latin1[128];\n"
        + "};\n";
    latin1: list[str] = [];
    for code in range(128, 256) {
        encoded = "".join(f"\\x{byte:02x}" for byte in chr(code).encode("utf-8"));
        latin1.append(f"_PyUnicode_LATIN1_INIT(\"\\x{code:02x}\", \"{encoded}\"),");
    }
    blocks[INIT_HEADER] = initializer(
        "_Py_small_ints_INIT",
        [f"_PyLong_DIGIT_INIT({i})," for i in range(-negative, positive)]
    )
        + "\n"
        + initializer(
            "_Py_bytes_characters_INIT",
            [f"_PyBytes_CHAR_INIT({i})," for i in range(256)]
        )
        + "\n"
        + initializer(
            "_Py_str_literals_INIT",
            [f"INIT_STR({name}, \"{value}\")," for (name, value) in by_name]
        )
        + "\n"
        + initializer(
            "_Py_str_identifiers_INIT", [f"INIT_ID({name})," for name in identifiers]
        )
        + "\n"
        + initializer(
            "_Py_str_ascii_INIT",
            [f"_PyASCIIObject_INIT(\"\\x{i:02x}\")," for i in range(128)]
        )
        + "\n"
        + initializer("_Py_str_latin1_INIT", latin1);
    interned = [f"&_Py_ID({name})" for name in identifiers]
        + [f"&_Py_STR({name})" for (name, _) in by_value];
    blocks[INTERN_HEADER] = "static inline void\n_PyUnicode_InitStaticStrings(PyInterpreterState *interp) {\n    PyObject *string;\n"
        + "".join(
            f"    string = {ref};\n    _PyUnicode_InternStatic(interp, &string);\n"
                + "    assert(_PyUnicode_CheckConsistency(string, 1));\n"
                + "    assert(PyUnicode_GET_LENGTH(string) != 1);\n" for ref in interned
        )
        + "}\n";
    statics = [
        f"(PyObject *)&_Py_SINGLETON(small_ints)[_PY_NSMALLNEGINTS + {i}]"
        for i in range(-negative, positive)
    ]
        + [f"(PyObject *)&_Py_SINGLETON(bytes_characters)[{i}]" for i in range(256)]
        + [f"(PyObject *)&_Py_STR({name})" for (name, _) in by_name]
        + [f"(PyObject *)&_Py_ID({name})" for name in identifiers]
        + [f"(PyObject *)&_Py_SINGLETON(strings).ascii[{i}]" for i in range(128)]
        + [
            f"(PyObject *)&_Py_SINGLETON(strings).latin1[{i} - 128]"
            for i in range(128, 256)
        ];
    blocks[FINI_HEADER] = "#ifdef Py_DEBUG\nstatic inline void\n_PyStaticObjects_CheckRefcnt(PyInterpreterState *interp) {\n"
        + "    /* generated runtime-global */\n"
        + "    // (see pycore_runtime_init_generated.h)\n"
        + "".join(f"    _PyStaticObject_CheckRefcnt({ref});\n" for ref in statics)
        + "    /* non-generated */\n"
        + "".join(
            f"    _PyStaticObject_CheckRefcnt({ref});\n" for ref in OTHER_STATIC_OBJECTS
        )
        + "}\n#endif  // Py_DEBUG\n";
    changed = 0;
    for (path, block) in blocks.items() {
        text = regenerated(updated[path], block);
        if text != updated[path] {
            updated[path] = text;
            changed += 1;
        }
    }
    return changed;
}

# ---------------------------------------------------------- conditional structs
# Each definition of `ctype` in `text` with the condition it sits under.
def conditional_definitions(text: str, ctype: str) -> list[tuple[int, int, str]] {
    spans = definitions(text, ctype);
    conditions = guards(blank_comments(text), [s for (s, _) in spans]);
    return [(s, e, conditions[s]) for (s, e) in spans];
}

# The struct bodies of CONDITIONAL_STRUCTS written into `updated`; returns
# the number of bodies changed.
def write_conditional_structs(updated: dict[str, str]) -> int {
    changed = 0;
    for (home, guard, ctype, lines) in CONDITIONAL_STRUCTS {
        if home not in updated {
            sys.exit(
                f"gen_include: CONDITIONAL_STRUCTS names {home}, which is no generated header"
            );
        }
        text = updated[home];
        places = [
            (s, e)
            for (s, e, condition) in conditional_definitions(text, ctype)
            if condition == guard
        ];
        if len(places) != 1 {
            sys.exit(
                f"gen_include: {home} defines {ctype} under `{guard}` {len(
                    places
                )} times"
            );
        }
        (start, end) = places[0];
        body = "\n".join(lines);
        if text[start + 1:end - 1] != body {
            updated[home] = text[:start + 1] + body + text[end - 1:];
            changed += 1;
        }
    }
    return changed;
}

# ------------------------------------------------------------------ the headers
# The headers this script owns.
def owned_paths -> list[str] {
    return [
        path
        for path in generated_paths()
        if path.startswith("Include/")
            and path.endswith(".h")
            and path not in OWNED_ELSEWHERE
    ];
}

def read_copy(path: str) -> str {
    with open(generated_copy(path), encoding="utf-8", newline="") as handle {
        return handle.read();
    }
}

# The C spelling of each field, as gen_layouts.jac asserts it.
def spelling(layout: Layout) -> list[tuple[str, bool]] {
    return [(f.designator(), f.array) for f in layout.fields];
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate the C API headers from the Jac definitions"
    );
    parser.add_argument("--check", action="store_true");
    parser.add_argument(
        "--layouts", help="read the records and constants from this layouts.jac"
    );
    parser.add_argument("--out", help="write the headers under this directory instead");
    args = parser.parse_args();
    layouts_jac = Path(args.layouts).resolve() if args.layouts else LAYOUTS_JAC;
    paths = owned_paths();
    texts = {path: read_copy(path) for path in paths};
    updated = dict(texts);
    restructured = write_conditional_structs(updated);
    (emitted, declared) = header_layouts(updated);
    heads = head_macros(declared.macros);
    for (alias, resolved) in declared.aliases.items() {
        if resolved.startswith("struct ") and resolved not in TYPEDEFS {
            TYPEDEFS[resolved] = alias;
        }
    }
    records = jac_records(layouts_jac);
    computed = jac_layouts(layouts_jac);
    # cpython_api.jac's C-layout records may rename a member C names after a
    # Jac keyword (Py_buffer's `obj` is `owner`), so only their types say
    # what the header declares.
    renamed = {
        name: fields
        for (name, fields) in jac_records(CAPI_JAC).items()
        if name not in records
    };
    # Records: compare each header struct, as the reader above reads it, with
    # its Jac record.
    rewrites: list[Rewrite] = [];
    checked = 0;
    for (name, ctype) in LAYOUTS {
        if name not in emitted or (name not in records and name not in renamed) {
            continue;
        }
        homes = [
            p
            for p in paths
            if definitions(updated[p], ctype)
        ];
        if not homes {
            continue;
        }
        checked += 1;
        # Every definition the release build's view leaves out is a table
        # entry, so it too is Jac data.
        for home in homes {
            found = conditional_definitions(updated[home], ctype);
            for (start, end, guard) in found {
                body = strip_comments(updated[home][start + 1:end - 1]);
                if (len(found) > 1 or re.search(r"(?m)^\s*#", body))
                    and (home, guard, ctype)
                        not in [(h, g, c) for (h, g, c, _) in CONDITIONAL_STRUCTS] {
                    sys.exit(
                        f"gen_include: {ctype} in {home} (under `{guard}`) has preprocessor branches or several definitions; add its body to capi_table.jac's CONDITIONAL_STRUCTS"
                    );
                }
            }
        }
        header = [(f.name, f.jac) for f in emitted[name].fields];
        if name in renamed {
            if [jt for (_, jt) in header] != [jt for (_, jt) in renamed[name]] {
                sys.exit(
                    f"gen_include: cpython_api.jac's {name} no longer matches {ctype} in {homes[
                        0
                    ]}; change the header by hand"
                );
            }
        } elif header != records[name] {
            if any(c == ctype for (_, _, c, _) in CONDITIONAL_STRUCTS) {
                sys.exit(
                    f"gen_include: {ctype} declares {header}, not {name}'s {records[
                        name
                    ]}; change its body in capi_table.jac's CONDITIONAL_STRUCTS"
                );
            }
            rewrites.append(Rewrite(name=name, ctype=ctype, fields=records[name]));
            continue;
        }
        if spelling(emitted[name]) != spelling(computed[name]) {
            sys.exit(
                f"gen_include: {ctype} in {homes[0]} spells its members {spelling(
                    emitted[name]
                )}; gen_layouts.jac's C_ARRAYS and C_MEMBERS give {spelling(
                    computed[name]
                )}"
            );
        }
    }
    for rewrite in rewrites {
        places: list[tuple[str, int, int]] = [
            (p, span[0], span[1]) for p in paths
            for span in definitions(updated[p], rewrite.ctype)
        ];
        if len(places) != 1 {
            sys.exit(
                f"gen_include: {rewrite.ctype} is defined {len(
                    places
                )} times; change it by hand to match {rewrite.name}"
            );
        }
        (home, start, end) = places[0];
        source = updated[home];
        body = rewritten_body(
            f"{home}: {rewrite.ctype}", source[start + 1:end - 1], rewrite.fields, heads
        );
        updated[home] = source[:start + 1] + body + source[end - 1:];
    }
    # Constants: one unconditional `#define NAME <integer>` per name.
    values = jac_constants(layouts_jac);
    owned_constants = {
        name
        for (name, expression, _) in CONSTANTS
        if name == expression and name in values
    };
    sites: dict[str, list[str]] = {};
    pattern = re.compile(
        r"(?m)^([ \t]*#[ \t]*define[ \t]+(\w+))(?!\()([ \t]+)([^\n\\]*?)([ \t]*(?:/\*[^\n]*?\*/|//[^\n]*)?)[ \t]*$"
    );
    for path in paths {
        for hit in pattern.finditer(updated[path]) {
            if hit.group(2) in owned_constants {
                sites.setdefault(hit.group(2), []).append(path);
            }
        }
    }
    respelt = 0;
    constants_checked = 0;
    for (name, homes) in sorted(sites.items()) {
        if len(homes) != 1 {
            continue;
        }
        site = homes[0];
        text = updated[site];
        for hit in pattern.finditer(text) {
            if hit.group(2) != name {
                continue;
            }
            current = literal_value(hit.group(4));
            if current is None {
                break;
            }
            constants_checked += 1;
            (jt, wanted) = values[name];
            if jt.startswith("u") and current < 0 {
                current += 1 << 64;
            }
            if current != wanted {
                spelled = respelled(hit.group(4), wanted);
                updated[site] = text[:hit.start(4)] + spelled + text[hit.end(4):];
                respelt += 1;
            }
            break;
        }
    }
    # C API declarations: the table's entries, header by header.
    entries: dict[str, list[tuple[str, str]]] = {};
    for (declaring, guard, c_text) in DECLARATIONS {
        if declaring not in updated and declaring not in OWNED_ELSEWHERE {
            sys.exit(
                f"gen_include: capi_table.jac names {declaring}, which is no generated header"
            );
        }
        entries.setdefault(declaring, []).append((guard, c_text));
    }
    redeclared = 0;
    for path in paths {
        (updated[path], count) = declare(path, updated[path], entries.get(path, []));
        redeclared += count;
    }
    # Another generator's headers are only compared: their declarations come
    # from that generator's Jac table.
    for path in sorted(OWNED_ELSEWHERE) {
        found = [
            (site.guard, site.text) for site in declaration_sites(path, read_copy(path))
        ];
        if found != entries.get(path, []) {
            sys.exit(
                f"gen_include: {path} declares {found}; capi_table.jac lists {entries.get(
                    path, []
                )}"
            );
        }
    }
    # Global strings: every `_Py_ID_<name>` offset layouts.jac reads names a
    # table identifier.
    unknown = sorted(
        name[len("_Py_ID_"):]
        for name in values
        if name.startswith("_Py_ID_") and name[len("_Py_ID_"):] not in IDENTIFIERS
    );
    if unknown {
        sys.exit(
            f"gen_include: layouts.jac reads _Py_ID offsets global_strings.jac lacks: {', '.join(
                unknown
            )}"
        );
    }
    restrung = write_global_strings(updated);
    current = True;
    for path in paths {
        target = Path(args.out) / f"{path}.in" if args.out else generated_copy(path);
        if args.check {
            if updated[path] != texts[path] {
                print(f"{path} is stale; rerun {COMMAND}", file=sys.stderr);
                current = False;
            }
            continue;
        }
        if args.out or updated[path] != texts[path] {
            target.parent.mkdir(parents=True, exist_ok=True);
            with open(target, "w", encoding="utf-8", newline="") as handle {
                handle.write(updated[path]);
            }
            if updated[path] != texts[path] {
                print(f"wrote {target}");
            }
        }
    }
    print(
        f"{len(paths)} headers: {checked} records checked, {len(rewrites)} rewritten; "
            + f"{constants_checked} constants checked, {respelt} rewritten; "
            + f"{len(CONDITIONAL_STRUCTS)} conditional structs, {restructured} rewritten; "
            + f"{len(DECLARATIONS)} declarations, {redeclared} rewritten; "
            + f"{len(IDENTIFIERS) + len(STRINGS)} global strings, {restrung} blocks rewritten"
    );
    if not current {
        sys.exit(1);
    }
}
