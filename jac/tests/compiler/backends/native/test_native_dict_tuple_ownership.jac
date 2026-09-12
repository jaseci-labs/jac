"""Tuple-valued dictionary reads retain values and release temporary owners."""

import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import ctypes;
import from tests.support { compile_native, get_func }
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }

test "dictionary tuple reads release each object exactly once" {
    (engine, module) = compile_native("dict_tuple_ownership.jac");
    issues = native_lowering_issues(str(artifact_for(module).llvm_ir));
    assert not issues , str(issues);
    drops = get_func(engine, "drop_count", ctypes.c_int64);
    for name in ["local_objects", "temporary_objects"] {
        probe = get_func(engine, name, ctypes.c_int64);
        before = drops();
        assert probe() == 13 , name;
        delta = drops() - before;
        assert delta == 2 , f"{name}: {delta}";
    }
}
