"""
tests/test_realm.na.jac — A3.0/A3.1 smoke tests for runtime/realm.na.jac.

Verifies:
  1. realm_new() produces a valid Realm.
  2. Two realm_new() calls return independent objects (no shared state).
  3. GC control fields have correct initial values.
  4. String / symbol tables start empty.
  5. Queue fields start empty.

Note: Typed cell tables (objects, closures, etc.) were removed from Realm in
A3.1 to break circular imports.  They live in their owning modules (A3.2).
"""

import from engine.src.runtime.realm { Realm, realm_new }

with entry {
    # ── Test 1: realm_new() returns a non-null object ────────────────────────
    r: Realm = realm_new();
    print("OK: realm_new() returned object");

    # ── Test 2: Two calls return independent objects ─────────────────────────
    r1: Realm = realm_new();
    r2: Realm = realm_new();

    r1.gc_alloc_count = 42;
    if r2.gc_alloc_count != 0 {
        print("FAIL: r2 gc_alloc_count polluted by r1 mutation");
    } else {
        print("OK: realms are independent");
    }

    # ── Test 3: GC control fields have correct initial values ────────────────
    r3: Realm = realm_new();
    ok: bool = True;
    if r3.gc_alloc_count != 0 {
        ok = False;
        print("FAIL: gc_alloc_count != 0");
    }
    if r3.gc_threshold != 10000 {
        ok = False;
        print("FAIL: gc_threshold != 10000");
    }
    if r3.gc_in_progress != False {
        ok = False;
        print("FAIL: gc_in_progress != False");
    }
    if r3.stack_limit != 1024 {
        ok = False;
        print("FAIL: stack_limit != 1024");
    }
    if r3.interrupt_flag != False {
        ok = False;
        print("FAIL: interrupt_flag != False");
    }
    if ok {
        print("OK: GC control fields correct");
    }

    # ── Test 4: String / symbol tables start empty ───────────────────────────
    r4: Realm = realm_new();
    ok2: bool = True;
    if len(r4.symbols) != 0 {
        ok2 = False;
        print("FAIL: symbols not empty");
    }
    if r4.intern_next_id != 0 {
        ok2 = False;
        print("FAIL: intern_next_id != 0");
    }
    if r4.intern_seeded != False {
        ok2 = False;
        print("FAIL: intern_seeded != False");
    }
    if r4.symbol_seeded != False {
        ok2 = False;
        print("FAIL: symbol_seeded != False");
    }
    if ok2 {
        print("OK: string/symbol tables correct");
    }

    # ── Test 5: Queue fields start empty ────────────────────────────────────
    r5: Realm = realm_new();
    ok3: bool = True;
    if len(r5.microtask_fns) != 0 {
        ok3 = False;
        print("FAIL: microtask_fns not empty");
    }
    if len(r5.next_tick_fns) != 0 {
        ok3 = False;
        print("FAIL: next_tick_fns not empty");
    }
    if len(r5.react_on_f) != 0 {
        ok3 = False;
        print("FAIL: react_on_f not empty");
    }
    if len(r5.fired_fns) != 0 {
        ok3 = False;
        print("FAIL: fired_fns not empty");
    }
    if r5.timer_next_id != 1 {
        ok3 = False;
        print("FAIL: timer_next_id != 1");
    }
    if ok3 {
        print("OK: queue fields correct");
    }

    print("A3.1 realm tests done");
}
