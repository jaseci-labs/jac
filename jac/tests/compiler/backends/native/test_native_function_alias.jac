"""Direct import aliases use the same canonical callable registry as modules."""
import ctypes;
import from tests.support { compile_native, get_func }
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }

test "direct function import aliases resolve their original declaration" {
    (engine, module) = compile_native("native_function_alias.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , str(issues);
    probe = get_func(engine, "imported_function_alias_probe", ctypes.c_int64);
    assert probe() == 12;
    factory = get_func(engine, "imported_factory_alias_probe", ctypes.c_int64);
    assert factory() == 40;
}
