"""
Minimal TOML reader for bunfig.toml (engine/src/pm).

Covers what bun's install configuration uses: `[table]` / `[a.b]` headers,
bare, quoted and dotted keys, basic and literal strings (including the
multi-line forms), booleans, integers (decimal / 0x / 0o / 0b), floats (kept
as their source text), arrays of scalars (multi-line, trailing comma) and
inline tables (flattened to dotted keys). Reported as an error rather than
guessed at: arrays of tables `[[x]]`, nested arrays, dates and times.

Everything is flattened into a dict of dotted keys, so

    [install.cache]
    dir = "x"

and `install.cache.dir = "x"` read the same. Byte-oriented like the rest of
the engine: multi-byte UTF-8 in strings is copied through untouched.
"""

import from engine.src.runtime.jsstring { utf8_encode_scalar }

obj:pub TomlValue {
    has kind: str = "",
        s: str = "",
        b: bool = False,
        i: int = 0,
        items: list[str] = [],
        item_kinds: list[str] = [];  # "string" | "bool" | "int" | "float" | "array"
}

# string value; for "float" the source text

# array elements, stringified (strings unquoted)
obj:pub TomlDoc {
    has values: dict[str, TomlValue] = {},
        order: list[str] = [],
        error: str = "";  # dotted key -> value
}

# keys in document order
# "" when parsed cleanly, else "line N: message"
obj TomlParser {
    has src: str,
        doc: TomlDoc,
        pos: int = 0,
        n: int = 0,
        line: int = 1,
        table: str = "";
}

# current [table] prefix, "" at the document root
# ── Cursor helpers ────────────────────────────────────────────────────────────

def _tp_at(p: TomlParser, off: int) -> str {
    if p.pos + off >= p.n {
        return "";
    }
    return p.src[p.pos + off];
}

def _tp_adv(p: TomlParser) {
    if p.pos < p.n {
        if p.src[p.pos] == "\n" {
            p.line = p.line + 1;
        }
        p.pos = p.pos + 1;
    }
}

def _tp_fail(p: TomlParser, msg: str) {
    if p.doc.error == "" {
        p.doc.error = "line " + str(p.line) + ": " + msg;
    }
    p.pos = p.n;  # stop parsing
}

def _tp_skip_blanks(p: TomlParser) {
    while True {
        c: str = _tp_at(p, 0);
        if c == " " or c == "\t" {
            _tp_adv(p);
        } else {
            break;
        }
    }
}

"""At '#': skip to the end of the line (the newline itself is left in place)."""
def _tp_skip_comment(p: TomlParser) {
    if _tp_at(p, 0) == "#" {
        while p.pos < p.n and p.src[p.pos] != "\n" {
            p.pos = p.pos + 1;
        }
    }
}

"""Skip blanks, newlines and comments (between top-level items / array elements)."""
def _tp_skip_ws_all(p: TomlParser) {
    while p.pos < p.n {
        c: str = p.src[p.pos];
        if c == " " or c == "\t" or c == "\r" {
            p.pos = p.pos + 1;
        } elif c == "\n" {
            _tp_adv(p);
        } elif c == "#" {
            _tp_skip_comment(p);
        } else {
            break;
        }
    }
}

def _tp_is_bare(c: str) -> bool {
    if c == "" {
        return False;
    }
    o: int = ord(c);
    if o >= 48 and o <= 57 {
        return True;
    }
    if o >= 65 and o <= 90 {
        return True;
    }
    if o >= 97 and o <= 122 {
        return True;
    }
    return c == "_" or c == "-";
}

def _tp_hex_val(c: str) -> int {
    if c == "" {
        return -1;
    }
    o: int = ord(c);
    if o >= 48 and o <= 57 {
        return o - 48;
    }
    if o >= 97 and o <= 102 {
        return o - 87;
    }
    if o >= 65 and o <= 70 {
        return o - 55;
    }
    return -1;
}

# ── Strings ───────────────────────────────────────────────────────────────────

"""Basic string body; the cursor is just past the opening quote(s)."""
def _tp_basic_string(p: TomlParser, multi: bool) -> str {
    out: list[str] = [];
    if multi {
        # A newline right after the opening """ is trimmed.
        if _tp_at(p, 0) == "\r" {
            _tp_adv(p);
        }
        if _tp_at(p, 0) == "\n" {
            _tp_adv(p);
        }
    }
    while True {
        c: str = _tp_at(p, 0);
        if c == "" {
            _tp_fail(p, "unterminated string");
            return "".join(out);
        }
        if c == "\"" {
            if not multi {
                _tp_adv(p);
                return "".join(out);
            }
            if _tp_at(p, 1) == "\"" and _tp_at(p, 2) == "\"" {
                _tp_adv(p);
                _tp_adv(p);
                _tp_adv(p);
                return "".join(out);
            }
            out.append(c);
            _tp_adv(p);
            continue;
        }
        if c == "\n" and not multi {
            _tp_fail(p, "newline in single-line string");
            return "";
        }
        if c == "\\" {
            e: str = _tp_at(p, 1);
            if multi and (e == "\n" or e == "\r" or e == " " or e == "\t") {
                # Line-ending backslash: drop it and all whitespace up to the next content.
                _tp_adv(p);
                while True {
                    w: str = _tp_at(p, 0);
                    if w == " " or w == "\t" or w == "\r" or w == "\n" {
                        _tp_adv(p);
                    } else {
                        break;
                    }
                }
                continue;
            }
            _tp_adv(p);
            _tp_adv(p);
            if e == "n" {
                out.append("\n");
            } elif e == "t" {
                out.append("\t");
            } elif e == "r" {
                out.append(chr(13));
            } elif e == "b" {
                out.append(chr(8));
            } elif e == "f" {
                out.append(chr(12));
            } elif e == "\"" {
                out.append("\"");
            } elif e == "\\" {
                out.append("\\");
            } elif e == "u" or e == "U" {
                digits: int = 4;
                if e == "U" {
                    digits = 8;
                }
                cp: int = 0;
                k: int = 0;
                while k < digits {
                    hv: int = _tp_hex_val(_tp_at(p, 0));
                    if hv < 0 {
                        _tp_fail(p, "invalid unicode escape");
                        return "";
                    }
                    cp = cp * 16 + hv;
                    _tp_adv(p);
                    k = k + 1;
                }
                out.append(utf8_encode_scalar(cp));
            } else {
                _tp_fail(p, "invalid escape '\\" + e + "'");
                return "";
            }
            continue;
        }
        out.append(c);
        _tp_adv(p);
    }
    return "".join(out);
}

"""Literal string body ('...' or '''...'''); no escapes."""
def _tp_literal_string(p: TomlParser, multi: bool) -> str {
    out: list[str] = [];
    if multi {
        if _tp_at(p, 0) == "\r" {
            _tp_adv(p);
        }
        if _tp_at(p, 0) == "\n" {
            _tp_adv(p);
        }
    }
    while True {
        c: str = _tp_at(p, 0);
        if c == "" {
            _tp_fail(p, "unterminated literal string");
            return "".join(out);
        }
        if c == "'" {
            if not multi {
                _tp_adv(p);
                return "".join(out);
            }
            if _tp_at(p, 1) == "'" and _tp_at(p, 2) == "'" {
                _tp_adv(p);
                _tp_adv(p);
                _tp_adv(p);
                return "".join(out);
            }
        }
        if c == "\n" and not multi {
            _tp_fail(p, "newline in single-line string");
            return "";
        }
        out.append(c);
        _tp_adv(p);
    }
    return "".join(out);
}

# ── Keys ──────────────────────────────────────────────────────────────────────

"""A (possibly dotted) key: bare or quoted segments joined with '.'."""
def _tp_key(p: TomlParser) -> str {
    segs: list[str] = [];
    while True {
        _tp_skip_blanks(p);
        c: str = _tp_at(p, 0);
        seg: str = "";
        if c == "\"" {
            _tp_adv(p);
            seg = _tp_basic_string(p, False);
        } elif c == "'" {
            _tp_adv(p);
            seg = _tp_literal_string(p, False);
        } elif _tp_is_bare(c) {
            while _tp_is_bare(_tp_at(p, 0)) {
                seg = seg + _tp_at(p, 0);
                _tp_adv(p);
            }
        } else {
            _tp_fail(p, "expected a key");
            return "";
        }
        segs.append(seg);
        _tp_skip_blanks(p);
        if _tp_at(p, 0) == "." {
            _tp_adv(p);
            continue;
        }
        break;
    }
    return ".".join(segs);
}

# ── Values ────────────────────────────────────────────────────────────────────

def _tp_is_num_char(c: str) -> bool {
    if c == "" {
        return False;
    }
    if _tp_hex_val(c) >= 0 {
        return True;
    }
    return c == "x"
        or c == "X"
        or c == "o"
        or c == "O"
        or c == "+"
        or c == "-"
        or c == "_"
        or c == ".";
}

"""Strings, booleans and numbers (the element types allowed inside arrays)."""
def _tp_scalar(p: TomlParser) -> TomlValue {
    v: TomlValue = TomlValue();
    c: str = _tp_at(p, 0);
    if c == "\"" {
        v.kind = "string";
        if _tp_at(p, 1) == "\"" and _tp_at(p, 2) == "\"" {
            _tp_adv(p);
            _tp_adv(p);
            _tp_adv(p);
            v.s = _tp_basic_string(p, True);
        } else {
            _tp_adv(p);
            v.s = _tp_basic_string(p, False);
        }
        return v;
    }
    if c == "'" {
        v.kind = "string";
        if _tp_at(p, 1) == "'" and _tp_at(p, 2) == "'" {
            _tp_adv(p);
            _tp_adv(p);
            _tp_adv(p);
            v.s = _tp_literal_string(p, True);
        } else {
            _tp_adv(p);
            v.s = _tp_literal_string(p, False);
        }
        return v;
    }
    # bare word: true / false / inf / nan / number
    word: str = "";
    while True {
        w: str = _tp_at(p, 0);
        if _tp_is_num_char(w) or (w != "" and ord(w) >= 97 and ord(w) <= 122) {
            word = word + w;
            _tp_adv(p);
        } else {
            break;
        }
    }
    if word == "true" {
        v.kind = "bool";
        v.b = True;
        return v;
    }
    if word == "false" {
        v.kind = "bool";
        v.b = False;
        return v;
    }
    if word == "" {
        _tp_fail(p, "expected a value");
        return v;
    }
    low: str = word.lower();
    if low == "inf"
        or low == "+inf"
        or low == "-inf"
        or low == "nan"
        or low == "+nan"
        or low == "-nan" {
        v.kind = "float";
        v.s = word;
        return v;
    }
    digits: str = word.replace("_", "");
    sign: int = 1;
    if digits.startswith("-") {
        sign = -1;
        digits = digits[1:];
    } elif digits.startswith("+") {
        digits = digits[1:];
    }
    base: int = 10;
    if digits.startswith("0x") or digits.startswith("0X") {
        base = 16;
        digits = digits[2:];
    } elif digits.startswith("0o") or digits.startswith("0O") {
        base = 8;
        digits = digits[2:];
    } elif digits.startswith("0b") or digits.startswith("0B") {
        base = 2;
        digits = digits[2:];
    }
    if base == 10
        and (digits.find(".") >= 0 or digits.find("e") >= 0 or digits.find("E") >= 0) {
        v.kind = "float";
        v.s = word;
        return v;
    }
    if digits == "" {
        _tp_fail(p, "invalid number '" + word + "'");
        return v;
    }
    acc: int = 0;
    k: int = 0;
    while k < len(digits) {
        dv: int = _tp_hex_val(digits[k]);
        if dv < 0 or dv >= base {
            _tp_fail(p, "invalid number '" + word + "'");
            return v;
        }
        acc = acc * base + dv;
        k = k + 1;
    }
    v.kind = "int";
    v.i = acc * sign;
    return v;
}

def _tp_set(p: TomlParser, key: str, v: TomlValue) {
    if not (key in p.doc.values) {
        p.doc.order.append(key);
    }
    p.doc.values[key] = v;
}

"""Parse the value for `key` (dotted, table prefix included) and store it.
Arrays become one "array" value; inline tables are flattened to `key.sub`."""
def _tp_value(p: TomlParser, key: str) -> None {
    _tp_skip_blanks(p);
    c: str = _tp_at(p, 0);
    if c == "[" {
        _tp_adv(p);
        arr: TomlValue = TomlValue();
        arr.kind = "array";
        while True {
            _tp_skip_ws_all(p);
            a: str = _tp_at(p, 0);
            if a == "" {
                _tp_fail(p, "unterminated array");
                return;
            }
            if a == "]" {
                _tp_adv(p);
                break;
            }
            if a == "[" {
                _tp_fail(p, "nested arrays are not supported");
                return;
            }
            if a == "{" {
                _tp_fail(p, "tables inside arrays are not supported");
                return;
            }
            el: TomlValue = _tp_scalar(p);
            if p.doc.error != "" {
                return;
            }
            if el.kind == "string" or el.kind == "float" {
                arr.items.append(el.s);
            } elif el.kind == "int" {
                arr.items.append(str(el.i));
            } elif el.b {
                arr.items.append("true");
            } else {
                arr.items.append("false");
            }
            arr.item_kinds.append(el.kind);
            _tp_skip_ws_all(p);
            b: str = _tp_at(p, 0);
            if b == "," {
                _tp_adv(p);
                continue;
            }
            if b == "]" {
                _tp_adv(p);
                break;
            }
            _tp_fail(p, "expected ',' or ']' in array");
            return;
        }
        _tp_set(p, key, arr);
        return;
    }
    if c == "{" {
        _tp_adv(p);
        while True {
            _tp_skip_blanks(p);
            t: str = _tp_at(p, 0);
            if t == "}" {
                _tp_adv(p);
                break;
            }
            if t == "" or t == "\n" {
                _tp_fail(p, "unterminated inline table");
                return;
            }
            sub: str = _tp_key(p);
            if p.doc.error != "" {
                return;
            }
            _tp_skip_blanks(p);
            if _tp_at(p, 0) != "=" {
                _tp_fail(p, "expected '=' in inline table");
                return;
            }
            _tp_adv(p);
            _tp_value(p, key + "." + sub);
            if p.doc.error != "" {
                return;
            }
            _tp_skip_blanks(p);
            u: str = _tp_at(p, 0);
            if u == "," {
                _tp_adv(p);
                continue;
            }
            if u == "}" {
                _tp_adv(p);
                break;
            }
            _tp_fail(p, "expected ',' or '}' in inline table");
            return;
        }
        return;
    }
    v: TomlValue = _tp_scalar(p);
    if p.doc.error != "" {
        return;
    }
    _tp_set(p, key, v);
}

# ── Document ──────────────────────────────────────────────────────────────────

def:pub toml_parse(text: str) -> TomlDoc {
    p: TomlParser = TomlParser(
        src=text, pos=0, n=len(text), line=1, table="", doc=TomlDoc()
    );
    while True {
        _tp_skip_ws_all(p);
        if p.pos >= p.n {
            break;
        }
        c: str = p.src[p.pos];
        if c == "[" {
            if _tp_at(p, 1) == "[" {
                _tp_fail(p, "arrays of tables ([[x]]) are not supported");
                break;
            }
            _tp_adv(p);
            name: str = _tp_key(p);
            if p.doc.error != "" {
                break;
            }
            _tp_skip_blanks(p);
            if _tp_at(p, 0) != "]" {
                _tp_fail(p, "expected ']' after table name");
                break;
            }
            _tp_adv(p);
            p.table = name;
        } else {
            key: str = _tp_key(p);
            if p.doc.error != "" {
                break;
            }
            _tp_skip_blanks(p);
            if _tp_at(p, 0) != "=" {
                _tp_fail(p, "expected '=' after key '" + key + "'");
                break;
            }
            _tp_adv(p);
            full: str = key;
            if p.table != "" {
                full = p.table + "." + key;
            }
            _tp_value(p, full);
            if p.doc.error != "" {
                break;
            }
        }
        # Rest of the line: blanks, an optional comment, then newline or EOF.
        _tp_skip_blanks(p);
        _tp_skip_comment(p);
        c2: str = _tp_at(p, 0);
        if c2 == "\r" {
            _tp_adv(p);
            c2 = _tp_at(p, 0);
        }
        if c2 != "" and c2 != "\n" {
            _tp_fail(p, "unexpected text after value");
            break;
        }
    }
    return p.doc;
}

# ── Accessors ─────────────────────────────────────────────────────────────────

def:pub toml_has(doc: TomlDoc, key: str) -> bool {
    return key in doc.values;
}

"""String form of a scalar value ("" when missing or an array)."""
def:pub toml_get_str(doc: TomlDoc, key: str) -> str {
    if not (key in doc.values) {
        return "";
    }
    v: TomlValue = doc.values[key];
    if v.kind == "string" or v.kind == "float" {
        return v.s;
    }
    if v.kind == "int" {
        return str(v.i);
    }
    if v.kind == "bool" {
        if v.b {
            return "true";
        }
        return "false";
    }
    return "";
}

def:pub toml_get_bool(doc: TomlDoc, key: str, dflt: bool) -> bool {
    if not (key in doc.values) {
        return dflt;
    }
    v: TomlValue = doc.values[key];
    if v.kind == "bool" {
        return v.b;
    }
    if v.kind == "string" {
        return v.s == "true";
    }
    if v.kind == "int" {
        return v.i != 0;
    }
    return dflt;
}

def:pub toml_get_int(doc: TomlDoc, key: str, dflt: int) -> int {
    if not (key in doc.values) {
        return dflt;
    }
    v: TomlValue = doc.values[key];
    if v.kind == "int" {
        return v.i;
    }
    return dflt;
}

"""Array items; a scalar string reads as a one-element list."""
def:pub toml_get_list(doc: TomlDoc, key: str) -> list[str] {
    out: list[str] = [];
    if not (key in doc.values) {
        return out;
    }
    v: TomlValue = doc.values[key];
    if v.kind == "array" {
        for it in v.items {
            out.append(it);
        }
    } elif v.kind == "string" {
        out.append(v.s);
    }
    return out;
}

"""Keys that live under `prefix.` (returned in document order, full dotted form)."""
def:pub toml_keys_under(doc: TomlDoc, prefix: str) -> list[str] {
    out: list[str] = [];
    pre: str = prefix + ".";
    for k in doc.order {
        if k.startswith(pre) {
            out.append(k);
        }
    }
    return out;
}
