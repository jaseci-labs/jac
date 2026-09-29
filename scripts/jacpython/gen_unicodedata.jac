"""Generate the Unicode database tables of the native unicodedata module.

CPython's Tools/unicode/makeunicodedata.py writes the tables unicodedata.c
reads as two generated headers, Modules/unicodedata_db.h (character
properties, decomposition, composition and the 3.2.0 deltas) and
Modules/unicodename_db.h (the character-name DAWG, aliases and named
sequences). This script reads both from the pinned CPython archive and writes
them as C data definitions, so the port links the same tables with no C
source and no start-up work:

    jac run scripts/jacpython/gen_unicodedata.jac            # rewrite both files
    jac run scripts/jacpython/gen_unicodedata.jac --check    # fail on drift

- jaclang/runtime/python/modules/unicodedata_db.jac
- jaclang/runtime/python/modules/unicodename_db.jac

An integer table is a bytes literal of its little-endian elements, which the
native compiler lays out as the C array; a struct table is a list of foreign
struct constructors and a string table a list of C strings. The two pieces of
logic the header carries (get_change_3_2_0's two-level lookup and the
normalization_3_2_0 switch) become data: the lookup's shift and the switch's
case pairs. Table names keep their C spelling; the static ones take a `ucd_`
or `ucn_` prefix because a C data definition is an exported symbol.
"""
import argparse;
import re;
import sys;
import from pathlib { Path }
import from common {
    RUNTIME,
    archive_texts,
    bytes_literal,
    format_jac_many,
    pin,
    write_or_check
}

glob COMMAND: str = "scripts/jacpython/gen_unicodedata.jac",
     DATABASE: Path = RUNTIME / "modules/unicodedata_db.jac",
     NAMES: Path = RUNTIME / "modules/unicodename_db.jac",
     # C scalar types of the tables and struct fields, as Jac sized types.
     C_TYPES: dict[str, str] = {
         "unsigned char": "u8",
         "unsigned short": "u16",
         "unsigned int": "u32",
         "char": "u8",
         "short": "i16",
         "int": "i32",
         "Py_UCS2": "u16",
         "Py_UCS4": "u32",
         "double": "f64"
     };

obj Unsupported(Exception) {}

def strip_comments(text: str) -> str {
    return re.sub(r"/\*.*?\*/", "", re.sub(r"//[^\n]*", "", text), flags=re.S);
}

# `#define NAME value` lines of a header.
def defines(text: str) -> dict[str, str] {
    return {
        m.group(1): m.group(2).strip()
        for m in re.finditer(r"^#define\s+(\w+)\s+(.+)$", text, re.M)
    };
}

def define_int(found: dict[str, str], name: str) -> int {
    if name not in found {
        raise Unsupported(f"#define {name} not found");
    }
    return int(found[name], 0);
}

# `static const unsigned int name = value;` scalars of a header.
def scalar(text: str, name: str) -> int {
    m = re.search(r"\b" + name + r"\s*=\s*([0-9a-fA-Fx]+)\s*;", text);
    if m is None {
        raise Unsupported(f"scalar {name} not found");
    }
    return int(m.group(1), 0);
}

# The element type and initializer body of the C array `name`.
def array(text: str, name: str) -> tuple[str, str] {
    m = re.search(
        r"^(?:static\s+)?(?:const\s+)?([\w ]+?)\s*(\*?)\s*(?:const\s+)?\b"
            + name
            + r"\[\]\s*=\s*\{(.*?)\n\};",
        text,
        re.M | re.S
    );
    if m is None {
        raise Unsupported(f"array {name} not found");
    }
    return (m.group(1).strip() + m.group(2), m.group(3));
}

def jac_type(ctype: str) -> str {
    ctype = ctype.replace("const ", "").strip();
    if ctype not in C_TYPES {
        raise Unsupported(f"no Jac type for C type {ctype!r}");
    }
    return C_TYPES[ctype];
}

def int_items(body: str) -> list[int] {
    return [
        int(item, 0)
        for item in re.split(r"[,\s]+", body.strip())
        if item
    ];
}

def int_array(text: str, name: str) -> tuple[str, list[int]] {
    (ctype, body) = array(text, name);
    return (jac_type(ctype), int_items(body));
}

# Brace-delimited records of a struct array: each record's items as text.
def records(body: str) -> list[list[str]] {
    found: list[list[str]] = [];
    for m in re.finditer(r"\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}", body) {
        inner = m.group(1);
        nested = re.search(r"\{([^{}]*)\}", inner);
        head = inner[:nested.start()] if nested else inner;
        items = [
            item.strip()
            for item in head.split(",")
            if item.strip()
        ];
        if nested {
            items.append("{" + nested.group(1) + "}");
        }
        found.append(items);
    }
    return found;
}

# (field, Jac type) of a C struct body `type a; type b, c;`.
def struct_fields(body: str) -> list[tuple[str, str]] {
    fields: list[tuple[str, str]] = [];
    for decl in strip_comments(body).split(";") {
        decl = " ".join(decl.split());
        if not decl {
            continue;
        }
        m = re.match(r"((?:const\s+)?(?:unsigned\s+)?\w+)\s+(.+)$", decl);
        if m is None {
            raise Unsupported(f"cannot read struct field {decl!r}");
        }
        jt = jac_type(m.group(1));
        for declarator in m.group(2).split(",") {
            fields.append((declarator.strip(), jt));
        }
    }
    return fields;
}

def typedef_fields(text: str, name: str) -> list[tuple[str, str]] {
    m = re.search(
        r"typedef\s+struct\s*\w*\s*\{([^{}]*)\}\s*" + name + r"\s*;", text, re.S
    );
    if m is None {
        raise Unsupported(f"typedef {name} not found");
    }
    return struct_fields(m.group(1));
}

def c_string(item: str) -> str {
    if item == "NULL" or item == "0" {
        return "ptr[u8]()";
    }
    if not (item.startswith('"') and item.endswith('"')) {
        raise Unsupported(f"not a C string literal: {item!r}");
    }
    return f"ptr[u8]({item})";
}

def string_table(text: str, name: str) -> list[str] {
    (_, body) = array(text, name);
    items = re.findall(r'"(?:[^"\\]|\\.)*"|\bNULL\b', strip_comments(body));
    return [c_string(item) for item in items];
}

def struct_value(struct: str, fields: list[tuple[str, str]], items: list[str]) -> str {
    if len(items) != len(fields) {
        raise Unsupported(f"{struct} record {items} does not match its fields");
    }
    parts: list[str] = [];
    for ((_, jt), item) in zip(fields, items) {
        if jt == "f64" {
            parts.append(repr(float(item)));
        } else {
            parts.append(str(int(item, 0)));
        }
    }
    return f"{struct}({', '.join(parts)})";
}

obj Emitter {
    has lines: list[str] = [],
        structs: list[str] = [],
        data: list[str] = [],
        constants: list[str] = [];

    def struct(name: str, fields: list[tuple[str, str]]) {
        body = ", ".join(f"{field}: {jt}" for (field, jt) in fields);
        self.structs.append(f"obj {name} {{ has {body}; }}");
    }

    def constant(name: str, jt: str, value: any) {
        self.constants.append(f"{name}: Final[{jt}] = {value!r}");
    }

    def ints(name: str, jt: str, values: list[int]) {
        self.data.append(f"{name}: list[{jt}] = {bytes_literal(values, jt)}");
    }

    def strings(name: str, items: list[str]) {
        self.data.append(f"{name}: list[ptr[u8]] = [{', '.join(items)}]");
    }

    def structs_of(name: str, struct: str, values: list[str]) {
        self.data.append(f"{name}: list[{struct}] = [{', '.join(values)}]");
    }

    def render(doc: list[str]) -> str {
        out = ['"""' + doc[0]] + doc[1:] + ['"""', ""];
        out.append("glob " + ",\n     ".join(self.constants) + ";");
        out.append("");
        out.append("import from c {");
        out += [f"    {s}" for s in self.structs];
        out.append("    glob " + ",\n         ".join(self.data) + ";");
        out.append("}");
        return "\n".join(out) + "\n";
    }
}

def database(text: str, module: str, version: str) -> str {
    emitter = Emitter();
    found = defines(text);
    unidata = found.get("UNIDATA_VERSION", "").strip('"');
    if not unidata {
        raise Unsupported("UNIDATA_VERSION not found");
    }
    emitter.constants.append(f'UNIDATA_VERSION: Final[str] = "{unidata}"');
    for name in ("SHIFT", "DECOMP_SHIFT", "COMP_SHIFT", "TOTAL_FIRST", "TOTAL_LAST") {
        emitter.constant(name, "i64", define_int(found, name));
    }
    # get_change_3_2_0: index = changes_3_2_0_index[n>>S]; then
    # changes_3_2_0_data[(index<<S)+(n & M)] with M = (1 << S) - 1.
    lookup = re.search(
        r"changes_3_2_0_index\[n>>(\d+)\];.*?changes_3_2_0_data\[\(index<<(\d+)\)\+\(n & (\d+)\)\]",
        text,
        re.S
    );
    if lookup is None
        or lookup.group(1) != lookup.group(2)
        or int(lookup.group(3)) != (1 << int(lookup.group(1))) - 1 {
        raise Unsupported("get_change_3_2_0 is not the expected two-level lookup");
    }
    emitter.constant("CHANGES_3_2_0_SHIFT", "i64", int(lookup.group(1)));
    cases_block = re.search(
        r"normalization_3_2_0\(Py_UCS4 n\)\s*\{\s*switch\(n\)\s*\{(.*?)default: return 0;",
        text,
        re.S
    );
    if cases_block is None {
        raise Unsupported("normalization_3_2_0 switch not found");
    }
    cases = re.findall(
        r"case (0x[0-9a-fA-F]+): return (0x[0-9a-fA-F]+);", cases_block.group(1)
    );
    emitter.constant("NORMALIZATION_3_2_0_LENGTH", "i64", len(cases));

    record_fields = typedef_fields(module, "_PyUnicode_DatabaseRecord");
    change_fields = typedef_fields(module, "change_record");
    reindex = re.search(r"struct reindex\s*\{([^{}]*)\};", text);
    if reindex is None {
        raise Unsupported("struct reindex not found");
    }
    emitter.struct("DatabaseRecord", record_fields);
    emitter.struct("ChangeRecord", change_fields);
    emitter.struct("Reindex", struct_fields(reindex.group(1)));
    emitter.struct("NormalizationChange", [("code", "u32"), ("value", "u32")]);

    (_, body) = array(text, "_PyUnicode_Database_Records");
    emitter.structs_of(
        "_PyUnicode_Database_Records",
        "DatabaseRecord",
        [
            struct_value("DatabaseRecord", record_fields, items)
            for items in records(body)
        ]
    );
    reindex_fields = struct_fields(reindex.group(1));
    for name in ("nfc_first", "nfc_last") {
        (_, body) = array(text, name);
        emitter.structs_of(
            f"ucd_{name}",
            "Reindex",
            [struct_value("Reindex", reindex_fields, items) for items in records(body)]
        );
    }
    for name in (
        "_PyUnicode_CategoryNames",
        "_PyUnicode_BidirectionalNames",
        "_PyUnicode_EastAsianWidthNames"
    ) {
        emitter.strings(name, string_table(text, name));
    }
    emitter.strings("ucd_decomp_prefix", string_table(text, "decomp_prefix"));
    for name in (
        "index1",
        "index2",
        "decomp_data",
        "decomp_index1",
        "decomp_index2",
        "comp_index",
        "comp_data",
        "changes_3_2_0_index",
        "changes_3_2_0_data"
    ) {
        (jt, values) = int_array(text, name);
        emitter.ints(f"ucd_{name}", jt, values);
    }
    (_, body) = array(text, "change_records_3_2_0");
    emitter.structs_of(
        "ucd_change_records_3_2_0",
        "ChangeRecord",
        [struct_value("ChangeRecord", change_fields, items) for items in records(body)]
    );
    emitter.structs_of(
        "ucd_normalization_3_2_0",
        "NormalizationChange",
        [
            f"NormalizationChange({int(code, 16)}, {int(value, 16)})"
            for (code, value) in cases
        ]
    );
    return emitter.render(
        [
            f"The Unicode {unidata} character database of the native unicodedata module.",
            "",
            f"Generated by {COMMAND} from CPython {version}",
            "Modules/unicodedata_db.h (Tools/unicode/makeunicodedata.py); do not edit.",
            "Integer tables are bytes literals of their little-endian elements;",
            "get_change_3_2_0's shift and normalization_3_2_0's cases are data here.",
            "See ../LICENSE.cpython."
        ]
    );
}

def names(text: str, version: str) -> str {
    emitter = Emitter();
    found = defines(text);
    for name in (
        "NAME_MAXLEN",
        "DAWG_CODEPOINT_TO_POS_SHIFT",
        "DAWG_CODEPOINT_TO_POS_NOTFOUND"
    ) {
        emitter.constant(name, "i64", define_int(found, name));
    }
    for name in (
        "aliases_start",
        "aliases_end",
        "named_sequences_start",
        "named_sequences_end"
    ) {
        emitter.constant(name, "i64", scalar(text, name));
    }
    range_fields = typedef_fields(text, "derived_name_range");
    (_, body) = array(text, "derived_name_ranges");
    ranges = records(body);
    prefixes = string_table(text, "derived_name_prefixes");
    emitter.constant("DERIVED_NAME_RANGES_LENGTH", "i64", len(ranges));
    emitter.constant("DERIVED_NAME_PREFIXES_LENGTH", "i64", len(prefixes));
    emitter.struct("DerivedNameRange", range_fields);
    for name in (
        "packed_name_dawg",
        "dawg_pos_to_codepoint",
        "dawg_codepoint_to_pos_index1",
        "dawg_codepoint_to_pos_index2",
        "name_aliases"
    ) {
        (jt, values) = int_array(text, name);
        emitter.ints(f"ucn_{name}", jt, values);
    }
    # named_sequence {int seqlen; Py_UCS2 seq[4];} as two tables: the lengths
    # and four UCS-2 slots per sequence.
    seq_fields = typedef_fields(text, "named_sequence");
    if [f for (f, _) in seq_fields] != ["seqlen", "seq[4]"] {
        raise Unsupported("named_sequence is not {int seqlen; Py_UCS2 seq[4];}");
    }
    (_, body) = array(text, "named_sequences");
    lengths: list[int] = [];
    chars: list[int] = [];
    for items in records(body) {
        seq = int_items(items[1].strip("{}"));
        if int(items[0], 0) != len(seq) or len(seq) > 4 {
            raise Unsupported(f"named sequence {items} does not fit seq[4]");
        }
        lengths.append(len(seq));
        chars += seq + [0] * (4 - len(seq));
    }
    emitter.ints("ucn_named_sequence_lengths", "u8", lengths);
    emitter.ints("ucn_named_sequence_chars", "u16", chars);
    emitter.structs_of(
        "ucn_derived_name_ranges",
        "DerivedNameRange",
        [struct_value("DerivedNameRange", range_fields, items) for items in ranges]
    );
    emitter.strings("ucn_derived_name_prefixes", prefixes);
    return emitter.render(
        [
            "The Unicode character names of the native unicodedata module.",
            "",
            f"Generated by {COMMAND} from CPython {version}",
            "Modules/unicodename_db.h (Tools/unicode/makeunicodedata.py); do not edit.",
            "Integer tables are bytes literals of their little-endian elements;",
            "named_sequences is split into its lengths and four UCS-2 slots per",
            "sequence. See ../LICENSE.cpython."
        ]
    );
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate the native unicodedata module's database tables"
    );
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    texts = archive_texts(
        (
            "Modules/unicodedata.c",
            "Modules/unicodedata_db.h",
            "Modules/unicodename_db.h"
        )
    );
    version = pin()["version"];
    try {
        rendered = [
            (
                database(
                    texts["Modules/unicodedata_db.h"],
                    texts["Modules/unicodedata.c"],
                    version
                ),
                DATABASE
            ),
            (names(texts["Modules/unicodename_db.h"], version), NAMES)
        ];
    } except Unsupported as reason {
        sys.exit(f"{COMMAND}: {reason}");
    }
    formatted = format_jac_many(rendered);
    current = True;
    for ((_, target), text) in zip(rendered, formatted) {
        current = write_or_check(target, text, args.check, COMMAND) and current;
    }
    if not current {
        sys.exit(1);
    }
}
