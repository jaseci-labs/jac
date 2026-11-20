"""Entry for third-module-struct fix test (FIX 3b).

Imports make_data_a from fix_third_a and read_value/read_sum from
fix_third_b.  When calling read_value(d), DataA is a "third-module" type
(defined in A, referenced through B's parameter).  Before the fix the
compiler emitted i64(0) instead of the correct struct pointer.
"""

import from fix_third_a { DataA, make_data_a }
import from fix_third_b { read_value, read_sum }

"""Create a DataA in A's constructor, pass it to B's read_value; expect 77."""
def:pub test_third_struct_value() -> int {
    d: DataA = make_data_a(77, 3);
    return read_value(d);
}

"""Verify both fields survive the cross-module round-trip; expect 77+3 = 80."""
def:pub test_third_struct_sum() -> int {
    d: DataA = make_data_a(77, 3);
    return read_sum(d);
}

with entry {}
