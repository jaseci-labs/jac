"""Chained and temporary receivers use the same union-property dispatch."""
import ctypes;
import from tests.support { compile_mir, compile_native, get_func }

test "iterate properties through chained, named and temporary union receivers" {
    demoted = compile_mir("union_property_iterable.jac").demoted();
    assert not demoted , str(demoted);
    (engine, _fx) = compile_native("union_property_iterable.jac");
    assert get_func(engine, "probe", ctypes.c_int64)() == 8;
    calls = get_func(engine, "calls", ctypes.c_int64);
    drops = get_func(engine, "drops", ctypes.c_int64);
    for name in ["called", "named"] {
        call = get_func(engine, name, ctypes.c_int64, ctypes.c_bool);
        for (flag, expected) in [(True, 5), (False, 3)] {
            before_calls = calls();
            before_drops = drops();
            assert call(flag) == expected , name;
            assert calls() - before_calls == 1 , name;
            delta = drops() - before_drops;
            assert delta == 1 , f"{name}({flag}): {delta}";
        }
    }
}
