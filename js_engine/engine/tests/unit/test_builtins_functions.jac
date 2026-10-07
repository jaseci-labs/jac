import from engine.src.runtime.global {
    GlobalContext,
    global_context_create,
    init_global,
    run_script
}
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_int,
    js_undefined,
    js_null,
    jsv_from_string_id,
    jsv_is_double,
    jsv_is_int32,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_to_int32,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_set,
    KEY_LENGTH
}
import from engine.src.bytecode.op { CompiledFunction, make_compiled_fn }
import from engine.src.builtins.function {
    js_function_create,
    is_fn_val,
    js_fn_get_name,
    js_fn_get_length,
    js_fn_get_prototype,
    js_function_call,
    js_builtin_create,
    is_builtin_val,
    get_builtin_idx,
    js_Function,
    js_Function_prototype_toString,
    js_Function_prototype_call,
    js_Function_prototype_apply,
    js_Function_prototype_bind
}

"""Create a string JSValue from a plain Jac string."""
def _tstr(s: str) -> JSValue {
    return jsv_from_string_id(str_intern(s));
}

"""Evaluate JS source in `ctx` and return the function it declares as `fname`
(the script's completion value). Goes through run_script, the engine's own
parse+compile+VM path, so the function is compiled with source text and the
context's global object exactly as in a real run."""
def _compile_fn(ctx: GlobalContext, js_src: str, fname: str) -> JSValue {
    return run_script(ctx, js_src + "\n" + fname + ";");
}

# ══════════════════════════════════════════════════════════════════════════════
# Smoke tests
# ══════════════════════════════════════════════════════════════════════════════
with entry {
    # Engine startup: wire every module's realm singleton and install the
    # builtin prototypes, as the runtime does before running any script.
    ctx = global_context_create();
    init_global(ctx);

    ok: int = 0;
    fail: int = 0;

    # ── 1: js_function_create → is_fn_val ────────────────────────────────
    stub1: CompiledFunction = make_compiled_fn("greet", "test.js");
    fn1: JSValue = js_function_create(stub1, []);
    if is_fn_val(fn1) {
        ok += 1;
        print("OK  js_function_create → is_fn_val");
    } else {
        fail += 1;
        print("FAIL js_function_create tag=", fn1, " ptr=", jsv_to_table_id(fn1));
    }

    # ── 2: metadata — name  ──────────────────────────────────────────────
    name1: str = js_fn_get_name(fn1);
    if name1 == "greet" {
        ok += 1;
        print("OK  js_fn_get_name = 'greet'");
    } else {
        fail += 1;
        print("FAIL js_fn_get_name got='", name1, "'");
    }

    # ── 3: metadata — length (param count) ───────────────────────────────
    # make_compiled_fn creates a fn with no params → length = 0
    len1: int = js_fn_get_length(fn1);
    if len1 == 0 {
        ok += 1;
        print("OK  js_fn_get_length = 0");
    } else {
        fail += 1;
        print("FAIL js_fn_get_length got=", len1);
    }

    # ── 4: js_function_call — invoke a VM-compiled function ──────────────
    sq_val: JSValue = _compile_fn(ctx, "function sq(x) { return x * x; }", "sq");
    res4: JSValue = js_function_call(sq_val, js_undefined(), [js_int(7)]);
    if jsv_is_int32(res4) and jsv_to_int32(res4) == 49 {
        ok += 1;
        print("OK  js_function_call sq(7) = 49");
    } else {
        fail += 1;
        print("FAIL js_function_call sq(7) tag=", res4, " int=", jsv_to_int32(res4));
    }

    # ── 5: js_function_call — multi-arg function ─────────────────────────
    add_val: JSValue = _compile_fn(ctx, "function add(a,b) { return a+b; }", "add");
    res5: JSValue = js_function_call(add_val, js_undefined(), [js_int(3), js_int(4)]);
    if jsv_is_int32(res5) and jsv_to_int32(res5) == 7 {
        ok += 1;
        print("OK  js_function_call add(3,4) = 7");
    } else {
        fail += 1;
        print("FAIL js_function_call add(3,4) tag=", res5, " int=", jsv_to_int32(res5));
    }

    # ── 6: js_Function_prototype_toString — built-in source ──────────────
    s6: JSValue = js_Function_prototype_toString(fn1);
    if jsv_is_string_cell(s6) {
        ok += 1;
        print("OK  Function.prototype.toString returns String");
    } else {
        fail += 1;
        print("FAIL .toString() tag=", s6);
    }

    # ── 7: js_Function_prototype_toString — contains function name ────────
    s6_text: str = str_from_id(jsv_to_table_id(s6));
    found7: bool = False;
    i7: int = 0;
    while i7 <= len(s6_text) - 5 {
        if s6_text[i7] == "g"
            and s6_text[i7 + 1] == "r"
            and s6_text[i7 + 2] == "e"
            and s6_text[i7 + 3] == "e"
            and s6_text[i7 + 4] == "t" {
            found7 = True;
            i7 = len(s6_text);
        }
        i7 = i7 + 1;
    }
    if found7 {
        ok += 1;
        print("OK  .toString() contains 'greet'");
    } else {
        fail += 1;
        print("FAIL .toString() missing 'greet' got='", s6_text, "'");
    }

    # ── 8: Function.prototype.call ────────────────────────────────────────
    res8: JSValue = js_Function_prototype_call(sq_val, js_undefined(), [js_int(5)]);
    if jsv_is_int32(res8) and jsv_to_int32(res8) == 25 {
        ok += 1;
        print("OK  Function.prototype.call sq.call(_, 5) = 25");
    } else {
        fail += 1;
        print("FAIL .call() tag=", res8, " int=", jsv_to_int32(res8));
    }

    # ── 9: Function.prototype.apply ───────────────────────────────────────
    args_obj9: JSValue = js_object_create_null();
    js_object_set(args_obj9, KEY_LENGTH, js_int(1));
    js_object_set(args_obj9, str_intern("0"), js_int(6));
    res9: JSValue = js_Function_prototype_apply(sq_val, js_undefined(), args_obj9);
    if jsv_is_int32(res9) and jsv_to_int32(res9) == 36 {
        ok += 1;
        print("OK  Function.prototype.apply sq.apply(_, [6]) = 36");
    } else {
        fail += 1;
        print("FAIL .apply() tag=", res9, " int=", jsv_to_int32(res9));
    }

    # ── 10: Function.prototype.bind — returns a new fn_val ────────────────
    bound10: JSValue = js_Function_prototype_bind(add_val, js_null(), []);
    if is_fn_val(bound10) {
        ok += 1;
        print("OK  Function.prototype.bind returns fn_val");
    } else {
        fail += 1;
        print("FAIL .bind() returned non-fn val tag=", bound10);
    }

    # ── 11: bind — sets name to 'bound <original>' ────────────────────────
    bname11: str = js_fn_get_name(bound10);
    starts11: bool = False;
    if len(bname11) >= 6 {
        starts11 = bname11[0] == "b"
            and bname11[1] == "o"
            and bname11[2] == "u"
            and bname11[3] == "n"
            and bname11[4] == "d"
            and bname11[5] == " ";
    }
    if starts11 {
        ok += 1;
        print("OK  bound fn name starts with 'bound '");
    } else {
        fail += 1;
        print("FAIL bound fn name='", bname11, "'");
    }

    # ── 12: bind with partial arg — .length reduced ───────────────────────
    bound12: JSValue = js_Function_prototype_bind(add_val, js_null(), [js_int(10)]);
    len12: int = js_fn_get_length(bound12);
    if len12 == 1 {
        ok += 1;
        print("OK  bind(partial) .length = orig - 1 = 1");
    } else {
        fail += 1;
        print("FAIL bind partial length=", len12);
    }

    # ── 13: js_builtin_create → is_builtin_val ────────────────────────────
    b13: JSValue = js_builtin_create("Math.sqrt", 1, 42);
    if is_builtin_val(b13) {
        ok += 1;
        print("OK  js_builtin_create → is_builtin_val");
    } else {
        fail += 1;
        print(
            "FAIL is_builtin_val returned False tag=",
            b13,
            " ptr=",
            jsv_to_table_id(b13)
        );
    }

    # ── 14: builtin name ──────────────────────────────────────────────────
    bname14: str = js_fn_get_name(b13);
    if bname14 == "Math.sqrt" {
        ok += 1;
        print("OK  builtin name = 'Math.sqrt'");
    } else {
        fail += 1;
        print("FAIL builtin name='", bname14, "'");
    }

    # ── 15: builtin arity ─────────────────────────────────────────────────
    blen15: int = js_fn_get_length(b13);
    if blen15 == 1 {
        ok += 1;
        print("OK  builtin arity = 1");
    } else {
        fail += 1;
        print("FAIL builtin arity=", blen15);
    }

    # ── 16: builtin is classified by is_builtin_val, NOT is_fn_val ──────────
    # is_fn_val() is for JS closures only (table_id < BUILTIN_BASE=1M).
    # is_builtin_val() sub-classifies the builtin range [1M, 2M).
    if is_builtin_val(b13) {
        ok += 1;
        print("OK  builtin is_fn_val returned False");
    } else {
        fail += 1;
        print("FAIL builtin is_builtin_val returned False");
    }

    # ── 17: builtin .toString ─────────────────────────────────────────────
    ts17: JSValue = js_Function_prototype_toString(b13);
    ts17_text: str = str_from_id(jsv_to_table_id(ts17));
    found17: bool = False;
    i17: int = 0;
    while i17 <= len(ts17_text) - 9 {
        if ts17_text[i17] == "M"
            and ts17_text[i17 + 1] == "a"
            and ts17_text[i17 + 2] == "t"
            and ts17_text[i17 + 3] == "h" {
            found17 = True;
            i17 = len(ts17_text);
        }
        i17 = i17 + 1;
    }
    if found17 {
        ok += 1;
        print("OK  builtin .toString() contains 'Math'");
    } else {
        fail += 1;
        print("FAIL builtin .toString() got='", ts17_text, "'");
    }

    # ── 18: js_Function(body_string) — constructor ────────────────────────
    fn18: JSValue = js_Function([_tstr("return 99;")]);
    if is_fn_val(fn18) {
        ok += 1;
        print("OK  js_Function('return 99;') is_fn_val");
    } else {
        fail += 1;
        print("FAIL js_Function returned non-fn tag=", fn18);
    }

    # ── 19: js_Function — result is callable and returns correct value ─────
    res19: JSValue = js_function_call(fn18, js_undefined(), []);
    if jsv_is_int32(res19) and jsv_to_int32(res19) == 99 {
        ok += 1;
        print("OK  js_Function body executes, returns 99");
    } else {
        fail += 1;
        print("FAIL js_Function call tag=", res19, " int=", jsv_to_int32(res19));
    }

    # ── 20: js_Function with param + body ─────────────────────────────────
    fn20: JSValue = js_Function([_tstr("x"), _tstr("return x * 3;")]);
    res20: JSValue = js_function_call(fn20, js_undefined(), [js_int(4)]);
    if jsv_is_int32(res20) and jsv_to_int32(res20) == 12 {
        ok += 1;
        print("OK  js_Function('x','return x*3') → fn(4) = 12");
    } else {
        fail += 1;
        print("FAIL js_Function w/param tag=", res20, " int=", jsv_to_int32(res20));
    }

    # ── 21: get_builtin_idx round-trip ────────────────────────────────────
    b21a: JSValue = js_builtin_create("Array.isArray", 1, 100);
    b21b: JSValue = js_builtin_create("Object.keys", 1, 101);
    idx21a: int = get_builtin_idx(b21a);
    idx21b: int = get_builtin_idx(b21b);
    if idx21b == idx21a + 1 {
        ok += 1;
        print("OK  builtin indices are sequential");
    } else {
        fail += 1;
        print("FAIL builtin idx21a=", idx21a, " idx21b=", idx21b);
    }

    # ── 22: js_fn_get_prototype returns a JSObject ────────────────────────
    proto22: JSValue = js_fn_get_prototype(fn1);
    if jsv_is_object_cell(proto22) and jsv_to_table_id(proto22) > 0 {
        ok += 1;
        print("OK  js_fn_get_prototype returns Object");
    } else {
        fail += 1;
        print(
            "FAIL js_fn_get_prototype tag=", proto22, " ptr=", jsv_to_table_id(proto22)
        );
    }

    # ── 23: Function.prototype.apply with null/undefined array ────────────
    res23: JSValue = js_Function_prototype_apply(sq_val, js_undefined(), js_null());
    # apply(null, null) → call with no args → sq(undefined) = NaN but sq = x*x
    # undefined * undefined = NaN with Float64 tag
    if jsv_is_double(res23) or jsv_is_int32(res23) {
        ok += 1;
        print("OK  apply with null argsArray does not throw");
    } else {
        fail += 1;
        print("FAIL apply(null, null) tag=", res23);
    }

    print("function smoke: passed=" + str(ok) + " failed=" + str(fail));
    if fail > 0 {
        fflush(0);
        _exit(1);
    }
}
