"""Explicit separator split and rsplit agree with direction and maxsplit."""
import ctypes;
import from tests.support { compile_native, get_func }

test "native split respects limits and scans right to left" {
    (engine, _) = compile_native("string_split_limits.jac");
    check = get_func(engine, "split_checks", ctypes.c_bool);
    for _ in range(30) {
        assert check();
    }
}
