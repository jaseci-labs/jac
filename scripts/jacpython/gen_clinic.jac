"""Generate native Jac Argument Clinic glue for a CPython extension module.

CPython describes each extension function once, in a `/*[clinic input]` block,
and Tools/clinic generates the argument parsing that calls the handwritten
`<name>_impl` C function. This script runs that same parser (Tools/clinic from
the checksum-pinned CPython archive) and writes the Jac equivalent of the
generated `Modules/clinic/<file>.c.h`:

    jac run scripts/jacpython/gen_clinic.jac _zoneinfo     # one module
    jac run scripts/jacpython/gen_clinic.jac --check       # all, fail on drift

The output, jaclang/runtime/python/bindings/clinic/<name>.jac, contains the call
signatures, converter prologues, return conversions and the method, getter and
setter tables. The `_impl` functions keep their C names and C signatures and
live in jaclang/runtime/python/modules/<name>.jac, so porting a module means
porting its `_impl` bodies. A module's type hooks and state stay in the
handwritten jaclang/runtime/python/bindings/<name>.jac, as they do in C. A
class whose methods take defining_class reads it through `<Class>_token`, a
ClassToken the module file defines and the binding points at the created type.

Converters without a generic Jac equivalent (posix's path_t, a module's own
converter functions) are called as convert_<name>(value, fname, label) and
imported from the module's Jac file, as C modules define their own converters.
Default values that name C macros are imported from the module's file too.
"""
import argparse;
import ast;
import importlib;
import re;
import sys;
import tempfile;
import from pathlib { Path }
import from common { BOOTSTRAP, REPO, RUNTIME, extract_tree, format_jac_many, pin }

glob OUTPUT: Path = RUNTIME / "bindings/clinic",
     MODULES: str = "jaclang.runtime.python.modules",
     REGISTRY: Path = BOOTSTRAP / "jacpython-clinic.txt",
     # PyMethodDef flags by name. METH_METHOD is left out: a method taking
     # defining_class finds it through its ClassToken.
     METHOD_FLAGS: dict[str, int] = {
         "METH_VARARGS": 1,
         "METH_KEYWORDS": 2,
         "METH_NOARGS": 4,
         "METH_O": 8,
         "METH_CLASS": 16,
         "METH_STATIC": 32,
         "METH_COEXIST": 64,
         "METH_FASTCALL": 128,
         "METH_METHOD": 0
     },
     # Clinic converter= functions the interpreter defines, by shared Jac
     # converter.
     SHARED_CONVERTERS: dict[str, str] = {
         "_PyEval_SliceIndexNotNone": "convert_slice_index_not_none"
     },
     SCALAR: dict[str, str] = {
         "int": "i32",
         "unsigned int": "u32",
         "long": "i64",
         "unsigned long": "u64",
         "long long": "i64",
         "unsigned long long": "u64",
         "Py_ssize_t": "i64",
         "size_t": "u64",
         "double": "f64",
         "float": "f32",
         "char": "i8",
         "unsigned char": "u8",
         "unsigned short": "u16",
         "short": "i16",
         "uint32_t": "u32",
         "uint16_t": "u16",
         "uint64_t": "u64",
         "int32_t": "i32",
         "int64_t": "i64",
         "intptr_t": "i64",
         "Py_UCS4": "u32",
         "Py_off_t": "i64",
         "pid_t": "i32",
         "uid_t": "u32",
         "gid_t": "u32",
         "dev_t": "u64",
         "mode_t": "u32",
         "clockid_t": "i32"
     },
     BUILTIN_TYPES: dict[str, tuple[str, str]] = {
         "&PyUnicode_Type": ("jacpy_is_unicode", "str"),
         "&PyTuple_Type": ("jacpy_is_tuple", "tuple"),
         "&PyDict_Type": ("jacpy_is_dict", "dict"),
         "&PyList_Type": ("jacpy_is_list", "list"),
         "&PyBytes_Type": ("jacpy_is_bytes", "bytes"),
         "&PyType_Type": ("jacpy_is_type", "type"),
         "&PyLong_Type": ("jacpy_is_long", "int"),
         "&PyFloat_Type": ("jacpy_is_float", "float"),
         "&PyByteArray_Type": ("jacpy_is_bytearray", "bytearray")
     },
     # Object converters typed by their C layout (format units S and Y); clinic
     # checks them as object(subclass_of=...) over the same type.
     TYPED_OBJECTS: dict[str, str] = {
         "PyBytesObject": "&PyBytes_Type",
         "PyByteArrayObject": "&PyByteArray_Type"
     },
     # Unsigned converters with a range check: Jac type, limit, overflow text.
     BOUNDED: dict[str, tuple[str, int, str]] = {
         "unsigned_int": ("u32", 0xFFFFFFFF, "unsigned int"),
         "unsigned_short": ("u16", 0xFFFF, "unsigned short"),
         "unsigned_char": ("u8", 0xFF, "unsigned byte integer"),
         "uint32": ("u32", 0xFFFFFFFF, "Python int too large for C uint32_t"),
         "uint16": ("u16", 0xFFFF, "Python int too large for C uint16_t"),
         "uint8": ("u8", 0xFF, "Python int too large for C uint8_t"),
         "uint64": ("u64", 0xFFFFFFFFFFFFFFFF, "Python int too large for C uint64_t")
     },
     RETURNS: dict[str, str] = {
         "CReturnConverter": "",
         "int": "return_int",
         "bool": "return_bool",
         "long": "return_long",
         "Py_ssize_t": "return_ssize",
         "size_t": "return_size",
         "unsigned_int": "return_unsigned",
         "double": "return_double"
     },
     KEYWORDS: set[str] = set(
         (
             "obj node edge walker root here visitor self super init has can def glob "
             + "impl sem test entry exit spawn visit disengage report ignore by to with "
             + "in is not and or if else elif for while return yield break continue try "
             + "except finally raise assert del import from as lambda async await class "
             + "enum include skip match case switch default flow wait priv pub protect "
             + "static override abs kw let type any str int float bool bytes list dict "
             + "set tuple ptr object len format hash iter next callable id args kwargs "
             + "module value arg own"
         ).split()
     );

def local(name: str) -> str {
    return name + "_" if name in KEYWORDS else name;
}

def jac_string(text: str) -> str {
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace(
        "\n", "\\n"
    ).replace(
        "\t", "\\t"
    );
    return '"' + escaped + '"';
}

obj Unsupported(Exception) {}

# Preprocessor symbols only Windows defines. JacPython builds for Linux and
# macOS, so a clinic function whose #if needs one is not generated.
glob WINDOWS_SYMBOLS: set[str] = {
         "MS_WINDOWS",
         "MS_WINDOWS_DESKTOP",
         "MS_WINDOWS_APP"
     };

def:priv tested_symbol(hit: any) -> str {
    return hit.group(1) or hit.group(2);
}

# Whether a clinic #if condition can hold on a POSIX target: Windows symbols
# are undefined, and the condition holds for some choice of every other
# feature test (a function under !defined(HAVE_BROKEN_POLL) exists where poll
# works), since the module binding decides what a platform actually offers.
def posix_condition(condition: str) -> bool {
    if not condition {
        return True;
    }
    # A comparison (SIZEOF_WCHAR_T == 4) is not evaluated; only a Windows
    # symbol in it decides.
    if re.search(r"[<>=]", condition) {
        return not any(name in condition for name in WINDOWS_SYMBOLS);
    }
    expression = re.sub(
        r"defined\s*\(\s*(\w+)\s*\)|defined\s+(\w+)", "\\1\\2", condition
    );
    expression = expression.replace("&&", " and ").replace("||", " or ");
    expression = re.sub(r"!(?!=)", " not ", expression);
    symbols = sorted(
        set(re.findall(r"\b[A-Za-z_]\w*\b", expression))
            - {"True", "False", "and", "or", "not"}
    );
    features = [
        name
        for name in symbols
        if name not in WINDOWS_SYMBOLS
    ];
    if len(features) > 12 {
        return True;
    }
    for choice in range(2 ** len(features)) {
        values: dict[str, bool] = {name: False for name in symbols};
        for (bit, name) in enumerate(features) {
            values[name] = bool((choice >> bit) & 1);
        }
        try {
            if eval(expression, {}, values) {
                return True;
            }
        } except Exception {
            return True;
        }
    }
    return False;
}

# A body line starting with RELEASE releases what the lines before it
# acquired: the rest of the body runs in a try whose finally does it, so an
# argument that fails to convert (or the impl) never leaks a buffer export
# or the defining class, as clinic's cleanup label does in C.
glob RELEASE: str = "\x00release ";

def nest_releases(body: list[str], indent: str) -> list[str] {
    lines: list[str] = [];
    for (index, line) in enumerate(body) {
        if line.startswith(RELEASE) {
            lines.append(indent + "try {");
            lines += nest_releases(body[index + 1:], indent + "    ");
            lines.append(indent + "} finally {");
            lines.append(indent + "    " + line[len(RELEASE):]);
            lines.append(indent + "}");
            return lines;
        }
        lines.append(indent + line);
    }
    return lines;
}

def class_name(value: any) -> str {
    return value.__class__.__name__;
}

def accepted(conv: any) -> set[str] {
    return {
        getattr(a, "__name__", str(a)) for a in (getattr(conv, "accept", ()) or ())
    };
}

def module_sources(tree: Path, module: str) -> list[Path] {
    for setup in ("Modules/Setup.stdlib.in", "Modules/Setup.bootstrap.in") {
        for line in (tree / setup).read_text().splitlines() {
            parts = re.sub(r"^@[A-Z0-9_]+@", "", line.strip()).split();
            if parts and parts[0] == module {
                return [
                    tree / "Modules" / p
                    for p in parts[1:]
                    if p.endswith(".c")
                ];
            }
        }
    }
    sys.exit(f"{module} is not built by Modules/Setup.stdlib.in or Setup.bootstrap.in");
}

# The preprocessor condition each clinic function is compiled under, as
# Tools/clinic sees it while rendering the block ("" when none). Keyed by the
# Function's id: a function defined once per platform branch (semaphore.c's
# SemLock.acquire) has one full name for several definitions.
glob CONDITIONS: dict[int, str] = {};

# JacPython builds only POSIX targets, where a function compiled only under a
# Windows condition does not exist.
def windows_only(condition: str) -> bool {
    return not posix_condition(condition);
}

# How Tools/clinic parses each function's arguments, by Function id: its
# ParseArgsCodeGen (flags, pos_only, min_pos, max_pos, min_kw_only) and the
# generated C parser, which names the getargs routine it calls.
glob PARSERS: dict[int, tuple[any, str]] = {};

# A C string literal's body as a Python bytes literal's: characters outside
# ASCII become the \x escapes of their UTF-8 bytes.
def c_bytes_literal(piece: str) -> str {
    return "".join(
        c if ord(c) < 128 else "".join(f"\\x{byte:02x}" for byte in c.encode("utf-8"))
        for c in piece
    );
}

# The PyDoc_STRVAR docstrings of `sources` outside clinic blocks, by C
# identifier, in source order: the docs of a module's hand-written method
# tables, types and the module itself. A name defined under several #if
# branches keeps the first one a POSIX target compiles.
def c_docstrings(tree: Path, sources: list[Path]) -> dict[str, str] {
    sys.path.insert(0, str(tree / "Tools/clinic"));
    cpp = importlib.import_module("libclinic.cpp");
    found: dict[str, str] = {};
    for source in sources {
        lines = source.read_text().splitlines();
        monitor = cpp.Monitor(str(source));
        index = 0;
        generated = False;
        while index < len(lines) {
            line = lines[index];
            monitor.writeline(line);
            # Clinic's own output (a block written into the .c file) is
            # generated separately.
            if "[clinic start generated code]" in line {
                generated = True;
            }
            if "[clinic end generated code" in line {
                generated = False;
            }
            start = None if generated else re.match(r"\s*PyDoc_STRVAR\((\w+),(.*)$", line);
            if not start {
                index += 1;
                continue;
            }
            name = start.group(1);
            condition = monitor.condition();
            body = start.group(2);
            while not re.search(r"\);\s*$", body) and index + 1 < len(lines) {
                index += 1;
                monitor.writeline(lines[index]);
                body += "\n" + lines[index];
            }
            index += 1;
            # C line splices, then the adjacent string literals as the bytes
            # C compiles them to (\xNN escapes are bytes), read as UTF-8.
            body = body.replace("\\\n", "");
            text = b"".join(
                ast.literal_eval('b"' + c_bytes_literal(piece) + '"')
                for piece in re.findall(r'"((?:[^"\\\n]|\\.)*)"', body)
            ).decode("utf-8");
            if name not in found and posix_condition(condition) {
                found[name] = text;
            }
        }
    }
    return found;
}

# Splits a C macro argument list at its top-level commas, keeping string
# literals and nested parentheses whole.
def split_c_arguments(text: str) -> list[str] {
    pieces: list[str] = [];
    depth = 0;
    current = "";
    quoted = False;
    index = 0;
    while index < len(text) {
        c = text[index];
        if quoted {
            current += c;
            if c == "\\" and index + 1 < len(text) {
                current += text[index + 1];
                index += 2;
                continue;
            }
            if c == '"' {
                quoted = False;
            }
        } elif c == '"' {
            quoted = True;
            current += c;
        } elif c == "(" {
            depth += 1;
            current += c;
        } elif c == ")" {
            depth -= 1;
            current += c;
        } elif c == "," and depth == 0 {
            pieces.append(current.strip());
            current = "";
        } else {
            current += c;
        }
        index += 1;
    }
    pieces.append(current.strip());
    return pieces;
}

# Docstrings defined through a function-like macro whose body is a
# PyDoc_STRVAR (math's FUNC1(name, func, overflow, "doc")): each invocation's
# expanded name and doc text.
def c_macro_docstrings(sources: list[Path]) -> dict[str, str] {
    found: dict[str, str] = {};
    for source in sources {
        text = source.read_text().replace("\\\n", " ");
        macros: dict[str, tuple[list[str], str, str]] = {};
        for hit in re.finditer(r"#define\s+(\w+)\(([^)]*)\)(.*)", text) {
            doc = re.search(
                r"PyDoc_STRVAR\(\s*([\w#\s]+?)\s*,\s*(\w+)\s*\)", hit.group(3)
            );
            if doc {
                params = [p.strip() for p in hit.group(2).split(",")];
                macros[hit.group(1)] = (params, doc.group(1), doc.group(2));
            }
        }
        for (macro, (params, name_pattern, doc_param)) in macros.items() {
            for call in re.finditer(r"(?m)^" + macro + r"\(", text) {
                depth = 1;
                end = call.end();
                quoted = False;
                while end < len(text) and depth > 0 {
                    c = text[end];
                    if quoted {
                        if c == "\\" {
                            end += 1;
                        } elif c == '"' {
                            quoted = False;
                        }
                    } elif c == '"' {
                        quoted = True;
                    } elif c == "(" {
                        depth += 1;
                    } elif c == ")" {
                        depth -= 1;
                    }
                    end += 1;
                }
                values = split_c_arguments(text[call.end():end - 1]);
                if len(values) != len(params) {
                    continue;
                }
                binding = dict(zip(params, values));
                name = "".join(
                    binding.get(part.strip(), part.strip())
                    for part in name_pattern.split("##")
                );
                literals = re.findall(
                    r'"((?:[^"\\\n]|\\.)*)"', binding.get(doc_param, "")
                );
                if literals and name not in found {
                    found[name] = b"".join(
                        ast.literal_eval('b"' + c_bytes_literal(piece) + '"')
                        for piece in literals
                    ).decode("utf-8");
                }
            }
        }
    }
    return found;
}

# The docs a C source writes inline into its PyMethodDef, PyMemberDef and
# PyGetSetDef tables (PyDoc_STR("...") or a literal), as
# <table>_<entry>_doc. Entries a POSIX target does not compile are left out.
def c_table_docs(tree: Path, sources: list[Path]) -> dict[str, str] {
    sys.path.insert(0, str(tree / "Tools/clinic"));
    cpp = importlib.import_module("libclinic.cpp");
    found: dict[str, str] = {};
    for source in sources {
        lines = source.read_text().splitlines();
        monitor = cpp.Monitor(str(source));
        table = "";
        pending = "";
        condition = "";
        for line in lines {
            monitor.writeline(line);
            start = re.match(
                r"\s*(?:static\s+)?(?:struct\s+)?(?:PyMethodDef|PyMemberDef|PyGetSetDef)\s+(\w+)\s*\[\]\s*=",
                line
            );
            if start {
                table = start.group(1);
                continue;
            }
            if not table {
                continue;
            }
            if re.match(r"\s*};", line) {
                table = "";
                continue;
            }
            if not pending {
                if not re.match(r'\s*\{\s*"', line) {
                    continue;
                }
                condition = monitor.condition();
            }
            pending += line.replace("\\\n", "") + "\n";
            if not re.search(r"\}\s*,?\s*(/\*.*)?$", pending.rstrip()) {
                continue;
            }
            record = pending;
            pending = "";
            name = re.match(r'\s*\{\s*"(\w+)"', record);
            literals = re.findall(r'"((?:[^"\\\n]|\\.)*)"', record);
            if not name or len(literals) < 2 or not posix_condition(condition) {
                continue;
            }
            # The first literal is the pending's name; the rest are its doc.
            text = b"".join(
                ast.literal_eval('b"' + c_bytes_literal(piece) + '"')
                for piece in literals[1:]
            ).decode("utf-8");
            found[f"{table}_{name.group(1)}_doc"] = text;
        }
    }
    return found;
}

# (class or None, clinic function) for every clinic input block of `sources`.
def clinic_functions(tree: Path, sources: list[Path]) -> list[tuple[any, any]] {
    sys.path.insert(0, str(tree / "Tools/clinic"));
    app = importlib.import_module("libclinic.app");
    clanguage = importlib.import_module("libclinic.clanguage");
    parse_args = importlib.import_module("libclinic.parse_args");
    # Tools/clinic/libclinic/cli.py: a file defining Py_LIMITED_API gets the
    # limited C API's parsers and messages.
    limited = importlib.import_module("libclinic.cli").LIMITED_CAPI_REGEX;
    function_type = importlib.import_module("libclinic.function").Function;
    found: list[tuple[any, any]] = [];
    for source in sources {
        text = source.read_text();
        if "[clinic input]" not in text {
            continue;
        }
        language = clanguage.CLanguage(str(source));
        render = language.render;
        def record_conditions(clinic: any, signatures: any) -> any {
            for signature in signatures {
                if isinstance(signature, function_type) {
                    CONDITIONS[id(signature)] = language.cpp.condition();
                }
            }
            return render(clinic, signatures);
        }
        def record_parser(f: any, codegen: any) -> dict[str, str] {
            generator = parse_args.ParseArgsCodeGen(f, codegen);
            templates = generator.parse_args(language);
            PARSERS[id(f)] = (generator, templates["parser_definition"]);
            return templates;
        }
        language.render = record_conditions;
        language.output_templates = record_parser;
        clinic = app.Clinic(
            language,
            filename=str(source),
            verify=False,
            limited_capi=bool(limited.search(text))
        );
        clinic.parse(text);
        # Classes declared without a module prefix (md5's `class MD5Type`)
        # belong to the clinic itself rather than to one of its modules.
        for module in [clinic] + list(clinic.modules.values()) {
            found += [(None, f) for f in module.functions];
            stack = list(module.classes.values());
            while stack {
                cls = stack.pop(0);
                found += [(cls, f) for f in cls.functions];
                stack += list(cls.classes.values());
            }
        }
    }
    return found;
}

def jac_ctype(ctype: str) -> str {
    base = " ".join(ctype.replace("const ", "").replace("*", " * ").split());
    if base in SCALAR {
        return SCALAR[base];
    }
    if (base.endswith("*") and base[:-1].strip() in ("PyObject", "PyTypeObject"))
        or base.endswith("Object *") {
        return "ptr[PyObject]";
    }
    if base == "char *" {
        return "str";
    }
    if base == "Py_buffer" {
        return "BufferArgument";
    }
    if base in ("int", "_Bool", "bool") {
        return "bool";
    }
    # A C typedef (SEM_HANDLE) names nothing in Jac: the converter's own
    # return type types the variable.
    return "";
}

obj Emitter {
    has module: str,
        name: str,
        lines: list[str] = [],
        impls: set[str] = set(),
        module_names: set[str] = set(),
        api: set[str] = {"NULL", "PyObject"},
        converters: set[str] = set(),
        tables: dict[str, list[str]] = {},
        getsets: dict[str, dict[str, dict[str, str]]] = {},
        hooks: list[str] = [],
        tokens: set[str] = set(),
        invokers: set[str] = {"BoundArguments"},
        qualified: bool = False,
        skipped: list[str] = [],
        windows: list[str] = [],
        class_docs: dict[str, str] = {},
        c_docs: dict[str, str] = {};

    def use(name: str) -> str {
        self.converters.add(name);
        return name;
    }

    def token_name(cls_name: str) -> str {
        return f"{cls_name}_token";
    }

    def table_name(cls: any) -> str {
        return f"{cls.name}_methods" if cls else "module_methods";
    }

    # The Jac expression for a parameter's default.
    def default_value(p: any, jtype: str) -> str {
        c_default = getattr(p.converter, "c_default", "");
        py_default = p.default;
        if jtype == "ptr[u8]" and (c_default == "NULL" or py_default is None) {
            return "ptr[u8]()";
        }
        if c_default in (None, "") {
            if py_default is None {
                return "NULL" if jtype == "ptr[PyObject]" else "None";
            }
            if isinstance(py_default, bool) {
                return "True" if py_default else "False";
            }
            if isinstance(py_default, (int, float)) {
                return repr(py_default);
            }
            if isinstance(py_default, str) {
                return jac_string(py_default);
            }
            raise Unsupported(f"default {py_default!r}");
        }
        text = str(c_default).strip();
        if jtype == "BufferArgument"
            and text.replace(" ", "")
                in ("{NULL,NULL}", '{.buf="",.obj=NULL,.len=0}') {
            return "BufferArgument()";
        }
        if text == "NULL" {
            return "NULL" if jtype.startswith("ptr") else "None";
        }
        if text == "Py_None" {
            return self.use("borrowed_none") + "()";
        }
        if text in ("Py_True", "Py_False") {
            return self.use("borrowed_" + text[3:].lower()) + "()";
        }
        if jtype == "bool" and text in ("0", "1", "true", "false") {
            return "True" if text in ("1", "true") else "False";
        }
        if re.fullmatch(r"-?\d+(\.\d+)?([eE][-+]?\d+)?", text) {
            return text;
        }
        if re.fullmatch(r'"(?:[^"\\]|\\.)*"', text) {
            return text;
        }
        # Py_ssize_t's limit on every JacPython target.
        if text == "PY_SSIZE_T_MAX" {
            return "9223372036854775807";
        }
        if re.fullmatch(r"[A-Za-z_]\w*", text) {
            self.module_names.add(text);
            return text;
        }
        # A bitwise OR of macros (select's POLLIN | POLLPRI | POLLOUT), in
        # the parameter's own width.
        if re.fullmatch(r"[A-Za-z_]\w*(?:\s*\|\s*[A-Za-z_]\w*)+", text) {
            names = re.findall(r"[A-Za-z_]\w*", text);
            self.module_names.update(names);
            joined = " | ".join(names);
            return f"{jtype}({joined})" if jtype in SCALAR.values() else joined;
        }
        raise Unsupported(f"C default {text}");
    }

    # (Jac type, expression over `value`, extra statements) for one parameter.
    def convert(
        fname: str, p: any, position: int, numbered: bool = False
    ) -> tuple[str, str, list[str]] {
        conv = p.converter;
        kind = class_name(conv).removesuffix("_converter");
        # getargs' own conversions (a format parser) number every argument.
        shown = p.name if p.kind.name != "POSITIONAL_ONLY" and not numbered else "";
        # Position 0 is clinic's METH_O argument, named only "argument".
        label = jac_string("argument")
            if position == 0
            else self.use("argument_label") + f"({jac_string(shown)}, {position})";
        where = f"{jac_string(fname)}, {label}";
        accept_names = accepted(conv);
        # The limited C API reports a mismatch with the type's %T name.
        qualified = ", True" if self.qualified else "";
        # Clinic records bitwise=True only as the mask format unit it selects.
        bitwise = getattr(conv, "format_unit", "") in ("B", "H", "I", "k", "K");
        # object(converter=..., type=...): the named function converts into
        # the declared C type.
        through = getattr(conv, "converter", None);
        if kind == "object" and isinstance(through, str) and through {
            if through in SHARED_CONVERTERS {
                return (
                    jac_ctype(conv.type),
                    self.use(SHARED_CONVERTERS[through]) + f"(value, {where})",
                    []
                );
            }
            custom = "convert_" + re.sub(r"\W", "_", through);
            self.module_names.add(custom);
            return (jac_ctype(conv.type), f"{custom}(value, {where})", []);
        }
        if kind == "object" or kind in TYPED_OBJECTS {
            subclass = TYPED_OBJECTS[kind]
                if kind in TYPED_OBJECTS
                else getattr(conv, "subclass_of", "");
            if not subclass {
                return ("ptr[PyObject]", "value", []);
            }
            if subclass in BUILTIN_TYPES {
                check = BUILTIN_TYPES[subclass][0];
                expected = BUILTIN_TYPES[subclass][1];
                self.api.add(check);
                bad = self.use("bad_argument");
                return (
                    "ptr[PyObject]",
                    "value",
                    [
                        f"if {check}(value) == 0 {{ {bad}({where}, {jac_string(
                            expected
                        )}, value{qualified}); }}"
                    ]
                );
            }
            check = "subclass_" + re.sub(r"\W+", "_", subclass).strip("_");
            self.module_names.add(check);
            return ("ptr[PyObject]", "value", [f"{check}(value, {where});"]);
        }
        if kind == "int" {
            # int(accept={str}) is clinic's "C" unit: one unicode character.
            # int_converter keeps only that format unit, not the accept set.
            if "str" in accept_names or getattr(conv, "format_unit", "") == "C" {
                return (
                    "i32",
                    f"i32({self.use('convert_unicode_char')}(value, {where}))",
                    []
                );
            }
            return ("i32", self.use("convert_int") + "(value)", []);
        }
        if kind == "bool" {
            if "int" in accept_names {
                return ("bool", self.use("convert_bool_int") + "(value)", []);
            }
            return ("bool", self.use("convert_bool") + "(value)", []);
        }
        # PyLong_AsPid is PyLong_AsInt where pid_t is an int (every JacPython target).
        if kind == "pid_t" {
            return ("i32", self.use("convert_int") + "(value)", []);
        }
        if kind == "fildes" {
            return ("i32", self.use("convert_fildes") + f"(value, {where})", []);
        }
        if kind == "Py_ssize_t" {
            return ("i64", self.use("convert_ssize") + "(value)", []);
        }
        if kind == "long" {
            return ("i64", self.use("convert_long") + "(value)", []);
        }
        if kind == "long_long" {
            return ("i64", self.use("convert_long_long") + "(value)", []);
        }
        if kind in ("unsigned_long", "unsigned_long_long") {
            return (
                "u64",
                self.use("convert_" + kind) + f"(value, {bitwise}, {where})",
                []
            );
        }
        # Without bitwise=True these are CPython's _PyLong_*_Converter.
        if kind in ("unsigned_short", "unsigned_int", "uint8", "uint16", "uint32", "uint64")
            and not bitwise {
            return (BOUNDED[kind][0], self.use("convert_" + kind) + "(value)", []);
        }
        if kind in BOUNDED {
            jt = BOUNDED[kind][0];
            limit = BOUNDED[kind][1];
            text = BOUNDED[kind][2];
            bounded = self.use("convert_unsigned_bounded");
            return (
                jt,
                f"{jt}({bounded}(value, {bitwise}, u64({limit}), {jac_string(text)}, {where}))",
                []
            );
        }
        if kind == "double" {
            return ("f64", self.use("convert_double") + "(value)", []);
        }
        if kind == "float" {
            return ("f32", self.use("convert_float") + "(value)", []);
        }
        # Tools/clinic keeps a str or Py_buffer converter's accepted types only
        # as the getargs format unit it selects.
        unit = getattr(conv, "format_unit", "");
        if kind == "str" {
            if unit not in ("s", "z") or getattr(conv, "encoding", "") {
                raise Unsupported(f"str converter '{unit}'");
            }
            accepts_none = unit == "z";
            # A str that may be NULL (None accepted, or a NULL C default) stays
            # C's `const char *`: the argument's UTF-8, NULL when absent.
            if accepts_none or getattr(conv, "c_default", "") == "NULL" {
                return (
                    "ptr[u8]",
                    self.use("convert_cstr") + f"(value, {where}, {accepts_none})",
                    []
                );
            }
            return ("str", self.use("convert_str") + f"(value, {where})", []);
        }
        if kind == "unicode" and self.qualified {
            self.api.add("jacpy_is_unicode");
            bad = self.use("bad_argument");
            return (
                "ptr[PyObject]",
                "value",
                [
                    f'if jacpy_is_unicode(value) == 0 {{ {bad}({where}, "str", value, True); }}'
                ]
            );
        }
        if kind == "unicode" {
            return (
                "ptr[PyObject]",
                self.use("convert_unicode") + f"(value, {where})",
                []
            );
        }
        if kind == "Py_buffer" {
            converter = {
                "y*": "convert_buffer",
                "s*": "convert_text_buffer",
                "w*": "convert_writable_buffer"
            }.get(
                unit
            );
            if converter is None {
                raise Unsupported(f"Py_buffer converter '{unit}'");
            }
            return ("BufferArgument", self.use(converter) + f"(value, {where})", []);
        }
        named = getattr(conv, "converter", "");
        # Converters the interpreter itself provides (ceval.c), shared by
        # every module that names them.
        if isinstance(named, str) and named in SHARED_CONVERTERS {
            return (
                jac_ctype(conv.type),
                self.use(SHARED_CONVERTERS[named]) + f"(value, {where})",
                []
            );
        }
        # A module-defined converter, supplied by the module's Jac file.
        custom = re.sub(
            r"\W",
            "_",
            "convert_" + (named if isinstance(named, str) and named else kind)
        );
        self.module_names.add(custom);
        # A converter the C glue calls with the module first (_struct's
        # cache_struct_converter(module, arg, &out)) gets the receiver too.
        parsed = "";
        try {
            parsed = conv.parse_arg("arg", "argument", limited_capi=False) or "";
        } except Exception {
            parsed = "";
        }
        if isinstance(named, str) and named and f"{named}(module," in parsed {
            return (jac_ctype(conv.type), f"{custom}(receiver, value, {where})", []);
        }
        return (jac_ctype(conv.type), f"{custom}(value, {where})", []);
    }

    # The PyMethodDef flags and getargs parser clinic generates for `f`.
    # tp_new and tp_init keep the flags clinic chose internally; they only
    # select the parser.
    def calling_convention(f: any) -> tuple[int, str] {
        if id(f) not in PARSERS {
            raise Unsupported("no clinic parser");
        }
        generator = PARSERS[id(f)][0];
        body = PARSERS[id(f)][1];
        names = [name.strip() for name in generator.flags.split("|")];
        flags = 0;
        for name in names {
            if name not in METHOD_FLAGS {
                raise Unsupported(f"flag {name}");
            }
            flags = flags | METHOD_FLAGS[name];
        }
        if "switch (" in body {
            raise Unsupported("optional groups");
        }
        if "_PyArg_ParseStackAndKeywords(" in body
            or "_PyArg_ParseTupleAndKeywordsFast(" in body {
            raise Unsupported("keyword format parsing");
        }
        if "PyArg_ParseTupleAndKeywords(" in body {
            parser = "PARSE_FORMAT_KEYWORDS";
        } elif "METH_NOARGS" in names {
            parser = "PARSE_NOTHING"
                if "_PyArg_NoPositional(" in body
                else "PARSE_GIVEN";
        } elif "METH_O" in names {
            parser = "PARSE_GIVEN";
        } elif "_PyArg_UnpackKeywords(" in body {
            parser = "PARSE_KEYWORDS";
        } elif "takes no arguments" in body {
            parser = "PARSE_NO_ARGUMENTS";
        } elif "_PyArg_ParseStack(" in body or "PyArg_ParseTuple(" in body {
            parser = "PARSE_FORMAT";
        } elif "_PyArg_CheckPositional(" in body
            or (generator.limited_capi and "expected" in body) {
            # The limited C API spells _PyArg_CheckPositional() out inline.
            parser = "PARSE_POSITIONAL";
        } else {
            raise Unsupported(f"parser for {generator.flags}");
        }
        return (flags, parser);
    }

    def function(cls: any, f: any) {
        kind = f.kind.name;
        params = list(f.parameters.values());
        params.pop(0);
        uses_class = bool(params)
            and class_name(params[0].converter) == "defining_class_converter";
        if uses_class {
            params.pop(0);
            self.tokens.add(cls.name);
        }
        if any(p.group for p in params) {
            raise Unsupported("optional groups");
        }
        varpos = [
            p
            for p in params
            if class_name(p.converter)
                in ("varpos_tuple_converter", "varpos_array_converter")
        ];
        if varpos {
            self.varargs_function(cls, f, params, varpos[0]);
            return;
        }
        convention = self.calling_convention(f);
        flags = convention[0];
        parser = convention[1];
        generator = PARSERS[id(f)][0];
        # The limited C API's clinic converters name a mismatched argument's
        # type with %T; getargs' format conversions use tp_name.
        self.qualified = bool(generator.limited_capi)
            and parser != "PARSE_FORMAT_KEYWORDS";
        # getargs converts as it binds: a binding error waits for the
        # arguments before it to convert.
        stepwise = parser == "PARSE_FORMAT_KEYWORDS";
        base = f.c_basename;
        impl_name = base + "_impl";
        self.impls.add(impl_name);
        fname = (cls.name if cls else f.name)
            if kind in ("METHOD_NEW", "METHOD_INIT")
            else f.name;
        ret_kind = class_name(f.return_converter).removesuffix("_return_converter");
        # A module's own return converter (cmath's Py_complex_protected) is
        # return_<kind> in the module's Jac file, as its C one is in the module.
        wrap = "";
        if ret_kind in RETURNS {
            wrap = RETURNS[ret_kind];
            if wrap {
                self.use(wrap);
            }
        } else {
            wrap = re.sub(r"\W", "_", "return_" + ret_kind);
            self.module_names.add(wrap);
        }
        # The body that converts bound values and calls the impl.
        body: list[str] = [];
        call_args = ["receiver"];
        if uses_class {
            finder = "defining_class_of_type"
                if kind == "CLASS_METHOD"
                else "defining_class";
            body.append(
                f"cls = {self.use(finder)}(receiver, {self.token_name(cls.name)});"
            );
            self.api.add("jacpy_release");
            body.append(RELEASE + "jacpy_release(cls);");
            call_args.append("cls");
        }
        # A METH_O argument is named only "argument" in type errors.
        meth_o = bool(flags & METHOD_FLAGS["METH_O"]);
        for (i, p) in enumerate(params) {
            var = local(p.name);
            position = i + 1;
            slot = f"args.values[{i}]";
            if stepwise {
                body.append(f"args.reach({i});");
            }
            # Py_ssize_t(accept={int, NoneType}) and an object parsed by
            # _Py_convert_optional_to_ssize_t (mmap's read(n)) are one converter.
            optional_ssize = (
                class_name(p.converter) == "Py_ssize_t_converter"
                and "NoneType" in accepted(p.converter)
            )
                or getattr(p.converter, "converter", "")
                    == "_Py_convert_optional_to_ssize_t";
            if optional_ssize {
                fallback = self.default_value(p, "i64") if p.is_optional() else "0";
                body.append(f"{var}: i64 = {fallback};");
                body.append(
                    f"if {slot} != NULL {{ {var} = {self.use('convert_optional_ssize')}({slot}, {fallback}); }}"
                );
                call_args.append(var);
                continue;
            }
            converted = self.convert(fname, p, 0 if meth_o else position, stepwise);
            jtype = converted[0];
            expr = converted[1];
            checks = converted[2];
            if p.is_optional() {
                if not jtype {
                    raise Unsupported("optional module converter");
                }
                fallback = self.default_value(p, jtype);
                if jtype == "BufferArgument" {
                    body.append(f"{var} = BufferArgument();");
                    body.append(RELEASE + f"{var}.close();");
                } else {
                    body.append(f"{var}: {jtype} = {fallback};");
                }
                body.append(f"if {slot} != NULL {{");
                body.append(f"    value = {slot};");
                body += [f"    {c}" for c in checks];
                body.append(f"    {var} = {expr};");
                body.append("}");
            } else {
                body.append(f"value = {slot};");
                body += checks;
                body.append(
                    f"{var}: {jtype} = {expr};" if jtype else f"{var} = {expr};"
                );
                if jtype == "BufferArgument" {
                    body.append(RELEASE + f"{var}.close();");
                }
            }
            # A converter whose cleanup drops the reference it produced
            # (_struct's cache_struct) hands the impl a new reference.
            if jtype != "BufferArgument"
                and re.search(r"Py_X?DECREF\(", p.converter.cleanup() or "") {
                self.api.add("jacpy_release");
                body.append(RELEASE + f"jacpy_release({var});");
            }
            call_args.append(var);
        }
        if stepwise {
            body.append(f"args.reach({len(params)});");
        }
        call = f"{impl_name}({', '.join(call_args)})";
        result = f"{wrap}({call})" if wrap else call;
        body.append(f"return {result};");
        sig = f"{base}_signature";
        if parser != "PARSE_GIVEN" {
            names = ", ".join(jac_string(p.name) for p in params);
            options = [
                f"{jac_string(fname)}",
                f"[{names}]",
                str(generator.min_pos),
                str(generator.max_pos),
                str(generator.pos_only)
            ];
            if generator.min_kw_only {
                options.append(f"keyword_required={generator.min_kw_only}");
            }
            options.append(f"parser={self.parse_constant(parser)}");
            self.lines.append(
                f"glob:priv {sig} = {self.invoker('CallSignature')}({', '.join(
                    options
                )});"
            );
        }
        self.lines.append(
            f"def:priv {base}_bound(args: BoundArguments) -> ptr[PyObject] {{"
        );
        self.lines.append("    receiver = args.context;");
        self.lines += nest_releases(body, "    ");
        self.lines.append("}");
        doc = f.docstring or "";
        # A signature-only docstring ends with the blank line the
        # __text_signature__ getter expects, as Tools/clinic writes it.
        if doc.split("\n")[-1] == "--" {
            doc += "\n\n";
        }
        if kind in ("METHOD_NEW", "METHOD_INIT") and cls is not None {
            self.class_docs[cls.name] = doc;
        }
        # Clinic's self_type_check: a tp_new/tp_init that refuses arguments
        # does so only for the class or a subclass keeping the other slot.
        type_check = "";
        if "{self_type_check}" in PARSERS[id(f)][1]
            and cls is not None
            and cls.typedef {
            self.tokens.add(cls.name);
            finder = "new_checks_arguments"
                if kind == "METHOD_NEW"
                else "init_checks_arguments";
            subject = "type" if kind == "METHOD_NEW" else "receiver";
            type_check = f", checked={self.use(finder)}({subject}, {self.token_name(cls.name)})";
        }
        if kind == "METHOD_NEW" {
            self.lines.append(
                f"def:pub {base}_new(type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]) -> ptr[PyObject] {{"
            );
            self.lines.append(
                f"    return {self.invoker('invoke')}({sig}, args, kwargs, {base}_bound, type{type_check});"
            );
            self.lines.append("}");
            self.hooks.append(f"{base}_new");
            return;
        }
        if kind == "METHOD_INIT" {
            self.lines.append(
                f"def:pub {base}_init(receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]) -> i32 {{"
            );
            self.lines.append(
                f"    result = {self.invoker('invoke')}({sig}, args, kwargs, {base}_bound, receiver{type_check});"
            );
            self.lines.append("    if not result { return i32(-1); }");
            self.lines.append("    jacpy_release(result);");
            self.lines.append("    return i32(0);");
            self.lines.append("}");
            self.api.add("jacpy_release");
            self.hooks.append(f"{base}_init");
            return;
        }
        if kind in ("GETTER", "SETTER") {
            raise Unsupported("getter/setter routed separately");
        }
        # The callback CPython's call machinery invokes for these flags.
        fast = bool(flags & METHOD_FLAGS["METH_FASTCALL"]);
        keywords = bool(flags & METHOD_FLAGS["METH_KEYWORDS"]);
        head = f"def:priv {base}_call(receiver: ptr[PyObject], ";
        if meth_o or flags & METHOD_FLAGS["METH_NOARGS"] {
            argument = "value" if meth_o else "unused";
            self.lines.append(head + f"{argument}: ptr[PyObject]) -> ptr[PyObject] {{");
            self.lines.append(
                f"    return {self.invoker('invoke_given')}({'value'
                    if meth_o
                    else 'NULL'}, {base}_bound, receiver);"
            );
            callback = "positional";
        } elif fast {
            kwnames = ", kwnames: ptr[PyObject]" if keywords else "";
            self.lines.append(
                head
                    + f"args: ptr[ptr[PyObject]], nargs: i64{kwnames}) -> ptr[PyObject] {{"
            );
            self.lines.append(
                f"    return {self.invoker('invoke_vector')}({sig}, args, nargs, {'kwnames'
                    if keywords
                    else 'NULL'}, {base}_bound, receiver);"
            );
            callback = "fast_keywords" if keywords else "fast";
        } elif keywords {
            self.lines.append(
                head + "args: ptr[PyObject], kwargs: ptr[PyObject]) -> ptr[PyObject] {"
            );
            self.lines.append(
                f"    return {self.invoker('invoke')}({sig}, args, kwargs, {base}_bound, receiver);"
            );
            callback = "keywords";
        } else {
            raise Unsupported(f"calling convention {generator.flags}");
        }
        self.lines.append("}");
        self.tables.setdefault(self.table_name(cls), []).append(
            f"MethodDefinition({jac_string(f.name)}, MethodCallbacks({callback}={base}_call), {jac_string(
                doc
            )}, {flags})"
        );
    }

    # A function of only *args (math.gcd): METH_FASTCALL with no arity check,
    # the impl taking the argument array and its length (or, for a tuple
    # converter, the arguments as a tuple).
    def varargs_function(cls: any, f: any, params: list[any], varpos: any) {
        if len(params) != 1 or f.kind.name != "CALLABLE" {
            raise Unsupported("*args with other parameters");
        }
        flags = 0;
        for name in PARSERS[id(f)][0].flags.split("|") {
            flags = flags | METHOD_FLAGS[name.strip()];
        }
        if flags != METHOD_FLAGS["METH_FASTCALL"] {
            raise Unsupported("*args with keywords");
        }
        base = f.c_basename;
        impl_name = base + "_impl";
        self.impls.add(impl_name);
        self.lines.append(
            f"def:priv {base}_call(receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64) -> ptr[PyObject] {{"
        );
        if class_name(varpos.converter) == "varpos_tuple_converter" {
            tuple_of = self.invoker("vector_tuple");
            self.api.add("jacpy_release");
            self.lines.append(f"    values = {tuple_of}(args, nargs);");
            self.lines.append("    if not values { return NULL; }");
            self.lines.append(f"    result = {impl_name}(receiver, values);");
            self.lines.append("    jacpy_release(values);");
            self.lines.append("    return result;");
        } else {
            self.lines.append(f"    return {impl_name}(receiver, args, nargs);");
        }
        self.lines.append("}");
        doc = f.docstring or "";
        if doc.split("\n")[-1] == "--" {
            doc += "\n\n";
        }
        self.tables.setdefault(self.table_name(cls), []).append(
            f"MethodDefinition({jac_string(f.name)}, MethodCallbacks(fast={base}_call), {jac_string(
                doc
            )}, {flags})"
        );
    }

    def invoker(name: str) -> str {
        self.invokers.add(name);
        return name;
    }

    def parse_constant(name: str) -> str {
        self.invokers.add(name);
        return name;
    }

    def accessor(cls: any, f: any) {
        base = f.c_basename;
        # Clinic names accessor impls <c_basename>_get_impl / _set_impl.
        impl_name = base + ("_get_impl" if f.kind.name == "GETTER" else "_set_impl");
        self.impls.add(impl_name);
        record = self.getsets.setdefault(self.table_name(cls), {}).setdefault(
            f.name, {"doc": ""}
        );
        if f.kind.name == "GETTER" {
            self.lines.append(
                f"def:priv {base}_get(receiver: ptr[PyObject], context: u64) -> ptr[PyObject] {{"
            );
            self.lines.append(f"    return {impl_name}(receiver);");
            self.lines.append("}");
            record["read"] = f"{base}_get";
            record["doc"] = f.docstring or record["doc"];
        } else {
            self.lines.append(
                f"def:priv {base}_set(receiver: ptr[PyObject], value: ptr[PyObject], context: u64) -> i32 {{"
            );
            self.lines.append(f"    return i32({impl_name}(receiver, value));");
            self.lines.append("}");
            record["write"] = f"{base}_set";
        }
    }

    def render(source_names: list[str], version: str) -> str {
        head = [
            f'"""Argument Clinic glue for {self.module}: signatures, converters and tables.',
            "",
            f"Generated by scripts/jacpython/gen_clinic.jac from CPython {version}",
            f"{', '.join(source_names)}; do not edit. The _impl functions live in",
            f"{MODULES}.{self.name}."
        ];
        if self.skipped {
            head += [
                "",
                "Bound by hand in the module binding (no generic Jac converter):"
            ];
            head += [f"    {item}" for item in self.skipped];
        }
        if self.windows {
            head += ["", "Compiled only on Windows, so absent here:"];
            head += [f"    {item}" for item in self.windows];
        }
        head.append('"""');
        imports = [
            f"import from jaclang.runtime.python.cpython_api {{ {', '.join(
                sorted(self.api)
            )} }}",
            "import from jaclang.runtime.python.bindings.module { MethodDefinition, MethodCallbacks }",
            "import from jaclang.runtime.python.bindings.type { PropertyDefinition, PropertyCallbacks }",
            f"import from jaclang.runtime.python.bindings.arguments {{ {', '.join(
                sorted(self.invokers)
            )} }}",
            "import from jaclang.runtime.python.bindings.buffer { BufferArgument }"
        ];
        converters = sorted(self.converters);
        if converters {
            imports.append(
                f"import from jaclang.runtime.python.bindings.converters {{ {', '.join(
                    converters
                )} }}"
            );
        }
        # A class's ClassToken lives in the module file with its impls, which
        # also read the instance state through it; the binding fills it in.
        provided = sorted(
            self.impls | self.module_names | {self.token_name(c) for c in self.tokens}
        );
        if provided {
            imports.append(
                f"import from {MODULES}.{self.name} {{ {', '.join(provided)} }}"
            );
        }
        tables: list[str] = [];
        for (cls_name, doc) in sorted(self.class_docs.items()) {
            tables.append(f"glob {cls_name}_doc: str = {jac_string(doc)};");
        }
        # The C module's own PyDoc_STRVAR docstrings, under their C names.
        taken = {f"{cls_name}_doc" for cls_name in self.class_docs};
        for (doc_name, doc) in self.c_docs.items() {
            if doc_name not in taken and doc_name not in KEYWORDS {
                tables.append(f"glob {doc_name}: str = {jac_string(doc)};");
            }
        }
        for (table, entries) in sorted(self.tables.items()) {
            tables.append(f"glob {table}: list[MethodDefinition] = [");
            tables += [f"    {e}," for e in entries];
            tables.append("];");
        }
        for (table, props) in sorted(self.getsets.items()) {
            tables.append(
                f"glob {table.replace(
                    '_methods', '_getset'
                )}: list[PropertyDefinition] = ["
            );
            for (prop, record) in sorted(props.items()) {
                callbacks = ", ".join(
                    f"{side}={record[side]}"
                    for side in ("read", "write")
                    if side in record
                );
                tables.append(
                    f"    PropertyDefinition({jac_string(prop)}, PropertyCallbacks({callbacks}), 0, {jac_string(
                        record['doc']
                    )}),"
                );
            }
            tables.append("];");
        }
        return "\n".join(head + imports + [""] + self.lines + [""] + tables) + "\n";
    }
}

# The module's short name and its formatted clinic glue.
def generate(tree: Path, module: str, version: str) -> tuple[str, str] {
    sources = module_sources(tree, module);
    name = module.lstrip("_");
    emitter = Emitter(module=module, name=name);
    for pair in clinic_functions(tree, sources) {
        cls = pair[0];
        f = pair[1];
        if windows_only(CONDITIONS.get(id(f), "")) {
            emitter.windows.append(f.full_name);
            continue;
        }
        try {
            if f.kind.name in ("GETTER", "SETTER") {
                emitter.accessor(cls, f);
            } else {
                emitter.function(cls, f);
            }
        } except Unsupported as reason {
            emitter.skipped.append(f"{f.full_name}: {reason}");
        }
    }
    emitter.c_docs = {
        ** c_docstrings(tree, sources),
        ** c_macro_docstrings(sources),
        ** c_table_docs(tree, sources)
    };
    relative = [str(s.relative_to(tree)) for s in sources];
    return (name, emitter.render(relative, version));
}

def registered -> list[str] {
    if not REGISTRY.is_file() {
        return [];
    }
    return [
        line.split()[0]
        for line in REGISTRY.read_text().splitlines()
        if line.strip() and not line.startswith("#")
    ];
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate native Jac Argument Clinic glue"
    );
    parser.add_argument("modules", nargs="*");
    parser.add_argument("--check", action="store_true");
    parser.add_argument(
        "--out", type=Path, help="write here instead of the bindings tree"
    );
    args = parser.parse_args();
    version = pin()["version"];
    stale: list[str] = [];
    with tempfile.TemporaryDirectory() as scratch {
        tree = extract_tree(Path(scratch), ("Tools/clinic/", "Modules/"));
        rendered = [
            generate(tree, module, version) for module in args.modules or registered()
        ];
        targets = [(args.out or OUTPUT) / f"{name}.jac" for (name, _) in rendered];
        formatted = format_jac_many(
            [(text, target) for ((_, text), target) in zip(rendered, targets)]
        );
        for (target, text) in zip(targets, formatted) {
            if args.check {
                if not target.is_file() or target.read_text() != text {
                    stale.append(str(target.relative_to(REPO)));
                }
                continue;
            }
            target.parent.mkdir(parents=True, exist_ok=True);
            target.write_text(text);
            print(f"wrote {target}");
        }
    }
    if stale {
        sys.exit(
            "Stale clinic glue; rerun scripts/jacpython/gen_clinic.jac:\n  "
                + "\n  ".join(stale)
        );
    }
}
