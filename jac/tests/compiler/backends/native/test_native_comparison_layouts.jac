import ctypes;
import from tests.support { compile_native, get_func }

test "native tuple and set comparisons preserve operand layouts" {
    (engine, _) = compile_native("native_comparison_layouts.jac");
    compare = get_func(engine, "comparison_layouts", ctypes.c_bool, ctypes.c_int64);
    optional = get_func(engine, "optional_values", ctypes.c_bool, ctypes.c_int64);
    for seed in [-3, 0, 7] {
        assert compare(seed);
        assert optional(seed);
    }
}
