"""Iteration cleanup preserves values referenced outside the loop body."""

import ctypes;
import from tests.support { compile_native, get_func }

test "managed loop values survive their iteration cleanup" {
    (engine, _) = compile_native("loop_live_out.jac");
    for (name, expected) in [
        ("while_result", 42),
        ("for_result", 3),
        ("nested_result", 2)
    ] {
        result = get_func(engine, name, ctypes.c_int64);
        assert result() == expected;
    }
}
