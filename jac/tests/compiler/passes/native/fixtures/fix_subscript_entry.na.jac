"""Entry for cross-module list-subscript multilevel field access test (FIX 5).

Imports push_item, items_len, and the ITEMS glob from fix_subscript_outer.
Tests that inline cross-module subscript access (ITEMS[i].field) emits
a correct bitcast and returns the right value — not 0 or garbage.

Before the fix, var_type_node was never populated for imported globals,
so _resolve_ptr_elem_cast_type fell back to i8* and the field read was 0.
"""

import from fix_subscript_outer { Outer, ITEMS, push_item, items_len }

"""Push one item and access value field inline; expect 42."""
def:pub test_subscript_value() -> int {
    push_item(42, 7);
    return ITEMS[0].value;
}

"""Push one item and access extra field inline; expect 7."""
def:pub test_subscript_extra() -> int {
    push_item(42, 7);
    return ITEMS[0].extra;
}

"""Push two items; access second item's value inline; expect 99."""
def:pub test_subscript_second_item() -> int {
    push_item(42, 7);
    push_item(99, 3);
    return ITEMS[1].value;
}

with entry {}
