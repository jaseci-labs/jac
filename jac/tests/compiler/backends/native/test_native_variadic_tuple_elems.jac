"""Native lists of variadic tuples store each tuple as the sequence it lowers to.

`list[tuple[T, ...]]` reads its elements as `list[T]` sequences, but tuple
displays were stored into it as fixed-arity tuple boxes, so indexing an
element crashed (`xs[1][1]`) and sorting ordered garbage.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "list[tuple[T, ...]] elements read back, iterate and sort like Python" {
    (engine, _) = compile_native("variadic_tuple_elems.jac");
    for name in [
        "displayed",
        "appended",
        "inserted_and_assigned",
        "int_elements",
        "sorted_float_elements",
        "sorted_in_place_reversed",
        "sorted_int_elements",
        "fixed_pairs_median_split"
    ] {
        assert get_func(engine, name, ctypes.c_bool)() , name;
    }
}
