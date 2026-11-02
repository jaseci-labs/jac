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
     _GC_REM_VALS_CAP: int = 4096,
     _GC_REM_GENS: list[int] = [];

# JSGeneratorState.cell_flags bit: the state is in the remembered list (above
# the 0xFF DEAD sentinel, like the object flags).
glob:pub FLAG_GEN_REMEMBERED: int = 4096;

# Young budget, in approximate bytes (V8-style: the young generation is sized
# in bytes, starts small and grows only when collecting it often is what
# costs). Allocation sites add an estimate of what they allocate (a cell's row,
# a slot or element buffer's growth, a string's characters); a minor
# collection is requested once the bytes allocated since the last collection
# reach the budget. The allocation-count nursery (JAC_GC_NURSERY) stays as an
# upper bound. JAC_GC_YOUNG_MIN_MB / JAC_GC_YOUNG_MAX_MB set the range.
glob _GC_YOUNG_BYTES: int = 0,
     _GC_YOUNG_BUDGET: int = 8388608,
     _GC_YOUNG_MIN: int = 8388608,
     _GC_YOUNG_MAX: int = 1073741824,
     _GC_LAST_END_NS: int = 0;

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

"""Record old generator state `idx` as remembered: it was suspended (its
locals, saved stack and delegate written) since the last collection, so the
next minor collection traces it. Its caller has set FLAG_GEN_REMEMBERED."""
def:pub gc_rem_gen(idx: int) -> None {
    _GC_REM_GENS.append(idx);
}

"""The remembered generator states since the last collection."""
def:pub gc_rem_gens -> list[int] {
    return _GC_REM_GENS;
}

"""Start a new cycle: forget the remembered objects (the collector clears
their FLAG_REMEMBERED first) and the logged values."""
def:pub gc_barrier_reset -> None {
    _GC_REM_OBJS = [];
    _GC_REM_VALS = [];
    _GC_REM_VALS_CAP = 4096;
    _GC_REM_GENS = [];
}

"""Add `n` young bytes (a buffer's growth); the next cell allocation checks the
budget."""
def:pub gc_young_note(n: int) -> None {
    _GC_YOUNG_BYTES = _GC_YOUNG_BYTES + n;
}

"""Add `n` young bytes for a cell allocation; True once the young budget is
spent and a minor collection is due (generational mode only)."""
def:pub gc_young_add(n: int) -> bool {
    _GC_YOUNG_BYTES = _GC_YOUNG_BYTES + n;
    return _GC_GEN_ON and _GC_YOUNG_BYTES >= _GC_YOUNG_BUDGET;
}

"""A collection started: the young bytes so far are being collected."""
def:pub gc_young_reset -> None {
    _GC_YOUNG_BYTES = 0;
}

def:pub gc_young_budget -> int {
    return _GC_YOUNG_BUDGET;
}

"""Set the young budget's range in bytes (non-positive values keep the
default); the budget restarts at the minimum."""
def:pub gc_young_range_set(lo: int, hi: int) -> None {
    if lo > 0 {
        _GC_YOUNG_MIN = lo;
    }
    if hi > 0 {
        _GC_YOUNG_MAX = hi;
    }
    if _GC_YOUNG_MAX < _GC_YOUNG_MIN {
        _GC_YOUNG_MAX = _GC_YOUNG_MIN;
    }
    _GC_YOUNG_BUDGET = _GC_YOUNG_MIN;
}

"""Adapt the young budget after an automatic collection that ended at `now_ns`
and took `gc_ns`, `sweep_ns` of it sweeping young cells. Like V8's new space,
the budget doubles when much of the young generation survives (20% or more of
the `allocs` cells allocated since the last collection, of which `freed` were
freed) or when the part of a minor that does not scale with the young
generation -- roots, survivors, full-table sweeps -- costs 2% or more of the
program's time since the last collection; it halves when little survives (under
5%) and that part costs under 0.5%. A minor's young sweep scales with the
budget itself, so it never drives growth. Majors only restart the clock."""
def:pub gc_young_adapt(minor: bool, allocs: int, freed: int, gc_ns: int, sweep_ns: int, now_ns: int) -> None {
    mutator_ns: int = now_ns - gc_ns - _GC_LAST_END_NS;
    _GC_LAST_END_NS = now_ns;
    if not minor or allocs <= 0 or mutator_ns <= 0 {
        return;
    }
    survived: int = allocs - freed;
    if survived < 0 {
        survived = 0;
    }
    fixed_ns: int = gc_ns - sweep_ns;
    if survived * 100 >= allocs * 20 or fixed_ns * 100 >= mutator_ns * 2 {
        if _GC_YOUNG_BUDGET < _GC_YOUNG_MAX {
            _GC_YOUNG_BUDGET = _GC_YOUNG_BUDGET * 2;
            if _GC_YOUNG_BUDGET > _GC_YOUNG_MAX {
                _GC_YOUNG_BUDGET = _GC_YOUNG_MAX;
            }
        }
    } elif survived * 100 < allocs * 5 and fixed_ns * 200 < mutator_ns {
        if _GC_YOUNG_BUDGET > _GC_YOUNG_MIN {
            _GC_YOUNG_BUDGET = _GC_YOUNG_BUDGET // 2;
            if _GC_YOUNG_BUDGET < _GC_YOUNG_MIN {
                _GC_YOUNG_BUDGET = _GC_YOUNG_MIN;
            }
        }
    }
}
