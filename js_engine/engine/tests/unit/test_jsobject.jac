import from engine.src.runtime.global { global_context_create }
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_from_int32,
    jsv_to_int32,
    jsv_is_object_cell,
    jsv_to_table_id,
    jsv_undefined
}
import from engine.src.runtime.jsobject {
    KEY_BASE,
    JSProperty,
    js_object_create,
    js_object_create_null,
    js_object_get,
    js_object_set,
    js_object_delete,
    js_object_has_own,
    js_object_has,
    js_object_get_prototype,
    js_object_set_prototype,
    js_object_keys,
    js_object_entries,
    js_object_assign,
    js_object_freeze,
    js_object_is_frozen,
    js_object_define_property,
    js_object_get_own_property_descriptor
}

# ═══════════════════════════════════════════════════════════════════════════════
# Smoke tests
# ═══════════════════════════════════════════════════════════════════════════════
with entry {
    # Engine startup: wire every module's realm singleton (string table,
    # object table, …); the engine code under test reads them.
    ctx = global_context_create();

    ok: int = 0;
    err: int = 0;
}

glob
     # Pre-test keys (using KEY_BASE offset to avoid collision with well-known IDs)
     k_x: int = KEY_BASE + 0,  # 10
     k_y: int = KEY_BASE + 1,  # 11
     k_z: int = KEY_BASE + 2;  # 12

with entry {
    # ── create / set / get ──────────────────────────────────────────────────

    obj1: JSValue = js_object_create_null();
    js_object_set(obj1, k_x, jsv_from_int32(42));
    got: JSValue = js_object_get(obj1, k_x);
    if jsv_to_int32(got) == 42 {
        ok += 1;
    } else {
        print("FAIL js_object_set/get Int32 got", jsv_to_int32(got));
        err += 1;
    }

    # ── has_own / has ────────────────────────────────────────────────────────

    if js_object_has_own(obj1, k_x) {
        ok += 1;
    } else {
        print("FAIL js_object_has_own present");
        err += 1;
    }
    if not js_object_has_own(obj1, k_y) {
        ok += 1;
    } else {
        print("FAIL js_object_has_own absent should be False");
        err += 1;
    }

    # ── delete ───────────────────────────────────────────────────────────────

    js_object_set(obj1, k_y, jsv_from_int32(99));
    del_ok: bool = js_object_delete(obj1, k_y);
    if del_ok and not js_object_has_own(obj1, k_y) {
        ok += 1;
    } else {
        print("FAIL js_object_delete");
        err += 1;
    }

    # ── prototype chain ──────────────────────────────────────────────────────

    proto: JSValue = js_object_create_null();
    js_object_set(proto, k_z, jsv_from_int32(77));
    child: JSValue = js_object_create(proto);
    inherited: JSValue = js_object_get(child, k_z);
    if jsv_to_int32(inherited) == 77 {
        ok += 1;
    } else {
        print("FAIL prototype chain get got", jsv_to_int32(inherited));
        err += 1;
    }
    if js_object_has(child, k_z) and not js_object_has_own(child, k_z) {
        ok += 1;
    } else {
        print("FAIL has vs has_own chain");
        err += 1;
    }

    # ── get/set prototype ────────────────────────────────────────────────────

    p: JSValue = js_object_get_prototype(child);
    if jsv_is_object_cell(p) and jsv_to_table_id(p) == jsv_to_table_id(proto) {
        ok += 1;
    } else {
        print("FAIL js_object_get_prototype");
        err += 1;
    }

    new_proto: JSValue = js_object_create_null();
    js_object_set_prototype(child, new_proto);
    p2: JSValue = js_object_get_prototype(child);
    if jsv_to_table_id(p2) == jsv_to_table_id(new_proto) {
        ok += 1;
    } else {
        print("FAIL js_object_set_prototype");
        err += 1;
    }

    # ── keys / entries ───────────────────────────────────────────────────────

    obj2: JSValue = js_object_create_null();
    js_object_set(obj2, k_x, jsv_from_int32(1));
    js_object_set(obj2, k_y, jsv_from_int32(2));
    ks: list[int] = js_object_keys(obj2);
    if len(ks) == 2 {
        ok += 1;
    } else {
        print("FAIL js_object_keys count got", len(ks));
        err += 1;
    }
    entries: list[JSValue] = js_object_entries(obj2);
    if len(entries) == 4 {
        ok += 1;
    } else {
        print("FAIL js_object_entries count got", len(entries));
        err += 1;
    }

    # ── Object.assign ────────────────────────────────────────────────────────

    src1: JSValue = js_object_create_null();
    src2: JSValue = js_object_create_null();
    js_object_set(src1, k_x, jsv_from_int32(10));
    js_object_set(src2, k_y, jsv_from_int32(20));
    target: JSValue = js_object_create_null();
}

glob sources: list[JSValue] = [];
with entry {
    sources.append(src1);
    sources.append(src2);
    js_object_assign(target, sources);
    ax: JSValue = js_object_get(target, k_x);
    ay: JSValue = js_object_get(target, k_y);
    if jsv_to_int32(ax) == 10 and jsv_to_int32(ay) == 20 {
        ok += 1;
    } else {
        print("FAIL js_object_assign x=", jsv_to_int32(ax), "y=", jsv_to_int32(ay));
        err += 1;
    }

    # ── freeze / is_frozen ───────────────────────────────────────────────────

    obj3: JSValue = js_object_create_null();
    js_object_set(obj3, k_x, jsv_from_int32(5));
    if not js_object_is_frozen(obj3) {
        ok += 1;
    } else {
        print("FAIL is_frozen before freeze should be False");
        err += 1;
    }
    js_object_freeze(obj3);
    if js_object_is_frozen(obj3) {
        ok += 1;
    } else {
        print("FAIL is_frozen after freeze");
        err += 1;
    }
    # set on frozen should be rejected
    js_object_set(obj3, k_x, jsv_from_int32(99));
    frozen_val: JSValue = js_object_get(obj3, k_x);
    if jsv_to_int32(frozen_val) == 5 {
        ok += 1;
    } else {
        print("FAIL frozen object rejects write got", jsv_to_int32(frozen_val));
        err += 1;
    }

    # ── define_property / get_own_property_descriptor ───────────────────────

    obj4: JSValue = js_object_create_null();
    ro_desc: JSProperty = JSProperty(
        key=k_x,
        value=jsv_from_int32(123),
        writable=False,
        enumerable=True,
        configurable=False,
        deleted=False
    );
    js_object_define_property(obj4, k_x, ro_desc);
    desc: JSProperty = js_object_get_own_property_descriptor(obj4, k_x);
    if desc.key != 0 and not desc.writable and jsv_to_int32(desc.value) == 123 {
        ok += 1;
    } else {
        print("FAIL define_property / get_descriptor");
        err += 1;
    }
    not_found: JSProperty = js_object_get_own_property_descriptor(obj4, k_y);
    if not_found.key == 0 {
        ok += 1;
    } else {
        print("FAIL get_descriptor not found sentinel");
        err += 1;
    }

    print("jsobject smoke:", ok, "passed,", err, "failed");
    if err > 0 {
        fflush(0);
        _exit(1);
    }
}
