"""Global Object Bootstrap smoke tests.

Integration tests for runtime/global.na.jac.
Run with: jac run tests/test_global.na.jac
"""

import from engine.src.runtime.global {
    JSGlobalObject,
    GlobalContext,
    global_context_create,
    init_global,
    get_global,
    set_global,
    has_global,
    throw_exception,
    clear_exception,
    has_exception
}
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_boolean,
    js_number,
    js_nan,
    js_infinity,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_to_double
}
import from engine.src.runtime.jsobject { js_object_get }
import from engine.src.runtime.jsstring { str_intern }

with entry {
    ok: int = 0;
    err: int = 0;

    # ── 1 — global_context_create returns a usable context ───────────────────
    ctx: GlobalContext = global_context_create();
    if jsv_is_object_cell(ctx.global_obj.object) {
        print("OK  global_context_create: object tag = Object");
        ok = ok + 1;
    } else {
        print("FAIL  global_context_create: bad tag");
        err = err + 1;
    }

    # ── 2 — no pending exception initially ───────────────────────────────────
    if has_exception(ctx) == False {
        print("OK  has_exception: False initially");
        ok = ok + 1;
    } else {
        print("FAIL  has_exception: True before init");
        err = err + 1;
    }

    # ── 3 — init_global runs without crashing ────────────────────────────────
    init_global(ctx);
    if jsv_is_object_cell(ctx.global_obj.object) {
        print("OK  init_global: global object still valid");
        ok = ok + 1;
    } else {
        print("FAIL  init_global: global object corrupted");
        err = err + 1;
    }

    # ── 4 — undefined is registered ──────────────────────────────────────────
    k_undef: int = str_intern("undefined");
    v_undef: JSValue = get_global(ctx, k_undef);
    if jsv_is_undefined(v_undef) {
        print("OK  undefined: tag = Undefined");
        ok = ok + 1;
    } else {
        print("FAIL  undefined: tag =", v_undef);
        err = err + 1;
    }

    # ── 5 — NaN is registered ────────────────────────────────────────────────
    k_nan: int = str_intern("NaN");
    v_nan: JSValue = get_global(ctx, k_nan);
    if jsv_is_double(v_nan) {
        print("OK  NaN: tag = Float64");
        ok = ok + 1;
    } else {
        print("FAIL  NaN: tag =", v_nan);
        err = err + 1;
    }

    # ── 6 — Infinity is registered ───────────────────────────────────────────
    k_inf: int = str_intern("Infinity");
    v_inf: JSValue = get_global(ctx, k_inf);
    if jsv_is_double(v_inf) {
        print("OK  Infinity: tag = Float64");
        ok = ok + 1;
    } else {
        print("FAIL  Infinity: tag =", v_inf);
        err = err + 1;
    }

    # ── 7 — globalThis points to the global object ───────────────────────────
    k_gt: int = str_intern("globalThis");
    v_gt: JSValue = get_global(ctx, k_gt);
    if jsv_is_object_cell(v_gt) {
        print("OK  globalThis: tag = Object");
        ok = ok + 1;
    } else {
        print("FAIL  globalThis: tag =", v_gt);
        err = err + 1;
    }

    # ── 8 — Math is registered as an Object ──────────────────────────────────
    k_math: int = str_intern("Math");
    v_math: JSValue = get_global(ctx, k_math);
    if jsv_is_object_cell(v_math) {
        print("OK  Math: tag = Object");
        ok = ok + 1;
    } else {
        print("FAIL  Math: tag =", v_math);
        err = err + 1;
    }

    # ── 9 — Math.PI ───────────────────────────────────────────────────────────
    k_pi: int = str_intern("PI");
    v_pi: JSValue = js_object_get(v_math, k_pi);
    if jsv_is_double(v_pi)
        and jsv_to_double(v_pi) > 3.14
        and jsv_to_double(v_pi) < 3.15 {
        print("OK  Math.PI =", jsv_to_double(v_pi));
        ok = ok + 1;
    } else {
        print("FAIL  Math.PI: tag =", v_pi, "val =", jsv_to_double(v_pi));
        err = err + 1;
    }

    # ── 10 — Math.E ──────────────────────────────────────────────────────────
    k_e: int = str_intern("E");
    v_e: JSValue = js_object_get(v_math, k_e);
    if jsv_is_double(v_e) and jsv_to_double(v_e) > 2.71 and jsv_to_double(v_e) < 2.72 {
        print("OK  Math.E =", jsv_to_double(v_e));
        ok = ok + 1;
    } else {
        print("FAIL  Math.E: tag =", v_e, "val =", jsv_to_double(v_e));
        err = err + 1;
    }

    # ── 11 — console is registered as an Object ──────────────────────────────
    k_console: int = str_intern("console");
    v_console: JSValue = get_global(ctx, k_console);
    if jsv_is_object_cell(v_console) {
        print("OK  console: tag = Object");
        ok = ok + 1;
    } else {
        print("FAIL  console: tag =", v_console);
        err = err + 1;
    }

    # ── 12 — JSON is registered as an Object ──────────────────────────────────
    k_json: int = str_intern("JSON");
    v_json: JSValue = get_global(ctx, k_json);
    if jsv_is_object_cell(v_json) {
        print("OK  JSON: tag = Object");
        ok = ok + 1;
    } else {
        print("FAIL  JSON: tag =", v_json);
        err = err + 1;
    }

    # ── 13 — has_global: known key returns True ──────────────────────────────
    if has_global(ctx, k_math) == True {
        print("OK  has_global(Math) = True");
        ok = ok + 1;
    } else {
        print("FAIL  has_global(Math) = False");
        err = err + 1;
    }

    # ── 14 — has_global: unknown key returns False ────────────────────────────
    k_missing: int = str_intern("__no_such_key__");
    if has_global(ctx, k_missing) == False {
        print("OK  has_global(__no_such_key__) = False");
        ok = ok + 1;
    } else {
        print("FAIL  has_global(__no_such_key__) = True unexpectedly");
        err = err + 1;
    }

    # ── 15 — set_global / get_global round-trip ───────────────────────────────
    k_custom: int = str_intern("__custom__");
    set_global(ctx, k_custom, js_number(42.0));
    v_custom: JSValue = get_global(ctx, k_custom);
    if jsv_is_double(v_custom) and jsv_to_double(v_custom) == 42.0 {
        print("OK  set_global/get_global round-trip =", jsv_to_double(v_custom));
        ok = ok + 1;
    } else {
        print(
            "FAIL  set_global/get_global: tag =",
            v_custom,
            "val =",
            jsv_to_double(v_custom)
        );
        err = err + 1;
    }

    # ── 16 — throw_exception sets pending exception ───────────────────────────
    err_val: JSValue = js_number(500.0);
    throw_exception(ctx, err_val);
    if has_exception(ctx) == True {
        print("OK  throw_exception: has_exception = True");
        ok = ok + 1;
    } else {
        print("FAIL  throw_exception: has_exception still False");
        err = err + 1;
    }

    # ── 17 — clear_exception clears it ───────────────────────────────────────
    clear_exception(ctx);
    if has_exception(ctx) == False {
        print("OK  clear_exception: has_exception = False");
        ok = ok + 1;
    } else {
        print("FAIL  clear_exception: has_exception still True");
        err = err + 1;
    }

    # ── 18 — stack_depth starts at 0 ─────────────────────────────────────────
    if ctx.stack_depth == 0 {
        print("OK  stack_depth = 0");
        ok = ok + 1;
    } else {
        print("FAIL  stack_depth =", ctx.stack_depth);
        err = err + 1;
    }

    # ── 19 — uv_loop_ptr starts at 0 ─────────────────────────────────────────
    if ctx.global_obj.uv_loop_ptr == 0 {
        print("OK  uv_loop_ptr = 0 (not yet wired)");
        ok = ok + 1;
    } else {
        print("FAIL  uv_loop_ptr =", ctx.global_obj.uv_loop_ptr);
        err = err + 1;
    }

    print("global smoke:", ok, "passed,", err, "failed");
}
