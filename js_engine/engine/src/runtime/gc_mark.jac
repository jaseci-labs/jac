"""
runtime/gc_mark.na.jac — Unified GC mark-bitmap helpers (A2.2 / A2.2b).

Three functions replace the 30 per-table helpers that used to live in each
builtins / runtime / vm module:

    gc_mark(realm, kind, idx)          — stamp the slot with the current epoch
    gc_is_marked(realm, kind, idx)     — true iff the slot's stamp == current epoch
    gc_clear_marks(realm, kind)        — bump the epoch (O(1) un-mark of all slots)

G1.1 epoch marks: each `*_mark_epoch` array holds, per slot, the `gc_epoch` at
which it was last marked (0 = never). "Marked this cycle" is
`*_mark_epoch[idx] == realm.gc_epoch`; clearing is a single `gc_epoch += 1`,
so a full cycle no longer pays an O(live) bitmap reset. (Was: `list[bool]`
with a per-slot reset loop in gc_clear_marks.)

`kind` is a CELL_KIND_* constant from runtime.jscell.
`idx` follows each table's own convention:
  - CELL_KIND_OBJECT  → 1-based external index (JSValue table_id); internally
                        stored at bitmap position idx-1.
  - all other kinds   → 0-based index.

Phase: A2.2 / A2.2b
"""

import from engine.src.runtime.realm { Realm }
import from engine.src.runtime.jsobj_type { JSObject }
import from engine.src.vm.closure_type { JSClosure }
import from engine.src.builtins.function_type { JSFunctionMeta, BuiltinFn }
import from engine.src.builtins.native_type { NativeFn }
import from engine.src.builtins.map_type { JSMapStorage }
import from engine.src.builtins.set_type { JSSetStorage }
import from engine.src.builtins.generator_type { JSGeneratorState }
import from engine.src.builtins.regexp_type { JSRegExpState }
import from engine.src.vm.timer_type { TimerEntry }
import from engine.src.runtime.jscell {
    CELL_KIND_OBJECT,
    CELL_KIND_CLOSURE,
    CELL_KIND_FUNCTION,
    CELL_KIND_BUILTIN,
    CELL_KIND_NATIVE,
    CELL_KIND_MAP,
    CELL_KIND_SET,
    CELL_KIND_GENERATOR,
    CELL_KIND_REGEXP,
    CELL_KIND_TIMER
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_mark — set the mark bit for one cell
# ─────────────────────────────────────────────────────────────────────────────

"""Mark the cell identified by (kind, idx) as reachable in the current GC cycle
by stamping its `*_mark_epoch` slot with `realm.gc_epoch`.

Pads the epoch array on demand so the length always tracks the table length
(the alloc sites already pre-size it in lockstep; this is a safety net).
Unknown kinds are silently ignored (forward-compat with future cell types).
"""
def:pub gc_mark(realm: Realm, kind: int, idx: int) {
    if kind == CELL_KIND_OBJECT {
        bi: int = idx - 1;  # 1-based → 0-based
        while len(realm.objects_mark_epoch) < len(realm.objects) {
            realm.objects_mark_epoch.append(0);
        }
        if bi >= 0 and bi < len(realm.objects_mark_epoch) {
            realm.objects_mark_epoch[bi] = realm.gc_epoch;
        }
    } elif kind == CELL_KIND_CLOSURE {
        while len(realm.closures_mark_epoch) < len(realm.closures) {
            realm.closures_mark_epoch.append(0);
        }
        if idx >= 0 and idx < len(realm.closures_mark_epoch) {
            realm.closures_mark_epoch[idx] = realm.gc_epoch;
        }
    } elif kind == CELL_KIND_FUNCTION {
        while len(realm.functions_mark_epoch) < len(realm.functions) {
            realm.functions_mark_epoch.append(0);
        }
        if idx >= 0 and idx < len(realm.functions_mark_epoch) {
            realm.functions_mark_epoch[idx] = realm.gc_epoch;
        }
    } elif kind == CELL_KIND_BUILTIN {
        while len(realm.builtins_mark_epoch) < len(realm.builtins) {
            realm.builtins_mark_epoch.append(0);
        }
        if idx >= 0 and idx < len(realm.builtins_mark_epoch) {
            realm.builtins_mark_epoch[idx] = realm.gc_epoch;
        }
    } elif kind == CELL_KIND_NATIVE {
        while len(realm.natives_mark_epoch) < len(realm.natives) {
            realm.natives_mark_epoch.append(0);
        }
        if idx >= 0 and idx < len(realm.natives_mark_epoch) {
            realm.natives_mark_epoch[idx] = realm.gc_epoch;
        }
    } elif kind == CELL_KIND_MAP {
        while len(realm.maps_mark_epoch) < len(realm.maps) {
            realm.maps_mark_epoch.append(0);
        }
        if idx >= 0 and idx < len(realm.maps_mark_epoch) {
            realm.maps_mark_epoch[idx] = realm.gc_epoch;
        }
    } elif kind == CELL_KIND_SET {
        while len(realm.sets_mark_epoch) < len(realm.sets) {
            realm.sets_mark_epoch.append(0);
        }
        if idx >= 0 and idx < len(realm.sets_mark_epoch) {
            realm.sets_mark_epoch[idx] = realm.gc_epoch;
        }
    } elif kind == CELL_KIND_GENERATOR {
        while len(realm.generators_mark_epoch) < len(realm.generators) {
            realm.generators_mark_epoch.append(0);
        }
        if idx >= 0 and idx < len(realm.generators_mark_epoch) {
            realm.generators_mark_epoch[idx] = realm.gc_epoch;
        }
    } elif kind == CELL_KIND_REGEXP {
        while len(realm.regexps_mark_epoch) < len(realm.regexps) {
            realm.regexps_mark_epoch.append(0);
        }
        if idx >= 0 and idx < len(realm.regexps_mark_epoch) {
            realm.regexps_mark_epoch[idx] = realm.gc_epoch;
        }
    } elif kind == CELL_KIND_TIMER {
        while len(realm.timers_mark_epoch) < len(realm.timers) {
            realm.timers_mark_epoch.append(0);
        }
        if idx >= 0 and idx < len(realm.timers_mark_epoch) {
            realm.timers_mark_epoch[idx] = realm.gc_epoch;
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_is_marked — query the mark bit for one cell
# ─────────────────────────────────────────────────────────────────────────────

"""Return True if the cell identified by (kind, idx) was marked during this
GC cycle.  Returns False for out-of-range indices and unknown kinds."""
def:pub gc_is_marked(realm: Realm, kind: int, idx: int) -> bool {
    if kind == CELL_KIND_OBJECT {
        bi: int = idx - 1;
        if bi < 0 or bi >= len(realm.objects_mark_epoch) {
            return False;
        }
        return realm.objects_mark_epoch[bi] == realm.gc_epoch;
    } elif kind == CELL_KIND_CLOSURE {
        if idx < 0 or idx >= len(realm.closures_mark_epoch) {
            return False;
        }
        return realm.closures_mark_epoch[idx] == realm.gc_epoch;
    } elif kind == CELL_KIND_FUNCTION {
        if idx < 0 or idx >= len(realm.functions_mark_epoch) {
            return False;
        }
        return realm.functions_mark_epoch[idx] == realm.gc_epoch;
    } elif kind == CELL_KIND_BUILTIN {
        if idx < 0 or idx >= len(realm.builtins_mark_epoch) {
            return False;
        }
        return realm.builtins_mark_epoch[idx] == realm.gc_epoch;
    } elif kind == CELL_KIND_NATIVE {
        if idx < 0 or idx >= len(realm.natives_mark_epoch) {
            return False;
        }
        return realm.natives_mark_epoch[idx] == realm.gc_epoch;
    } elif kind == CELL_KIND_MAP {
        if idx < 0 or idx >= len(realm.maps_mark_epoch) {
            return False;
        }
        return realm.maps_mark_epoch[idx] == realm.gc_epoch;
    } elif kind == CELL_KIND_SET {
        if idx < 0 or idx >= len(realm.sets_mark_epoch) {
            return False;
        }
        return realm.sets_mark_epoch[idx] == realm.gc_epoch;
    } elif kind == CELL_KIND_GENERATOR {
        if idx < 0 or idx >= len(realm.generators_mark_epoch) {
            return False;
        }
        return realm.generators_mark_epoch[idx] == realm.gc_epoch;
    } elif kind == CELL_KIND_REGEXP {
        if idx < 0 or idx >= len(realm.regexps_mark_epoch) {
            return False;
        }
        return realm.regexps_mark_epoch[idx] == realm.gc_epoch;
    } elif kind == CELL_KIND_TIMER {
        if idx < 0 or idx >= len(realm.timers_mark_epoch) {
            return False;
        }
        return realm.timers_mark_epoch[idx] == realm.gc_epoch;
    }
    return False;
}

# ─────────────────────────────────────────────────────────────────────────────
# gc_clear_marks — reset all mark bits for one table
# ─────────────────────────────────────────────────────────────────────────────

"""Clear all mark bits for the table identified by kind.

Called at the start of each GC cycle before the mark phase begins.

G1.1 epoch marks: instead of an O(live) reset of every `*_mark_epoch` array,
just bump the realm's monotonic `gc_epoch`. A slot counts as "marked this
cycle" iff `*_mark_epoch[idx] == gc_epoch` (see gc_mark/gc_is_marked), so a
single increment logically un-marks every slot in every table at once — O(1)
regardless of heap size. The `kind` argument is therefore ignored (the only
caller passes -1 = all); a monotonic i64 epoch never wraps in practice.
Stale per-slot stamps are harmless: they are all `< gc_epoch` after the bump,
and a reused slot is re-stamped 0 at handout.
"""
def:pub gc_clear_marks(realm: Realm, kind: int) {
    realm.gc_epoch = realm.gc_epoch + 1;
}
