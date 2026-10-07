"""
tests/test_gc.na.jac — Phase A2.4 smoke tests for the mark-and-sweep GC.

Tests:
  1. Unreachable objects freed — allocate N, drop refs, collect, freed == N.
  2. Reachable objects kept   — root-referenced objects survive.
  3. Linked chain             — linked objects all freed when root dropped.
  4. Slot reuse               — alloc after collect re-uses a free-list slot.
  5. Re-entrancy guard        — nested gc_collect returns 0 (guard works).

Phase: A2.4
Run:   jac run tests/test_gc.na.jac
"""

import from engine.src.runtime.realm { Realm, realm_new }
import from engine.src.runtime.jsobject {
    obj_set_realm,
    js_object_create_null,
    js_object_set
}
import from engine.src.runtime.jsvalue { JSValue, jsv_to_table_id, js_int }
import from engine.src.runtime.jsstring { str_set_realm, str_intern }
import from engine.src.runtime.gc { gc_collect }
import from engine.src.runtime.jscell { CELL_FLAG_DEAD }
import from engine.src.builtins.function { fn_realm_set }

with entry {
    ok: int = 0;

    # ── Bootstrap ──────────────────────────────────────────────────────────
    r: Realm = realm_new();
    obj_set_realm(r);
    str_set_realm(r);
    fn_realm_set(r);

    # ══════════════════════════════════════════════════════════════════════
    # Test 1 — Unreachable objects are freed
    # Allocate 5 objects, keep no root references, collect.
    # Expected: freed == 5.
    # ══════════════════════════════════════════════════════════════════════
    o1: JSValue = js_object_create_null();
    o2: JSValue = js_object_create_null();
    o3: JSValue = js_object_create_null();
    o4: JSValue = js_object_create_null();
    o5: JSValue = js_object_create_null();

    # Drop all references — the 5 objects are now unreachable.
    o1 = 0;  # 0 == JS_UNDEFINED (NaN-boxed; not a cell → traced no-op)
    o2 = 0;
    o3 = 0;
    o4 = 0;
    o5 = 0;
}

glob empty: list[JSValue] = [];
with entry {
    freed1: int = gc_collect(r, empty);
    if freed1 == 5 {
        print("OK freed unreachable objects");
        ok += 1;
    } else {
        print("FAIL freed unreachable objects: freed=", freed1, "expected=5");
    }

    # ══════════════════════════════════════════════════════════════════════
    # Test 2 — Reachable objects survive (root held via realm.global_this)
    # ══════════════════════════════════════════════════════════════════════
    gc_root: JSValue = js_object_create_null();
    r.global_this = gc_root;  # make it a GC root
    freed2: int = gc_collect(r, empty);
    r.global_this = 0;  # clear root so future tests are clean
    # Sweep gc_root (now unreachable) before the next test so counts are clean.
    gc_collect(r, empty);

    if freed2 == 0 {
        print("OK reachable objects survive");
        ok += 1;
    } else {
        print("FAIL reachable objects survive: freed=", freed2, "expected=0");
    }

    # ══════════════════════════════════════════════════════════════════════
    # Test 3 — Linked chain: parent → child via property.
    # Both freed when the chain is unreachable.
    # ══════════════════════════════════════════════════════════════════════
    parent: JSValue = js_object_create_null();
    child: JSValue = js_object_create_null();
    key: int = str_intern("child");
    i: int = js_object_set(parent, key, child);  # parent.child = child
    # Drop both local refs — chain is unreachable
    parent = 0;
    child = 0;
    freed3: int = gc_collect(r, empty);
    if freed3 == 2 {
        print("OK linked chain freed");
        ok += 1;
    } else {
        print("FAIL linked chain freed: freed=", freed3, "expected=2");
    }

    # ══════════════════════════════════════════════════════════════════════
    # Test 4 — Free-list slot reuse.
    # After freeing N objects, the next allocation should reuse a slot
    # rather than extending the table.
    # ══════════════════════════════════════════════════════════════════════
    a1: JSValue = js_object_create_null();
    before_len: int = len(r.objects);
    idx1: int = jsv_to_table_id(a1);
    a1 = 0;
    freed4: int = gc_collect(r, empty);
    # Now allocate one more — should pop from free_object_slots.
    a2: JSValue = js_object_create_null();
    after_len: int = len(r.objects);
    idx2: int = jsv_to_table_id(a2);

    if freed4 >= 1 and after_len == before_len and idx2 == idx1 {
        print("OK free-list slot reused");
        ok += 1;
    } else {
        print(
            "FAIL free-list slot reused: freed=",
            freed4,
            "before=",
            before_len,
            "after=",
            after_len,
            "idx1=",
            idx1,
            "idx2=",
            idx2
        );
    }

    # ══════════════════════════════════════════════════════════════════════
    # Test 5 — Re-entrancy guard.
    # Simulate nested collect: set gc_in_progress=True, call collect.
    # Expected: returns 0 without doing anything.
    # ══════════════════════════════════════════════════════════════════════
    a3: JSValue = js_object_create_null();
    a3 = 0;
    r.gc_in_progress = True;
    freed5: int = gc_collect(r, empty);
    r.gc_in_progress = False;
    # Now collect for real to clean up a3.
    freed5b: int = gc_collect(r, empty);

    if freed5 == 0 and freed5b >= 1 {
        print("OK re-entrancy guard");
        ok += 1;
    } else {
        print("FAIL re-entrancy guard: nested=", freed5, "real=", freed5b);
    }

    if ok == 5 {
        print("ALL OK (5/5)");
    } else {
        print("FAILURES:", 5 - ok, "/ 5");
    }
}
