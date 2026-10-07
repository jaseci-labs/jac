"""
Closure cells — shared mutable references for captured variables.

A "cell" is a tiny wrapper object that holds a single JSValue. When a local
variable in a function is captured by one or more inner closures, the
defining function wraps it in a cell (MAKE_CELL opcode).  All closures that
capture that variable receive the *same* cell reference, so writes from one
closure (STORE_FREE / STORE_DEREF) are visible to the others (LOAD_FREE /
LOAD_DEREF).

Implementation: each cell is a JS object with a single property "__c__".
"""

import from engine.src.runtime.jsvalue { JSValue, jsv_is_object_cell, jsv_to_table_id }
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_get,
    js_object_set,
    js_object_has_own,
    js_object_ic_shape,
    js_object_slot_at_id,
    js_object_own_data_slot,
    js_object_shape_slot_set
}

"""Interned key used inside cell objects to store the wrapped value."""
glob _CELL_KEY: int = -1;

"""Lazily initialise _CELL_KEY (str_intern is not available at glob-init time)."""
def _get_ck -> int {
    if _CELL_KEY < 0 {
        _CELL_KEY = str_intern("__c__");
    }
    return _CELL_KEY;
}

# Every cell is built the same way (an empty null-prototype object, then
# `__c__`), so all cells share one shape with the value in one slot. The
# first make_cell learns both; cell_get / cell_set then read or write that
# slot straight from the object table when an object has that shape — a
# closure-variable access (LOAD_FREE / STORE_FREE: every module-level binding
# an ES module's functions use) no longer pays a full [[Get]] / [[Set]]
# (prototype walk, shape dict lookup, an owned JSObject reference). Anything
# else — no shape learned yet, a dict-mode or frozen object — takes the
# general path, so the fast path can only ever agree with it.
glob _CELL_SHAPE: int = -1,
     _CELL_SLOT: int = -1;

"""Create a closure cell wrapping `val`."""
def:pub make_cell(val: JSValue) -> JSValue {
    ck: int = _get_ck();
    cell: JSValue = js_object_create_null();
    js_object_set(cell, ck, val);
    if _CELL_SHAPE < 0 {
        mc_slot: int = js_object_own_data_slot(cell, ck);
        mc_shape: int = js_object_ic_shape(cell);
        if mc_slot >= 0 and mc_shape > 0 {
            _CELL_SLOT = mc_slot;
            _CELL_SHAPE = mc_shape;
        }
    }
    return cell;
}

"""Read the value inside a closure cell."""
def:pub cell_get(cell: JSValue) -> JSValue {
    if _CELL_SHAPE > 0 and js_object_ic_shape(cell) == _CELL_SHAPE {
        return js_object_slot_at_id(jsv_to_table_id(cell), _CELL_SLOT);
    }
    return js_object_get(cell, _get_ck());
}

"""Write a new value into a closure cell."""
def:pub cell_set(cell: JSValue, val: JSValue) -> None {
    if _CELL_SHAPE > 0
        and js_object_shape_slot_set(cell, _CELL_SHAPE, _CELL_SLOT, val) {
        return;
    }
    js_object_set(cell, _get_ck(), val);
}

"""True if `v` is a closure cell (a null-proto object holding the `__c__` slot).
Used by dynamic name resolution (LOAD_NAME/STORE_NAME inside `with`) to read or
write through a possibly-cellified local slot."""
def:pub is_cell(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _get_ck());
}
