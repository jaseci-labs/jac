"""Tests for JSValue — core type system."""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_boolean,
    js_true,
    js_false,
    js_number,
    js_int,
    js_nan,
    js_infinity,
    js_neg_infinity,
    js_strict_equal,
    js_abstract_equal,
    js_typeof,
    jsv_coerce_to_bool,
    jsv_coerce_to_number,
    jsv_coerce_to_str,
    jsv_is_nan,
    jsv_is_null,
    jsv_is_number,
    jsv_is_undefined,
    jsv_is_nullish,
    jsv_is_bool,
    jsv_is_any_object,
    jsv_to_number,
    MATH_INF,
    MATH_NEG_INF,
    MATH_NAN,
    jsv_is_int32,
    jsv_to_int32,
    jsv_is_double,
    jsv_to_double
}
import from engine.src.ffi.libc { fflush, _exit }

# JSValue is a NaN-boxed int, so the old JSValue.is_primitive/is_finite/
# is_integer methods are expressed through the engine's own decoders.
def _ut_is_primitive(v: JSValue) -> bool {
    return not jsv_is_any_object(v);
}

def _ut_is_finite(v: JSValue) -> bool {
    if not jsv_is_number(v) {
        return False;
    }
    d: float = jsv_to_number(v);
    return d == d and d != MATH_INF and d != MATH_NEG_INF;
}

def _ut_is_integer(v: JSValue) -> bool {
    if not _ut_is_finite(v) {
        return False;
    }
    d: float = jsv_to_number(v);
    return d == float(int(d));
}

with entry {
    ok: int = 0;
    err: int = 0;

    # ----------------------------------------------------------
    # Undefined
    # ----------------------------------------------------------
    undef = js_undefined();
    if jsv_is_undefined(undef) {
        ok += 1;
    } else {
        print("FAIL undefined.is_undefined");
        err += 1;
    }
    if not jsv_is_null(undef) {
        ok += 1;
    } else {
        print("FAIL undefined.is_null should be False");
        err += 1;
    }
    if not jsv_is_number(undef) {
        ok += 1;
    } else {
        print("FAIL undefined.is_number should be False");
        err += 1;
    }
    if jsv_is_nullish(undef) {
        ok += 1;
    } else {
        print("FAIL undefined.is_nullish");
        err += 1;
    }
    if _ut_is_primitive(undef) {
        ok += 1;
    } else {
        print("FAIL undefined.is_primitive");
        err += 1;
    }
    if not jsv_coerce_to_bool(undef) {
        ok += 1;
    } else {
        print("FAIL undefined.to_boolean should be False");
        err += 1;
    }
    if jsv_coerce_to_str(undef) == "undefined" {
        ok += 1;
    } else {
        print("FAIL undefined.to_string got", jsv_coerce_to_str(undef));
        err += 1;
    }
    if js_typeof(undef) == "undefined" {
        ok += 1;
    } else {
        print("FAIL typeof undefined got", js_typeof(undef));
        err += 1;
    }

    # ----------------------------------------------------------
    # Null
    # ----------------------------------------------------------
    null_val = js_null();
    if jsv_is_null(null_val) {
        ok += 1;
    } else {
        print("FAIL null.is_null");
        err += 1;
    }
    if not jsv_is_undefined(null_val) {
        ok += 1;
    } else {
        print("FAIL null.is_undefined should be False");
        err += 1;
    }
    if jsv_is_nullish(null_val) {
        ok += 1;
    } else {
        print("FAIL null.is_nullish");
        err += 1;
    }
    if _ut_is_primitive(null_val) {
        ok += 1;
    } else {
        print("FAIL null.is_primitive");
        err += 1;
    }
    if not jsv_coerce_to_bool(null_val) {
        ok += 1;
    } else {
        print("FAIL null.to_boolean should be False");
        err += 1;
    }
    if jsv_coerce_to_number(null_val) == 0.0 {
        ok += 1;
    } else {
        print("FAIL null.to_number got", jsv_coerce_to_number(null_val));
        err += 1;
    }
    if jsv_coerce_to_str(null_val) == "null" {
        ok += 1;
    } else {
        print("FAIL null.to_string got", jsv_coerce_to_str(null_val));
        err += 1;
    }
    if js_typeof(null_val) == "object" {
        ok += 1;
    } else {
        print("FAIL typeof null got", js_typeof(null_val));
        err += 1;
    }

    # ----------------------------------------------------------
    # Boolean
    # ----------------------------------------------------------
    tv = js_true();
    fv = js_false();
    if jsv_is_bool(tv) {
        ok += 1;
    } else {
        print("FAIL true.is_boolean");
        err += 1;
    }
    if jsv_is_bool(fv) {
        ok += 1;
    } else {
        print("FAIL false.is_boolean");
        err += 1;
    }
    if not jsv_is_number(tv) {
        ok += 1;
    } else {
        print("FAIL true.is_number should be False");
        err += 1;
    }
    if _ut_is_primitive(tv) {
        ok += 1;
    } else {
        print("FAIL true.is_primitive");
        err += 1;
    }
    if not jsv_is_nullish(tv) {
        ok += 1;
    } else {
        print("FAIL true.is_nullish should be False");
        err += 1;
    }
    if jsv_coerce_to_bool(tv) {
        ok += 1;
    } else {
        print("FAIL true.to_boolean");
        err += 1;
    }
    if not jsv_coerce_to_bool(fv) {
        ok += 1;
    } else {
        print("FAIL false.to_boolean should be False");
        err += 1;
    }
    if jsv_coerce_to_number(tv) == 1.0 {
        ok += 1;
    } else {
        print("FAIL true.to_number got", jsv_coerce_to_number(tv));
        err += 1;
    }
    if jsv_coerce_to_number(fv) == 0.0 {
        ok += 1;
    } else {
        print("FAIL false.to_number got", jsv_coerce_to_number(fv));
        err += 1;
    }
    if jsv_coerce_to_str(tv) == "true" {
        ok += 1;
    } else {
        print("FAIL true.to_string got", jsv_coerce_to_str(tv));
        err += 1;
    }
    if jsv_coerce_to_str(fv) == "false" {
        ok += 1;
    } else {
        print("FAIL false.to_string got", jsv_coerce_to_str(fv));
        err += 1;
    }
    if js_typeof(tv) == "boolean" {
        ok += 1;
    } else {
        print("FAIL typeof true got", js_typeof(tv));
        err += 1;
    }

    # ----------------------------------------------------------
    # Int32
    # ----------------------------------------------------------
    iv = js_int(42);
    zero_i = js_int(0);
    if jsv_is_number(iv) {
        ok += 1;
    } else {
        print("FAIL int.is_number");
        err += 1;
    }
    if _ut_is_integer(iv) {
        ok += 1;
    } else {
        print("FAIL int.is_integer");
        err += 1;
    }
    if _ut_is_finite(iv) {
        ok += 1;
    } else {
        print("FAIL int.is_finite");
        err += 1;
    }
    if not jsv_is_nan(iv) {
        ok += 1;
    } else {
        print("FAIL int.is_nan should be False");
        err += 1;
    }
    if _ut_is_primitive(iv) {
        ok += 1;
    } else {
        print("FAIL int.is_primitive");
        err += 1;
    }
    if jsv_coerce_to_number(iv) == 42.0 {
        ok += 1;
    } else {
        print("FAIL int.to_number got", jsv_coerce_to_number(iv));
        err += 1;
    }
    if jsv_coerce_to_str(iv) == "42" {
        ok += 1;
    } else {
        print("FAIL int.to_string got", jsv_coerce_to_str(iv));
        err += 1;
    }
    if jsv_coerce_to_bool(iv) {
        ok += 1;
    } else {
        print("FAIL int(42).to_boolean");
        err += 1;
    }
    if not jsv_coerce_to_bool(zero_i) {
        ok += 1;
    } else {
        print("FAIL int(0).to_boolean should be False");
        err += 1;
    }
    if js_typeof(iv) == "number" {
        ok += 1;
    } else {
        print("FAIL typeof int got", js_typeof(iv));
        err += 1;
    }

    # ----------------------------------------------------------
    # Float64 — normal numbers
    # ----------------------------------------------------------
    fnum = js_number(3.14);
    neg = js_number(-7.5);
    zero_f = js_number(0.0);
    if jsv_is_number(fnum) {
        ok += 1;
    } else {
        print("FAIL float.is_number");
        err += 1;
    }
    if _ut_is_finite(fnum) {
        ok += 1;
    } else {
        print("FAIL 3.14.is_finite");
        err += 1;
    }
    if not jsv_is_nan(fnum) {
        ok += 1;
    } else {
        print("FAIL 3.14.is_nan should be False");
        err += 1;
    }
    if jsv_coerce_to_bool(fnum) {
        ok += 1;
    } else {
        print("FAIL 3.14.to_boolean");
        err += 1;
    }
    if not jsv_coerce_to_bool(zero_f) {
        ok += 1;
    } else {
        print("FAIL 0.0.to_boolean should be False");
        err += 1;
    }
    if jsv_coerce_to_bool(neg) {
        ok += 1;
    } else {
        print("FAIL -7.5.to_boolean");
        err += 1;
    }
    if js_typeof(fnum) == "number" {
        ok += 1;
    } else {
        print("FAIL typeof float got", js_typeof(fnum));
        err += 1;
    }
    if _ut_is_integer(js_int(5)) {
        ok += 1;
    } else {
        print("FAIL int(5).is_integer");
        err += 1;
    }
    if _ut_is_integer(js_number(5.0)) {
        ok += 1;
    } else {
        print("FAIL 5.0.is_integer");
        err += 1;
    }
    if not _ut_is_integer(js_number(5.5)) {
        ok += 1;
    } else {
        print("FAIL 5.5.is_integer should be False");
        err += 1;
    }

    # ----------------------------------------------------------
    # NaN
    # ----------------------------------------------------------
    nan_val = js_nan();
    nan_float: float = jsv_coerce_to_number(nan_val);
    if jsv_is_number(nan_val) {
        ok += 1;
    } else {
        print("FAIL nan.is_number");
        err += 1;
    }
    if jsv_is_nan(nan_val) {
        ok += 1;
    } else {
        print("FAIL nan.is_nan");
        err += 1;
    }
    if not _ut_is_finite(nan_val) {
        ok += 1;
    } else {
        print("FAIL nan.is_finite should be False");
        err += 1;
    }
    if not _ut_is_integer(nan_val) {
        ok += 1;
    } else {
        print("FAIL nan.is_integer should be False");
        err += 1;
    }
    if not jsv_coerce_to_bool(nan_val) {
        ok += 1;
    } else {
        print("FAIL nan.to_boolean should be False");
        err += 1;
    }
    if jsv_coerce_to_str(nan_val) == "NaN" {
        ok += 1;
    } else {
        print("FAIL nan.to_string got", jsv_coerce_to_str(nan_val));
        err += 1;
    }
    if not (nan_float == nan_float) {
        ok += 1;
    } else {
        print("FAIL NaN!=NaN should be True");
        err += 1;
    }

    # ----------------------------------------------------------
    # Infinity
    # ----------------------------------------------------------
    inf_val = js_infinity();
    neg_inf = js_neg_infinity();
    if jsv_is_number(inf_val) {
        ok += 1;
    } else {
        print("FAIL inf.is_number");
        err += 1;
    }
    if not _ut_is_finite(inf_val) {
        ok += 1;
    } else {
        print("FAIL inf.is_finite should be False");
        err += 1;
    }
    if not _ut_is_integer(inf_val) {
        ok += 1;
    } else {
        print("FAIL inf.is_integer should be False");
        err += 1;
    }
    if not jsv_is_nan(inf_val) {
        ok += 1;
    } else {
        print("FAIL inf.is_nan should be False");
        err += 1;
    }
    if jsv_coerce_to_bool(inf_val) {
        ok += 1;
    } else {
        print("FAIL inf.to_boolean");
        err += 1;
    }
    if jsv_coerce_to_str(inf_val) == "Infinity" {
        ok += 1;
    } else {
        print("FAIL inf.to_string got", jsv_coerce_to_str(inf_val));
        err += 1;
    }
    if jsv_coerce_to_str(neg_inf) == "-Infinity" {
        ok += 1;
    } else {
        print("FAIL -inf.to_string got", jsv_coerce_to_str(neg_inf));
        err += 1;
    }

    # ----------------------------------------------------------
    # is_nullish / is_primitive
    # ----------------------------------------------------------
    if jsv_is_nullish(js_undefined()) {
        ok += 1;
    } else {
        print("FAIL undefined.is_nullish");
        err += 1;
    }
    if jsv_is_nullish(js_null()) {
        ok += 1;
    } else {
        print("FAIL null.is_nullish");
        err += 1;
    }
    if not jsv_is_nullish(js_true()) {
        ok += 1;
    } else {
        print("FAIL true.is_nullish should be False");
        err += 1;
    }
    if not jsv_is_nullish(js_number(1.0)) {
        ok += 1;
    } else {
        print("FAIL 1.0.is_nullish should be False");
        err += 1;
    }
    if _ut_is_primitive(js_undefined()) {
        ok += 1;
    } else {
        print("FAIL undefined.is_primitive");
        err += 1;
    }
    if _ut_is_primitive(js_null()) {
        ok += 1;
    } else {
        print("FAIL null.is_primitive");
        err += 1;
    }
    if _ut_is_primitive(js_true()) {
        ok += 1;
    } else {
        print("FAIL true.is_primitive");
        err += 1;
    }
    if _ut_is_primitive(js_number(1.0)) {
        ok += 1;
    } else {
        print("FAIL 1.0.is_primitive");
        err += 1;
    }

    # ----------------------------------------------------------
    # Strict equality (===)
    # ----------------------------------------------------------
    if js_strict_equal(js_number(42.0), js_number(42.0)) {
        ok += 1;
    } else {
        print("FAIL 42.0===42.0");
        err += 1;
    }
    if not js_strict_equal(js_number(42.0), js_number(43.0)) {
        ok += 1;
    } else {
        print("FAIL 42.0===43.0 should be False");
        err += 1;
    }
    if not js_strict_equal(js_nan(), js_nan()) {
        ok += 1;
    } else {
        print("FAIL NaN===NaN should be False");
        err += 1;
    }
    if js_strict_equal(js_undefined(), js_undefined()) {
        ok += 1;
    } else {
        print("FAIL undef===undef");
        err += 1;
    }
    if js_strict_equal(js_null(), js_null()) {
        ok += 1;
    } else {
        print("FAIL null===null");
        err += 1;
    }
    if not js_strict_equal(js_null(), js_undefined()) {
        ok += 1;
    } else {
        print("FAIL null===undef should be False");
        err += 1;
    }
    if js_strict_equal(js_true(), js_true()) {
        ok += 1;
    } else {
        print("FAIL true===true");
        err += 1;
    }
    if not js_strict_equal(js_true(), js_false()) {
        ok += 1;
    } else {
        print("FAIL true===false should be False");
        err += 1;
    }
    if js_strict_equal(js_int(5), js_int(5)) {
        ok += 1;
    } else {
        print("FAIL int(5)===int(5)");
        err += 1;
    }
    if not js_strict_equal(js_int(5), js_int(6)) {
        ok += 1;
    } else {
        print("FAIL int(5)===int(6) should be False");
        err += 1;
    }
    if js_strict_equal(js_int(1), js_number(1.0)) {
        ok += 1;
    } else {
        print("FAIL int(1)===float(1.0) should be True (same Number value)");
        err += 1;
    }

    # ----------------------------------------------------------
    # Abstract equality (==)
    # ----------------------------------------------------------
    if js_abstract_equal(js_null(), js_undefined()) {
        ok += 1;
    } else {
        print("FAIL null==undef");
        err += 1;
    }
    if js_abstract_equal(js_undefined(), js_null()) {
        ok += 1;
    } else {
        print("FAIL undef==null");
        err += 1;
    }
    if not js_abstract_equal(js_null(), js_false()) {
        ok += 1;
    } else {
        print("FAIL null==false should be False");
        err += 1;
    }
    if js_abstract_equal(js_true(), js_true()) {
        ok += 1;
    } else {
        print("FAIL true==true");
        err += 1;
    }
    if js_abstract_equal(js_number(1.0), js_number(1.0)) {
        ok += 1;
    } else {
        print("FAIL 1.0==1.0");
        err += 1;
    }

    # ----------------------------------------------------------
    # typeof
    # ----------------------------------------------------------
    if js_typeof(js_undefined()) == "undefined" {
        ok += 1;
    } else {
        print("FAIL typeof undefined got", js_typeof(js_undefined()));
        err += 1;
    }
    if js_typeof(js_null()) == "object" {
        ok += 1;
    } else {
        print("FAIL typeof null got", js_typeof(js_null()));
        err += 1;
    }
    if js_typeof(js_true()) == "boolean" {
        ok += 1;
    } else {
        print("FAIL typeof true got", js_typeof(js_true()));
        err += 1;
    }
    if js_typeof(js_int(1)) == "number" {
        ok += 1;
    } else {
        print("FAIL typeof int(1) got", js_typeof(js_int(1)));
        err += 1;
    }
    if js_typeof(js_number(1.0)) == "number" {
        ok += 1;
    } else {
        print("FAIL typeof 1.0 got", js_typeof(js_number(1.0)));
        err += 1;
    }
    if js_typeof(js_nan()) == "number" {
        ok += 1;
    } else {
        print("FAIL typeof NaN got", js_typeof(js_nan()));
        err += 1;
    }

    # ----------------------------------------------------------
    # NaN-boxing edge cases. These go through __float_bits and 64-bit
    # mask/shift arithmetic, so they pin the native backend's handling of
    # wide hex literals and float<->bits reinterpretation.
    # ----------------------------------------------------------
    # x86 produces a sign-bit NaN (0xFFF8…) for inf-inf; unboxed it would land
    # in the tag space above 0xFFFE…, so boxing must canonicalise every NaN.
    neg_nan: JSValue = js_number(MATH_INF - MATH_INF);
    if jsv_is_nan(neg_nan) and jsv_is_double(neg_nan) {
        ok += 1;
    } else {
        print("FAIL inf-inf NaN not canonical, bits=", neg_nan);
        err += 1;
    }
    if jsv_is_nan(js_number(-MATH_NAN)) {
        ok += 1;
    } else {
        print("FAIL -NaN not canonical");
        err += 1;
    }
    if jsv_is_nan(js_number(MATH_NAN * 0.0)) {
        ok += 1;
    } else {
        print("FAIL NaN*0 not canonical");
        err += 1;
    }
    # -0 must survive boxing. Jac float division by zero raises (Python
    # semantics), so the sign is checked through the boxed bits and the
    # formatted value, as the engine's own _is_negative_zero does.
    nz: JSValue = js_number(-0.0);
    if jsv_is_double(nz) and nz != js_number(0.0) {
        ok += 1;
    } else {
        print("FAIL -0 boxed like +0, bits=", nz);
        err += 1;
    }
    nzd: float = jsv_to_double(nz);
    if nzd == 0.0 and str(nzd).startswith("-") {
        ok += 1;
    } else {
        print("FAIL -0 lost its sign on unbox:", str(nzd));
        err += 1;
    }
    # Int32 payload is 32 bits wide and sign-extends on unbox.
    if jsv_is_int32(js_int(2147483647))
        and jsv_to_int32(js_int(2147483647)) == 2147483647 {
        ok += 1;
    } else {
        print("FAIL int32 max round-trip");
        err += 1;
    }
    if jsv_to_int32(js_int(-2147483648)) == -2147483648 {
        ok += 1;
    } else {
        print("FAIL int32 min round-trip got", jsv_to_int32(js_int(-2147483648)));
        err += 1;
    }
    if jsv_to_int32(js_int(-1)) == -1 {
        ok += 1;
    } else {
        print("FAIL int32 -1 round-trip got", jsv_to_int32(js_int(-1)));
        err += 1;
    }
    # Doubles at the edges of the encoding round-trip bit-exactly.
    for d in [
        5e-324,
        2.2250738585072014e-308,
        1.7976931348623157e308,
        -1.7976931348623157e308,
        0.1,
        -2.5
    ] {
        bx: JSValue = js_number(d);
        if jsv_is_double(bx) and jsv_to_double(bx) == d {
            ok += 1;
        } else {
            print("FAIL double round-trip", d);
            err += 1;
        }
    }
    if jsv_is_double(js_number(MATH_INF))
        and jsv_to_double(js_number(MATH_INF)) == MATH_INF {
        ok += 1;
    } else {
        print("FAIL +Infinity round-trip");
        err += 1;
    }
    if jsv_to_double(js_number(MATH_NEG_INF)) == MATH_NEG_INF {
        ok += 1;
    } else {
        print("FAIL -Infinity round-trip");
        err += 1;
    }
    if not jsv_is_nan(js_number(MATH_INF)) {
        ok += 1;
    } else {
        print("FAIL Infinity boxed as NaN");
        err += 1;
    }

    print("jsvalue smoke:", ok, "passed,", err, "failed");
    if err > 0 {
        fflush(0);
        _exit(1);
    }
}
