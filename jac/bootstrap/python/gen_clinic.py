"""Generate native Jac Argument Clinic glue for a CPython extension module.

CPython describes each extension function once, in a `/*[clinic input]` block,
and Tools/clinic generates the argument parsing that calls the handwritten
`<name>_impl` C function. This script runs that same parser (Tools/clinic from
the checksum-pinned CPython archive) and writes the Jac equivalent of the
generated `Modules/clinic/<file>.c.h`:

    python3 jac/bootstrap/python/gen_clinic.py _zoneinfo          # one module
    python3 jac/bootstrap/python/gen_clinic.py --check             # all, fail on drift

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
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tarfile
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from jac_format import format_jac  # noqa: E402

HERE = Path(__file__).resolve().parent
JAC = HERE.parents[1]
REPO = JAC.parent
OUTPUT = JAC / "jaclang/runtime/python/bindings/clinic"
MODULES = "jaclang.runtime.python.modules"
REGISTRY = HERE / "jacpython-clinic.txt"

METH_VARARGS, METH_KEYWORDS, METH_NOARGS, METH_O = 1, 2, 4, 8
METH_CLASS, METH_STATIC = 16, 32

SCALAR = {
    "int": "i32", "unsigned int": "u32", "long": "i64", "unsigned long": "u64",
    "long long": "i64", "unsigned long long": "u64", "Py_ssize_t": "i64",
    "size_t": "u64", "double": "f64", "float": "f32", "char": "i8",
    "unsigned char": "u8", "unsigned short": "u16", "short": "i16",
    "uint32_t": "u32", "uint16_t": "u16", "uint64_t": "u64", "int32_t": "i32",
    "int64_t": "i64", "intptr_t": "i64", "Py_UCS4": "u32", "Py_off_t": "i64",
    "pid_t": "i32", "uid_t": "u32", "gid_t": "u32", "dev_t": "u64", "mode_t": "u32",
}
BUILTIN_TYPES = {
    "&PyUnicode_Type": ("jacpy_is_unicode", "str"), "&PyTuple_Type": ("jacpy_is_tuple", "tuple"),
    "&PyDict_Type": ("jacpy_is_dict", "dict"), "&PyList_Type": ("jacpy_is_list", "list"),
    "&PyBytes_Type": ("jacpy_is_bytes", "bytes"), "&PyType_Type": ("jacpy_is_type", "type"),
    "&PyLong_Type": ("jacpy_is_long", "int"), "&PyFloat_Type": ("jacpy_is_float", "float"),
    "&PyByteArray_Type": ("jacpy_is_bytearray", "bytearray"),
}
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
    "args", "kwargs", "module", "value", "arg",
}


def local(name: str) -> str:
    return name + "_" if name in KEYWORDS else name


def jac_string(text: str) -> str:
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")
    return f'"{escaped}"'


class Unsupported(Exception):
    pass


def pinned_tree(work: Path) -> Path:
    pin = json.loads((HERE / "sources.json").read_text())["cpython"]
    archive = JAC / ".python-build/jacpython/sources" / f"{pin['sha256']}.tar.gz"
    if not archive.is_file():
        sys.exit(f"Pinned CPython archive not found: {archive}; run a JacPython build once")
    if hashlib.sha256(archive.read_bytes()).hexdigest() != pin["sha256"]:
        sys.exit(f"{archive} does not match the pinned SHA256")
    with tarfile.open(archive) as bundle:
        members = [m for m in bundle.getmembers()
                   if m.name.split("/", 1)[-1].startswith(("Tools/clinic/", "Modules/"))]
        bundle.extractall(work, members=members, filter="data")
    return next(work.iterdir())


def module_sources(tree: Path, module: str) -> list[Path]:
    for setup in ("Modules/Setup.stdlib.in", "Modules/Setup.bootstrap.in"):
        for line in (tree / setup).read_text().splitlines():
            line = re.sub(r"^@[A-Z0-9_]+@", "", line.strip())
            parts = line.split()
            if parts and parts[0] == module:
                return [tree / "Modules" / p for p in parts[1:] if p.endswith(".c")]
    sys.exit(f"{module} is not built by Modules/Setup.stdlib.in or Setup.bootstrap.in")


def clinic_functions(tree: Path, sources: list[Path]):
    sys.path.insert(0, str(tree / "Tools/clinic"))
    from libclinic.app import Clinic
    from libclinic.clanguage import CLanguage
    found = []
    for source in sources:
        text = source.read_text()
        if "[clinic input]" not in text:
            continue
        clinic = Clinic(CLanguage(str(source)), filename=str(source), verify=False, limited_capi=False)
        clinic.parse(text)
        for module in clinic.modules.values():
            found += [(None, f) for f in module.functions]
            stack = list(module.classes.values())
            while stack:
                cls = stack.pop(0)
                found += [(cls, f) for f in cls.functions]
                stack += list(cls.classes.values())
    return found


def jac_ctype(ctype: str) -> str:
    base = " ".join(ctype.replace("const ", "").replace("*", " * ").split())
    if base in SCALAR:
        return SCALAR[base]
    if base.endswith("*") and base[:-1].strip() in ("PyObject", "PyTypeObject") or base.endswith("Object *"):
        return "ptr[PyObject]"
    if base in ("char *",):
        return "str"
    if base == "Py_buffer":
        return "BufferArgument"
    if base in ("int", "_Bool", "bool"):
        return "bool"
    return re.sub(r"\W", "_", base.replace(" *", "")).strip("_")


class Emitter:
    def __init__(self, module: str, name: str):
        self.module, self.name = module, name
        self.lines: list[str] = []
        self.impls: set[str] = set()
        self.module_names: set[str] = set()
        self.api: set[str] = {"NULL", "PyObject"}
        self.converters: set[str] = set()
        self.tables: dict[str, list[str]] = {}
        self.getsets: dict[str, dict[str, dict[str, str]]] = {}
        self.hooks: list[str] = []
        self.tokens: set[str] = set()
        self.skipped: list[str] = []
        self.class_docs: dict[str, str] = {}

    def use(self, name: str) -> str:
        self.converters.add(name)
        return name

    # --- parameters -------------------------------------------------------
    def default(self, p, jtype: str) -> str:
        conv = p.converter
        c_default = getattr(conv, "c_default", None)
        py_default = p.default
        text = (c_default if c_default not in (None, "") else None)
        if text is None:
            if py_default is None:
                return "NULL" if jtype == "ptr[PyObject]" else "None"
            if isinstance(py_default, bool):
                return "True" if py_default else "False"
            if isinstance(py_default, (int, float)):
                return repr(py_default)
            if isinstance(py_default, str):
                return jac_string(py_default)
            raise Unsupported(f"default {py_default!r}")
        text = text.strip()
        if jtype == "BufferArgument" and text.replace(" ", "") in ("{NULL,NULL}", "{.buf=\"\",.obj=NULL,.len=0}"):
            return "BufferArgument()"
        if text == "NULL":
            return "NULL" if jtype.startswith("ptr") else "None"
        if text == "Py_None":
            return self.use("borrowed_none") + "()"
        if text in ("Py_True", "Py_False"):
            return self.use("borrowed_" + text[3:].lower()) + "()"
        if jtype == "bool" and text in ("0", "1", "true", "false"):
            return "True" if text in ("1", "true") else "False"
        if re.fullmatch(r"-?\d+(\.\d+)?", text):
            return text
        if re.fullmatch(r'"(?:[^"\\]|\\.)*"', text):
            return text
        if re.fullmatch(r"[A-Za-z_]\w*", text):
            self.module_names.add(text)
            return text
        raise Unsupported(f"C default {text}")

    def convert(self, fname: str, p, index: int, position: int, cls) -> tuple[str, str, list[str]]:
        """Return (jac type, expression over `value`, extra statements)."""
        conv = p.converter
        kind = type(conv).__name__.removesuffix("_converter")
        label = self.use("argument_label") + f'({jac_string(p.name if p.kind.name != "POSITIONAL_ONLY" else "")}, {position})'
        accept = set(getattr(conv, "accept", ()) or ())
        accept_names = {getattr(a, "__name__", str(a)) for a in accept}
        # Clinic records bitwise=True only as the mask format unit it selects.
        bitwise = getattr(conv, "format_unit", "") in ("B", "H", "I", "k", "K")
        if kind == "object":
            subclass = getattr(conv, "subclass_of", None)
            if subclass:
                if subclass in BUILTIN_TYPES:
                    check, expected = BUILTIN_TYPES[subclass]
                    self.api.add(check)
                    return "ptr[PyObject]", "value", [
                        f"if {check}(value) == 0 {{ {self.use('bad_argument')}({jac_string(fname)}, {label}, {jac_string(expected)}, value); }}"]
                check = "subclass_" + re.sub(r"\W+", "_", subclass).strip("_")
                self.module_names.add(check)
                return "ptr[PyObject]", "value", [f"{check}(value, {jac_string(fname)}, {label});"]
            return "ptr[PyObject]", "value", []
        if kind == "int":
            if accept_names & {"str"}:
                raise Unsupported("int(accept={str})")
            return "i32", self.use("convert_int") + "(value)", []
        if kind == "bool":
            if "int" in accept_names:
                return "bool", self.use("convert_bool_int") + "(value)", []
            return "bool", self.use("convert_bool") + "(value)", []
        if kind == "Py_ssize_t":
            if "NoneType" in accept_names:
                raise Unsupported("optional Py_ssize_t")  # handled by caller
            return "i64", self.use("convert_ssize") + "(value)", []
        if kind in ("long",):
            return "i64", self.use("convert_long") + "(value)", []
        if kind in ("long_long",):
            return "i64", self.use("convert_long_long") + "(value)", []
        if kind == "unsigned_long":
            return "u64", self.use("convert_unsigned_long") + f"(value, {bitwise}, {jac_string(fname)}, {label})", []
        if kind == "unsigned_long_long":
            return "u64", self.use("convert_unsigned_long_long") + f"(value, {bitwise}, {jac_string(fname)}, {label})", []
        bounded = {"unsigned_int": ("u32", 0xFFFFFFFF, "unsigned int"), "unsigned_short": ("u16", 0xFFFF, "unsigned short"),
                   "unsigned_char": ("u8", 0xFF, "unsigned byte integer"), "uint32": ("u32", 0xFFFFFFFF, "Python int too large for C uint32_t"),
                   "uint16": ("u16", 0xFFFF, "Python int too large for C uint16_t")}
        if kind in bounded:
            jt, limit, text = bounded[kind]
            return jt, f"{jt}(" + self.use("convert_unsigned_bounded") + f"(value, {bitwise}, u64({limit}), {jac_string(text)}, {jac_string(fname)}, {label}))", []
        if kind == "double":
            return "f64", self.use("convert_double") + "(value)", []
        if kind == "float":
            return "f32", self.use("convert_float") + "(value)", []
        if kind == "str":
            if accept_names - {"str", "NoneType"} or getattr(conv, "encoding", None):
                raise Unsupported(f"str(accept={sorted(accept_names)})")
            if "NoneType" in accept_names:
                return "str | None", self.use("convert_optional_str") + f"(value, {jac_string(fname)}, {label})", []
            return "str", self.use("convert_str") + f"(value, {jac_string(fname)}, {label})", []
        if kind == "unicode":
            return "ptr[PyObject]", self.use("convert_unicode") + f"(value, {jac_string(fname)}, {label})", []
        if kind == "Py_buffer":
            if "rwbuffer" in accept_names:
                return "BufferArgument", self.use("convert_writable_buffer") + f"(value, {jac_string(fname)}, {label})", []
            if accept_names - {"buffer"}:
                raise Unsupported(f"Py_buffer(accept={sorted(accept_names)})")
            return "BufferArgument", self.use("convert_buffer") + f"(value, {jac_string(fname)}, {label})", []
        # A module-defined converter, supplied by the module's Jac file.
        jtype = jac_ctype(conv.type)
        custom = "convert_" + (conv.converter if isinstance(getattr(conv, "converter", None), str) else kind)
        custom = re.sub(r"\W", "_", custom)
        self.module_names.add(custom)
        return jtype, f"{custom}(value, {jac_string(fname)}, {label})", []

    # --- functions --------------------------------------------------------
    def function(self, cls, f) -> None:
        kind = f.kind.name
        params = list(f.parameters.values())
        receiver = params.pop(0)
        uses_class = bool(params) and type(params[0].converter).__name__ == "defining_class_converter"
        if uses_class:
            params.pop(0)
            self.tokens.add(cls.name)
        if any(p.group for p in params):
            raise Unsupported("optional groups")
        if any(type(p.converter).__name__ in ("varpos_tuple_converter", "varpos_array_converter") for p in params):
            raise Unsupported("*args")
        base = f.c_basename
        impl = base + "_impl"
        self.impls.add(impl)
        fname = f.name if kind not in ("METHOD_NEW", "METHOD_INIT") else (cls.name if cls else f.name)
        ret_kind = type(f.return_converter).__name__.removesuffix("_return_converter")
        wrap = {"CReturnConverter": "", "int": "return_int", "bool": "return_bool", "long": "return_long",
                "Py_ssize_t": "return_ssize", "size_t": "return_size", "unsigned_int": "return_unsigned",
                "double": "return_double"}.get(ret_kind if ret_kind != "CReturnConverter" else "CReturnConverter")
        if wrap is None:
            raise Unsupported(f"return converter {ret_kind}")
        if wrap:
            self.use(wrap)

        # Build the body that converts bound values and calls the impl.
        body: list[str] = []
        call_args = ["receiver"]
        if uses_class:
            token = self.token_name(cls.name)
            finder = "defining_class_of_type" if kind == "CLASS_METHOD" else "defining_class"
            body.append(f"cls = {self.use(finder)}(receiver, {token});")
            call_args.append("cls")
        positional_only = sum(1 for p in params if p.kind.name == "POSITIONAL_ONLY")
        positional = sum(1 for p in params if p.kind.name != "KEYWORD_ONLY")
        required = [i for i, p in enumerate(params) if not p.is_optional()]
        prefix = 0
        while prefix < len(params) and prefix in required:
            prefix += 1
        for i, p in enumerate(params):
            var = local(p.name)
            position = i + 1
            conv = p.converter
            accept_names = {getattr(a, "__name__", str(a)) for a in (getattr(conv, "accept", ()) or ())}
            optional_ssize = type(conv).__name__ == "Py_ssize_t_converter" and "NoneType" in accept_names
            if optional_ssize:
                jtype = "i64"
                expr = None
            else:
                jtype, expr, checks = self.convert(fname, p, i, position, cls)
            if i in required and i >= prefix:
                body.append(f"if args.values[{i}] == NULL {{ {self.use('missing_argument')}({jac_string(fname)}, {jac_string(p.name)}, {position}); }}")
            if optional_ssize:
                fallback = self.default(p, "i64") if p.is_optional() else "0"
                body.append(f"{var}: i64 = {fallback};")
                body.append(f"if args.values[{i}] != NULL {{ {var} = {self.use('convert_optional_ssize')}(args.values[{i}], {fallback}); }}")
            elif p.is_optional():
                fallback = self.default(p, jtype)
                if jtype == "BufferArgument":
                    body.append(f"{var} = BufferArgument();")
                else:
                    body.append(f"{var}: {jtype} = {fallback};")
                body.append(f"if args.values[{i}] != NULL {{")
                body.append(f"    value = args.values[{i}];")
                body += [f"    {c}" for c in checks]
                body.append(f"    {var} = {expr};")
                body.append("}")
            else:
                body.append(f"value = args.values[{i}];")
                body += checks
                body.append(f"{var}: {jtype} = {expr};")
            call_args.append(var)
        call = f"{impl}({', '.join(call_args)})"
        result = f"{wrap}({call})" if wrap else call
        if uses_class:
            body.append(f"result = {result};")
            body.append("jacpy_release(cls);")
            self.api.add("jacpy_release")
            body.append("return result;")
        else:
            body.append(f"return {result};")

        names = ", ".join(jac_string(p.name) for p in params)
        sig = f"{base}_signature"
        self.lines.append(
            f"glob:priv {sig} = CallSignature({jac_string(fname)}, [{names}], {prefix}, {positional}, {positional_only});")
        self.lines.append(f"def:priv {base}_bound(args: BoundArguments) -> ptr[PyObject] {{")
        self.lines.append("    receiver = args.context;")
        self.lines += ["    " + line for line in body]
        self.lines.append("}")

        doc = f.docstring or ""
        if kind in ("METHOD_NEW", "METHOD_INIT") and cls is not None:
            self.class_docs[cls.name] = doc
        if kind == "METHOD_NEW":
            self.lines.append(f"def:pub {base}_new(type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]) -> ptr[PyObject] {{")
            self.lines.append(f"    return invoke({sig}, args, kwargs, {base}_bound, type);")
            self.lines.append("}")
            self.hooks.append(f"{base}_new")
            return
        if kind == "METHOD_INIT":
            self.lines.append(f"def:pub {base}_init(receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]) -> i32 {{")
            self.lines.append(f"    result = invoke({sig}, args, kwargs, {base}_bound, receiver);")
            self.lines.append("    if not result { return i32(-1); }")
            self.lines.append("    jacpy_release(result);")
            self.lines.append("    return i32(0);")
            self.lines.append("}")
            self.api.add("jacpy_release")
            self.hooks.append(f"{base}_init")
            return
        if kind in ("GETTER", "SETTER"):
            raise Unsupported("getter/setter routed separately")
        flags = METH_VARARGS | METH_KEYWORDS
        if kind == "CLASS_METHOD":
            flags |= METH_CLASS
        if kind == "STATIC_METHOD":
            flags |= METH_STATIC
        self.lines.append(f"def:priv {base}_call(receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]) -> ptr[PyObject] {{")
        self.lines.append(f"    return invoke({sig}, args, kwargs, {base}_bound, receiver);")
        self.lines.append("}")
        table = self.table_name(cls)
        self.tables.setdefault(table, []).append(
            f"MethodDefinition({jac_string(f.name)}, MethodCallbacks(keywords={base}_call), {jac_string(doc)}, {flags})")

    def accessor(self, cls, f) -> None:
        kind = f.kind.name
        base = f.c_basename
        impl = base + "_impl"
        self.impls.add(impl)
        prop = f.name
        entry = self.getsets.setdefault(self.table_name(cls), {}).setdefault(prop, {"doc": ""})
        if kind == "GETTER":
            self.lines.append(f"def:priv {base}_get(receiver: ptr[PyObject], context: u64) -> ptr[PyObject] {{")
            self.lines.append(f"    return {impl}(receiver);")
            self.lines.append("}")
            entry["read"] = f"{base}_get"
            entry["doc"] = f.docstring or entry["doc"]
        else:
            self.lines.append(f"def:priv {base}_set(receiver: ptr[PyObject], value: ptr[PyObject], context: u64) -> i32 {{")
            self.lines.append(f"    return i32({impl}(receiver, value));")
            self.lines.append("}")
            entry["write"] = f"{base}_set"

    def token_name(self, cls_name: str) -> str:
        return f"{cls_name}_token"

    def table_name(self, cls) -> str:
        return f"{cls.name}_methods" if cls else "module_methods"

    def render(self, source_names: list[str], pin: str) -> str:
        head = [
            f'"""Argument Clinic glue for {self.module}: signatures, converters and tables.',
            "",
            f"Generated by jac/bootstrap/python/gen_clinic.py from CPython {pin}",
            f"{', '.join(source_names)}; do not edit. The _impl functions live in",
            f"{MODULES}.{self.name}.",
        ]
        if self.skipped:
            head += ["", "Bound by hand in the module binding (no generic Jac converter):"]
            head += [f"    {item}" for item in self.skipped]
        head.append('"""')
        imports = [
            f"import from jaclang.runtime.python.cpython_api {{ {', '.join(sorted(self.api))} }}",
            "import from jaclang.runtime.python.bindings.module { MethodDefinition, MethodCallbacks }",
            "import from jaclang.runtime.python.bindings.type { PropertyDefinition, PropertyCallbacks }",
            "import from jaclang.runtime.python.bindings.arguments { BoundArguments, CallSignature, invoke }",
            "import from jaclang.runtime.python.bindings.buffer { BufferArgument }",
        ]
        converters = sorted(self.converters)
        if converters:
            imports.append(f"import from jaclang.runtime.python.bindings.converters {{ {', '.join(converters)} }}")
        # A class's ClassToken lives in the module file with its impls, which
        # also read the instance state through it; the binding fills it in.
        provided = sorted(self.impls | self.module_names | {self.token_name(c) for c in self.tokens})
        if provided:
            imports.append(f"import from {MODULES}.{self.name} {{ {', '.join(provided)} }}")
        body = list(self.lines)
        tables = []
        for cls_name, doc in sorted(self.class_docs.items()):
            tables.append(f"glob:pub {cls_name}_doc: str = {jac_string(doc)};")
        for table, entries in sorted(self.tables.items()):
            tables.append(f"glob:pub {table}: list[MethodDefinition] = [")
            tables += [f"    {e}," for e in entries]
            tables.append("];")
        for table, props in sorted(self.getsets.items()):
            name = table.replace("_methods", "_getset")
            tables.append(f"glob:pub {name}: list[PropertyDefinition] = [")
            for prop, entry in sorted(props.items()):
                read = entry.get("read", "")
                write = entry.get("write", "")
                callbacks = ", ".join(x for x in (f"read={read}" if read else "", f"write={write}" if write else "") if x)
                tables.append(f"    PropertyDefinition({jac_string(prop)}, PropertyCallbacks({callbacks}), 0, {jac_string(entry['doc'])}),")
            tables.append("];")
        return "\n".join(head + imports + [""] + body + [""] + tables) + "\n"


def generate(tree: Path, module: str, pin: str) -> tuple[str, str]:
    sources = module_sources(tree, module)
    name = module.lstrip("_")
    emitter = Emitter(module, name)
    for cls, f in clinic_functions(tree, sources):
        try:
            if f.kind.name in ("GETTER", "SETTER"):
                emitter.accessor(cls, f)
            else:
                emitter.function(cls, f)
        except Unsupported as reason:
            emitter.skipped.append(f"{f.full_name}: {reason}")
    relative = [str(s.relative_to(tree)) for s in sources]
    return name, format_jac(emitter.render(relative, pin), OUTPUT / f"{name}.jac")


def registered() -> list[str]:
    if not REGISTRY.is_file():
        return []
    return [line.split()[0] for line in REGISTRY.read_text().splitlines()
            if line.strip() and not line.startswith("#")]


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate native Jac Argument Clinic glue")
    parser.add_argument("modules", nargs="*")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--out", type=Path, help="write here instead of the bindings tree")
    args = parser.parse_args()
    pin = json.loads((HERE / "sources.json").read_text())["cpython"]["version"]
    modules = args.modules or registered()
    with tempfile.TemporaryDirectory() as scratch:
        tree = pinned_tree(Path(scratch))
        stale = []
        for module in modules:
            name, text = generate(tree, module, pin)
            target = (args.out or OUTPUT) / f"{name}.jac"
            if args.check:
                if not target.is_file() or target.read_text() != text:
                    stale.append(str(target.relative_to(REPO)))
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)
            print(f"wrote {target}")
        if stale:
            sys.exit("Stale clinic glue; rerun gen_clinic.py:\n  " + "\n  ".join(stale))


if __name__ == "__main__":
    main()
