"""Generate native Jac Argument Clinic glue for a Python extension module.

A C extension describes each function once, in a `/*[clinic input]` block,
and Tools/clinic generates the argument parsing that calls the handwritten
`<name>_impl` C function. JacPython keeps those signatures as Jac data,
scripts/jacpython/clinic/<name>.jac (see clinic_schema.jac), and this script
writes the Jac equivalent of the generated `Modules/clinic/<file>.c.h` from it:

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
The glue names everything it uses from other modules (the `_impl` functions,
the shared machinery of bindings/arguments.jac and bindings/converters.jac)
without imports: jaclang/archwire.jac wires each name into the module.

Converters without a generic Jac equivalent (posix's path_t, a module's own
converter functions) are called as convert_<name>(value, fname, label) and
imported from the module's Jac file, as C modules define their own converters.
Default values that name C macros are imported from the module's file too,
and a default read from the module state or the receiver
(`clinic_state()->ConnectionType`, `((pysqlite_Cursor *)self)->arraysize`)
is a module function over the receiver (`clinic_state_ConnectionType(receiver)`,
`self_arraysize(receiver)`). A parameter deprecated with `[from X.Y]` warns
as Tools/clinic's parser does. A clinic function whose `_impl` the C source
never defined (a clone kept for its docstring and PyMethodDef, like
`_sqlite3.connect`) contributes only `<c_basename>_doc`; the module binds it.
"""
import argparse;
import importlib;
import re;
import sys;
import from pathlib { Path }
import from common { BOOTSTRAP, REPO, RUNTIME, format_jac_many }
import from clinic_schema { Clinic, Function, Parameter }

glob OUTPUT: Path = RUNTIME / "bindings/clinic",
     # The signatures, one Clinic record per module.
     DATA: Path = Path(__file__).resolve().parent / "clinic",
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
         "": "",
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
             # the names the generated glue gives its own locals
             + " receiver stack count clinic_args cls result values unpacked"
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

# Converters the C API itself provides (not a module's own), which
# bindings/converters.jac supplies to every module.
glob API_CONVERTERS: set[str] = {"convert_PyUnicode_FSConverter"};

# Preprocessor symbols a JacPython build never defines: Windows's (it builds
# for Linux and macOS) and the debug build's (it is a release build). A
# clinic function whose #if needs one is not generated.
glob WINDOWS_SYMBOLS: set[str] = {
         "MS_WINDOWS",
         "MS_WINDOWS_DESKTOP",
         "MS_WINDOWS_APP",
         "MS_WINDOWS_SYSTEM",
         "_MSC_VER"
     },
     DEBUG_SYMBOLS: set[str] = {"Py_DEBUG"};

# The JacPython targets and the symbols only one of them defines; the other
# systems' symbols (and HAVE_CWAIT, HAVE_SPAWNV and HAVE_WSPAWNV, which only PC/pyconfig.h
# sets, VxWorks' HAVE_RTPSPAWN and the AIX and Solaris HAVE_PLOCK) are never
# defined on either.
glob PLATFORMS: list[str] = ["darwin", "linux"],
     PLATFORM_SYMBOLS: dict[str, str] = {
         "__APPLE__": "darwin",
         "__MACH__": "darwin",
         "__linux__": "linux"
     },
     OTHER_SYSTEM_SYMBOLS: set[str] = {
         "__FreeBSD__",
         "__DragonFly__",
         "__NetBSD__",
         "__OpenBSD__",
         "__sun",
         "__VXWORKS__",
         "__EMSCRIPTEN__",
         "__wasi__",
         "HAVE_CWAIT",
         "HAVE_SPAWNV",
         "HAVE_WSPAWNV",
         "HAVE_RTPSPAWN",
         "HAVE_PLOCK"
     };

# The targets on which a clinic #if condition can hold, every other feature
# test being free as in posix_condition().
def condition_platforms(condition: str) -> list[str] {
    if not condition {
        return list(PLATFORMS);
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
    fixed = WINDOWS_SYMBOLS
        | DEBUG_SYMBOLS
        | OTHER_SYSTEM_SYMBOLS
        | set(PLATFORM_SYMBOLS);
    features = [
        name
        for name in symbols
        if name not in fixed
    ];
    if len(features) > 12 or re.search(r"[<>=]", condition) {
        return list(PLATFORMS);
    }
    found: list[str] = [];
    for platform in PLATFORMS {
        holds = False;
        for choice in range(2 ** len(features)) {
            values: dict[str, bool] = {name: False for name in symbols};
            for name in symbols {
                if PLATFORM_SYMBOLS.get(name) == platform {
                    values[name] = True;
                }
            }
            for (bit, name) in enumerate(features) {
                values[name] = bool((choice >> bit) & 1);
            }
            try {
                holds = bool(eval(expression, {}, values));
            } except Exception {
                holds = True;
            }
            if holds {
                break;
            }
        }
        if holds {
            found.append(platform);
        }
    }
    return found;
}

def:priv tested_symbol(hit: any) -> str {
    return hit.group(1) or hit.group(2);
}

# Whether a clinic #if condition can hold on a POSIX release build: the
# `undefined` symbols (Windows's and Py_DEBUG) are undefined, and the
# condition holds for some choice of every other
# feature test (a function under !defined(HAVE_BROKEN_POLL) exists where poll
# works), since the module binding decides what a platform actually offers.
def posix_condition(
    condition: str, undefined: set[str] = WINDOWS_SYMBOLS | DEBUG_SYMBOLS
) -> bool {
    if not condition {
        return True;
    }
    # A comparison (SIZEOF_WCHAR_T == 4) is not evaluated; only a Windows
    # symbol in it decides.
    if re.search(r"[<>=]", condition) {
        return not any(name in condition for name in undefined);
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
        if name not in undefined
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

# JacPython builds only POSIX targets, where a function compiled only under a
# Windows condition does not exist.
def windows_only(condition: str) -> bool {
    return not posix_condition(condition);
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
        invokers: set[str] = set(),
        capi: set[str] = set(),
        qualified: bool = False,
        skipped: list[str] = [],
        windows: list[str] = [],
        elsewhere: list[str] = [],
        variants: list[str] = [],
        table_suffix: str = "",
        debug: list[str] = [],
        class_docs: dict[str, str] = {},
        c_docs: dict[str, str] = {},
        slow_only: bool = False,
        raise_free: bool = False,
        checked_converters: bool = False,
        function_docs: dict[str, str] = {},
        classes: dict[str, str] = {};

    def use(name: str) -> str {
        self.converters.add(name);
        return name;
    }

    def token_name(cls_name: str) -> str {
        return f"{cls_name}_token";
    }

    def table_name(cls: str) -> str {
        return (f"{cls}_methods" if cls else "module_methods") + self.table_suffix;
    }

    # The Jac expression for a parameter's default.
    def default_value(p: Parameter, jtype: str) -> str {
        initial = self.initializer(p);
        if initial {
            return initial;
        }
        c_default = p.c_default;
        py_default = p.py_default;
        none_default = p.default_kind == "value" and py_default is None;
        if jtype == "ptr[u8]" and (c_default == "NULL" or none_default) {
            return "ptr[u8]()";
        }
        if not c_default {
            if none_default {
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
            shown = repr(py_default)
                if p.default_kind == "value"
                else f"<{(p.default_kind or 'unspecified').capitalize()}>";
            raise Unsupported(f"default {shown}");
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
        # A value of the module state or of the receiver's own C fields: the
        # module computes it from the receiver.
        state = re.fullmatch(
            r"(?:\(\s*\w+\s*\*\s*\))?\s*clinic_state\(\)->(\w+)", text
        );
        if state is not None {
            name = "clinic_state_" + state.group(1);
            self.module_names.add(name);
            return f"{name}(receiver)";
        }
        field = re.fullmatch(r"\(\(\s*\w+\s*\*\s*\)\s*self\s*\)->(\w+)", text);
        if field is not None {
            name = "self_" + field.group(1);
            self.module_names.add(name);
            return f"{name}(receiver)";
        }
        # A C call over a C object (posix's fileno(stdout)), not over the
        # receiver: both are the module's.
        call = re.fullmatch(r"([A-Za-z_]\w*)\(\s*([A-Za-z_]\w*)\s*\)", text);
        if call is not None and call.group(2) not in ("self", "module", "type") {
            self.module_names.update([call.group(1), call.group(2)]);
            return f"{call.group(1)}({call.group(2)})";
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
        fname: str, p: Parameter, position: int, numbered: bool = False
    ) -> tuple[str, str, list[str]] {
        kind = p.converter;
        # getargs' own conversions (a format parser) number every argument.
        shown = p.name if p.kind != "POSITIONAL_ONLY" and not numbered else "";
        # Position 0 is clinic's METH_O argument, named only "argument". The
        # label is argument_label()'s text as a literal, so a call formats
        # nothing unless an argument fails to convert.
        label = jac_string(
            "argument"
                if position == 0
                else (f"argument '{shown}'" if shown else f"argument {position}")
        );
        where = f"{jac_string(fname)}, {label}";
        accept_names = set(p.accept);
        # The limited C API reports a mismatch with the type's %T name.
        qualified = ", True" if self.qualified else "";
        # Clinic records bitwise=True only as the mask format unit it selects.
        bitwise = p.format_unit in ("B", "H", "I", "k", "K");
        # object(converter=..., type=...): the named function converts into
        # the declared C type.
        through = p.convert_with;
        if kind == "object" and through {
            if through in SHARED_CONVERTERS {
                return (
                    jac_ctype(p.type),
                    self.use(SHARED_CONVERTERS[through]) + f"(value, {where})",
                    []
                );
            }
            custom = "convert_" + re.sub(r"\W", "_", through);
            self.module_names.add(custom);
            return (jac_ctype(p.type), f"{custom}(value, {where})", []);
        }
        if kind == "object" or kind in TYPED_OBJECTS {
            subclass = TYPED_OBJECTS[kind] if kind in TYPED_OBJECTS else p.subclass_of;
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
            # clinic_state() is the state of the receiver's module, and _ssl's
            # get_state_ctx(self)->Sock_Type is read from the receiver: a
            # check against such a type takes the receiver.
            if "clinic_state()" in subclass or re.search(r"\bself\b", subclass) {
                return (
                    "ptr[PyObject]",
                    "value",
                    [f"{check}(receiver, value, {where});"]
                );
            }
            return ("ptr[PyObject]", "value", [f"{check}(value, {where});"]);
        }
        # int(accept={str}) keeps its accepted types only as the "C" unit.
        if kind == "int" {
            # int(accept={str}) is clinic's "C" unit: one unicode character.
            if "str" in accept_names or p.format_unit == "C" {
                return (
                    "i32",
                    f"i32({self.use('convert_unicode_char')}(value, {where}))",
                    []
                );
            }
            return ("i32", self.use("convert_int") + "(value)", []);
        }
        if kind == "bool" {
            # An int default other than 0 or 1 (posix.link's -1, "not
            # given") keeps C's int variable.
            c_int_default = p.c_default.strip();
            if re.fullmatch(r"-?\d+", c_int_default)
                and c_int_default not in ("0", "1") {
                return ("i32", "i32(" + self.use("convert_bool") + "(value))", []);
            }
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
        # Without bitwise=True these are the C API's _PyLong_*_Converter.
        if kind
            in ("unsigned_short", "unsigned_int", "uint8", "uint16", "uint32", "uint64")
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
        unit = p.format_unit;
        if kind == "str" {
            # "s#" as clinic parses it for a METH_O function, with PyArg_Parse;
            # the _impl takes the C string and its size.
            if unit == "s#" and position == 0 and not p.encoding {
                return (
                    self.use("SizedText"),
                    self.use("convert_sized_str") + f"(value, {where})",
                    []
                );
            }
            if unit not in ("s", "z") or p.encoding {
                raise Unsupported(f"str converter '{unit}'");
            }
            accepts_none = unit == "z";
            # A str that may be NULL (None accepted, or a NULL C default) stays
            # C's `const char *`: the argument's UTF-8, NULL when absent.
            if accepts_none or p.c_default == "NULL" {
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
        named = p.convert_with;
        # Converters the interpreter itself provides (ceval.c), shared by
        # every module that names them.
        if isinstance(named, str) and named in SHARED_CONVERTERS {
            return (
                jac_ctype(p.type),
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
        if custom in API_CONVERTERS {
            self.use(custom);
            return (jac_ctype(p.type), f"{custom}(value, {where})", []);
        }
        self.module_names.add(custom);
        # A converter that fills a C struct its initializer macro sets up
        # (posix's path_t and PATH_T_INITIALIZE_P) is handed that initializer,
        # which also stands for the omitted argument.
        initial = self.initializer(p);
        if initial {
            return (jac_ctype(p.type), f"{custom}(value, {initial})", []);
        }
        # Keyword options the converter keeps (confname's `table`, the name
        # of a module attribute) follow the error context; a custom parse
        # that hands the converter the module gets the receiver first.
        options = "".join(f", {name}" for name in self.converter_options(p));
        module = "receiver, " if p.takes_module else "";
        return (jac_ctype(p.type), f"{custom}({module}value, {where}{options})", []);
    }

    # The C initializer macro call a by-reference converter defaults to, in
    # Jac, or "" when it has none.
    def initializer(p: Parameter) -> str {
        if not p.by_reference {
            return "";
        }
        text = p.c_default.strip();
        call = re.fullmatch(r"([A-Za-z_]\w*)\((.*)\)", text);
        if call is None {
            return "";
        }
        arguments: list[str] = [];
        for argument in re.findall(r'"(?:[^"\\]|\\.)*"|[^,\s][^,]*', call.group(2)) {
            argument = argument.strip();
            if re.fullmatch(r"[A-Za-z_]\w*", argument) {
                self.module_names.add(argument);
            }
            arguments.append(argument);
        }
        self.module_names.add(call.group(1));
        return f"{call.group(1)}({', '.join(arguments)})";
    }

    # A module converter's own keyword options: the names of C objects of
    # the module, and string literals as they are.
    def converter_options(p: Parameter) -> list[str] {
        for option in p.options {
            if re.fullmatch(r"[A-Za-z_]\w*", option) {
                self.module_names.add(option);
            }
        }
        return list(p.options);
    }

    # The PyMethodDef flags and getargs parser clinic generates for `f`.
    # tp_new and tp_init keep the flags clinic chose internally; they only
    # select the parser.
    def calling_convention(f: Function) -> tuple[int, str] {
        if not f.flags {
            raise Unsupported("no clinic parser");
        }
        names = [name.strip() for name in f.flags.split("|")];
        flags = 0;
        for name in names {
            if name not in METHOD_FLAGS {
                raise Unsupported(f"flag {name}");
            }
            flags = flags | METHOD_FLAGS[name];
        }
        # A parse no arguments.jac parser does (optional groups, getargs'
        # keyword format parsing) names why instead.
        if not f.parser.startswith("PARSE_") {
            raise Unsupported(f.parser);
        }
        return (flags, f.parser);
    }

    # The deprecation warnings Tools/clinic's parser emits for `f`: CallSignature
    # options for the positional and keyword `[from X.Y]` rules, with the
    # messages its generated parser has.
    def deprecations(f: Function, params: list[Parameter]) -> list[str] {
        options: list[str] = [];
        positional = [
            i
            for (i, p) in enumerate(params)
            if p.deprecated_positional
        ];
        keyword = [
            i
            for (i, p) in enumerate(params)
            if p.deprecated_keyword
        ];
        if positional {
            message = f.positional_warning;
            options.append(f"positional_warning={jac_string(message)}");
            options.append(
                f"positional_warn_range=({positional[0]}, {positional[-1] + 1})"
            );
        }
        if keyword {
            message = f.keyword_warning;
            # deprecate_keyword_use(): a required parameter passed by keyword
            # warns alone; an optional one after it only when given.
            required = -1;
            optional: list[int] = [];
            for i in keyword {
                if params[i].is_optional() {
                    optional.append(i);
                } else {
                    required = i;
                    optional = [];
                }
            }
            options.append(f"keyword_warning={jac_string(message)}");
            options.append(f"keyword_warn_required={required}");
            options.append(f"keyword_warn_optional={optional}");
        }
        return options;
    }

    def function(cls: str, f: Function) {
        kind = f.kind;
        self.slow_only = False;
        # A clone kept only for its docstring and method table entry: the C
        # module binds it by hand.
        if kind not in ("METHOD_NEW", "METHOD_INIT") and f.bound_by_hand {
            doc = f.docstring or "";
            if doc.split("\n")[-1] == "--" {
                doc += "\n\n";
            }
            self.function_docs[f.c_basename] = doc;
            return;
        }
        params = list(f.params);
        params.pop(0);
        uses_class = bool(params) and params[0].converter == "defining_class";
        if uses_class {
            params.pop(0);
            self.tokens.add(cls);
        }
        if any(p.group for p in params) {
            raise Unsupported("optional groups");
        }
        varpos = [
            p
            for p in params
            if p.converter in ("varpos_tuple", "varpos_array")
        ];
        if varpos {
            self.varargs_function(cls, f, params, varpos[0]);
            return;
        }
        convention = self.calling_convention(f);
        flags = convention[0];
        parser = convention[1];
        # The limited C API's clinic converters name a mismatched argument's
        # type with %T; getargs' format conversions use tp_name.
        self.qualified = f.limited_capi and parser != "PARSE_FORMAT_KEYWORDS";
        # getargs converts as it binds: a binding error waits for the
        # arguments before it to convert.
        stepwise = parser == "PARSE_FORMAT_KEYWORDS";
        base = f.c_basename;
        impl_name = base + "_impl";
        self.impls.add(impl_name);
        fname = (cls or f.name) if kind in ("METHOD_NEW", "METHOD_INIT") else f.name;
        ret_kind = f.returns;
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
        # A raise-free module's impls report errors as C does and never raise
        # boundary_failure, so a call whose arguments need no conversion that
        # can raise (an object taken as it is, an exact int read as a
        # Py_ssize_t) runs this body without the exception frame: `direct`
        # when every parameter allows it, for the stack indices in
        # `direct_ints` holding exact ints.
        direct: list[str] = [];
        direct_ok = self.raise_free;
        direct_ints: list[int] = [];
        if uses_class {
            finder = "defining_class_of_type"
                if kind == "CLASS_METHOD"
                else "defining_class";
            # Borrowed, as METH_METHOD's defining class is.
            body.append(f"cls = {self.use(finder)}(receiver, {self.token_name(cls)});");
            if direct_ok {
                direct += [
                    f"cls = {self.use(finder + '_or_null')}(receiver, {self.token_name(
                        cls
                    )});",
                    "if cls == NULL {",
                    "    return NULL;",
                    "}"
                ];
            }
            call_args.append("cls");
        }
        # A METH_O argument is named only "argument" in type errors.
        meth_o = bool(flags & METHOD_FLAGS["METH_O"]);
        for (i, p) in enumerate(params) {
            var = local(p.name);
            position = i + 1;
            # Where parameter i's value is and whether it was passed: the
            # METH_O argument, the stepwise parser's BoundArguments, or the
            # bound array (shorter than the parameters on the fast path).
            slot = f"clinic_args[{i}]";
            present = f"count > {i} and clinic_args[{i}] != NULL";
            if meth_o {
                slot = "value";
                present = "True";
            } elif stepwise {
                slot = f"args.values[{i}]";
                present = f"{slot} != NULL";
            }
            if stepwise {
                body.append(f"args.reach({i});");
            }
            # Py_ssize_t(accept={int, NoneType}) and an object parsed by
            # _Py_convert_optional_to_ssize_t (mmap's read(n)) are one converter.
            optional_ssize = (p.converter == "Py_ssize_t" and "NoneType" in p.accept)
                or p.convert_with == "_Py_convert_optional_to_ssize_t";
            if optional_ssize {
                direct_ok = False;
                fallback = self.default_value(p, "i64") if p.is_optional() else "0";
                body.append(f"{var}: i64 = {fallback};");
                body.append(
                    f"if {present} {{ {var} = {self.use('convert_optional_ssize')}({slot}, {fallback}); }}"
                );
                call_args.append(var);
                continue;
            }
            converted = self.convert(fname, p, 0 if meth_o else position, stepwise);
            jtype = converted[0];
            expr = converted[1];
            checks = converted[2];
            # A module's own converter types its value itself (a C enum, a
            # `const char *` that may be NULL): an omitted argument keeps the
            # C default in the same variable.
            custom = expr.startswith("convert_")
                and expr.split("(")[0] in self.module_names;
            if direct_ok {
                direct_ok = self.direct_argument(
                    p, i, var, (jtype, expr, checks), meth_o, direct, direct_ints
                );
            }
            if p.is_optional() and custom {
                fallback = self.default_value(p, jtype);
                # The untyped variable takes a literal default in the
                # converter's own type (posix.mknod's dev_t device=0).
                if re.fullmatch(r"-?\d+(\.\d+)?", fallback)
                    and re.fullmatch(r"[iu](8|16|32|64)|f(32|64)", jtype) {
                    fallback = f"{jtype}({fallback})";
                }
                if slot != "value" {
                    body.append(f"value = {slot} if {present} else NULL;");
                }
                body.append(f"{var} = {expr} if value != NULL else {fallback};");
            } elif p.is_optional() {
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
                body.append(f"if {present} {{");
                body.append(f"    value = {slot};");
                body += [f"    {c}" for c in checks];
                body.append(f"    {var} = {expr};");
                body.append("}");
            } else {
                if slot != "value" {
                    body.append(f"value = {slot};");
                }
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
            if jtype != "BufferArgument" and p.releases {
                direct_ok = False;
                self.api.add("jacpy_release");
                body.append(RELEASE + f"jacpy_release({var});");
            }
            if jtype == "SizedText" {
                call_args += [f"{var}.data", f"{var}.size"];
            } else {
                call_args.append(var);
            }
        }
        if stepwise {
            body.append(f"args.reach({len(params)});");
        }
        call = f"{impl_name}({', '.join(call_args)})";
        result = f"{wrap}({call})" if wrap else call;
        body.append(f"return {result};");
        direct.append(f"return {result};");
        sig = f"{base}_signature";
        if parser != "PARSE_GIVEN" {
            names = ", ".join(jac_string(p.name) for p in params);
            options = [
                f"{jac_string(fname)}",
                f"[{names}]",
                str(f.min_pos),
                str(f.max_pos),
                str(f.pos_only)
            ];
            if f.min_kw_only {
                options.append(f"keyword_required={f.min_kw_only}");
            }
            warnings = self.deprecations(f, params);
            # Tools/clinic's deprecation checks run in its parser, so a
            # function that warns always binds through the signature.
            self.slow_only = bool(warnings);
            options += warnings;
            options.append(f"parser={self.parse_constant(parser)}");
            self.lines.append(
                f"glob:priv {sig} = {self.invoker('CallSignature')}({', '.join(
                    options
                )});"
            );
        }
        if stepwise {
            self.invoker("BoundArguments");
            self.lines.append(
                f"def:priv {base}_bound(args: BoundArguments) -> ptr[PyObject] {{"
            );
            self.lines.append("    receiver = args.context;");
            self.lines += nest_releases(body, "    ");
            self.lines.append("}");
        } elif kind in ("METHOD_NEW", "METHOD_INIT")
            or not (meth_o or flags & METHOD_FLAGS["METH_NOARGS"]) {
            self.lines.append(
                f"def:priv {base}_bound(receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64) -> ptr[PyObject] {{"
            );
            if params {
                self.lines.append("    clinic_args = stack.view(count);");
            }
            self.lines += self.guarded(body, "    ");
            self.lines.append("}");
        }
        # Tools/clinic's deprecation warnings run in its parser; a shared
        # return converter reports as the impl does.
        direct_ok = direct_ok
            and not stepwise
            and not self.slow_only
            and (
                not wrap
                or wrap in RETURNS.values()
                or (self.checked_converters and wrap in self.module_names)
            )
            and kind not in ("METHOD_NEW", "METHOD_INIT");
        if direct_ok
            and not (meth_o or flags & METHOD_FLAGS["METH_NOARGS"])
            and flags & METHOD_FLAGS["METH_FASTCALL"] {
            self.lines.append(
                f"def:priv {base}_direct(receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64) -> ptr[PyObject] {{"
            );
            if params {
                self.lines.append("    clinic_args = stack.view(count);");
            }
            self.lines += ["    " + line for line in direct];
            self.lines.append("}");
        }
        doc = f.docstring or "";
        # A signature-only docstring ends with the blank line the
        # __text_signature__ getter expects, as Tools/clinic writes it.
        if doc.split("\n")[-1] == "--" {
            doc += "\n\n";
        }
        if kind in ("METHOD_NEW", "METHOD_INIT") and cls {
            self.class_docs[cls] = doc;
        }
        # Clinic's self_type_check: a tp_new/tp_init that refuses arguments
        # does so only for the class or a subclass keeping the other slot.
        type_check = "";
        if f.self_type_check and cls and self.classes.get(cls) {
            self.tokens.add(cls);
            finder = "new_checks_arguments"
                if kind == "METHOD_NEW"
                else "init_checks_arguments";
            subject = "type" if kind == "METHOD_NEW" else "receiver";
            type_check = f", checked={self.use(finder)}({subject}, {self.token_name(
                cls
            )})";
        }
        invoke_args = "invoke" if stepwise else "invoke_tuple";
        # A keyword-capable parser binds a call with keywords into argsbuf on
        # the C stack, as clinic's _PyArg_UnpackKeywords does.
        if not stepwise and not self.slow_only and parser == "PARSE_KEYWORDS" {
            invoke_args = "invoke_mapping";
        }
        if kind == "METHOD_NEW" {
            self.lines.append(
                f"def:pub {base}_new(type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]) -> ptr[PyObject] {{"
            );
            if not stepwise {
                self.lines += self.tuple_fast_path(parser, f, base, "type");
            }
            self.lines.append(
                f"    return {self.invoker(invoke_args)}({sig}, args, kwargs, {base}_bound, type{type_check});"
            );
            self.lines.append("}");
            self.hooks.append(f"{base}_new");
            return;
        }
        if kind == "METHOD_INIT" {
            self.lines.append(
                f"def:pub {base}_init(receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]) -> i32 {{"
            );
            arity = [] if stepwise else self.tuple_arity(parser, f);
            if arity {
                self.api.add("jacpy_dict_size");
                self.api.add("jacpy_tuple_items");
                self.api.add("PyTuple_Size");
                self.lines += [
                    "    result: ptr[PyObject] = NULL;",
                    "    bound = False;",
                    "    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {",
                    "        size = PyTuple_Size(args);",
                    f"        if size >= {arity[0]} and size <= {arity[1]} {{",
                    "            bound = True;",
                    f"            result = {base}_bound(receiver, jacpy_tuple_items(args), size);",
                    "        }",
                    "    }",
                    "    if not bound {"
                ];
                self.lines += [
                    f"        result = {self.invoker(invoke_args)}({sig}, args, kwargs, {base}_bound, receiver{type_check});",
                    "    }"
                ];
            } else {
                self.lines.append(
                    f"    result = {self.invoker(invoke_args)}({sig}, args, kwargs, {base}_bound, receiver{type_check});"
                );
            }
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
        # The callback the runtime's call machinery invokes for these flags.
        fast = bool(flags & METHOD_FLAGS["METH_FASTCALL"]);
        keywords = bool(flags & METHOD_FLAGS["METH_KEYWORDS"]);
        head = f"def:priv {base}_call(receiver: ptr[PyObject], ";
        if meth_o or flags & METHOD_FLAGS["METH_NOARGS"] {
            # The runtime's call checked the arity: convert the argument in place.
            argument = "value" if meth_o else "unused";
            self.lines.append(head + f"{argument}: ptr[PyObject]) -> ptr[PyObject] {{");
            if direct_ok {
                self.lines += ["    " + line for line in direct];
            } else {
                self.lines += self.guarded(body, "    ");
            }
            callback = "positional";
        } elif fast and stepwise {
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
        } elif fast {
            # The vectorcall stack is the bound array when clinic's own fast
            # path applies; otherwise the signature's parser binds it.
            kwnames = ", kwnames: ptr[PyObject]" if keywords else "";
            self.lines.append(
                head
                    + f"args: ptr[ptr[PyObject]], nargs: i64{kwnames}) -> ptr[PyObject] {{"
            );
            if parser == "PARSE_POSITIONAL" and not self.slow_only {
                # The count is checked inline; only a bad one calls out to
                # say so.
                outside = f"nargs > {f.max_pos}";
                if f.min_pos > 0 {
                    outside = f"nargs < {f.min_pos} or " + outside;
                }
                self.lines.append(
                    f"    if ({outside}) and not {self.invoker('check_positional')}({jac_string(
                        fname
                    )}, int(nargs), {f.min_pos}, {f.max_pos}) {{"
                );
                self.lines.append("        return NULL;");
                self.lines.append("    }");
                self.lines += self.bind_stack(base, direct_ok, direct_ints, "    ");
            } else {
                fast_path = self.stack_fast_path(parser, f, keywords);
                if fast_path {
                    self.lines.append(f"    if {fast_path} {{");
                    self.lines += self.bind_stack(
                        base, direct_ok, direct_ints, "        "
                    );
                    self.lines.append("    }");
                }
                # A call with keywords binds into argsbuf on the C stack, as
                # clinic's _PyArg_UnpackKeywords does; the parser reports one
                # that does not bind.
                invoke_stack = "invoke_stack";
                if parser == "PARSE_KEYWORDS" and keywords and not self.slow_only {
                    invoke_stack = "invoke_keywords";
                }
                self.lines.append(
                    f"    return {self.invoker(invoke_stack)}({sig}, args, nargs, {'kwnames'
                        if keywords
                        else 'NULL'}, {base}_bound, receiver);"
                );
            }
            callback = "fast_keywords" if keywords else "fast";
        } elif keywords {
            self.lines.append(
                head + "args: ptr[PyObject], kwargs: ptr[PyObject]) -> ptr[PyObject] {"
            );
            if not stepwise {
                self.lines += self.tuple_fast_path(parser, f, base, "receiver");
            }
            self.lines.append(
                f"    return {self.invoker(invoke_args)}({sig}, args, kwargs, {base}_bound, receiver);"
            );
            callback = "keywords";
        } else {
            raise Unsupported(f"calling convention {f.flags}");
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
    def varargs_function(
        cls: str, f: Function, params: list[Parameter], varpos: Parameter
    ) {
        if len(params) != 1 or f.kind != "CALLABLE" {
            raise Unsupported("*args with other parameters");
        }
        flags = 0;
        for name in f.flags.split("|") {
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
        if varpos.converter == "varpos_tuple" {
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

    # Add parameter `index` of a raise-free module's call to its `direct`
    # body if its conversion (`converted`) cannot raise: an object is taken as
    # it is, a Py_ssize_t read with PyLong_AsSsize_t from an exact int (whose
    # index is added to `ints`). False when the call needs its conversions.
    def direct_argument(
        p: any,
        index: int,
        var: str,
        converted: tuple[str, str, list[str]],
        meth_o: bool,
        direct: list[str],
        ints: list[int]
    ) -> bool {
        jtype = converted[0];
        expr = converted[1];
        slot = "value" if meth_o else f"clinic_args[{index}]";
        present = f"count > {index}";
        if jtype == "ptr[PyObject]" and expr == "value" and not converted[2] {
            if meth_o or not p.is_optional() {
                direct.append(f"{var}: ptr[PyObject] = {slot};");
            } else {
                direct.append(
                    f"{var}: ptr[PyObject] = {self.default_value(p, jtype)};"
                );
                direct += [f"if {present} {{", f"    {var} = {slot};", "}"];
            }
            return True;
        }
        if jtype == "f64" and expr == "convert_double(value)" {
            self.api.add("PyFloat_AsDouble");
            if meth_o or not p.is_optional() {
                direct += [
                    f"{var}: f64 = PyFloat_AsDouble({slot});",
                    f"if {var} == -1.0 and {self.use('failed')}() {{",
                    "    return NULL;",
                    "}"
                ];
                return True;
            }
            return False;
        }
        # A module whose converters report failure as C's do (the error
        # indicator, never boundary_failure) converts a required argument
        # in place and checks the indicator, as clinic's glue does.
        if self.checked_converters
            and expr.startswith("convert_")
            and expr.split("(")[0] in self.module_names
            and not converted[2]
            and (meth_o or not p.is_optional()) {
            if not meth_o {
                direct.append(f"value = {slot};");
            }
            direct += [
                f"{var} = {expr};",
                f"if {self.use('failed')}() {{",
                "    return NULL;",
                "}"
            ];
            return True;
        }
        if jtype == "i64" and expr == "convert_ssize(value)" and not meth_o {
            self.api.add("PyLong_AsSsize_t");
            fallback = self.default_value(p, jtype) if p.is_optional() else "0";
            direct += [
                f"{var}: i64 = {fallback};",
                f"if {present} {{",
                f"    {var} = PyLong_AsSsize_t({slot});",
                f"    if {var} == -1 and {self.use('failed')}() {{",
                "        return NULL;",
                "    }",
                "}"
            ];
            ints.append(index);
            return True;
        }
        return False;
    }

    # The vectorcall fast path's call once the stack binds as it is: the
    # direct body when its exact-int arguments are, else the bound one.
    def bind_stack(
        base: str, direct_ok: bool, ints: list[int], indent: str
    ) -> list[str] {
        bound = f"return {base}_bound(receiver, args, nargs);";
        if not direct_ok {
            return [indent + bound];
        }
        call = f"return {base}_direct(receiver, args, nargs);";
        if not ints {
            return [indent + call];
        }
        check = " and ".join(
            f"{self.use('exact_int_at')}(args, nargs, {i})" for i in ints
        );
        return [
            f"{indent}if {check} {{",
            f"{indent}    {call}",
            f"{indent}}}",
            indent + bound
        ];
    }

    # `body` inside the exception region every conversion and impl may
    # raise boundary_failure from, with its releases nested.
    def guarded(body: list[str], indent: str) -> list[str] {
        self.capi.add("boundary_failure");
        return [indent + "try {"]
            + nest_releases(body, indent + "    ")
            + [
                indent + "} except boundary_failure {",
                indent + "    return NULL;",
                indent + "}"
            ];
    }

    # The condition under which a vectorcall's stack binds as it is: clinic's
    # `kwnames == NULL && minpos <= nargs && nargs <= maxpos` for
    # _PyArg_UnpackKeywords, no arguments at all for a parameterless
    # defining-class method.
    def stack_fast_path(parser: str, f: Function, keywords: bool) -> str {
        if self.slow_only {
            return "";
        }
        no_keywords = "kwnames == NULL and " if keywords else "";
        if parser == "PARSE_KEYWORDS" and not f.min_kw_only {
            return f"{no_keywords}nargs >= {f.min_pos} and nargs <= {f.max_pos}";
        }
        if parser == "PARSE_NO_ARGUMENTS" {
            return f"{no_keywords}nargs == 0";
        }
        return "";
    }

    # The positional counts a tuple-and-dict call without keywords binds as
    # its tuple's items: the parser's own arity, when it has one to check.
    def tuple_arity(parser: str, f: Function) -> list[int] {
        if self.slow_only {
            return [];
        }
        if parser in ("PARSE_KEYWORDS", "PARSE_POSITIONAL", "PARSE_FORMAT")
            and not f.min_kw_only {
            return [f.min_pos, f.max_pos];
        }
        if parser == "PARSE_NOTHING" {
            return [0, 0];
        }
        return [];
    }

    def tuple_fast_path(
        parser: str, f: Function, base: str, receiver: str
    ) -> list[str] {
        arity = self.tuple_arity(parser, f);
        if not arity {
            return [];
        }
        self.api.add("jacpy_dict_size");
        self.api.add("jacpy_tuple_items");
        self.api.add("PyTuple_Size");
        return [
            "    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {",
            "        size = PyTuple_Size(args);",
            f"        if size >= {arity[0]} and size <= {arity[1]} {{",
            f"            return {base}_bound({receiver}, jacpy_tuple_items(args), size);",
            "        }",
            "    }"
        ];
    }

    def invoker(name: str) -> str {
        self.invokers.add(name);
        return name;
    }

    def parse_constant(name: str) -> str {
        self.invokers.add(name);
        return name;
    }

    def accessor(cls: str, f: Function) {
        base = f.c_basename;
        # Clinic names accessor impls <c_basename>_get_impl / _set_impl.
        impl_name = base + ("_get_impl" if f.kind == "GETTER" else "_set_impl");
        self.impls.add(impl_name);
        record = self.getsets.setdefault(self.table_name(cls), {}).setdefault(
            f.name, {"doc": ""}
        );
        if f.kind == "GETTER" {
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
        # A signature only the slow path uses goes with it: a positional-only
        # METH_FASTCALL function checks its arity inline.
        text = "\n".join(self.lines);
        kept: list[str] = [];
        for line in self.lines {
            declared = re.match(r"glob:priv (\w+_signature) = ", line);
            if declared
                and len(re.findall(r"\b" + declared.group(1) + r"\b", text)) == 1 {
                continue;
            }
            kept.append(line);
        }
        self.lines = kept;
        text = "\n".join(self.lines);
        self.invokers = {
            name
            for name in self.invokers
            if re.search(r"\b" + name + r"\b", text)
        };
        head = [
            f'"""Argument Clinic glue for {self.module}: signatures, converters and tables.',
            "",
            f"Generated by scripts/jacpython/gen_clinic.jac from Python {version}",
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
        if self.elsewhere {
            head += ["", "Compiled only for other systems, so absent here:"];
            head += [f"    {item}" for item in self.elsewhere];
        }
        if self.variants {
            head += [
                "",
                "One definition per target (names and tables suffixed _<target>;",
                "the binding installs its own target's):"
            ];
            head += [f"    {item}" for item in self.variants];
        }
        if self.debug {
            head += ["", "Compiled only in debug (Py_DEBUG) builds, so absent here:"];
            head += [f"    {item}" for item in self.debug];
        }
        head.append('"""');
        tables: list[str] = [];
        for (cls_name, doc) in sorted(self.class_docs.items()) {
            tables.append(f"glob {cls_name}_doc: str = {jac_string(doc)};");
        }
        # A clinic clone's docstring (a function the module binds by hand).
        taken = {f"{cls_name}_doc" for cls_name in self.class_docs};
        for (base, doc) in sorted(self.function_docs.items()) {
            if f"{base}_doc" not in taken {
                tables.append(f"glob {base}_doc: str = {jac_string(doc)};");
                taken.add(f"{base}_doc");
            }
        }
        # The C module's own PyDoc_STRVAR docstrings, under their C names.
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
        return "\n".join(head + [""] + self.lines + [""] + tables) + "\n";
    }
}

# A module's signatures: the Clinic record of scripts/jacpython/clinic/<name>.jac.
def signatures(module: str) -> Clinic {
    name = data_name(module);
    if not (DATA / f"{name}.jac").is_file() {
        sys.exit(f"{module} has no clinic data: {DATA / name}.jac");
    }
    if str(DATA.parent) not in sys.path {
        sys.path.insert(0, str(DATA.parent));
    }
    return importlib.import_module(f"clinic.{name}").CLINIC;
}

# The module's short name and its formatted clinic glue.
def generate(module: str) -> tuple[str, str] {
    clinic = signatures(module);
    name = data_name(module);
    emitter = Emitter(
        module=module,
        name=name,
        raise_free="raise-free" in registry_options().get(module, []),
        checked_converters="checked-converters" in registry_options().get(module, []),
        classes=dict(clinic.classes)
    );
    # A function C defines once per system (#ifdef __APPLE__ ... #else): the
    # definitions that can exist on a JacPython target, by full name, kind
    # (a getter and its setter share a name) and C name (a clone under
    # another C name, like _io's _Buffered.flush, is a function of its own).
    defined: dict[str, list[Function]] = {};
    for f in clinic.functions {
        if not windows_only(f.condition) and condition_platforms(f.condition) {
            defined.setdefault(f"{f.full_name}:{f.kind}:{f.c_basename}", []).append(f);
        }
    }
    for f in clinic.functions {
        condition = f.condition;
        if windows_only(condition) {
            if posix_condition(condition, WINDOWS_SYMBOLS) {
                emitter.debug.append(f.full_name);
            } else {
                emitter.windows.append(f.full_name);
            }
            continue;
        }
        targets = condition_platforms(condition);
        if not targets {
            emitter.elsewhere.append(f.full_name);
            continue;
        }
        emitter.table_suffix = "";
        if len(defined.get(f"{f.full_name}:{f.kind}:{f.c_basename}", [])) > 1 {
            if len(targets) != 1 {
                sys.exit(f"{f.full_name} has definitions for more than one target");
            }
            emitter.table_suffix = "_" + targets[0];
            emitter.variants.append(f"{f.full_name}: {targets[0]}");
            f.c_basename = f.c_basename + emitter.table_suffix;
        }
        try {
            if f.kind in ("GETTER", "SETTER") {
                emitter.accessor(f.cls, f);
            } else {
                emitter.function(f.cls, f);
            }
        } except Unsupported as reason {
            emitter.skipped.append(f"{f.full_name}: {reason}");
        }
    }
    emitter.c_docs = dict(clinic.docs);
    return (name, emitter.render(clinic.sources, clinic.version));
}

# A registry line may name the module's Jac files after its module name
# (`_hashlib hashopenssl`) when the default, the name without its leading
# underscore, is taken by a shared module.
def jac_names -> dict[str, str] {
    if not REGISTRY.is_file() {
        return {};
    }
    names: dict[str, str] = {};
    for line in REGISTRY.read_text().splitlines() {
        parts = line.split();
        # A Jac name is an identifier; `raise-free` and other options are not.
        if len(parts) > 1
            and not line.startswith("#")
            and re.fullmatch(r"\w+", parts[1]) {
            names[parts[0]] = parts[1];
        }
    }
    return names;
}

# The name of a module's Jac files: its clinic data, glue and module.
def data_name(module: str) -> str {
    return jac_names().get(module, module.lstrip("_"));
}

def registered -> list[str] {
    return list(registry_options());
}

# The registered modules and the options that follow each name.
def registry_options -> dict[str, list[str]] {
    if not REGISTRY.is_file() {
        return {};
    }
    return {
        line.split()[0]: line.split()[1:]
        for line in REGISTRY.read_text().splitlines()
        if line.strip() and not line.startswith("#")
    };
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
    stale: list[str] = [];
    rendered = [generate(module) for module in args.modules or registered()];
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
    if stale {
        sys.exit(
            "Stale clinic glue; rerun scripts/jacpython/gen_clinic.jac:\n  "
                + "\n  ".join(stale)
        );
    }
}
