"""
tests/test_gc_live.na.jac — Verify gc_tick actually fires in VM operation.

Lowers gc_threshold to 50 (fires every 50 opcodes), allocates 500 objects in
a loop (many thousands of opcodes total), then reads gc_stats() to confirm at
least one collection ran and freed something.

Run: jac run tests/test_gc_live.na.jac
"""

import from engine.src.runtime.realm { Realm, realm_new }
import from engine.src.runtime.jsobject { obj_set_realm, js_object_create_null }
import from engine.src.runtime.jsvalue { JSValue }
import from engine.src.runtime.jsstring { str_set_realm }
import from engine.src.builtins.function { fn_realm_set }
import from engine.src.runtime.gc { gc_collect, gc_stats }

with entry {
    r: Realm = realm_new();
    obj_set_realm(r);
    str_set_realm(r);
    fn_realm_set(r);

    # Lower threshold so collections fire frequently during the allocation loop.
    r.gc_threshold = 50;

    # Allocate 500 objects in a tight loop.
    # None are rooted (local var overwritten each iteration) → all become garbage.
    i: int = 0;
    while i < 500 {
        _v: JSValue = js_object_create_null();
        i = i + 1;
    }
}

glob
     # Force a final collection to sweep any remaining unreachable slots.
     empty: list[JSValue] = [];
with entry {
    gc_collect(r, empty);

    stats: list[int] = gc_stats();
    cycles: int = stats[0];
    freed: int = stats[1];

    print("GC cycles fired:", cycles);
    print("Total cells freed:", freed);

    if cycles >= 1 {
        print("OK gc_tick fired at least once");
    } else {
        print("FAIL gc_tick never fired (threshold too high or counter broken)");
    }

    if freed >= 100 {
        print("OK GC reclaimed objects (freed >= 100)");
    } else {
        print("FAIL fewer than 100 freed:", freed);
    }
}
