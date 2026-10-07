"""
tests/test_gc_mark.na.jac — A2.2 / A2.2b smoke tests for GC mark bitmaps.

Verifies the three unified functions in runtime/gc_mark.na.jac:
  gc_mark(realm, kind, idx)       — sets the mark bit
  gc_is_marked(realm, kind, idx)  — queries the mark bit
  gc_clear_marks(realm, kind)     — resets all bits for one table

Checked for kinds: OBJECT (1-based idx), BUILTIN, NATIVE, MAP, SET (0-based).

Phase: A2.2 / A2.2b
Run:   jac run tests/test_gc_mark.na.jac
"""

import from engine.src.runtime.realm { Realm, realm_new }
import from engine.src.runtime.jsobject { obj_set_realm, js_object_create_null }
import from engine.src.runtime.jsvalue { JSValue, jsv_to_table_id }
import from engine.src.runtime.jsstring { str_set_realm }
import from engine.src.runtime.jscell {
    CELL_KIND_OBJECT,
    CELL_KIND_BUILTIN,
    CELL_KIND_NATIVE,
    CELL_KIND_MAP,
    CELL_KIND_SET
}
import from engine.src.runtime.gc_mark { gc_mark, gc_is_marked, gc_clear_marks }
import from engine.src.builtins.function { fn_realm_set, js_builtin_create }
import from engine.src.builtins.native_registry { native_set_realm, js_native_create }
import from engine.src.builtins.map { map_set_realm, js_map_create }
import from engine.src.builtins.set { set_set_realm, js_set_create }

with entry {
    ok: int = 0;
    err: int = 0;

    # ── Bootstrap a fresh Realm ───────────────────────────────────────────────
    r: Realm = realm_new();

    # Wire up the per-module realm globals that need it for alloc
    obj_set_realm(r);
    str_set_realm(r);
    fn_realm_set(r);
    native_set_realm(r);
    map_set_realm(r);
    set_set_realm(r);

    # ══════════════════════════════════════════════════════════════════════════
    # 1. realm.objects — CELL_KIND_OBJECT (1-based external idx)
    # ══════════════════════════════════════════════════════════════════════════
    obj1: JSValue = js_object_create_null();
    obj_idx: int = jsv_to_table_id(obj1);  # 1-based

    if not gc_is_marked(r, CELL_KIND_OBJECT, obj_idx) {
        ok += 1;
    } else {
        print("FAIL objects: new object should NOT be marked");
        err += 1;
    }

    gc_mark(r, CELL_KIND_OBJECT, obj_idx);
    if gc_is_marked(r, CELL_KIND_OBJECT, obj_idx) {
        ok += 1;
    } else {
        print("FAIL objects: gc_mark did not set bit");
        err += 1;
    }

    gc_clear_marks(r, CELL_KIND_OBJECT);
    if not gc_is_marked(r, CELL_KIND_OBJECT, obj_idx) {
        ok += 1;
    } else {
        print("FAIL objects: gc_clear_marks did not clear bit");
        err += 1;
    }

    if ok == 3 and err == 0 {
        print("OK objects mark bitmap");
    } else {
        print("FAIL objects");
    }

    # ══════════════════════════════════════════════════════════════════════════
    # 2. realm.builtins — CELL_KIND_BUILTIN (0-based idx)
    # ══════════════════════════════════════════════════════════════════════════
    ok = 0;
    err = 0;
    bi_val: JSValue = js_builtin_create("testBuiltin", 1, 0);
    bi_idx: int = len(r.builtins) - 1;

    if not gc_is_marked(r, CELL_KIND_BUILTIN, bi_idx) {
        ok += 1;
    } else {
        print("FAIL builtins: new builtin should NOT be marked");
        err += 1;
    }

    gc_mark(r, CELL_KIND_BUILTIN, bi_idx);
    if gc_is_marked(r, CELL_KIND_BUILTIN, bi_idx) {
        ok += 1;
    } else {
        print("FAIL builtins: gc_mark did not set bit");
        err += 1;
    }

    gc_clear_marks(r, CELL_KIND_BUILTIN);
    if not gc_is_marked(r, CELL_KIND_BUILTIN, bi_idx) {
        ok += 1;
    } else {
        print("FAIL builtins: gc_clear_marks did not clear bit");
        err += 1;
    }

    if ok == 3 and err == 0 {
        print("OK builtins mark bitmap");
    } else {
        print("FAIL builtins");
    }

    # ══════════════════════════════════════════════════════════════════════════
    # 3. realm.natives — CELL_KIND_NATIVE (0-based idx)
    # ══════════════════════════════════════════════════════════════════════════
    ok = 0;
    err = 0;
    nat_val: JSValue = js_native_create("testNative", 0, 0);
    nat_idx: int = len(r.natives) - 1;

    if not gc_is_marked(r, CELL_KIND_NATIVE, nat_idx) {
        ok += 1;
    } else {
        print("FAIL natives: new native should NOT be marked");
        err += 1;
    }

    gc_mark(r, CELL_KIND_NATIVE, nat_idx);
    if gc_is_marked(r, CELL_KIND_NATIVE, nat_idx) {
        ok += 1;
    } else {
        print("FAIL natives: gc_mark did not set bit");
        err += 1;
    }

    gc_clear_marks(r, CELL_KIND_NATIVE);
    if not gc_is_marked(r, CELL_KIND_NATIVE, nat_idx) {
        ok += 1;
    } else {
        print("FAIL natives: gc_clear_marks did not clear bit");
        err += 1;
    }

    if ok == 3 and err == 0 {
        print("OK natives mark bitmap");
    } else {
        print("FAIL natives");
    }

    # ══════════════════════════════════════════════════════════════════════════
    # 4. realm.maps — CELL_KIND_MAP (0-based idx)
    # ══════════════════════════════════════════════════════════════════════════
    ok = 0;
    err = 0;
    map_val: JSValue = js_map_create();
    map_idx: int = len(r.maps) - 1;

    if not gc_is_marked(r, CELL_KIND_MAP, map_idx) {
        ok += 1;
    } else {
        print("FAIL maps: new map should NOT be marked");
        err += 1;
    }

    gc_mark(r, CELL_KIND_MAP, map_idx);
    if gc_is_marked(r, CELL_KIND_MAP, map_idx) {
        ok += 1;
    } else {
        print("FAIL maps: gc_mark did not set bit");
        err += 1;
    }

    gc_clear_marks(r, CELL_KIND_MAP);
    if not gc_is_marked(r, CELL_KIND_MAP, map_idx) {
        ok += 1;
    } else {
        print("FAIL maps: gc_clear_marks did not clear bit");
        err += 1;
    }

    if ok == 3 and err == 0 {
        print("OK maps mark bitmap");
    } else {
        print("FAIL maps");
    }

    # ══════════════════════════════════════════════════════════════════════════
    # 5. realm.sets — CELL_KIND_SET (0-based idx)
    # ══════════════════════════════════════════════════════════════════════════
    ok = 0;
    err = 0;
    set_val: JSValue = js_set_create();
    set_idx: int = len(r.sets) - 1;

    if not gc_is_marked(r, CELL_KIND_SET, set_idx) {
        ok += 1;
    } else {
        print("FAIL sets: new set should NOT be marked");
        err += 1;
    }

    gc_mark(r, CELL_KIND_SET, set_idx);
    if gc_is_marked(r, CELL_KIND_SET, set_idx) {
        ok += 1;
    } else {
        print("FAIL sets: gc_mark did not set bit");
        err += 1;
    }

    gc_clear_marks(r, CELL_KIND_SET);
    if not gc_is_marked(r, CELL_KIND_SET, set_idx) {
        ok += 1;
    } else {
        print("FAIL sets: gc_clear_marks did not clear bit");
        err += 1;
    }

    if ok == 3 and err == 0 {
        print("OK sets mark bitmap");
    } else {
        print("FAIL sets");
    }
}
