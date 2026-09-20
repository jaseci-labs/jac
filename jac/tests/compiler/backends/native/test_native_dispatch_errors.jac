"""Virtual calls unwind before continuing or returning to their caller."""
import ctypes;
import from tests.support { compile_native, get_func }

test "virtual errors release callee locals and reach the caller handler" {
    (engine, _) = compile_native("virtual_error_cleanup.jac");
    check = get_func(engine, "check", ctypes.c_bool);
    for _ in range(100) {
        assert check();
    }
}
