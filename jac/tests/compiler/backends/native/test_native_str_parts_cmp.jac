"""Native string comparison agrees with byte-wise lexicographic order.

== / != and the orderings compare (data, len) parts, against literals and
between computed strings alike; these pin the results against a byte-wise
reference.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "string comparisons match byte-wise lexicographic order" {
    (eng, _) = compile_native("str_parts_cmp.jac");
    assert get_func(eng, "matrix_mismatches", ctypes.c_int64)() == 0;
    assert get_func(eng, "literal_mismatches", ctypes.c_int64)() == 0;
}
