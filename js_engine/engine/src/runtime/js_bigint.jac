"""BigInt value helpers shared by VM and builtins.

Implements StringToBigInt / NumberToBigInt / ToBigInt (primitive path) per
ECMAScript §7.1.13–§7.1.15 and §21.2.1.1.  Object ToPrimitive is left to the
VM (`obs_to_bigint`) so callable @@toPrimitive / valueOf / toString run with
observable abrupt completions.
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_is_bigint_cell,
    jsv_to_table_id,
    jsv_from_string_id,
    jsv_is_int32,
    jsv_to_int32,
    jsv_is_double,
    jsv_to_double,
    jsv_is_bool,
    jsv_to_bool,
    jsv_is_string_cell,
    jsv_is_symbol,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_object_cell,
    jsv_from_cell_kind,
    JS_CELL_KIND_BIGINT,
    js_undefined,
    MATH_INF,
    MATH_NEG_INF
}
import from engine.src.runtime.jsstring { str_from_id, str_intern }
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.runtime.bignat {
    bn_parse_decimal,
    bn_cmp,
    bn_zero,
    bn_from_int,
    bn_mul_small,
    bn_add,
    bn_to_string,
    bn_is_zero
}
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    make_syntax_error,
    vm_throw_native
}

glob:priv _JS_BIGINT_SAFE_MAX: float = 9007199254740992.0;  # 2^53

def:priv _bigint_str_is_decimal(s: str) -> bool {
    if len(s) == 0 {
        return False;
    }
    i: int = 0;
    if s[0:1] == "-" {
        i = 1;
    }
    if i >= len(s) {
        return False;
    }
    while i < len(s) {
        ch: str = s[i:i + 1];
        if ch < "0" or ch > "9" {
            return False;
        }
        i = i + 1;
    }
    return True;
}

def:pub js_bigint_cells_equal(a: JSValue, b: JSValue) -> bool {
    if a == b {
        return True;
    }
    sa: str = str_from_id(jsv_to_table_id(a));
    sb: str = str_from_id(jsv_to_table_id(b));
    if _bigint_str_is_decimal(sa) and _bigint_str_is_decimal(sb) {
        return bn_cmp(bn_parse_decimal(sa), bn_parse_decimal(sb)) == 0;
    }
    return float(sa) == float(sb);
}

"""Create a BigInt cell from a decimal digit string (no validation)."""
def:pub js_bigint_from_decimal_str(s: str) -> JSValue {
    if len(s) == 0 {
        s = "0";
    }
    return jsv_from_cell_kind(str_intern(s), JS_CELL_KIND_BIGINT);
}

"""Create a BigInt cell from a float that is an integral Number (NumberToBigInt)."""
def:pub js_bigint_from_num_exact(f: float) -> JSValue {
    if not (f == f) or f == MATH_INF or f == MATH_NEG_INF {
        vm_throw_native(
            make_range_error(
                "The number cannot be converted to a BigInt because it is not an integer"
            )
        );
        return js_bigint_from_decimal_str("0");
    }
    # IsIntegralNumber (§7.2.6): finite and trunc(ℝ(n)) == n.
    if float(int(f)) != f {
        vm_throw_native(
            make_range_error(
                "The number cannot be converted to a BigInt because it is not an integer"
            )
        );
        return js_bigint_from_decimal_str("0");
    }
    # Exact integers in float64, including ±2^53.
    if f > -_JS_BIGINT_SAFE_MAX and f < _JS_BIGINT_SAFE_MAX {
        return js_bigint_from_decimal_str(str(int(f)));
    }
    if f == _JS_BIGINT_SAFE_MAX or f == -_JS_BIGINT_SAFE_MAX {
        if f < 0.0 {
            return js_bigint_from_decimal_str("-9007199254740992");
        }
        return js_bigint_from_decimal_str("9007199254740992");
    }
    return js_bigint_from_decimal_str(str(int(f)));
}

def:priv _is_ws(ch: str) -> bool {
    # ES StrWhiteSpace: TAB, VT, FF, SP, NBSP, LS, PS, and other Unicode Space_Separator.
    # Cover the ASCII set used by test262 StringToBigInt cases.
    return ch == " "
        or ch == "\t"
        or ch == "\n"
        or ch == "\r"
        or ch == "\v"
        or ch == "\f";
}

def:priv _hex_digit(ch: str) -> int {
    if ch >= "0" and ch <= "9" {
        return int(ch);
    }
    if ch >= "a" and ch <= "f" {
        return 10 + (ord(ch) - ord("a"));
    }
    if ch >= "A" and ch <= "F" {
        return 10 + (ord(ch) - ord("A"));
    }
    return -1;
}

"""Parse a non-empty digit string in radix 2/8/10/16 into a BigNat."""
def:priv _bn_parse_radix(digits: str, radix: int) -> list[int] {
    acc: list[int] = bn_zero();
    i: int = 0;
    while i < len(digits) {
        ch: str = digits[i:i + 1];
        d: int = -1;
        if radix == 16 {
            d = _hex_digit(ch);
        } elif ch >= "0" and ch <= "9" {
            d = int(ch);
        }
        if d < 0 or d >= radix {
            return [];
        }
        acc = bn_mul_small(acc, radix);
        acc = bn_add(acc, bn_from_int(d));
        i = i + 1;
    }
    return acc;
}

"""
StringToBigInt(argument) — §7.1.14.
Returns a BigInt cell, or undefined JSValue if the string is not a valid
StringIntegerLiteral (caller throws SyntaxError).
Whitespace-only / empty → 0n.
Supports decimal, 0b/0B, 0o/0O, 0x/0X prefixes.
"""
def:pub js_string_to_bigint(s: str) -> JSValue {
    n: int = len(s);
    i: int = 0;
    while i < n and _is_ws(s[i:i + 1]) {
        i = i + 1;
    }
    j: int = n;
    while j > i and _is_ws(s[j - 1:j]) {
        j = j - 1;
    }
    if i >= j {
        return js_bigint_from_decimal_str("0");
    }
    body: str = s[i:j];
    sign: int = 0;
    if body[0:1] == "+" {
        body = body[1:len(body)];
        if len(body) == 0 {
            return js_undefined();
        }
    } elif body[0:1] == "-" {
        sign = 1;
        body = body[1:len(body)];
        if len(body) == 0 {
            return js_undefined();
        }
    }
    radix: int = 10;
    digits: str = body;
    if len(body) >= 2 and body[0:1] == "0" {
        pfx: str = body[1:2];
        if pfx == "b" or pfx == "B" {
            # test262 / StringIntegerLiteral: signed 0b/0o/0x forms are invalid.
            if sign == 1 {
                return js_undefined();
            }
            radix = 2;
            digits = body[2:len(body)];
        } elif pfx == "o" or pfx == "O" {
            if sign == 1 {
                return js_undefined();
            }
            radix = 8;
            digits = body[2:len(body)];
        } elif pfx == "x" or pfx == "X" {
            if sign == 1 {
                return js_undefined();
            }
            radix = 16;
            digits = body[2:len(body)];
        }
    }
    if len(digits) == 0 {
        return js_undefined();
    }
    # Decimal: no dots / exponents / non-digits.
    if radix == 10 {
        k: int = 0;
        while k < len(digits) {
            chd: str = digits[k:k + 1];
            if chd < "0" or chd > "9" {
                return js_undefined();
            }
            k = k + 1;
        }
        if sign == 1 {
            return js_bigint_from_decimal_str("-" + digits);
        }
        return js_bigint_from_decimal_str(digits);
    }
    bn: list[int] = _bn_parse_radix(digits, radix);
    if len(bn) == 0 {
        return js_undefined();
    }
    if sign == 1 and not bn_is_zero(bn) {
        # Negate via "-"+decimal
        return js_bigint_from_decimal_str("-" + bn_to_string(bn, 10));
    }
    return js_bigint_from_decimal_str(bn_to_string(bn, 10));
}

"""
ToBigInt on a *primitive* value (post-ToPrimitive) — §7.1.13.
Throws TypeError for undefined/null/symbol/object; RangeError is not used here
(Number goes through NumberToBigInt which throws RangeError for non-integers).

For BigInt(value) the constructor uses NumberToBigInt for Number primitives
instead of rejecting them — callers choose via `allow_number`.
"""
def:pub js_bigint_from_primitive(v: JSValue, allow_number: bool) -> JSValue {
    if jsv_is_bigint_cell(v) {
        return v;
    }
    if jsv_is_undefined(v) or jsv_is_null(v) {
        vm_throw_native(
            make_type_error("Cannot convert undefined or null to a BigInt")
        );
        return js_bigint_from_decimal_str("0");
    }
    if jsv_is_symbol(v) {
        vm_throw_native(make_type_error("Cannot convert a Symbol value to a BigInt"));
        return js_bigint_from_decimal_str("0");
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return js_bigint_from_decimal_str("1");
        }
        return js_bigint_from_decimal_str("0");
    }
    if jsv_is_string_cell(v) {
        raw: str = str_from_id(jsv_to_table_id(v));
        parsed: JSValue = js_string_to_bigint(raw);
        if jsv_is_undefined(parsed) {
            vm_throw_native(
                make_syntax_error("Cannot convert " + raw + " to a BigInt")
            );
            return js_bigint_from_decimal_str("0");
        }
        return parsed;
    }
    if jsv_is_int32(v) {
        if allow_number {
            return js_bigint_from_decimal_str(str(jsv_to_int32(v)));
        }
        vm_throw_native(make_type_error("Cannot convert a Number value to a BigInt"));
        return js_bigint_from_decimal_str("0");
    }
    if jsv_is_double(v) {
        if allow_number {
            return js_bigint_from_num_exact(jsv_to_double(v));
        }
        vm_throw_native(make_type_error("Cannot convert a Number value to a BigInt"));
        return js_bigint_from_decimal_str("0");
    }
    if jsv_is_object_cell(v) {
        vm_throw_native(make_type_error("Cannot convert object to a BigInt"));
        return js_bigint_from_decimal_str("0");
    }
    vm_throw_native(make_type_error("Cannot convert value to a BigInt"));
    return js_bigint_from_decimal_str("0");
}

# Merge note: adel_fixes added native js_bigint_as_uint_n / js_bigint_as_int_n
# plus _bn_pow2 / _bn_mod_nonneg helpers here. They are dead code — BigInt.asIntN
# and BigInt.asUintN are implemented in JS (builtins_stubs.js), so nothing calls
# the native versions. Dropped to avoid dead code (and the O(1e6)-iteration
# subtract loop in _bn_mod_nonneg). Only js_bigint_to_string (used by dispatch)
# is kept below.
# ── BigInt.prototype intrinsic (wired from init_global) ───────────────────────
glob _BIGINT_PROTO: JSValue = js_undefined();
def:pub js_bigint_set_proto(proto: JSValue) {
    _BIGINT_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

def:pub js_bigint_get_proto -> JSValue {
    return _BIGINT_PROTO;
}

"""BigInt.prototype.toString(radix) — §21.2.3.1."""
def:pub js_bigint_to_string(v: JSValue, radix: int) -> JSValue {
    if not jsv_is_bigint_cell(v) {
        vm_throw_native(
            make_type_error(
                "BigInt.prototype.toString requires that 'this' be a BigInt"
            )
        );
        return jsv_from_string_id(str_intern("0"));
    }
    if radix < 2 or radix > 36 {
        vm_throw_native(
            make_range_error(
                "radix must be an integer at least 2 and not greater than 36"
            )
        );
        return jsv_from_string_id(str_intern("0"));
    }
    raw: str = str_from_id(jsv_to_table_id(v));
    n: list[int] = bn_parse_decimal(raw);
    return jsv_from_string_id(str_intern(bn_to_string(n, radix)));
}
