"""Native module aliases retain their source module binding."""
import ctypes;
import from tests.support { compile_native, get_func }
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }

test "module aliases resolve native functions and globals" {
    (engine, module) = compile_native("native_module_alias.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    probe = get_func(engine, "module_alias_probe", ctypes.c_int64);
    assert probe() == 52;
}

test "module aliases preserve lexical shadowing and standard library dispatch" {
    (engine, module) = compile_native("native_module_alias.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    shadowed = get_func(engine, "module_alias_shadow_probe", ctypes.c_int64);
    standard = get_func(engine, "standard_module_alias_probe", ctypes.c_int64);
    assert shadowed() == 9;
    assert standard() == 13;
}

test "dotted native module references preserve module identity" {
    (engine, module) = compile_native("native_dotted_module_alias.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    aliased = get_func(engine, "dotted_alias_probe", ctypes.c_int64);
    dotted = get_func(engine, "dotted_module_probe", ctypes.c_int64);
    assert aliased() == 25;
    assert dotted() == 7;
}

test "module aliases resolve bundled native library implementations" {
    (engine, module) = compile_native("native_stdlib_module_alias.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    probe = get_func(engine, "standard_library_module_alias_probe", ctypes.c_bool);
    assert probe();
    mixed_path = get_func(engine, "mixed_path_dispatch_probe", ctypes.c_bool);
    assert mixed_path();
}

test "qualified module members do not resolve a same-named local callable" {
    (engine, module) = compile_native("native_module_alias.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    probe = get_func(engine, "module_member_shadow_probe", ctypes.c_int64);
    assert probe() == 140;
}

test "module dispatch respects the binding rather than the source module spelling" {
    (engine, module) = compile_native("native_module_alias_shadowing.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    standard = get_func(engine, "standard_module_shadow_probe", ctypes.c_int64);
    canonical = get_func(engine, "canonical_module_name_shadow_probe", ctypes.c_int64);
    assert standard() == 21;
    assert canonical() == 8;
}
