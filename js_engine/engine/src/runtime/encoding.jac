"""Shared JSValue encoding constants and range predicates.

Single source of truth for the three-tier function-cell encoding:
  closures:  table_id < FN_BUILTIN_BASE
  builtins:  FN_BUILTIN_BASE <= table_id < FN_NATIVE_BASE
  natives:   table_id >= FN_NATIVE_BASE
The function bases sit high (2^30, 2^30 + 2^29) so the closure table can hold
about a billion entries: a vite build keeps more than a million closures alive,
and with the old 1M/2M bases closure #1,000,000 decoded as a builtin (not
callable, never marked by the GC). Ids stay below 2^31.

BUILTIN_BASE / NATIVE_BASE / SYMBOL_KEY_BASE are PROPERTY-KEY boundaries
(string-intern keys < BUILTIN_BASE, engine marker keys above it, symbol keys
from SYMBOL_KEY_BASE) and are unrelated to function ids.
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_is_cell,
    jsv_cell_kind,
    jsv_to_table_id,
    JS_CELL_KIND_NATIVE
}

glob:pub FN_BUILTIN_BASE: int = 1073741824,
     FN_NATIVE_BASE: int = 1610612736,
     BUILTIN_BASE: int = 1000000,
     NATIVE_BASE: int = 2000000,
     SYMBOL_KEY_BASE: int = 10000000,
     STR_INTERN_EMPTY: int = 6,
     PROTO_MAX_DEPTH: int = 1000;

"""True if v encodes a JS closure (table id in [0, FN_BUILTIN_BASE))."""
def:pub jsv_is_closure_cell(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    id: int = jsv_to_table_id(v);
    return id >= 0 and id < FN_BUILTIN_BASE;
}

"""True if v encodes a legacy builtin slot (FN_BUILTIN_BASE <= id < FN_NATIVE_BASE)."""
def:pub jsv_is_builtin_cell(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    id: int = jsv_to_table_id(v);
    return id >= FN_BUILTIN_BASE and id < FN_NATIVE_BASE;
}

"""True if v encodes a registered native function (id >= FN_NATIVE_BASE)."""
def:pub jsv_is_native_cell(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    return jsv_to_table_id(v) >= FN_NATIVE_BASE;
}
