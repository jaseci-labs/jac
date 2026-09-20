import ctypes;
import from tests.support { compile_native, get_func }

test "foreign aliases and qualified calls use the declared C symbol and ABI" {
    (engine, _) = compile_native("foreign_aliases.jac", required=True);
    assert get_func(engine, "alias_calls", ctypes.c_bool)();
}
