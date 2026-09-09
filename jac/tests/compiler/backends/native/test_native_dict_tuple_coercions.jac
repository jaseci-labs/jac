"""Tuple arity and semantic coercions survive generic pointer storage."""
import ctypes;
import from tests.support { compile_native, get_func }
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }

test "dictionary tuple storage preserves arity and element coercions" {
    (engine, module) = compile_native("dict_tuple_coercions.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , str(issues);
    assert get_func(engine, "singleton", ctypes.c_int64)() == 44;
    assert get_func(engine, "widened_numeric", ctypes.c_double)() == 7.0;
    assert get_func(engine, "optional_elements", ctypes.c_int64)() == 10;
}
