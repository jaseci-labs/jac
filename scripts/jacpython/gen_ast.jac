"""Generate the AST object layer of JacPython from CPython's ASDL description.

CPython's Parser/asdl_c.py reads Parser/Python.asdl and writes
Python/Python-ast.c: the C structs of the AST nodes and their arena
constructors (`_PyAST_*`), the `ast.AST` node classes of the `_ast` module,
and the conversions between the two (`PyAST_mod2obj`, `PyAST_obj2mod`). This
script reads the same description from the pinned CPython archive and writes
that module as native Jac, visitor for visitor:

    jac run scripts/jacpython/gen_ast.jac            # rewrite the module
    jac run scripts/jacpython/gen_ast.jac --check    # fail on drift
    jac run scripts/jacpython/gen_ast.jac --headers DIR --cc "zig cc"
                                                     # also check the layouts

- jaclang/runtime/python/object_model/python_ast.jac

The code asdl_c.py writes verbatim (the AST base type's slots, pickling,
copy.replace() and repr support, and the conversion of the builtin ASDL
types) is scripts/jacpython/python_ast.jac.in; the rest is generated here
from the description. The interpreter's `struct ast_state` and the asdl
sequences are header layouts (gen_layouts.jac); the node structs are
generated here, laid out as the C compiler lays out pycore_ast.h's structs on
the supported LP64 targets. With `--headers` (a configured CPython's include
directory) every generated offset, size and enumerator is compared with the
C compiler's.

Deviations from the C kept by asdl_c.py, all with the same behavior:
- an obj2ast conversion returns `(status, value)` instead of writing `*out`,
  and a sum's per-constructor branch is a function of its own;
- an ast2obj list conversion is generated per element type instead of
  taking a function pointer;
- the typed `_Py_asdl_<type>_seq_new` constructors share asdl.c's
  `_Py_asdl_generic_seq_new`, the expansion they all are (every asdl
  sequence has the same size and element width).
"""
import argparse;
import re;
import shlex;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from common { JAC, REPO, RUNTIME, archive_texts, pin, write_or_check }

glob COMMAND: str = "scripts/jacpython/gen_ast.jac",
     TARGET: Path = RUNTIME / "object_model/python_ast.jac",
     TEMPLATE: Path = REPO / "scripts/jacpython/python_ast.jac.in",
     ASDL_SOURCE: str = "Parser/Python.asdl",
     BUILTIN_TYPES: set[str] = {"identifier", "string", "int", "constant"},
     # ASDL types held as a PyObject pointer.
     OBJECT_TYPES: set[str] = {"identifier", "string", "constant", "object"},
     # The Python type of a builtin field in the node classes' annotations.
     BUILTIN_PYTHON_TYPES: dict[str, str] = {
         "identifier": "PyUnicode_Type",
         "string": "PyUnicode_Type",
         "int": "PyLong_Type",
         "constant": "PyBaseObject_Type"
     },
     # An optional attribute defaults to the attribute it ends.
     ATTRIBUTE_DEFAULTS: dict[str, str] = {
         "end_lineno": "lineno",
         "end_col_offset": "col_offset"
     },
     # Names Jac reserves (keywords and builtin type names): a field, parameter
     # or local named after one takes a trailing underscore.
     RESERVED: set[str] = set(
         (
             "abst obj class enum node edge walker has can def static override "
             + "comptime impl getter setter deleter sem test glob graph import include "
             + "from as if elif else for by while forever match switch case default try "
             + "except finally awaiting with return yield break continue raise del assert "
             + "skip report visit spawn entry exit disengage here visitor root async await "
             + "flow wait and or not in is lambda own lin mut imm pub priv protect self "
             + "props init super postinit int float str bool bytes list dict set tuple any "
             + "ignore to let kw abs"
         ).split()
     ),
     POINTER_SIZE: int = 8,
     INT_SIZE: int = 4;

obj AsdlError(Exception) {}

# A field of a constructor or product: `type`, its quantifiers ("?" optional,
# "*" sequence) in order, and its name.
obj Field {
    has type: str,
        name: str,
        quantifiers: list[str];

    def seq -> bool {
        return len(self.quantifiers) > 0 and self.quantifiers[-1] == "*";
    }

    def opt -> bool {
        return len(self.quantifiers) > 0 and self.quantifiers[-1] == "?";
    }

    def describe -> str {
        return f"{self.type}{''.join(self.quantifiers)} {self.name}";
    }
}

obj Constructor {
    has name: str,
        fields: list[Field];
}

# A definition `name = ...`: a sum of constructors (with attributes) when
# `constructors` is set, otherwise a product of `fields`.
obj Definition {
    has name: str,
        is_sum: bool,
        constructors: list[Constructor],
        fields: list[Field],
        attributes: list[Field];
}

# asdl.py's tokenize_asdl: (kind, value, line) with kind "Constructor",
# "Type" or the operator itself.
def tokenize_asdl(text: str) -> list[tuple[str, str, int]] {
    tokens: list[tuple[str, str, int]] = [];
    lineno = 0;
    for line in text.splitlines() {
        lineno += 1;
        for m in re.finditer(r"\s*(\w+|--.*|.)", line.strip()) {
            c = m.group(1);
            if c[0].isalpha() {
                tokens.append(("Constructor" if c[0].isupper() else "Type", c, lineno));
            } elif c.startswith("--") {
                break;
            } elif c in ("=", ",", "?", "|", "(", ")", "*", "{", "}") {
                tokens.append((c, c, lineno));
            } else {
                raise AsdlError(f"Syntax error on line {lineno}: Invalid operator {c}");
            }
        }
    }
    return tokens;
}

# asdl.py's ASDLParser.
obj Parser {
    has tokens: list[tuple[str, str, int]],
        pos: int = 0;

    def kind -> str {
        if self.pos < len(self.tokens) {
            return self.tokens[self.pos][0];
        }
        return "";
    }

    def value -> str {
        return self.tokens[self.pos][1] if self.pos < len(self.tokens) else "";
    }

    def advance -> str {
        current = self.value();
        self.pos += 1;
        return current;
    }

    def expect(kinds: tuple[str, ...]) -> str {
        if self.kind() not in kinds {
            line = self.tokens[self.pos][2] if self.pos < len(self.tokens) else 0;
            raise AsdlError(
                f"Syntax error on line {line}: Unmatched {kinds} (found {self.kind()})"
            );
        }
        return self.advance();
    }

    def at_keyword(word: str) -> bool {
        return self.kind() == "Type" and self.value() == word;
    }

    def module -> list[Definition] {
        if not self.at_keyword("module") {
            raise AsdlError(f'Expected "module" (found {self.value()})');
        }
        self.advance();
        self.expect(("Constructor", "Type"));
        self.expect(("{", ));
        definitions: list[Definition] = [];
        while self.kind() == "Type" {
            name = self.advance();
            self.expect(("=", ));
            definitions.append(self.definition(name));
        }
        self.expect(("}", ));
        return definitions;
    }

    def definition(name: str) -> Definition {
        if self.kind() == "(" {
            fields = self.fields();
            return Definition(
                name=name,
                is_sum=False,
                constructors=[],
                fields=fields,
                attributes=self.optional_attributes()
            );
        }
        constructors = [self.constructor()];
        while self.kind() == "|" {
            self.advance();
            constructors.append(self.constructor());
        }
        return Definition(
            name=name,
            is_sum=True,
            constructors=constructors,
            fields=[],
            attributes=self.optional_attributes()
        );
    }

    def constructor -> Constructor {
        name = self.expect(("Constructor", ));
        fields: list[Field] = [];
        if self.kind() == "(" {
            fields = self.fields();
        }
        return Constructor(name=name, fields=fields);
    }

    def fields -> list[Field] {
        found: list[Field] = [];
        self.expect(("(", ));
        while self.kind() == "Type" {
            type_name = self.advance();
            quantifiers: list[str] = [];
            while self.kind() in ("*", "?") {
                quantifiers.append(self.advance());
            }
            name = "";
            if self.kind() in ("Constructor", "Type") {
                name = self.advance();
            }
            if not name {
                raise AsdlError(f"field of type {type_name} has no name");
            }
            found.append(Field(type=type_name, name=name, quantifiers=quantifiers));
            if self.kind() == ")" {
                break;
            } elif self.kind() == "," {
                self.advance();
            }
        }
        self.expect((")", ));
        return found;
    }

    def optional_attributes -> list[Field] {
        if self.at_keyword("attributes") {
            self.advance();
            return self.fields();
        }
        return [];
    }
}

# asdl.check: every field type is a builtin or a definition.
def check_types(definitions: list[Definition]) {
    defined = {d.name for d in definitions};
    for d in definitions {
        fields = d.fields + d.attributes;
        for c in d.constructors {
            fields = fields + c.fields;
        }
        for f in fields {
            if f.type not in BUILTIN_TYPES and f.type not in defined {
                raise AsdlError(f"Undefined type {f.type}, used in {d.name}");
            }
        }
    }
}

def round_up(value: int, align: int) -> int {
    return (value + align - 1) // align * align;
}

def jac_name(name: str) -> str {
    return f"{name}_" if name in RESERVED else name;
}

# Jac string literal of `text`.
def literal(text: str) -> str {
    return (
        '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    );
}

def c_literal(text: str) -> str {
    return f"ptr[u8]({literal(text)})";
}

obj Generator {
    has definitions: list[Definition],
        state_keywords: set[str],
        simple_sums: set[str],
        singletons: set[str],
        identifiers: set[str],
        types: set[str],
        out: list[str],
        # (name, C expression, expected value) of each generated layout fact.
        facts: list[tuple[str, str, int]],
        union_offset: int = 0;

    # MetadataVisitor: the simple sums, their constructors (singletons), every
    # field and attribute name, and every type name.
    def collect {
        for d in self.definitions {
            self.types.add(d.name);
            if d.is_sum {
                if self.is_simple(d) {
                    self.simple_sums.add(d.name);
                }
                for c in d.constructors {
                    if self.is_simple(d) {
                        self.singletons.add(c.name);
                    }
                    self.types.add(c.name);
                    for f in c.fields {
                        self.identifiers.add(f.name);
                    }
                }
            } else {
                for f in d.fields {
                    self.identifiers.add(f.name);
                }
            }
            for f in d.attributes {
                self.identifiers.add(f.name);
            }
        }
    }

    def is_simple(d: Definition) -> bool {
        return d.is_sum
            and not d.attributes
            and not any(len(c.fields) > 0 for c in d.constructors);
    }

    def emit(line: str) {
        self.out.append(line);
    }

    # The interpreter state member holding `name` (gen_layouts.jac's naming).
    def st(name: str) -> str {
        member = f"{name}_" if name in self.state_keywords else name;
        return f"state.view(1)[0].{member}";
    }

    def is_numeric(f: Field) -> bool {
        return f.type == "int";
    }

    def is_simple_type(f: Field) -> bool {
        return f.type in self.simple_sums or self.is_numeric(f);
    }

    # The Jac type of a field's value (its C type in pycore_ast.h).
    def field_type(f: Field) -> str {
        if f.seq() {
            return "ptr[asdl_seq]";
        }
        return self.value_type(f.type);
    }

    # The Jac type of one value of ASDL type `type_name`.
    def value_type(type_name: str) -> str {
        if type_name in OBJECT_TYPES {
            return "ptr[PyObject]";
        }
        if type_name == "int" or type_name in self.simple_sums {
            return "i32";
        }
        return f"ptr[_{type_name}]";
    }

    def zero(jac_type: str) -> str {
        if jac_type == "ptr[PyObject]" {
            return "NULL";
        }
        if jac_type == "i32" {
            return "0";
        }
        return f"{jac_type}()";
    }

    def field_size(f: Field) -> int {
        return INT_SIZE if self.field_type(f) == "i32" else POINTER_SIZE;
    }

    # C offsets of `fields` laid out in order, the struct size and alignment.
    def layout(fields: list[Field], start: int = 0) -> tuple[list[int], int, int] {
        offsets: list[int] = [];
        offset = start;
        align = 1;
        for f in fields {
            size = self.field_size(f);
            offset = round_up(offset, size);
            offsets.append(offset);
            offset += size;
            align = max(align, size);
        }
        return (offsets, round_up(offset, align), align);
    }

    def record(name: str, members: list[str]) {
        self.emit(f"obj {name} {{");
        self.emit("    has " + ",\n        ".join(members) + ";");
        self.emit("}");
    }

    def fact(name: str, expression: str, value: int) {
        self.facts.append((name, expression, value));
    }

    # -- Enumerators, node structs and the field-name tables -------------

    def emit_constants {
        entries: list[str] = [];
        for d in self.definitions {
            if not d.is_sum {
                continue;
            }
            for (index, c) in enumerate(d.constructors) {
                name = c.name if self.is_simple(d) else f"{c.name}_kind";
                entries.append(f"{name}: Final[i32] = {index + 1}");
                self.fact(f"enum_{name}", name, index + 1);
            }
        }
        for d in self.definitions {
            if self.is_simple(d) {
                continue;
            }
            entries.append(f"_{d.name}_SIZE: Final[u64] = {self.struct_size(d)}");
        }
        entries.append(f"AST_UNION_OFFSET: Final[i64] = {self.union_offset}");
        self.emit("glob " + ",\n     ".join(entries) + ";");
        self.emit("");
    }

    def struct_size(d: Definition) -> int {
        if d.is_sum {
            (_, size, _) = self.sum_layout(d);
            return size;
        }
        (_, size, _) = self.layout(d.fields + d.attributes);
        return size;
    }

    # (union offset, struct size, widest constructor) of a sum's node struct.
    def sum_layout(d: Definition) -> tuple[int, int, Constructor | None] {
        union_size = 0;
        union_align = 1;
        widest: Constructor | None = None;
        widest_align = 1;
        for c in d.constructors {
            if not c.fields {
                continue;
            }
            (_, size, align) = self.layout(c.fields);
            if size > union_size {
                union_size = size;
                widest = c;
                widest_align = align;
            }
            union_align = max(union_align, align);
        }
        if widest is not None and widest_align != union_align {
            raise AsdlError(
                f"the widest constructor of {d.name} is not the most aligned one"
            );
        }
        union_size = round_up(union_size, union_align);
        start = round_up(INT_SIZE, union_align);
        (_, size, align) = self.layout(d.attributes, start + union_size);
        return (start, round_up(size, max(align, union_align, INT_SIZE)), widest);
    }

    def members(fields: list[Field]) -> list[str] {
        return [f"{jac_name(f.name)}: {self.field_type(f)}" for f in fields];
    }

    def emit_records {
        self.emit("import from c {");
        offsets: set[int] = set();
        for d in self.definitions {
            if self.is_simple(d) {
                continue;
            }
            struct = f"struct _{d.name}";
            if not d.is_sum {
                fields = d.fields + d.attributes;
                self.record(f"_{d.name}", self.members(fields));
                (field_offsets, size, _) = self.layout(fields);
                for (f, offset) in zip(fields, field_offsets) {
                    self.fact(
                        f"{d.name}_{f.name}", f"offsetof({struct}, {f.name})", offset
                    );
                }
                self.fact(f"{d.name}_SIZE", f"sizeof({struct})", size);
                continue;
            }
            (start, size, widest) = self.sum_layout(d);
            offsets.add(start);
            for c in d.constructors {
                if not c.fields {
                    continue;
                }
                self.record(f"_{d.name}_{c.name}", self.members(c.fields));
                (field_offsets, _, _) = self.layout(c.fields);
                for (f, offset) in zip(c.fields, field_offsets) {
                    self.fact(
                        f"{d.name}_{c.name}_{f.name}",
                        f"offsetof({struct}, v.{c.name}.{f.name})",
                        start + offset
                    );
                }
            }
            node_members = ["kind: i32"];
            if widest is not None {
                node_members.append(f"v: _{d.name}_{widest.name}");
            }
            node_members += self.members(d.attributes);
            self.record(f"_{d.name}", node_members);
            self.fact(f"{d.name}_v", f"offsetof({struct}, v)", start);
            (attribute_offsets, _, _) = self.layout(
                d.attributes, start + self.union_size(d)
            );
            for (f, offset) in zip(d.attributes, attribute_offsets) {
                self.fact(
                    f"{d.name}_{f.name}", f"offsetof({struct}, {f.name})", offset
                );
            }
            self.fact(f"{d.name}_SIZE", f"sizeof({struct})", size);
        }
        if len(offsets) != 1 {
            raise AsdlError("the node unions do not share one offset");
        }
        self.union_offset = offsets.pop();
        self.emit_field_tables();
        self.emit("}");
        self.emit("");
    }

    def union_size(d: Definition) -> int {
        (start, size, widest) = self.sum_layout(d);
        if widest is None {
            return 0;
        }
        (_, widest_size, _) = self.layout(widest.fields);
        (_, _, align) = self.layout(widest.fields);
        return round_up(widest_size, align);
    }

    def name_table(name: str, names: list[str]) -> str {
        items = ", ".join(c_literal(n) for n in names);
        return f"{name}: list[ptr[u8]] = [{items}]";
    }

    # PyTypesDeclareVisitor: the `<type>_fields` and `<type>_attributes` tables.
    def emit_field_tables {
        tables: list[str] = [];
        for d in self.definitions {
            if d.attributes {
                tables.append(
                    self.name_table(
                        f"{d.name}_attributes", [a.name for a in d.attributes]
                    )
                );
            }
            if not d.is_sum and d.fields {
                tables.append(
                    self.name_table(f"{d.name}_fields", [f.name for f in d.fields])
                );
            }
            for c in d.constructors {
                if c.fields {
                    tables.append(
                        self.name_table(f"{c.name}_fields", [f.name for f in c.fields])
                    );
                }
            }
        }
        self.emit("glob:priv " + ",\n     ".join(tables) + ";");
    }

    # -- Module state ----------------------------------------------------

    def module_state -> tuple[list[str], list[str]] {
        strings = {
            "ast",
            "_fields",
            "__match_args__",
            "__doc__",
            "__dict__",
            "__module__",
            "_attributes"
        }
            | self.identifiers;
        state = set(strings);
        state |= {f"{s}_singleton" for s in self.singletons};
        state |= {f"{t}_type" for t in self.types};
        return (sorted(strings), sorted(state));
    }

    def emit_fini(state: list[str]) {
        self.emit("import from c {");
        self.emit("    def _PyAST_Fini(interp: ptr[u8]) {");
        self.emit("        state = ptr[ast_state](interp + PyInterpreterState_AST);");
        self.emit("        old = NULL;");
        for s in state {
            self.emit(f"        old = {self.st(s)};");
            self.emit(f"        {self.st(s)} = NULL;");
            self.emit("        object_xdecref(old);");
        }
        self.emit(f"        {self.st('finalized')} = 1;");
        self.emit("        ptr[_PyOnceFlag](state).view(1)[0].v = 0;");
        self.emit("    }");
        self.emit("}");
        self.emit("");
    }

    def emit_identifiers(strings: list[str]) {
        self.emit("def init_identifiers(state: ptr[ast_state]) -> i32 {");
        for s in strings {
            self.emit(
                f"    {self.st(s)} = PyUnicode_InternFromString({c_literal(s)});"
            );
            self.emit(f"    if not {self.st(s)} {{");
            self.emit("        return -1;");
            self.emit("    }");
        }
        self.emit("    return 0;");
        self.emit("}");
        self.emit("");
    }

    # -- Annotations and node types --------------------------------------

    def emit_annotations {
        self.emit("def add_ast_annotations(state: ptr[ast_state]) -> i32 {");
        self.emit("    annotations = NULL;");
        for d in self.definitions {
            if d.is_sum {
                for c in d.constructors {
                    self.annotations_of(c.name, c.fields);
                }
            } else {
                self.annotations_of(d.name, d.fields);
            }
        }
        self.emit("    return 1;");
        self.emit("}");
        self.emit("");
    }

    def annotations_of(name: str, fields: list[Field]) {
        self.emit("    annotations = PyDict_New();");
        self.emit("    if not annotations {");
        self.emit("        return 0;");
        self.emit("    }");
        for f in fields {
            if f.type in BUILTIN_PYTHON_TYPES {
                type_expr = f"ptr[PyObject](addressof({BUILTIN_PYTHON_TYPES[f.type]}))";
            } else {
                type_expr = self.st(f"{f.type}_type");
            }
            quantifier = 1 if f.opt() else (2 if f.seq() else 0);
            self.emit(
                f"    if not add_field_annotation(annotations, {c_literal(f.name)}, {type_expr}, {quantifier}) {{"
            );
            self.emit("        object_decref(annotations);");
            self.emit("        return 0;");
            self.emit("    }");
        }
        self.emit(
            f"    if not set_field_annotations({self.st(
                name + '_type'
            )}, annotations) {{"
        );
        self.emit("        return 0;");
        self.emit("    }");
    }

    def asdl_of(name: str, fields: list[Field]) -> str {
        text = ", ".join(f.describe() for f in fields);
        return f"{name}({text})" if text else name;
    }

    def sum_doc(d: Definition) -> str {
        if self.is_simple(d) {
            types = " | ".join(c.name for c in d.constructors);
        } else {
            sep = "\n" + " " * (len(d.name) + 1) + "| ";
            types = sep.join(self.asdl_of(c.name, c.fields) for c in d.constructors);
        }
        return f"{d.name} = {types}";
    }

    def make_type(name: str, base: str, table: str, count: int, doc: str) {
        self.emit(
            f"    {self.st(name + '_type')} = make_type(state, {c_literal(name)}, {base}, {table}, {count}, {c_literal(
                doc
            )});"
        );
        self.emit(f"    if not {self.st(name + '_type')} {{");
        self.emit("        return -1;");
        self.emit("    }");
    }

    def add_attributes(name: str, attributes: list[Field]) {
        table = f"addressof({name}_attributes)" if attributes else "ptr[ptr[u8]]()";
        self.emit(
            f"    if add_attributes(state, {self.st(name + '_type')}, {table}, {len(
                attributes
            )}) < 0 {{"
        );
        self.emit("        return -1;");
        self.emit("    }");
    }

    def emit_defaults(name: str, fields: list[Field]) {
        for f in fields {
            if f.opt() {
                self.emit(
                    f"    if PyObject_SetAttr({self.st(name + '_type')}, {self.st(
                        f.name
                    )}, Py_None) == -1 {{"
                );
                self.emit("        return -1;");
                self.emit("    }");
            }
        }
    }

    def emit_init_types {
        self.emit("def init_types(arg: ptr) -> i32 {");
        self.emit("    state = ptr[ast_state](arg);");
        self.emit("    if init_identifiers(state) < 0 {");
        self.emit("        return -1;");
        self.emit("    }");
        self.emit(
            f"    {self.st('AST_type')} = PyType_FromSpec(addressof(AST_type_spec));"
        );
        self.emit(f"    if not {self.st('AST_type')} {{");
        self.emit("        return -1;");
        self.emit("    }");
        self.emit("    if add_ast_fields(state) < 0 {");
        self.emit("        return -1;");
        self.emit("    }");
        for d in self.definitions {
            if not d.is_sum {
                table = f"addressof({d.name}_fields)" if d.fields else "ptr[ptr[u8]]()";
                self.make_type(
                    d.name,
                    self.st("AST_type"),
                    table,
                    len(d.fields),
                    self.asdl_of(d.name, d.fields)
                );
                self.add_attributes(d.name, d.attributes);
                self.emit_defaults(d.name, d.fields);
                self.emit_defaults(d.name, d.attributes);
                continue;
            }
            self.make_type(
                d.name, self.st("AST_type"), "ptr[ptr[u8]]()", 0, self.sum_doc(d)
            );
            self.add_attributes(d.name, d.attributes);
            self.emit_defaults(d.name, d.attributes);
            for c in d.constructors {
                table = f"addressof({c.name}_fields)" if c.fields else "ptr[ptr[u8]]()";
                self.make_type(
                    c.name,
                    self.st(f"{d.name}_type"),
                    table,
                    len(c.fields),
                    self.asdl_of(c.name, c.fields)
                );
                self.emit_defaults(c.name, c.fields);
                if self.is_simple(d) {
                    self.emit(
                        f"    {self.st(c.name + '_singleton')} = PyType_GenericNew({self.st(
                            c.name + '_type'
                        )}, NULL, NULL);"
                    );
                    self.emit(f"    if not {self.st(c.name + '_singleton')} {{");
                    self.emit("        return -1;");
                    self.emit("    }");
                }
            }
        }
        self.emit("    if add_ast_annotations(state) == 0 {");
        self.emit("        return -1;");
        self.emit("    }");
        self.emit("    return 0;");
        self.emit("}");
        self.emit("");
    }

    # -- Arena constructors (FunctionVisitor) ----------------------------

    def params(fields: list[Field]) -> list[str] {
        return [f"{jac_name(f.name)}: {self.field_type(f)}" for f in fields];
    }

    def emit_constructor(
        name: str,
        owner: str,
        fields: list[Field],
        attributes: list[Field],
        in_union: bool
    ) {
        params = self.params(fields + attributes) + ["arena: ptr"];
        node_type = f"ptr[_{owner}]";
        self.emit(f"    def _PyAST_{name}({', '.join(params)}) -> {node_type} {{");
        for f in fields {
            if f.opt() or f.seq() or self.is_numeric(f) {
                continue;
            }
            missing = f"{jac_name(f.name)} == 0"
                if self.field_type(f) == "i32"
                else f"not {jac_name(f.name)}";
            self.emit(f"        if {missing} {{");
            message = c_literal(f"field '{f.name}' is required for {name}");
            self.emit(f"            PyErr_SetString(PyExc_ValueError, {message});");
            self.emit(f"            return {node_type}();");
            self.emit("        }");
        }
        self.emit(f"        p = {node_type}(_PyArena_Malloc(arena, _{owner}_SIZE));");
        self.emit("        if not p {");
        self.emit(f"            return {node_type}();");
        self.emit("        }");
        if in_union {
            self.emit(f"        p.view(1)[0].kind = {name}_kind;");
            if fields {
                self.emit(f"        v = ptr[_{owner}_{name}](node_union(ptr(p)));");
                for f in fields {
                    self.emit(
                        f"        v.view(1)[0].{jac_name(f.name)} = {jac_name(f.name)};"
                    );
                }
            }
        } else {
            for f in fields {
                self.emit(
                    f"        p.view(1)[0].{jac_name(f.name)} = {jac_name(f.name)};"
                );
            }
        }
        for f in attributes {
            self.emit(f"        p.view(1)[0].{jac_name(f.name)} = {jac_name(f.name)};");
        }
        self.emit("        return p;");
        self.emit("    }");
    }

    def emit_constructors {
        self.emit("import from c {");
        for d in self.definitions {
            if self.is_simple(d) {
                continue;
            }
            self.emit(
                f"    def _Py_asdl_{d.name}_seq_new(size: i64, arena: ptr) -> ptr {{"
            );
            self.emit("        return _Py_asdl_generic_seq_new(size, arena);");
            self.emit("    }");
        }
        for d in self.definitions {
            if d.is_sum {
                if self.is_simple(d) {
                    continue;
                }
                for c in d.constructors {
                    self.emit_constructor(c.name, d.name, c.fields, d.attributes, True);
                }
            } else {
                self.emit_constructor(d.name, d.name, d.fields, d.attributes, False);
            }
        }
        self.emit("}");
        self.emit("");
    }

    # -- AST -> Python (ObjVisitor) --------------------------------------

    def ast2obj_value(type_name: str, access: str) -> str {
        if type_name in OBJECT_TYPES {
            return f"ast2obj_object(state, {access})";
        }
        if type_name == "int" {
            return f"ast2obj_int(state, i64({access}))";
        }
        return f"ast2obj_{type_name}(state, {access})";
    }

    def list_kind(type_name: str) -> str {
        return "object" if type_name in OBJECT_TYPES else type_name;
    }

    def ast2obj_set(f: Field, access: str, indent: str) {
        if f.seq() and f.type in self.simple_sums {
            count = f"n_{f.name}";
            index = f"i_{f.name}";
            self.emit(f"{indent}{count} = asdl_seq_len({access});");
            self.emit(f"{indent}value = PyList_New({count});");
            self.emit(f"{indent}if not value {{");
            self.emit(f"{indent}    return ast2obj_failed(result, value);");
            self.emit(f"{indent}}}");
            self.emit(f"{indent}{index}: i64 = 0;");
            self.emit(f"{indent}while {index} < {count} {{");
            self.emit(
                f"{indent}    list_set_item(value, {index}, ast2obj_{f.type}(state, asdl_int_seq_get({access}, {index})));"
            );
            self.emit(f"{indent}    {index} += 1;");
            self.emit(f"{indent}}}");
        } elif f.seq() {
            self.emit(
                f"{indent}value = ast2obj_list_{self.list_kind(f.type)}(state, {access});"
            );
        } else {
            self.emit(f"{indent}value = {self.ast2obj_value(f.type, access)};");
        }
    }

    def ast2obj_field(f: Field, access: str, indent: str) {
        self.ast2obj_set(f, access, indent);
        self.emit(f"{indent}if not value {{");
        self.emit(f"{indent}    return ast2obj_failed(result, value);");
        self.emit(f"{indent}}}");
        self.emit(
            f"{indent}if PyObject_SetAttr(result, {self.st(f.name)}, value) == -1 {{"
        );
        self.emit(f"{indent}    return ast2obj_failed(result, value);");
        self.emit(f"{indent}}}");
        self.emit(f"{indent}object_decref(value);");
    }

    def ast2obj_begin(name: str) {
        self.emit(
            f"def ast2obj_{name}(state: ptr[ast_state], o: ptr[_{name}]) -> ptr[PyObject] {{"
        );
        self.emit("    result = NULL;");
        self.emit("    value = NULL;");
        self.emit("    if not o {");
        self.emit("        return object_new_ref(Py_None);");
        self.emit("    }");
        self.emit(
            f"    if Py_EnterRecursiveCall({c_literal(
                'during  ast construction'
            )}) != 0 {{"
        );
        self.emit("        return NULL;");
        self.emit("    }");
    }

    def ast2obj_end {
        self.emit("    Py_LeaveRecursiveCall();");
        self.emit("    return result;");
        self.emit("}");
        self.emit("");
    }

    def emit_ast2obj {
        lists: list[str] = [];
        for d in self.definitions {
            fields = d.fields + d.attributes;
            for c in d.constructors {
                fields = fields + c.fields;
            }
            for f in fields {
                if f.seq() and f.type not in self.simple_sums {
                    kind = self.list_kind(f.type);
                    if kind not in lists {
                        lists.append(kind);
                    }
                }
            }
        }
        for kind in lists {
            element = "ptr[PyObject]" if kind == "object" else self.value_type(kind);
            self.emit(
                f"def ast2obj_list_{kind}(state: ptr[ast_state], seq: ptr[asdl_seq]) -> ptr[PyObject] {{"
            );
            self.emit("    n = asdl_seq_len(seq);");
            self.emit("    result = PyList_New(n);");
            self.emit("    if not result {");
            self.emit("        return NULL;");
            self.emit("    }");
            self.emit("    i: i64 = 0;");
            self.emit("    while i < n {");
            self.emit(
                f"        value = ast2obj_{kind}(state, {element}(asdl_seq_get_untyped(seq, i)));"
            );
            self.emit("        if not value {");
            self.emit("            object_decref(result);");
            self.emit("            return NULL;");
            self.emit("        }");
            self.emit("        list_set_item(result, i, value);");
            self.emit("        i += 1;");
            self.emit("    }");
            self.emit("    return result;");
            self.emit("}");
            self.emit("");
        }
        for d in self.definitions {
            if self.is_simple(d) {
                self.emit(
                    f"def ast2obj_{d.name}(state: ptr[ast_state], o: i32) -> ptr[PyObject] {{"
                );
                for c in d.constructors {
                    self.emit(f"    if o == {c.name} {{");
                    self.emit(
                        f"        return object_new_ref({self.st(
                            c.name + '_singleton'
                        )});"
                    );
                    self.emit("    }");
                }
                self.emit(
                    f"    _Py_FatalErrorFunc({c_literal('ast2obj_' + d.name)}, {c_literal(
                        'Unreachable C code path reached'
                    )});"
                );
                self.emit("    return NULL;");
                self.emit("}");
                self.emit("");
                continue;
            }
            self.ast2obj_begin(d.name);
            if d.is_sum {
                self.emit("    kind = o.view(1)[0].kind;");
                first = True;
                for c in d.constructors {
                    keyword = "if" if first else "} elif";
                    first = False;
                    self.emit(f"    {keyword} kind == {c.name}_kind {{");
                    self.emit(
                        f"        result = PyType_GenericNew({self.st(
                            c.name + '_type'
                        )}, NULL, NULL);"
                    );
                    self.emit("        if not result {");
                    self.emit("            return ast2obj_failed(result, value);");
                    self.emit("        }");
                    if c.fields {
                        union_var = f"v_{c.name}";
                        self.emit(
                            f"        {union_var} = ptr[_{d.name}_{c.name}](node_union(ptr(o)));"
                        );
                        for f in c.fields {
                            self.ast2obj_field(
                                f,
                                f"{union_var}.view(1)[0].{jac_name(f.name)}",
                                "        "
                            );
                        }
                    }
                }
                self.emit("    }");
            } else {
                self.emit(
                    f"    result = PyType_GenericNew({self.st(
                        d.name + '_type'
                    )}, NULL, NULL);"
                );
                self.emit("    if not result {");
                self.emit("        return NULL;");
                self.emit("    }");
                for f in d.fields {
                    self.ast2obj_field(f, f"o.view(1)[0].{jac_name(f.name)}", "    ");
                }
            }
            for a in d.attributes {
                self.ast2obj_field(a, f"o.view(1)[0].{jac_name(a.name)}", "    ");
            }
            self.ast2obj_end();
        }
    }

    # -- Python -> AST (Obj2ModVisitor) ----------------------------------

    # One field's conversion into the local `var`; `owner` names the node in
    # messages and `fail` is the failure return.
    def obj2ast_field(f: Field, owner: str, fail: str) {
        var = jac_name(f.name);
        self.emit(
            f"    if PyObject_GetOptionalAttr(obj_, {self.st(f.name)}, &mut tmp) < 0 {{"
        );
        self.emit(f"        return {fail};");
        self.emit("    }");
        guard = c_literal(f" while traversing '{owner}' node");
        if f.seq() {
            count = f"len_{f.name}";
            index = f"i_{f.name}";
            status = f"res_{f.name}";
            item = f"item_{f.name}";
            seq_kind = "int" if self.is_simple_type(f) else f.type;
            self.emit("    if not tmp {");
            self.emit("        tmp = PyList_New(0);");
            self.emit("        if not tmp {");
            self.emit(f"            return {fail};");
            self.emit("        }");
            self.emit("    }");
            self.emit("    if not list_check(tmp) {");
            message = c_literal(
                f'{owner} field "{f.name}" must be a list, not a %.200s'
            );
            self.emit(
                f"        PyErr_Format(PyExc_TypeError, {message}, _PyType_Name(ptr[PyObject](object_type(tmp))));"
            );
            self.emit("        object_xdecref(tmp);");
            self.emit(f"        return {fail};");
            self.emit("    }");
            self.emit(f"    {count} = object_size(tmp);");
            self.emit(
                f"    {var} = ptr[asdl_seq](_Py_asdl_{seq_kind}_seq_new({count}, arena));"
            );
            self.emit(f"    if not {var} {{");
            self.emit("        object_xdecref(tmp);");
            self.emit(f"        return {fail};");
            self.emit("    }");
            self.emit(f"    {index}: i64 = 0;");
            self.emit(f"    while {index} < {count} {{");
            self.emit(f"        tmp2 = object_new_ref(list_get_item(tmp, {index}));");
            self.emit(f"        if Py_EnterRecursiveCall({guard}) != 0 {{");
            self.emit("            object_xdecref(tmp);");
            self.emit(f"            return {fail};");
            self.emit("        }");
            self.emit(
                f"        ({status}, {item}) = obj2ast_{f.type}(state, tmp2, arena);"
            );
            self.emit("        Py_LeaveRecursiveCall();");
            self.emit("        object_decref(tmp2);");
            self.emit(f"        if {status} != 0 {{");
            self.emit("            object_xdecref(tmp);");
            self.emit(f"            return {fail};");
            self.emit("        }");
            self.emit(f"        if {count} != object_size(tmp) {{");
            message = c_literal(
                f'{owner} field "{f.name}" changed size during iteration'
            );
            self.emit(f"            PyErr_SetString(PyExc_RuntimeError, {message});");
            self.emit("            object_xdecref(tmp);");
            self.emit(f"            return {fail};");
            self.emit("        }");
            if self.is_simple_type(f) {
                self.emit(f"        asdl_int_seq_set({var}, {index}, {item});");
            } else {
                self.emit(f"        asdl_seq_set({var}, {index}, ptr({item}));");
            }
            self.emit(f"        {index} += 1;");
            self.emit("    }");
            self.emit("    object_decref(tmp);");
            self.emit("    tmp = NULL;");
            return;
        }
        if not f.opt() {
            self.emit("    if not tmp {");
            message = c_literal(f'required field "{f.name}" missing from {owner}');
            self.emit(f"        PyErr_SetString(PyExc_TypeError, {message});");
            self.emit(f"        return {fail};");
            self.emit("    }");
        } else {
            if self.is_numeric(f) {
                fallback = jac_name(ATTRIBUTE_DEFAULTS.get(f.name, ""))
                    if f.name in ATTRIBUTE_DEFAULTS
                    else "0";
            } elif not self.is_simple_type(f) {
                fallback = self.zero(self.field_type(f));
            } else {
                raise AsdlError(f"could not determine the default value for {f.name}");
            }
            self.emit("    if not tmp or tmp == Py_None {");
            self.emit("        object_xdecref(tmp);");
            self.emit("        tmp = NULL;");
            self.emit(f"        {var} = {fallback};");
            self.emit("    } else {");
        }
        status = f"res_{f.name}";
        value = f"val_{f.name}";
        self.emit(f"    if Py_EnterRecursiveCall({guard}) != 0 {{");
        self.emit("        object_xdecref(tmp);");
        self.emit(f"        return {fail};");
        self.emit("    }");
        self.emit(f"    ({status}, {value}) = obj2ast_{f.type}(state, tmp, arena);");
        self.emit("    Py_LeaveRecursiveCall();");
        self.emit(f"    if {status} != 0 {{");
        self.emit("        object_xdecref(tmp);");
        self.emit(f"        return {fail};");
        self.emit("    }");
        self.emit(f"    {var} = {value};");
        self.emit("    object_decref(tmp);");
        self.emit("    tmp = NULL;");
        if f.opt() {
            self.emit("    }");
        }
    }

    def declare(fields: list[Field]) {
        for f in fields {
            jt = self.field_type(f);
            self.emit(f"    {jac_name(f.name)}: {jt} = {self.zero(jt)};");
        }
    }

    def obj2ast_signature(name: str, extra: list[str], result: str) -> str {
        params = ["state: ptr[ast_state]", "obj_: ptr[PyObject]", "arena: ptr"] + extra;
        return f"def obj2ast_{name}({', '.join(params)}) -> tuple[i32, {result}] {{";
    }

    # Build the node from the converted locals and return it.
    def obj2ast_finish(name: str, args: list[Field], node_type: str) {
        call_args = ", ".join([jac_name(f.name) for f in args] + ["arena"]);
        self.emit(f"    out = _PyAST_{name}({call_args});");
        self.emit("    if not out {");
        self.emit("        object_xdecref(tmp);");
        self.emit(f"        return (i32(-1), {self.zero(node_type)});");
        self.emit("    }");
        self.emit("    return (i32(0), out);");
        self.emit("}");
        self.emit("");
    }

    def emit_obj2ast {
        for d in self.definitions {
            if self.is_simple(d) {
                self.emit(self.obj2ast_signature(d.name, [], "i32"));
                for c in d.constructors {
                    self.emit(
                        f"    isinstance_ = PyObject_IsInstance(obj_, {self.st(
                            c.name + '_type'
                        )});"
                    );
                    self.emit("    if isinstance_ == -1 {");
                    self.emit("        return (i32(-1), i32(0));");
                    self.emit("    }");
                    self.emit("    if isinstance_ != 0 {");
                    self.emit(f"        return (i32(0), {c.name});");
                    self.emit("    }");
                }
                message = c_literal(f"expected some sort of {d.name}, but got %R");
                self.emit(f"    PyErr_Format(PyExc_TypeError, {message}, obj_);");
                self.emit("    return (i32(-1), i32(0));");
                self.emit("}");
                self.emit("");
                continue;
            }
            node_type = f"ptr[_{d.name}]";
            fail = f"(i32(-1), {self.zero(node_type)})";
            if not d.is_sum {
                self.emit(self.obj2ast_signature(d.name, [], node_type));
                self.emit("    tmp = NULL;");
                self.declare(d.fields + d.attributes);
                for f in d.fields + d.attributes {
                    self.obj2ast_field(f, d.name, fail);
                }
                self.obj2ast_finish(d.name, d.fields + d.attributes, node_type);
                continue;
            }
            attribute_params = [f"{jac_name(a.name)}: i32" for a in d.attributes];
            for c in d.constructors {
                names = {f.name for f in c.fields};
                for a in d.attributes {
                    if a.name in names {
                        raise AsdlError(
                            f"{c.name} has a field named like attribute {a.name}"
                        );
                    }
                }
                self.emit(
                    self.obj2ast_signature(
                        f"{d.name}_{c.name}", attribute_params, node_type
                    )
                );
                self.emit("    tmp = NULL;");
                self.declare(c.fields);
                for f in c.fields {
                    self.obj2ast_field(f, c.name, fail);
                }
                self.obj2ast_finish(c.name, c.fields + d.attributes, node_type);
            }
            self.emit(self.obj2ast_signature(d.name, [], node_type));
            self.emit("    tmp = NULL;");
            self.declare(d.attributes);
            self.emit("    if obj_ == Py_None {");
            self.emit(f"        return (i32(0), {self.zero(node_type)});");
            self.emit("    }");
            for a in d.attributes {
                self.obj2ast_field(a, d.name, fail);
            }
            attribute_args = ", ".join(jac_name(a.name) for a in d.attributes);
            for c in d.constructors {
                self.emit(
                    f"    isinstance_ = PyObject_IsInstance(obj_, {self.st(
                        c.name + '_type'
                    )});"
                );
                self.emit("    if isinstance_ == -1 {");
                self.emit(f"        return {fail};");
                self.emit("    }");
                self.emit("    if isinstance_ != 0 {");
                args = "state, obj_, arena"
                    + (f", {attribute_args}" if attribute_args else "");
                self.emit(f"        return obj2ast_{d.name}_{c.name}({args});");
                self.emit("    }");
            }
            message = c_literal(f"expected some sort of {d.name}, but got %R");
            self.emit(f"    PyErr_Format(PyExc_TypeError, {message}, obj_);");
            self.emit("    object_xdecref(tmp);");
            self.emit(f"    return {fail};");
            self.emit("}");
            self.emit("");
        }
    }

    # -- The _ast module (ASTModuleVisitor) ------------------------------

    def add_object(name: str) {
        self.emit(
            f"    if PyModule_AddObjectRef(m, {c_literal(name)}, {self.st(
                name + '_type'
            )}) < 0 {{"
        );
        self.emit("        return -1;");
        self.emit("    }");
    }

    def emit_module_exec {
        self.emit("def astmodule_exec(m: ptr[PyObject]) -> i32 {");
        self.emit("    state = get_ast_state();");
        self.emit("    if not state {");
        self.emit("        return -1;");
        self.emit("    }");
        self.add_object("AST");
        for flag in (
            "PyCF_ALLOW_TOP_LEVEL_AWAIT",
            "PyCF_ONLY_AST",
            "PyCF_TYPE_COMMENTS",
            "PyCF_OPTIMIZED_AST"
        ) {
            self.emit(
                f"    if PyModule_AddIntConstant(m, {c_literal(flag)}, i64({flag})) < 0 {{"
            );
            self.emit("        return -1;");
            self.emit("    }");
        }
        for d in self.definitions {
            self.add_object(d.name);
            for c in d.constructors {
                self.add_object(c.name);
            }
        }
        self.emit("    return 0;");
        self.emit("}");
        self.emit("");
    }

    def generate -> str {
        body_start = len(self.out);
        self.emit_records();
        records = self.out[body_start:];
        self.out = self.out[:body_start];
        self.emit_constants();
        self.out += records;
        (strings, state) = self.module_state();
        self.emit_fini(state);
        self.emit_identifiers(strings);
        self.emit_annotations();
        self.emit_init_types();
        self.emit_constructors();
        self.emit_ast2obj();
        self.emit_obj2ast();
        self.emit_module_exec();
        return "\n".join(self.out) + "\n";
    }
}

def module_docstring(version: str) -> str {
    return "\n".join(
        [
            '"""The AST object layer and the _ast module.',
            "",
            f"Generated by {COMMAND} from CPython {version}",
            f"{ASDL_SOURCE} and scripts/jacpython/python_ast.jac.in, as Parser/asdl_c.py",
            "writes Python/Python-ast.c; do not edit. The node structs of",
            "Include/internal/pycore_ast.h are records here (a sum's union `v` is its widest",
            "constructor's record, each constructor's members a record read at",
            "AST_UNION_OFFSET), and the exported C functions keep their C names. See",
            '../LICENSE.cpython."""',
            ""
        ]
    );
}

# Compare the generated layout facts with the C compiler's reading of the
# configured headers.
def verify(facts: list[tuple[str, str, int]], headers: str, cc: str) {
    import from gen_layouts { extract }
    constants = [(f"ast_{name}", expression, "i64") for (name, expression, _) in facts];
    values = extract(Path(headers), shlex.split(cc), constants);
    wrong = [
        f"{expression} is {values[f'ast_{name}']}, generated {expected}"
        for (name, expression, expected) in facts
        if values[f"ast_{name}"] != expected
    ];
    if wrong {
        sys.exit(
            f"{COMMAND}: the generated layouts do not match pycore_ast.h:\n"
                + "\n".join(wrong)
        );
    }
    print(f"verified {len(facts)} layout facts against {headers}");
}

# Format `text` as `jac fmt --lintfix` leaves it in place at TARGET (runtime
# code: docstrings stripped, bodies in impls), repeated to a fixed point. The
# scratch directory sits beside TARGET and is named relative to jac/, as
# `jac fmt --lintfix` is run on runtime modules from there.
def lintfixed(text: str) -> str {
    jac = shutil.which("jac");
    if jac is None {
        sys.exit("jac is not on PATH; generated Jac is formatted with `jac fmt`");
    }
    scratch = Path(tempfile.mkdtemp(prefix="gen_ast_", dir=TARGET.parent));
    path = scratch / TARGET.name;
    try {
        path.write_text(text);
        for _ in range(4) {
            before = path.read_text();
            result = subprocess.run(
                [jac, "fmt", "--lintfix", str(path.relative_to(JAC))],
                capture_output=True,
                text=True,
                cwd=JAC
            );
            if result.returncode != 0 {
                sys.exit(
                    f"jac fmt failed on generated Jac:\n{result.stdout}{result.stderr}"
                );
            }
            if path.read_text() == before {
                break;
            }
        }
        return path.read_text();
    } finally {
        shutil.rmtree(scratch, ignore_errors=True);
    }
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate the native AST object layer from Parser/Python.asdl"
    );
    parser.add_argument("--check", action="store_true");
    parser.add_argument(
        "--headers", help="a configured CPython's include directory, to verify layouts"
    );
    parser.add_argument("--cc", help="C compiler command for --headers");
    parser.set_defaults(cc="cc");
    args = parser.parse_args();
    import from gen_layouts { JAC_KEYWORDS }
    text = archive_texts((ASDL_SOURCE, ))[ASDL_SOURCE];
    try {
        definitions = Parser(tokens=tokenize_asdl(text)).module();
        check_types(definitions);
        generator = Generator(
            definitions=definitions,
            state_keywords=set(JAC_KEYWORDS),
            simple_sums=set(),
            singletons=set(),
            identifiers=set(),
            types={"AST"},
            out=[],
            facts=[]
        );
        generator.collect();
        generated = generator.generate();
    } except AsdlError as reason {
        sys.exit(f"{COMMAND}: {reason}");
    }
    if args.headers {
        verify(generator.facts, args.headers, args.cc);
    }
    rendered = module_docstring(pin()["version"])
        + "\n"
        + TEMPLATE.read_text()
        + "\n"
        + generated;
    if not write_or_check(TARGET, lintfixed(rendered), args.check, COMMAND) {
        sys.exit(1);
    }
}
