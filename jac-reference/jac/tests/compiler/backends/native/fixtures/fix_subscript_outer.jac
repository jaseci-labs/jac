"""Outer module for cross-module list-subscript multilevel field access test (FIX 5).

Exports a module-level list[Outer] glob (ITEMS) and a push helper.
The entry module imports ITEMS and accesses ITEMS[i].value and ITEMS[i].extra
inline (without first assigning to a typed local).

Before the fix, _register_imported_globals did not populate var_type_node,
so _resolve_ptr_elem_cast_type had no AST node for the list element type
and emitted an unconditional i8* null, producing 0 or garbage at runtime.
"""

obj:pub Outer {
    has value: int;
    has extra: int;
}

glob:pub ITEMS: list[Outer] = [];

"""Append an Outer item to ITEMS."""
def:pub push_item(v: int, e: int) -> None {
    item: Outer = Outer(value=v, extra=e);
    ITEMS.append(item);
}

"""Return the number of items in ITEMS."""
def:pub items_len() -> int {
    return len(ITEMS);
}
