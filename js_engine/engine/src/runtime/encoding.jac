"""Shared JSValue encoding constants and range predicates.

Single source of truth for the three-tier cell encoding:
  closures:  table_id < BUILTIN_BASE
  builtins:  BUILTIN_BASE <= table_id < NATIVE_BASE
  natives:   table_id >= NATIVE_BASE
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_is_cell,
    jsv_cell_kind,
    jsv_to_table_id,
    JS_CELL_KIND_NATIVE
}

glob:pub BUILTIN_BASE: int = 1000000,
     NATIVE_BASE: int = 2000000,
     SYMBOL_KEY_BASE: int = 10000000,
     STR_INTERN_EMPTY: int = 6,
     PROTO_MAX_DEPTH: int = 1000;

"""True if v encodes a JS closure (table id in [0, BUILTIN_BASE))."""
def:pub jsv_is_closure_cell(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    id: int = jsv_to_table_id(v);
    return id >= 0 and id < BUILTIN_BASE;
}

"""True if v encodes a legacy builtin slot (BUILTIN_BASE <= id < NATIVE_BASE)."""
def:pub jsv_is_builtin_cell(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    id: int = jsv_to_table_id(v);
    return id >= BUILTIN_BASE and id < NATIVE_BASE;
}

"""True if v encodes a registered native function (id >= NATIVE_BASE)."""
def:pub jsv_is_native_cell(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    return jsv_to_table_id(v) >= NATIVE_BASE;
}
