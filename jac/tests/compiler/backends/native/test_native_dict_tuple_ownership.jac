"""Tuple-valued dictionary reads retain values and release temporary owners."""
import ctypes;
import from tests.support { compile_native, get_func }

test "dictionary tuple reads release each object exactly once" {
    (engine, fx) = compile_native("dict_tuple_ownership.jac");
    assert not fx.iface().demoted , fx.iface().demoted;
    drops = get_func(engine, "drop_count", ctypes.c_int64);
    for name in ["local_objects", "temporary_objects"] {
        probe = get_func(engine, name, ctypes.c_int64);
        before = drops();
        assert probe() == 13 , name;
        delta = drops() - before;
        assert delta == 2 , f"{name}: {delta}";
    }
}
