import from engine.src.runtime.global { global_context_create, init_global }
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_int,
    js_undefined,
    js_null,
    js_true,
    js_false,
    js_strict_equal,
    jsv_from_double,
    jsv_from_string_id,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_to_bool,
    jsv_to_int32
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_set,
    js_object_get
}
import from engine.src.builtins.array { js_array_len }
import from engine.src.builtins.object {
    js_Object,
    js_Object_create,
    js_Object_keys,
    js_Object_values,
    js_Object_entries,
    js_Object_assign,
    js_Object_freeze,
    js_Object_isFrozen,
    js_Object_getPrototypeOf,
    js_Object_setPrototypeOf,
    js_Object_getOwnPropertyNames,
    js_Object_getOwnPropertyDescriptor,
    js_Object_defineProperty,
    js_Object_is,
    js_Object_hasOwn,
    js_Object_fromEntries,
    js_Object_prototype_toString,
    js_Object_prototype_hasOwnProperty,
    js_Object_prototype_isPrototypeOf
}

def _ut_str(s: str) -> JSValue {
    return jsv_from_string_id(str_intern(s));
}

def _arr_len(arr: JSValue) -> int {
    return js_array_len(arr);
}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  Smoke tests
# ══════════════════════════════════════════════════════════════════════════════
with entry {
    # Engine startup: wire every module's realm singleton and install the
    # builtin prototypes, as the runtime does before running any script.
    ctx = global_context_create();
    init_global(ctx);

    ok: int = 0;
    fail: int = 0;

    # 1: Object() with no args returns object
    o1: JSValue = js_Object([]);
    if jsv_is_object_cell(o1) {
        ok += 1;
        print("OK  Object() returns Object");
    } else {
        fail += 1;
        print("FAIL Object() tag=", o1);
    }

    # 2: Object(existing_obj) returns same object
    existing: JSValue = js_object_create_null();
    o2: JSValue = js_Object([existing]);
    if js_strict_equal(o2, existing) {
        ok += 1;
        print("OK  Object(jsobj) identity");
    } else {
        fail += 1;
        print("FAIL Object(jsobj) identity");
    }

    # 3: Object.create(proto) sets prototype
    proto: JSValue = js_object_create_null();
    js_object_set(proto, str_intern("x"), js_int(42));
    child: JSValue = js_Object_create(proto, js_undefined());
    inherited: JSValue = js_object_get(child, str_intern("x"));
    if jsv_is_int32(inherited) and jsv_to_int32(inherited) == 42 {
        ok += 1;
        print("OK  Object.create proto chain");
    } else {
        fail += 1;
        print("FAIL Object.create got=", jsv_to_int32(inherited));
    }

    # 4: Object.keys returns array of string keys
    obj4: JSValue = js_object_create_null();
    js_object_set(obj4, str_intern("a"), js_int(1));
    js_object_set(obj4, str_intern("b"), js_int(2));
    keys4: JSValue = js_Object_keys(obj4);
    len4: int = _arr_len(keys4);
    if len4 == 2 {
        ok += 1;
        print("OK  Object.keys length=2");
    } else {
        fail += 1;
        print("FAIL Object.keys len=", len4);
    }

    # 5: Object.values
    vals5: JSValue = js_Object_values(obj4);
    len5: int = _arr_len(vals5);
    if len5 == 2 {
        ok += 1;
        print("OK  Object.values length=2");
    } else {
        fail += 1;
        print("FAIL Object.values len=", len5);
    }

    # 6: Object.entries
    ents6: JSValue = js_Object_entries(obj4);
    len6: int = _arr_len(ents6);
    if len6 == 2 {
        ok += 1;
        print("OK  Object.entries length=2 (2 pairs)");
    } else {
        fail += 1;
        print("FAIL Object.entries len=", len6);
    }

    # 7: Object.assign
    tgt: JSValue = js_object_create_null();
    js_object_set(tgt, str_intern("x"), js_int(1));
    src: JSValue = js_object_create_null();
    js_object_set(src, str_intern("y"), js_int(2));
    js_Object_assign(tgt, [src]);
    got_y: JSValue = js_object_get(tgt, str_intern("y"));
    if jsv_is_int32(got_y) and jsv_to_int32(got_y) == 2 {
        ok += 1;
        print("OK  Object.assign");
    } else {
        fail += 1;
        print("FAIL Object.assign got=", jsv_to_int32(got_y));
    }

    # 8: Object.freeze + isFrozen
    obj8: JSValue = js_object_create_null();
    js_object_set(obj8, str_intern("z"), js_int(5));
    js_Object_freeze(obj8);
    if js_Object_isFrozen(obj8) {
        ok += 1;
        print("OK  Object.freeze / isFrozen");
    } else {
        fail += 1;
        print("FAIL Object.isFrozen after freeze");
    }

    # 9: Object.getPrototypeOf / setPrototypeOf
    p9: JSValue = js_object_create_null();
    c9: JSValue = js_object_create_null();
    js_Object_setPrototypeOf(c9, p9);
    got_p: JSValue = js_Object_getPrototypeOf(c9);
    if js_strict_equal(got_p, p9) {
        ok += 1;
        print("OK  Object.getPrototypeOf / setPrototypeOf");
    } else {
        fail += 1;
        print("FAIL getPrototypeOf");
    }
}

glob
     # 10: Object.is — NaN equals NaN, +0 != -0
     # Workaround: 0.0/0.0 causes SIGABRT in native backend; use Inf-Inf instead.
     _inf: float = 1e308 * 2.0;
with entry {
    _nan: float = _inf - _inf;
    nan_a: JSValue = jsv_from_double(_nan);
    nan_b: JSValue = jsv_from_double(_nan);
    if js_Object_is(nan_a, nan_b) {
        ok += 1;
        print("OK  Object.is(NaN, NaN) = true");
    } else {
        fail += 1;
        print("FAIL Object.is(NaN, NaN)");
    }

    # 11: Object.hasOwn
    obj11: JSValue = js_object_create_null();
    js_object_set(obj11, str_intern("foo"), js_int(1));
    if js_Object_hasOwn(obj11, _ut_str("foo"))
        and not js_Object_hasOwn(obj11, _ut_str("bar")) {
        ok += 1;
        print("OK  Object.hasOwn");
    } else {
        fail += 1;
        print("FAIL Object.hasOwn");
    }

    # 12: Object.getOwnPropertyDescriptor
    obj12: JSValue = js_object_create_null();
    js_object_set(obj12, str_intern("k"), js_int(99));
    desc12: JSValue = js_Object_getOwnPropertyDescriptor(obj12, _ut_str("k"));
    v12: JSValue = js_object_get(desc12, str_intern("value"));
    if jsv_is_object_cell(desc12) and jsv_is_int32(v12) and jsv_to_int32(v12) == 99 {
        ok += 1;
        print("OK  Object.getOwnPropertyDescriptor");
    } else {
        fail += 1;
        print("FAIL getOwnPropertyDescriptor val=", jsv_to_int32(v12));
    }

    # 13: Object.defineProperty
    obj13: JSValue = js_object_create_null();
    desc_obj: JSValue = js_object_create_null();
    js_object_set(desc_obj, str_intern("value"), js_int(7));
    js_object_set(desc_obj, str_intern("writable"), js_false());
    js_object_set(desc_obj, str_intern("enumerable"), js_true());
    js_object_set(desc_obj, str_intern("configurable"), js_false());
    js_Object_defineProperty(obj13, _ut_str("n"), desc_obj);
    got13: JSValue = js_object_get(obj13, str_intern("n"));
    if jsv_is_int32(got13) and jsv_to_int32(got13) == 7 {
        ok += 1;
        print("OK  Object.defineProperty");
    } else {
        fail += 1;
        print("FAIL defineProperty got=", jsv_to_int32(got13));
    }

    # 14: Object.fromEntries round-trips Object.entries
    src14: JSValue = js_object_create_null();
    js_object_set(src14, str_intern("p"), js_int(10));
    js_object_set(src14, str_intern("q"), js_int(20));
    entries14: JSValue = js_Object_entries(src14);
    result14: JSValue = js_Object_fromEntries(entries14);
    pv: JSValue = js_object_get(result14, str_intern("p"));
    qv: JSValue = js_object_get(result14, str_intern("q"));
    if jsv_is_int32(pv)
        and jsv_to_int32(pv) == 10
        and jsv_is_int32(qv)
        and jsv_to_int32(qv) == 20 {
        ok += 1;
        print("OK  Object.fromEntries round-trips entries");
    } else {
        fail += 1;
        print("FAIL fromEntries p=", jsv_to_int32(pv), "q=", jsv_to_int32(qv));
    }

    # 15: Object.prototype.toString tag
    obj15: JSValue = js_object_create_null();
    s15: JSValue = js_Object_prototype_toString(obj15);
    if jsv_is_string_cell(s15) {
        ok += 1;
        print("OK  Object.prototype.toString returns String");
    } else {
        fail += 1;
        print("FAIL toString tag=", s15);
    }

    # 16: Object.prototype.hasOwnProperty
    obj16: JSValue = js_object_create_null();
    js_object_set(obj16, str_intern("own"), js_int(1));
    hv: JSValue = js_Object_prototype_hasOwnProperty(obj16, _ut_str("own"));
    if jsv_is_bool(hv) and jsv_to_bool(hv) {
        ok += 1;
        print("OK  Object.prototype.hasOwnProperty");
    } else {
        fail += 1;
        print("FAIL hasOwnProperty");
    }

    # 17: Object.prototype.isPrototypeOf
    p17: JSValue = js_object_create_null();
    c17: JSValue = js_object_create(p17);
    res17: JSValue = js_Object_prototype_isPrototypeOf(p17, c17);
    if jsv_is_bool(res17) and jsv_to_bool(res17) {
        ok += 1;
        print("OK  Object.prototype.isPrototypeOf");
    } else {
        fail += 1;
        print("FAIL isPrototypeOf");
    }

    print("object smoke: passed=" + str(ok) + " failed=" + str(fail));
    if fail > 0 {
        fflush(0);
        _exit(1);
    }
}
