"""Tuple unpacking uses the dictionary read's checked type."""
import ctypes;
import from tests.support { compile_native, compile_native_ir, get_func }
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }

test "unpack tuple-valued local global and temporary dictionaries" {
    module = compile_native_ir("dict_tuple_values.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , str(issues);
    (engine, _) = compile_native("dict_tuple_values.jac");
    get_func(engine, "jac_entry", None)();
    for (name, expected) in [
        ("global_tuple", 34),
        ("local_tuple", 12),
        ("temporary_tuple", 49)
    ] {
        probe = get_func(engine, name, ctypes.c_int64);
        assert probe() == expected , name;
    }
}

test "unpack an imported tuple-valued dictionary" {
    module = compile_native_ir("dict_tuple_import.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , str(issues);
    (engine, _) = compile_native("dict_tuple_import.jac");
    get_func(engine, "jac_entry", None)();
    assert get_func(engine, "imported_tuple", ctypes.c_int64)() == 34;
}
