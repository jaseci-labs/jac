"""Native sorting orders erased-slot elements by their checked type.

A list of tuples, bytes or lists keeps each element in an `i8*` slot, and the
value sort compared every such slot as a string -- a tuple was ordered by the
bytes of its first field, so float and string leads (and ints past one byte)
came back in input order. Each fixture function answers whether its sorts
match Python's order.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "sorted and list.sort order tuples, bytes and lists like Python" {
    (engine, _) = compile_native("sort_erased_elements.jac");
    for name in [
        "float_int_tuples",
        "mixed_tuples",
        "keyed_tuples",
        "list_sort_tuples",
        "nested_tuples",
        "other_erased",
        "ragged_tuples"
    ] {
        assert get_func(engine, name, ctypes.c_bool)() , name;
    }
}
