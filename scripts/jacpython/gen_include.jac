"""Generate the public C API headers from the Jac layouts and constants.

The headers a C extension compiles against through Python.h, Include/*.h and
Include/cpython/*.h, are checked in as
jac/bootstrap/python/generated/Include/<path>.in. cpython-sources.txt marks
each one `generated`, so both builds stage these copies where the archive's
were, and `make install` puts them where `python3-config --includes` points:

    jac run scripts/jacpython/gen_include.jac            # rewrite them
    jac run scripts/jacpython/gen_include.jac --check    # fail on drift

The Jac definitions own what the runtime defines and reads in place:

- Records. A struct a header defines for a record of
  jaclang/runtime/python/layouts.jac (or a C-layout record of cpython_api.jac
  that gen_layouts.jac maps) has that record's members, in its order and of
  its types, as gen_layouts.jac maps C types to Jac ones. A struct that
  disagrees is rewritten from the record: a member the record still has keeps
  its declaration (its typedef, const and comment), any other member is
  declared from its Jac type. A struct with preprocessor branches, a union, a
  nested struct or bit-fields, or defined more than once, is not rewritten:
  the script names it and stops.
- Constants. A header's `#define NAME <integer>` for a constant layouts.jac
  declares carries the Jac value, written in the literal's own notation
  (decimal, hexadecimal or `1 << n`) and suffix. A constant whose definition
  is an expression of other macros, or differs between configurations, keeps
  its text; bootstrap/python/layouts_check.c asserts its value.

Everything else in a header (function and data declarations, macros, static
inline functions, comments) is the checked-in text, which is CPython's for a
header no Jac definition has changed. Include/opcode_ids.h is
gen_opcode_meta.jac's. build.sh compiles layouts_check.c against the staged
headers in every JacPython build, so a header that disagrees with the Jac
layouts fails the build.
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
    closing,
    header_layouts,
    head_macros,
    jac_type,
    members,
    strip_comments
}

glob COMMAND: str = "scripts/jacpython/gen_include.jac",
     LAYOUTS_JAC: Path = RUNTIME / "layouts.jac",
     CAPI_JAC: Path = RUNTIME / "cpython_api.jac",
     # Generated headers another script writes.
     OWNED_ELSEWHERE: set[str] = {"Include/opcode_ids.h"},
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
     };

"""One header struct to bring in line with its Jac record."""
obj Rewrite {
    has name: str,
        ctype: str,
        fields: list[tuple[str, str]];
}

# ------------------------------------------------------------- Jac definitions
# A Jac type with the formatter's line breaks taken out.
def normal_type(text: str) -> str {
    text = " ".join(text.split());
    text = re.sub(r"\[\s+", "[", text);
    text = re.sub(r",?\s*\]", "]", text);
    return re.sub(r"\s*,\s*", ", ", text);
}

# The pieces of `text` split at the commas outside brackets and parentheses.
def split_top(text: str) -> list[str] {
    pieces: list[str] = [];
    depth = 0;
    current = "";
    for ch in text {
        if ch in "[(" {
            depth += 1;
        } elif ch in "])" {
            depth -= 1;
        }
        if ch == "," and depth == 0 {
            pieces.append(current);
            current = "";
        } else {
            current += ch;
        }
    }
    if current.strip() {
        pieces.append(current);
    }
    return pieces;
}

# Every C-layout record of a Jac module: name -> [(field, Jac type)].
def jac_records(path: Path) -> dict[str, list[tuple[str, str]]] {
    found: dict[str, list[tuple[str, str]]] = {};
    for hit in re.finditer(
        r"\bobj (\w+)\s*\{\s*has\s+(.*?);\s*\}", path.read_text(), re.S
    ) {
        fields: list[tuple[str, str]] = [];
        for piece in split_top(hit.group(2)) {
            (name, declared) = piece.split(":", 1);
            fields.append(
                (
                    name.strip(),
                    normal_type(re.sub(r"\s*=.*$", "", declared, flags=re.S))
                )
            );
        }
        found[hit.group(1)] = fields;
    }
    return found;
}

# layouts.jac's constants: name -> (Jac type, value).
def jac_constants(path: Path) -> dict[str, tuple[str, int]] {
    return {
        hit.group(1): (hit.group(2), int(hit.group(3)))
        for hit in re.finditer(r"\b(\w+): Final\[(\w+)\] = (-?\d+)\b", path.read_text())
    };
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

# ------------------------------------------------------------------ the headers
# The headers this script owns.
def owned_paths -> list[str] {
    return [
        path
        for path in generated_paths()
        if re.fullmatch(r"Include/(cpython/)?[^/]+\.h", path)
            and path not in OWNED_ELSEWHERE
    ];
}

def read_copy(path: str) -> str {
    with open(generated_copy(path), encoding="utf-8", newline="") as handle {
        return handle.read();
    }
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate the public C API headers from the Jac definitions"
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
    (emitted, declared) = header_layouts();
    heads = head_macros(declared.macros);
    for (alias, resolved) in declared.aliases.items() {
        if resolved.startswith("struct ") and resolved not in TYPEDEFS {
            TYPEDEFS[resolved] = alias;
        }
    }
    records = jac_records(layouts_jac);
    # cpython_api.jac's C-layout records may rename a member C names after a
    # Jac keyword (Py_buffer's `obj` is `owner`), so only their types say
    # what the header declares.
    renamed = {
        name: fields
        for (name, fields) in jac_records(CAPI_JAC).items()
        if name not in records
    };
    # Records: compare each header struct, as gen_layouts.jac reads it, with
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
            if definitions(texts[p], ctype)
        ];
        if not homes {
            continue;
        }
        checked += 1;
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
            rewrites.append(Rewrite(name=name, ctype=ctype, fields=records[name]));
        }
    }
    updated = dict(texts);
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
            + f"{constants_checked} constants checked, {respelt} rewritten"
    );
    if not current {
        sys.exit(1);
    }
}
