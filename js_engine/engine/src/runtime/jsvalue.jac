"""
Core JavaScript value representation for js_engine runtime.

A1.3: JSValue is now a true int64 type alias (NaN-boxed).
The 5-field struct and JSValueTag enum have been deleted.
Every JS value is a register-resident 64-bit integer encoded as per the
JSC-style NaN-boxing scheme documented in docs/JSEngineProduction.md §A1.1.

Encoding layout:
  [0x0000_0000_0000_0000 … 0x0000_0FFF_FFFF_FFFF]  heap cell ptr (48-bit, bits 47..44 = cell kind)
  [0xFFFE_0000_0000_0000 … 0xFFFE_FFFF_FFFF_FFFF]  Int32
   0xFFFF_0000_0000_0000                            undefined
   0xFFFF_0000_0000_0001                            null
   0xFFFF_0000_0000_0002                            false
   0xFFFF_0000_0000_0003                            true
   0xFFFF_0000_0000_0004                            the-hole
  [0x0001_0000_0000_0000 … 0xFFFD_FFFF_FFFF_FFFF]  Float64 + JS_DOUBLE_OFF bias

Cell kinds (bits 47..44):
  0 = String   1 = Object   2 = Symbol   3 = BigInt   4 = Native
  5 = [[IsHTMLDDA]] Object (test262 host document.all exotic)
"""

# IEEE 754 special value constants.
# Workaround: math.inf / math.nan resolve to 0.0 in Jac native (compiler bug).
# 1e308 * 2.0 overflows to +Inf; Inf - Inf = NaN — no FP traps.
glob:pub MATH_INF: float = 1e308 * 2.0,
     MATH_NEG_INF: float = -1e308 * 2.0,
     MATH_NAN: float = 1e308 * 2.0 - 1e308 * 2.0;

# ============================================================
# A1.3: JSValue is a true int64 type alias
# ============================================================

"""
A1.3: JSValue is now a type alias for int64.
No struct, no enum — every JS value is a 64-bit NaN-boxed integer.
""" type JSValue = int;

# ============================================================
# Factory functions (ECMAScript-style; delegate to jsv_* API)
# ============================================================

"""Create the ECMAScript undefined value."""
def:pub js_undefined -> JSValue {
    return jsv_undefined();
}

"""Create the ECMAScript null value."""
def:pub js_null -> JSValue {
    return jsv_null();
}

"""Create a boolean JSValue from a Jac bool."""
def:pub js_boolean(b: bool) -> JSValue {
    return jsv_from_bool(b);
}

"""Create the true JSValue."""
def:pub js_true -> JSValue {
    return jsv_true();
}

"""Create the false JSValue."""
def:pub js_false -> JSValue {
    return jsv_false();
}

"""Create a Float64 JSValue from a Jac float."""
def:pub js_number(n: float) -> JSValue {
    return jsv_from_double(n);
}

"""Create an Int32 JSValue from a Jac int."""
def:pub js_int(i: int) -> JSValue {
    return jsv_from_int32(i);
}

"""Create the NaN JSValue."""
def:pub js_nan -> JSValue {
    return JS_BITS_NAN;
}

"""Create the +Infinity JSValue."""
def:pub js_infinity -> JSValue {
    return jsv_from_double(MATH_INF);
}

"""Create the -Infinity JSValue."""
def:pub js_neg_infinity -> JSValue {
    return jsv_from_double(MATH_NEG_INF);
}

# ============================================================
# ECMAScript coercion helpers (replace struct .to_*() methods)
# ============================================================

"""
ToBoolean(v) — ECMAScript §7.1.2
Replaces the old JSValue.to_boolean() method.
"""
# Intern ID for the BigInt string "0" — set by jsv_set_bigint_zero_id() after
# str_intern_seed_well_known().  Default -1 makes BigInt falsiness tests safe
# even if initialization is late (any real intern id is >= 0).
glob:pub _BIGINT_ZERO_INTERN_ID: int = -1;

def:pub jsv_set_bigint_zero_id(id: int) {
    _BIGINT_ZERO_INTERN_ID = id;
}

def:pub jsv_coerce_to_bool(v: JSValue) -> bool {
    if jsv_is_undefined(v) or jsv_is_null(v) {
        return False;
    }
    if jsv_is_htmldda(v) {
        return False;
    }
    if jsv_is_bool(v) {
        return jsv_to_bool(v);
    }
    if jsv_is_int32(v) {
        return jsv_to_int32(v) != 0;
    }
    if jsv_is_double(v) {
        n: float = jsv_to_double(v);
        return n != 0.0 and n == n;
    }
    if jsv_is_string_cell(v) {
        return jsv_to_table_id(v) != 6;
    }  # 6 = intern id for ""
    if jsv_is_bigint_cell(v) {
        return jsv_to_table_id(v) != _BIGINT_ZERO_INTERN_ID;
    }
    return True;  # objects, symbols, fn/native vals
}

"""
ToNumber(v) — ECMAScript §7.1.4 (simplified — strings return 0.0)
Replaces the old JSValue.to_number() method.
For strings, vm.na.jac's js_to_num() provides full str→float coercion.
"""
def:pub jsv_coerce_to_number(v: JSValue) -> float {
    if jsv_is_undefined(v) {
        return MATH_NAN;
    }
    if jsv_is_null(v) {
        return 0.0;
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return 1.0;
        }
        return 0.0;
    }
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return jsv_to_double(v);
    }
    return 0.0;  # strings, objects, etc. — simplified
}

"""
ToString(v) — simplified ECMAScript §7.1.17
Replaces the old JSValue.to_string() method.
For strings, callers should use str_from_id(jsv_to_table_id(v)) directly.
"""
def:pub jsv_coerce_to_str(v: JSValue) -> str {
    if jsv_is_undefined(v) {
        return "undefined";
    }
    if jsv_is_null(v) {
        return "null";
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return "true";
        }
        return "false";
    }
    if jsv_is_int32(v) {
        return str(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        n: float = jsv_to_double(v);
        if not (n == n) {
            return "NaN";
        }
        if n == MATH_INF {
            return "Infinity";
        }
        if n == MATH_NEG_INF {
            return "-Infinity";
        }
        # Integer-valued doubles (e.g. Date.now()) must not use scientific notation in `+`.
        i: int = int(n);
        if float(i) == n {
            return str(i);
        }
        return str(n);
    }
    if jsv_is_string_cell(v) {
        return "<string>";
    }  # caller should do str_from_id
    if jsv_is_object_cell(v)
        or (jsv_is_cell(v) and jsv_cell_kind(v) == JS_CELL_KIND_NATIVE) {
        return "[object Object]";
    }
    if jsv_is_symbol(v) {
        return "Symbol()";
    }
    return "";
}

"""
True if v has JS Object type: regular object, fn value, builtin, or native val.
This replaces the old JSValue.is_object() method which tested tag == JSValueTag.Object.
After A1.3, tag==Object maps to: kind==OBJECT (regular) or kind==NATIVE (fn/builtin/native).
"""
def:pub jsv_is_any_object(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    kind: int = jsv_cell_kind(v);
    return kind == JS_CELL_KIND_OBJECT
        or kind == JS_CELL_KIND_NATIVE
        or kind == JS_CELL_KIND_HTMLDDA;
}

"""True if v is a BigInt cell."""
def:pub jsv_is_bigint_cell(v: JSValue) -> bool {
    return jsv_is_cell(v) and jsv_cell_kind(v) == JS_CELL_KIND_BIGINT;
}

"""True if v encodes a NaN float64."""
def:pub jsv_is_nan(v: JSValue) -> bool {
    return v == JS_BITS_NAN;
}

# ============================================================
# Strict Equality (===)
# ============================================================

"""
Strict Equality Comparison (===) — ECMAScript §7.2.16

In NaN-boxing equal non-numeric values have identical bit patterns.
Cross-type numeric comparison (Int32 vs Float64) requires value comparison.
"""
def:pub js_strict_equal(a: JSValue, b: JSValue) -> bool {
    if jsv_is_int32(a) {
        if jsv_is_int32(b) {
            return a == b;
        }
        if jsv_is_double(b) {
            bn: float = jsv_to_double(b);
            if not (bn == bn) {
                return False;
            }
            return float(jsv_to_int32(a)) == bn;
        }
        return False;
    }
    if jsv_is_double(a) {
        an: float = jsv_to_double(a);
        if jsv_is_double(b) {
            bn: float = jsv_to_double(b);
            if not (an == an) or not (bn == bn) {
                return False;
            }
            return an == bn;
        }
        if jsv_is_int32(b) {
            if not (an == an) {
                return False;
            }
            return an == float(jsv_to_int32(b));
        }
        return False;
    }
    # For all other types (undefined, null, bool, cells), bit equality suffices.
    # NOTE for strings: bit equality is correct for INTERNED strings only. Two
    # heap (computed, non-deduped) strings with equal content have different ids,
    # so callers that may see heap strings — the VM's STRICT_EQ / abstract-eq
    # paths — compare content explicitly before delegating here. Low-level
    # jsvalue cannot resolve string text (jsstring depends on this module).
    return a == b;
}

# ============================================================
# Abstract Equality (==)
# ============================================================

"""
Abstract Equality Comparison (==) — ECMAScript §7.2.15

Applies type coercion, then delegates to js_strict_equal.
Note: String→Number coercion uses 0.0 (simplified).
vm.na.jac's _vm_js_abstract_equal() provides full coercion with str_to_float.
"""
def:pub js_abstract_equal(a: JSValue, b: JSValue) -> bool {
    # Fast path: identical bit patterns (covers same-type non-double equality)
    if a == b and not jsv_is_double(a) {
        return True;
    }
    # Both numeric
    if jsv_is_number(a) and jsv_is_number(b) {
        return js_strict_equal(a, b);
    }
    # null == undefined
    if jsv_is_null(a) and jsv_is_undefined(b) {
        return True;
    }
    if jsv_is_undefined(a) and jsv_is_null(b) {
        return True;
    }
    # Number == String: coerce string to 0.0 (simplified)
    if jsv_is_number(a) and jsv_is_string_cell(b) {
        return js_abstract_equal(a, jsv_from_double(0.0));
    }
    if jsv_is_number(b) and jsv_is_string_cell(a) {
        return js_abstract_equal(jsv_from_double(0.0), b);
    }
    # Boolean: coerce to number
    if jsv_is_bool(a) {
        return js_abstract_equal(jsv_from_double(jsv_coerce_to_number(a)), b);
    }
    if jsv_is_bool(b) {
        return js_abstract_equal(a, jsv_from_double(jsv_coerce_to_number(b)));
    }
    return False;
}

# ============================================================
# typeof
# ============================================================

"""
typeof operator — ECMAScript §13.5.3

Returns one of: "undefined", "boolean", "number", "string",
"symbol", "bigint", "object", "function".
"""
def:pub js_typeof(v: JSValue) -> str {
    if jsv_is_undefined(v) {
        return "undefined";
    }
    if jsv_is_htmldda(v) {
        return "undefined";
    }
    if jsv_is_null(v) {
        return "object";
    }
    if jsv_is_bool(v) {
        return "boolean";
    }
    if jsv_is_number(v) {
        return "number";
    }
    if jsv_is_string_cell(v) {
        return "string";
    }
    if jsv_is_symbol(v) {
        return "symbol";
    }
    if jsv_is_bigint_cell(v) {
        return "bigint";
    }
    # object cell (regular object) or native (fn, builtin, native obj)
    return "object";
}

# ============================================================
# A1.1 — NaN-boxed JSValue encoding
# ============================================================
#
# JSC-style 64-bit NaN-boxing.  Every value fits in one int64:
#
#   [0x0000_0000_0000_0000 … 0x0000_0FFF_FFFF_FFFF]  heap cell ptr (48-bit, bits 47..44 = kind)
#   [0xFFFE_0000_0000_0000 … 0xFFFE_FFFF_FFFF_FFFF]  Int32
#    0xFFFF_0000_0000_0000                            undefined
#    0xFFFF_0000_0000_0001                            null
#    0xFFFF_0000_0000_0002                            false
#    0xFFFF_0000_0000_0003                            true
#    0xFFFF_0000_0000_0004                            the-hole
#   [0x0001_0000_0000_0000 … 0xFFFD_FFFF_FFFF_FFFF]  Float64 + DOUBLE_OFFSET bias
#
# Requires the __float_bits / __bits_float compiler intrinsics (shipped in
# jac/jaclang/compiler/passes/native/na_ir_gen_pass.impl/calls.impl.jac).
#
# Type stubs for the compiler intrinsics — call sites are intercepted at
# codegen and emitted as single LLVM bitcasts, so the stub bodies are
# unreachable but required for the type checker to know the signatures.
def __float_bits(d: float) -> int {
    return 0;
}
def __bits_float(b: int) -> float {
    return 0.0;
}

# ------------------------------------------------------------
# Encoding constants
# ------------------------------------------------------------

"""High 16-bit mask — bits 63..48."""
glob:pub JS_TAG_HI_MASK: int = 0xFFFF_0000_0000_0000;

"""Int32 tag — high 16 bits = 0xFFFE."""
glob:pub JS_INT32_TAG: int = 0xFFFE_0000_0000_0000;

"""Bias added to every float64 before storing so the bit pattern never
collides with pointer / int32 / immediate ranges."""
glob:pub JS_DOUBLE_OFF: int = 0x0001_0000_0000_0000;

# Immediate bit-patterns
glob:pub JS_BITS_UNDEFINED: int = 0xFFFF_0000_0000_0000,
     JS_BITS_NULL: int = 0xFFFF_0000_0000_0001,
     JS_BITS_FALSE: int = 0xFFFF_0000_0000_0002,
     JS_BITS_TRUE: int = 0xFFFF_0000_0000_0003,
     JS_BITS_HOLE: int = 0xFFFF_0000_0000_0004;

"""Canonical quiet-NaN bit pattern used after NaN normalisation."""
glob:pub JS_BITS_NAN: int = 0x7FF8_0000_0000_0000;

# Cell sub-kind bits stored in bits 47..44 of a heap-pointer value.
glob:pub JS_CELL_KIND_SHIFT: int = 44,
     JS_CELL_KIND_STRING: int = 0,
     JS_CELL_KIND_OBJECT: int = 1,
     JS_CELL_KIND_SYMBOL: int = 2,
     JS_CELL_KIND_BIGINT: int = 3,
     JS_CELL_KIND_NATIVE: int = 4,
     JS_CELL_KIND_HTMLDDA: int = 5;


# fn/builtin/native-obj encoded as negative as_ptr
# object-table cell with [[IsHTMLDDA]]
# ------------------------------------------------------------
# Type guards
# ------------------------------------------------------------

"""True if v encodes an Int32."""
def:pub jsv_is_int32(v: JSValue) -> bool {
    return (v & JS_TAG_HI_MASK) == JS_INT32_TAG;
}

"""True if v encodes a Float64 (not pointer, not int32, not immediate)."""
def:pub jsv_is_double(v: JSValue) -> bool {
    hi: int = (v >> 48) & 0xFFFF;
    return hi != 0x0000 and hi != 0xFFFE and hi != 0xFFFF;
}

"""True if v is Int32 or Float64."""
def:pub jsv_is_number(v: JSValue) -> bool {
    return jsv_is_int32(v) or jsv_is_double(v);
}

"""True if v is undefined."""
def:pub jsv_is_undefined(v: JSValue) -> bool {
    return v == JS_BITS_UNDEFINED;
}

"""True if v is null."""
def:pub jsv_is_null(v: JSValue) -> bool {
    return v == JS_BITS_NULL;
}

"""True if v is null or undefined."""
def:pub jsv_is_nullish(v: JSValue) -> bool {
    return v == JS_BITS_UNDEFINED or v == JS_BITS_NULL;
}

"""True if v is a boolean."""
def:pub jsv_is_bool(v: JSValue) -> bool {
    return v == JS_BITS_FALSE or v == JS_BITS_TRUE;
}

"""True if v is the array-hole sentinel."""
def:pub jsv_is_hole(v: JSValue) -> bool {
    return v == JS_BITS_HOLE;
}

"""True if v is a heap cell pointer (top 16 bits == 0x0000)."""
def:pub jsv_is_cell(v: JSValue) -> bool {
    return ((v >> 48) & 0xFFFF) == 0;
}

# ------------------------------------------------------------
# Constructors
# ------------------------------------------------------------

"""Return the undefined immediate."""
def:pub jsv_undefined -> JSValue {
    return JS_BITS_UNDEFINED;
}

"""Return the null immediate."""
def:pub jsv_null -> JSValue {
    return JS_BITS_NULL;
}

"""Return the true immediate."""
def:pub jsv_true -> JSValue {
    return JS_BITS_TRUE;
}

"""Return the false immediate."""
def:pub jsv_false -> JSValue {
    return JS_BITS_FALSE;
}

"""Return the hole immediate."""
def:pub jsv_hole -> JSValue {
    return JS_BITS_HOLE;
}

"""Box a Jac bool as a JSValue."""
def:pub jsv_from_bool(b: bool) -> JSValue {
    if b {
        return JS_BITS_TRUE;
    }
    return JS_BITS_FALSE;
}

"""Box a signed 32-bit integer."""
def:pub jsv_from_int32(i: int) -> JSValue {
    return JS_INT32_TAG | (i & 0xFFFF_FFFF);
}

"""Box a float64, normalising any NaN to JS_BITS_NAN."""
def:pub jsv_from_double(d: float) -> JSValue {
    bits: int = __float_bits(d);
    # Normalise NaN: if exponent bits are all 1 and mantissa != 0 → canonical NaN.
    exp_mask: int = 0x7FF0_0000_0000_0000;
    if (bits & exp_mask) == exp_mask and (bits & 0x000F_FFFF_FFFF_FFFF) != 0 {
        return JS_BITS_NAN;
    }
    return bits + JS_DOUBLE_OFF;
}

"""Box a 48-bit heap cell pointer (top 16 bits must be 0)."""
def:pub jsv_from_cell(ptr: int) -> JSValue {
    return ptr & 0x0000_FFFF_FFFF_FFFF;
}

"""Box a heap cell with an explicit cell kind tag in bits 47..44."""
def:pub jsv_from_cell_kind(ptr: int, kind: int) -> JSValue {
    return (ptr & 0x0000_0FFF_FFFF_FFFF) | (kind << JS_CELL_KIND_SHIFT);
}

# ------------------------------------------------------------
# Accessors
# ------------------------------------------------------------

"""Unbox Int32. Caller must assert jsv_is_int32(v)."""
def:pub jsv_to_int32(v: JSValue) -> int {
    # Sign-extend the low 32 bits: (x ^ 2^31) - 2^31 is the branch-free form
    # LLVM lowers to one movsxd (the if/or form cost six instructions on
    # every int32 unbox in the dispatch loops).
    return ((v & 0xFFFF_FFFF) ^ 0x8000_0000) - 0x8000_0000;
}

"""Unbox Float64. Caller must assert jsv_is_double(v)."""
def:pub jsv_to_double(v: JSValue) -> float {
    return __bits_float(v - JS_DOUBLE_OFF);
}

"""Reinterpret a float64 as its raw IEEE-754 bit pattern (u64). Public wrapper
over the __float_bits codegen intrinsic (which is file-private because it is
intercepted at IR-gen). Used by the Wasmtime bridge to store an f64 value into
a wasmtime_val_t union slot."""
def:pub jsv_double_bits(d: float) -> int {
    return __float_bits(d);
}

"""Reinterpret a raw IEEE-754 u64 bit pattern back into a float64. Inverse of
jsv_double_bits; wraps the __bits_float intrinsic for the Wasmtime bridge."""
def:pub jsv_double_from_bits(b: int) -> float {
    return __bits_float(b);
}

"""IEEE-754 binary32 bits (an unsigned 32-bit pattern) as the double of the
same value — Float32Array reads and Math.fround. Both zeros, the infinities
and the subnormals round-trip exactly; any NaN is the canonical quiet NaN."""
def:pub f32_bits_to_double(bits: int) -> float {
    fb: int = bits & 4294967295;
    f_sign: int = (fb >> 31) & 1;
    f_exp: int = (fb >> 23) & 255;
    f_frac: int = fb & 8388607;
    if f_exp == 255 {
        if f_frac != 0 {
            return __bits_float(9221120237041090560);
        }
        if f_sign == 1 {
            return __bits_float(-4503599627370496);
        }
        return __bits_float(9218868437227405312);
    }
    if f_exp == 0 {
        if f_frac == 0 {
            if f_sign == 1 {
                return __bits_float((-9223372036854775807) - 1);
            }
            return 0.0;
        }
        # subnormal: frac * 2^-149, exact in a double
        f_sub: float = float(f_frac) * __bits_float(3936146074321813504);
        if f_sign == 1 {
            return -f_sub;
        }
        return f_sub;
    }
    f_pos: int = ((f_exp - 127 + 1023) << 52) | (f_frac << 29);
    if f_sign == 1 {
        return __bits_float(f_pos + ((-9223372036854775807) - 1));
    }
    return __bits_float(f_pos);
}

"""The double `d` rounded to the nearest IEEE-754 binary32 (ties to even),
as that float's 32-bit pattern — Float32Array writes and Math.fround. NaN
encodes as the canonical quiet NaN."""
def:pub double_to_f32_bits(d: float) -> int {
    if d != d {
        return 2143289344;
    }
    db: int = __float_bits(d);
    d_sign: int = 0;
    if db < 0 {
        d_sign = 2147483648;
        db = db & 9223372036854775807;
    }
    d_exp: int = (db >> 52) & 2047;
    d_frac: int = db & 4503599627370495;
    if d_exp == 2047 {
        return d_sign | 2139095040;
    }
    if d_exp == 0 {
        return d_sign;
    }
    d_e: int = d_exp - 1023;
    if d_e > 127 {
        return d_sign | 2139095040;
    }
    if d_e >= -126 {
        d_m: int = d_frac >> 29;
        d_rem: int = d_frac & 536870911;
        if d_rem > 268435456 or (d_rem == 268435456 and (d_m & 1) == 1) {
            d_m = d_m + 1;
        }
        if d_m == 8388608 {
            d_m = 0;
            d_e = d_e + 1;
            if d_e > 127 {
                return d_sign | 2139095040;
            }
        }
        return d_sign | ((d_e + 127) << 23) | d_m;
    }
    # subnormal binary32: units of 2^-149 from the 53-bit significand
    d_shift: int = 0 - (d_e + 97);
    if d_shift > 53 {
        return d_sign;
    }
    d_sig: int = 4503599627370496 | d_frac;
    d_sm: int = d_sig >> d_shift;
    d_srem: int = d_sig & ((1 << d_shift) - 1);
    d_half: int = 1 << (d_shift - 1);
    if d_srem > d_half or (d_srem == d_half and (d_sm & 1) == 1) {
        d_sm = d_sm + 1;
    }
    return d_sign | d_sm;
}

"""Unbox bool. Caller must assert jsv_is_bool(v)."""
def:pub jsv_to_bool(v: JSValue) -> bool {
    return v == JS_BITS_TRUE;
}

"""Unbox cell pointer (strip cell-kind bits, return raw 48-bit address)."""
def:pub jsv_to_cell(v: JSValue) -> int {
    return v & 0x0000_0FFF_FFFF_FFFF;
}

"""Return the cell kind stored in bits 47..44."""
def:pub jsv_cell_kind(v: JSValue) -> int {
    return (v >> JS_CELL_KIND_SHIFT) & 0xF;
}

"""Coerce to a Jac float (works for both Int32 and Float64 JSValues)."""
def:pub jsv_to_number(v: JSValue) -> float {
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    return jsv_to_double(v);
}

# ------------------------------------------------------------
# Cell-kind convenience guards
# ------------------------------------------------------------

"""True if v is a Symbol cell."""
def:pub jsv_is_symbol(v: JSValue) -> bool {
    return jsv_is_cell(v) and jsv_cell_kind(v) == JS_CELL_KIND_SYMBOL;
}

"""True if v is an Object cell."""
def:pub jsv_is_object_cell(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    kind: int = jsv_cell_kind(v);
    return kind == JS_CELL_KIND_OBJECT or kind == JS_CELL_KIND_HTMLDDA;
}

"""True for the test262 host's document.all-like [[IsHTMLDDA]] exotic."""
def:pub jsv_is_htmldda(v: JSValue) -> bool {
    return jsv_is_cell(v) and jsv_cell_kind(v) == JS_CELL_KIND_HTMLDDA;
}

"""True if v is a String cell."""
def:pub jsv_is_string_cell(v: JSValue) -> bool {
    return jsv_is_cell(v) and jsv_cell_kind(v) == JS_CELL_KIND_STRING;
}

# ------------------------------------------------------------
# Table-ID constructors (A1.2: cells are still table indices)
# ------------------------------------------------------------

"""Box a symbol table index as a JSValue."""
def:pub jsv_from_symbol_id(id: int) -> JSValue {
    return jsv_from_cell_kind(id, JS_CELL_KIND_SYMBOL);
}

"""Box an object table index as a JSValue."""
def:pub jsv_from_object_id(id: int) -> JSValue {
    return jsv_from_cell_kind(id, JS_CELL_KIND_OBJECT);
}

"""Box an object-table index as the document.all-like [[IsHTMLDDA]] exotic."""
def:pub jsv_from_htmldda_id(id: int) -> JSValue {
    return jsv_from_cell_kind(id, JS_CELL_KIND_HTMLDDA);
}

"""Box a string table index as a JSValue."""
def:pub jsv_from_string_id(id: int) -> JSValue {
    return jsv_from_cell_kind(id, JS_CELL_KIND_STRING);
}

"""Extract the table index from any cell value (alias for jsv_to_cell)."""
def:pub jsv_to_table_id(v: JSValue) -> int {
    return jsv_to_cell(v);
}
