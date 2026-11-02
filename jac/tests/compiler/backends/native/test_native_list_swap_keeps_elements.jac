"""Reversing or sorting a list of objects in place keeps its elements alive.

`list.reverse()` and the keyed `list.sort()` swapped two elements by reading
both and writing each back through the list's "set" helper. That helper
releases the element it overwrites, so the first write freed an element held
only by the swap, and the second stored the freed element back: half of a
reversed list of objects (or of lists, or of dicts) was dangling, read back
as zeros or as whatever was allocated next, and a sort aborted. A swap
changes no ownership, so the two elements are now stored straight into each
other's slots.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "reversing and sorting lists of objects keeps every element" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "list_swap_keeps_elements.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    lines = out.splitlines();
    assert lines[-5] == "[7, 6, 5, 4, 3, 2, 1, 0] [2, 2, 2, 2, 2, 2, 2, 2]" , out;
    assert lines[-4] == "[4, 3, 2, 1, 0] [2, 2, 2, 2, 2]" , out;
    assert lines[-3] == "[0, 1, 2, 3, 4, 5, 6, 7] [2, 2, 2, 2, 2, 2, 2, 2]" , out;
    assert lines[-2] == "[[3, 6], [2, 4], [1, 2], [0, 0]]" , out;
    assert lines[-1] == "[4, 3, 2, 1, 0]" , out;
}
