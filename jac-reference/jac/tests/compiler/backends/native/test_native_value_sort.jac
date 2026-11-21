"""Stable native value sorting uses bounded merge passes and preserves owners."""
import ctypes;
import from tests.support { compile_native, get_func }

test "native value sorting handles large lists and scalar representations" {
    (engine, _) = compile_native("list_value_sort.jac");
    large = get_func(engine, "large_sort", ctypes.c_int64, ctypes.c_int32);
    scalars = get_func(engine, "scalar_sorts", ctypes.c_bool);
    assert large(150000) == 150000 * 150001 // 2;
    for _ in range(20) {
        assert scalars();
    }
}
