"""Extract the Argument Clinic signatures gen_clinic.jac generates from.

A one-off that runs upstream's Tools/clinic parser from the checksum-pinned
CPython archive over the `/*[clinic input]` blocks of every module
jacpython-clinic.txt lists, and writes each module's signatures as the Jac
data gen_clinic.jac reads (a Clinic record of clinic_schema.jac):

    jac run scripts/jacpython/gen_clinic_data.jac            # write all
    jac run scripts/jacpython/gen_clinic_data.jac zlib       # one module
    jac run scripts/jacpython/gen_clinic_data.jac --check    # compare

The data, scripts/jacpython/clinic/<name>.jac, is the source of the
signatures now; the C sources are not part of JacPython. While the pin is the
release the data was taken from, --check shows every difference between the
data and what the archive says, so an edit that drifts from CPython is
visible. After the pin moves, its differences are the upstream changes to
review and carry into the data by hand.
"""
import argparse;
import ast;
import codecs;
import difflib;
import importlib;
import inspect;
import json;
import re;
import sys;
import tempfile;
import from pathlib { Path }
import from common { REPO, extract_tree, format_jac_many, pin }
import from gen_clinic { DATA, data_name, posix_condition, registered }
import from clinic_schema { Clinic, Function, Parameter }

# The CPython release the data was taken from.
glob EXTRACTED_FROM: str = "3.14.6";

# Built-in modules the interpreter core defines rather than Setup: their C
# source under Python/, by module name.
glob CORE_SOURCES: dict[str, str] = {
         "_warnings": "Python/_warnings.c",
         "_imp": "Python/import.c",
         "marshal": "Python/marshal.c"
     };

# A module's C sources: those Setup lists, each followed by the local `.c`
# files it textually includes (_ssl.c's `#include "_ssl/cert.c"`), whose clinic
# blocks belong to the same module.
def module_sources(tree: Path, module: str) -> list[Path] {
    if module in CORE_SOURCES {
        return [tree / CORE_SOURCES[module]];
    }
    for setup in ("Modules/Setup.stdlib.in", "Modules/Setup.bootstrap.in") {
        for line in (tree / setup).read_text().splitlines() {
            parts = re.sub(r"^@[A-Z0-9_]+@", "", line.strip()).split();
            if parts and parts[0] == module {
                sources: list[Path] = [];
                pending = [
                    tree / "Modules" / p
                    for p in parts[1:]
                    if p.endswith(".c")
                ];
                while pending {
                    source = pending.pop(0);
                    sources.append(source);
                    included = re.findall(
                        r'^#\s*include\s+"([^"]+\.c)"', source.read_text(), re.M
                    );
                    pending = [source.parent / name for name in included] + pending;
                }
                return sources;
            }
        }
    }
    sys.exit(f"{module} is not built by Modules/Setup.stdlib.in or Setup.bootstrap.in");
}

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
            start = None
                if generated
                else re.match(r"\s*PyDoc_STRVAR\((\w+),(.*)$", line);
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
            ).decode(
                "utf-8"
            );
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
                    ).decode(
                        "utf-8"
                    );
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
            ).decode(
                "utf-8"
            );
            found[f"{table}_{name.group(1)}_doc"] = text;
        }
    }
    return found;
}

# The preprocessor condition each clinic function is compiled under, as
# Tools/clinic sees it while rendering the block ("" when none). Keyed by the
# Function's id: a function defined once per platform branch (semaphore.c's
# SemLock.acquire) has one full name for several definitions.
glob CONDITIONS: dict[int, str] = {};

# How Tools/clinic parses each function's arguments, by Function id: its
# ParseArgsCodeGen (flags, pos_only, min_pos, max_pos, min_kw_only) and the
# generated C parser, which names the getargs routine it calls.
glob PARSERS: dict[int, tuple[any, str]] = {};

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

def class_name(value: any) -> str {
    return value.__class__.__name__;
}

def accepted(conv: any) -> list[str] {
    return sorted(
        {getattr(a, "__name__", str(a)) for a in (getattr(conv, "accept", ()) or ())}
    );
}

# The C a converter's parse_arg renders ("" when it renders none).
def custom_parse_source(conv: any) -> str {
    try {
        return conv.parse_arg("__argument", "__argument", limited_capi=False) or "";
    } except Exception {
        return "";
    }
}

# The values of a converter's own keyword options that name C objects of the
# module, or that its parse spells as C string literals (kept as one).
def converter_options(conv: any) -> list[str] {
    init = getattr(type(conv), "converter_init", None);
    if init is None {
        return [];
    }
    names: list[str] = [];
    for (name, parameter) in inspect.signature(init).parameters.items() {
        # type=, converter= and subclass_of= are recorded as the
        # parameter's own fields.
        if parameter.kind != parameter.KEYWORD_ONLY
            or name in ("type", "converter", "subclass_of") {
            continue;
        }
        value = getattr(conv, name, None);
        if not isinstance(value, str) {
            continue;
        }
        if f'"{value}"' in custom_parse_source(conv) {
            names.append(json.dumps(value));
        } elif re.fullmatch(r"[A-Za-z_]\w*", value) {
            names.append(value);
        }
    }
    return names;
}

# The bindings/arguments.jac parser that does what clinic's generated C
# parser `body` does, or why none can.
def parser_kind(generator: any, body: str) -> str {
    names = [name.strip() for name in generator.flags.split("|")];
    if "switch (" in body {
        return "optional groups";
    }
    if "_PyArg_ParseStackAndKeywords(" in body
        or "_PyArg_ParseTupleAndKeywordsFast(" in body {
        return "keyword format parsing";
    }
    if "PyArg_ParseTupleAndKeywords(" in body {
        return "PARSE_FORMAT_KEYWORDS";
    }
    if "METH_NOARGS" in names {
        return "PARSE_NOTHING" if "_PyArg_NoPositional(" in body else "PARSE_GIVEN";
    }
    if "METH_O" in names {
        return "PARSE_GIVEN";
    }
    if "_PyArg_UnpackKeywords(" in body {
        return "PARSE_KEYWORDS";
    }
    if "takes no arguments" in body {
        return "PARSE_NO_ARGUMENTS";
    }
    if "_PyArg_ParseStack(" in body or "PyArg_ParseTuple(" in body {
        return "PARSE_FORMAT";
    }
    # The limited C API spells _PyArg_CheckPositional() out inline.
    if "_PyArg_CheckPositional(" in body
        or (generator.limited_capi and "expected" in body) {
        return "PARSE_POSITIONAL";
    }
    return f"parser for {generator.flags}";
}

# The DeprecationWarning texts clinic's parser `body` emits.
def warnings_of(body: str) -> list[str] {
    messages: list[str] = [];
    for hit in re.finditer(
        r'PyErr_WarnEx\(PyExc_DeprecationWarning,((?:\s*"(?:[^"\\]|\\.)*")+)\s*,\s*1\)',
        body
    ) {
        pieces = re.findall(r'"((?:[^"\\]|\\.)*)"', hit.group(1));
        messages.append(codecs.decode("".join(pieces), "unicode_escape"));
    }
    return messages;
}

def version_text(version: any) -> str {
    return ".".join(str(part) for part in version) if version else "";
}

def describe_parameter(p: any) -> Parameter {
    conv = p.converter;
    default_kind = "value";
    py_default = p.default;
    if p.default is inspect.Parameter.empty or repr(p.default) == "<Unspecified>" {
        default_kind = "";
        py_default = None;
    } elif repr(p.default) == "<Null>" {
        default_kind = "NULL";
        py_default = None;
    } elif repr(p.default) == "<Unknown>" {
        default_kind = "unknown";
        py_default = None;
    } elif not isinstance(
        p.default, (type(None), bool, int, float, str, bytes, tuple)
    ) {
        sys.exit(f"{p.function.full_name}: default {p.default!r} has no Jac literal");
    }
    # Rendering a block pre-renders copies of its converters; a by-reference
    # converter's C default (path_t's PATH_T_INITIALIZE_P(...)) is set there.
    if getattr(conv, "impl_by_reference", False) {
        conv.pre_render();
    }
    for field in ("format_unit", "c_default", "encoding", "subclass_of", "type") {
        value = getattr(conv, field, "");
        if value is not None and not isinstance(value, str) {
            sys.exit(f"{p.function.full_name}: {field} {value!r} is not text");
        }
    }
    named = getattr(conv, "converter", "");
    named = named if isinstance(named, str) else "";
    parsed = custom_parse_source(conv);
    return Parameter(
        name=p.name,
        kind=p.kind.name,
        converter=class_name(conv).removesuffix("_converter"),
        type=getattr(conv, "type", "") or "",
        format_unit=getattr(conv, "format_unit", "") or "",
        default_kind=default_kind,
        py_default=py_default,
        c_default=getattr(conv, "c_default", "") or "",
        group=p.group,
        accept=accepted(conv),
        convert_with=named,
        subclass_of=getattr(conv, "subclass_of", "") or "",
        encoding=getattr(conv, "encoding", "") or "",
        by_reference=bool(getattr(conv, "impl_by_reference", False)),
        options=converter_options(conv),
        takes_module="(module, " in parsed
            or bool(named and f"{named}(module," in parsed),
        releases=bool(re.search(r"Py_X?DECREF\(", conv.cleanup() or "")),
        deprecated_positional=version_text(getattr(p, "deprecated_positional", None)),
        deprecated_keyword=version_text(getattr(p, "deprecated_keyword", None))
    );
}

def describe_function(cls: any, f: any, source_text: str) -> Function {
    kind = f.kind.name;
    record = Function(
        name=f.name,
        full_name=f.full_name,
        c_basename=f.c_basename,
        kind=kind,
        cls=cls.name if cls else "",
        docstring=f.docstring or "",
        condition=CONDITIONS.get(id(f), ""),
        returns=class_name(f.return_converter).removesuffix(
            "_return_converter"
        ).replace(
            "CReturnConverter", ""
        ),
        params=[describe_parameter(p) for p in f.parameters.values()]
    );
    body = "";
    if id(f) in PARSERS {
        generator = PARSERS[id(f)][0];
        body = PARSERS[id(f)][1];
        record.flags = generator.flags;
        record.parser = parser_kind(generator, body);
        record.min_pos = generator.min_pos;
        record.max_pos = generator.max_pos;
        record.pos_only = generator.pos_only;
        record.min_kw_only = generator.min_kw_only;
        record.limited_capi = bool(generator.limited_capi);
        messages = warnings_of(body);
        record.positional_warning = next(
            (
                m
                for m in messages
                if "positional argument" in m
            ),
            ""
        );
        record.keyword_warning = next(
            (
                m
                for m in messages
                if m.startswith("Passing keyword")
            ),
            ""
        );
        record.self_type_check = "{self_type_check}" in body;
    }
    # A parser calls `<c_basename>_impl`; without one (a METH_O object
    # argument) the C function is the impl itself. A clone whose impl the C
    # never defines is kept only for its docstring and PyMethodDef.
    if kind not in ("METHOD_NEW", "METHOD_INIT", "GETTER", "SETTER") {
        expected = f.c_basename + "_impl"
            if re.search(r"_impl\(", body.replace("{c_basename}", f.c_basename))
            else f.c_basename;
        record.bound_by_hand = not re.search(rf"\b{expected}\s*\(", source_text);
    }
    return record;
}

# A module's signatures, read from the archive `tree`.
def describe(tree: Path, module: str, version: str) -> Clinic {
    sources = module_sources(tree, module);
    source_text = "\n".join(s.read_text() for s in sources);
    classes: dict[str, str] = {};
    functions: list[Function] = [];
    for (cls, f) in clinic_functions(tree, sources) {
        if cls is not None {
            typedef = cls.typedef or "";
            if classes.get(cls.name, typedef) != typedef {
                sys.exit(f"{module}: two classes named {cls.name}");
            }
            classes[cls.name] = typedef;
        }
        functions.append(describe_function(cls, f, source_text));
    }
    return Clinic(
        module=module,
        version=version,
        sources=[str(s.relative_to(tree)) for s in sources],
        classes=classes,
        functions=functions,
        docs={
            ** c_docstrings(tree, sources),
            ** c_macro_docstrings(sources),
            ** c_table_docs(tree, sources)
        }
    );
}

# A value as a Jac literal: records as constructor calls naming only the
# fields that differ from their defaults.
def literal(value: any, indent: str = "") -> str {
    inner = indent + "    ";
    if isinstance(value, (Clinic, Function, Parameter)) {
        fields: list[str] = [];
        blank = None;
        if isinstance(value, Parameter) {
            blank = Parameter(name="");
        } elif isinstance(value, Function) {
            blank = Function(name="", full_name="", c_basename="");
        } else {
            blank = Clinic(module="", version="", sources=[]);
        }
        for (field, item) in vars(value).items() {
            if field
                not in (
                    "name",
                    "full_name",
                    "c_basename",
                    "module",
                    "version",
                    "sources"
                )
                and item == getattr(blank, field)
                and type(item) is type(getattr(blank, field)) {
                continue;
            }
            fields.append(f"{inner}{field}={literal(item, inner)}");
        }
        return f"{class_name(value)}(\n" + ",\n".join(fields) + f"\n{indent})";
    }
    if isinstance(value, list) {
        if not value {
            return "[]";
        }
        return "[\n"
            + ",\n".join(inner + literal(v, inner) for v in value)
            + f"\n{indent}]";
    }
    if isinstance(value, tuple) {
        if len(value) == 1 {
            return f"({literal(value[0], indent)},)";
        }
        return "(" + ", ".join(literal(v, indent) for v in value) + ")";
    }
    if isinstance(value, dict) {
        if not value {
            return "{}";
        }
        return "{\n"
            + ",\n".join(
                f"{inner}{literal(k, inner)}: {literal(v, inner)}"
                for (k, v) in value.items()
            )
            + f"\n{indent}}}";
    }
    # A text of several lines is written a line per literal.
    if isinstance(value, str) and "\n" in value.rstrip("\n") {
        pieces = [
            piece
            for piece in re.split(r"(?<=\n)", value)
            if piece
        ];
        return f"\n{inner}".join(
            json.dumps(piece, ensure_ascii=False) for piece in pieces
        );
    }
    if isinstance(value, str) {
        return json.dumps(value, ensure_ascii=False);
    }
    if value is None or isinstance(value, (bool, int, float, bytes)) {
        return repr(value);
    }
    raise TypeError(f"no Jac literal for {value!r}");
}

def render(clinic: Clinic, name: str) -> str {
    return "\n".join(
        [
            f'"""The Argument Clinic signatures of {clinic.module}.',
            "",
            "scripts/jacpython/gen_clinic.jac generates",
            f"jaclang/runtime/python/bindings/clinic/{name}.jac from them. Taken from",
            f"CPython {clinic.version} {', '.join(clinic.sources)}.",
            '"""',
            "import from clinic_schema { Clinic, Function, Parameter }",
            "",
            f"glob CLINIC: Clinic = {literal(clinic)};",
            ""
        ]
    );
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Extract the Argument Clinic signatures gen_clinic.jac reads"
    );
    parser.add_argument("modules", nargs="*");
    parser.add_argument("--check", action="store_true");
    parser.add_argument(
        "--out", type=Path, help="write here instead of scripts/jacpython/clinic"
    );
    args = parser.parse_args();
    version = pin()["version"];
    if args.check and version != EXTRACTED_FROM {
        print(
            f"The clinic data was taken from CPython {EXTRACTED_FROM}; the pin is "
                + f"{version}, so the differences below are upstream changes to review.",
            file=sys.stderr
        );
    }
    stale: list[str] = [];
    with tempfile.TemporaryDirectory() as scratch {
        tree = extract_tree(
            Path(scratch),
            ("Tools/clinic/", "Modules/") + tuple(sorted(set(CORE_SOURCES.values())))
        );
        modules = args.modules or registered();
        rendered = [
            render(describe(tree, module, version), data_name(module))
            for module in modules
        ];
        targets = [(args.out or DATA) / f"{data_name(m)}.jac" for m in modules];
        formatted = format_jac_many(list(zip(rendered, targets)));
        for (target, text) in zip(targets, formatted) {
            if args.check {
                current = target.read_text() if target.is_file() else "";
                if current != text {
                    stale.append(str(target.relative_to(REPO)));
                    sys.stdout.writelines(
                        difflib.unified_diff(
                            current.splitlines(keepends=True),
                            text.splitlines(keepends=True),
                            str(target.relative_to(REPO)),
                            f"CPython {version}"
                        )
                    );
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
            "The clinic data differs from the pinned CPython sources:\n  "
                + "\n  ".join(stale)
        );
    }
}
