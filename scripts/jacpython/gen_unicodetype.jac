"""Generate the character type tables of the native str type.

CPython's Tools/unicode/makeunicodedata.py writes the tables
Objects/unicodectype.c reads as the generated header Objects/unicodetype_db.h:
the type records, the extended case mappings, the two-level index, and three
functions written as switch statements (_PyUnicode_ToNumeric,
_PyUnicode_IsWhitespace and _PyUnicode_IsLinebreak). This script reads it from
the pinned CPython archive and writes it as C data, so unicodectype.jac links
the same tables with no C source and no start-up work:

    jac run scripts/jacpython/gen_unicodetype.jac            # rewrite the file
    jac run scripts/jacpython/gen_unicodetype.jac --check    # fail on drift

- jaclang/runtime/python/object_model/unicodetype_db.jac

Tables are encoded as gen_unicodedata.jac encodes them. Each switch becomes
data: its case labels as a sorted code-point table, which unicodectype.jac
searches by bisection, and for _PyUnicode_ToNumeric a parallel table of
indexes into its distinct values. Table names keep their C spelling; the
static ones and the switch tables take a `uct_` prefix because a C data
definition is an exported symbol.
"""
import argparse;
import re;
import sys;
import from pathlib { Path }
import from common { RUNTIME, archive_texts, format_jac, pin, write_or_check }
import from gen_unicodedata {
    Emitter,
    Unsupported,
    array,
    define_int,
    defines,
    int_array,
    records,
    struct_value,
    typedef_fields
}

glob COMMAND: str = "scripts/jacpython/gen_unicodetype.jac",
     TYPE_DATABASE: Path = RUNTIME / "object_model/unicodetype_db.jac",
     # One token of a switch body: a case label or a return.
     CASE_TOKEN: str = r"case (0x[0-9a-fA-F]+):|return ([^;]+);",
     # The value `return (double) N;` or `return (double) N/D;` gives: C
     # converts N and divides in double, as float(N) / float(D) does.
     NUMERIC_RETURN: str = r"\(double\) (-?\d+(?:\.\d*)?(?:e[+-]?\d+)?)(?:/(\d+(?:\.\d*)?))?";

# The cases of the `switch (ch)` that is the whole body of the function
# declared `signature`: (code point, returned expression) pairs in source
# order, and the expression returned after the switch.
def switch_cases(text: str, signature: str) -> tuple[list[tuple[int, str]], str] {
    m = re.search(
        re.escape(signature)
            + r"\s*\{\s*switch \(ch\) \{(.*?)\n    \}\n    return ([^;]+);\n\}",
        text,
        re.S
    );
    if m is None {
        raise Unsupported(f"the switch of {signature} not found");
    }
    body = m.group(1);
    if re.sub(CASE_TOKEN, "", body).strip() {
        raise Unsupported(
            f"{signature}: the switch holds more than case labels and returns"
        );
    }
    cases: list[tuple[int, str]] = [];
    pending: list[int] = [];
    for token in re.finditer(CASE_TOKEN, body) {
        if token.group(1) {
            pending.append(int(token.group(1), 16));
        } else {
            if not pending {
                raise Unsupported(f"{signature}: a return without a case label");
            }
            cases += [(code, token.group(2).strip()) for code in pending];
            pending = [];
        }
    }
    if pending or not cases {
        raise Unsupported(f"{signature}: case labels without a return");
    }
    codes = [code for (code, _) in cases];
    if len(set(codes)) != len(codes) {
        raise Unsupported(f"{signature}: a code point has two case labels");
    }
    return (cases, m.group(2).strip());
}

def numeric_value(expr: str) -> float {
    m = re.fullmatch(NUMERIC_RETURN, expr);
    if m is None {
        raise Unsupported(f"_PyUnicode_ToNumeric returns {expr!r}");
    }
    if m.group(2) {
        return float(m.group(1)) / float(m.group(2));
    }
    return float(m.group(1));
}

# The sorted case labels of a switch that returns 1 for each and 0 after.
def code_set(text: str, signature: str) -> list[int] {
    (cases, fallback) = switch_cases(text, signature);
    if fallback != "0" or any(value != "1" for (_, value) in cases) {
        raise Unsupported(f"{signature} is not a 1-for-listed, 0-otherwise switch");
    }
    return sorted(code for (code, _) in cases);
}

def type_database(text: str, module: str, version: str) -> str {
    emitter = Emitter();
    shift = define_int(defines(text), "SHIFT");
    # gettyperecord: index = index1[code>>SHIFT]; then
    # index2[(index<<SHIFT)+(code&((1<<SHIFT)-1))].
    lookup = re.search(
        r"index = index1\[\(code>>SHIFT\)\];\s*"
            + r"index = index2\[\(index<<SHIFT\)\+\(code&\(\(1<<SHIFT\)-1\)\)\];",
        module
    );
    if lookup is None {
        raise Unsupported("gettyperecord is not the expected two-level lookup");
    }
    (numeric, fallback) = switch_cases(text, "double _PyUnicode_ToNumeric(Py_UCS4 ch)");
    if fallback != "-1.0" {
        raise Unsupported(f"_PyUnicode_ToNumeric returns {fallback} by default");
    }
    numeric_values = sorted((code, numeric_value(expr)) for (code, expr) in numeric);
    distinct = sorted(set(value for (_, value) in numeric_values));
    if len(distinct) > 256 {
        raise Unsupported("more numeric values than a u8 index reaches");
    }
    whitespace = code_set(text, "int _PyUnicode_IsWhitespace(const Py_UCS4 ch)");
    linebreak = code_set(text, "int _PyUnicode_IsLinebreak(const Py_UCS4 ch)");
    emitter.constant("SHIFT", "i64", shift);
    emitter.constant("NUMERIC_LENGTH", "i64", len(numeric_values));
    emitter.constant("WHITESPACE_LENGTH", "i64", len(whitespace));
    emitter.constant("LINEBREAK_LENGTH", "i64", len(linebreak));
    record_fields = typedef_fields(module, "_PyUnicode_TypeRecord");
    emitter.struct("TypeRecord", record_fields);
    (_, body) = array(text, "_PyUnicode_TypeRecords");
    emitter.structs_of(
        "_PyUnicode_TypeRecords",
        "TypeRecord",
        [struct_value("TypeRecord", record_fields, items) for items in records(body)]
    );
    (jt, values) = int_array(text, "_PyUnicode_ExtendedCase");
    emitter.ints("_PyUnicode_ExtendedCase", jt, values);
    for name in ("index1", "index2") {
        (jt, values) = int_array(text, name);
        emitter.ints(f"uct_{name}", jt, values);
    }
    emitter.ints("uct_numeric_codes", "u32", [code for (code, _) in numeric_values]);
    emitter.ints(
        "uct_numeric_value_index",
        "u8",
        [distinct.index(value) for (_, value) in numeric_values]
    );
    emitter.data.append(
        "uct_numeric_values: list[f64] = ["
            + ", ".join(repr(value) for value in distinct)
            + "]"
    );
    emitter.ints("uct_whitespace", "u32", whitespace);
    emitter.ints("uct_linebreak", "u32", linebreak);
    return emitter.render(
        [
            "The character type database of the native str type.",
            "",
            f"Generated by {COMMAND} from CPython {version}",
            "Objects/unicodetype_db.h (Tools/unicode/makeunicodedata.py); do not edit.",
            "Integer tables are bytes literals of their little-endian elements. The",
            "switches of _PyUnicode_ToNumeric, _PyUnicode_IsWhitespace and",
            "_PyUnicode_IsLinebreak are sorted code-point tables here, and",
            "_PyUnicode_ToNumeric's values an index into its distinct values.",
            "See ../LICENSE.cpython."
        ]
    );
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate the native str type's character type tables"
    );
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    texts = archive_texts(("Objects/unicodectype.c", "Objects/unicodetype_db.h"));
    try {
        rendered = type_database(
            texts["Objects/unicodetype_db.h"],
            texts["Objects/unicodectype.c"],
            pin()["version"]
        );
    } except Unsupported as reason {
        sys.exit(f"{COMMAND}: {reason}");
    }
    text = format_jac(rendered, TYPE_DATABASE);
    if not write_or_check(TYPE_DATABASE, text, args.check, COMMAND) {
        sys.exit(1);
    }
}
