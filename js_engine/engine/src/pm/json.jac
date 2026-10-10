"""JSON / JSONC parser producing a native tree, for the package manager.

Parses from raw bytes (ptr, len) so packuments, package.json and bun.lock are
consumed straight from file/HTTP buffers without per-character string churn.
Like bun's JSON reader it accepts `//` and `/* */` comments and trailing
commas (bun.lock relies on the latter). Object key order is preserved.

Independent of the JS engine's JSON.parse: no JSValue, heap or GC involvement,
so it can run before the runtime is initialised (the PM dispatches first).
"""

import from engine.src.runtime.mem { read_byte }
import from engine.src.pm.bytes { bytes_to_str, str_to_cbuf }
import from engine.src.runtime.mem { io_free }

glob:pub JV_MISSING: int = -1,
     JV_NULL: int = 0,
     JV_BOOL: int = 1,
     JV_NUM: int = 2,
     JV_STR: int = 3,
     JV_ARR: int = 4,
     JV_OBJ: int = 5;

"""A JSON value. `kind` selects which field is meaningful."""
obj:pub JVal {
    has kind: int = -1,
        b: bool = False,
        num: float = 0.0,
        is_int: bool = False,
        i: int = 0,
        s: str = "",
        items: list[JVal] = [],
        keys: list[str] = [],
        vals: dict[str, JVal] = {},
        single_line: bool = False;
}

# JV_ARR
# JV_OBJ, in source order
# JV_OBJ
# JV_ARR/JV_OBJ: written on one line in the source
obj:pub JsonDoc {
    has ok: bool = False,
        error: str = "",
        line: int = 0,
        value: JVal = JVal();
}

obj JsonParser {
    has ptr: int,
        n: int,
        pos: int = 0,
        line: int = 1,
        error: str = "";
}

# ── constructors ──────────────────────────────────────────────────────────────

def:pub jv_missing -> JVal {
    return JVal();
}
def:pub jv_null -> JVal {
    return JVal(kind=JV_NULL);
}
def:pub jv_bool(b: bool) -> JVal {
    return JVal(kind=JV_BOOL, b=b);
}
def:pub jv_int(i: int) -> JVal {
    return JVal(kind=JV_NUM, num=float(i), is_int=True, i=i);
}
def:pub jv_float(f: float) -> JVal {
    return JVal(kind=JV_NUM, num=f);
}
def:pub jv_string(s: str) -> JVal {
    return JVal(kind=JV_STR, s=s);
}
def:pub jv_array -> JVal {
    return JVal(kind=JV_ARR);
}
def:pub jv_object -> JVal {
    return JVal(kind=JV_OBJ);
}

def:pub jv_set(o: JVal, key: str, v: JVal) {
    if not (key in o.vals) {
        o.keys.append(key);
    }
    o.vals[key] = v;
}

def:pub jv_push(a: JVal, v: JVal) {
    a.items.append(v);
}

# ── accessors ─────────────────────────────────────────────────────────────────

def:pub jv_is_missing(v: JVal) -> bool {
    return v.kind == JV_MISSING;
}
def:pub jv_is_null(v: JVal) -> bool {
    return v.kind == JV_NULL;
}
def:pub jv_is_obj(v: JVal) -> bool {
    return v.kind == JV_OBJ;
}
def:pub jv_is_arr(v: JVal) -> bool {
    return v.kind == JV_ARR;
}
def:pub jv_is_str(v: JVal) -> bool {
    return v.kind == JV_STR;
}
def:pub jv_is_num(v: JVal) -> bool {
    return v.kind == JV_NUM;
}
def:pub jv_is_bool(v: JVal) -> bool {
    return v.kind == JV_BOOL;
}

"""Member lookup; a JV_MISSING value when absent or `v` is not an object."""
def:pub jv_get(v: JVal, key: str) -> JVal {
    if v.kind != JV_OBJ {
        return JVal();
    }
    if key in v.vals {
        return v.vals[key];
    }
    return JVal();
}

def:pub jv_has(v: JVal, key: str) -> bool {
    return v.kind == JV_OBJ and (key in v.vals);
}

"""String member or `dflt` when absent / not a string."""
def:pub jv_get_str(v: JVal, key: str, dflt: str) -> str {
    m: JVal = jv_get(v, key);
    if m.kind == JV_STR {
        return m.s;
    }
    return dflt;
}

def:pub jv_get_bool(v: JVal, key: str, dflt: bool) -> bool {
    m: JVal = jv_get(v, key);
    if m.kind == JV_BOOL {
        return m.b;
    }
    return dflt;
}

def:pub jv_get_int(v: JVal, key: str, dflt: int) -> int {
    m: JVal = jv_get(v, key);
    if m.kind == JV_NUM {
        return int(m.num);
    }
    return dflt;
}

def:pub jv_str(v: JVal) -> str {
    if v.kind == JV_STR {
        return v.s;
    }
    return "";
}

def:pub jv_len(v: JVal) -> int {
    if v.kind == JV_ARR {
        return len(v.items);
    }
    if v.kind == JV_OBJ {
        return len(v.keys);
    }
    return 0;
}

def:pub jv_at(v: JVal, idx: int) -> JVal {
    if v.kind != JV_ARR or idx < 0 or idx >= len(v.items) {
        return JVal();
    }
    return v.items[idx];
}

"""Strings of an array (non-strings skipped); a lone string → [that string]."""
def:pub jv_str_list(v: JVal) -> list[str] {
    out: list[str] = [];
    if v.kind == JV_STR {
        out.append(v.s);
        return out;
    }
    if v.kind == JV_ARR {
        for it in v.items {
            if it.kind == JV_STR {
                out.append(it.s);
            }
        }
    }
    return out;
}

# ── parsing ───────────────────────────────────────────────────────────────────

def:pub json_parse_bytes(ptr: int, n: int) -> JsonDoc {
    doc: JsonDoc = JsonDoc();
    p: JsonParser = JsonParser(ptr=ptr, n=n);
    _skip_ws(p);
    v: JVal = _parse_value(p, 0);
    if p.error == "" {
        _skip_ws(p);
        if p.pos < p.n {
            p.error = "unexpected trailing characters";
        }
    }
    if p.error != "" {
        doc.ok = False;
        doc.error = p.error;
        doc.line = p.line;
        return doc;
    }
    doc.ok = True;
    doc.value = v;
    return doc;
}

def:pub json_parse_str(text: str) -> JsonDoc {
    n: int = len(text);
    p: int = str_to_cbuf(text);
    doc: JsonDoc = json_parse_bytes(p, n);
    io_free(p);
    return doc;
}

def _peek(p: JsonParser) -> int {
    if p.pos >= p.n {
        return -1;
    }
    return read_byte(p.ptr, p.pos);
}

def _skip_ws(p: JsonParser) -> None {
    while p.pos < p.n {
        c: int = read_byte(p.ptr, p.pos);
        if c == 32 or c == 9 or c == 13 {
            p.pos = p.pos + 1;
        } elif c == 10 {
            p.pos = p.pos + 1;
            p.line = p.line + 1;
        } elif c == 47 and p.pos + 1 < p.n {  # '/'
            c2: int = read_byte(p.ptr, p.pos + 1);
            if c2 == 47 {  # // line comment
                p.pos = p.pos + 2;
                while p.pos < p.n and read_byte(p.ptr, p.pos) != 10 {
                    p.pos = p.pos + 1;
                }
            } elif c2 == 42 {  # /* block comment */
                p.pos = p.pos + 2;
                closed: bool = False;
                while p.pos + 1 < p.n {
                    if read_byte(p.ptr, p.pos) == 42
                        and read_byte(p.ptr, p.pos + 1) == 47 {
                        p.pos = p.pos + 2;
                        closed = True;
                        break;
                    }
                    if read_byte(p.ptr, p.pos) == 10 {
                        p.line = p.line + 1;
                    }
                    p.pos = p.pos + 1;
                }
                if not closed {
                    p.pos = p.n;
                }
            } else {
                return;
            }
        } else {
            return;
        }
    }
}

def _parse_value(p: JsonParser, depth: int) -> JVal {
    if depth > 512 {
        p.error = "nesting too deep";
        return JVal();
    }
    c: int = _peek(p);
    if c < 0 {
        p.error = "unexpected end of input";
        return JVal();
    }
    if c == 123 {
        return _parse_object(p, depth);
    }  # {
    if c == 91 {
        return _parse_array(p, depth);
    }  # [
    if c == 34 {
        return jv_string(_parse_string(p));
    }  # "
    if c == 116 {
        return _parse_literal(p, "true", jv_bool(True));
    }
    if c == 102 {
        return _parse_literal(p, "false", jv_bool(False));
    }
    if c == 110 {
        return _parse_literal(p, "null", jv_null());
    }
    if c == 45 or (c >= 48 and c <= 57) {
        return _parse_number(p);
    }
    p.error = "unexpected character '" + chr(c) + "'";
    return JVal();
}

def _parse_literal(p: JsonParser, word: str, v: JVal) -> JVal {
    m: int = len(word);
    i: int = 0;
    while i < m {
        if p.pos + i >= p.n or read_byte(p.ptr, p.pos + i) != ord(word[i]) {
            p.error = "invalid literal";
            return JVal();
        }
        i = i + 1;
    }
    p.pos = p.pos + m;
    return v;
}

def _parse_number(p: JsonParser) -> JVal {
    start: int = p.pos;
    is_int: bool = True;
    if _peek(p) == 45 {
        p.pos = p.pos + 1;
    }
    while p.pos < p.n {
        c: int = read_byte(p.ptr, p.pos);
        if c >= 48 and c <= 57 {
            p.pos = p.pos + 1;
        } elif c == 46 or c == 101 or c == 69 or c == 43 or c == 45 {
            is_int = False;
            p.pos = p.pos + 1;
        } else {
            break;
        }
    }
    text: str = bytes_to_str(p.ptr, start, p.pos - start);
    if text == "" or text == "-" {
        p.error = "invalid number";
        return JVal();
    }
    v: JVal = JVal(kind=JV_NUM);
    if is_int and len(text) < 18 {
        try {
            v.i = int(text);
            v.is_int = True;
            v.num = float(v.i);
        } except Exception {
            p.error = "invalid number: " + text;
            return JVal();
        }
        return v;
    }
    try {
        v.num = float(text);
    } except Exception {
        p.error = "invalid number: " + text;
        return JVal();
    }
    if v.num == float(int(v.num)) and abs(v.num) < 9007199254740992.0 {
        v.is_int = True;
        v.i = int(v.num);
    }
    return v;
}

def _hex4(p: JsonParser) -> int {
    if p.pos + 4 > p.n {
        return -1;
    }
    v: int = 0;
    i: int = 0;
    while i < 4 {
        c: int = read_byte(p.ptr, p.pos + i);
        d: int = -1;
        if c >= 48 and c <= 57 {
            d = c - 48;
        } elif c >= 97 and c <= 102 {
            d = c - 87;
        } elif c >= 65 and c <= 70 {
            d = c - 55;
        }
        if d < 0 {
            return -1;
        }
        v = v * 16 + d;
        i = i + 1;
    }
    p.pos = p.pos + 4;
    return v;
}

"""Parse a string at p.pos (which must be the opening quote)."""
def _parse_string(p: JsonParser) -> str {
    p.pos = p.pos + 1;  # opening quote
    start: int = p.pos;
    # fast path: no escapes
    while p.pos < p.n {
        c: int = read_byte(p.ptr, p.pos);
        if c == 34 {
            s: str = bytes_to_str(p.ptr, start, p.pos - start);
            p.pos = p.pos + 1;
            return s;
        }
        if c == 92 {
            break;
        }
        if c == 10 {
            p.line = p.line + 1;
        }
        p.pos = p.pos + 1;
    }
    # slow path: assemble pieces
    parts: list[str] = [];
    if p.pos > start {
        parts.append(bytes_to_str(p.ptr, start, p.pos - start));
    }
    while p.pos < p.n {
        c: int = read_byte(p.ptr, p.pos);
        if c == 34 {
            p.pos = p.pos + 1;
            return "".join(parts);
        }
        if c == 92 {
            p.pos = p.pos + 1;
            if p.pos >= p.n {
                break;
            }
            e: int = read_byte(p.ptr, p.pos);
            p.pos = p.pos + 1;
            if e == 34 {
                parts.append("\"");
            } elif e == 92 {
                parts.append("\\");
            } elif e == 47 {
                parts.append("/");
            } elif e == 98 {
                parts.append(chr(8));
            } elif e == 102 {
                parts.append(chr(12));
            } elif e == 110 {
                parts.append("\n");
            } elif e == 114 {
                parts.append("\r");
            } elif e == 116 {
                parts.append("\t");
            } elif e == 117 {
                cp: int = _hex4(p);
                if cp < 0 {
                    p.error = "invalid \\u escape";
                    return "";
                }
                if cp >= 55296
                    and cp <= 56319
                    and p.pos + 1 < p.n
                    and read_byte(p.ptr, p.pos) == 92
                    and read_byte(p.ptr, p.pos + 1) == 117 {
                    save: int = p.pos;
                    p.pos = p.pos + 2;
                    lo: int = _hex4(p);
                    if lo >= 56320 and lo <= 57343 {
                        cp = 65536 + ((cp - 55296) << 10) + (lo - 56320);
                    } else {
                        p.pos = save;
                    }
                }
                if cp == 0 {
                    parts.append("");
                } elif cp >= 55296 and cp <= 57343 {  # engine strings cannot hold NUL
                    parts.append(chr(65533));
                } else {
                    parts.append(chr(cp));
                }
            } else {
                p.error = "invalid escape";
                return "";
            }
            continue;
        }
        # run of plain bytes
        run_start: int = p.pos;
        while p.pos < p.n {
            d: int = read_byte(p.ptr, p.pos);
            if d == 34 or d == 92 {
                break;
            }
            if d == 10 {
                p.line = p.line + 1;
            }
            p.pos = p.pos + 1;
        }
        parts.append(bytes_to_str(p.ptr, run_start, p.pos - run_start));
    }
    p.error = "unterminated string";
    return "";
}

def _parse_array(p: JsonParser, depth: int) -> JVal {
    a: JVal = jv_array();
    start_line: int = p.line;
    p.pos = p.pos + 1;  # [
    while True {
        _skip_ws(p);
        c: int = _peek(p);
        if c < 0 {
            p.error = "unterminated array";
            return JVal();
        }
        if c == 93 {
            p.pos = p.pos + 1;
            a.single_line = p.line == start_line;
            return a;
        }
        v: JVal = _parse_value(p, depth + 1);
        if p.error != "" {
            return JVal();
        }
        a.items.append(v);
        _skip_ws(p);
        c = _peek(p);
        if c == 44 {
            p.pos = p.pos + 1;
            continue;  # trailing comma allowed: next loop sees ']'
        }
        if c == 93 {
            p.pos = p.pos + 1;
            a.single_line = p.line == start_line;
            return a;
        }
        p.error = "expected ',' or ']' in array";
        return JVal();
    }
}

def _parse_object(p: JsonParser, depth: int) -> JVal {
    o: JVal = jv_object();
    start_line: int = p.line;
    p.pos = p.pos + 1;  # {
    while True {
        _skip_ws(p);
        c: int = _peek(p);
        if c < 0 {
            p.error = "unterminated object";
            return JVal();
        }
        if c == 125 {
            p.pos = p.pos + 1;
            o.single_line = p.line == start_line;
            return o;
        }
        if c != 34 {
            p.error = "expected string key in object";
            return JVal();
        }
        key: str = _parse_string(p);
        if p.error != "" {
            return JVal();
        }
        _skip_ws(p);
        if _peek(p) != 58 {
            p.error = "expected ':' after object key";
            return JVal();
        }
        p.pos = p.pos + 1;
        _skip_ws(p);
        v: JVal = _parse_value(p, depth + 1);
        if p.error != "" {
            return JVal();
        }
        jv_set(o, key, v);
        _skip_ws(p);
        c = _peek(p);
        if c == 44 {
            p.pos = p.pos + 1;
            continue;
        }
        if c == 125 {
            p.pos = p.pos + 1;
            o.single_line = p.line == start_line;
            return o;
        }
        p.error = "expected ',' or '}' in object";
        return JVal();
    }
}

# ── serialisation helpers ─────────────────────────────────────────────────────

"""JSON string literal for `s` (with quotes). Escapes like JSON.stringify:
\" \\ and control characters; non-ASCII is emitted raw (UTF-8)."""
def:pub json_quote(s: str) -> str {
    out: list[str] = ["\""];
    n: int = len(s);
    i: int = 0;
    run_start: int = 0;
    while i < n {
        c: int = ord(s[i]);
        esc: str = "";
        if c == 34 {
            esc = "\\\"";
        } elif c == 92 {
            esc = "\\\\";
        } elif c == 10 {
            esc = "\\n";
        } elif c == 13 {
            esc = "\\r";
        } elif c == 9 {
            esc = "\\t";
        } elif c == 8 {
            esc = "\\b";
        } elif c == 12 {
            esc = "\\f";
        } elif c < 32 {
            hexd: str = "0123456789abcdef";
            esc = "\\u00" + hexd[c >> 4] + hexd[c & 15];
        }
        if esc != "" {
            if i > run_start {
                out.append(s[run_start:i]);
            }
            out.append(esc);
            run_start = i + 1;
        }
        i = i + 1;
    }
    if n > run_start {
        out.append(s[run_start:n]);
    }
    out.append("\"");
    return "".join(out);
}

"""Compact JSON text of a value (keys in stored order)."""
def:pub json_stringify_compact(v: JVal) -> str {
    if v.kind == JV_NULL or v.kind == JV_MISSING {
        return "null";
    }
    if v.kind == JV_BOOL {
        return "true" if v.b else "false";
    }
    if v.kind == JV_NUM {
        if v.is_int {
            return str(v.i);
        }
        return str(v.num);
    }
    if v.kind == JV_STR {
        return json_quote(v.s);
    }
    if v.kind == JV_ARR {
        parts: list[str] = [];
        for it in v.items {
            parts.append(json_stringify_compact(it));
        }
        return "[" + ",".join(parts) + "]";
    }
    parts2: list[str] = [];
    for k in v.keys {
        parts2.append(json_quote(k) + ":" + json_stringify_compact(v.vals[k]));
    }
    return "{" + ",".join(parts2) + "}";
}
