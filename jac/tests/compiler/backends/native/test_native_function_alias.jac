"""Direct import aliases use the same canonical callable registry as modules."""
import ctypes;
import from tests.support { compile_mir, compile_native, get_func }

test "direct function import aliases resolve their original declaration" {
    fx = compile_mir("native_function_alias.jac");
    assert not fx.demoted() , str(fx.demoted());
    (engine, _fx) = compile_native("native_function_alias.jac");
    probe = get_func(engine, "imported_function_alias_probe", ctypes.c_int64);
    assert probe() == 12;
    factory = get_func(engine, "imported_factory_alias_probe", ctypes.c_int64);
    assert factory() == 40;
}
