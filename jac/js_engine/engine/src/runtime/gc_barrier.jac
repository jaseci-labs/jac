"""
Generational GC write-barrier state (docs/GENERATIONAL_GC.md §4.4).

A leaf module (it imports only jsvalue) so the object, closure, Map / Set and
native-function types can record stores without importing the realm. Other
modules use the functions below, never the globs directly: a glob rebound
here would not be seen through another module's import of it.

  * Remembered objects — old objects (1-based table ids) that had a
    reference stored into them since the last collection. JSObject's own
    barrier flags the row (FLAG_REMEMBERED) so an id is recorded once.
  * Logged values — references stored into an old non-object container
    (closure fields, Map / Set storages, native-function props) since the
    last collection; the next minor collection traces them as roots. A
    store allocates nothing, so a loop of stores never brings the collection
    that clears the list: past a cap it is compacted to its distinct values
    (at most the heap), and the cap doubles from what is left.
"""

import from engine.src.runtime.jsvalue { JSValue, jsv_is_cell }

glob _GC_GEN_ON: bool = False,
     _GC_REM_OBJS: list[int] = [],
     _GC_REM_VALS: list[JSValue] = [],
     _GC_REM_VALS_CAP: int = 4096;

"""True while generational collection is on (JAC_GC_GEN). With it off no cell
is ever flagged old, so every barrier is inert."""
def:pub gc_gen_on -> bool {
    return _GC_GEN_ON;
}

def:pub gc_gen_set(on: bool) -> None {
    _GC_GEN_ON = on;
}

"""Record old object `oid` (1-based) as remembered (its caller has set
FLAG_REMEMBERED on the row)."""
def:pub gc_rem_obj(oid: int) -> None {
    _GC_REM_OBJS.append(oid);
}

"""Log `v`, just stored into an old non-object container, for the next minor
collection (non-cells need no tracing)."""
def:pub gc_log_val(v: JSValue) -> None {
    if _GC_GEN_ON and jsv_is_cell(v) {
        _GC_REM_VALS.append(v);
        if len(_GC_REM_VALS) >= _GC_REM_VALS_CAP {
            _gc_rem_vals_compact();
        }
    }
}

"""Drop the repeated values from the log and double the cap from what is
left (amortized O(1) per store; the log stays within twice the distinct
values stored since the last collection)."""
def _gc_rem_vals_compact -> None {
    rc_seen: dict[int, bool] = {};
    rc_kept: list[JSValue] = [];
    for rc_v in _GC_REM_VALS {
        if rc_v not in rc_seen {
            rc_seen[rc_v] = True;
            rc_kept.append(rc_v);
        }
    }
    _GC_REM_VALS = rc_kept;
    _GC_REM_VALS_CAP = 4096;
    if 2 * len(rc_kept) > _GC_REM_VALS_CAP {
        _GC_REM_VALS_CAP = 2 * len(rc_kept);
    }
}

"""The remembered objects since the last collection (read by the collector)."""
def:pub gc_rem_objs -> list[int] {
    return _GC_REM_OBJS;
}

"""The logged values since the last collection (read by the collector)."""
def:pub gc_rem_vals -> list[JSValue] {
    return _GC_REM_VALS;
}

"""Start a new cycle: forget the remembered objects (the collector clears
their FLAG_REMEMBERED first) and the logged values."""
def:pub gc_barrier_reset -> None {
    _GC_REM_OBJS = [];
    _GC_REM_VALS = [];
    _GC_REM_VALS_CAP = 4096;
}
