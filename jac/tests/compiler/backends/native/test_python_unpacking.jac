"""Unpack Python iterables with Python error and consumption semantics."""
import ctypes;
import from tests.support { compile_native, get_func }


test "native unpacking consumes Python objects without a layout cast" {
    (engine, _) = compile_native("python_unpacking.jac", required=True);
    assert get_func(engine, "pair_sum", ctypes.c_int64)() == 5;
    assert get_func(engine, "consume_extra", ctypes.c_int64)() == 4;
    for (symbol, message) in [
        ("too_few", "not enough values to unpack (expected 2, got 1)"),
        ("too_many", "too many values to unpack (expected 2)")
    ] {
        raised = False;
        try {
            get_func(engine, symbol, ctypes.c_int64)();
        } except ValueError as error {
            raised = True;
            assert str(error) == message;
        }
        assert raised;
    }
}
