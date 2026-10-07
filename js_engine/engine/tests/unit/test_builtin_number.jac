"""
Smoke tests: Number & Boolean built-ins

Covers: constructors, static methods, prototype methods, global functions.
Run with: jac run tests/test_builtin_number.na.jac
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_true,
    js_false,
    js_int,
    js_number,
    js_nan,
    js_infinity,
    jsv_from_string_id,
    jsv_is_double,
    jsv_is_int32,
    jsv_to_bool,
    jsv_to_double,
    jsv_to_int32,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.global { global_context_create, init_global }
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.builtins.number {
    js_Number_call,
    js_Number_new,
    is_number_object,
    number_value_of,
    js_Number_isNaN,
    js_Number_isFinite,
    js_Number_isInteger,
    js_Number_isSafeInteger,
    js_Number_parseFloat,
    js_Number_parseInt,
    js_Number_MAX_VALUE,
    js_Number_MIN_VALUE,
    js_Number_EPSILON,
    js_Number_MAX_SAFE_INTEGER,
    js_Number_MIN_SAFE_INTEGER,
    js_Number_POSITIVE_INFINITY,
    js_Number_NEGATIVE_INFINITY,
    js_Number_NaN,
    js_num_toFixed,
    js_num_toPrecision,
    js_num_toExponential,
    js_num_toString,
    js_num_valueOf,
    js_Boolean_call,
    js_Boolean_new,
    is_boolean_object,
    js_Boolean_prototype_toString,
    js_Boolean_prototype_valueOf,
    js_parseInt,
    js_parseFloat,
    js_isNaN,
    js_isFinite,
    js_neg_infinity
}

# ══════════════════════════════════════════════════════════════════════════════
# 12.  Smoke tests
# ══════════════════════════════════════════════════════════════════════════════
with entry {
    # Engine startup: wire every module's realm singleton and install the
    # builtin prototypes. Builtins read realm state (string table, protos).
    ctx = global_context_create();
    init_global(ctx);

    ok: int = 0;
    fail: int = 0;

    # ── 1: Number(v) primitive coercion ──────────────────────────────────
    n1: JSValue = js_Number_call([js_int(42)]);
    if jsv_is_int32(n1) and jsv_to_int32(n1) == 42 {
        ok += 1;
        print("OK  Number(42) = 42");
    } else {
        fail += 1;
        print("FAIL Number(42) tag=", n1);
    }

    # ── 2: Number("3.14") ─────────────────────────────────────────────────
    sv: JSValue = jsv_from_string_id(str_intern("3.14"));
    n2: JSValue = js_Number_call([sv]);
    if jsv_is_double(n2) {
        ok += 1;
        print("OK  Number('3.14') = 3.14");
    } else {
        fail += 1;
        print("FAIL Number('3.14') tag=", n2);
    }

    # ── 3: Number() → 0 ───────────────────────────────────────────────────
    n3: JSValue = js_Number_call([]);
    if jsv_is_int32(n3) and jsv_to_int32(n3) == 0 {
        ok += 1;
        print("OK  Number() = 0");
    } else {
        fail += 1;
        print("FAIL Number() got tag=", n3);
    }

    # ── 4: Number(undefined) → NaN ────────────────────────────────────────
    n4: JSValue = js_Number_call([js_undefined()]);
    if jsv_is_double(n4) {
        f4: float = jsv_to_double(n4);
        if not (f4 == f4) {
            ok += 1;
            print("OK  Number(undefined) = NaN");
        } else {
            fail += 1;
            print("FAIL Number(undefined) not NaN");
        }
    } else {
        fail += 1;
        print("FAIL Number(undefined) tag=", n4);
    }

    # ── 5: Number(true) → 1, Number(false) → 0 ───────────────────────────
    n5a: JSValue = js_Number_call([js_true()]);
    n5b: JSValue = js_Number_call([js_false()]);
    if jsv_to_int32(n5a) == 1 and jsv_to_int32(n5b) == 0 {
        ok += 1;
        print("OK  Number(true)=1 Number(false)=0");
    } else {
        fail += 1;
        print("FAIL Number(bool)");
    }

    # ── 6: new Number(v) returns object ───────────────────────────────────
    nw6: JSValue = js_Number_new([js_int(7)]);
    if is_number_object(nw6) {
        ok += 1;
        print("OK  new Number(7) is a Number object");
    } else {
        fail += 1;
        print("FAIL new Number object tag=", nw6);
    }

    # ── 7: number_value_of extracts primitive ─────────────────────────────
    nw7: JSValue = js_Number_new([js_number(1.5)]);
    prim7: JSValue = number_value_of(nw7);
    if jsv_is_double(prim7) and jsv_to_double(prim7) == 1.5 {
        ok += 1;
        print("OK  number_value_of(new Number(1.5)) = 1.5");
    } else {
        fail += 1;
        print("FAIL number_value_of");
    }

    # ── 8: Number.isNaN ───────────────────────────────────────────────────
    nn8: JSValue = js_nan();
    if jsv_to_bool(js_Number_isNaN([nn8]))
        and not jsv_to_bool(js_Number_isNaN([js_int(1)])) {
        ok += 1;
        print("OK  Number.isNaN");
    } else {
        fail += 1;
        print("FAIL Number.isNaN");
    }

    # ── 9: Number.isFinite ────────────────────────────────────────────────
    ni9: JSValue = js_infinity();
    if not jsv_to_bool(js_Number_isFinite([ni9]))
        and jsv_to_bool(js_Number_isFinite([js_int(5)])) {
        ok += 1;
        print("OK  Number.isFinite");
    } else {
        fail += 1;
        print("FAIL Number.isFinite");
    }

    # ── 10: Number.isInteger ──────────────────────────────────────────────
    if jsv_to_bool(js_Number_isInteger([js_int(3)]))
        and not jsv_to_bool(js_Number_isInteger([js_number(3.5)])) {
        ok += 1;
        print("OK  Number.isInteger");
    } else {
        fail += 1;
        print("FAIL Number.isInteger");
    }

    # ── 11: Number.isSafeInteger ──────────────────────────────────────────
    big11: JSValue = js_number(9007199254740992.0);  # 2^53 — exceeds safe range
    if jsv_to_bool(js_Number_isSafeInteger([js_int(1)]))
        and not jsv_to_bool(js_Number_isSafeInteger([big11])) {
        ok += 1;
        print("OK  Number.isSafeInteger");
    } else {
        fail += 1;
        print("FAIL Number.isSafeInteger");
    }

    # ── 12: toFixed ───────────────────────────────────────────────────────
    tf12: JSValue = js_num_toFixed(js_number(3.14159), [js_int(2)]);
    if str_from_id(jsv_to_table_id(tf12)) == "3.14" {
        ok += 1;
        print("OK  (3.14159).toFixed(2) = '3.14'");
    } else {
        fail += 1;
        print("FAIL toFixed got='", str_from_id(jsv_to_table_id(tf12)), "'");
    }

    # ── 13: toFixed(0) ────────────────────────────────────────────────────
    tf13: JSValue = js_num_toFixed(js_number(3.7), [js_int(0)]);
    if str_from_id(jsv_to_table_id(tf13)) == "4" {
        ok += 1;
        print("OK  (3.7).toFixed(0) = '4'");
    } else {
        fail += 1;
        print("FAIL toFixed(0) got='", str_from_id(jsv_to_table_id(tf13)), "'");
    }

    # ── 14: toString(2) — binary ──────────────────────────────────────────
    ts14: JSValue = js_num_toString(js_int(10), [js_int(2)]);
    if str_from_id(jsv_to_table_id(ts14)) == "1010" {
        ok += 1;
        print("OK  (10).toString(2) = '1010'");
    } else {
        fail += 1;
        print("FAIL toString(2) got='", str_from_id(jsv_to_table_id(ts14)), "'");
    }

    # ── 15: toString(16) — hex ────────────────────────────────────────────
    ts15: JSValue = js_num_toString(js_int(255), [js_int(16)]);
    if str_from_id(jsv_to_table_id(ts15)) == "ff" {
        ok += 1;
        print("OK  (255).toString(16) = 'ff'");
    } else {
        fail += 1;
        print("FAIL toString(16) got='", str_from_id(jsv_to_table_id(ts15)), "'");
    }

    # ── 16: parseInt decimal ──────────────────────────────────────────────
    pi16sv: JSValue = jsv_from_string_id(str_intern("42"));
    pi16: JSValue = js_parseInt([pi16sv]);
    if jsv_is_int32(pi16) and jsv_to_int32(pi16) == 42 {
        ok += 1;
        print("OK  parseInt('42') = 42");
    } else {
        fail += 1;
        print("FAIL parseInt('42') got=", jsv_to_int32(pi16));
    }

    # ── 17: parseInt hex ──────────────────────────────────────────────────
    pi17sv: JSValue = jsv_from_string_id(str_intern("0xff"));
    pi17: JSValue = js_parseInt([pi17sv]);
    if jsv_is_int32(pi17) and jsv_to_int32(pi17) == 255 {
        ok += 1;
        print("OK  parseInt('0xff') = 255");
    } else {
        fail += 1;
        print("FAIL parseInt('0xff') got=", jsv_to_int32(pi17));
    }

    # ── 18: parseInt with radix ───────────────────────────────────────────
    pi18sv: JSValue = jsv_from_string_id(str_intern("1010"));
    pi18: JSValue = js_parseInt([pi18sv, js_int(2)]);
    if jsv_is_int32(pi18) and jsv_to_int32(pi18) == 10 {
        ok += 1;
        print("OK  parseInt('1010', 2) = 10");
    } else {
        fail += 1;
        print("FAIL parseInt('1010',2) got=", jsv_to_int32(pi18));
    }

    # ── 19: parseInt NaN on invalid ───────────────────────────────────────
    pi19sv: JSValue = jsv_from_string_id(str_intern("abc"));
    pi19: JSValue = js_parseInt([pi19sv, js_int(10)]);
    if jsv_is_double(pi19) {
        f19: float = jsv_to_double(pi19);
        if not (f19 == f19) {
            ok += 1;
            print("OK  parseInt('abc',10) = NaN");
        } else {
            fail += 1;
            print("FAIL parseInt NaN check");
        }
    } else {
        fail += 1;
        print("FAIL parseInt NaN tag=", pi19);
    }

    # ── 20: parseFloat ────────────────────────────────────────────────────
    pf20sv: JSValue = jsv_from_string_id(str_intern("2.718"));
    pf20: JSValue = js_parseFloat([pf20sv]);
    if jsv_is_double(pf20)
        and jsv_to_double(pf20) > 2.71
        and jsv_to_double(pf20) < 2.72 {
        ok += 1;
        print("OK  parseFloat('2.718') ~ 2.718");
    } else {
        fail += 1;
        print("FAIL parseFloat('2.718') got tag=", pf20);
    }

    # ── 21: isNaN and isFinite globals ────────────────────────────────────
    if jsv_to_bool(js_isNaN([js_nan()])) and not jsv_to_bool(js_isNaN([js_int(0)])) {
        ok += 1;
        print("OK  isNaN");
    } else {
        fail += 1;
        print("FAIL isNaN");
    }

    if jsv_to_bool(js_isFinite([js_int(1)]))
        and not jsv_to_bool(js_isFinite([js_infinity()])) {
        ok += 1;
        print("OK  isFinite");
    } else {
        fail += 1;
        print("FAIL isFinite");
    }

    # ── 22: Boolean(v) coercion ───────────────────────────────────────────
    bv22: JSValue = js_Boolean_call([js_int(0)]);
    bv22t: JSValue = js_Boolean_call([js_int(1)]);
    if not jsv_to_bool(bv22) and jsv_to_bool(bv22t) {
        ok += 1;
        print("OK  Boolean(0)=false Boolean(1)=true");
    } else {
        fail += 1;
        print("FAIL Boolean coercion");
    }

    # ── 23: Boolean("") → false, Boolean("x") → true ─────────────────────
    empty_sv: JSValue = jsv_from_string_id(str_intern(""));
    x_sv: JSValue = jsv_from_string_id(str_intern("x"));
    bv23a: JSValue = js_Boolean_call([empty_sv]);
    bv23b: JSValue = js_Boolean_call([x_sv]);
    if not jsv_to_bool(bv23a) and jsv_to_bool(bv23b) {
        ok += 1;
        print("OK  Boolean('')=false Boolean('x')=true");
    } else {
        fail += 1;
        print("FAIL Boolean string coercion");
    }

    # ── 24: new Boolean(v) returns object ────────────────────────────────
    bw24: JSValue = js_Boolean_new([js_true()]);
    if is_boolean_object(bw24) {
        ok += 1;
        print("OK  new Boolean(true) is Boolean object");
    } else {
        fail += 1;
        print("FAIL new Boolean object");
    }

    # ── 25: Boolean.prototype.toString ───────────────────────────────────
    bt25: JSValue = js_Boolean_prototype_toString(js_true());
    bf25: JSValue = js_Boolean_prototype_toString(js_false());
    if str_from_id(jsv_to_table_id(bt25)) == "true"
        and str_from_id(jsv_to_table_id(bf25)) == "false" {
        ok += 1;
        print("OK  Boolean.prototype.toString");
    } else {
        fail += 1;
        print("FAIL Boolean.prototype.toString");
    }

    # ── 26: Number.MAX_VALUE / Number.EPSILON ────────────────────────────
    mv26: JSValue = js_Number_MAX_VALUE();
    ep26: JSValue = js_Number_EPSILON();
    if jsv_is_double(mv26) and jsv_is_double(ep26) {
        ok += 1;
        print("OK  Number.MAX_VALUE and Number.EPSILON");
    } else {
        fail += 1;
        print("FAIL Number constants");
    }

    # ── 27: toExponential ────────────────────────────────────────────────
    te27: JSValue = js_num_toExponential(js_number(12345.0), [js_int(2)]);
    te27_s: str = str_from_id(jsv_to_table_id(te27));
    if len(te27_s) > 0 and te27_s[0] == "1" {
        ok += 1;
        print("OK  (12345).toExponential(2) =", te27_s);
    } else {
        fail += 1;
        print("FAIL toExponential got='", te27_s, "'");
    }

    print("number smoke: passed=", ok, "failed=", fail);
    if fail > 0 {
        fflush(0);
        _exit(1);
    }
}
