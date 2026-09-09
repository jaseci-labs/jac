"""Chained and temporary receivers use the same union-property dispatch."""
import ctypes;
import from tests.support { compile_native, get_func }
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }

test "iterate properties through chained, named and temporary union receivers" {
    (engine, module) = compile_native("union_property_iterable.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , str(issues);
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
