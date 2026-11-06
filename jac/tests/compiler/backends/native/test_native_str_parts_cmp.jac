"""Native string comparison lowered inline from (data, len) parts.

== / != compare lengths before any bytes, so against a literal the byte compare
is a constant-size memcmp LLVM expands inline; orderings branch on the shorter
side so the literal's length is the memcmp size on the hot path. The test pins
the results against a byte-wise reference.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "string comparisons match byte-wise lexicographic order" {
    (eng, _) = compile_native("str_parts_cmp.jac");
    assert get_func(eng, "matrix_mismatches", ctypes.c_int64)() == 0;
    assert get_func(eng, "literal_mismatches", ctypes.c_int64)() == 0;
}
