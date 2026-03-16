"""Fixture for del list[i] fix test (FIX 4).

Before the fix, `del container.field_list[i]` was silently ignored —
the element was never removed and the list length never decremented.
After the fix, the emitter shifts remaining elements left and decrements
the length field.

Exported functions return integer codes so they can be asserted via ctypes:
  - test_del_shrinks_length  → after del list[2] on a [10,20,30] list, returns len (expect 2)
  - test_del_shifts_elements → after del list[0] on [10,20,30], elem[0] is now 20 (expect 20)
  - test_del_last_element    → after del list[0] on a single-item list, len is 0 (expect 0)
"""

obj Container {
    has items: list[int];
}

"""Delete the last element; return new length (expect 2)."""
def:pub test_del_shrinks_length() -> int {
    c: Container = Container(items=[10, 20, 30]);
    del c.items[2];
    return len(c.items);
}

"""Delete the first element; return the new first value (expect 20)."""
def:pub test_del_shifts_elements() -> int {
    c: Container = Container(items=[10, 20, 30]);
    del c.items[0];
    return c.items[0];
}

"""Delete the only element; return new length (expect 0)."""
def:pub test_del_last_element() -> int {
    c: Container = Container(items=[42]);
    del c.items[0];
    return len(c.items);
}

with entry {}
