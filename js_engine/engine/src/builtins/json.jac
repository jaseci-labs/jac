"""
Built-in: JSON

Implements ECMAScript §25.5 — The JSON Object.
  JSON.parse(text, reviver?)           — recursive-descent parser
  JSON.stringify(value, replacer?, space?) — serializer with optional indentation

Zero internal dependencies beyond the /1 runtime primitives.

Bun reference  : bun/src/bun.js/bindings/JSONObject.zig
                 bun/src/js/builtins/JSON.ts
JSC reference  : Source/JavaScriptCore/runtime/JSONObject.h
                 Source/JavaScriptCore/runtime/LiteralParser.h (fast JSON parser)
ECMAScript §25.5: https://tc39.es/ecma262/#sec-json-object

Design notes:
  - reviver  (JSON.parse arg 2)  : routed through json_vm.na.jac when called from VM.
  - replacer (JSON.stringify arg 2): applied in vm.na.jac (_vm_json_serialize_prepass).
  - toJSON() method support: invoked via json_vm.na.jac when called from VM.
  - Numbers: Int32 produced for whole numbers in [-2^31, 2^31-1], Float64 otherwise.
  - Cycle detection: tracks as_ptr of visited Object values; throws TypeError.
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_int,
    js_number,
    js_true,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_bool,
    jsv_is_null,
    jsv_is_string_cell,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_is_bigint_cell,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_bool,
    jsv_to_table_id,
    jsv_from_bool,
    jsv_from_string_id
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_new_ordinary,
    js_object_get,
    js_object_set,
    js_object_keys,
    KEY_CTOR_KIND,
    js_object_has_own,
    js_object_delete
}
import from engine.src.runtime.jsstring {
    str_intern_index,
    str_intern,
    str_heap,
    str_from_id,
    str_substr,
    str_char_at,
    utf8_encode_scalar
}
import from engine.src.runtime.error {
    make_syntax_error,
    make_type_error,
    vm_throw_native
}
import from engine.src.builtins.array { _KEY_IS_ARRAY, js_array_create }
import from engine.src.builtins.string {
    is_string_object,
    string_value_of,
    js_coerce_to_string
}
import from engine.src.vm.vm_obs { js_to_string_observable, js_object_get_observable }
import from engine.src.runtime.binary_state {
    binary_is_typed_array,
    binary_typed_array_length,
    binary_typed_array_element_kind,
    binary_typed_array_load
}
import from engine.src.builtins.number {
    is_number_object,
    number_value_of,
    is_boolean_object,
    boolean_value_of
}
import from engine.src.runtime.gc_pin { gc_pin_value, gc_unpin_value }
import from engine.src.runtime.dtoa { number_to_string_radix10 }

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Constants
# ══════════════════════════════════════════════════════════════════════════════

"""Maximum nesting depth for JSON parse/stringify (prevents stack overflow)."""
glob JSON_MAX_DEPTH: int = 512;

"""Sentinel returned by _strf_value to signal a circular reference."""
glob:pub _CYCLE_SENTINEL: str = "\x00CYCLE\x00";

"""
Parallel source tree from the most recent JSON.parse.
Mirrors the parsed value shape: string cells hold primitive literal source text;
objects/arrays hold nested source nodes under the same keys/indices.
Used by the VM reviver to populate `context.source` (json-parse-with-source).
"""
glob:pub _JSON_LAST_SOURCE_ROOT: JSValue = js_undefined();

# ══════════════════════════════════════════════════════════════════════════════
# 2.  Parser — recursive descent
# ══════════════════════════════════════════════════════════════════════════════

"""
Mutable state for the JSON recursive-descent parser.
  src       — the full JSON source string
  pos       — current read position (0-based character index)
  had_error — True once an error has been encountered
  error_msg — human-readable description of the first error
"""
obj JSONParser {
    has src: str,
        pos: int,
        had_error: bool,
        error_msg: str,
        want_source: bool = False,
        src_len: int = -1;
}

# json-parse-with-source (TC39): build the parallel source-text tree only
# when a reviver is present to observe `context.source`. WITHOUT a reviver
# the tree is unobservable, and building it per value (a heap-string copy of
# every literal's source span + mirror objects/arrays) is pure waste — for
# a large document (e.g. a bundler sourcemap with embedded sourcesContent)
# it dominates allocation and, since JSON.parse is one long native call with
# no interleaved GC, OOMs the process. Default False; set True by
# json_parse_core only when args[1] is callable. Appended at struct END.

# Byte length of `src`, cached on first use by _parse_string. Appended at END.
# ── Low-level cursor helpers ──────────────────────────────────────────────────

"""Return the character at the current position, or "" if at/past the end."""
def _peek(p: JSONParser) -> str {
    return str_char_at(p.src, p.pos);
}

"""Advance the cursor by one character."""
def _advance(p: JSONParser) {
    p.pos = p.pos + 1;
}

"""Return the current character and advance the cursor."""
def _read(p: JSONParser) -> str {
    ch: str = str_char_at(p.src, p.pos);
    p.pos = p.pos + 1;
    return ch;
}

"""Skip JSON whitespace (space, horizontal tab, CR, LF — RFC 8259 §2)."""
def _skip_ws(p: JSONParser) {
    ch: str = _peek(p);
    while ch == " " or ch == "\t" or ch == "\n" or ch == chr(13) {
        _advance(p);
        ch = _peek(p);
    }
}

"""Record a parse error if none has been recorded yet."""
def _set_error(p: JSONParser, msg: str) {
    if not p.had_error {
        p.had_error = True;
        p.error_msg = msg;
    }
}

# ── Value dispatcher ──────────────────────────────────────────────────────────

"""
Parse a single JSON value at the current position.
Returns [value, source_node] where source_node is a string cell for primitive
literals (exact source text) or an object/array mirroring containers.
Returns [js_null(), js_undefined()] on error (check p.had_error after the call).
"""
def _parse_value_ex(p: JSONParser, depth: int) -> list[JSValue] {
    if p.had_error {
        return [js_null(), js_undefined()];
    }
    if depth > JSON_MAX_DEPTH {
        _set_error(p, "Maximum nesting depth exceeded");
        return [js_null(), js_undefined()];
    }
    _skip_ws(p);
    ch: str = _peek(p);
    if ch == "" {
        _set_error(p, "Unexpected end of JSON input");
        return [js_null(), js_undefined()];
    }
    start: int = p.pos;
    if ch == "\"" {
        raw_s: str = _parse_string(p);
        # Source node only when a reviver will observe it (see want_source): the
        # str_substr + str_heap of every literal's span is the JSON leak driver.
        if p.want_source {
            src_lit: str = str_substr(p.src, start, p.pos);
            return [
                jsv_from_string_id(str_heap(raw_s)),  # G1.5: JSON string VALUE (key path interns separately)
                jsv_from_string_id(str_heap(src_lit))  # G1.5: JSON source-text value
            ];
        }
        return [jsv_from_string_id(str_heap(raw_s)), js_undefined()];
    }
    if ch == "{" {
        return _parse_object_ex(p, depth + 1);
    }
    if ch == "[" {
        return _parse_array_ex(p, depth + 1);
    }
    if ch == "t" {
        kv: JSValue = _check_keyword(p, "true");
        if p.want_source {
            return [kv, jsv_from_string_id(str_heap(str_substr(p.src, start, p.pos)))];
        }
        return [kv, js_undefined()];
    }
    if ch == "f" {
        kv2: JSValue = _check_keyword(p, "false");
        if p.want_source {
            return [kv2, jsv_from_string_id(str_heap(str_substr(p.src, start, p.pos)))];
        }
        return [kv2, js_undefined()];
    }
    if ch == "n" {
        kv3: JSValue = _check_keyword(p, "null");
        if p.want_source {
            return [kv3, jsv_from_string_id(str_heap(str_substr(p.src, start, p.pos)))];
        }
        return [kv3, js_undefined()];
    }
    if ch == "-" or (ch >= "0" and ch <= "9") {
        num_v: JSValue = _parse_number(p);
        if p.want_source {
            return [
                num_v,
                jsv_from_string_id(str_heap(str_substr(p.src, start, p.pos)))
            ];
        }
        return [num_v, js_undefined()];
    }
    _set_error(p, "Unexpected token: " + ch);
    return [js_null(), js_undefined()];
}

"""Parse a JSON value; discard the parallel source node."""
def _parse_value(p: JSONParser, depth: int) -> JSValue {
    pair: list[JSValue] = _parse_value_ex(p, depth);
    return pair[0];
}

"""
Consume a fixed literal keyword (true / false / null) from the current position.
kw must be one of "true", "false", "null".
Constructs the JSValue locally to avoid the imported-struct-as-param codegen issue.
"""
def _check_keyword(p: JSONParser, kw: str) -> JSValue {
    n: int = len(kw);
    actual: str = str_substr(p.src, p.pos, p.pos + n);
    if actual == kw {
        p.pos = p.pos + n;
        if kw == "true" {
            return jsv_from_bool(True);
        }
        if kw == "false" {
            return jsv_from_bool(False);
        }
        return js_null();
    }
    _set_error(p, "Unexpected token: " + actual);
    return js_null();
}

# ── String parser ─────────────────────────────────────────────────────────────

"""
Parse a JSON string from the current position (cursor must be on the opening '"').
Returns the decoded string (without surrounding quotes).  Sets p.had_error on
any violation of the JSON string grammar.
"""
def _parse_string(p: JSONParser) -> str {
    # Scan BYTES (the cursor is a byte offset — str_char_at is byte-indexed) and
    # copy each run of plain characters with ONE slice, joining the pieces at the
    # end. The old loop appended one character at a time (`result = result + ch`),
    # copying the whole prefix per character: O(n²) in the string's length — a
    # 1.46 MB bundler sourcemap (sourcesContent holds whole files) took 15 s to
    # parse, and Vite's dev server re-parses it on every transform of that dep.
    _advance(p);  # consume opening "
    src: str = p.src;
    if p.src_len < 0 {
        p.src_len = len(src);
    }
    n: int = p.src_len;
    parts: list[str] = [];
    run_start: int = p.pos;
    while True {
        if p.pos >= n {
            if p.pos > run_start {
                parts.append(str_substr(src, run_start, p.pos));
            }
            _set_error(p, "Unterminated string literal");
            return "".join(parts);
        }
        b: int = ord(src[p.pos]);
        if b == 34 {  # closing "
            if p.pos > run_start {
                parts.append(str_substr(src, run_start, p.pos));
            }
            p.pos = p.pos + 1;
            return "".join(parts);
        }
        if b == 92 {  # backslash escape
            if p.pos > run_start {
                parts.append(str_substr(src, run_start, p.pos));
            }
            p.pos = p.pos + 1;
            esc: str = _read(p);
            if esc == "\"" {
                parts.append("\"");
            } elif esc == "\\" {
                parts.append("\\");
            } elif esc == "/" {
                parts.append("/");
            }
            # U+0008 / U+000C — use chr() like \r; Jac "\b"/"\f" literals may not compile to control bytes.
            elif esc == "b" {
                parts.append(chr(8));
            } elif esc == "f" {
                parts.append(chr(12));
            } elif esc == "n" {
                parts.append("\n");
            } elif esc == "r" {
                parts.append(chr(13));
            } elif esc == "t" {
                parts.append("\t");
            } elif esc == "u" {
                # \uXXXX — consume 4 hexadecimal digits
                hex4: str = str_substr(src, p.pos, p.pos + 4);
                if len(hex4) < 4 {
                    _set_error(p, "Invalid \\u escape in string");
                    return "".join(parts);
                }
                p.pos = p.pos + 4;
                cp: int = _hex4_to_int(hex4);
                if cp < 0 {
                    _set_error(p, "Invalid \\u escape: " + hex4);
                    return "".join(parts);
                }
                # A high-surrogate escape followed by a low-surrogate escape is ONE
                # code point (`"\\ud83d\\ude00"` is "😀"). Encoding the halves
                # separately left two lone surrogates in the UTF-8 string, which then
                # compared unequal to the same text written literally.
                if cp >= 55296
                    and cp <= 56319
                    and p.pos + 6 <= n
                    and ord(src[p.pos]) == 92
                    and src[p.pos + 1] == "u" {
                    lo4: int = _hex4_to_int(str_substr(src, p.pos + 2, p.pos + 6));
                    if lo4 >= 56320 and lo4 <= 57343 {
                        cp = 65536 + (cp - 55296) * 1024 + (lo4 - 56320);
                        p.pos = p.pos + 6;
                    }
                }
                parts.append(utf8_encode_scalar(cp));
            } else {
                _set_error(p, "Invalid escape sequence: \\" + esc);
                return "".join(parts);
            }
            run_start = p.pos;
            continue;
        }
        # ES §25.5.1 JSONString grammar: a JSONStringCharacter is any code
        # point EXCEPT U+0000-U+001F, which must appear escaped. A literal
        # tab/newline inside a string is a SyntaxError, not content. (Bytes of a
        # multi-byte UTF-8 character are all >= 0x80.)
        if b < 32 {
            if p.pos > run_start {
                parts.append(str_substr(src, run_start, p.pos));
            }
            _set_error(p, "Unescaped control character in string");
            return "".join(parts);
        }
        p.pos = p.pos + 1;
    }
    return "".join(parts);  # unreachable; satisfies type checker
}

"""
Convert a 4-character lowercase or uppercase hex string to an integer codepoint.
Returns -1 if the string contains a non-hexadecimal character.
"""
def _hex4_to_int(s: str) -> int {
    result: int = 0;
    i: int = 0;
    while i < 4 {
        c: str = str_char_at(s, i);
        if c >= "0" and c <= "9" {
            result = result * 16 + (ord(c) - ord("0"));
        } elif c >= "a" and c <= "f" {
            result = result * 16 + 10 + (ord(c) - ord("a"));
        } elif c >= "A" and c <= "F" {
            result = result * 16 + 10 + (ord(c) - ord("A"));
        } else {
            return -1;
        }
        i = i + 1;
    }
    return result;
}

# ── Number parser ─────────────────────────────────────────────────────────────

"""
Parse a JSON number (integer or float) from the current position.
Produces a JSValue with tag=Int32 when the number is a whole value that fits in
a 32-bit signed integer; Float64 otherwise.
"""
def _parse_number(p: JSONParser) -> JSValue {
    start: int = p.pos;
    is_int: bool = True;

    # Optional leading minus
    if _peek(p) == "-" {
        _advance(p);
    }

    # Integer part
    first_dig: str = _peek(p);
    if first_dig == "0" {
        _advance(p);
    } elif first_dig >= "1" and first_dig <= "9" {
        _advance(p);
        next_d: str = _peek(p);
        while next_d >= "0" and next_d <= "9" {
            _advance(p);
            next_d = _peek(p);
        }
    } else {
        _set_error(p, "Invalid number: expected digit");
        return js_int(0);
    }

    # Optional fractional part
    if _peek(p) == "." {
        is_int = False;
        _advance(p);
        frac_d: str = _peek(p);
        if not (frac_d >= "0" and frac_d <= "9") {
            _set_error(p, "Invalid number: expected digit after '.'");
            return js_int(0);
        }
        nfd: str = _peek(p);
        while nfd >= "0" and nfd <= "9" {
            _advance(p);
            nfd = _peek(p);
        }
    }

    # Optional exponent
    exp_c: str = _peek(p);
    if exp_c == "e" or exp_c == "E" {
        is_int = False;
        _advance(p);
        sgn_c: str = _peek(p);
        if sgn_c == "+" or sgn_c == "-" {
            _advance(p);
        }
        exp_d: str = _peek(p);
        if not (exp_d >= "0" and exp_d <= "9") {
            _set_error(p, "Invalid number: expected digit in exponent");
            return js_int(0);
        }
        ned: str = _peek(p);
        while ned >= "0" and ned <= "9" {
            _advance(p);
            ned = _peek(p);
        }
    }

    num_str: str = str_substr(p.src, start, p.pos);
    if is_int {
        n_i: int = int(num_str);
        if n_i >= -2147483648 and n_i <= 2147483647 {
            return js_int(n_i);
        }
        return js_number(float(n_i));
    }
    return js_number(float(num_str));
}

# ── Object parser ─────────────────────────────────────────────────────────────

"""
Parse a JSON object { "key": value, ... } starting at '{'.
Returns [object, source_object] where source_object mirrors keys with source nodes.
"""
def _parse_object_ex(p: JSONParser, depth: int) -> list[JSValue] {
    _advance(p);  # consume {
    # JSON.parse produces ORDINARY objects (ES §25.5.1) — [[Prototype]] must be
    # Object.prototype, not null; `Object.getPrototypeOf(JSON.parse("{}"))` is
    # Object.prototype and the result is extensible/writable/configurable.
    obj_out: JSValue = js_object_new_ordinary();
    # Mirror source object only when a reviver observes it (want_source). When
    # off it stays undefined and the guarded js_object_set below never fires
    # (pair_o[1] is undefined), so no source object is allocated or populated.
    src_out: JSValue = js_object_new_ordinary() if p.want_source else js_undefined();
    _skip_ws(p);
    if _peek(p) == "}" {
        _advance(p);
        return [obj_out, src_out];
    }
    first: bool = True;
    while not p.had_error {
        _skip_ws(p);
        if not first {
            sep_c: str = _peek(p);
            if sep_c == "}" {
                _advance(p);
                return [obj_out, src_out];
            }
            if sep_c != "," {
                _set_error(p, "Expected ',' or '}' in object");
                return [obj_out, src_out];
            }
            _advance(p);  # consume ,
            _skip_ws(p);
        }
        first = False;
        # Key must be a string
        if _peek(p) != "\"" {
            _set_error(p, "Expected string key in object, got: " + _peek(p));
            return [obj_out, src_out];
        }
        key_str: str = _parse_string(p);
        if p.had_error {
            return [obj_out, src_out];
        }
        _skip_ws(p);
        if _peek(p) != ":" {
            _set_error(p, "Expected ':' after object key");
            return [obj_out, src_out];
        }
        _advance(p);  # consume :
        pair_o: list[JSValue] = _parse_value_ex(p, depth);
        if p.had_error {
            return [obj_out, src_out];
        }
        kid: int = str_intern(key_str);
        js_object_set(obj_out, kid, pair_o[0]);
        if not jsv_is_undefined(pair_o[1]) {
            js_object_set(src_out, kid, pair_o[1]);
        }
        _skip_ws(p);
    }
    return [obj_out, src_out];
}

# ── Array parser ──────────────────────────────────────────────────────────────

"""
Parse a JSON array [ value, ... ] starting at '['.
Returns [array, source_array] where source_array mirrors element source nodes.
"""
def _parse_array_ex(p: JSONParser, depth: int) -> list[JSValue] {
    _advance(p);  # consume [
    # Collect elements then build a REAL array via js_array_create so the result's
    # [[Prototype]] is Array.prototype (ES §25.5.1 produces ordinary Arrays), not a
    # null-proto object with just the _KEY_IS_ARRAY marker.
    elems: list[JSValue] = [];
    src_elems: list[JSValue] = [];
    _skip_ws(p);
    if _peek(p) == "]" {
        _advance(p);
        return [
            js_array_create(elems),
            (js_array_create(src_elems) if p.want_source else js_undefined())
        ];
    }
    first_a: bool = True;
    while not p.had_error {
        _skip_ws(p);
        if not first_a {
            sep_a: str = _peek(p);
            if sep_a == "]" {
                _advance(p);
                return [
                    js_array_create(elems),
                    (js_array_create(src_elems) if p.want_source else js_undefined())
                ];
            }
            if sep_a != "," {
                _set_error(p, "Expected ',' or ']' in array");
                return [
                    js_array_create(elems),
                    (js_array_create(src_elems) if p.want_source else js_undefined())
                ];
            }
            _advance(p);  # consume ,
        }
        first_a = False;
        pair_a: list[JSValue] = _parse_value_ex(p, depth);
        if p.had_error {
            return [
                js_array_create(elems),
                (js_array_create(src_elems) if p.want_source else js_undefined())
            ];
        }
        elems.append(pair_a[0]);
        # Source mirror only when a reviver observes it (want_source).
        if p.want_source {
            if jsv_is_undefined(pair_a[1]) {
                src_elems.append(js_null());
            } else {
                src_elems.append(pair_a[1]);
            }
        }
        _skip_ws(p);
    }
    return [
        js_array_create(elems),
        (js_array_create(src_elems) if p.want_source else js_undefined())
    ];
}

# ══════════════════════════════════════════════════════════════════════════════
# 3.  Stringifier
# ══════════════════════════════════════════════════════════════════════════════

"""
True if `v` should be treated as a Function value for JSON (callable objects
including user closures, native function values, and `js_callable_create` class
constructors). Matches the VM’s `typeof` = \"function\" cases well enough
that a callable JSObject is not mis-serialized as `{}` when it has no props.
"""
def:pub _strf_is_function_value(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    if jsv_to_table_id(v) < 0 {
        return True;  # user function or native; both are not plain data objects
    }
    if jsv_to_table_id(v) > 0 and js_object_has_own(v, KEY_CTOR_KIND) {
        return True;
    }
    is_cls: int = str_intern("__IS_CLASS__");
    if jsv_to_table_id(v) >= 0 and js_object_has_own(v, is_cls) {
        return True;
    }
    return False;
}

"""
Produce the JSON fragment for a single JSValue.

`indent_str` — the per-depth indentation unit; "" → compact (no newlines).
`depth`      — current nesting depth (used to build the indentation prefix).
`visited`    — list of as_ptr values for objects currently on the serialization
               stack; used for O(n) cycle detection.

Returns:
  - A non-empty string with the JSON representation.
  - "" if the value should be *omitted* (undefined, Symbol — object keys skip,
    array slots become "null").
  - _CYCLE_SENTINEL if a circular reference was detected.
"""
def _strf_value(v: JSValue, indent_str: str, depth: int, visited: set[int]) -> str {
    if jsv_is_undefined(v) {
        return "";  # omit in objects; caller converts to "null" in arrays
    }
    if jsv_is_null(v) {
        return "null";
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return "true";
        } else {
            return "false";
        }
    }
    if jsv_is_int32(v) {
        return str(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return _strf_number(jsv_to_double(v));
    }
    if jsv_is_string_cell(v) {
        return _strf_string(str_from_id(jsv_to_table_id(v)));
    }
    if jsv_is_object_cell(v) {
        if is_string_object(v) {
            return _strf_string(str_from_id(jsv_to_table_id(string_value_of(v))));
        }
        if is_number_object(v) {
            prim_n: JSValue = number_value_of(v);
            if jsv_is_int32(prim_n) {
                return str(jsv_to_int32(prim_n));
            }
            if jsv_is_double(prim_n) {
                return _strf_number(jsv_to_double(prim_n));
            }
        }
        if is_boolean_object(v) {
            if jsv_to_bool(boolean_value_of(v)) {
                return "true";
            } else {
                return "false";
            }
        }
        # Object-boxed BigInt ([[PrimitiveValue]]) — SerializeJSONProperty unwraps
        # [[BigIntData]] then throws TypeError.
        bi_prim: JSValue = js_object_get(v, str_intern("[[PrimitiveValue]]"));
        if jsv_is_bigint_cell(bi_prim) {
            vm_throw_native(make_type_error("Do not know how to serialize a BigInt"));
            return "";
        }
        if _strf_is_function_value(v) {
            return "";  # function values omit (and root undefined in js_json_stringify)
        }
        # Cycle detection: check if this object pointer is already on the stack
        ptr: int = jsv_to_table_id(v);
        if ptr in visited {
            return _CYCLE_SENTINEL;
        }
        visited.add(ptr);
        # Dispatch: array or plain object?
        marker_v: JSValue = js_object_get(v, _KEY_IS_ARRAY);
        is_arr_v: bool = jsv_is_bool(marker_v) and jsv_to_bool(marker_v);
        out_s: str = "";
        if is_arr_v {
            out_s = _strf_array(v, indent_str, depth, visited);
        } else {
            out_s = _strf_object(v, indent_str, depth, visited);
        }
        visited.discard(ptr);
        return out_s;
    }
    if jsv_is_bigint_cell(v) {
        vm_throw_native(make_type_error("Do not know how to serialize a BigInt"));
        return "";
    }
    # Symbol, Function → omit
    return "";
}

"""
Format a float as a JSON number token.
NaN and ±Infinity are not valid JSON; the spec requires them to be emitted as "null".
"""
def _strf_number(f: float) -> str {
    # NaN: not equal to itself
    if not (f == f) {
        return "null";
    }
    # Infinity: magnitude exceeds the largest finite double
    big: float = 1.7976931348623157e+308;
    if f > big or f < -big {
        return "null";
    }
    if f == 0.0 {
        return "0";
    }
    if f == int(f) and f >= -9007199254740991.0 and f <= 9007199254740991.0 {
        return str(int(f));
    }
    # §25.5.2.3 SerializeJSONProperty: ToString(number) (not the host's %g form).
    return number_to_string_radix10(f);
}

"""Produce a JSON-encoded string with surrounding double-quotes and all required escapes."""
# Workaround: Jac native "\\n" compiles to backslash+newline (0x5C 0x0A), not
# backslash+'n'.  Same for \\t, \\r, \\b, \\f.  Concatenating "\\" + "n" etc.
# forces the letter to be the literal ASCII byte, which is what we need.
glob _JSON_ESC_QUOT: str = "\\" + "\"";
glob _JSON_ESC_BSL: str = "\\" + "\\",
     _JSON_ESC_N: str = "\\" + "n",
     _JSON_ESC_R: str = "\\" + "r",
     _JSON_ESC_T: str = "\\" + "t",
     _JSON_ESC_B: str = "\\" + "b",
     _JSON_ESC_F: str = "\\" + "f",
     _JSON_ESC_U: str = "\\" + "u";

def _strf_string(s: str) -> str {
    # Printable ASCII (0x20..0x7E: no control characters, no CESU-8 lead
    # byte) without `"` or `\\` needs no escape: one copy (V4.19).
    if s.isprintable() and s.find("\"") < 0 and s.find("\\") < 0 {
        return "\"" + s + "\"";
    }
    # list[str] + join avoids O(n^2) host string concat on large payloads.
    parts: list[str] = [];
    parts.append("\"");
    i: int = 0;
    n: int = len(s);
    while i < n {
        ch: str = str_char_at(s, i);
        o: int = ord(ch);
        if ch == "\"" {
            parts.append(_JSON_ESC_QUOT);
        } elif ch == "\\" {
            # A backslash is always text here: U+0000 is the C0 80 sentinel
            # (handled below), so `\x00` in a string is four real characters.
            parts.append(_JSON_ESC_BSL);
        } elif ch == "\n" {
            parts.append(_JSON_ESC_N);
        } elif o == 13 {
            parts.append(_JSON_ESC_R);
        } elif o == 9 {
            parts.append(_JSON_ESC_T);
        } elif o == 8 {
            # Backspace — compare via code point; Jac "\\b" literals are unreliable.
            parts.append(_JSON_ESC_B);
        } elif o == 12 {
            # Form feed
            parts.append(_JSON_ESC_F);
        } elif o < 32 {
            # Other control characters → \u00XX
            parts.append(_JSON_ESC_U);
            parts.append("00");
            parts.append(_hex2(o));
        } elif o == 0xC0 and i + 1 < n and ord(str_char_at(s, i + 1)) == 0x80 {
            # U+0000 (the engine's NUL sentinel C0 80) → \u0000
            parts.append(_JSON_ESC_U);
            parts.append("0000");
            i = i + 2;
            continue;
        } elif o == 0xED {
            # Potential CESU-8 lone surrogate (U+D800..U+DFFF): 3-byte pattern ED [A0-BF] [80-BF]
            sur_ok: bool = False;
            if i + 2 < n {
                b1: int = ord(str_char_at(s, i + 1));
                b2: int = ord(str_char_at(s, i + 2));
                if b1 >= 0xA0 and b1 <= 0xBF and b2 >= 0x80 and b2 <= 0xBF {
                    cp_s: int = 0xD000 | ((b1 & 0x3F) << 6) | (b2 & 0x3F);
                    parts.append(_JSON_ESC_U);
                    parts.append(_hex4(cp_s));
                    i = i + 3;
                    sur_ok = True;
                    continue;
                }
            }
            if not sur_ok {
                parts.append(ch);
            }
        } else {
            parts.append(ch);
        }
        i = i + 1;
    }
    parts.append("\"");
    return "".join(parts);
}

"""Return a 4-character lowercase hex string for a 16-bit integer (0–0xFFFF)."""
def _hex4(n: int) -> str {
    d3: int = (n >> 12) & 0xF;
    d2: int = (n >> 8) & 0xF;
    d1: int = (n >> 4) & 0xF;
    d0: int = n & 0xF;
    return _hex_c(d3) + _hex_c(d2) + _hex_c(d1) + _hex_c(d0);
}

"""Return the integer value 0-15 for a hex digit character, or -1 if not a hex digit."""
def _hex_val_char(c: str) -> int {
    o: int = ord(c);
    if o >= 48 and o <= 57 {
        return o - 48;
    }  # '0'-'9'
    if o >= 97 and o <= 102 {
        return o - 87;
    }  # 'a'-'f'
    if o >= 65 and o <= 70 {
        return o - 55;
    }  # 'A'-'F'
    return -1;
}

"""Return a 2-character lowercase hex string for an integer 0–255."""
def _hex2(n: int) -> str {
    hi: int = n // 16;
    lo: int = n - hi * 16;
    return _hex_c(hi) + _hex_c(lo);
}

"""Return a single hex digit character for a nibble 0–15."""
def _hex_c(n: int) -> str {
    if n < 10 {
        return str(n);
    }
    if n == 10 {
        return "a";
    }
    if n == 11 {
        return "b";
    }
    if n == 12 {
        return "c";
    }
    if n == 13 {
        return "d";
    }
    if n == 14 {
        return "e";
    }
    return "f";
}

"""True for the engine-internal own fields of a TypedArray view object
(binary_types.js constructor / buffer_native.jac); they are not JS-visible
own properties (mirrors vm.jac _ta_is_internal_key)."""
def _json_ta_internal_key(key_s: str) -> bool {
    return (
        key_s == "_isTypedArrayInstance"
        or key_s == "_typedArrayName"
        or key_s == "BYTES_PER_ELEMENT"
        or key_s == "_getter"
        or key_s == "_setter"
        or key_s == "_ctor"
        or key_s == "_buffer"
        or key_s == "_byteOffset"
        or key_s == "_fixedLength"
        or key_s == "_length"
        or key_s == "_readAt"
        or key_s == "_writeAt"
    );
}

"""Stringify a plain JSObject (non-array) as a JSON object fragment."""
def _strf_object(v: JSValue, indent_str: str, depth: int, visited: set[int]) -> str {
    keys: list[int] = js_object_keys(v);
    ta_len: int = 0;
    ta_kind: int = 0;
    if binary_is_typed_array(v) {
        # A TypedArray serializes as an object of its index keys (ES §25.5.2.2
        # via EnumerableOwnProperties): virtual integer keys first, then any
        # user-added own keys; the engine-internal fields are not visible.
        ta_keys: list[int] = [];
        ta_len = binary_typed_array_length(v);
        ta_kind = binary_typed_array_element_kind(v);
        ta_i: int = 0;
        while ta_i < ta_len {
            ta_keys.append(str_intern_index(ta_i));
            ta_i = ta_i + 1;
        }
        for ta_k in keys {
            ta_ks: str = str_from_id(ta_k);
            if not _json_ta_internal_key(ta_ks) {
                ta_keys.append(ta_k);
            }
        }
        keys = ta_keys;
    }
    is_ta_obj: bool = binary_is_typed_array(v);
    uses_indent: bool = indent_str != "";
    parts: list[str] = [];
    parts.append("{");
    first_k: bool = True;
    ki: int = 0;
    while ki < len(keys) {
        key_id: int = keys[ki];
        ki = ki + 1;
        # Skip internal marker keys (those not in the string-intern table)
        key_s: str = str_from_id(key_id);
        if key_s == "" {
            continue;
        }
        val_v: JSValue = js_object_get(v, key_id);
        if is_ta_obj and ki <= ta_len {
            # Integer-indexed elements live in the binary side-table, not the
            # property map: integer kinds load natively; float/bigint kinds go
            # through the VM's [[Get]] when a VM context is active.
            if ta_kind >= 1 and ta_kind <= 7 {
                val_v = binary_typed_array_load(v, ki - 1);
            } else {
                val_v = js_object_get_observable(v, key_id, v);
            }
        }
        val_s: str = _strf_value(val_v, indent_str, depth + 1, visited);
        if val_s == _CYCLE_SENTINEL {
            return _CYCLE_SENTINEL;
        }
        if val_s == "" {
            continue;
        }  # undefined / Symbol → omit this key
        if not first_k {
            parts.append(",");
        }
        first_k = False;
        if uses_indent {
            parts.append("\n");
            parts.append(_repeat(indent_str, depth + 1));
        }
        parts.append(_strf_string(key_s));
        parts.append(":");
        if uses_indent {
            parts.append(" ");
        }
        parts.append(val_s);
    }
    if uses_indent and not first_k {
        parts.append("\n");
        parts.append(_repeat(indent_str, depth));
    }
    parts.append("}");
    return "".join(parts);
}

"""Stringify a JS Array JSValue as a JSON array fragment."""
def _strf_array(v: JSValue, indent_str: str, depth: int, visited: set[int]) -> str {
    len_v: JSValue = js_object_get(v, str_intern("length"));
    n_el: int = 0;
    if jsv_is_int32(len_v) {
        n_el = jsv_to_int32(len_v);
    } elif jsv_is_double(len_v) {
        n_el = int(jsv_to_double(len_v));
    }
    uses_indent: bool = indent_str != "";
    parts: list[str] = [];
    parts.append("[");
    first_el: bool = True;
    i_el: int = 0;
    while i_el < n_el {
        elem_key: int = str_intern_index(i_el);
        elem: JSValue = js_object_get(v, elem_key);
        elem_s: str = _strf_value(elem, indent_str, depth + 1, visited);
        if elem_s == _CYCLE_SENTINEL {
            return _CYCLE_SENTINEL;
        }
        # undefined / Symbol in an array slot → "null" (per spec §25.5.2.2)
        if elem_s == "" {
            elem_s = "null";
        }
        if not first_el {
            parts.append(",");
        }
        first_el = False;
        if uses_indent {
            parts.append("\n");
            parts.append(_repeat(indent_str, depth + 1));
        }
        parts.append(elem_s);
        i_el = i_el + 1;
    }
    if uses_indent and not first_el {
        parts.append("\n");
        parts.append(_repeat(indent_str, depth));
    }
    parts.append("]");
    return "".join(parts);
}

"""Repeat string `s` exactly `n` times."""
def _repeat(s: str, n: int) -> str {
    if n <= 0 {
        return "";
    }
    if n == 1 {
        return s;
    }
    # Prefer host repeat when available; fall back to join for safety.
    parts: list[str] = [];
    i: int = 0;
    while i < n {
        parts.append(s);
        i = i + 1;
    }
    return "".join(parts);
}

# ══════════════════════════════════════════════════════════════════════════════
# 4.  Public API
# ══════════════════════════════════════════════════════════════════════════════

"""
JSON.parse(text, reviver?) — core parse without reviver (reviver handled in json_vm).
"""
def:pub json_parse_core(args: list[JSValue]) -> JSValue {
    text_v: JSValue = args[0] if len(args) > 0 else js_undefined();
    # ES §25.5.1 step 1: `Let jsonString be ? ToString(text)`. Non-strings are
    # coerced, not rejected — JSON.parse(42) parses "42" and returns 42, and
    # JSON.parse(null) parses "null". Only the resulting *text* can be invalid.
    src_s: str = "";
    if jsv_is_string_cell(text_v) {
        src_s = str_from_id(jsv_to_table_id(text_v));
    } elif jsv_is_symbol(text_v) {
        vm_throw_native(make_type_error("Cannot convert a Symbol value to a string"));
        return js_undefined();
    } elif jsv_is_object_cell(text_v) {
        src_s = js_to_string_observable(text_v);
        if vm_has_native_exc() {
            return js_undefined();
        }
    } else {
        src_s = js_coerce_to_string(text_v);
    }
    # Build the parallel source-text tree only when a reviver (args[1]) is
    # present to observe `context.source`; otherwise it is unobservable waste
    # that OOMs on large documents (see JSONParser.want_source).
    # Superset of the VM's reviver test (_vm_json_hook_callable): any non-null
    # second arg. Guarantees source is built whenever a reviver could run (never
    # miss `context.source`); a non-callable non-null arg just builds it in vain
    # (rare, off the hot path). The common JSON.parse(text) omits args[1] → False.
    want_src: bool = len(args) > 1
        and not jsv_is_undefined(args[1])
        and not jsv_is_null(args[1]);
    state: JSONParser = JSONParser(
        src=src_s, pos=0, had_error=False, error_msg="", want_source=want_src
    );
    pair_p: list[JSValue] = _parse_value_ex(state, 0);
    result_v: JSValue = pair_p[0];
    if state.had_error {
        gc_unpin_value(_JSON_LAST_SOURCE_ROOT);  # churning glob root
        _JSON_LAST_SOURCE_ROOT = js_undefined();
        vm_throw_native(make_syntax_error("JSON.parse: " + state.error_msg));
        return js_undefined();
    }
    # Ensure no trailing garbage (beyond whitespace)
    _skip_ws(state);
    leftover: str = _peek(state);
    if leftover != "" {
        gc_unpin_value(_JSON_LAST_SOURCE_ROOT);  # churning glob root
        _JSON_LAST_SOURCE_ROOT = js_undefined();
        vm_throw_native(
            make_syntax_error(
                "JSON.parse: Unexpected non-whitespace after JSON value: " + leftover
            )
        );
        return js_undefined();
    }
    # churning glob root — invisible to the GC root walk; unpin old, pin new
    gc_unpin_value(_JSON_LAST_SOURCE_ROOT);
    _JSON_LAST_SOURCE_ROOT = pair_p[1];
    gc_pin_value(_JSON_LAST_SOURCE_ROOT);
    return result_v;
}

def:pub js_json_parse(args: list[JSValue]) -> JSValue {
    return json_parse_core(args);
}

"""
JSON.stringify(value, replacer?, space?) — with optional toJSON hooks via VM.
"""
def:pub json_stringify_core(args: list[JSValue]) -> JSValue {
    val_sv: JSValue = args[0] if len(args) > 0 else js_undefined();
    # args[1] is replacer — ignored for
    space_v: JSValue = args[2] if len(args) > 2 else js_undefined();

    # ES §25.5.2: Number/String exotic objects are unboxed via ToNumber/ToString
    # ([[NumberData]] / [[StringData]]). Observable valueOf/toString is handled
    # by the VM stringify path before calling into this core.
    if jsv_is_object_cell(space_v) {
        if is_number_object(space_v) {
            space_v = number_value_of(space_v);
        } elif is_string_object(space_v) {
            space_v = string_value_of(space_v);
        }
    }

    # Compute the per-level indentation string from the `space` parameter
    indent_s: str = "";
    if jsv_is_int32(space_v) {
        sp_n: int = jsv_to_int32(space_v);
        if sp_n < 0 {
            sp_n = 0;
        }
        if sp_n > 10 {
            sp_n = 10;
        }
        indent_s = _repeat(" ", sp_n);
    } elif jsv_is_double(space_v) {
        sp_nf: int = int(jsv_to_double(space_v));
        if sp_nf < 0 {
            sp_nf = 0;
        }
        if sp_nf > 10 {
            sp_nf = 10;
        }
        indent_s = _repeat(" ", sp_nf);
    } elif jsv_is_string_cell(space_v) {
        sp_str: str = str_from_id(jsv_to_table_id(space_v));
        n_sp: int = len(sp_str);
        if n_sp > 10 {
            n_sp = 10;
        }
        indent_s = str_substr(sp_str, 0, n_sp);
    }

    visited_sv: set[int] = set();
    # The serializer's result string is produced by a helper that RETURNS it
    # (released correctly) and consumed inline; a named `raw_s: str` local in
    # this frame was never released — every JSON.stringify leaked its output.
    return _json_wrap_result(_json_stringify_str(val_sv, indent_s, visited_sv));
}

def _json_stringify_str(val_sv: JSValue, indent_s: str, visited_sv: set[int]) -> str {
    raw_s: str = _strf_value(val_sv, indent_s, 0, visited_sv);
    if raw_s == _CYCLE_SENTINEL {
        vm_throw_native(make_type_error("Converting circular structure to JSON"));
        return "";
    }
    return raw_s;
}

"""undefined on a pending native exception or an empty result (top-level
undefined / Symbol → undefined, not the string "undefined")."""
def _json_wrap_result(s: str) -> JSValue {
    if vm_has_native_exc() {
        return js_undefined();
    }
    if len(s) == 0 {
        return js_undefined();
    }
    return jsv_from_string_id(str_heap(s));
}

def:pub js_json_stringify(args: list[JSValue]) -> JSValue {
    return json_stringify_core(args);
}
