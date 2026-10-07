import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_from_bool,
    jsv_from_double,
    jsv_from_int32,
    jsv_is_null,
    jsv_is_undefined,
    jsv_null,
    jsv_to_bool,
    jsv_to_double,
    jsv_to_int32
}
import from engine.src.runtime.heap { JSHandle, js_handle, StrongRef, js_strong_ref }

# ═══════════════════════════════════════════════════════════════════════════════
# Smoke tests
# ═══════════════════════════════════════════════════════════════════════════════
with entry {
    ok: int = 0;
    err: int = 0;

    # ── JSHandle ────────────────────────────────────────────────────────────

    v_int: JSValue = jsv_from_int32(42);
    hnd: JSHandle = js_handle(v_int);
    got: JSValue = hnd.get();
    if jsv_to_int32(got) == 42 {
        ok += 1;
    } else {
        print("FAIL JSHandle create/get Int32 got", jsv_to_int32(got));
        err += 1;
    }

    v_bool: JSValue = jsv_from_bool(True);
    hnd.set(v_bool);
    got2: JSValue = hnd.get();
    if jsv_to_bool(got2) == True {
        ok += 1;
    } else {
        print("FAIL JSHandle.set Boolean");
        err += 1;
    }

    hnd.release();
    got3: JSValue = hnd.get();
    if jsv_is_undefined(got3) {
        ok += 1;
    } else {
        print("FAIL JSHandle.release got tag", got3);
        err += 1;
    }

    # ── StrongRef ───────────────────────────────────────────────────────────

    v_float: JSValue = jsv_from_double(2.71828);
    sref: StrongRef = js_strong_ref(v_float);
    sg: JSValue = sref.get();
    if jsv_to_double(sg) == 2.71828 {
        ok += 1;
    } else {
        print("FAIL StrongRef create/get Float64 got", jsv_to_double(sg));
        err += 1;
    }

    v_null: JSValue = jsv_null();
    sref.set(v_null);
    sg2: JSValue = sref.get();
    if jsv_is_null(sg2) {
        ok += 1;
    } else {
        print("FAIL StrongRef.set Null got tag", sg2);
        err += 1;
    }

    sref.deinit();
    sg3: JSValue = sref.get();
    if jsv_is_undefined(sg3) {
        ok += 1;
    } else {
        print("FAIL StrongRef.deinit got tag", sg3);
        err += 1;
    }

    # ── Independent handles don't alias ─────────────────────────────────────

    va: JSValue = jsv_from_int32(10);
    vb: JSValue = jsv_from_int32(20);
    ha: JSHandle = js_handle(va);
    hb: JSHandle = js_handle(vb);
    ha.set(jsv_from_int32(99));
    if jsv_to_int32(hb.get()) == 20 {
        ok += 1;
    } else {
        print("FAIL independent handles no alias got", jsv_to_int32(hb.get()));
        err += 1;
    }

    print("heap smoke:", ok, "passed,", err, "failed");
}
