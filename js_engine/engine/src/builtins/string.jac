"""
Built-in: String constructor

Wraps the internal JSString (runtime/jsstring.na.jac) as a callable
JavaScript String object. Provides the constructor, all static methods,
and all String.prototype methods dispatched on JSValue{tag=String}.

Bun reference   : bun/src/js/builtins/StringConstructor.ts
                  bun/src/JavaScriptCore/StringPrototype.cpp
ECMAScript spec : §22.1 — https://tc39.es/ecma262/#sec-string-objects

Encoding:
  String primitive → JSValue{tag=String, as_ptr=intern_id}
  String object    → JSValue{tag=Object, as_ptr=obj_idx}
                     with _OBJECT_TABLE[obj_idx-1] having a hidden
                     KEY_IS_STRING_OBJ property = JSValue{tag=String}
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_true,
    js_false,
    js_int,
    js_nan,
    jsv_from_string_id,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_nan,
    jsv_is_bigint_cell,
    jsv_is_symbol,
    jsv_to_bool,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_table_id,
    jsv_coerce_to_number
}
import from engine.src.runtime.jsstring {
    str_intern_index,
    js_string_unit_str,
    str_cell_ascii,
    str_heap_ascii,
    str_cell_len,
    str_slice_cell,
    str_substr_cell,
    LAZY_SLICE_MIN,
    str_intern,
    str_heap,
    str_from_id,
    str_char_at,
    str_substr,
    str_to_float,
    utf8_encode_scalar,
    js_string_utf16_units,
    js_string_utf16_len,
    js_string_from_utf16_code_units,
    js_string_utf16_unit_at,
    js_string_unit_at_cell,
    codepoints_to_utf16_units,
    utf16_units_to_scalars,
    js_string_byte_to_unit,
    js_string_unit_to_byte,
    U16Index,
    js_string_u16ix,
    u16ix_unit_to_byte,
    u16ix_byte_to_unit
}
import from engine.src.runtime.jsobject {
    KEY_LENGTH,
    js_object_create,
    js_object_create_null,
    js_object_get,
    js_object_set,
    js_object_define_property,
    js_object_all_keys,
    js_object_brand
}
import from engine.src.runtime.jsobj_type { JSProperty, BRAND_STRING_OBJ }
import from engine.src.builtins.array {
    _KEY_IS_ARRAY,
    _array_index_key_numeric,
    js_array_create
}
import from engine.src.runtime.error {
    make_uri_error,
    vm_throw_native,
    make_range_error,
    make_type_error,
    vm_has_native_exc
}
import from engine.src.runtime.dtoa { number_to_string_radix10 }
import from engine.src.vm.vm_obs {
    js_to_string_observable,
    js_to_number_observable,
    js_call_observable,
    js_call_bridge_ready
}
import from engine.src.runtime.spec_ops { spec_is_callable }
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.ffi.libicu {
    icu_normalize_str,
    icu_compare_str,
    icu_default_locale_str,
    icu_canonical_locale_str
}

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Property key constants (hidden String-object sentinel)
# ══════════════════════════════════════════════════════════════════════════════

"""
Hidden property key used to mark a JSObject as a String wrapper and store
the wrapped primitive value.  Chosen well above KEY_LENGTH (1) and
auto-intern IDs — guaranteed distinct by being stored outside the normal
intern-table range.
"""
# Negative: never collides with str_intern() (non-negative int keys from user strings).
# Must equal builtins.markers._KEY_IS_STRING_OBJ, the id jsobj_type maps to
# BRAND_STRING_OBJ (is_string_object tests that brand bit).
glob KEY_IS_STRING_OBJ: int = -20;
glob _STRING_PROTO: JSValue = js_undefined();
"""Record the realm's String.prototype.

ES §22.1.3: "The String prototype object is itself a String object whose
[[StringData]] is the empty String." Marking it here makes `String.prototype == ""`
hold and lets string methods invoked with `this === String.prototype` see an empty
string value rather than falling through to ToString and yielding "[object Object]"."""
def:pub js_string_set_proto(proto: JSValue) {
    _STRING_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
    js_object_set(proto, KEY_IS_STRING_OBJ, _mk_str(""));
}

"""The realm's String.prototype, or undefined before realm_bootstrap runs.

The VM resolves primitive-string property reads through this object rather than
synthesizing method objects per access, so `"".split === "".split` holds and
`String.prototype.split` is a real property."""
def:pub js_string_get_proto -> JSValue {
    return _STRING_PROTO;
}

# ══════════════════════════════════════════════════════════════════════════════
# 2.  Primitive helpers — JSValue ↔ Jac str
# ══════════════════════════════════════════════════════════════════════════════

"""Normalize the exponent in a float string to ECMAScript Number::toString form:
strip a single leading zero after `e+`/`e-` (Jac's `str(float)` emits `1e-07`, but
JS wants `1e-7`).  Two-or-more-digit exponents (`1e+21`, `1.5e-10`) are unchanged."""
def _js_num_normalize_exp(s: str) -> str {
    ei: int = -1;
    i: int = 0;
    sn: int = len(s);
    while i < sn {
        if s[i] == "e" or s[i] == "E" {
            ei = i;
            i = sn;
        } else {
            i = i + 1;
        }
    }
    if ei < 0 {
        return s;
    }
    # Split: mantissa `e` sign digits.  Sign is optional; JS always emits it.
    head: str = str_substr(s, 0, ei);  # up to but not including 'e'
    rest: str = str_substr(s, ei + 1, sn);  # after 'e'
    sign: str = "";
    di: int = 0;
    if len(rest) > 0 and (rest[0] == "+" or rest[0] == "-") {
        sign = str_substr(rest, 0, 1);
        di = 1;
    } else {
        sign = "+";
    }
    # Strip leading zeros from the exponent digits (keep at least one digit).
    while di < len(rest) - 1 and rest[di] == "0" {
        di = di + 1;
    }
    digits: str = str_substr(rest, di, len(rest));
    return head + "e" + sign + digits;
}

"""
Coerce any JSValue to a Jac str following ECMAScript §7.1.17 ToString.
Canonical coercion used by builtins, dispatch, and VM glue.
"""
def:pub js_coerce_to_string(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    if jsv_is_undefined(v) {
        return "undefined";
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
        f: float = jsv_to_double(v);
        return number_to_string_radix10(f);
    }
    if jsv_is_bigint_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    if jsv_is_object_cell(v) {
        return "[object Object]";
    }
    return "";
}

"""
Coerce any JSValue to a Jac str following ECMAScript §7.1.17 ToString.
This is the coercion used internally throughout this module for argument values.

Objects go through observable ToString so a user-supplied `toString`/`valueOf` is
actually invoked, and so a conversion that yields no primitive (e.g. a `toString`
returning a RegExp object) throws a TypeError instead of silently producing
"[object Object]".
"""
def:pub js_to_string_prim(v: JSValue) -> str {
    if jsv_is_object_cell(v) {
        return js_to_string_observable(v);
    }
    # ToString(Symbol) throws a TypeError (§7.1.17) — a Symbol never coerces to a
    # string implicitly (String(sym) is a separate explicit path handled elsewhere).
    if jsv_is_symbol(v) {
        vm_throw_native(make_type_error("Cannot convert a Symbol value to a string"));
        return "";
    }
    return js_coerce_to_string(v);
}

"""Wrap a computed String.prototype RESULT as a JSValue{tag=String} primitive.

G1.5: results of slice/substring/substr/pad/repeat/concat/case/trim/normalize/
split/replace etc. are transient computed VALUES that are numerous and never
reused as keys — route them to the collectible heap (str_heap) instead of the
immortal intern table. `str_heap("")` returns the canonical empty id 6, so the
many `_mk_str("")` early-returns are unaffected. Single-char results
(charAt/at/fromCharCode) use `_mk_char` (interned) — a bounded, deduped set."""
def _mk_str(s: str) -> JSValue {
    return jsv_from_string_id(str_heap(s));
}

"""_mk_str for a slice of a byte-clean string (ASCII, no NUL sentinel): the
result is byte-clean too, so its flag is set without scanning it."""
def _mk_str_ascii(s: str) -> JSValue {
    return jsv_from_string_id(str_heap_ascii(s));
}

"""Wrap a single-CHARACTER result. Kept interned: the char set is tiny and
bounded, so dedup beats per-occurrence heap allocation (esp. without --gc)."""
def _mk_char(s: str) -> JSValue {
    return jsv_from_string_id(str_intern(s));
}

"""Return the raw Jac str from any JSValue (same as js_to_string_prim)."""
def _raw(v: JSValue) -> str {
    return js_to_string_prim(v);
}

"""
ToIntegerOrInfinity(v) — ECMAScript §7.1.5, as a Jac float.

Runs observable ToNumber (so a `{valueOf}`/`{toString}` argument is invoked and a
Symbol/BigInt argument throws a TypeError), then: NaN → 0, ±∞ preserved, otherwise
truncate toward zero. Callers that need a bounded index should read the result and
clamp; ±∞ stays as a large magnitude that clamps naturally against the length.

If the ToNumber step throws, a native exception is pending; the returned value is
irrelevant because the VM discards the builtin's result and propagates the throw.
"""
def _to_int_or_inf(v: JSValue) -> float {
    if jsv_is_undefined(v) {
        return 0.0;
    }
    # The common case (`charCodeAt(i)`, `slice(a, b)`): already an integer.
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    num: float = js_to_number_observable(v);
    if num != num {
        return 0.0;
    }  # NaN → 0
    # ±∞ pass through unchanged; int() must not be applied to a non-finite float.
    if num >= 1.7976931348623157e+308 {
        return num;
    }
    if num <= -1.7976931348623157e+308 {
        return num;
    }
    if num > 0.0 {
        return float(int(num));
    }
    if num < 0.0 {
        return float(int(num));
    }
    return 0.0;  # +0 / -0
}

"""
ToUint32(v) — ECMAScript §7.1.6, via observable ToNumber (valueOf/toString run,
Symbol/BigInt throw). NaN/±0/±∞ → 0; otherwise truncate toward zero and reduce
modulo 2^32 into [0, 2^32).
"""
def _to_uint32(v: JSValue) -> int {
    num: float = js_to_number_observable(v);
    if num != num {
        return 0;
    }  # NaN
    if num >= 1.7976931348623157e+308 {
        return 0;
    }  # +∞
    if num <= -1.7976931348623157e+308 {
        return 0;
    }  # -∞
    t: int = int(num);  # truncate toward zero
    m: int = t % 4294967296;
    if m < 0 {
        m = m + 4294967296;
    }
    return m;
}

"""
Clamp a ToIntegerOrInfinity result to a valid [0, length] string index.
Negative → 0; anything ≥ length (incl. +∞) → length.
"""
def _clamp_index(n: float, length: int) -> int {
    if n != n {
        return 0;
    }
    if n <= 0.0 {
        return 0;
    }
    if n >= float(length) {
        return length;
    }
    return int(n);
}

# ══════════════════════════════════════════════════════════════════════════════
# 3.  String constructor — String(v) and new String(v)
# ══════════════════════════════════════════════════════════════════════════════

"""
`String(v)` — ECMAScript §22.1.1.1
Called as a function: coerce `v` to a String primitive.
Called as a constructor (`new String(v)`): return a String wrapper object.

The `new_target` flag distinguishes the two cases in the VM; here we provide
both entry points as separate functions:

  js_String_call  → String(v) primitive
  js_String_new   → new String(v) wrapper object
"""
def:pub js_String_call(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return _mk_str("");
    }
    return _mk_str(js_to_string_prim(args[0]));
}

"""Create a String *object* wrapper (new String(v))."""
def:pub js_String_new(args: list[JSValue]) -> JSValue {
    prim: JSValue = js_String_call(args);
    wrapper: JSValue;
    if jsv_is_undefined(_STRING_PROTO) {
        wrapper = js_object_create_null();
    } else {
        wrapper = js_object_create(_STRING_PROTO);
    }
    # Store the wrapped primitive on the hidden _IS_STRING_OBJ property
    js_object_set(wrapper, KEY_IS_STRING_OBJ, prim);
    # Set .length property — ECMAScript counts UTF-16 code units, not code points
    s: str = str_from_id(jsv_to_table_id(prim));
    js_object_define_property(
        wrapper,
        KEY_LENGTH,
        JSProperty(
            key=KEY_LENGTH,
            value=js_int(js_string_utf16_len(s)),
            writable=False,
            enumerable=False,
            configurable=False,
            deleted=False
        )
    );
    return wrapper;
}

"""
Test whether a JSValue is a String *object* wrapper (not a primitive).
Used by autobox-aware prototype methods.

Only an OWN [[StringData]] marker counts (ES §22.1: String objects are the
wrappers, String.prototype, and String-subclass instances, all of which carry
it own). The marker is mirrored in the object's brand, so the common "not a
String object" answer costs a field read. It used to be js_object_get, which
walks the prototype chain: every property read paid that walk, and any object
inheriting from a String object (Object.create(String.prototype)) passed.
"""
def:pub is_string_object(v: JSValue) -> bool {
    if (js_object_brand(v) & BRAND_STRING_OBJ) == 0 {
        return False;
    }
    inner: JSValue = js_object_get(v, KEY_IS_STRING_OBJ);
    return jsv_is_string_cell(inner);
}

"""
Extract the String primitive from a String primitive or String wrapper object.

Any other coercible receiver falls back to ToString (ES §22.1.3 step 2: `Let S be
? ToString(O)`), so `String.prototype.slice.call(12345, 1, 3)` yields "23" rather
than "". The non-coercible receivers — null, undefined, Symbol — are rejected by
`_str_this_not_coercible` at the dispatch boundary before reaching here.
"""
def:pub string_value_of(v: JSValue) -> JSValue {
    if jsv_is_string_cell(v) {
        return v;
    }
    if is_string_object(v) {
        return js_object_get(v, KEY_IS_STRING_OBJ);
    }
    # Any other object goes through observable ToString, which runs the receiver's
    # own toString/valueOf (so `new Object(1100.007)` yields "1100.007", not
    # "[object Object]") and throws if neither returns a primitive.
    if jsv_is_object_cell(v) {
        return _mk_str(js_to_string_observable(v));
    }
    return _mk_str(js_coerce_to_string(v));
}

"""Bounds-checked UTF-16 code-unit lookup; undefined if idx is out of range."""
def:pub js_string_index_value(s: str, idx: int) -> JSValue {
    if idx < 0 {
        return js_undefined();
    }
    units: list[int] = js_string_utf16_units(s);
    if idx >= len(units) {
        return js_undefined();
    }
    return _mk_char(js_string_from_utf16_code_units([units[idx]]));
}

"""True if `key` is an own String-exotic index of the wrapper value."""
def:pub js_string_exotic_has_index(v: JSValue, key: int) -> bool {
    if not is_string_object(v) {
        return False;
    }
    idx: int = _array_index_key_numeric(key);
    if idx < 0 {
        return False;
    }
    s: str = str_from_id(jsv_to_table_id(string_value_of(v)));
    return idx < js_string_utf16_len(s);
}

"""Own String-exotic [[Get]] for an index key; undefined if not an own index."""
def:pub js_string_exotic_get_index(v: JSValue, key: int) -> JSValue {
    if not js_string_exotic_has_index(v, key) {
        return js_undefined();
    }
    idx: int = _array_index_key_numeric(key);
    s: str = str_from_id(jsv_to_table_id(string_value_of(v)));
    return js_string_index_value(s, idx);
}

"""String exotic [[OwnPropertyKeys]] — virtual code-unit indices then ordinary own keys."""
def:pub js_string_own_key_ids(v: JSValue) -> list[int] {
    out: list[int] = [];
    if not is_string_object(v) {
        return out;
    }
    s: str = str_from_id(jsv_to_table_id(string_value_of(v)));
    n: int = js_string_utf16_len(s);
    i: int = 0;
    while i < n {
        out.append(str_intern_index(i));
        i = i + 1;
    }
    for key in js_object_all_keys(v) {
        if key < 0 {
            continue;
        }
        if _array_index_key_numeric(key) >= 0 and _array_index_key_numeric(key) < n {
            continue;
        }
        out.append(key);
    }
    return out;
}

# ══════════════════════════════════════════════════════════════════════════════
# 4.  Auto-boxing — ECMAScript §7.3.3 ToObject for String
# ══════════════════════════════════════════════════════════════════════════════

"""
When a method is called on a String primitive the spec requires wrapping it
in a temporary String object (ToObject step). Returns a wrapper object with
the same semantics as js_String_new but ephemeral in the call. Callers
should use the returned JSValue only for the duration of the method call.
ECMAScript §7.3.3
"""
def:pub js_string_autobox(v: JSValue) -> JSValue {
    return js_String_new([v]);
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  String static methods
# ══════════════════════════════════════════════════════════════════════════════

"""
String.fromCharCode(...codeUnits) — ECMAScript §22.1.2.1
Each argument is a UTF-16 code unit (0–65535); returns the concatenated
string.  Example: String.fromCharCode(65, 66) → "AB".
"""
def:pub js_String_fromCharCode(args: list[JSValue]) -> JSValue {
    units_fcc: list[int] = [];
    i: int = 0;
    while i < len(args) {
        # §7.1.5 / §7.1.10 ToUint16 via observable ToNumber (valueOf/toString;
        # BigInt/Symbol throw and must propagate).
        num: float = js_to_number_observable(args[i]);
        if vm_has_native_exc() {
            return js_undefined();
        }
        code: int = 0;
        if num == num
            and num < 1.7976931348623157e+308
            and num > -1.7976931348623157e+308 {
            code = int(num);
        }
        cu: int = code % 65536;
        if cu < 0 {
            cu = cu + 65536;
        }
        units_fcc.append(cu);
        i = i + 1;
    }
    return _mk_str(js_string_from_utf16_code_units(units_fcc));
}

"""
String.fromCodePoint(...codePoints) — ECMAScript §22.1.2.2
Like fromCharCode but accepts full Unicode code points (above U+FFFF).
"""
def:pub js_String_fromCodePoint(args: list[JSValue]) -> JSValue {
    result: str = "";
    i: int = 0;
    while i < len(args) {
        a: JSValue = args[i];
        # NaN is always invalid for fromCodePoint (spec §22.1.2.2 step 5.b)
        if jsv_is_nan(a) {
            vm_throw_native(make_range_error("Invalid code point NaN"));
            return js_undefined();
        }
        code: int = 0;
        if jsv_is_int32(a) {
            code = jsv_to_int32(a);
        } elif jsv_is_double(a) {
            d: float = jsv_to_double(a);
            # Out-of-range (includes ±Infinity) → RangeError
            if d < 0.0 or d > 1114111.0 {
                vm_throw_native(make_range_error("Invalid code point"));
                return js_undefined();
            }
            code = int(d);
            # Non-integer → RangeError (e.g. 3.14)
            if float(code) != d {
                vm_throw_native(make_range_error("Invalid code point"));
                return js_undefined();
            }
        }
        if code < 0 or code > 1114111 {
            vm_throw_native(make_range_error("Invalid code point"));
            return js_undefined();
        }
        # Astral scalar → encode as CESU-8 surrogate pair so result matches
        # the JS literal \uHigh\uLow (which _unescape_string encodes the same way).
        if code >= 65536 {
            u: int = code - 65536;
            hi: int = 55296 + (u >> 10);
            lo: int = 56320 + (u & 1023);
            result = result + utf8_encode_scalar(hi) + utf8_encode_scalar(lo);
        } else {
            result = result + utf8_encode_scalar(code);
        }
        i = i + 1;
    }
    return _mk_str(result);
}

"""
String.raw(template, ...substitutions) — ECMAScript §22.1.2.4
Template tag that returns raw strings without processing escape sequences.
The first argument must be a template-info object with a .raw property.
"""
def:pub js_String_raw(template: JSValue, subs: list[JSValue]) -> JSValue {
    raw_key: int = str_intern("raw");
    raw_arr: JSValue = js_object_get(template, raw_key);
    if not jsv_is_object_cell(raw_arr) {
        return _mk_str("");
    }
    len_v: JSValue = js_object_get(raw_arr, KEY_LENGTH);
    count: int = 0;
    if jsv_is_int32(len_v) {
        count = jsv_to_int32(len_v);
    }
    result: str = "";
    k: int = 0;
    while k < count {
        seg_key: int = str_intern_index(k);
        seg: JSValue = js_object_get(raw_arr, seg_key);
        result = result + js_to_string_prim(seg);
        if k < len(subs) {
            result = result + js_to_string_prim(subs[k]);
        }
        k = k + 1;
    }
    return _mk_str(result);
}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  String.prototype — length
# ══════════════════════════════════════════════════════════════════════════════

"""
String.prototype.length — ECMAScript §22.1.3
Returns the number of UTF-16 code units (characters) in the string.
"""
def:pub js_str_length(v: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    return js_int(js_string_utf16_len(s));
}

# ══════════════════════════════════════════════════════════════════════════════
# 7.  String.prototype — character access
# ══════════════════════════════════════════════════════════════════════════════

"""Resolve the string-VALUE cell of a receiver to its table id (for the cached
ASCII fast path in char*At). A direct string primitive gives its id; a String
wrapper object unwraps to its primitive. Returns -1 when neither, so the caller
falls back to the plain-str path."""
def _str_value_cell_id(v: JSValue) -> int {
    if jsv_is_string_cell(v) {
        return jsv_to_table_id(v);
    }
    inner_scid: JSValue = string_value_of(v);
    if jsv_is_string_cell(inner_scid) {
        return jsv_to_table_id(inner_scid);
    }
    return -1;
}

"""charAt(pos) — ECMAScript §22.1.3.1"""
def:pub js_str_charAt(v: JSValue, pos: JSValue) -> JSValue {
    # ToString(this) precedes ToIntegerOrInfinity(pos); read cell id first so the
    # value's own toString runs, then coerce the position (may invoke valueOf/throw).
    cid_ca: int = _str_value_cell_id(v);
    posf: float = _to_int_or_inf(pos);
    # A ±∞ or out-of-int32-range position is simply out of bounds → "".
    if posf < 0.0 or posf >= 2147483647.0 {
        return _mk_str("");
    }
    n: int = int(posf);
    # O(1) at ASCII positions via the cell's cached ASCII flag (see the note on
    # js_string_unit_at_cell) — this is what makes charAt-in-a-loop O(n).
    unit_ca: int = js_string_unit_at_cell(cid_ca, n)
        if cid_ca >= 0
        else js_string_utf16_unit_at(_raw(string_value_of(v)), n);
    if unit_ca < 0 {
        return _mk_str("");
    }
    return _mk_char(js_string_unit_str(unit_ca));
}

"""charCodeAt(pos) — ECMAScript §22.1.3.2"""
def:pub js_str_charCodeAt(v: JSValue, pos: JSValue) -> JSValue {
    cid_cc: int = _str_value_cell_id(v);
    posf: float = _to_int_or_inf(pos);
    if posf < 0.0 or posf >= 2147483647.0 {
        return js_nan();
    }
    n: int = int(posf);
    unit_cc: int = js_string_unit_at_cell(cid_cc, n)
        if cid_cc >= 0
        else js_string_utf16_unit_at(_raw(string_value_of(v)), n);
    if unit_cc < 0 {
        return js_nan();
    }
    return js_int(unit_cc);
}

"""codePointAt(pos) — ECMAScript §22.1.3.3"""
def:pub js_str_codePointAt(v: JSValue, pos: JSValue) -> JSValue {
    cid_cp: int = _str_value_cell_id(v);
    posf: float = _to_int_or_inf(pos);
    if posf < 0.0 or posf >= 2147483647.0 {
        return js_undefined();
    }
    n: int = int(posf);
    use_cell: bool = cid_cp >= 0;
    s_cp: str = "" if use_cell else _raw(string_value_of(v));
    hi: int = js_string_unit_at_cell(cid_cp, n)
        if use_cell
        else js_string_utf16_unit_at(s_cp, n);
    if hi < 0 {
        return js_undefined();
    }
    # If hi is a high surrogate and next unit is a low surrogate, combine them.
    if hi >= 55296 and hi <= 56319 {
        lo: int = js_string_unit_at_cell(cid_cp, n + 1)
            if use_cell
            else js_string_utf16_unit_at(s_cp, n + 1);
        if lo >= 56320 and lo <= 57343 {
            return js_int(65536 + ((hi - 55296) << 10) + (lo - 56320));
        }
    }
    return js_int(hi);
}

"""at(index) — ECMAScript §22.1.3, proposal-relative-indexing"""
def:pub js_str_at(v: JSValue, idx: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    units_at: list[int] = js_string_utf16_units(s);
    slen: int = len(units_at);
    rel: float = _to_int_or_inf(idx);
    # Relative index: negative counts from the end. ±∞ never lands in-bounds.
    k: float = rel;
    if rel < 0.0 {
        k = float(slen) + rel;
    }
    if k < 0.0 or k >= float(slen) {
        return js_undefined();
    }
    return _mk_char(js_string_from_utf16_code_units([units_at[int(k)]]));
}

# ══════════════════════════════════════════════════════════════════════════════
# 8.  String.prototype — search
# ══════════════════════════════════════════════════════════════════════════════

"""indexOf(searchString, position) — ECMAScript §22.1.3.8"""
def:pub js_str_indexOf(v: JSValue, needle: JSValue, from_v: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    # Spec order: ToString(searchString) before ToIntegerOrInfinity(position).
    n: str = js_to_string_prim(needle);
    # A Symbol searchString (bare or via @@toPrimitive/valueOf/toString) throws in
    # ToString; propagate instead of searching for the empty string.
    if vm_has_native_exc() {
        return js_undefined();
    }
    # Positions are UTF-16 code units. For a "byte-clean" string (no multi-byte
    # UTF-8, no \x00 sentinel) byte offset == unit offset, so the fast byte path
    # is exact; otherwise translate unit<->byte around the native byte search so
    # the returned index matches .length/charCodeAt/slice (see
    # js_string_byte_to_unit). A raw indexOf byte offset broke rollup render on
    # \0-prefixed virtual ids (positions ran +3 per embedded NUL).
    byte_len: int = len(s);
    if _byte_clean(v, s) {
        # Byte-clean: unit offset == byte offset. Native start-offset search, NO
        # tail copy (the old `str_substr(s, from, len)` + find copied the whole
        # tail per call: 300KB and 1.7ms per `indexOf(";", pos)` on a 650KB
        # sourcemap `mappings` string — rollup's render phase called it once per
        # line and the copies were retained → the 12GB OOM).
        from_clean: int = _clamp_index(_to_int_or_inf(from_v), byte_len);
        if len(n) == 0 {
            return js_int(from_clean);
        }
        pos_c: int = s.find(n, from_clean);
        if pos_c == -1 {
            return js_int(-1);
        }
        return js_int(pos_c);
    }
    # Non-ASCII string cell: convert positions through its cached checkpoint
    # index and search in place — no whole-string decode or tail copy per call.
    if jsv_is_string_cell(v) {
        ix_io: U16Index = js_string_u16ix(jsv_to_table_id(v), s);
        if ix_io.regular {
            from_ix: int = _clamp_index(_to_int_or_inf(from_v), ix_io.total);
            if len(n) == 0 {
                return js_int(from_ix);
            }
            fb_ix: int = u16ix_unit_to_byte(ix_io, s, from_ix);
            # Inside a surrogate pair: the next match can only start after it.
            if fb_ix < 0 {
                fb_ix = u16ix_unit_to_byte(ix_io, s, from_ix + 1);
            }
            pos_ix: int = s.find(n, fb_ix);
            if pos_ix == -1 {
                return js_int(-1);
            }
            return js_int(u16ix_byte_to_unit(ix_io, s, pos_ix));
        }
    }
    unit_len: int = js_string_utf16_len(s);
    from_unit: int = _clamp_index(_to_int_or_inf(from_v), unit_len);
    from_byte: int = js_string_unit_to_byte(s, from_unit);
    tail2: str = str_substr(s, from_byte, byte_len);
    bpos: int = tail2.find(n);
    if bpos == -1 {
        return js_int(-1);
    }
    return js_int(js_string_byte_to_unit(s, from_byte + bpos));
}

"""lastIndexOf(searchString, position) — ECMAScript §22.1.3.9"""
def:pub js_str_lastIndexOf(v: JSValue, needle: JSValue, pos_v: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    # Spec order: ToString(searchString) BEFORE ToNumber(position).
    n: str = js_to_string_prim(needle);
    if vm_has_native_exc() {
        return js_undefined();
    }
    slen: int = len(s);
    # numPos = ToNumber(position); NaN → +∞ (search the whole string). Otherwise
    # ToIntegerOrInfinity, clamped to [0, len]. Observable: valueOf runs / throws.
    start: int = slen;
    if not jsv_is_undefined(pos_v) {
        num: float = js_to_number_observable(pos_v);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if num == num {  # not NaN → clamp; NaN keeps start = slen
            if num < 0.0 {
                start = 0;
            } elif num >= float(slen) {
                start = slen;
            } else {
                start = int(num);
            }
        }
    }
    # Last occurrence with match start ≤ start. Positions are UTF-16 units; when
    # `s` is not byte-clean (multi-byte UTF-8 / \x00 sentinel) translate the byte
    # rfind result back to a unit index (see js_string_byte_to_unit).
    nlen: int = len(n);
    unit_len_l: int = js_string_utf16_len(s);
    if slen == unit_len_l {
        limit: int = start;
        if limit + nlen > slen {
            limit = slen - nlen;
        }
        pos: int = -1;
        if limit >= 0 {
            if limit + nlen >= slen {
                pos = s.rfind(n);  # whole string: no prefix copy
            } else {
                cand: str = str_substr(s, 0, limit + nlen);
                pos = cand.rfind(n);
            }
        }
        return js_int(pos);
    }
    # `start` above was clamped against the byte length; recompute in units then
    # map to bytes for the search window.
    start_unit_l: int = start;
    if start_unit_l > unit_len_l {
        start_unit_l = unit_len_l;
    }
    start_byte_l: int = js_string_unit_to_byte(s, start_unit_l);
    hi_byte_l: int = start_byte_l + nlen;
    if hi_byte_l > slen {
        hi_byte_l = slen;
    }
    bpos_l: int = -1;
    if hi_byte_l >= nlen {
        cand2: str = str_substr(s, 0, hi_byte_l);
        bpos_l = cand2.rfind(n);
    }
    if bpos_l == -1 {
        return js_int(-1);
    }
    return js_int(js_string_byte_to_unit(s, bpos_l));
}

"""
includes(searchString [, position]) — ECMAScript §22.1.3.7
`position` is where the search begins (default 0, clamped to 0..len). The
IsRegExp TypeError guard runs in the dispatch wrapper before this is called.
"""
def:pub js_str_includes(v: JSValue, needle: JSValue, pos_v: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    # Spec order: ToString(searchString) before ToIntegerOrInfinity(position).
    n: str = js_to_string_prim(needle);
    # `position` is a UTF-16 unit index; map to a byte offset for the search
    # window when `s` is not byte-clean (multi-byte UTF-8 / \x00 sentinel).
    byte_len_i: int = len(s);
    if _byte_clean(v, s) {
        # No tail copy / no rescan for byte-clean cells (see js_str_indexOf).
        st_c: int = _clamp_index(_to_int_or_inf(pos_v), byte_len_i);
        if len(n) == 0 {
            return js_true();
        }
        if s.find(n, st_c) != -1 {
            return js_true();
        } else {
            return js_false();
        }
    }
    unit_len_i: int = js_string_utf16_len(s);
    st_unit: int = _clamp_index(_to_int_or_inf(pos_v), unit_len_i);
    st: int = st_unit;
    if byte_len_i != unit_len_i {
        st = js_string_unit_to_byte(s, st_unit);
    }
    tail: str = str_substr(s, st, byte_len_i);
    if n in tail {
        return js_true();
    } else {
        return js_false();
    }
}

"""
startsWith(searchString [, position]) — ECMAScript §22.1.3.20
`position` selects the index in the string where the match is attempted
(default 0, clamped to 0..len).
"""
def:pub js_str_startsWith(v: JSValue, prefix: JSValue, pos_v: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    p: str = js_to_string_prim(prefix);
    slen: int = len(s);
    st: int = _clamp_index(_to_int_or_inf(pos_v), slen);
    plen: int = len(p);
    if plen == 0 {
        return js_true();
    }
    if st + plen > slen {
        return js_false();
    }
    sub: str = str_substr(s, st, st + plen);
    if sub == p {
        return js_true();
    } else {
        return js_false();
    }
}

"""
endsWith(searchString [, endPosition]) — ECMAScript §22.1.3.6
`endPosition` is the end index (exclusive) of the string prefix considered
for the check (default len); clamped to 0..len.
"""
def:pub js_str_endsWith(v: JSValue, suffix: JSValue, endpos_v: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    p: str = js_to_string_prim(suffix);
    slen: int = len(s);
    en: int = slen;
    if not jsv_is_undefined(endpos_v) {
        en = _clamp_index(_to_int_or_inf(endpos_v), slen);
    }
    plen2: int = len(p);
    if plen2 == 0 {
        return js_true();
    }
    if plen2 > en {
        return js_false();
    }
    if en == slen {
        # Whole-string suffix test: no prefix copy (was str_substr(s, 0, len)).
        if s.endswith(p) {
            return js_true();
        } else {
            return js_false();
        }
    }
    sub2: str = str_substr(s, en - plen2, en);  # copy only the compared window
    if sub2 == p {
        return js_true();
    } else {
        return js_false();
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 9.  String.prototype — extraction
# ══════════════════════════════════════════════════════════════════════════════

"""Map a ToIntegerOrInfinity result to a relative slice index in [0, length]."""
def _rel_index(n: float, length: int) -> int {
    if n != n {
        return 0;
    }
    if n < 0.0 {
        m: float = float(length) + n;
        if m < 0.0 {
            return 0;
        }
        return int(m);
    }
    if n >= float(length) {
        return length;
    }
    return int(n);
}

"""Build a string from UTF-16 units[st..en) (bounds pre-clamped, st ≤ en)."""
def _units_substr(units: list[int], st: int, en: int) -> JSValue {
    kept: list[int] = [];
    i: int = st;
    while i < en {
        kept.append(units[i]);
        i = i + 1;
    }
    return _mk_str(js_string_from_utf16_code_units(kept));
}

"""True when `s` can be sliced BY BYTE OFFSET: pure ASCII (the NUL sentinel
C0 80 is not ASCII, so a string holding one never qualifies). For such strings
UTF-16 indices == byte indices, so slice/substring/substr need ONE str_substr instead of
decode-all-units → copy → re-encode (which was >1MB of allocation and
~330µs PER slice call — the vite transform OOM/stall)."""
def _byte_sliceable(s: str) -> bool {
    # isascii() is the native byte loop (the ord(s[i]) loop cost ~4x per byte).
    return s.isascii();
}

"""Byte-clean test that uses the string CELL's cached flag (computed once at
creation: 1 = pure ASCII without the NUL sentinel) instead of rescanning the
whole string on every slice/substring/indexOf — a 650KB module string was
scanned per call. Falls back to the scan for non-cell values (wrappers)."""
def _byte_clean(v: JSValue, s: str) -> bool {
    if jsv_is_string_cell(v) {
        bc_f: int = str_cell_ascii(jsv_to_table_id(v));
        if bc_f == 1 {
            return True;
        }
        if bc_f == 2 {
            return False;
        }
    }
    return _byte_sliceable(s);
}

"""The string cell id of `v` when slice/substring can work on it without reading
its text: a byte-clean (ASCII) string cell of at least LAZY_SLICE_MIN bytes,
where a UTF-16 index is a byte index. -1 otherwise."""
def _lazy_slice_src(v: JSValue) -> int {
    if not jsv_is_string_cell(v) {
        return -1;
    }
    ls_id: int = jsv_to_table_id(v);
    if str_cell_ascii(ls_id) != 1 {
        return -1;
    }
    if str_cell_len(ls_id) < LAZY_SLICE_MIN {
        return -1;
    }
    return ls_id;
}

"""Bytes [st, en) of byte-clean string cell `id` (0 <= st < en <= its length):
the cell itself for the whole range, a lazy slice cell when long (no copy, see
str_slice_cell), else a copy read through to the slice's parent."""
def _lazy_slice(v: JSValue, id: int, st: int, en: int) -> JSValue {
    if st == 0 and en == str_cell_len(id) {
        return v;
    }
    if en - st >= LAZY_SLICE_MIN {
        return jsv_from_string_id(str_slice_cell(id, st, en - st, 1));
    }
    return _mk_str_ascii(str_substr_cell(id, st, en));
}

"""slice(start, end) — ECMAScript §22.1.3.19"""
def:pub js_str_slice(v: JSValue, start: JSValue, end_v: JSValue) -> JSValue {
    # Long byte-clean string: cut by offsets without reading its text (a lazy
    # slice stays unread). Same ToIntegerOrInfinity order as below.
    lz_id: int = _lazy_slice_src(v);
    if lz_id >= 0 {
        lz_len: int = str_cell_len(lz_id);
        lz_st: int = _rel_index(_to_int_or_inf(start), lz_len);
        if vm_has_native_exc() {
            return js_undefined();
        }
        lz_en: int = lz_len;
        if not jsv_is_undefined(end_v) {
            lz_en = _rel_index(_to_int_or_inf(end_v), lz_len);
            if vm_has_native_exc() {
                return js_undefined();
            }
        }
        if lz_st >= lz_en {
            return _mk_str("");
        }
        return _lazy_slice(v, lz_id, lz_st, lz_en);
    }
    s: str = _raw(string_value_of(v));
    if vm_has_native_exc() {
        return js_undefined();
    }
    # ASCII fast path: UTF-16 index == byte index → one str_substr, no decode.
    if _byte_clean(v, s) {
        slen_b: int = len(s);
        st_b: int = _rel_index(_to_int_or_inf(start), slen_b);
        if vm_has_native_exc() {
            return js_undefined();
        }
        en_b: int = slen_b;
        if not jsv_is_undefined(end_v) {
            en_b = _rel_index(_to_int_or_inf(end_v), slen_b);
            if vm_has_native_exc() {
                return js_undefined();
            }
        }
        if st_b >= en_b {
            return _mk_str("");
        }
        # INLINE the substr: a named `str` local holding an owned call result
        # is never released by the native compiler (scope-exit release is not
        # emitted), so `sl: str = str_substr(...); return _mk_str(sl)` leaked
        # every slice result (~845B/call; MagicString slices per chunk → the
        # vite render-phase OOM). An inline call-result temp IS released.
        return _mk_str_ascii(str_substr(s, st_b, en_b));
    }
    # Non-ASCII string cell: map the bounds to byte offsets through its cached
    # checkpoint index and cut the UTF-8 bytes — no whole-string decode per call.
    if jsv_is_string_cell(v) {
        ix_sl: U16Index = js_string_u16ix(jsv_to_table_id(v), s);
        if ix_sl.regular {
            st_x: int = _rel_index(_to_int_or_inf(start), ix_sl.total);
            if vm_has_native_exc() {
                return js_undefined();
            }
            en_x: int = ix_sl.total;
            if not jsv_is_undefined(end_v) {
                en_x = _rel_index(_to_int_or_inf(end_v), ix_sl.total);
                if vm_has_native_exc() {
                    return js_undefined();
                }
            }
            if st_x >= en_x {
                return _mk_str("");
            }
            b0_x: int = u16ix_unit_to_byte(ix_sl, s, st_x);
            b1_x: int = u16ix_unit_to_byte(ix_sl, s, en_x);
            if b0_x >= 0 and b1_x >= 0 {
                return _mk_str(str_substr(s, b0_x, b1_x));
            }
            # A bound splits a surrogate pair: cut the code units instead.
            return _units_substr(js_string_utf16_units(s), st_x, en_x);
        }
    }
    units_sl: list[int] = js_string_utf16_units(s);
    slen: int = len(units_sl);  # length in UTF-16 code units, not bytes
    # ToIntegerOrInfinity(start) then ToIntegerOrInfinity(end), in that order.
    st: int = _rel_index(_to_int_or_inf(start), slen);
    if vm_has_native_exc() {
        return js_undefined();
    }
    en: int = slen;
    if not jsv_is_undefined(end_v) {
        en = _rel_index(_to_int_or_inf(end_v), slen);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if st >= en {
        return _mk_str("");
    }
    return _units_substr(units_sl, st, en);
}

"""substring(start, end) — ECMAScript §22.1.3.22"""
def:pub js_str_substring(v: JSValue, start: JSValue, end_v: JSValue) -> JSValue {
    # Long byte-clean string: see js_str_slice.
    lz_id: int = _lazy_slice_src(v);
    if lz_id >= 0 {
        lz_len: int = str_cell_len(lz_id);
        lz_st: int = _clamp_index(_to_int_or_inf(start), lz_len);
        if vm_has_native_exc() {
            return js_undefined();
        }
        lz_en: int = lz_len;
        if not jsv_is_undefined(end_v) {
            lz_en = _clamp_index(_to_int_or_inf(end_v), lz_len);
            if vm_has_native_exc() {
                return js_undefined();
            }
        }
        if lz_st > lz_en {
            lz_t: int = lz_st;
            lz_st = lz_en;
            lz_en = lz_t;
        }
        if lz_st >= lz_en {
            return _mk_str("");
        }
        return _lazy_slice(v, lz_id, lz_st, lz_en);
    }
    s: str = _raw(string_value_of(v));
    if vm_has_native_exc() {
        return js_undefined();
    }
    # ASCII fast path — see js_str_slice.
    if _byte_clean(v, s) {
        slen_c: int = len(s);
        st_c: int = _clamp_index(_to_int_or_inf(start), slen_c);
        if vm_has_native_exc() {
            return js_undefined();
        }
        en_c: int = slen_c;
        if not jsv_is_undefined(end_v) {
            en_c = _clamp_index(_to_int_or_inf(end_v), slen_c);
            if vm_has_native_exc() {
                return js_undefined();
            }
        }
        if st_c > en_c {
            tmp_c: int = st_c;
            st_c = en_c;
            en_c = tmp_c;
        }
        if st_c >= en_c {
            return _mk_str("");
        }
        return _mk_str_ascii(str_substr(s, st_c, en_c));  # inline: see js_str_slice
    }
    # Non-ASCII string cell: as in js_str_slice.
    if jsv_is_string_cell(v) {
        ix_su: U16Index = js_string_u16ix(jsv_to_table_id(v), s);
        if ix_su.regular {
            st_y: int = _clamp_index(_to_int_or_inf(start), ix_su.total);
            if vm_has_native_exc() {
                return js_undefined();
            }
            en_y: int = ix_su.total;
            if not jsv_is_undefined(end_v) {
                en_y = _clamp_index(_to_int_or_inf(end_v), ix_su.total);
                if vm_has_native_exc() {
                    return js_undefined();
                }
            }
            if st_y > en_y {
                tmp_y: int = st_y;
                st_y = en_y;
                en_y = tmp_y;
            }
            if st_y >= en_y {
                return _mk_str("");
            }
            b0_y: int = u16ix_unit_to_byte(ix_su, s, st_y);
            b1_y: int = u16ix_unit_to_byte(ix_su, s, en_y);
            if b0_y >= 0 and b1_y >= 0 {
                return _mk_str(str_substr(s, b0_y, b1_y));
            }
            return _units_substr(js_string_utf16_units(s), st_y, en_y);
        }
    }
    units_su: list[int] = js_string_utf16_units(s);
    slen: int = len(units_su);
    st: int = _clamp_index(_to_int_or_inf(start), slen);
    if vm_has_native_exc() {
        return js_undefined();
    }
    en: int = slen;
    if not jsv_is_undefined(end_v) {
        en = _clamp_index(_to_int_or_inf(end_v), slen);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if st > en {
        tmp: int = st;
        st = en;
        en = tmp;
    }
    return _units_substr(units_su, st, en);
}

"""ToNumber then ToInteger (truncate toward 0) for substr coercions — §7.1.4 / §7.1.5.
Uses observable ToNumber so a `{valueOf}` argument runs and a Symbol argument throws."""
def _substr_to_integer(v: JSValue) -> int {
    n: float = js_to_number_observable(v);
    if not (n == n) {
        return 0;
    }
    # Avoid int(non-finite): clamp to representable range; substr clamps length to remainder anyway.
    if n >= 1.7976931348623157e+308 {
        return 2147483647;
    }
    if n <= -1.7976931348623157e+308 {
        return -2147483648;
    }
    return int(n);
}

"""Legacy substr(start, length) — ECMA-262 B.2.2 (String.prototype.substr)"""
def:pub js_str_substr(v: JSValue, start: JSValue, len_v: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    if vm_has_native_exc() {
        return js_undefined();
    }
    units_ss: list[int] = js_string_utf16_units(s);
    slen: int = len(units_ss);  # UTF-16 code-unit length
    st: int = _substr_to_integer(start);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if st < 0 {
        st = slen + st;
        if st < 0 {
            st = 0;
        }
    } elif st > slen {
        st = slen;
    }
    rem: int = slen - st;
    rlen: int = rem;
    if not jsv_is_undefined(len_v) {
        rlen = _substr_to_integer(len_v);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if rlen < 0 {
        rlen = 0;
    }
    if rlen > rem {
        rlen = rem;
    }
    if rlen == 0 {
        return _mk_str("");
    }
    return _units_substr(units_ss, st, st + rlen);
}

# ══════════════════════════════════════════════════════════════════════════════
# 9b.  String.prototype — Annex B §B.2.3 HTML wrapper methods
# ══════════════════════════════════════════════════════════════════════════════

"""
CreateHTML(S, tag, attribute, value) — ECMAScript §B.2.3.2.1.

Wraps ToString(this) in `<tag>…</tag>`, optionally with an attribute whose value
has its `"` escaped to `&quot;`. `attr == ""` means no attribute (bold/italics/…).
The 13 legacy methods (bold/anchor/link/fontcolor/…) all funnel through here; the
dispatch layer supplies the constant tag/attribute and the caller's value arg.
"""
def:pub js_str_html(v: JSValue, tag: str, attr: str, valv: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    p1: str = "<" + tag;
    if attr != "" {
        vstr: str = js_to_string_prim(valv);
        vstr = vstr.replace("\"", "&quot;");
        p1 = p1 + " " + attr + "=\"" + vstr + "\"";
    }
    return _mk_str(p1 + ">" + s + "</" + tag + ">");
}

# ══════════════════════════════════════════════════════════════════════════════
# 9c.  String.prototype — well-formed Unicode
# ══════════════════════════════════════════════════════════════════════════════

"""
isWellFormed() — ECMAScript §22.1.3.11. True unless the string contains a lone
surrogate (an unpaired high or low UTF-16 code unit).
"""
def:pub js_str_isWellFormed(v: JSValue) -> JSValue {
    units_wf: list[int] = js_string_utf16_units(_raw(string_value_of(v)));
    n_wf: int = len(units_wf);
    i: int = 0;
    while i < n_wf {
        u: int = units_wf[i];
        if u >= 55296 and u <= 56319 {
            # High surrogate must be followed by a low surrogate.
            if i + 1 >= n_wf {
                return js_false();
            }
            lo: int = units_wf[i + 1];
            if lo < 56320 or lo > 57343 {
                return js_false();
            }
            i = i + 2;
        } elif u >= 56320 and u <= 57343 {
            return js_false();  # lone low surrogate
        } else {
            i = i + 1;
        }
    }
    return js_true();
}

"""
toWellFormed() — ECMAScript §22.1.3.36. Replaces each lone surrogate with
U+FFFD (REPLACEMENT CHARACTER); paired surrogates are preserved.
"""
def:pub js_str_toWellFormed(v: JSValue) -> JSValue {
    units_tw: list[int] = js_string_utf16_units(_raw(string_value_of(v)));
    n_tw: int = len(units_tw);
    out: list[int] = [];
    i: int = 0;
    while i < n_tw {
        u: int = units_tw[i];
        if u >= 55296 and u <= 56319 {
            if i + 1 < n_tw {
                lo: int = units_tw[i + 1];
                if lo >= 56320 and lo <= 57343 {
                    out.append(u);
                    out.append(lo);
                    i = i + 2;
                    continue;
                }
            }
            out.append(65533);  # lone high surrogate → U+FFFD
            i = i + 1;
        } elif u >= 56320 and u <= 57343 {
            out.append(65533);  # lone low surrogate → U+FFFD
            i = i + 1;
        } else {
            out.append(u);
            i = i + 1;
        }
    }
    return _mk_str(js_string_from_utf16_code_units(out));
}

# ══════════════════════════════════════════════════════════════════════════════
# 10.  String.prototype — case conversion
# ══════════════════════════════════════════════════════════════════════════════

"""toLowerCase() / toLocaleLowerCase() — ECMAScript §22.1.3.26"""
def:pub js_str_toLowerCase(v: JSValue) -> JSValue {
    return _mk_str(_raw(string_value_of(v)).lower());
}

"""toUpperCase() / toLocaleUpperCase() — ECMAScript §22.1.3.28"""
def:pub js_str_toUpperCase(v: JSValue) -> JSValue {
    return _mk_str(_raw(string_value_of(v)).upper());
}

# ══════════════════════════════════════════════════════════════════════════════
# 11.  String.prototype — trim
# ══════════════════════════════════════════════════════════════════════════════

"""
Trim JS whitespace/line-terminators from `s`. `left`/`right` select which
ends are trimmed. Operates on UTF-16 code units (spec §22.1.3.32.1 TrimString):
WhiteSpace (§12.2) ∪ LineTerminator (§12.3). Every member is in the BMP, so a
single UTF-16 unit fully identifies it — no surrogate handling needed.
"""
def _js_trim(s: str, left: bool, right: bool) -> str {
    units: list[int] = js_string_utf16_units(s);
    # Membership set for the trim characters (all BMP code units): value 1 == member.
    ws: dict[int, int] = {
        0x09: 1,
        0x0A: 1,
        0x0B: 1,
        0x0C: 1,
        0x0D: 1,
        0x20: 1,
        0xA0: 1,
        0x1680: 1,
        0x2000: 1,
        0x2001: 1,
        0x2002: 1,
        0x2003: 1,
        0x2004: 1,
        0x2005: 1,
        0x2006: 1,
        0x2007: 1,
        0x2008: 1,
        0x2009: 1,
        0x200A: 1,
        0x2028: 1,
        0x2029: 1,
        0x202F: 1,
        0x205F: 1,
        0x3000: 1,
        0xFEFF: 1
    };
    start: int = 0;
    end: int = len(units);
    if left {
        while start < end and (units[start] in ws) {
            start = start + 1;
        }
    }
    if right {
        while end > start and (units[end - 1] in ws) {
            end = end - 1;
        }
    }
    kept: list[int] = [];
    i: int = start;
    while i < end {
        kept.append(units[i]);
        i = i + 1;
    }
    return js_string_from_utf16_code_units(kept);
}

"""trim() — ECMAScript §22.1.3.30"""
def:pub js_str_trim(v: JSValue) -> JSValue {
    return _mk_str(_js_trim(_raw(string_value_of(v)), True, True));
}

"""trimStart() / trimLeft() — ECMAScript §22.1.3.31"""
def:pub js_str_trimStart(v: JSValue) -> JSValue {
    return _mk_str(_js_trim(_raw(string_value_of(v)), True, False));
}

"""trimEnd() / trimRight() — ECMAScript §22.1.3.32"""
def:pub js_str_trimEnd(v: JSValue) -> JSValue {
    return _mk_str(_js_trim(_raw(string_value_of(v)), False, True));
}

# ══════════════════════════════════════════════════════════════════════════════
# 12.  String.prototype — split
# ══════════════════════════════════════════════════════════════════════════════

"""
split(separator, limit) — ECMAScript §22.1.3.21
Returns a JSValue{tag=Object} array of string parts.
"""
def:pub js_str_split(v: JSValue, sep: JSValue, limit_v: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    # ToString(this) may have thrown — native code doesn't unwind, so bail before
    # coercing the limit (whose own ToNumber could overwrite the pending exception).
    if vm_has_native_exc() {
        return js_undefined();
    }
    # §22.1.3.21: ToUint32(limit) runs BEFORE ToString(separator) — a throwing
    # limit valueOf must fire before the separator is coerced.
    lim: int = 4294967295;
    if not jsv_is_undefined(limit_v) {
        lim = _to_uint32(limit_v);
    }
    if vm_has_native_exc() {
        return js_undefined();
    }

    parts: list[str] = [];
    if jsv_is_undefined(sep) {
        # §22.1.3.21: ToString(separator) is still performed for its side effects
        # before the lim==0 / undefined checks — but undefined has none, so skip.
        if lim == 0 {
            return js_array_create([]);
        }
        parts.append(s);
    } else {
        # ToString(separator) runs BEFORE the lim==0 short-circuit (a throwing
        # separator toString must fire even when limit is 0).
        sep_str: str = js_to_string_prim(sep);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if lim == 0 {
            return js_array_create([]);
        }
        if sep_str == "" {
            # split("") must expose UTF-16 code units (each surrogate half is a separate element).
            units_sp: list[int] = js_string_utf16_units(s);
            i: int = 0;
            while i < len(units_sp) and len(parts) < lim {
                parts.append(utf8_encode_scalar(units_sp[i]));
                i = i + 1;
            }
        } else {
            raw_parts: list[str] = s.split(sep_str);
            i: int = 0;
            while i < len(raw_parts) and len(parts) < lim {
                parts.append(raw_parts[i]);
                i = i + 1;
            }
        }
    }

    # Build a REAL array via js_array_create so its [[Prototype]] is Array.prototype
    # (a null-proto object with just the _KEY_IS_ARRAY marker has no `.join`/`.indexOf`
    # etc. — the methods are only reachable via Array.prototype).
    elems: list[JSValue] = [];
    i: int = 0;
    while i < len(parts) {
        elems.append(_mk_str(parts[i]));
        i = i + 1;
    }
    return js_array_create(elems);
}

# ══════════════════════════════════════════════════════════════════════════════
# 13.  String.prototype — replace / replaceAll
# ══════════════════════════════════════════════════════════════════════════════

"""
GetSubstitution for a string search (no capture groups) — ECMAScript §22.1.3.18.
Expands the replacement-text `$` patterns relative to a match of `matched` at
byte offset `position` in `s`:
  $$ → "$"   $& → matched   $` → s[0..position]   $' → s[position+len(matched)..]
`$n` / `$<name>` have no captures here, so they are emitted literally (spec: an
n with no corresponding capture is left as "$n").
"""
def _get_substitution_str(matched: str, s: str, position: int, repl: str) -> str {
    out: str = "";
    i: int = 0;
    nlen: int = len(repl);
    tail_start: int = position + len(matched);
    while i < nlen {
        c: str = repl[i];
        if c == "$" and i + 1 < nlen {
            nc: str = repl[i + 1];
            if nc == "$" {
                out = out + "$";
                i = i + 2;
                continue;
            }
            if nc == "&" {
                out = out + matched;
                i = i + 2;
                continue;
            }
            if nc == "`" {
                out = out + str_substr(s, 0, position);
                i = i + 2;
                continue;
            }
            if nc == "'" {
                out = out + str_substr(s, tail_start, len(s));
                i = i + 2;
                continue;
            }
        }
        out = out + c;
        i = i + 1;
    }
    return out;
}

"""
Compute the replacement text for one match. If `replacement` is callable,
Call(replacement, undefined, [matched, position, string]) and ToString the result
(§22.1.3.14 step 14). Otherwise expand the `$` patterns in `r` via GetSubstitution.
"""
def _replace_one(
    matched: str, s: str, position: int, replacement: JSValue, is_fn: bool, r: str
) -> str {
    if is_fn {
        pos_v: JSValue = js_int(position);
        res: JSValue = js_call_observable(
            replacement, js_undefined(), [_mk_str(matched), pos_v, _mk_str(s)]
        );
        if vm_has_native_exc() {
            return "";
        }
        return js_to_string_prim(res);
    }
    return _get_substitution_str(matched, s, position, r);
}

"""replace(searchValue, replaceValue) — ECMAScript §22.1.3.14 (string search, first match)."""
def:pub js_str_replace(v: JSValue, search: JSValue, replacement: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    if vm_has_native_exc() {
        return js_undefined();
    }
    n: str = js_to_string_prim(search);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # §22.1.3.14 step 6: ToString(replaceValue) (non-callable) runs BEFORE the
    # string is searched — its side effects fire even when the search fails.
    is_fn: bool = js_call_bridge_ready() and spec_is_callable(replacement);
    r: str = "";
    if not is_fn {
        r = js_to_string_prim(replacement);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    pos: int = s.find(n);
    if pos < 0 {
        return _mk_str(s);
    }
    nlen_r: int = len(n);
    # All pieces inline (named owned str locals leak — see js_str_slice).
    res_r: JSValue = _mk_str(
        str_substr(s, 0, pos)
            + _replace_one(
                str_substr(s, pos, pos + nlen_r), s, pos, replacement, is_fn, r
            )
            + str_substr(s, pos + nlen_r, len(s))
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return res_r;
}

"""replaceAll(searchValue, replaceValue) — ECMAScript §22.1.3.15 (string search, all matches)."""
def:pub js_str_replaceAll(
    v: JSValue, search: JSValue, replacement: JSValue
) -> JSValue {
    s: str = _raw(string_value_of(v));
    if vm_has_native_exc() {
        return js_undefined();
    }
    n: str = js_to_string_prim(search);
    if vm_has_native_exc() {
        return js_undefined();
    }
    is_fn: bool = js_call_bridge_ready() and spec_is_callable(replacement);
    r: str = "";
    if not is_fn {
        r = js_to_string_prim(replacement);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    # The builder lives in a helper that RETURNS its `out` (a returned named
    # local is released correctly; one kept in this frame would leak).
    res_ra: JSValue = _mk_str(_replace_all_build(s, n, replacement, is_fn, r));
    if vm_has_native_exc() {
        return js_undefined();
    }
    return res_ra;
}

def _replace_all_build(
    s: str, n: str, replacement: JSValue, is_fn: bool, r: str
) -> str {
    slen: int = len(s);
    nlen: int = len(n);
    out: str = "";
    pos: int = 0;
    while pos <= slen {
        # StringIndexOf: empty search matches at every position (incl. end).
        found: int = -1;
        if nlen == 0 {
            found = pos;
        } else {
            # Native offset search — no per-iteration tail copy (was
            # str_substr(s, pos, slen) + find: an O(n) copy per match).
            found = s.find(n, pos);
        }
        if found < 0 {
            break;
        }
        out = out + str_substr(s, pos, found);
        out = out + _replace_one(n, s, found, replacement, is_fn, r);
        if vm_has_native_exc() {
            return "";
        }
        if nlen == 0 {
            # advance one char past the empty match, emitting the skipped char
            if found < slen {
                out = out + s[found];
            }
            pos = found + 1;
        } else {
            pos = found + nlen;
        }
    }
    out = out + str_substr(s, pos, slen);
    return out;
}

# ══════════════════════════════════════════════════════════════════════════════
# 14.  String.prototype — pad
# ══════════════════════════════════════════════════════════════════════════════

"""
StringPad §22.1.3.15.1 shared core, operating on UTF-16 code units so an astral
fill string (e.g. "💩") pads by code unit and never splits a pair incorrectly.
`at_start` prepends the fill, else appends. Returns the padded string.
"""
def _str_pad(v: JSValue, target_v: JSValue, pad_v: JSValue, at_start: bool) -> JSValue {
    s: str = _raw(string_value_of(v));
    if vm_has_native_exc() {
        return js_undefined();
    }
    s_units: list[int] = js_string_utf16_units(s);
    slen_p: int = len(s_units);
    # ToLength(maxLength) → early-out if ≤ len → ToString(fillString).
    tf: float = _to_int_or_inf(target_v);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if tf < 0.0 {
        tf = 0.0;
    }
    if tf <= float(slen_p) {
        return _mk_str(s);
    }
    target: int = int(tf);
    pad_units: list[int] = [0x20];  # default fill is a single space
    if not jsv_is_undefined(pad_v) {
        pad_units = js_string_utf16_units(js_to_string_prim(pad_v));
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    pad_len: int = len(pad_units);
    if pad_len == 0 {
        return _mk_str(s);
    }
    needed: int = target - slen_p;
    fill: list[int] = [];
    k: int = 0;
    while k < needed {
        fill.append(pad_units[k % pad_len]);
        k = k + 1;
    }
    out: list[int] = [];
    if at_start {
        i: int = 0;
        while i < len(fill) {
            out.append(fill[i]);
            i = i + 1;
        }
        i = 0;
        while i < slen_p {
            out.append(s_units[i]);
            i = i + 1;
        }
    } else {
        i2: int = 0;
        while i2 < slen_p {
            out.append(s_units[i2]);
            i2 = i2 + 1;
        }
        i2 = 0;
        while i2 < len(fill) {
            out.append(fill[i2]);
            i2 = i2 + 1;
        }
    }
    return _mk_str(js_string_from_utf16_code_units(out));
}

"""padStart(targetLength, padString) — ECMAScript §22.1.3.12"""
def:pub js_str_padStart(v: JSValue, target_v: JSValue, pad_v: JSValue) -> JSValue {
    return _str_pad(v, target_v, pad_v, True);
}

"""padEnd(targetLength, padString) — ECMAScript §22.1.3.11"""
def:pub js_str_padEnd(v: JSValue, target_v: JSValue, pad_v: JSValue) -> JSValue {
    return _str_pad(v, target_v, pad_v, False);
}

# ══════════════════════════════════════════════════════════════════════════════
# 15.  String.prototype — repeat / concat
# ══════════════════════════════════════════════════════════════════════════════

"""repeat(count) — ECMAScript §22.1.3.16"""
def:pub js_str_repeat(v: JSValue, count_v: JSValue) -> JSValue {
    s: str = _raw(string_value_of(v));
    # ToIntegerOrInfinity(count) — observable (valueOf runs, Symbol/BigInt throw).
    cf: float = _to_int_or_inf(count_v);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # count < 0 or count == +∞ → RangeError (§22.1.3.16 steps 4–5).
    is_inf: bool = cf >= 1.7976931348623157e+308;
    if cf < 0.0 or is_inf {
        vm_throw_native(make_range_error("Invalid count value"));
        return _mk_str("");
    }
    n: int = int(cf);
    if n == 0 {
        return _mk_str("");
    }
    # Repeating the empty string is empty for any valid count — short-circuit
    # before allocating, so `"".repeat(2147483647)` returns "" instead of
    # attempting a 2GB allocation.
    if len(s) == 0 {
        return _mk_str("");
    }
    return _mk_str(s * n);
}

"""concat(...strings) — ECMAScript §22.1.3.4"""
def:pub js_str_concat(v: JSValue, args: list[JSValue]) -> JSValue {
    # Collect pieces then join once — host `s = s + x` is O(n^2) for many args.
    parts: list[str] = [];
    parts.append(_raw(string_value_of(v)));
    # ToString(this) precedes ToString(args); bail if it threw so an arg's own
    # ToString can't overwrite the pending exception (native code doesn't unwind).
    if vm_has_native_exc() {
        return js_undefined();
    }
    i: int = 0;
    while i < len(args) {
        parts.append(js_to_string_prim(args[i]));
        if vm_has_native_exc() {
            return js_undefined();
        }
        i = i + 1;
    }
    return _mk_str("".join(parts));
}

# ══════════════════════════════════════════════════════════════════════════════
# 16.  String.prototype — match / search stubs (RegExp )
# ══════════════════════════════════════════════════════════════════════════════

"""match() — §22.1.3.11  RegExp integration stub; returns null."""
def:pub js_str_match(v: JSValue, pattern: JSValue) -> JSValue {
    return js_null();
}

"""matchAll() — §22.1.3.12  RegExp integration stub; returns null."""
def:pub js_str_matchAll(v: JSValue, pattern: JSValue) -> JSValue {
    return js_null();
}

"""search() — §22.1.3.17  RegExp integration stub; returns -1."""
def:pub js_str_search(v: JSValue, pattern: JSValue) -> JSValue {
    return js_int(-1);
}

"""
Return the NFKC/NFKD replacement string for a single codepoint, or "" if
none exists (caller uses utf8_encode_scalar(cp) as fallback).
Covers the most common Unicode compatibility mappings tested in practice.
"""
def _nfkc_compat(cp: int) -> str {
    # Latin ligatures U+FB00–U+FB06
    if cp == 0xFB00 {
        return "ff";
    }
    if cp == 0xFB01 {
        return "fi";
    }
    if cp == 0xFB02 {
        return "fl";
    }
    if cp == 0xFB03 {
        return "ffi";
    }
    if cp == 0xFB04 {
        return "ffl";
    }
    if cp == 0xFB05 {
        return "st";
    }
    if cp == 0xFB06 {
        return "st";
    }
    # No mapping found
    return "";
}

def:pub js_str_normalize(v: JSValue, form: JSValue) -> JSValue {
    # §22.1.3.15: RequireObjectCoercible / ToString(this) happen in dispatch;
    # then ToString(form) BEFORE form validation so abrupt completions win.
    form_str: str = "NFC";
    if not jsv_is_undefined(form) {
        form_str = js_to_string_prim(form);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    # Validate form per ECMAScript §22.1.3.15
    if form_str != "NFC"
        and form_str != "NFD"
        and form_str != "NFKC"
        and form_str != "NFKD" {
        vm_throw_native(
            make_range_error(
                "The normalization form should be one of NFC, NFD, NFKC, NFKD."
            )
        );
        return js_undefined();
    }
    sv: JSValue = string_value_of(v);
    s: str = _raw(sv);
    # Prefer ICU Unicode normalization when the shim is available.
    normed: str = icu_normalize_str(form_str, s);
    if normed != "" or s == "" {
        return _mk_str(normed);
    }
    # Fallback: NFC/NFD identity; NFKC/NFKD best-effort compatibility map.
    if form_str == "NFC" or form_str == "NFD" {
        return sv;
    }
    units: list[int] = js_string_utf16_units(s);
    scalars: list[int] = utf16_units_to_scalars(units);
    out: str = "";
    i: int = 0;
    while i < len(scalars) {
        cp: int = scalars[i];
        compat: str = _nfkc_compat(cp);
        if compat != "" {
            out = out + compat;
        } else {
            out = out + utf8_encode_scalar(cp);
        }
        i = i + 1;
    }
    return _mk_str(out);
}

# ══════════════════════════════════════════════════════════════════════════════
# 16b. String.prototype.localeCompare — §22.1.3.12
# ══════════════════════════════════════════════════════════════════════════════

"""
String.prototype.localeCompare(that [, locales [, options]])

Respects locales + options.sensitivity / options.numeric via ICU collation.
Returns negative / 0 / positive as required by ECMAScript.
"""
def:pub js_str_localeCompare(
    v: JSValue, that: JSValue, locales: JSValue, options: JSValue
) -> JSValue {
    a: str = js_to_string_prim(v);
    if vm_has_native_exc() {
        return js_undefined();
    }
    b: str = js_to_string_prim(that);
    if vm_has_native_exc() {
        return js_undefined();
    }
    sens: str = "";
    numeric: bool = False;
    if jsv_is_object_cell(options) {
        sens_key: int = str_intern("sensitivity");
        sens_val: JSValue = js_object_get(options, sens_key);
        if jsv_is_string_cell(sens_val) {
            sens = str_from_id(jsv_to_table_id(sens_val));
        }
        num_key: int = str_intern("numeric");
        num_val: JSValue = js_object_get(options, num_key);
        if jsv_is_bool(num_val) {
            numeric = jsv_to_bool(num_val);
        } elif not jsv_is_undefined(num_val) and not jsv_is_null(num_val) {
            # ToBoolean for other types
            if jsv_is_string_cell(num_val) {
                ns: str = str_from_id(jsv_to_table_id(num_val));
                numeric = ns != "" and ns != "false" and ns != "0";
            } elif jsv_is_int32(num_val) {
                numeric = jsv_to_int32(num_val) != 0;
            } elif jsv_is_double(num_val) {
                numeric = jsv_to_double(num_val) != 0.0;
            } else {
                numeric = True;
            }
        }
    }
    loc: str = "";
    if jsv_is_string_cell(locales) {
        loc = str_from_id(jsv_to_table_id(locales));
    } elif jsv_is_object_cell(locales) {
        # Array-like: use first element when present.
        len_v: JSValue = js_object_get(locales, KEY_LENGTH);
        if jsv_is_int32(len_v) and jsv_to_int32(len_v) > 0 {
            first: JSValue = js_object_get(locales, str_intern("0"));
            if jsv_is_string_cell(first) {
                loc = str_from_id(jsv_to_table_id(first));
            }
        }
    }
    if loc == "" {
        loc = icu_default_locale_str();
    }
    if loc == "" {
        loc = "en";
    }
    loc_canon: str = icu_canonical_locale_str(loc);
    if loc_canon != "" {
        loc = loc_canon;
    }
    # ICU en_US_POSIX / en-US-u-va-posix is not a usable Intl locale.
    loc_l: str = loc.lower();
    if loc_l.find("posix") >= 0 {
        loc = "en-US";
    }
    if numeric {
        # Append kn so ICU enables numeric collation (options override).
        if loc.find("-u-") < 0 {
            loc = loc + "-u-kn";
        } elif loc.find("-kn") < 0 {
            loc = loc + "-kn";
        }
    }
    # Default sensitivity matches Intl.Collator ("variant").
    if sens == "" {
        sens = "variant";
    }
    # FFI may deliver the C int32 as a zero-extended Jac int; normalize via js_int
    # (same path as intl_compare / __icu.compare) before sign checks.
    raw: JSValue = js_int(icu_compare_str(loc, sens, a, b));
    cmp: int = jsv_to_int32(raw);
    if cmp != -2147483648 {
        if cmp < 0 {
            return js_int(-1);
        }
        if cmp > 0 {
            return js_int(1);
        }
        return js_int(0);
    }
    # Fallback without ICU
    if sens == "base" or sens == "accent" {
        a = a.lower();
        b = b.lower();
    }
    if a < b {
        return js_int(-1);
    }
    if a > b {
        return js_int(1);
    }
    return js_int(0);
}

# ══════════════════════════════════════════════════════════════════════════════
# 17.  String.prototype — toString / valueOf
# ══════════════════════════════════════════════════════════════════════════════

"""String.prototype.toString() / valueOf() — ECMAScript §22.1.3.27"""
def:pub js_str_toString(v: JSValue) -> JSValue {
    return string_value_of(v);
}

# ══════════════════════════════════════════════════════════════════════════════
# 18.  URI encoding / decoding — §19.2.6
# ══════════════════════════════════════════════════════════════════════════════

glob _HEX_CHARS: str = "0123456789ABCDEF";

"""
encodeURIComponent(str) — ECMAScript §19.2.6.4
Encodes everything EXCEPT:  A-Z a-z 0-9 - _ . ~ ! * ' ( )
"""
def:pub js_encodeURIComponent(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return _mk_str("undefined");
    }
    return _uri_encode(_raw(args[0]), False);
}

"""Shared Encode abstract operation — ECMAScript §19.2.6.5.

`unescaped_set` is the set of code points left as-is: for encodeURIComponent
that is uriUnescaped, for encodeURI it also includes uriReserved plus '#'.

The input `s` is a UTF-8 Jac string, so it must first be decoded to Unicode
SCALAR values. Iterating raw bytes (the previous implementation) re-encoded each
byte of an already-UTF-8 sequence, so "é" became %C3%83%C2%A9 instead of %C3%A9.

An unpaired surrogate is a URIError (§19.2.6.5 step 3.a.ii) — after
utf16_units_to_scalars, a value that is still in D800-DFFF was unpaired."""
def _uri_encode(s: str, keep_reserved: bool) -> JSValue {
    units: list[int] = js_string_utf16_units(s);
    scalars: list[int] = utf16_units_to_scalars(units);
    result: str = "";
    i: int = 0;
    n: int = len(scalars);
    while i < n {
        c: int = scalars[i];
        keep: bool = False;
        # uriUnescaped: ALPHA / DIGIT / uriMark
        if (c >= 65 and c <= 90)
            or (c >= 97 and c <= 122)
            or (c >= 48 and c <= 57)
            or c == 45
            or c == 95
            or c == 46
            or c == 126
            or c == 33
            or c == 42
            or c == 39
            or c == 40
            or c == 41 {
            keep = True;
        } elif keep_reserved {
            # uriReserved  ; / ? : @ & = + $ ,   plus  #
            if c == 59
                or c == 47
                or c == 63
                or c == 58
                or c == 64
                or c == 38
                or c == 61
                or c == 43
                or c == 36
                or c == 44
                or c == 35 {
                keep = True;
            }
        }
        if keep {
            result = result + utf8_encode_scalar(c);
        } elif c >= 55296 and c <= 57343 {
            # Unpaired surrogate — not a valid scalar value.
            vm_throw_native(make_uri_error("URI malformed"));
            return js_undefined();
        } else {
            result = result + _pct_encode_scalar(c);
        }
        i = i + 1;
    }
    return _mk_str(result);
}

"""Percent-encode one Unicode scalar as its UTF-8 bytes (%XX per byte)."""
def _pct_encode_scalar(c: int) -> str {
    out: str = "";
    if c < 128 {
        out = out + _pct_byte(c);
    } elif c < 2048 {
        out = out + _pct_byte(192 + (c // 64));
        out = out + _pct_byte(128 + (c % 64));
    } elif c < 65536 {
        out = out + _pct_byte(224 + (c // 4096));
        out = out + _pct_byte(128 + ((c // 64) % 64));
        out = out + _pct_byte(128 + (c % 64));
    } else {
        out = out + _pct_byte(240 + (c // 262144));
        out = out + _pct_byte(128 + ((c // 4096) % 64));
        out = out + _pct_byte(128 + ((c // 64) % 64));
        out = out + _pct_byte(128 + (c % 64));
    }
    return out;
}

"""Format one byte as %XX with uppercase hex digits."""
def _pct_byte(b: int) -> str {
    return "%" + str_char_at(_HEX_CHARS, b // 16) + str_char_at(_HEX_CHARS, b % 16);
}

"""
Helper: convert a hex character (0-9, A-F, a-f) to its numeric value.
Returns -1 for invalid characters.
"""
def:pub _hex_val(c: int) -> int {
    if c >= 48 and c <= 57 {
        return c - 48;
    }  # 0-9
    if c >= 65 and c <= 70 {
        return c - 65 + 10;
    }  # A-F
    if c >= 97 and c <= 102 {
        return c - 97 + 10;
    }  # a-f
    return -1;
}

"""True for the bytes decodeURI must leave percent-escaped: uriReserved
(; / ? : @ & = + $ ,) plus '#'."""
def _is_uri_reserved_byte(b: int) -> bool {
    return b == 59
        or b == 47
        or b == 63
        or b == 58
        or b == 64
        or b == 38
        or b == 61
        or b == 43
        or b == 36
        or b == 44
        or b == 35;
}

"""
decodeURIComponent(str) — ECMAScript §19.2.6.2
Decodes percent-encoded UTF-8 bytes back to a string.
"""
def:pub js_decodeURIComponent(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return _mk_str("undefined");
    }
    return _uri_decode(_raw(args[0]), False);
}

"""Shared Decode abstract operation — ECMAScript §19.2.6.4.

When `preserve_reserved` is True (decodeURI), a percent-escape whose decoded
byte is in uriReserved (; / ? : @ & = + $ ,) or '#' is left in its ESCAPED form
rather than decoded, so decodeURI("%3B") is "%3B" while
decodeURIComponent("%3B") is ";"."""
def _uri_decode(s: str, preserve_reserved: bool) -> JSValue {
    result: str = "";
    i: int = 0;
    slen: int = len(s);
    while i < slen {
        ch: str = str_char_at(s, i);
        if ch == "%" {
            # Must have exactly 2 hex digits following % — §19.2.6.2 Decode step 4
            if i + 2 >= slen {
                vm_throw_native(make_uri_error("URI malformed"));
                return js_undefined();
            }
            h1: int = _hex_val(ord(str_char_at(s, i + 1)));
            h2: int = _hex_val(ord(str_char_at(s, i + 2)));
            if h1 < 0 or h2 < 0 {
                vm_throw_native(make_uri_error("URI malformed"));
                return js_undefined();
            }
            byte1: int = h1 * 16 + h2;
            if byte1 < 128 {
                # Single-byte ASCII. decodeURI keeps the reserved set escaped
                # (§19.2.6.4 step 4.d.i): the escape is copied through verbatim.
                if preserve_reserved and _is_uri_reserved_byte(byte1) {
                    result = result + str_substr(s, i, i + 3);
                } else {
                    result = result + chr(byte1);
                }
                i = i + 3;
            } elif byte1 >= 192 and byte1 < 224 {
                # 2-byte UTF-8: 110xxxxx 10xxxxxx — need %XX%XX
                if i + 5 >= slen {
                    vm_throw_native(make_uri_error("URI malformed"));
                    return js_undefined();
                }
                b2: int = _decode_percent_byte(s, i + 3);
                if b2 < 0 {
                    vm_throw_native(make_uri_error("URI malformed"));
                    return js_undefined();
                }
                cp: int = (byte1 - 192) * 64 + (b2 - 128);
                if not _uri_scalar_valid(cp, 2) {
                    vm_throw_native(make_uri_error("URI malformed"));
                    return js_undefined();
                }
                result = result + utf8_encode_scalar(cp);
                i = i + 6;
            } elif byte1 >= 224 and byte1 < 240 {
                # 3-byte UTF-8: 1110xxxx 10xxxxxx 10xxxxxx — need %XX%XX%XX
                if i + 8 >= slen {
                    vm_throw_native(make_uri_error("URI malformed"));
                    return js_undefined();
                }
                b2: int = _decode_percent_byte(s, i + 3);
                b3: int = _decode_percent_byte(s, i + 6);
                if b2 < 0 or b3 < 0 {
                    vm_throw_native(make_uri_error("URI malformed"));
                    return js_undefined();
                }
                cp: int = (byte1 - 224) * 4096 + (b2 - 128) * 64 + (b3 - 128);
                if not _uri_scalar_valid(cp, 3) {
                    vm_throw_native(make_uri_error("URI malformed"));
                    return js_undefined();
                }
                result = result + utf8_encode_scalar(cp);
                i = i + 9;
            } elif byte1 >= 240 and byte1 < 248 {
                # 4-byte UTF-8: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx — need %XX%XX%XX%XX
                if i + 11 >= slen {
                    vm_throw_native(make_uri_error("URI malformed"));
                    return js_undefined();
                }
                b2: int = _decode_percent_byte(s, i + 3);
                b3: int = _decode_percent_byte(s, i + 6);
                b4: int = _decode_percent_byte(s, i + 9);
                if b2 < 0 or b3 < 0 or b4 < 0 {
                    vm_throw_native(make_uri_error("URI malformed"));
                    return js_undefined();
                }
                cp: int = (byte1 - 240) * 262144
                    + (b2 - 128) * 4096
                    + (b3 - 128) * 64
                    + (b4 - 128);
                if not _uri_scalar_valid(cp, 4) {
                    vm_throw_native(make_uri_error("URI malformed"));
                    return js_undefined();
                }
                result = result + utf8_encode_scalar(cp);
                i = i + 12;
            } else {
                # Byte 0x80-0xBF (continuation without lead) or 0xF8+ — not valid UTF-8 lead
                vm_throw_native(make_uri_error("URI malformed"));
                return js_undefined();
            }
        } else {
            result = result + ch;
            i = i + 1;
        }
    }
    return _mk_str(result);
}

"""Decode a single %XX CONTINUATION byte at position pos. Returns -1 if the
sequence is absent, malformed, or not a 10xxxxxx continuation byte.

§19.2.6.4 requires every trailing byte of a multi-byte sequence to be in
0x80-0xBF; without that check "%C3%28" decoded as if 0x28 were a continuation
and produced a bogus character instead of a URIError."""
def _decode_percent_byte(s: str, pos: int) -> int {
    slen: int = len(s);
    # Need three chars: '%', hex, hex — the last valid index is pos+2.
    if pos + 2 > slen - 1 {
        return -1;
    }
    if str_char_at(s, pos) != "%" {
        return -1;
    }
    h1: int = _hex_val(ord(str_char_at(s, pos + 1)));
    h2: int = _hex_val(ord(str_char_at(s, pos + 2)));
    if h1 < 0 or h2 < 0 {
        return -1;
    }
    b: int = h1 * 16 + h2;
    if b < 128 or b > 191 {
        return -1;
    }
    return b;
}

"""Validate a decoded scalar for the given UTF-8 sequence length (§19.2.6.4).

Rejects overlong encodings (a value encodable in fewer bytes), UTF-16 surrogate
halves (D800-DFFF are not scalar values), and anything above U+10FFFF. Returns
False when the sequence must raise a URIError."""
def _uri_scalar_valid(cp: int, nbytes: int) -> bool {
    if cp > 1114111 {
        return False;
    }
    if cp >= 55296 and cp <= 57343 {
        return False;
    }
    if nbytes == 2 and cp < 128 {
        return False;
    }
    if nbytes == 3 and cp < 2048 {
        return False;
    }
    if nbytes == 4 and cp < 65536 {
        return False;
    }
    return True;
}

"""
encodeURI(str) — ECMAScript §19.2.6.3
Same as encodeURIComponent but also preserves:  ; / ? : @ & = + $ , #
"""
def:pub js_encodeURI(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return _mk_str("undefined");
    }
    return _uri_encode(_raw(args[0]), True);
}

"""
decodeURI(str) — ECMAScript §19.2.6.1
Same as decodeURIComponent but does NOT decode reserved chars:  ; / ? : @ & = + $ , #
"""
def:pub js_decodeURI(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return _mk_str("undefined");
    }
    return _uri_decode(_raw(args[0]), True);
}
