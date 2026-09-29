"""A range object is a value: it iterates and it has a length.

Only `for i in range(...)` written inline lowered; a range held in a
variable failed with "for-loop iterable element type", and `len()` of a
range did not lower at all.
"""

import ctypes;
import from tests.support { compile_native, native_address }

test "a range in a variable iterates and measures like CPython" {
    (eng, _) = compile_native("range_values.jac");
    cases = [("walk_up", 7, 1204), ("walk_down", 10, 2204), ("measure", 4, 4003)];
    for (name, arg, want) in cases {
        address = native_address(eng, name);
        assert isinstance(address, int) and address != 0 , name;
        got = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address)(arg);
        assert got == want , f"{name}({arg}): {got} != {want}";
    }
}
